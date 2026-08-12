-- modules/clicker.lua
-- Click mode, CPS slider, keybind capture, and the actual click loop
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local bind = ctx.bind
    local UserInputService = ctx.UserInputService
    local RunService = ctx.RunService
    local resolvePosition = ctx.resolvePosition
    local silentClick = ctx.silentClick
    local updateClickerUI = ctx.updateClickerUI
    local toggleClicker = ctx.toggleClicker

    -- ═══════════════════════════════════════════
    -- MODE TOGGLE (Cursor / Fixed)
    -- ═══════════════════════════════════════════
    bind(gui.ModeBtn.MouseButton1Click, function()
        if ctx.mode == "cursor" then
            ctx.mode = "fixed"
            gui.ModeBtn.Text = "Click Mode: Fixed Position"
        else
            ctx.mode = "cursor"
            gui.ModeBtn.Text = "Click Mode: Follow Cursor"
        end
        updateClickerUI()
    end)

    -- ═══════════════════════════════════════════
    -- TOGGLE BUTTON
    -- ═══════════════════════════════════════════
    bind(gui.ToggleBtn.MouseButton1Click, toggleClicker)

    -- ═══════════════════════════════════════════
    -- KEYBIND CAPTURE
    -- ═══════════════════════════════════════════
    bind(gui.KeybindBtn.MouseButton1Click, function()
        if ctx.listeningKeybind then return end
        ctx.listeningKeybind = true
        gui.KeybindBtn.Text = "Press any key..."
        gui.KeybindBtn.BackgroundColor3 = THEME.warn
        gui.KeybindBtn.TextColor3 = Color3.new(1, 1, 1)

        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            conn:Disconnect()

            ctx.toggleKey = input.KeyCode
            gui.KeybindBtn.Text = "Key: " .. tostring(ctx.toggleKey):gsub("Enum.KeyCode.", "")
            gui.KeybindBtn.BackgroundColor3 = THEME.panel2
            gui.KeybindBtn.TextColor3 = THEME.dim
            updateClickerUI()

            task.delay(0.1, function()
                ctx.listeningKeybind = false
            end)
        end)
    end)

    -- ═══════════════════════════════════════════
    -- CPS SLIDER
    -- ═══════════════════════════════════════════
    bind(gui.SliderKnob.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            ctx.draggingSlider = true
        end
    end)

    bind(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            ctx.draggingSlider = false
        end
    end)

    bind(UserInputService.InputChanged, function(i)
        if ctx.draggingSlider and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local ratio = math.clamp((i.Position.X - gui.SliderTrack.AbsolutePosition.X) / gui.SliderTrack.AbsoluteSize.X, 0, 1)
            ctx.clickCPS = math.max(1, math.floor(ratio * 100))
            ctx.clickDelay = 1 / ctx.clickCPS
            gui.SliderFill.Size = UDim2.new(ratio, 0, 1, 0)
            -- Knob is anchored at (0, 0.5): X offset -8 centers its 16px width,
            -- Y offset must stay 0 or the knob floats above the track.
            gui.SliderKnob.Position = UDim2.new(ratio, -8, 0.5, 0)
            gui.CPSLbl.Text = "CPS: " .. ctx.clickCPS
        end
    end)

    -- ═══════════════════════════════════════════
    -- CLICK LOOP
    -- ═══════════════════════════════════════════
    bind(RunService.Heartbeat, function()
        if ctx.destroyed or not ctx.clicking then return end
        local now = tick()
        if now - ctx.lastClick >= ctx.clickDelay then
            ctx.lastClick = now
            local x, y = resolvePosition()
            if x and y then
                silentClick(x, y)
                ctx.totalClicks = ctx.totalClicks + 1
            end
        end
    end)

    updateClickerUI()
end
