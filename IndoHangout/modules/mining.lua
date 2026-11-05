-- IndoHangout/modules/mining.lua
-- Auto Mine + Sell Crystals. Crystals live at workspace.MapContent.Crystals.
-- Each crystal requires 3 hits; move to the nearest valid crystal, only
-- interact when physically close (no unrealistic teleports).

return function(ctx)
    local Players = game:GetService("Players")
    local THEME = ctx.config.Theme
    local gui = ctx.gui

    local page = gui.TabPages.Mining
    local Mining = {}

    -- Runtime state
    local autoMineEnabled = false
    local maxDistance = ctx.config.Mining.MaxDistance or 12
    local hitsPerCrystal = 3
    local autoSellEnabled = false
    local sellEveryX = ctx.config.Mining.SellEveryX or 10
    local sellCooldown = ctx.config.Mining.SellCooldown or 3
    local sellCategory = ctx.config.Mining.SellCategory or "Sell All"

    local mineLoopThread = nil
    local autoSellThread = nil
    local hitCounts = {} -- [crystalModel] = number of hits

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

    local function findNearestCrystal()
        local folder = getCrystalsFolder()
        if not folder then return nil end
        local myPos = getCharacterPosition()
        if not myPos then return nil end

        local nearest = nil
        local nearestDist = maxDistance + 1

        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") or model:IsA("BasePart") then
                local center = getCrystalCenter(model)
                if center then
                    local dist = (center - myPos).Magnitude
                    if dist <= maxDistance and dist < nearestDist then
                        nearest = model
                        nearestDist = dist
                    end
                end
            end
        end
        return nearest
    end

    local function isNearCrystal(model)
        if not model then return false end
        local lp = Players.LocalPlayer
        local char = lp and lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local center = getCrystalCenter(model)
        if not center then return false end
        return (center - hrp.Position).Magnitude <= 2.5
    end

    ---------------------------------------------------------------------
    -- MINING INTERACTION
    ---------------------------------------------------------------------
    local VirtualUser = game:GetService("VirtualUser")

    local function hitCrystal(model)
        if not model then return false end
        local prompt = model:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    prompt = d
                    break
                end
            end
        end
        if prompt then
            pcall(function()
                prompt:InputHoldBegin()
                task.wait(0.15)
                prompt:InputHoldEnd()
            end)
            return true
        end
        pcall(function()
            VirtualUser:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VirtualUser:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
        return true
    end

    ---------------------------------------------------------------------
    -- AUTO MINE LOOP
    ---------------------------------------------------------------------
    local function mineLoop()
        while autoMineEnabled and not ctx.destroyed do
            local crystal = findNearestCrystal()
            if not crystal then
                task.wait(1)
                continue
            end
            if not isNearCrystal(crystal) then
                task.wait(0.5)
                continue
            end
            local hits = hitCounts[crystal] or 0
            if hits >= hitsPerCrystal then
                hitCounts[crystal] = nil
                task.wait(0.3)
                continue
            end
            local ok = hitCrystal(crystal)
            if ok then
                hitCounts[crystal] = hits + 1
            end
            task.wait(0.5)
        end
        mineLoopThread = nil
    end

    local function startMineLoop()
        if mineLoopThread then return end
        hitCounts = {}
        mineLoopThread = task.spawn(mineLoop)
        ctx.log("Mining: Auto Mine ON", THEME.success)
    end

    local function stopMineLoop()
        autoMineEnabled = false
        mineLoopThread = nil
        hitCounts = {}
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
        local ok, err = pcall(function()
            remote:InvokeServer("SellCrystal", category)
        end)
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