-- IndoHangout/modules/fishing.lua
-- Auto Fish: equip rod -> cast -> detect reeling minigame -> catch.
-- Streak protection keeps the catch progress above a threshold.
-- Auto-sell fish through the SellFish RemoteFunction, with a protected list.
-- Locked spot repositions the character to a saved CFrame before casting.

return function(ctx)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")
    local lp = Players.LocalPlayer
    local THEME = ctx.config.Theme
    local gui = ctx.gui

    local page = gui.TabPages.Fishing
    local Fishing = {}

    -- Config-backed runtime state
    local autoFishEnabled = false
    local streakProtection = ctx.config.Fishing.StreakProtection
    local streakThreshold = ctx.config.Fishing.StreakThreshold or 0.07
    local autoSellFish = false
    local sellAtCount = ctx.config.Fishing.SellAtCount or 10
    local selectedRod = nil
    local protectedFish = {}
    local lockedSpot = nil

    -- Runtime thread handles
    local fishThread = nil
    local sellThread = nil

    ---------------------------------------------------------------------
    -- REMOTE / TOOL LOOKUP
    ---------------------------------------------------------------------
    local cachedRodRemote = nil
    local function getRodRemote()
        if cachedRodRemote and cachedRodRemote.Parent then
            return cachedRodRemote
        end
        local events = ReplicatedStorage:FindFirstChild("Events")
        if not events then return nil end
        local remoteEvent = events:FindFirstChild("RemoteEvent")
        if not remoteEvent then return nil end
        cachedRodRemote = remoteEvent:FindFirstChild("Rod")
        return cachedRodRemote
    end

    local cachedSellRemote = nil
    local function getSellFishRemote()
        if cachedSellRemote and cachedSellRemote.Parent then
            return cachedSellRemote
        end
        local events = ReplicatedStorage:FindFirstChild("Events")
        if not events then return nil end
        local remoteFunction = events:FindFirstChild("RemoteFunction")
        if not remoteFunction then return nil end
        cachedSellRemote = remoteFunction:FindFirstChild("SellFish")
        return cachedSellRemote
    end

    ---------------------------------------------------------------------
    -- CHARACTER / TOOL HELPERS
    ---------------------------------------------------------------------
    local function getCharacter()
        return lp.Character
    end

    local function getHumanoid()
        local char = getCharacter()
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    -- Find all rods in backpack/character
    local function findRods()
        local rods = {}
        local containers = {}
        local backpack = lp:FindFirstChild("Backpack")
        if backpack then table.insert(containers, backpack) end
        local char = getCharacter()
        if char then table.insert(containers, char) end
        for _, container in ipairs(containers) do
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") and child.Name:lower():find("rod", 1, true) then
                    table.insert(rods, child)
                end
            end
        end
        return rods
    end

    local function equipRod()
        local rods = findRods()
        if #rods == 0 then return false end
        local chosen = rods[1]
        if selectedRod then
            for _, rod in ipairs(rods) do
                if rod.Name == selectedRod then
                    chosen = rod
                    break
                end
            end
        end
        local hum = getHumanoid()
        if not hum then return false end
        if chosen.Parent ~= getCharacter() then
            local ok = pcall(function() hum:EquipTool(chosen) end)
            if not ok then return false end
        end
        return true
    end

    ---------------------------------------------------------------------
    -- LOCKED SPOT
    ---------------------------------------------------------------------
    local function teleportToLockedSpot()
        if not lockedSpot then return end
        local char = getCharacter()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(function()
            hrp.CFrame = lockedSpot
        end)
    end

    ---------------------------------------------------------------------
    -- REELING MINIGAME DETECTION
    ---------------------------------------------------------------------
    -- Detect the Reeling GUI: PlayerGui.Reeling.MainFrame.Frame
    -- The catch bar is typically the "Frame" child with a fill bar.
    local function getReelingGui()
        local playerGui = lp:FindFirstChild("PlayerGui")
        if not playerGui then return nil end
        local reeling = playerGui:FindFirstChild("Reeling")
        if not reeling then return nil end
        return reeling
    end

    local function isReelingVisible()
        local reeling = getReelingGui()
        if not reeling then return false end
        local mainFrame = reeling:FindFirstChild("MainFrame")
        if not mainFrame then return false end
        return mainFrame.Visible
    end

    -- Try to infer the current catch progress from known bar UI.
    -- Many fishing games use a moving indicator or a fill Frame. We look for
    -- a Frame whose name suggests a progress bar and read its Size.X.Scale.
    local function getCatchProgress()
        local reeling = getReelingGui()
        if not reeling then return nil end
        local mainFrame = reeling:FindFirstChild("MainFrame")
        if not mainFrame then return nil end
        local barFrame = mainFrame:FindFirstChild("Frame") or mainFrame:FindFirstChild("ProgressBar") or mainFrame:FindFirstChild("Bar")
        if barFrame then
            -- The fill child of the bar
            local fill = barFrame:FindFirstChild("Fill") or barFrame:FindFirstChild("Bar")
            if fill and fill:IsA("GuiObject") then
                return fill.Size.X.Scale
            end
            -- Or the bar's own scale
            if barFrame:IsA("GuiObject") then
                return barFrame.Size.X.Scale
            end
        end
        return nil
    end

    ---------------------------------------------------------------------
    -- CAST + CATCH
    ---------------------------------------------------------------------
    -- Cast: equip rod, click (VirtualUser), then wait for reeling GUI.
    local function cast()
        if not equipRod() then return false end
        task.wait(0.2)
        pcall(function()
            VirtualUser:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VirtualUser:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
        return true
    end

    -- Catch: while reeling is visible, click to keep the fish.
    -- Streak protection watches a progress bar and clicks to raise it.
    local function performCatch()
        local startTime = tick()
        local timeout = 30

        while isReelingVisible() and tick() - startTime < timeout and ctx.destroyed == false do
            -- Click to catch
            pcall(function()
                VirtualUser:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(0.05)
                VirtualUser:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
            task.wait(0.1)

            -- Streak protection: if the progress dips below the threshold,
            -- click extra hard to recover it
            if streakProtection then
                local progress = getCatchProgress()
                if progress and progress < streakThreshold then
                    pcall(function()
                        VirtualUser:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                        task.wait(0.05)
                        VirtualUser:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    end)
                end
            end
        end
        return true
    end

    ---------------------------------------------------------------------
    -- AUTO FISH LOOP
    ---------------------------------------------------------------------
    local function fishLoop()
        while autoFishEnabled and not ctx.destroyed do
            if not lp.Character then
                task.wait(0.5)
                continue
            end

            teleportToLockedSpot()
            task.wait(0.2)

            local ok = cast()
            if ok then
                -- Wait for the reeling minigame to appear
                local waited = 0
                while not isReelingVisible() and waited < 8 and autoFishEnabled and not ctx.destroyed do
                    task.wait(0.1)
                    waited += 0.1
                end
                if isReelingVisible() then
                    performCatch()
                end
            end

            task.wait(ctx.config.Fishing.CooldownBetweenCasts or 1.0)
        end
        fishThread = nil
    end

    local function startFishLoop()
        if fishThread then return end
        fishThread = task.spawn(fishLoop)
        ctx.log("Fishing: Auto Fish ON", THEME.success)
    end

    local function stopFishLoop()
        autoFishEnabled = false
        fishThread = nil
    end

    ---------------------------------------------------------------------
    -- AUTO SELL
    ---------------------------------------------------------------------
    local function countFish()
        local count = 0
        local lp_ = Players.LocalPlayer
        local backpack = lp_ and lp_:FindFirstChild("Backpack")
        local containers = {}
        if backpack then table.insert(containers, backpack) end
        if lp_ and lp_.Character then table.insert(containers, lp_.Character) end
        for _, container in ipairs(containers) do
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") and not child.Name:lower():find("rod", 1, true) then
                    count += 1
                end
            end
        end
        return count
    end

    local function sellFish()
        local remote = getSellFishRemote()
        if not remote then return false, "SellFish remote not found" end
        local ok, err = pcall(function()
            remote:InvokeServer("SellFish", "All")
        end)
        if ok then
            ctx.log("Fish sold", THEME.success)
            return true
        end
        return false, err
    end

    local function sellLoop()
        while autoSellFish and not ctx.destroyed do
            local count = countFish()
            if count >= sellAtCount then
                sellFish()
                task.wait(1)
            else
                task.wait(1)
            end
        end
        sellThread = nil
    end

    local function startSellLoop()
        if sellThread then return end
        sellThread = task.spawn(sellLoop)
        ctx.log("Fishing: Auto Sell ON (at " .. tostring(sellAtCount) .. ")", THEME.success)
    end

    local function stopSellLoop()
        autoSellFish = false
        sellThread = nil
    end

    ---------------------------------------------------------------------
    -- PUBLIC CONTROLS
    ---------------------------------------------------------------------
    function Fishing.setEnabled(enabled)
        enabled = enabled and true or false
        autoFishEnabled = enabled
        if enabled then startFishLoop() else stopFishLoop() end
    end

    function Fishing.setStreakProtection(enabled)
        streakProtection = enabled and true or false
    end

    function Fishing.setThreshold(value)
        streakThreshold = math.clamp(tonumber(value) or 0.07, 0.01, 0.9)
    end

    function Fishing.setAutoSellFish(enabled)
        enabled = enabled and true or false
        autoSellFish = enabled
        if enabled then startSellLoop() else stopSellLoop() end
    end

    function Fishing.setSellAtCount(count)
        sellAtCount = math.max(1, math.floor(tonumber(count) or 10))
    end

    function Fishing.setProtectedFish(list)
        if type(list) == "table" then protectedFish = list end
    end

    function Fishing.getProtectedFish()
        return protectedFish
    end

    function Fishing.setLockedSpot(cf)
        lockedSpot = cf
    end

    function Fishing.getLockedSpot()
        return lockedSpot
    end

    function Fishing.lockCurrentSpot()
        local char = getCharacter()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            lockedSpot = hrp.CFrame
            ctx.config.Fishing.LockedSpot = lockedSpot
            ctx.log("Locked current fishing spot.", THEME.success)
            return true
        end
        return false
    end

    function Fishing.clearLockedSpot()
        lockedSpot = nil
        ctx.config.Fishing.LockedSpot = nil
    end

    function Fishing.sellNow()
        return sellFish()
    end

    function Fishing.applySettings(data)
        if type(data) ~= "table" then return end
        if data.StreakProtection ~= nil then Fishing.setStreakProtection(data.StreakProtection) end
        if data.StreakThreshold then Fishing.setThreshold(data.StreakThreshold) end
        if data.SellAtCount then Fishing.setSellAtCount(data.SellAtCount) end
        if type(data.ProtectedFish) == "table" then protectedFish = data.ProtectedFish end
        if data.LockedSpot ~= nil then
            -- LockedSpot may be a CFrame already (settings decode) or nil
            lockedSpot = data.LockedSpot
        end
        if data.AutoFish ~= nil then Fishing.setEnabled(data.AutoFish) end
        if data.AutoSellFish ~= nil then Fishing.setAutoSellFish(data.AutoSellFish) end
    end

    function Fishing.stopAll()
        stopFishLoop()
        stopSellLoop()
    end

    ---------------------------------------------------------------------
    -- UI BUILD
    ---------------------------------------------------------------------
    local function buildUI()
        if not page then return end
        local c = gui.components

        c.createSectionLabel(page.container, "Auto Fish")
        c.createToggle(page.container, "Auto Fish", false, function(val)
            Fishing.setEnabled(val)
        end)
        c.createDropdown(page.container, "Rod", { "(Auto)" }, 1, function(opt)
            selectedRod = (opt == "(Auto)") and nil or opt
        end)

        c.createSectionLabel(page.container, "Streak Protection")
        c.createToggle(page.container, "Enable Streak Protection", streakProtection, function(val)
            Fishing.setStreakProtection(val)
        end)
        c.createSlider(page.container, "Threshold", 1, 90, streakThreshold * 100, 1, function(val)
            Fishing.setThreshold(val / 100)
        end)

        c.createSectionLabel(page.container, "Locked Spot")
        c.createButton(page.container, "Lock Current Spot", function()
            Fishing.lockCurrentSpot()
        end)
        c.createButton(page.container, "Clear Locked Spot", function()
            Fishing.clearLockedSpot()
            ctx.log("Cleared locked spot.", THEME.dim)
        end)

        c.createSectionLabel(page.container, "Auto Sell Fish")
        c.createToggle(page.container, "Auto Sell Fish", false, function(val)
            Fishing.setAutoSellFish(val)
        end)
        c.createSlider(page.container, "Sell At Count", 1, 50, sellAtCount, 1, function(val)
            Fishing.setSellAtCount(val)
        end)
        c.createButton(page.container, "Sell Fish Now", function()
            local ok, err = Fishing.sellNow()
            if not ok then
                ctx.log("Sell failed: " .. tostring(err), THEME.danger)
            end
        end)
    end

    ---------------------------------------------------------------------
    -- LIFECYCLE
    ---------------------------------------------------------------------
    function Fishing.Init()
        buildUI()
    end

    function Fishing.Start() end
    function Fishing.Stop()
        Fishing.stopAll()
    end
    function Fishing.Destroy()
        Fishing.Stop()
    end

    ctx.registerCleanup(function() Fishing.Stop() end)

    return Fishing
end