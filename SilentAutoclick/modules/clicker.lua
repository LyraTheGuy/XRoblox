-- modules/clicker.lua
-- Click mode selector, toggle, keybind, CPS/interval controls, and click loop
return function(ctx)
    local gui = ctx.gui
    local bind = ctx.bind
    local RunService = ctx.RunService
    local resolvePosition = ctx.resolvePosition
    local silentClick = ctx.silentClick
    local updateClickerUI = ctx.updateClickerUI
    local toggleClicker = ctx.toggleClicker

    -- ═══════════════════════════════════════════
    -- TIMING SYNC HELPERS
    -- ═══════════════════════════════════════════
    local function syncCPS(cps)
        local value = math.clamp(math.floor(cps), ctx.config.Clicker.MinCPS, ctx.config.Clicker.MaxCPS)
        ctx.clickCPS = value
        ctx.clickMode = "cps"
        ctx.clickDelay = 1 / value

        gui.CPSLbl.Text = "Clicks/sec: " .. value
        gui.TimingStatus.Text = value .. " clicks/sec"
        gui.TimingStatus.TextColor3 = ctx.THEME.accent2

        -- Update slider position (10-100 range mapped to 0-1)
        local ratio = (value - ctx.config.Clicker.MinCPS) / (ctx.config.Clicker.MaxCPS - ctx.config.Clicker.MinCPS)
        if gui.CPSSlider and gui.CPSSlider.Set then
            gui.CPSSlider.Set(ratio, false)
        end

        updateClickerUI()
    end

    local function syncInterval(seconds)
        local value = tonumber(seconds)
        if not value then return false end
        local minS = ctx.config.Clicker.MinIntervalSeconds or 1
        local maxS = ctx.config.Clicker.MaxIntervalSeconds or 60
        value = math.clamp(value, minS, maxS)

        ctx.clickIntervalSeconds = value
        ctx.clickMode = "interval"
        ctx.clickDelay = value

        gui.TimingStatus.Text = "1 click / " .. string.format("%.1f", value) .. "s"
        gui.TimingStatus.TextColor3 = ctx.THEME.accent2
        gui.CPSLbl.Text = "Interval: " .. string.format("%.1f", value) .. "s"

        if gui.IntervalInput and gui.IntervalInput.SetText then
            gui.IntervalInput.SetText(string.format("%.1f", value), false)
        end

        updateClickerUI()
        return true
    end

    -- ═══════════════════════════════════════════
    -- MODE SWITCHING (CPS vs Interval)
    -- ═══════════════════════════════════════════
    gui.TimingModeDropdown.OnSelected(function(item)
        local isCPS = (item == "Clicks per Second")
        ctx.clickMode = isCPS and "cps" or "interval"

        -- Toggle visibility
        if gui._intervalModeElements then
            for _, el in ipairs(gui._intervalModeElements) do
                if el then el.Visible = isCPS end
            end
        end
        if gui._cpsModeElements then
            for _, el in ipairs(gui._cpsModeElements) do
                if el then el.Visible = not isCPS end
            end
        end

        if isCPS then
            syncCPS(ctx.clickCPS or ctx.config.Clicker.DefaultCPS)
        else
            syncInterval(ctx.clickIntervalSeconds or ctx.config.Clicker.DefaultIntervalSeconds or 5)
        end
    end)

    -- ═══════════════════════════════════════════
    -- CLICK MODE (cursor / fixed)
    -- ═══════════════════════════════════════════
    gui.ModeDropdown.OnSelected(function(item)
        ctx.mode = (item == "Fixed Position") and "fixed" or "cursor"
        updateClickerUI()
    end)

    -- ═══════════════════════════════════════════
    -- TOGGLE + KEYBIND
    -- ═══════════════════════════════════════════
    bind(gui.ToggleBtn.Instance.MouseButton1Click, toggleClicker)
    gui.KeybindBtn.OnChanged(function(key)
        ctx.toggleKey = key
        updateClickerUI()
    end)

    -- ═══════════════════════════════════════════
    -- CPS SLIDER
    -- ═══════════════════════════════════════════
    gui.CPSSlider.OnChanged(function(ratio)
        local minCPS = ctx.config.Clicker.MinCPS or 10
        local maxCPS = ctx.config.Clicker.MaxCPS or 100
        local cps = math.floor(minCPS + ratio * (maxCPS - minCPS))
        syncCPS(cps)
    end)

    -- ═══════════════════════════════════════════
    -- CPS PRESET BUTTONS
    -- ═══════════════════════════════════════════
    if gui.CPSPresetBtns then
        for cpsValue, btn in pairs(gui.CPSPresetBtns) do
            bind(btn.MouseButton1Click, function()
                syncCPS(cpsValue)
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

    -- ═══════════════════════════════════════════
    -- INTERVAL INPUT
    -- ═══════════════════════════════════════════
    if gui.IntervalInput then
        gui.IntervalInput.OnChanged(function(value)
            local trimmed = string.gsub(value or "", "%s+", "")
            if trimmed == "" then return end
            syncInterval(trimmed)
        end)
    end

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

    -- Initialize with CPS mode
    syncCPS(ctx.config.Clicker.DefaultCPS or 50)
    updateClickerUI()
end
