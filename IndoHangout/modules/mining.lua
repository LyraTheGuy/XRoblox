-- IndoHangout/modules/mining.lua
-- Auto Mine + Sell Crystals. Crystals live at workspace.MapContent.Crystals.
-- Auto Mine tweens the character to a random crystal in range, aims the camera
-- at it and hits it with plain screen clicks (3 by default, 1.5s apart).

return function(ctx)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local THEME = ctx.config.Theme
    local gui = ctx.gui

    local page = gui.TabPages.Mining
    local Mining = {}
    local invokeSell = ctx.Utils
        and ctx.Utils.invokeSell
        or function(remote, remoteArg, arg)
            if not remote then return false, "remote not found" end
            local ok, err = pcall(function()
                remote:InvokeServer(remoteArg, arg)
            end)
            return ok, err
        end

    -- Runtime state
    local autoMineEnabled = false
    -- Radius used to detect crystals; every crystal inside it is a candidate.
    local maxDistance = ctx.config.Mining.MaxDistance or 12
    local hitsPerCrystal = ctx.config.Mining.HitsPerCrystal or 3
    local hitDelay = ctx.config.Mining.HitDelay or 1.5
    local standOffset = ctx.config.Mining.StandOffset or 4
    local autoSellEnabled = false
    local sellEveryX = ctx.config.Mining.SellEveryX or 10
    local sellCooldown = ctx.config.Mining.SellCooldown or 3
    local sellCategory = ctx.config.Mining.SellCategory or "Sell All"

    local mineLoopThread = nil
    local autoSellThread = nil
    local moveTween = nil
    local warnedNoPickaxe = false

    local crystalsSellRemote = nil
    local crystalsFolder = nil

    ---------------------------------------------------------------------
    -- REMOTE / PATH RESOLUTION
    ---------------------------------------------------------------------
    local function getCrystalsFolder()
        if crystalsFolder and crystalsFolder.Parent then
            return crystalsFolder
        end
        local ws = game:GetService("Workspace")
        local mapContent = ws:FindFirstChild("MapContent")
        if not mapContent then return nil end
        crystalsFolder = mapContent:FindFirstChild("Crystals")
        return crystalsFolder
    end

    local function getSellCrystalRemote()
        if crystalsSellRemote and crystalsSellRemote.Parent then
            return crystalsSellRemote
        end
        local rs = game:GetService("ReplicatedStorage")
        local events = rs:FindFirstChild("Events")
        if not events then return nil end
        local remoteFunction = events:FindFirstChild("RemoteFunction")
        if not remoteFunction then return nil end
        crystalsSellRemote = remoteFunction:FindFirstChild("SellCrystal")
        return crystalsSellRemote
    end

    ---------------------------------------------------------------------
    -- CRYSTAL DETECTION
    ---------------------------------------------------------------------
    local function getCharacterPosition()
        local lp = Players.LocalPlayer
        local char = lp and lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.Position or nil
    end

    local function getCrystalCenter(model)
        if not model then return nil end
        local primary = model.PrimaryPart
        if primary then
            return primary.Position
        end
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                return part.Position
            end
        end
        return nil
    end

    -- Every crystal inside Max Distance, not just the closest one.
    local function findNearbyCrystals()
        local folder = getCrystalsFolder()
        local myPos = getCharacterPosition()
        if not folder or not myPos then return {} end

        local nearby = {}
        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") or model:IsA("BasePart") then
                local center = getCrystalCenter(model)
                if center and (center - myPos).Magnitude <= maxDistance then
                    table.insert(nearby, model)
                end
            end
        end
        return nearby
    end

    ---------------------------------------------------------------------
    -- MINING INTERACTION
    ---------------------------------------------------------------------
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local function getViewport()
        local camera = workspace.CurrentCamera
        return (camera and camera.ViewportSize) or Vector2.new(1920, 1080)
    end

    -- Where the crystal sits on screen, or nil when it is behind the camera.
    local function screenPointOf(model)
        local camera = workspace.CurrentCamera
        local center = getCrystalCenter(model)
        if not camera or not center then return nil end
        local point, onScreen = camera:WorldToViewportPoint(center)
        if not onScreen then return nil end
        return Vector2.new(point.X, point.Y)
    end

    -- Point the camera at the crystal so the click lands on it.
    local function faceCrystal(model)
        local camera = workspace.CurrentCamera
        local center = getCrystalCenter(model)
        if not camera or not center then return end
        pcall(function()
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, center)
        end)
    end

    -- A hit is literally one click on screen.
    local function clickTarget(model)
        local viewport = getViewport()
        local point = screenPointOf(model)
        local baseX = point and point.X or viewport.X * 0.5
        local baseY = point and point.Y or viewport.Y * 0.5
        local x = math.clamp(baseX + math.random(-12, 12), 0, viewport.X - 1)
        local y = math.clamp(baseY + math.random(-12, 12), 0, viewport.Y - 1)
        local ok = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(math.random(4, 9) / 100)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        return ok
    end

    -- hitsPerCrystal clicks, hitDelay seconds apart.
    local function hitCrystal(model, times, delay)
        if not model then return false end
        times = math.max(1, tonumber(times) or hitsPerCrystal)
        delay = tonumber(delay) or hitDelay
        for i = 1, times do
            if not autoMineEnabled or ctx.destroyed then return false end
            clickTarget(model)
            if i < times then
                task.wait(delay)
            end
        end
        return true
    end

    -- Where to stand: just outside the crystal, on the side we came from.
    local function standPointFor(model)
        local center = getCrystalCenter(model)
        local myPos = getCharacterPosition()
        if not center or not myPos then return nil end
        local away = Vector3.new(myPos.X - center.X, 0, myPos.Z - center.Z)
        if away.Magnitude < 0.05 then
            away = Vector3.new(0, 0, 1)
        end
        return center + away.Unit * standOffset
    end

    -- Smoothly tween the character to the crystal (no teleporting).
    local function moveToCrystal(model)
        local lp = Players.LocalPlayer
        local char = lp and lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local target = standPointFor(model)
        if not hrp or not target then return false end

        local distance = (hrp.Position - target).Magnitude
        if distance <= 0.5 then return true end

        local center = getCrystalCenter(model)
        local goal = CFrame.lookAt(
            Vector3.new(target.X, hrp.Position.Y, target.Z),
            Vector3.new(center.X, hrp.Position.Y, center.Z)
        )

        if moveTween then
            pcall(function() moveTween:Cancel() end)
            moveTween = nil
        end

        local duration = math.clamp(distance / 55, 0.15, 3)
        local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = goal })
        moveTween = tween
        tween:Play()
        tween.Completed:Wait()
        if moveTween == tween then moveTween = nil end

        return autoMineEnabled and not ctx.destroyed
    end

    ---------------------------------------------------------------------
    -- TOOL: BEST PICKAXE (mirrors fishing's auto-rod equip)
    ---------------------------------------------------------------------
    local function getHumanoid()
        local lp = Players.LocalPlayer
        local char = lp and lp.Character
        return char and char:FindFirstChildOfClass("Humanoid") or nil
    end

    local function findPickaxes()
        local picks = {}
        local lp = Players.LocalPlayer
        local containers = {}
        local backpack = lp and lp:FindFirstChild("Backpack")
        if backpack then table.insert(containers, backpack) end
        if lp and lp.Character then table.insert(containers, lp.Character) end
        for _, container in ipairs(containers) do
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then
                    local lower = child.Name:lower()
                    if lower:find("pickaxe", 1, true) or lower:find("pick", 1, true) then
                        table.insert(picks, child)
                    end
                end
            end
        end
        return picks
    end

    -- Higher tier word wins first, then a number in the name, then attributes.
    local TIER_WORDS = {
        mythic = 7, secret = 7, divine = 6,
        legendary = 5, exotic = 5,
        epic = 4, rare = 3, uncommon = 2, common = 1,
    }

    local function pickaxeScore(tool)
        local lower = tool.Name:lower()
        local score = 0
        for word, weight in pairs(TIER_WORDS) do
            if lower:find(word, 1, true) then
                score = math.max(score, weight * 1000)
            end
        end
        local number = tonumber(lower:match("(%d+)"))
        if number then score += number end
        for _, key in ipairs({ "Level", "Power", "Tier", "Damage" }) do
            local attr = tool:GetAttribute(key)
            if type(attr) == "number" then
                score += attr * 10
            end
        end
        return score
    end

    local equippedPickaxe = nil
    local selectedPickaxe = nil -- nil = auto (best in backpack)
    local pickaxeDropdown = nil

    local function equipBestPickaxe()
        local picks = findPickaxes()
        if #picks == 0 then return false end

        local best = nil

        -- Manual pick wins when it is still in the backpack.
        if selectedPickaxe then
            for _, tool in ipairs(picks) do
                if tool.Name == selectedPickaxe then
                    best = tool
                    break
                end
            end
        end

        if not best then
            best = picks[1]
            local bestScore = pickaxeScore(best)
            for i = 2, #picks do
                local score = pickaxeScore(picks[i])
                if score > bestScore then
                    best, bestScore = picks[i], score
                end
            end
        end

        local hum = getHumanoid()
        if not hum then return false end

        local char = Players.LocalPlayer.Character
        if best.Parent ~= char then
            local ok = pcall(function() hum:EquipTool(best) end)
            if not ok then return false end
            task.wait(0.4)
        end

        if equippedPickaxe ~= best then
            equippedPickaxe = best
            ctx.log("Mining: equipped " .. best.Name, THEME.success)
        end
        return true
    end

    local function ensurePickaxe()
        local hum = getHumanoid()
        if not hum then return false end
        local char = Players.LocalPlayer.Character
        local current = char and char:FindFirstChildOfClass("Tool")
        if current and current.Name:lower():find("pick", 1, true) then
            equippedPickaxe = current
            return true
        end
        return equipBestPickaxe()
    end

    ---------------------------------------------------------------------
    -- AUTO MINE LOOP
    ---------------------------------------------------------------------
    local function mineLoop()
        while autoMineEnabled and not ctx.destroyed do
            local nearby = findNearbyCrystals()
            if #nearby == 0 then
                task.wait(0.75)
                continue
            end

            -- A pickaxe must be in hand before any click counts.
            if not ensurePickaxe() then
                if not warnedNoPickaxe then
                    warnedNoPickaxe = true
                    ctx.log("Mining: no pickaxe in backpack", THEME.danger)
                end
                task.wait(0.5)
                continue
            end
            warnedNoPickaxe = false

            -- Random pick among the crystals in range, tween over to it.
            local crystal = nearby[math.random(1, #nearby)]
            if not moveToCrystal(crystal) then
                task.wait(0.25)
                continue
            end

            faceCrystal(crystal)
            task.wait(0.1)
            hitCrystal(crystal, hitsPerCrystal, hitDelay)
            task.wait(math.random(25, 45) / 100)
        end
        mineLoopThread = nil
    end

    local function startMineLoop()
        if mineLoopThread then return end
        warnedNoPickaxe = false
        if pickaxeDropdown and pickaxeDropdown.setOptions then
            pickaxeDropdown.setOptions(Mining.getPickaxeNames())
        end
        equipBestPickaxe()
        mineLoopThread = task.spawn(mineLoop)
        ctx.log("Mining: Auto Mine ON", THEME.success)
    end

    local function stopMineLoop()
        autoMineEnabled = false
        mineLoopThread = nil
        if moveTween then
            pcall(function() moveTween:Cancel() end)
            moveTween = nil
        end
    end

    ---------------------------------------------------------------------
    -- SELLING
    ---------------------------------------------------------------------
    local function countCrystalsInInventory()
        local count = 0
        local lp = Players.LocalPlayer
        local backpack = lp and lp:FindFirstChild("Backpack")
        local containers = {}
        if backpack then table.insert(containers, backpack) end
        if lp and lp.Character then table.insert(containers, lp.Character) end
        for _, container in ipairs(containers) do
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then
                    local lower = child.Name:lower()
                    if not lower:find("rod", 1, true) and not lower:find("pickaxe", 1, true) then
                        count += 1
                    end
                end
            end
        end
        return count
    end

    local function sellCrystals(category)
        local remote = getSellCrystalRemote()
        if not remote then return false, "SellCrystal remote not found" end
        category = category or sellCategory or "Sell All"
        -- Shared sell routine: same invoke pattern as fish selling, only the
        -- remote and its first argument differ.
        local ok, err = invokeSell(remote, "SellCrystal", category)
        if ok then
            ctx.log("Crystals sold (" .. tostring(category) .. ")", THEME.success)
            return true
        end
        return false, err
    end

    local function autoSellLoop()
        while autoSellEnabled and not ctx.destroyed do
            local count = countCrystalsInInventory()
            if count >= sellEveryX then
                sellCrystals(sellCategory)
                task.wait(sellCooldown)
            else
                task.wait(1)
            end
        end
        autoSellThread = nil
    end

    local function startAutoSell()
        if autoSellThread then return end
        autoSellThread = task.spawn(autoSellLoop)
        ctx.log("Mining: Auto Sell ON (every " .. tostring(sellEveryX) .. ")", THEME.success)
    end

    local function stopAutoSell()
        autoSellEnabled = false
        autoSellThread = nil
    end

    ---------------------------------------------------------------------
    -- PUBLIC CONTROLS
    ---------------------------------------------------------------------
    function Mining.setAutoMineEnabled(enabled)
        enabled = enabled and true or false
        autoMineEnabled = enabled
        if enabled then
            startMineLoop()
        else
            stopMineLoop()
        end
    end

    function Mining.setMaxDistance(dist)
        maxDistance = math.max(1, tonumber(dist) or 12)
    end

    -- "(Auto = best)" clears the manual pick.
    function Mining.setPickaxe(name)
        if not name or name == "(Auto = best)" then
            selectedPickaxe = nil
            ctx.log("Mining: pickaxe auto (best in backpack)", THEME.dim)
        else
            selectedPickaxe = tostring(name)
            ctx.log("Mining: pickaxe " .. selectedPickaxe, THEME.dim)
        end
        if autoMineEnabled then
            equipBestPickaxe()
        end
    end

    function Mining.getPickaxe()
        return selectedPickaxe
    end

    function Mining.getPickaxeNames()
        local names = { "(Auto = best)" }
        local seen = {}
        for _, tool in ipairs(findPickaxes()) do
            if not seen[tool.Name] then
                seen[tool.Name] = true
                table.insert(names, tool.Name)
            end
        end
        return names
    end

    function Mining.setAutoSellEnabled(enabled)
        enabled = enabled and true or false
        autoSellEnabled = enabled
        if enabled then
            startAutoSell()
        else
            stopAutoSell()
        end
    end

    function Mining.setSellEvery(count)
        sellEveryX = math.max(1, math.floor(tonumber(count) or 10))
    end

    function Mining.setSellCooldown(seconds)
        sellCooldown = math.max(1, tonumber(seconds) or 3)
    end

    function Mining.setSellCategory(category)
        if type(category) == "string" and category ~= "" then
            sellCategory = category
        end
    end

    function Mining.sellNow()
        return sellCrystals(sellCategory)
    end

    function Mining.applySettings(data)
        if type(data) ~= "table" then return end
        if data.MaxDistance then Mining.setMaxDistance(data.MaxDistance) end
        if data.SellEveryX then Mining.setSellEvery(data.SellEveryX) end
        if data.SellCooldown then Mining.setSellCooldown(data.SellCooldown) end
        if data.SellCategory then Mining.setSellCategory(data.SellCategory) end
        if data.AutoMine ~= nil then Mining.setAutoMineEnabled(data.AutoMine) end
        if data.AutoSellCrystals ~= nil then Mining.setAutoSellEnabled(data.AutoSellCrystals) end
    end

    function Mining.stopAll()
        stopMineLoop()
        stopAutoSell()
    end

    ---------------------------------------------------------------------
    -- UI BUILD
    ---------------------------------------------------------------------
    local function buildUI()
        if not page then return end
        local c = gui.components

        c.createSectionLabel(page.container, "Auto Mine")
        c.createToggle(page.container, "Auto Mine", false, function(val)
            Mining.setAutoMineEnabled(val)
        end)
        c.createSlider(page.container, "Max Distance", 1, 40, maxDistance, 1, function(val)
            Mining.setMaxDistance(val)
        end)
        pickaxeDropdown = c.createDropdown(page.container, "Pickaxe", Mining.getPickaxeNames(), 1, function(opt)
            Mining.setPickaxe(opt)
        end)

        c.createSectionLabel(page.container, "Selling")
        c.createButton(page.container, "Sell Crystals Now", function()
            local ok, err = Mining.sellNow()
            if not ok then
                ctx.log("Sell failed: " .. tostring(err), THEME.danger)
            end
        end)
        c.createDropdown(page.container, "Sell Category", ctx.config.Mining.SellCategories or {"Sell All"}, 1, function(opt)
            Mining.setSellCategory(opt)
        end)

        c.createSectionLabel(page.container, "Auto Sell")
        c.createToggle(page.container, "Auto Sell Crystals", false, function(val)
            Mining.setAutoSellEnabled(val)
        end)
        c.createSlider(page.container, "Sell Every X Crystals", 1, 50, sellEveryX, 1, function(val)
            Mining.setSellEvery(val)
        end)
        c.createSlider(page.container, "Sell Cooldown (s)", 1, 30, sellCooldown, 1, function(val)
            Mining.setSellCooldown(val)
        end)
    end

    ---------------------------------------------------------------------
    -- LIFECYCLE
    ---------------------------------------------------------------------
    function Mining.Init()
        buildUI()
    end

    function Mining.Start() end
    function Mining.Stop()
        Mining.stopAll()
    end
    function Mining.Destroy()
        Mining.Stop()
    end

    ctx.registerCleanup(function() Mining.Stop() end)

    return Mining
end