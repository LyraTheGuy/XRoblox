-- modules/ui.lua
-- All remaining UI bindings, heartbeat loop, startup
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log
    local getHRP = ctx.getHRP
    local Players = ctx.Players
    local UserInputService = ctx.UserInputService
    local RunService = ctx.RunService
    local VIM = ctx.VIM
    local useVIM = ctx.useVIM
    local mouse = ctx.mouse
    local isActiveZone = ctx.isActiveZone
    local isInsideAnyActiveZone = ctx.isInsideAnyActiveZone
    local getZoneParts = ctx.getZoneParts
    local getActiveZoneParts = ctx.getActiveZoneParts
    local nearestActiveZonePart = ctx.nearestActiveZonePart
    local moveToNearestActiveZone = ctx.moveToNearestActiveZone
    local tpToZone = ctx.tpToZone
    local refreshZoneESP = ctx.refreshZoneESP
    local unfreezeCharacter = ctx.unfreezeCharacter
    local updateClickerUI = ctx.updateClickerUI
    local updateRewardButtons = ctx.updateRewardButtons
    local applyTheme = ctx.applyTheme
    local switchTab = ctx.switchTab
    local toggleClicker = ctx.toggleClicker
    local resolvePosition = ctx.resolvePosition
    local silentClick = ctx.silentClick
    local beginDrag = ctx.beginDrag
    local destroyAll = ctx.destroyAll
    local refreshCharacterAdonis = ctx.refreshCharacterAdonis
    local startAutoTP = ctx.startAutoTP
    local stopAutoTP = ctx.stopAutoTP
    local updatePerfMonitor = ctx.updatePerfMonitor

    -- Player rows and targeting are owned by modules/adminmenu.lua
    -- (the Player Admin Menu). Nothing to wire here anymore.

    -- Set FishZone ESP to an explicit state (idempotent).
    local function setZoneESP(on)
        on = on and true or false
        if ctx.zoneESPOn == on then return end
        ctx.zoneESPOn = on
        gui.FishZone.ZoneESPBtn.Text = on and "FishZone ESP: ON" or "FishZone ESP: OFF"
        gui.FishZone.ZoneESPBtn.BackgroundColor3 = on and THEME.success or THEME.accent
        refreshZoneESP()
        log("FishZone ESP: " .. (on and "ON" or "OFF"), on and THEME.success or THEME.dim)
    end
    ctx.setZoneESP = setZoneESP

    bind(gui.FishZone.ZoneESPBtn.MouseButton1Click, function()
        setZoneESP(not ctx.zoneESPOn)
    end)

    bind(gui.FishZone.AutoTPBtn.MouseButton1Click, function()
        if ctx.autoTPEnabled then
            stopAutoTP()
            log("Auto TP: OFF", THEME.danger)
        else
            startAutoTP()
            moveToNearestActiveZone()
            log("Auto TP: ON - searching for active zone", THEME.success)
        end
    end)

    -- ═══════════════════════════════════════════
    -- Follow button toggle (Fishing)
    ctx.followEnabled = false
    ctx.followTarget = nil
    ctx.followTargetName = "None"

    local function addCorner(obj, corner)
        local c = Instance.new("UICorner")
        c.CornerRadius = corner
        c.Parent = obj
    end

    local function populateFollowPlayerList()
        local list = gui.FishZone.FollowPlayerList
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lp then
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, -4, 0, 22)
                row.BackgroundColor3 = THEME.panel2
                row.Text = player.Name
                row.TextColor3 = THEME.text
                row.Font = Enum.Font.GothamBold
                row.TextSize = 10
                row.BorderSizePixel = 0
                row.Parent = list
                addCorner(row, UDim.new(0, 5))
                -- Ensure the button can receive input (not blocked by siblings)
                row.ZIndex = 2
                if ctx.followTarget == player then
                    row.BackgroundColor3 = THEME.success
                    row.Text = player.Name .. " ✓"
                end
                -- Use MouseButton1Click directly (bind() also works but let's be explicit)
                row.MouseButton1Click:Connect(function()
                    log("Follow: clicked player button " .. player.Name, THEME.accentGlow)
                    ctx.followTarget = player
                    ctx.followTargetName = player.Name
                    gui.FishZone.FollowSelectedLbl.Text = "Following: " .. player.Name
                    log("Follow target set: " .. player.Name, THEME.success)
                    populateFollowPlayerList()
                end)
            end
        end
    end
    ctx.populateFollowPlayerList = populateFollowPlayerList

    bind(Players.PlayerAdded, populateFollowPlayerList)
    bind(Players.PlayerRemoving, populateFollowPlayerList)
    populateFollowPlayerList()

    -- Set Fish Follow to an explicit state. `targetPlayer` (optional) selects
    -- the follow target — used when a saved profile restores a target name.
    local function setFishFollow(on, targetPlayer)
        on = on and true or false
        if on and targetPlayer then
            ctx.followTarget = targetPlayer
            ctx.followTargetName = targetPlayer.Name
            if populateFollowPlayerList then populateFollowPlayerList() end
        end
        if ctx.followEnabled == on then return end
        ctx.followEnabled = on
        if on then
            -- Disable mining follow if it was active (avoid conflict)
            if ctx.mineFollowEnabled then
                if ctx.setMineFollow then
                    ctx.setMineFollow(false)
                else
                    ctx.mineFollowEnabled = false
                    ctx.mineFollowTarget = nil
                    ctx.mineFollowTargetName = "None"
                    gui.Mining.FollowBtn.Text = "Follow: OFF"
                    gui.Mining.FollowBtn.BackgroundColor3 = THEME.danger
                    gui.Mining.FollowSelectedLbl.Text = "Following: None"
                    unfreezeCharacter()
                end
                log("Mine Follow disabled — enabling Fish Follow", THEME.dim)
            end
            gui.FishZone.FollowBtn.Text = "Follow: ON"
            gui.FishZone.FollowBtn.BackgroundColor3 = THEME.success
            if ctx.followTarget then
                log("Follow started → " .. ctx.followTargetName, THEME.success)
            else
                log("Follow ON — select a player first!", THEME.warn)
            end
        else
            gui.FishZone.FollowBtn.Text = "Follow: OFF"
            gui.FishZone.FollowBtn.BackgroundColor3 = THEME.danger
            ctx.followTarget = nil
            ctx.followTargetName = "None"
            gui.FishZone.FollowSelectedLbl.Text = "Following: None"
            log("Follow stopped", THEME.dim)
            unfreezeCharacter()
        end
    end
    ctx.setFishFollow = setFishFollow

    bind(gui.FishZone.FollowBtn.MouseButton1Click, function()
        setFishFollow(not ctx.followEnabled)
    end)

for _, part in ipairs(getZoneParts()) do
        table.insert(ctx.zoneAttributeConnections, part:GetAttributeChangedSignal("IsActive"):Connect(function()
            refreshZoneESP()
            if ctx.autoTPEnabled then
                local hrp = getHRP(lp.Character)
                local currentStillActive = isActiveZone(ctx.currentZone)
                local insideActive, insidePart = isInsideAnyActiveZone(hrp)
                if not currentStillActive then
                    unfreezeCharacter()
                    ctx.currentZone = nil
                    moveToNearestActiveZone()
                elseif insideActive and insidePart ~= ctx.currentZone then
                    ctx.currentZone = insidePart
                    tpToZone(insidePart)
                elseif not insideActive then
                    moveToNearestActiveZone()
                end
            end
        end))
    end

    bind(gui.Clicker.ToggleBtn.MouseButton1Click, toggleClicker)

    -- Custom keybind for clicker
    local isListeningKeybind = false

    local function updateKeybindUI()
        local keyName = tostring(ctx.TOGGLE_KEY):gsub("Enum.KeyCode.", "")
        gui.Clicker.KeybindBtn.Text = "Key: " .. keyName
        gui.Clicker.ToggleBtn.Text = ctx.clicking
            and ("Stop [" .. keyName .. "]")
            or ("Start [" .. keyName .. "]")
    end
    ctx.updateKeybindUI = updateKeybindUI

    -- Sync the CPS slider visuals to the current ctx.clickCPS (used after loading settings)
    local function updateClickerSliderUI()
        local ratio = math.clamp(ctx.clickCPS / 100, 0, 1)
        gui.Clicker.SliderFill.Size = UDim2.new(ratio, 0, 1, 0)
        gui.Clicker.SliderKnob.Position = UDim2.new(ratio, -7, 0.5, -7)
        gui.Clicker.CPSLbl.Text = "CPS: " .. ctx.clickCPS
    end
    ctx.updateClickerSliderUI = updateClickerSliderUI

    bind(gui.Clicker.KeybindBtn.MouseButton1Click, function()
        if isListeningKeybind then return end
        isListeningKeybind = true
        gui.Clicker.KeybindBtn.Text = "Press any key..."
        gui.Clicker.KeybindBtn.BackgroundColor3 = THEME.warn
        gui.Clicker.KeybindBtn.TextColor3 = Color3.new(1, 1, 1)

        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            conn:Disconnect()

            ctx.TOGGLE_KEY = input.KeyCode
            updateKeybindUI()
            gui.Clicker.KeybindBtn.BackgroundColor3 = THEME.panel2
            gui.Clicker.KeybindBtn.TextColor3 = THEME.dim
            log("Clicker keybind: " .. tostring(ctx.TOGGLE_KEY):gsub("Enum.KeyCode.", ""), THEME.dim)

            task.delay(0.1, function()
                isListeningKeybind = false
            end)
        end)
    end)

    updateKeybindUI()

    bind(gui.Clicker.SliderKnob.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then ctx.draggingSlider = true end
    end)

    bind(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then ctx.draggingSlider = false end
    end)

    bind(UserInputService.InputChanged, function(i)
        if ctx.draggingSlider and i.UserInputType == Enum.UserInputType.MouseMovement then
            local ratio = math.clamp(
            (i.Position.X - gui.Clicker.SliderTrack.AbsolutePosition.X) / gui.Clicker.SliderTrack.AbsoluteSize.X, 0, 1)
            ctx.clickCPS = math.max(1, math.floor(ratio * 100))
            ctx.clickDelay = 1 / ctx.clickCPS
            gui.Clicker.SliderFill.Size = UDim2.new(ratio, 0, 1, 0)
            gui.Clicker.SliderKnob.Position = UDim2.new(ratio, -7, 0.5, -7)
            gui.Clicker.CPSLbl.Text = "CPS: " .. ctx.clickCPS
        end
    end)

    bind(gui.Settings.UnloadBtn.MouseButton1Click, destroyAll)
    bind(gui.CloseBtn.MouseButton1Click, destroyAll)

    bind(gui.MinBtn.MouseButton1Click, function()
        ctx.minimized = true
        gui.Main.Visible = false
        gui.MainShadow.Visible = false
        gui.MinimizedOrb.Visible = true
    end)

    bind(gui.MinimizedOrb.MouseButton1Click, function()
        ctx.minimized = false
        gui.Main.Visible = true
        gui.MainShadow.Visible = true
        gui.MinimizedOrb.Visible = false
    end)

    bind(gui.DragHit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)

    bind(UserInputService.InputChanged, function(input)
        if ctx.draggingUI and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - ctx.dragStart
            gui.Main.Position = UDim2.new(ctx.startPos.X.Scale, ctx.startPos.X.Offset + delta.X, ctx.startPos.Y.Scale,
                ctx.startPos.Y.Offset + delta.Y)
            gui.MainShadow.Position = UDim2.new(gui.Main.Position.X.Scale, gui.Main.Position.X.Offset - 5,
                gui.Main.Position.Y.Scale, gui.Main.Position.Y.Offset - 5)
        end
    end)

    bind(UserInputService.InputBegan, function(input, gp)
        if gp or ctx.destroyed then return end
        if input.KeyCode == ctx.TOGGLE_KEY then toggleClicker() end
        if input.KeyCode == ctx.PICK_KEY then
            ctx.savedX = mouse.X
            ctx.savedY = mouse.Y
            updateClickerUI()
        end
        if input.KeyCode == ctx.HIDE_KEY then
            ctx.hideUI = not ctx.hideUI
            if ctx.hideUI then
                gui.Main.Visible = false
                gui.MainShadow.Visible = false
                gui.MinimizedOrb.Visible = false
            else
                if ctx.minimized then
                    gui.MinimizedOrb.Visible = true
                else
                    gui.Main.Visible = true
                    gui.MainShadow.Visible = true
                end
            end
        end
    end)

    -- Halloween theme variants (centralized in config.ThemeVariants — no
    -- hardcoded colors here).
    bind(gui.Settings.DarkThemeBtn.MouseButton1Click, function()
        if ctx.applyThemeVariant then ctx.applyThemeVariant("Dark") end
        gui.Settings.DarkThemeBtn.BackgroundColor3 = THEME.accent
        gui.Settings.DarkThemeBtn.TextColor3 = Color3.new(1, 1, 1)
        gui.Settings.LightThemeBtn.BackgroundColor3 = THEME.panel2
        gui.Settings.LightThemeBtn.TextColor3 = THEME.dim
        log("Theme: Halloween (Dark)", THEME.dim)
    end)

    bind(gui.Settings.LightThemeBtn.MouseButton1Click, function()
        if ctx.applyThemeVariant then ctx.applyThemeVariant("Ember") end
        gui.Settings.LightThemeBtn.BackgroundColor3 = THEME.accent
        gui.Settings.LightThemeBtn.TextColor3 = Color3.new(1, 1, 1)
        gui.Settings.DarkThemeBtn.BackgroundColor3 = THEME.panel2
        gui.Settings.DarkThemeBtn.TextColor3 = THEME.dim
        log("Theme: Halloween (Ember)", THEME.dim)
    end)

    for name, btn in pairs(gui.TabButtons) do
        bind(btn.MouseButton1Click, function()
            switchTab(name)
        end)
    end

    -- Periodic performance monitor update + clicker + autoTP heartbeat
    local lastPerfUpdate = 0
    bind(RunService.Heartbeat, function()
        if ctx.destroyed then return end

        local now = tick()
        if now - lastPerfUpdate > 10 then
            lastPerfUpdate = now
            if ctx.autoFishEnabled or ctx.autoMineEnabled then
                updatePerfMonitor()
            end
        end

        if ctx.clicking then
            if now - ctx.lastClick >= ctx.clickDelay then
                ctx.lastClick = now
                local x, y = resolvePosition()
                if x and y then silentClick(x, y) end
            end
        end

        if ctx.autoTPEnabled then
            local hrp = getHRP(lp.Character)
            local insideActive, insidePart = isInsideAnyActiveZone(hrp)
            local currentStillActive = isActiveZone(ctx.currentZone)

            if not currentStillActive then
                moveToNearestActiveZone()
            elseif not insideActive then
                moveToNearestActiveZone()
            elseif ctx.currentZone ~= insidePart then
                tpToZone(insidePart)
            elseif ctx.frozenAnchor and ctx.frozenAnchor.Parent then
                ctx.frozenAnchor.Position = ctx.currentZone.Position + Vector3.new(0, ctx.currentZone.Size.Y / 2 + ctx.FLOAT_HEIGHT, 0)
            end

            if ctx.currentZone and isActiveZone(ctx.currentZone) then
                gui.FishZone.ZoneStatus.Text = "Locked: " .. ctx.currentZone.Name .. " [ACTIVE]"
                gui.FishZone.ZoneStatus.TextColor3 = THEME.success
            else
                local nearest = nearestActiveZonePart()
                gui.FishZone.ZoneStatus.Text = nearest and ("Searching → " .. nearest.Name) or "No active zone"
                gui.FishZone.ZoneStatus.TextColor3 = nearest and THEME.warn or THEME.danger
            end
        else
            local nearest = nearestActiveZonePart()
            if nearest then
                gui.FishZone.ZoneStatus.Text = "Nearest active zone: " .. nearest.Name
                gui.FishZone.ZoneStatus.TextColor3 = THEME.text
            else
                gui.FishZone.ZoneStatus.Text = "No active zone"
                gui.FishZone.ZoneStatus.TextColor3 = THEME.danger
            end
        end

        -- Follow player: only move when target is moving, freeze so you can fish/mine
        if ctx.followEnabled and ctx.followTarget and ctx.followTarget.Parent then
            local hrp = getHRP(lp.Character)
            local targetHRP = getHRP(ctx.followTarget.Character)
            local targetHum = ctx.followTarget.Character and ctx.followTarget.Character:FindFirstChildOfClass("Humanoid")
            if hrp and targetHRP and targetHum then
                local targetVel = (targetHRP.AssemblyLinearVelocity or Vector3.zero).Magnitude
                local dist = (targetHRP.Position - hrp.Position).Magnitude
                local moving = targetVel > 1.5 or targetHum.MoveDirection.Magnitude > 0.1
                local alreadyFrozen = ctx.frozenAnchor and ctx.frozenAnchor.Parent
                if moving and dist > 3 then
                    -- Always TP first — CFrame teleport bypasses invisible walls
                    ctx.tpToPlayer(ctx.followTarget)
                    local behindTarget = (targetHRP.CFrame * CFrame.new(0, 0, 5)).Position
                    if not alreadyFrozen then
                        task.wait(0.05)
                        ctx.freezeAt(behindTarget)
                    else
                        -- Already frozen — just update the anchor position
                        -- Do NOT update frozenGyro — it locks rotation once and stays
                        ctx.frozenAnchor.Position = behindTarget
                    end
                elseif not moving and dist <= 6 then
                    -- Target stopped and close — stay frozen for stable camera (like Auto Fish TP)
                    if not alreadyFrozen then
                        ctx.freezeAt(hrp.Position)
                    end
                end
                gui.FishZone.FollowSelectedLbl.Text = "Following: " .. ctx.followTargetName .. " (" .. math.floor(dist) .. "m)"
                gui.FishZone.FollowSelectedLbl.TextColor3 = (moving and dist > 3) or dist <= 6 and THEME.success or THEME.accentGlow
            end
        elseif ctx.followEnabled and ctx.followTarget and not ctx.followTarget.Parent then
            ctx.followEnabled = false
            gui.FishZone.FollowBtn.Text = "Follow: OFF"
            gui.FishZone.FollowBtn.BackgroundColor3 = THEME.danger
            gui.FishZone.FollowSelectedLbl.Text = "Following: None (left)"
            gui.FishZone.FollowSelectedLbl.TextColor3 = THEME.warn
            ctx.followTarget = nil
            ctx.followTargetName = "None"
            unfreezeCharacter()
            log("Follow target left server", THEME.warn)
        end
    end)

    switchTab("About")
    updateClickerUI()
    updateRewardButtons()
    refreshZoneESP()
    applyTheme()

    -- Startup logs
    log("LyraHub initialized", THEME.accentGlow)
    log("Player: " .. lp.Name, THEME.text)
    log("Clicker mode: " .. (useVIM and "Silent (VIM)" or "Fallback"), useVIM and THEME.success or THEME.warn)
    log("Active zones found: " .. #getActiveZoneParts(), THEME.dim)
    log("Press K to hide/show UI", THEME.dim)
end
