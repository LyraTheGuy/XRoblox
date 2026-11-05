-- IndoHangout/modules/fishing.lua
-- Logic reverted to the reference script (Indo Hangout - Advanced Auto Fish &
-- Streak Protector v3.1, robloxscripts.com):
--   • Cast: RodRemote:FireServer("Throw") after equipping the rod.
--   • Reel: RunService.Heartbeat deadzone tracker (WhiteBar vs RedBar, ±0.015)
--     controlling DirectMouseButton simulation at screen center
--     (VirtualInputManager:SendMouseButtonEvent) — NEVER Space, so the
--     character never jumps on catch.
--   • Streak failsafe: RenderStepped monitor of ProgressBg.ProgressBar; below
--     the threshold it fires RodRemote("Catch", "Err"), closes the Reeling GUI
--     and returns to the saved position (never registers a miss).
--   • Auto return: exact CFrame locked when Auto Fish starts (or via the Lock
--     button); re-applied on respawn together with the jump guard.
--   • Auto Sell Fish sells with SellFishRemote("SellFish", name) from the
--     SellFish GUI SellList, protected blacklist honored, bulk fallback.
--   • Anti-AFK via VirtualUser, fishing camera-shake cutscene disabled
--     natively (DisableFishingAnimation attribute).

return function(ctx)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local lp = Players.LocalPlayer
    local THEME = ctx.config.Theme
    local gui = ctx.gui
    local Utils = ctx.Utils or {}
    local invokeSell = Utils.invokeSell
        or function(remote, remoteArg, arg)
            if not remote then return false, "remote not found" end
            local ok, err = pcall(function()
                remote:InvokeServer(remoteArg, arg)
            end)
            return ok, err
        end

    local page = gui.TabPages.Fishing
    local Fishing = {}

    -- Config-backed settings
    local streakProtection = ctx.config.Fishing.StreakProtection
    local streakThreshold = ctx.config.Fishing.StreakThreshold or 0.07
    local sellAtCount = ctx.config.Fishing.SellAtCount or 10
    local sellCategory = ctx.config.Fishing.SellCategory or "Sell All"
    local sellMode = ctx.config.Fishing.SellMode or "Count" -- "Count" | "Minute"
    local sellEveryMinutes = ctx.config.Fishing.SellEveryMinutes or 1
    local lastAutoSellAt = 0
    local castCooldown = ctx.config.Fishing.CooldownBetweenCasts or 1.0

    -- Runtime state
    local autoFishEnabled = false
    local autoSellFish = false
    local selectedRod = nil
    local protectedFish = {}
    local lockedSpot = nil
    local streakSaves = 0
    local catches = 0
    local isHolding = false
    local jumpBlocked = false

    -- Connections (created in Init, killed in Destroy)
    local reelTrackerConn = nil   -- Heartbeat deadzone tracker
    local streakWatchConn = nil   -- RenderStepped failsafe
    local antiAfkConn = nil

    -- UI handles
    local spotLabel = nil
    local protectedLabel = nil
    local statsLabel = nil
    local sellRateInput = nil

    -- Forward declarations (bodies assigned below, used by helper closures)
    local isProtected, countBag, sellFishAction

    ---------------------------------------------------------------------
    -- STATIC GAME REFERENCES (exact spec paths)
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

    local function getReelingGui()
        local pgui = lp:FindFirstChild("PlayerGui")
        return pgui and pgui:FindFirstChild("Reeling")
    end

    local function getMain()
        local reeling = getReelingGui()
        return reeling and reeling:FindFirstChild("MainFrame")
    end

    local function isReelingActive()
        local reeling = getReelingGui()
        return not not (reeling and reeling.Enabled and reeling:FindFirstChild("MainFrame"))
    end

    local function getBars()
        local main = getMain()
        local frame = main and main:FindFirstChild("Frame")
        if not frame then return nil, nil end
        return frame:FindFirstChild("WhiteBar"), frame:FindFirstChild("RedBar")
    end

    local function getProgressScale()
        local main = getMain()
        if not main then return nil end
        local bg = main:FindFirstChild("ProgressBg")
        if not bg then return nil end
        local progress = bg:FindFirstChild("ProgressBar")
        if not progress then return nil end
        return progress.Size.X.Scale
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
            task.wait(0.4)
        end
        return true
    end

    ---------------------------------------------------------------------
    -- JUMP GUARD (Jumping state disabled while Auto Fish runs)
    ---------------------------------------------------------------------
    local function applyJumpGuard(disableJump)
        local hum = getHumanoid()
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, not disableJump)
            end)
        end
        jumpBlocked = disableJump and true or false
    end

    ---------------------------------------------------------------------
    -- POSITION MANAGEMENT & AUTO-RETURN
    ---------------------------------------------------------------------
    local function saveCurrentPosition()
        local char = getCharacter()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            lockedSpot = hrp.CFrame
            return true
        end
        return false
    end

    local function returnToSavedPosition()
        if not lockedSpot then return end
        local char = getCharacter()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.CFrame = lockedSpot
            end)
        end
    end

    local function updateSpotLabel()
        if spotLabel then
            spotLabel.Text = "Spot: " .. (lockedSpot and "locked" or "not locked")
        end
    end

    local function updateStats()
        if statsLabel then
            statsLabel.Text = string.format(
                "Catches: %d | In bag: %d | Saves: %d",
                catches, countBag(), streakSaves
            )
        end
    end

    ---------------------------------------------------------------------
    -- NON-JUMPING BAR TRACKER (DirectMouseButton at screen center — no Space!)
    ---------------------------------------------------------------------
    local function updateHold(desired)
        desired = desired and true or false
        if desired == isHolding then return end
        isHolding = desired
        local cam = workspace.CurrentCamera
        if not cam then isHolding = false return end
        local pos = cam.ViewportSize
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(
                pos.X / 2, pos.Y / 2, 0, desired, game, 0
            )
        end)
    end

    -- Heartbeat: fine deadzone alignment, zero-lag bar tracking
    local function startReelTracker()
        if reelTrackerConn then return end
        reelTrackerConn = RunService.Heartbeat:Connect(function()
            if not autoFishEnabled or ctx.destroyed then
                if isHolding then updateHold(false) end
                return
            end
            if not isReelingActive() then
                if isHolding then updateHold(false) end
                return
            end
            local white, red = getBars()
            if not (white and red) then return end
            local diff = red.Position.X.Scale - white.Position.X.Scale
            if diff > 0.015 then
                updateHold(true)
            elseif diff < -0.015 then
                updateHold(false)
            end
        end)
    end

    ---------------------------------------------------------------------
    -- FAIL-SAFE STREAK PROTECTOR (RenderStepped ProgressBar monitor)
    ---------------------------------------------------------------------
    local function triggerStreakSave()
        updateHold(false)
        streakSaves += 1
        updateStats()
        ctx.log("Fishing: streak save #" .. streakSaves .. " (intercepted miss)", THEME.warn)
        -- Gracefully abort the catch without registering a miss
        local rodRemote = getRodRemote()
        if rodRemote then
            pcall(function()
                rodRemote:FireServer("Catch", "Err")
            end)
        end
        -- Force reset the reeling GUI
        local reeling = getReelingGui()
        if reeling then reeling.Enabled = false end
        task.wait(0.5)
        returnToSavedPosition()
    end

    local function startStreakWatcher()
        if streakWatchConn then return end
        streakWatchConn = RunService.RenderStepped:Connect(function()
            if ctx.destroyed then return end
            if not (autoFishEnabled and streakProtection) then return end
            if not isReelingActive() then return end
            local progress = getProgressScale()
            if progress and progress > 0 and progress <= streakThreshold then
                pcall(triggerStreakSave)
            end
        end)
    end

    ---------------------------------------------------------------------
    -- CAST + MASTER BOT LOOP
    ---------------------------------------------------------------------
    local function fishLoop()
        while autoFishEnabled and not ctx.destroyed do
            -- Auto-sell check first: either by bag count or by time interval.
            if autoSellFish then
                local shouldSell = false
                if sellMode == "Minute" then
                    shouldSell = (os.clock() - lastAutoSellAt) >= (sellEveryMinutes * 60)
                else
                    local currentFish = countBag()
                    if currentFish >= sellAtCount then
                        ctx.log("Fishing: threshold (" .. currentFish .. ") reached — selling...", THEME.warn)
                        shouldSell = true
                    end
                end
                if shouldSell then
                    pcall(sellFishAction)
                    lastAutoSellAt = os.clock()
                    task.wait(1)
                end
            end

            if not getCharacter() then
                task.wait(0.5)
                continue
            end

            if not equipRod() then
                ctx.log("Fishing: equip a fishing rod!", THEME.danger)
                task.wait(1.5)
                continue
            end

            if isReelingActive() then
                -- Let the Heartbeat tracker work the minigame
                while autoFishEnabled and not ctx.destroyed and isReelingActive() do
                    task.wait(0.05)
                end
                -- Instantly ensure holding is OFF (no lingering input)
                updateHold(false)
                catches += 1
                updateStats()
                task.wait(1.2)
            else
                -- Ensure no lingering hold between casts
                if isHolding then
                    updateHold(false)
                end
                local rodRemote = getRodRemote()
                if rodRemote then
                    pcall(function()
                        rodRemote:FireServer("Throw")
                    end)
                end
                local elapsed = 0
                while autoFishEnabled and not ctx.destroyed
                    and not isReelingActive() and elapsed < 25 do
                    task.wait(0.25)
                    elapsed += 0.25
                end
            end

            task.wait(castCooldown)
        end
        updateHold(false)
        if jumpBlocked then
            applyJumpGuard(false) -- restore jumping when Auto Fish stops
        end
        updateStats()
    end

    ---------------------------------------------------------------------
    -- SELLING (SellList buttons -> SellFishRemote("SellFish", name))
    ---------------------------------------------------------------------
    function isProtected(name)
        if type(name) ~= "string" then return false end
        local lower = name:lower()
        for _, protected in ipairs(protectedFish) do
            if type(protected) == "string" and protected:lower():find(lower, 1, true) then
                return true
            end
        end
        return false
    end

    function countBag()
        local count = 0
        local bp = lp:FindFirstChild("Backpack")
        local char = getCharacter()
        for _, container in ipairs({ bp, char }) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Tool") then
                        local lower = item.Name:lower()
                        if not lower:find("rod", 1, true) and not lower:find("pickaxe", 1, true) then
                            count += 1
                        end
                    end
                end
            end
        end
        return count
    end

    -- Same sell contract as crystals: invoke the remote with the category
    -- string. Only the remote name differs (SellFish vs SellCrystal).
    function sellFishAction(category)
        local remote = getSellFishRemote()
        if not remote then
            return false, "SellFish remote not found"
        end

        category = category or sellCategory or "Sell All"

        local ok, err = invokeSell(remote, "SellFish", category)
        if ok then
            ctx.log("Fish sold — " .. tostring(category), THEME.success)
            updateStats()
            return true
        end

        -- Fallback: per-fish sweep of the open sell list, protected fish skipped.
        local sold = 0
        local pgui = lp:FindFirstChild("PlayerGui")
        local sellGui = pgui and pgui:FindFirstChild("SellFish")
        local main = sellGui and sellGui:FindFirstChild("MainFrame")
        local sellList = main and main:FindFirstChild("SellList")

        if sellList then
            for _, btn in ipairs(sellList:GetChildren()) do
                if btn:IsA("ImageButton") then
                    local fishName = btn.Name
                    if not isProtected(fishName) then
                        if invokeSell(remote, "SellFish", fishName) then
                            sold += 1
                            task.wait(0.08)
                        end
                    end
                end
            end
        end

        if sold > 0 then
            ctx.log("Fish sold: " .. sold, THEME.success)
            updateStats()
            return true
        end
        return false, tostring(err or "nothing sold")
    end

    ---------------------------------------------------------------------
    -- PUBLIC CONTROLS
    ---------------------------------------------------------------------
    function Fishing.setEnabled(enabled)
        enabled = enabled and true or false
        if enabled == autoFishEnabled then return end
        autoFishEnabled = enabled
        if enabled then
            if not lockedSpot then
                saveCurrentPosition()
                updateSpotLabel()
            end
            applyJumpGuard(true) -- keep jump permanently disabled while fishing
            startReelTracker()
            startStreakWatcher()
            task.spawn(fishLoop)
            ctx.log("Fishing: Auto Fish ON", THEME.success)
        else
            autoFishEnabled = false
            updateHold(false) -- force release any active input
            applyJumpGuard(false)
            updateStats()
            ctx.log("Fishing: Auto Fish OFF", THEME.dim)
        end
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
        if enabled then
            lastAutoSellAt = os.clock()
            local rate = sellMode == "Minute"
                and (tostring(sellEveryMinutes) .. " min")
                or ("count " .. tostring(sellAtCount))
            ctx.log("Fishing: Auto Sell ON (per " .. rate .. ")", THEME.success)
        else
            ctx.log("Fishing: Auto Sell OFF", THEME.dim)
        end
    end

    function Fishing.setSellAtCount(count)
        sellAtCount = math.max(1, math.floor(tonumber(count) or 10))
    end

    function Fishing.setSellMode(mode)
        sellMode = (tostring(mode or ""):lower():find("minute", 1, true)) and "Minute" or "Count"
        ctx.config.Fishing.SellMode = sellMode
        lastAutoSellAt = os.clock()
        ctx.log("Fishing: auto sell mode — per " .. sellMode, THEME.dim)
    end

    function Fishing.getSellMode()
        return sellMode
    end

    -- Count mode: how many fish in the bag. Minute mode: how often to sell.
    function Fishing.setSellRate(value)
        local number = tonumber(value)
        if not number or number <= 0 then return false end
        if sellMode == "Minute" then
            sellEveryMinutes = math.max(0.1, number)
            ctx.config.Fishing.SellEveryMinutes = sellEveryMinutes
        else
            sellAtCount = math.max(1, math.floor(number))
            ctx.config.Fishing.SellAtCount = sellAtCount
        end
        lastAutoSellAt = os.clock()
        return true
    end

    function Fishing.getSellRate()
        return sellMode == "Minute" and sellEveryMinutes or sellAtCount
    end

    function Fishing.setSellCategory(category)
        sellCategory = tostring(category or "Sell All")
        ctx.config.Fishing.SellCategory = sellCategory
        ctx.log("Fish sell category: " .. sellCategory, THEME.dim)
    end

    function Fishing.getSellCategory()
        return sellCategory
    end

    function Fishing.setProtectedFish(list)
        if type(list) == "table" then protectedFish = list end
        if protectedLabel then
            protectedLabel.Text = "Protected: " .. (#protectedFish > 0 and table.concat(protectedFish, ", ") or "(none)")
        end
    end

    function Fishing.getProtectedFish()
        return protectedFish
    end

    function Fishing.toggleProtected(name)
        if isProtected(name) then
            local lower = name:lower()
            for i = #protectedFish, 1, -1 do
                if type(protectedFish[i]) == "string" and protectedFish[i]:lower():find(lower, 1, true) then
                    table.remove(protectedFish, i)
                    break
                end
            end
            ctx.log("Protected fish removed: " .. name, THEME.warn)
        else
            table.insert(protectedFish, name)
            ctx.log("Protected fish added: " .. name, THEME.success)
        end
        Fishing.setProtectedFish(protectedFish)
    end

    function Fishing.setLockedSpot(cf)
        lockedSpot = cf
        updateSpotLabel()
    end

    function Fishing.getLockedSpot()
        return lockedSpot
    end

    function Fishing.lockCurrentSpot()
        if saveCurrentPosition() then
            updateSpotLabel()
            ctx.log("Locked current fishing spot.", THEME.success)
            return true
        end
        return false
    end

    function Fishing.clearLockedSpot()
        lockedSpot = nil
        ctx.config.Fishing.LockedSpot = nil
        updateSpotLabel()
    end

    function Fishing.sellNow()
        return sellFishAction(sellCategory)
    end

    function Fishing.applySettings(data)
        if type(data) ~= "table" then return end
        if data.StreakProtection ~= nil then Fishing.setStreakProtection(data.StreakProtection) end
        if data.StreakThreshold then Fishing.setThreshold(data.StreakThreshold) end
        if data.SellAtCount then Fishing.setSellAtCount(data.SellAtCount) end
        if data.SellCategory then Fishing.setSellCategory(data.SellCategory) end
        if data.SellMode then Fishing.setSellMode(data.SellMode) end
        if data.SellEveryMinutes then sellEveryMinutes = math.max(0.1, tonumber(data.SellEveryMinutes) or 1) end
        if type(data.ProtectedFish) == "table" then
            protectedFish = data.ProtectedFish
            Fishing.setProtectedFish(protectedFish)
        end
        if data.LockedSpot ~= nil then
            lockedSpot = data.LockedSpot
            updateSpotLabel()
        end
        if data.AutoFish ~= nil then Fishing.setEnabled(data.AutoFish) end
        if data.AutoSellFish ~= nil then Fishing.setAutoSellFish(data.AutoSellFish) end
    end

    function Fishing.stopAll()
        autoFishEnabled = false
        autoSellFish = false
        updateHold(false)
        applyJumpGuard(false)
        updateStats()
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
        spotLabel = c.createSectionLabel(page.container, "Spot: not locked")

        c.createSectionLabel(page.container, "Protected Fish")
        local protectedInput = c.createTextbox(page.container, "Add/Remove", "Fish name + Enter")
        do
            local box = protectedInput.box
            if box then
                box.FocusLost:Connect(function(enterPressed)
                    if not enterPressed then return end
                    local name = box.Text
                    if name and name ~= "" then
                        Fishing.toggleProtected(name)
                        box.Text = ""
                        box:ReleaseFocus()
                    end
                end)
            end
        end
        c.createButton(page.container, "Clear Protected List", function()
            protectedFish = {}
            Fishing.setProtectedFish(protectedFish)
            ctx.log("Protected list cleared.", THEME.warn)
        end)
        protectedLabel = c.createSectionLabel(page.container, "Protected: (none)")

        c.createSectionLabel(page.container, "Selling")
        c.createButton(page.container, "Sell Fish Now", function()
            local ok, err = Fishing.sellNow()
            if not ok then
                ctx.log("Sell failed: " .. tostring(err), THEME.danger)
            end
        end)
        c.createDropdown(page.container, "Sell Category", ctx.config.Fishing.SellCategories or { "Sell All" }, 1, function(opt)
            Fishing.setSellCategory(opt)
        end)

        c.createSectionLabel(page.container, "Auto Sell")
        c.createToggle(page.container, "Auto Sell Fish", false, function(val)
            Fishing.setAutoSellFish(val)
        end)
        local function refreshSellRate()
            if not sellRateInput then return end
            if sellRateInput.text then
                sellRateInput.text(tostring(Fishing.getSellRate()))
            end
            local row = sellRateInput.container
            local lbl = row and row:FindFirstChildOfClass("TextLabel")
            if lbl then
                lbl.Text = (Fishing.getSellMode() == "Minute")
                    and "Sell Every (min)"
                    or "Sell Rate (count)"
            end
        end

        c.createDropdown(page.container, "Sell Mode", { "Per Count", "Per Minute" },
            (Fishing.getSellMode() == "Minute") and 2 or 1, function(opt)
                Fishing.setSellMode(opt)
                refreshSellRate()
            end)
        sellRateInput = c.createTextbox(page.container, "Sell Rate (count)", "10")
        if sellRateInput then
            sellRateInput.text(tostring(Fishing.getSellRate()))
            refreshSellRate()
            local box = sellRateInput.box
            if box then
                box.FocusLost:Connect(function(enterPressed)
                    if not enterPressed then return end
                    if Fishing.setSellRate(box.Text) then
                        refreshSellRate()
                    else
                        box.Text = tostring(Fishing.getSellRate())
                    end
                    box:ReleaseFocus()
                end)
            end
        end

        c.createSectionLabel(page.container, "Session Stats")
        statsLabel = c.createSectionLabel(page.container, "Catches: 0 | In bag: 0 | Saves: 0")
    end

    ---------------------------------------------------------------------
    -- RESPAWN HANDLER (re-apply jump guard + return to locked spot)
    ---------------------------------------------------------------------
    local function onCharacter(char)
        if ctx.destroyed then return end
        task.wait(0.5)
        if ctx.destroyed then return end
        if autoFishEnabled then
            applyJumpGuard(true)
        end
        if lockedSpot then
            local hrp = char and char:WaitForChild("HumanoidRootPart", 5)
            if hrp then
                pcall(function()
                    hrp.CFrame = lockedSpot
                end)
            end
        end
    end

    ---------------------------------------------------------------------
    -- LIFECYCLE
    ---------------------------------------------------------------------
    function Fishing.Init()
        buildUI()
        updateSpotLabel()
        Fishing.setProtectedFish(protectedFish)
        updateStats()

        -- Disable camera shake cutscene natively
        pcall(function()
            lp:SetAttribute("DisableFishingAnimation", true)
        end)

        -- Anti-AFK (VirtualUser) — stays alive for the whole session
        antiAfkConn = lp.Idled:Connect(function()
            pcall(function()
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)

        startReelTracker()
        startStreakWatcher()

        if ctx.addCharacterHandler then
            ctx.addCharacterHandler(onCharacter)
        end
        if ctx.config.Fishing.LockedSpot ~= nil then
            lockedSpot = ctx.config.Fishing.LockedSpot
            updateSpotLabel()
        end
    end

    function Fishing.Start() end

    function Fishing.Stop()
        Fishing.stopAll()
    end

    function Fishing.Destroy()
        Fishing.Stop()
        if reelTrackerConn then
            pcall(function() reelTrackerConn:Disconnect() end)
            reelTrackerConn = nil
        end
        if streakWatchConn then
            pcall(function() streakWatchConn:Disconnect() end)
            streakWatchConn = nil
        end
        if antiAfkConn then
            pcall(function() antiAfkConn:Disconnect() end)
            antiAfkConn = nil
        end
    end

    ctx.registerCleanup(function() Fishing.Destroy() end)

    return Fishing
end
