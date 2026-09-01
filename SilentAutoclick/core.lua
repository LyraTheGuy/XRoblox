-- SilentAutoclick/core.lua
-- Shared context: services, state, silent-click utility, drag, toggle, destroy
-- Modules are loaded separately via main.lua
return function(gui, config)
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")

    local lp = Players.LocalPlayer
    local mouse = lp:GetMouse()

    local THEME = gui.Theme

    local ctx = {
        gui = gui,
        config = config,
        THEME = THEME,
        lp = lp,
        mouse = mouse,
        Players = Players,
        UserInputService = UserInputService,
        RunService = RunService,
        destroyed = false,
        clicking = false,
        clickCPS = config.Clicker.DefaultCPS,
        clickDelay = 1 / config.Clicker.DefaultCPS,
        lastClick = 0,
        mode = "cursor",
        fixedX = nil,
        fixedY = nil,
        minimized = false,
        hideUI = false,
        draggingUI = false,
        dragStart = nil,
        startPos = nil,
        dragTarget = nil,
        toggleKey = config.Keys.ToggleClicker,
        pickKey = config.Keys.PickPosition,
        hideKey = config.Keys.HideUI,
        totalClicks = 0,
        actualCPS = 0,
        fps = 0,
        ping = 0,
        connections = {}
    }

    local function bind(signal, fn)
        local c = signal:Connect(fn)
        table.insert(ctx.connections, c)
        return c
    end
    ctx.bind = bind

    local VIM = (pcall(function() return cloneref(game:GetService("VirtualInputManager")) end))
        and cloneref(game:GetService("VirtualInputManager"))
        or game:GetService("VirtualInputManager")
    ctx.VIM = VIM

    local useVIM = pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
    ctx.useVIM = useVIM

    local function silentClick(x, y)
        if useVIM then
            VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
            VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
        else
            pcall(function()
                local cx, cy = mouse.X, mouse.Y
                mousemoveabs(x, y)
                mouse1press()
                mouse1release()
                mousemoveabs(cx, cy)
            end)
        end
    end
    ctx.silentClick = silentClick

    local function resolvePosition()
        if ctx.mode == "fixed" then
            if ctx.fixedX and ctx.fixedY then
                return ctx.fixedX, ctx.fixedY
            end
            return nil, nil
        end
        return mouse.X, mouse.Y
    end
    ctx.resolvePosition = resolvePosition

    -- ═══════════════════════════════════════════
    -- CLICKER UI HELPERS
    -- ═══════════════════════════════════════════
    local function updateClickerUI()
        local keyName = tostring(ctx.toggleKey):gsub("Enum.KeyCode.", "")
        if ctx.clicking then
            gui.StatusLbl.Text = "Status: ON"
            gui.StatusLbl.TextColor3 = THEME.success
            gui.ToggleBtn.SetText("Stop [" .. keyName .. "]")
            gui.ToggleBtn.SetColor(THEME.danger)
        else
            gui.StatusLbl.Text = "Status: OFF"
            gui.StatusLbl.TextColor3 = THEME.danger
            gui.ToggleBtn.SetText("Start [" .. keyName .. "]")
            gui.ToggleBtn.SetColor(THEME.accent)
        end

        gui.MethodLbl.Text = useVIM and "Mode: Silent" or "Mode: Fallback"
        gui.MethodLbl.TextColor3 = useVIM and THEME.success or THEME.warn

        gui.MiniStats.StatusVal.Text = ctx.clicking and "ON" or "OFF"
        gui.MiniStats.StatusVal.TextColor3 = ctx.clicking and THEME.success or THEME.danger

        if ctx.mode == "fixed" then
            gui.PosLbl.Visible = true
            if ctx.fixedX and ctx.fixedY then
                gui.PosLbl.Text = string.format("Target: (%d, %d)", ctx.fixedX, ctx.fixedY)
                gui.PosLbl.TextColor3 = THEME.success
            else
                gui.PosLbl.Text = "Target: Not set (press P to pick)"
                gui.PosLbl.TextColor3 = THEME.warn
            end
        else
            gui.PosLbl.Visible = false
        end
    end
    ctx.updateClickerUI = updateClickerUI

    local function toggleClicker()
        if ctx.mode == "fixed" then
            local x, y = resolvePosition()
            if not x or not y then
                gui.PosLbl.Text = "Hover target and press P first"
                gui.PosLbl.TextColor3 = THEME.warn
                return
            end
        end
        ctx.clicking = not ctx.clicking
        updateClickerUI()
    end
    ctx.toggleClicker = toggleClicker

    -- ═══════════════════════════════════════════
    -- DESTROY
    -- ═══════════════════════════════════════════
    local function destroyAll()
        ctx.destroyed = true
        ctx.clicking = false
        for i = #ctx.connections, 1, -1 do
            pcall(function() ctx.connections[i]:Disconnect() end)
            table.remove(ctx.connections, i)
        end
        pcall(function() gui.ScreenGui:Destroy() end)
    end
    ctx.destroyAll = destroyAll
    _G.__SilentAutoclick_Destroy = destroyAll

    return ctx
end
