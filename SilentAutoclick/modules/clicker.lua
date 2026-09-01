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

    local function applyInterval(value)
        local seconds = tonumber(value)
        if not seconds then
            return false
        end

        seconds = math.clamp(seconds, 1, 360)
        ctx.clickIntervalSeconds = seconds
        ctx.clickDelay = seconds
        ctx.clickCPS = math.max(1, math.floor(1 / seconds))
        ctx.config.Clicker.IntervalSeconds = seconds
        gui.CPSLbl.Text = "CPS: " .. ctx.clickCPS
        if gui.Sparkline then
            gui.Sparkline.SetTarget(ctx.clickCPS)
        end
        updateClickerUI()
        return true
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
        applyInterval(trimmed)
    end)

    gui.CPSSlider.OnChanged(function(ratio)
        local cps = math.max(1, math.floor(ratio * 100))
        ctx.clickCPS = cps
        local seconds = math.max(1, 1 / cps)
        ctx.clickIntervalSeconds = seconds
        ctx.clickDelay = seconds
        ctx.config.Clicker.IntervalSeconds = seconds
        gui.TimingInput.SetText(string.format("%.2f", seconds), false)
        gui.CPSLbl.Text = "CPS: " .. cps
        if gui.Sparkline then
            gui.Sparkline.SetTarget(cps)
        end
        updateClickerUI()
    end)

    applyInterval(ctx.config.Clicker.IntervalSeconds or ctx.clickIntervalSeconds or 1)

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
