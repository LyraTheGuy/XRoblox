-- modules/fishing.lua
-- Auto Fish System (animation-based, d8nte engine)
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log
    local getHRP = ctx.getHRP
    local VIM = ctx.VIM
    local webhookFishCaught = ctx.webhookFishCaught
    local updatePerfMonitor = ctx.updatePerfMonitor

    local autoFishCasts = 0
    local autoFishCaught = 0
    local autoFishTimeouts = 0
    local autoFishStage = "Idle"
    local activeAnimConn = nil
    local fishSessionStart = 0
    local FISH_BREAK_INTERVAL = 3600 -- 60 min
    local FISH_BREAK_DURATION = 300 -- 5 min pause

    -- Timing config
    local AF_PRE_CAST_DELAY = 0.3
    local AF_CAST_HOLD_MIN = 0.4
    local AF_CAST_HOLD_MAX = 0.6
    local AF_VERIFY_CAST_TIMEOUT = 2.5
    local AF_BAIT_LANDED_TIMEOUT = 30
    local AF_MINIGAME_TIMEOUT = 30
    local AF_POST_END_DELAY = 0.3

    -- Animation IDs (IndoVoice fishing game)
    local FISHING_ANIM_ID = "rbxassetid://107858786510758"

    local function getRod()
        local char = lp.Character
        if not char then return nil end
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and (tool:FindFirstChild("Cast") or tool:FindFirstChild("CatchEvent") or string.find(string.lower(tool.Name), "rod")) then
                return tool
            end
        end
        return nil
    end

    local function getRodFromBackpack()
        local backpack = lp:FindFirstChildOfClass("Backpack")
        if not backpack then return nil end
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool:FindFirstChild("Cast") or tool:FindFirstChild("CatchEvent") or string.find(string.lower(tool.Name), "rod")) then
                return tool
            end
        end
        return nil
    end

    local function equipRod()
        local char = lp.Character
        if not char then return false end
        if getRod() then return true end
        local rod = getRodFromBackpack()
        if rod then
            rod.Parent = char
            log("AutoFish: Equipped " .. rod.Name, THEME.dim)
            task.wait(0.3)
            return true
        end
        return false
    end

    local function reequipRod()
        local char = lp.Character
        if not char then return end
        local current = getRod()
        if current then
            local backpack = lp:FindFirstChildOfClass("Backpack")
            if backpack then
                current.Parent = backpack
            end
        end
        task.wait(0.3)
        equipRod()
    end

    local function afSetStage(stage)
        autoFishStage = stage
        gui.AutoFish.Status.Text = "Status: " .. stage
    end

    local function afTimeout(reason)
        autoFishTimeouts = autoFishTimeouts + 1
        log("AutoFish: Timeout [" .. reason .. "] #" .. autoFishTimeouts, THEME.warn)

        if activeAnimConn then
            activeAnimConn:Disconnect()
            activeAnimConn = nil
        end

        pcall(function()
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)

        afSetStage("Re-equipping...")
        task.spawn(reequipRod)
        task.wait(0.5)
    end

    local function autoFishLoop()
        log("AutoFish: Engine started", THEME.success)
        gui.AutoFish.Status.TextColor3 = THEME.success
        fishSessionStart = tick()

        while ctx.autoFishEnabled and not ctx.destroyed do
            local char = lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not char or not hum then
                afSetStage("No character")
                task.wait(1)
                continue
            end

            if hum.MoveDirection.Magnitude > 0.1 then
                afSetStage("Moving... waiting")
                task.wait(0.2)
                continue
            end

            if not getRod() then
                afSetStage("Equipping rod...")
                if not equipRod() then
                    afSetStage("No rod found!")
                    gui.AutoFish.Status.TextColor3 = THEME.danger
                    log("AutoFish: No rod in character or backpack", THEME.danger)
                    task.wait(2)
                    continue
                end
            end

            -- PRE-CAST DELAY
            afSetStage("Pre-cast...")
            task.wait(AF_PRE_CAST_DELAY)
            if not ctx.autoFishEnabled or ctx.destroyed then break end
            if hum.MoveDirection.Magnitude > 0.1 then continue end

            -- CASTING (hold mouse) — fixed position (0,0) is reliable; a
            -- randomized offset was tried here but could intermittently land
            -- on the hub GUI panel and silently eat the click.
            afSetStage("Casting...")
            pcall(function()
                VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            end)

            local holdDuration = AF_CAST_HOLD_MIN + math.random() * (AF_CAST_HOLD_MAX - AF_CAST_HOLD_MIN)
            local holdElapsed = 0
            while holdElapsed < holdDuration and ctx.autoFishEnabled do
                task.wait(0.05)
                holdElapsed = holdElapsed + 0.05
            end

            pcall(function()
                VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)

            if not ctx.autoFishEnabled or ctx.destroyed then break end

            -- VERIFY CAST (detect fishing animation)
            afSetStage("Verify Cast...")
            local castVerified = false

            activeAnimConn = hum.AnimationPlayed:Connect(function(track)
                if track.Animation and track.Animation.AnimationId == FISHING_ANIM_ID then
                    castVerified = true
                    if activeAnimConn then activeAnimConn:Disconnect(); activeAnimConn = nil end
                end
            end)

            local verifyStart = tick()
            while not castVerified and (tick() - verifyStart) < AF_VERIFY_CAST_TIMEOUT and ctx.autoFishEnabled do
                task.wait(0.05)
            end

            if activeAnimConn then activeAnimConn:Disconnect(); activeAnimConn = nil end

            if not ctx.autoFishEnabled or ctx.destroyed then break end

            if not castVerified then
                afTimeout("Verify Cast")
                continue
            end

            autoFishCasts = autoFishCasts + 1

            -- WAITING FOR STARTMINIGAME (fish bite + fish info)
            afSetStage("Waiting for bite...")
            local minigameStarted = false
            local caughtFishData = nil
            local minigameConn = nil

            local rod2 = getRod()
            local startMinigame = rod2 and rod2:FindFirstChild("StartMinigame")

            if startMinigame and startMinigame:IsA("RemoteEvent") then
                minigameConn = startMinigame.OnClientEvent:Connect(function(baitPart, fishInfo, luckData)
                    minigameStarted = true
                    if fishInfo and type(fishInfo) == "table" then
                        caughtFishData = fishInfo
                    end
                end)
            else
                log("AutoFish: StartMinigame remote not found", THEME.warn)
            end

            local biteStart = tick()
            while not minigameStarted and (tick() - biteStart) < AF_BAIT_LANDED_TIMEOUT and ctx.autoFishEnabled do
                task.wait(0.1)
            end

            if minigameConn then minigameConn:Disconnect() end

            if not ctx.autoFishEnabled or ctx.destroyed then break end

            if not minigameStarted then
                afTimeout("Waiting Bite")
                continue
            end

            -- WAIT FOR MINIGAME GUI
            afSetStage("Fish on! Detecting minigame...")
            local playerGui = lp:FindFirstChild("PlayerGui")
            local minigameGui = nil
            local waitStart = tick()

            while not minigameGui and (tick() - waitStart) < 3 and ctx.autoFishEnabled do
                if playerGui then
                    for _, g in pairs(playerGui:GetChildren()) do
                        if g:IsA("ScreenGui") and g:FindFirstChild("FishingHolder", true) then
                            minigameGui = g
                            break
                        end
                    end
                end
                task.wait(0.1)
            end

            if not ctx.autoFishEnabled or ctx.destroyed then break end

            if not minigameGui then
                log("AutoFish: No minigame GUI detected", THEME.warn)
                afTimeout("No Minigame GUI")
                continue
            end

            -- SKIP MINIGAME (random 5-10s delay then catch)
            afSetStage("Minigame active, waiting to catch...")
            local skipDelay = 5 + math.random() * 5
            task.wait(skipDelay)

            if not ctx.autoFishEnabled or ctx.destroyed then break end

            -- CATCH
            afSetStage("Catching!")
            local rod3 = getRod()
            local catchRemote = rod3 and (rod3:FindFirstChild("CatchEvent") or rod3:FindFirstChild("Catch"))

            if catchRemote then
                pcall(function()
                    catchRemote:FireServer(true)
                end)
                autoFishCaught = autoFishCaught + 1

                local fishName = caughtFishData and caughtFishData.FishName or "Unknown"
                local fishRarity = caughtFishData and caughtFishData.Rarity or "?"
                local fishWeight = caughtFishData and caughtFishData.Weight or nil
                local fishPrice = caughtFishData and caughtFishData.Price or nil

                gui.AutoFish.LastCatch.Text = "Last: " .. fishName .. " [" .. fishRarity .. "]"
                log("AutoFish: Caught " .. fishName .. " (" .. fishRarity .. ")", THEME.success)

                ctx.perfRarityCounts[fishRarity] = (ctx.perfRarityCounts[fishRarity] or 0) + 1
                if fishPrice and tonumber(fishPrice) then
                    ctx.perfTotalEarnings = ctx.perfTotalEarnings + tonumber(fishPrice)
                end

                webhookFishCaught(fishName, fishRarity, fishWeight, fishPrice)
                updatePerfMonitor()
            else
                log("AutoFish: CatchEvent remote not found", THEME.danger)
                afTimeout("Catch")
                continue
            end

            -- END: clean up any leftover fishing UI
            afSetStage("Cleaning up...")
            pcall(function()
                local playerGui2 = lp:FindFirstChild("PlayerGui")
                if playerGui2 then
                    for _, g in pairs(playerGui2:GetChildren()) do
                        if g:IsA("ScreenGui") and g:FindFirstChild("FishingHolder", true) then
                            g:Destroy()
                            break
                        end
                    end
                end
            end)

            -- POST-END DELAY
            afSetStage("Resetting...")
            task.wait(AF_POST_END_DELAY)

            -- Break system: every 60 min, pause 5 min (mirrors the mining
            -- engine) to avoid being flagged for continuous long sessions.
            if (tick() - fishSessionStart) >= FISH_BREAK_INTERVAL then
                afSetStage("Taking break (5 min)...")
                log("AutoFish: 60 min reached, pausing 5 min", THEME.warn)
                task.wait(FISH_BREAK_DURATION)
                fishSessionStart = tick()
                log("AutoFish: Break over, resuming", THEME.success)
            end
        end

        afSetStage("Idle")
        gui.AutoFish.Status.TextColor3 = THEME.dim
        log("AutoFish: Stopped", THEME.dim)

        pcall(function()
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
    end

    bind(gui.AutoFish.ToggleBtn.MouseButton1Click, function()
        ctx.autoFishEnabled = not ctx.autoFishEnabled
        if ctx.autoFishEnabled then
            gui.AutoFish.ToggleBtn.Text = "Auto Fish: ON"
            gui.AutoFish.ToggleBtn.BackgroundColor3 = THEME.success
            task.spawn(autoFishLoop)
        else
            gui.AutoFish.ToggleBtn.Text = "Auto Fish: OFF"
            gui.AutoFish.ToggleBtn.BackgroundColor3 = THEME.accent
            pcall(function()
                VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
            if activeAnimConn then
                activeAnimConn:Disconnect()
                activeAnimConn = nil
            end
        end
        if gui.Toast and gui.Toast.show then
            local msg = ctx.autoFishEnabled and "Auto Fish started" or "Auto Fish stopped"
            gui.Toast.show({Text = msg, Variant = ctx.autoFishEnabled and "success" or "info", Duration = 1.5})
        end
    end)
end
