-- modules/antiafk.lua
-- Handles the game's own AFK system (separate from Roblox's platform-level
-- Idled event, which the existing "Anti Idle" toggle in Settings covers).
--
-- The game shows a "Still There?" prompt after ~30 min of inactivity, and
-- moves the player to a dedicated AFK server after ~2 hours.
--
-- Relevant remotes (ReplicatedStorage.GameRemoteEvents):
--   AFKCheckEvent           server -> client : the prompt is being shown
--   AFKCheckDecisionEvent   client -> server : our answer to that prompt
--   AFKReturnDecisionEvent  client -> server : decision when returning from AFK
--
-- Three layers of defence:
--   1. PREVENTION - periodic real input + tiny movement nudge so the game's
--                   idle timer keeps resetting and the prompt never fires.
--   2. REMOTE     - listen for AFKCheckEvent and immediately answer via
--                   AFKCheckDecisionEvent. Most reliable path.
--   3. GUI        - fallback that finds and clicks/closes the prompt window
--                   in case the remote signature changes.
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log
    local getHRP = ctx.getHRP
    local VIM = ctx.VIM
    local ReplicatedStorage = ctx.ReplicatedStorage

    ctx.antiAfkEnabled = ctx.antiAfkEnabled or false
    ctx.antiAfkConnections = ctx.antiAfkConnections or {}

    -- CONFIRMED from PlayerGui.HUD.AFKCheckController (decompiled):
    --   AFKCheckEvent.OnClientEvent passes ONE arg: seconds until the server
    --   deadline. Both the "I'M HERE" and "DISMISS" paths then call
    --   AFKCheckDecisionEvent:FireServer() with NO ARGUMENTS. Letting it time
    --   out only hides the UI and never fires, which is why you get moved.
    --
    --   So answering is simply: AFKCheckDecisionEvent:FireServer()
    --
    -- The prompt itself is rendered via PlayerGui.Confirmation (shared
    -- confirmation UI), NOT an AFK-named ScreenGui.

    -- Forward declaration: the remote handler (defined first) and the GUI
    -- layer (defined later) both need to call this.
    local scanForPrompt

    -- ── Resolve remotes ──
    local AFKCheckEvent, AFKCheckDecisionEvent, AFKReturnDecisionEvent
    task.spawn(function()
        local gre = ReplicatedStorage:WaitForChild("GameRemoteEvents", 15)
        if not gre then
            log("AntiAFK: GameRemoteEvents not found", THEME.danger)
            return
        end
        AFKCheckEvent = gre:FindFirstChild("AFKCheckEvent")
        AFKCheckDecisionEvent = gre:FindFirstChild("AFKCheckDecisionEvent")
        AFKReturnDecisionEvent = gre:FindFirstChild("AFKReturnDecisionEvent")

        -- ── Layer 2: answer the AFK check the moment it's raised ──
        if AFKCheckEvent and AFKCheckEvent:IsA("RemoteEvent") then
            local conn = AFKCheckEvent.OnClientEvent:Connect(function(deadlineSeconds)
                if not ctx.antiAfkEnabled then return end
                log("AntiAFK: AFK check received (deadline "
                    .. tostring(deadlineSeconds) .. "s), auto-answering", THEME.warn)

                -- Answer immediately — no arguments, matching the game's own
                -- AFKCheckController behaviour.
                if AFKCheckDecisionEvent and AFKCheckDecisionEvent:IsA("RemoteEvent") then
                    pcall(function()
                        AFKCheckDecisionEvent:FireServer()
                    end)
                end

                -- Belt-and-braces: hide the confirmation UI if it appeared.
                task.wait(0.3)
                scanForPrompt()
            end)
            table.insert(ctx.antiAfkConnections, conn)
            log("AntiAFK: Hooked AFKCheckEvent", THEME.dim)
        else
            log("AntiAFK: AFKCheckEvent missing, relying on GUI fallback", THEME.warn)
        end

        -- AFKReturnDecisionEvent may also be fired server -> client to offer
        -- a "return to game?" choice while parked on the AFK server. If so,
        -- answer it immediately.
        if AFKReturnDecisionEvent and AFKReturnDecisionEvent:IsA("RemoteEvent") then
            local returnConn = AFKReturnDecisionEvent.OnClientEvent:Connect(function(...)
                if not ctx.antiAfkEnabled then return end
                log("AntiAFK: Return prompt received, requesting return", THEME.warn)
                pcall(function()
                    AFKReturnDecisionEvent:FireServer(true)
                end)
            end)
            table.insert(ctx.antiAfkConnections, returnConn)
        end
    end)

    -- Answers the AFK check proactively (also usable if we detect the prompt
    -- through the GUI layer rather than the remote).
    local function sendStayDecision()
        if AFKCheckDecisionEvent and AFKCheckDecisionEvent:IsA("RemoteEvent") then
            pcall(function()
                AFKCheckDecisionEvent:FireServer()
            end)
            return true
        end
        return false
    end
    ctx.sendAfkStayDecision = sendStayDecision

    -- If we ever end up on the AFK server, this is how we signal a return.
    local function sendReturnDecision()
        if AFKReturnDecisionEvent and AFKReturnDecisionEvent:IsA("RemoteEvent") then
            pcall(function()
                AFKReturnDecisionEvent:FireServer(true)
            end)
            return true
        end
        return false
    end
    ctx.sendAfkReturnDecision = sendReturnDecision

    -- ── AFK server detection + auto-return ──
    -- The AFK server uses its own dedicated map, so the normal world folders
    -- (workspace.Main, with FishingZone / ActiveMiningStones inside) won't be
    -- present there. If we detect that state, request a return so a parked
    -- bot recovers on its own instead of idling on the AFK map forever.
    local function looksLikeAfkServer()
        local main = workspace:FindFirstChild("Main")
        if not main then return true end
        local hasFishing = main:FindFirstChild("FishingZone") ~= nil
        local hasMining = main:FindFirstChild("ActiveMiningStones") ~= nil
        return not hasFishing and not hasMining
    end

    local lastReturnAttempt = 0
    local RETURN_RETRY_INTERVAL = 30

    local function tryReturnFromAfkServer()
        if not looksLikeAfkServer() then return end
        if (tick() - lastReturnAttempt) < RETURN_RETRY_INTERVAL then return end
        lastReturnAttempt = tick()
        log("AntiAFK: Detected AFK server, requesting return", THEME.warn)
        sendReturnDecision()
    end

    -- ── Layer 3: GUI fallback ──
    -- The AFK prompt reuses the shared PlayerGui.Confirmation UI. We only
    -- act on it if its text matches the AFK wording, so we never dismiss an
    -- unrelated confirmation (e.g. the ore sell confirmation).
    local AFK_PROMPT_TEXT = "still there"

    local function matchesAny(text, patterns)
        local lower = string.lower(tostring(text or ""))
        for _, pattern in ipairs(patterns) do
            if string.find(lower, pattern, 1, true) then
                return true
            end
        end
        return false
    end

    -- True only if this Confirmation UI is showing the AFK check specifically.
    local function isAfkConfirmation(container)
        for _, desc in ipairs(container:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                if string.find(string.lower(tostring(desc.Text or "")), AFK_PROMPT_TEXT, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    local function clickGuiButton(button)
        local ok = pcall(function()
            local pos = button.AbsolutePosition
            local size = button.AbsoluteSize
            VIM:SendMouseButtonEvent(pos.X + size.X / 2, pos.Y + size.Y / 2, 0, true, game, 0)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(pos.X + size.X / 2, pos.Y + size.Y / 2, 0, false, game, 0)
        end)
        if not ok and firesignal then
            pcall(function() firesignal(button.MouseButton1Click) end)
        end
    end

    -- Buttons are looked up in priority order so we deterministically pick
    -- "I'M HERE" over "DISMISS" (GetDescendants order isn't guaranteed).
    -- Both satisfy the server, but the affirmative one is the correct intent.
    local BUTTON_PRIORITY = {
        { "i'm here", "im here", "still here" }, -- affirmative
        { "dismiss" },                            -- cancel (also valid)
        { "close" },                              -- X button
    }

    local function findConfirmButton(container)
        local buttons = {}
        for _, desc in ipairs(container:GetDescendants()) do
            if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
                table.insert(buttons, desc)
            end
        end

        for _, patternGroup in ipairs(BUTTON_PRIORITY) do
            for _, button in ipairs(buttons) do
                if button:IsA("TextButton") and matchesAny(button.Text, patternGroup) then
                    return button
                end
            end
        end

        -- Nothing matched by label — fall back to the first visible button.
        return buttons[1]
    end

            -- Assigned to the forward-declared local above so both the remote
    -- handler and the GUI watcher can call it.
    scanForPrompt = function()
        local playerGui = lp:FindFirstChild("PlayerGui")
        if not playerGui then return end

        local confirmation = playerGui:FindFirstChild("Confirmation")
        if not confirmation or not confirmation:IsA("ScreenGui") then return end
        if not confirmation.Enabled then return end

        -- Only touch it if it's actually the AFK prompt.
        if not isAfkConfirmation(confirmation) then return end

        log("AntiAFK: AFK confirmation UI detected, answering", THEME.warn)

        -- Answer the server first (this is what actually matters).
        sendStayDecision()

        -- Then click the button so the game's own UI tears itself down
        -- cleanly, rather than us destroying a shared GUI it still owns.
        local button = findConfirmButton(confirmation)
        if button then
            clickGuiButton(button)
        end
    end

    local promptWatcherConn = nil
    local function startPromptWatcher()
        if promptWatcherConn then return end
        local playerGui = lp:FindFirstChild("PlayerGui")
        if not playerGui then return end
        -- The Confirmation ScreenGui is long-lived and simply toggled via
        -- .Enabled rather than being re-created, so watch that instead of
        -- ChildAdded.
        local confirmation = playerGui:FindFirstChild("Confirmation")
        if confirmation then
            promptWatcherConn = confirmation:GetPropertyChangedSignal("Enabled"):Connect(function()
                if not ctx.antiAfkEnabled then return end
                if not confirmation.Enabled then return end
                task.wait(0.2)
                scanForPrompt()
            end)
        else
            -- Not created yet — fall back to catching it when it appears.
            promptWatcherConn = playerGui.ChildAdded:Connect(function(child)
                if not ctx.antiAfkEnabled then return end
                if child.Name ~= "Confirmation" then return end
                task.wait(0.2)
                scanForPrompt()
            end)
        end
        table.insert(ctx.antiAfkConnections, promptWatcherConn)
    end

    -- ── Layer 1: keep the idle timer from ever reaching the threshold ──
    local NUDGE_INTERVAL = 120 -- every 2 min, well under the 30 min threshold

    local function generateActivity()
        pcall(function()
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)

                -- Some games track movement rather than raw input. Skipped while a
        -- mine/fish attempt is mid-flight so it can't disturb one.
        --
        -- We nudge via Humanoid:MoveTo rather than writing HRP.CFrame directly:
        -- setting CFrame on a character with an active Humanoid fights the
        -- character controller and can cause visible jitter / rubber-banding.
        -- MoveTo asks the controller to walk a tiny step, which the game's
        -- movement-based idle detection still registers.
        if not ctx.autoFishEnabled and not ctx.autoMineEnabled then
            pcall(function()
                local char = lp.Character
                local hrp = getHRP(char)
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and humanoid then
                    local target = hrp.Position + Vector3.new(0, 0, 0.5)
                    humanoid:MoveTo(target)
                    task.wait(0.15)
                    humanoid:MoveTo(hrp.Position) -- settle back
                end
            end)
        end
    end

    local antiAfkLoopRunning = false
    local function startAntiAfkLoop()
        if antiAfkLoopRunning then return end
        antiAfkLoopRunning = true
        task.spawn(function()
            while ctx.antiAfkEnabled and not ctx.destroyed do
                generateActivity()
                scanForPrompt()            -- sweep in case a prompt slipped through
                tryReturnFromAfkServer()   -- recover if we got parked on the AFK map
                task.wait(NUDGE_INTERVAL)
            end
            antiAfkLoopRunning = false
        end)
    end

    -- ── Toggle ──
    local function updateAntiAfkBtnUI()
        if not gui.Settings.AntiAfkBtn then return end
        if ctx.antiAfkEnabled then
            gui.Settings.AntiAfkBtn.Text = "Anti AFK: ON"
            gui.Settings.AntiAfkBtn.BackgroundColor3 = THEME.success
        else
            gui.Settings.AntiAfkBtn.Text = "Anti AFK: OFF"
            gui.Settings.AntiAfkBtn.BackgroundColor3 = THEME.warn
        end
    end
    ctx.updateAntiAfkBtnUI = updateAntiAfkBtnUI

    -- Set Anti AFK to an explicit state (idempotent). Shared by the button and
    -- by saved-profile restoration (ctx.setAntiAfk).
    local function setAntiAfk(on)
        on = on and true or false
        if ctx.antiAfkEnabled == on then return end
        ctx.antiAfkEnabled = on
        updateAntiAfkBtnUI()
        log("AntiAFK: " .. (on and "ON" or "OFF"), on and THEME.success or THEME.dim)
        if on then
            startPromptWatcher()
            startAntiAfkLoop()
        end
    end
    ctx.setAntiAfk = setAntiAfk

    if gui.Settings.AntiAfkBtn then
        bind(gui.Settings.AntiAfkBtn.MouseButton1Click, function()
            setAntiAfk(not ctx.antiAfkEnabled)
        end)
    end

    updateAntiAfkBtnUI()

    -- Restore from saved settings
    if ctx.antiAfkEnabled then
        startPromptWatcher()
        startAntiAfkLoop()
    end
end
