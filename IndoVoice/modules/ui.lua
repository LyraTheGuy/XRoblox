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
    local refreshPlayerRows = ctx.refreshPlayerRows
    local makePlayerRow = ctx.makePlayerRow
    local removePlayerRow = ctx.removePlayerRow
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

    -- Player search
    bind(gui.Players.SearchBox:GetPropertyChangedSignal("Text"), function()
        ctx.playerSearchText = gui.Players.SearchBox.Text
        refreshPlayerRows()
    end)

    for _, p in ipairs(Players:GetPlayers()) do makePlayerRow(p) end
    bind(Players.PlayerAdded, makePlayerRow)
    bind(Players.PlayerRemoving, removePlayerRow)

    bind(gui.FishZone.ZoneESPBtn.MouseButton1Click, function()
        ctx.zoneESPOn = not ctx.zoneESPOn
        gui.FishZone.ZoneESPBtn.Text = ctx.zoneESPOn and "FishZone ESP: ON" or "FishZone ESP: OFF"
        gui.FishZone.ZoneESPBtn.BackgroundColor3 = ctx.zoneESPOn and THEME.success or THEME.accent
        refreshZoneESP()
        log("FishZone ESP: " .. (ctx.zoneESPOn and "ON" or "OFF"), ctx.zoneESPOn and THEME.success or THEME.dim)
        if gui.Toast and gui.Toast.show then
            local msg = ctx.zoneESPOn and "FishZone ESP enabled" or "FishZone ESP disabled"
            gui.Toast.show({Text = msg, Variant = ctx.zoneESPOn and "success" or "info", Duration = 1.5})
        end
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
        if gui.Toast and gui.Toast.show then
            local msg = ctx.autoTPEnabled and "Auto TP to FishZone ON" or "Auto TP to FishZone OFF"
            gui.Toast.show({Text = msg, Variant = ctx.autoTPEnabled and "success" or "info", Duration = 1.5})
        end
    end)

    bind(gui.FishZone.RefreshCharBtn.MouseButton1Click, function()
        gui.FishZone.RefreshCharBtn.Text = "Refreshing..."
        refreshCharacterAdonis()
        log("Refresh character sent (Adonis)", THEME.warn)
        if gui.Toast and gui.Toast.show then
            gui.Toast.show({Text = "Refreshed Character", Variant = "warn", Duration = 1.5})
        end
        task.delay(1.2, function()
            if gui.FishZone.RefreshCharBtn and gui.FishZone.RefreshCharBtn.Parent then
                gui.FishZone.RefreshCharBtn.Text = "Refresh Character"
            end
        end)
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

    -- Dark/Light theme toggle
    bind(gui.Settings.DarkThemeBtn.MouseButton1Click, function()
        THEME.accent = Color3.fromRGB(155, 89, 255)
        THEME.accentGlow = Color3.fromRGB(180, 130, 255)
        THEME.bg = Color3.fromRGB(12, 10, 20)
        THEME.bg2 = Color3.fromRGB(18, 15, 30)
        THEME.panel = Color3.fromRGB(22, 20, 38)
        THEME.panel2 = Color3.fromRGB(30, 27, 50)
        THEME.sidebar = Color3.fromRGB(16, 13, 28)
        THEME.topbar = Color3.fromRGB(20, 17, 34)
        THEME.text = Color3.fromRGB(240, 235, 255)
        THEME.dim = Color3.fromRGB(130, 120, 170)
        gui.Settings.DarkThemeBtn.BackgroundColor3 = THEME.accent
        gui.Settings.DarkThemeBtn.TextColor3 = Color3.new(1, 1, 1)
        gui.Settings.LightThemeBtn.BackgroundColor3 = THEME.panel2
        gui.Settings.LightThemeBtn.TextColor3 = THEME.dim
        applyTheme()
        log("Theme: Dark (Lyra)", THEME.dim)
    end)

    bind(gui.Settings.LightThemeBtn.MouseButton1Click, function()
        THEME.accent = Color3.fromRGB(120, 70, 220)
        THEME.accentGlow = Color3.fromRGB(100, 60, 190)
        THEME.bg = Color3.fromRGB(240, 238, 250)
        THEME.bg2 = Color3.fromRGB(228, 224, 242)
        THEME.panel = Color3.fromRGB(248, 246, 255)
        THEME.panel2 = Color3.fromRGB(220, 215, 238)
        THEME.sidebar = Color3.fromRGB(235, 230, 248)
        THEME.topbar = Color3.fromRGB(230, 226, 245)
        THEME.text = Color3.fromRGB(30, 20, 60)
        THEME.dim = Color3.fromRGB(100, 90, 140)
        gui.Settings.LightThemeBtn.BackgroundColor3 = THEME.accent
        gui.Settings.LightThemeBtn.TextColor3 = Color3.new(1, 1, 1)
        gui.Settings.DarkThemeBtn.BackgroundColor3 = THEME.panel2
        gui.Settings.DarkThemeBtn.TextColor3 = THEME.dim
        applyTheme()
        log("Theme: Light (Lyra)", THEME.dim)
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
    end)

    switchTab("About")
    updateClickerUI()
    updateRewardButtons()
    refreshPlayerRows()
    refreshZoneESP()
    applyTheme()

    -- Startup logs
    log("LyraHub initialized", THEME.accentGlow)
    log("Player: " .. lp.Name, THEME.text)
    log("Clicker mode: " .. (useVIM and "Silent (VIM)" or "Fallback"), useVIM and THEME.success or THEME.warn)
    log("Active zones found: " .. #getActiveZoneParts(), THEME.dim)
    log("Press K to hide/show UI", THEME.dim)
end
