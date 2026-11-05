-- IndoHangout/modules/mining.lua
-- Auto Mine + Sell Crystals. Crystals live at workspace.MapContent.Crystals.
-- Auto Mine tweens the character to a random crystal in range, then mines it
-- through ReplicatedStorage.Events.RemoteEvent.Pickaxe:FireServer("Hit")
-- (3 hits by default, 1.5s apart). No screen clicking involved.

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
    local sellMode = ctx.config.Mining.SellMode or "Count" -- "Count" | "Minute"
    local sellEveryMinutes = ctx.config.Mining.SellEveryMinutes or 1
    local lastAutoSellAt = 0
    local sellRateInput = nil

    local mineLoopThread = nil
    local autoSellThread = nil
    local moveTween = nil

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

    -- Average of the visible parts is far more reliable than "first descendant",
    -- which often lands on a sunken hitbox or an anchor part nowhere near the gem.
    local function getCrystalCenter(model)
        if not model then return nil end
        if model:IsA("BasePart") then return model.Position end
        if model.PrimaryPart then return model.PrimaryPart.Position end

        local sum, count = Vector3.zero, 0
        for _, part in ipairs(model:GetDescendants()) do
            -- The "HP" object is a health readout, not part of the gem body.
            if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HP" then
                sum = sum + part.Position
                count += 1
            end
        end
        if count > 0 then
            return sum / count
        end
        return nil
    end

    -- Only real crystals carry an "HP" object (health/durability). The folder
    -- also holds decorations, anchors and effects that must be ignored.
    local function findHP(model)
        if not model then return nil end
        local ok, hp = pcall(function() return model:FindFirstChild("HP", true) end)
        if ok then return hp end
        return nil
    end

    local function hasHP(model)
        if findHP(model) then return true end
        local ok, value = pcall(function() return model:GetAttribute("HP") end)
        return ok and value ~= nil
    end

    -- A crystal whose HP hit zero is depleted; leave it alone.
    local function isDepleted(model)
        local hp = findHP(model)
        local value = nil
        if hp and hp:IsA("ValueBase") then
            local ok, v = pcall(function() return tonumber(hp.Value) end)
            if ok then value = v end
        elseif not hp then
            local ok, v = pcall(function() return tonumber(model:GetAttribute("HP")) end)
            if ok then value = v end
        end
        return value ~= nil and value <= 0
    end

    -- Crystals may sit directly in the folder or one Folder deep.
    local function collectCrystals(folder, out, depth)
        if not folder or depth > 2 then return out end
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                if hasHP(child) then
                    table.insert(out, child)
                end
            elseif child:IsA("Folder") then
                collectCrystals(child, out, depth + 1)
            end
        end
        return out
    end

    -- Every crystal inside Max Distance, not just the closest one.
    local function findNearbyCrystals()
        local folder = getCrystalsFolder()
        local myPos = getCharacterPosition()
        if not folder or not myPos then return {}, nil end

        local nearby = {}
        local nearestDist = nil
        for _, model in ipairs(collectCrystals(folder, {}, 1)) do
            local center = getCrystalCenter(model)
            if center and not isDepleted(model) then
                local dist = (center - myPos).Magnitude
                if not nearestDist or dist < nearestDist then
                    nearestDist = dist
                end
                if dist <= maxDistance then
                    table.insert(nearby, model)
                end
            end
        end
        return nearby, nearestDist
    end

    ---------------------------------------------------------------------
    -- MINING INTERACTION
    ---------------------------------------------------------------------
    -- The game's mining remote: Pickaxe:FireServer("Hit").
    local cachedPickaxeRemote = nil
    local function getPickaxeRemote()
        if cachedPickaxeRemote and cachedPickaxeRemote.Parent then
            return cachedPickaxeRemote
        end
        local rs = game:GetService("ReplicatedStorage")
        local events = rs:FindFirstChild("Events")
        local remoteEvent = events and events:FindFirstChild("RemoteEvent")
        if not remoteEvent then return nil end
        cachedPickaxeRemote = remoteEvent:FindFirstChild("Pickaxe")
        return cachedPickaxeRemote
    end

    -- Point the camera at the crystal; the game may target whatever we look at.
    local function faceCrystal(model)
        local camera = workspace.CurrentCamera
        local center = getCrystalCenter(model)
        if not camera or not center then return end
        pcall(function()
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, center)
        end)
    end

    -- One hit = one Pickaxe:FireServer("Hit").
    local function hitCrystal(times, delay)
        local remote = getPickaxeRemote()
        if not remote then
            return false, "Pickaxe remote not found"
        end

        times = math.max(1, tonumber(times) or hitsPerCrystal)
        delay = tonumber(delay) or hitDelay

        for i = 1, times do
            if not autoMineEnabled or ctx.destroyed then return false end
            local ok = pcall(function() remote:FireServer("Hit") end)
            if not ok then
                return false, "Pickaxe:FireServer failed"
            end
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
        local emptyScans = 0
        while autoMineEnabled and not ctx.destroyed do
            local nearby, nearest = findNearbyCrystals()
            if #nearby == 0 then
                emptyScans += 1
                -- Say why nothing is happening instead of failing silently.
                if emptyScans == 4 then
                    local extra = nearest
                        and string.format(" (nearest %.1f studs away)", nearest)
                        or ""
                    ctx.log(
                        string.format("Mining: no live crystals within %d studs%s", math.floor(maxDistance), extra),
                        THEME.warn
                    )
                end
                task.wait(0.75)
                continue
            end
            emptyScans = 0

            -- Best effort: the game still accepts hits without a held tool.
            ensurePickaxe()

            -- Random pick among the crystals in range, tween over to it.
            local crystal = nearby[math.random(1, #nearby)]
            if not moveToCrystal(crystal) then
                task.wait(0.25)
                continue
            end

            faceCrystal(crystal)
            task.wait(0.1)
            local ok, err = hitCrystal(hitsPerCrystal, hitDelay)
            if not ok and err then
                ctx.log("Mining: " .. err, THEME.danger)
                task.wait(1)
            end
            task.wait(math.random(25, 45) / 100)
        end
        mineLoopThread = nil
    end

    local function startMineLoop()
        if mineLoopThread then return end
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
            local shouldSell = false
            if sellMode == "Minute" then
                shouldSell = (os.clock() - lastAutoSellAt) >= (sellEveryMinutes * 60)
            else
                shouldSell = countCrystalsInInventory() >= sellEveryX
            end

            if shouldSell then
                sellCrystals(sellCategory)
                lastAutoSellAt = os.clock()
                task.wait(sellCooldown)
            else
                task.wait(1)
            end
        end
        autoSellThread = nil
    end

    local function startAutoSell()
        if autoSellThread then return end
        lastAutoSellAt = os.clock()
        autoSellThread = task.spawn(autoSellLoop)
        local rate = sellMode == "Minute"
            and (tostring(sellEveryMinutes) .. " min")
            or ("count " .. tostring(sellEveryX))
        ctx.log("Mining: Auto Sell ON (per " .. rate .. ")", THEME.success)
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

    function Mining.setSellMode(mode)
        sellMode = (tostring(mode or ""):lower():find("minute", 1, true)) and "Minute" or "Count"
        ctx.config.Mining.SellMode = sellMode
        lastAutoSellAt = os.clock()
        ctx.log("Mining: auto sell mode — per " .. sellMode, THEME.dim)
    end

    function Mining.getSellMode()
        return sellMode
    end

    -- Count mode: how many crystals. Minute mode: how often to sell.
    function Mining.setSellRate(value)
        local number = tonumber(value)
        if not number or number <= 0 then return false end
        if sellMode == "Minute" then
            sellEveryMinutes = math.max(0.1, number)
            ctx.config.Mining.SellEveryMinutes = sellEveryMinutes
        else
            sellEveryX = math.max(1, math.floor(number))
            ctx.config.Mining.SellEveryX = sellEveryX
        end
        lastAutoSellAt = os.clock()
        return true
    end

    function Mining.getSellRate()
        return sellMode == "Minute" and sellEveryMinutes or sellEveryX
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
        if data.SellMode then Mining.setSellMode(data.SellMode) end
        if data.SellEveryMinutes then sellEveryMinutes = math.max(0.1, tonumber(data.SellEveryMinutes) or 1) end
        if data.SellCooldown then Mining.setSellCooldown(data.SellCooldown) end
        if data.SellCategory then Mining.setSellCategory(data.SellCategory) end
        if data.AutoMine ~= nil then Mining.setAutoMineEnabled(data.AutoMine) end
        if data.AutoSellCrystals ~= nil then Mining.setAutoSellEnabled(data.AutoSellCrystals) end
    end

    -- Diagnostics: prints what detection actually sees.
    function Mining.scan()
        local folder = getCrystalsFolder()
        if not folder then
            ctx.log("Mining: MapContent.Crystals not found", THEME.danger)
            return
        end
        local all = collectCrystals(folder, {}, 1)
        local nearby, nearest = findNearbyCrystals()
        ctx.log(
            string.format(
                "Mining scan: %d crystals with HP, %d in range%s",
                #all,
                #nearby,
                nearest and string.format(", nearest %.1f studs", nearest) or ", no positions"
            ),
            THEME.dim
        )
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
        c.createButton(page.container, "Scan Crystals", function()
            Mining.scan()
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
        local function refreshSellRate()
            if not sellRateInput then return end
            if sellRateInput.text then
                sellRateInput.text(tostring(Mining.getSellRate()))
            end
            local row = sellRateInput.container
            local lbl = row and row:FindFirstChildOfClass("TextLabel")
            if lbl then
                lbl.Text = (Mining.getSellMode() == "Minute")
                    and "Sell Every (min)"
                    or "Sell Rate (count)"
            end
        end

        c.createDropdown(page.container, "Sell Mode", { "Per Count", "Per Minute" },
            (Mining.getSellMode() == "Minute") and 2 or 1, function(opt)
                Mining.setSellMode(opt)
                refreshSellRate()
            end)
        sellRateInput = c.createTextbox(page.container, "Sell Rate (count)", "10")
        if sellRateInput then
            sellRateInput.text(tostring(Mining.getSellRate()))
            refreshSellRate()
            local box = sellRateInput.box
            if box then
                box.FocusLost:Connect(function(enterPressed)
                    if not enterPressed then return end
                    if Mining.setSellRate(box.Text) then
                        refreshSellRate()
                    else
                        box.Text = tostring(Mining.getSellRate())
                    end
                    box:ReleaseFocus()
                end)
            end
        end
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