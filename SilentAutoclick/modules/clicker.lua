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

    gui.ModeDropdown.OnSelected(function(item)
        ctx.mode = (item == "Fixed Position") and "fixed" or "cursor"
        updateClickerUI()
    end)

    bind(gui.ToggleBtn.Instance.MouseButton1Click, toggleClicker)
    gui.KeybindBtn.OnChanged(function(key)
        ctx.toggleKey = key
        updateClickerUI()
    end)

    gui.CPSSlider.OnChanged(function(ratio)
        ctx.clickCPS = math.max(1, math.floor(ratio * 100))
        ctx.clickDelay = 1 / ctx.clickCPS
        gui.CPSLbl.Text = "CPS: " .. ctx.clickCPS
        if gui.Sparkline then
            gui.Sparkline.SetTarget(ctx.clickCPS)
        end
    end)

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
