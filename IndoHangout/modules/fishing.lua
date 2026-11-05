-- IndoHangout/modules/fishing.lua
-- Auto Fish: equip rod -> cast with RodRemote:FireServer("Throw") -> track the
-- Reeling GUI (MainFrame.Frame.WhiteBar / RedBar / ProgressBg.ProgressBar) with
-- RunService.Heartbeat -> hold/release input via VirtualInputManager.
-- Streak protection releases the hold and fires RodRemote("Catch", "Err") when
-- progress dips to/below the threshold, counting it as a save (never a miss).
-- Auto Sell Fish uses the shared sell routine (same invoke pattern as crystal
-- selling, different remote), never sells protected fish.
-- Jumping is blocked while Auto Fish is active and restored on disable.

return function(ctx)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
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
    local sellDelay = ctx.config.Fishing.SellDelay or 0.6
    local castCooldown = ctx.config.Fishing.CooldownBetweenCasts or 1.0

    -- Runtime state
    local autoFishEnabled = false
    local autoSellFish = false
    local selectedRod = nil
    local protectedFish = {}
    local lockedSpot = nil
    local streakSaves = 0
    local reelConnection = nil
    local jumpBlocked = false

    -- UI handles (populated in buildUI)
    local spotLabel = nil
    local protectedLabel = nil
    local statsLabel = nil

    local function isProtected(name)
        if type(name) ~= "string" then return false end
        local lower = name:lower()
        for _, protected in ipairs(protectedFish) do
            if type(protected) == "string" and protected:lower():find(lower, 1, true) then
                return true
            end
        end
        return false
    end

    ---------------------------------------------------------------------
    -- REMOTE LOOKUP (exact spec paths)
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
    -- JUMP BLOCKING (restore on disable/stop)
    ---------------------------------------------------------------------
    local function setJumpBlocked(blocked)
        local enabled = not blocked
        local hum = getHumanoid()
        if hum then
            pcall(function()
                hum.Jump = false
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, enabled)
            end)
        end
        jumpBlocked = blocked and true or false
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

    local function updateSpotLabel()
        if spotLabel then
            spotLabel.Text = "Spot: " .. (lockedSpot and "locked" or "not locked")
        end
    end

    ---------------------------------------------------------------------
    -- REELING GUI TRACKING (exact spec paths)
    ---------------------------------------------------------------------
    local function getReelingParts()
        local playerGui = lp:FindFirstChild("PlayerGui")
        if not playerGui then return nil, nil, nil end
        local reeling = playerGui:FindFirstChild("Reeling")
        if not reeling then return nil, nil, nil end
        local mainFrame = reeling:FindFirstChild("MainFrame")
        if not mainFrame then return nil, nil, nil end
        if not mainFrame.Visible then return nil, nil, nil end
        local frame = mainFrame:FindFirstChild("Frame")
        if not frame then return nil, nil, nil end
        return frame:FindFirstChild("WhiteBar"), frame:FindFirstChild("RedBar"),
            frame:FindFirstChild("ProgressBg") and frame.ProgressBg:FindFirstChild("ProgressBar")
    end

    local function isReelingVisible()
        local white, red, progress = getReelingParts()
        return (white or red or progress) ~= nil
    end

    local function getProgressScale()
        local _, _, progress = getReelingParts()
        if progress and progress:IsA("GuiObject") then
            return progress.Size.X.Scale
        end
        return nil
    end

    ---------------------------------------------------------------------
    -- HOLD / RELEASE (VirtualInputManager, tracked by core for cleanup)
    ---------------------------------------------------------------------
    local function setHold(holding)
        ctx.pressVirtualButton(0, holding and true or false)
    end

    ---------------------------------------------------------------------
    -- REEL SESSION (Heartbeat-driven)
    ---------------------------------------------------------------------
    local function reelSession()
        local deadline = os.clock() + 45
        local function finish()
            if reelConnection then
                pcall(function() reelConnection:Disconnect() end)
                reelConnection = nil
            end
            setHold(false) -- release input immediately when reeling ends
        end

        reelConnection = RunService.Heartbeat:Connect(function()
            if not autoFishEnabled or ctx.destroyed then
                finish()
                return
            end
            if not isReelingVisible() or os.clock() > deadline then
                finish()
                return
            end

            local progress = getProgressScale()
            local saving = false
            if streakProtection and progress and progress <= streakThreshold then
                -- Streak protection: stop holding, graceful catch, no miss.
                setHold(false)
                local rodRemote = getRodRemote()
                pcall(function()
                    rodRemote:FireServer("Catch", "Err")
                end)
                streakSaves += 1
                saving = true
                if statsLabel then
                    statsLabel.Text = "Streak saves: " .. streakSaves
                end
                ctx.log("Streak protection: saved streak #" .. streakSaves, THEME.warn)
            end
            if not saving then
                setHold(true)
            end
        end)
    end

    ---------------------------------------------------------------------
    -- CAST + AUTO FISH LOOP
    ---------------------------------------------------------------------
    local function cast()
        local rodRemote = getRodRemote()
        if not rodRemote then
            ctx.log("Fishing: Rod remote not found", THEME.danger)
            return false
        end
        if not equipRod() then
            ctx.log("Fishing: no rod found", THEME.warn)
            return false
        end
        task.wait(0.15)
        local ok = pcall(function()
            rodRemote:FireServer("Throw")
        end)
        return ok
    end

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
                    reelSession()
                end
            end

            task.wait(castCooldown)
        end
        setHold(false)
        if jumpBlocked then
            setJumpBlocked(false) -- restore jumping
        end
    end

    ---------------------------------------------------------------------
    -- SELLING (shared routine: differs from crystals only by remote)
    ---------------------------------------------------------------------
    local function listFishTools()
        local fish = {}
        local containers = {}
        local backpack = lp:FindFirstChild("Backpack")
        if backpack then table.insert(containers, backpack) end
        local char = getCharacter()
        if char then table.insert(containers, char) end
        for _, container in ipairs(containers) do
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then
                    local lower = child.Name:lower()
                    -- Exclude rods and pickaxes per spec
                    if not lower:find("rod", 1, true) and not lower:find("pickaxe", 1, true) then
                        table.insert(fish, child)
                    end
                end
            end
        end
        return fish
    end

    local function countFish()
        return #listFishTools()
    end

    local function sellFish()
        local remote = getSellFishRemote()
        if not remote then return false, "SellFish remote not found" end

        -- Wait briefly for the SellFish GUI (spec path) before selling
        local playerGui = lp:FindFirstChild("PlayerGui")
        local sellGui = playerGui and playerGui:FindFirstChild("SellFish")
        if sellGui then
            task.wait(0.2)
        end

        local fish = listFishTools()
        local sold = 0
        local failed = 0
        for _, tool in ipairs(fish) do
            if not isProtected(tool.Name) then
                local ok = invokeSell(remote, "SellFish", tool.Name)
                if ok then
                    sold += 1
                    task.wait(sellDelay)
                else
                    failed += 1
                end
            end
        end

        -- Fallback per spec: bulk sell when individual selling is unavailable
        if sold == 0 and failed == #fish then
            local ok = invokeSell(remote, "SellFish", "Sell this fish")
            if ok then
                sold = 1
                failed = 0
            end
        end

        if sold > 0 then
            ctx.log("Fish sold: " .. sold .. (failed > 0 and (" (failed: " .. failed .. ")") or ""), THEME.success)
            return true
        end
        return false, "nothing sold" .. (failed > 0 and (" — " .. failed .. " sell(s) failed") or "")
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
    end

    ---------------------------------------------------------------------
    -- PUBLIC CONTROLS
    ---------------------------------------------------------------------
    function Fishing.setEnabled(enabled)
        enabled = enabled and true or false
        autoFishEnabled = enabled
        if enabled then
            setJumpBlocked(true) -- prevent jumping while Auto Fish runs
            task.spawn(fishLoop)
            ctx.log("Fishing: Auto Fish ON", THEME.success)
        else
            autoFishEnabled = false
            setHold(false) -- release input immediately
            setJumpBlocked(false) -- restore jumping
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
            task.spawn(sellLoop)
            ctx.log("Fishing: Auto Sell ON (at " .. tostring(sellAtCount) .. ")", THEME.success)
        else
            ctx.log("Fishing: Auto Sell OFF", THEME.dim)
        end
    end

    function Fishing.setSellAtCount(count)
        sellAtCount = math.max(1, math.floor(tonumber(count) or 10))
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
        local char = getCharacter()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            lockedSpot = hrp.CFrame
            ctx.config.Fishing.LockedSpot = lockedSpot
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
        return sellFish()
    end

    function Fishing.applySettings(data)
        if type(data) ~= "table" then return end
        if data.StreakProtection ~= nil then Fishing.setStreakProtection(data.StreakProtection) end
        if data.StreakThreshold then Fishing.setThreshold(data.StreakThreshold) end
        if data.SellAtCount then Fishing.setSellAtCount(data.SellAtCount) end
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
        if reelConnection then
            pcall(function() reelConnection:Disconnect() end)
            reelConnection = nil
        end
        setHold(false)
        setJumpBlocked(false)
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

        c.createSectionLabel(page.container, "Session Stats")
        statsLabel = c.createSectionLabel(page.container, "Streak saves: 0")
    end

    ---------------------------------------------------------------------
    -- RESPAWN HANDLER (re-apply jump block + locked spot while enabled)
    ---------------------------------------------------------------------
    local function onCharacter(char)
        if not autoFishEnabled or ctx.destroyed then return end
        task.wait(0.5)
        if not autoFishEnabled or ctx.destroyed then return end
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and jumpBlocked then
            pcall(function()
                hum.Jump = false
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end)
        end
    end

    ---------------------------------------------------------------------
    -- LIFECYCLE
    ---------------------------------------------------------------------
    function Fishing.Init()
        buildUI()
        updateSpotLabel()
        Fishing.setProtectedFish(protectedFish)
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
    end

    ctx.registerCleanup(function() Fishing.Stop() end)

    return Fishing
end
