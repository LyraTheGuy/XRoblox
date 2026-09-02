-- modules/clicker.lua
-- Click mode (LyraHub dropdown), toggle button, keybind picker, CPS slider,
-- and the actual click loop
return function(ctx)
    local gui = ctx.gui
    local bind = ctx.bind
    local RunService = ctx.RunService
    local resolvePosition = ctx.resolvePosition
    local silentClick = ctx.silentClick
    local updateClickerUI = ctx.updateClickerUI
    local toggleClicker = ctx.toggleClicker

    local function syncTimingFromSeconds(seconds)
        local value = tonumber(seconds)
        if not value then
            if gui.TimingStatus then
                gui.TimingStatus.Text = "Invalid value. Use 1-360s"
                gui.TimingStatus.TextColor3 = ctx.THEME.warn
            end
            return false
        end

        local minSeconds = ctx.config.Clicker.MinIntervalSeconds or 1
        local maxSeconds = ctx.config.Clicker.MaxIntervalSeconds or 360
        value = math.clamp(value, minSeconds, maxSeconds)

        ctx.clickIntervalSeconds = value
        ctx.clickDelay = value
        ctx.clickCPS = math.max(1, math.floor((1 / value) + 0.5))
        ctx.config.Clicker.IntervalSeconds = value

        gui.TimingInput.SetText(string.format("%.2f", value), false)
        gui.CPSLbl.Text = "CPS: " .. ctx.clickCPS
        if gui.Sparkline then
            gui.Sparkline.SetTarget(ctx.clickCPS)
        end

        if gui.TimingStatus then
            gui.TimingStatus.Text = "Range: 1s - 360s"
            gui.TimingStatus.TextColor3 = ctx.THEME.dim
        end

        updateClickerUI()
        return true
    end

    local function syncTimingFromCPS(cps)
        local value = math.max(1, math.min(100, math.floor(cps)))
        local seconds = math.max(1, 1 / value)
        return syncTimingFromSeconds(seconds)
    end

    gui.ModeDropdown.OnSelected(function(item)
        ctx.mode = (item == "Fixed Position") and "fixed" or "cursor"
        updateClickerUI()
    end)

    bind(gui.ToggleBtn.Instance.MouseButton1Click, toggleClicker)
    gui.KeybindBtn.OnChanged(function(key)
        ctx.toggleKey = key
        updateClickerUI()
    end)

    gui.TimingInput.OnChanged(function(value)
        local trimmed = string.gsub(value or "", "%s+", "")
        if trimmed == "" then
            return
        end
        syncTimingFromSeconds(trimmed)
    end)

    gui.ResetTimingBtn.Instance.MouseButton1Click:Connect(function()
        syncTimingFromSeconds(ctx.config.Clicker.DefaultIntervalSeconds or 1)
        if gui.Toast then
            gui.Toast.show({
                Text = "Timing reset to default",
                Variant = "info",
                ScreenGui = gui.ScreenGui,
                Duration = 2,
            })
        end
    end)

    gui.CPSSlider.OnChanged(function(ratio)
        local cps = math.max(1, math.floor(ratio * 100))
        syncTimingFromCPS(cps)
    end)

    -- ═══ CPS Preset Buttons ═══
    if gui.CPSPresetBtns then
        for cpsValue, btn in pairs(gui.CPSPresetBtns) do
            bind(btn.MouseButton1Click, function()
                syncTimingFromCPS(cpsValue)
                if gui.Toast then
                    gui.Toast.show({
                        Text = "CPS set to " .. tostring(cpsValue),
                        Variant = "success",
                        ScreenGui = gui.ScreenGui,
                        Duration = 1.5,
                    })
                end
            end)
        end
    end

    -- ═══ Hotkey Customization ═══
    if gui.PickTargetKey then
        gui.PickTargetKey.OnChanged(function(key)
            ctx.pickTargetKey = key
            ctx.config.Keys.PickTarget = key
        end)
    end

    if gui.HideShowKey then
        gui.HideShowKey.OnChanged(function(key)
            ctx.hideShowKey = key
            ctx.config.Keys.HideUI = key
        end)
    end

    syncTimingFromSeconds(ctx.config.Clicker.IntervalSeconds or ctx.clickIntervalSeconds or 1)

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
