-- SilentAutoclick/core.lua
-- Shared context: clicker, game interaction, settings persistence, movement, utility
return function(gui, config)
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
        ReplicatedStorage = ReplicatedStorage,
        destroyed = false,
        -- Clicker state
        clicking = false,
        clickCPS = config.Clicker.DefaultCPS,
        clickIntervalSeconds = config.Clicker.IntervalSeconds or config.Clicker.DefaultIntervalSeconds or 1,
        clickDelay = config.Clicker.IntervalSeconds or config.Clicker.DefaultIntervalSeconds or 1,
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

        -- Movement state
        flyEnabled = false,
        noClipEnabled = false,
        infJumpEnabled = false,
        flySpeed = config.Movement.FlySpeed or 50,
        walkSpeed = config.Movement.WalkSpeed or 16,
        flyBodyVelocity = nil,
        flyBodyGyro = nil,
        noclipConnection = nil,
        infJumpConnection = nil,
        -- Connections
        connections = {},
    }

    -- ═══════════════════════════════════════════
    -- UTILITY
    -- ═══════════════════════════════════════════
    local function bind(signal, fn)
        local c = signal:Connect(fn)
        table.insert(ctx.connections, c)
        return c
    end
    ctx.bind = bind

    local function disconnectList(list)
        for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
        table.clear(list)
    end
    ctx.disconnectList = disconnectList

    -- ═══════════════════════════════════════════
    -- SILENT CLICK
    -- ═══════════════════════════════════════════
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
            if ctx.fixedX and ctx.fixedY then return ctx.fixedX, ctx.fixedY end
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
        if gui.IntervalLbl then
            gui.IntervalLbl.Text = string.format("Delay: %.2fs / click", ctx.clickIntervalSeconds)
            gui.IntervalLbl.TextColor3 = THEME.accent2
        end
        if gui.TimingStatus then
            gui.TimingStatus.Text = string.format("Range: %.2fs - %.2fs", config.Clicker.MinIntervalSeconds, config.Clicker.MaxIntervalSeconds)
            gui.TimingStatus.TextColor3 = THEME.dim
        end
        gui.MiniStats.StatusVal.Text = ctx.clicking and "ON" or "OFF"
        gui.MiniStats.StatusVal.TextColor3 = ctx.clicking and THEME.success or THEME.danger
        if ctx.mode == "fixed" then
            gui.PosLbl.Visible = true
            if ctx.fixedX and ctx.fixedY then
                gui.PosLbl.Text = string.format("Target: (%d, %d)", ctx.fixedX, ctx.fixedY)
                gui.PosLbl.TextColor3 = THEME.success
            else
                gui.PosLbl.Text = "Target: Not set (press P)"
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
    -- GAME REMOTE ACCESS
    -- ═══════════════════════════════════════════
    local function findRemote(name)
        local ok, result = pcall(function() return ReplicatedStorage:WaitForChild(name, 3) end)
        if ok and result then return result end
        for _, folder in ipairs(ReplicatedStorage:GetChildren()) do
            if folder:IsA("Folder") then
                local child = folder:FindFirstChild(name, true)
                if child then return child end
            end
        end
        return nil
    end
    ctx.findRemote = findRemote



    -- ═══════════════════════════════════════════
    -- SETTINGS PERSISTENCE
    -- ═══════════════════════════════════════════
    local SETTINGS_FILE = "SilentHub_Settings.json"

    local function saveSettings()
        local data = {
            clickIntervalSeconds = ctx.clickIntervalSeconds,
            clickCPS = ctx.clickCPS,
            mode = ctx.mode,
            fixedX = ctx.fixedX,
            fixedY = ctx.fixedY,
            flyEnabled = ctx.flyEnabled,
            noClipEnabled = ctx.noClipEnabled,
            infJumpEnabled = ctx.infJumpEnabled,
            flySpeed = ctx.flySpeed,
            walkSpeed = ctx.walkSpeed,
        }
        local ok, err = pcall(function()
            writefile(SETTINGS_FILE, game:GetService("HttpService"):JSONEncode(data))
        end)
        if ok then
            gui.SaveStatusLabel.Text = "Settings saved!"
            gui.SaveStatusLabel.TextColor3 = THEME.success
        else
            gui.SaveStatusLabel.Text = "Save failed"
            gui.SaveStatusLabel.TextColor3 = THEME.danger
        end
        task.delay(3, function()
            if gui.SaveStatusLabel and gui.SaveStatusLabel.Parent then gui.SaveStatusLabel.Text = "" end
        end)
    end
    ctx.saveSettings = saveSettings

    local function applyToggle(btn, enabled, label)
        if not btn then return end
        btn.Text = label .. (enabled and ": ON" or ": OFF")
        btn.BackgroundColor3 = enabled and THEME.success or THEME.panel2
        btn.TextColor3 = enabled and Color3.new(1, 1, 1) or THEME.dim
    end

    local function loadSettings()
        local ok, result = pcall(function()
            if isfile and isfile(SETTINGS_FILE) then
                return game:GetService("HttpService"):JSONDecode(readfile(SETTINGS_FILE))
            end
            return nil
        end)
        if not ok or not result then
            gui.SaveStatusLabel.Text = "No saved settings"
            gui.SaveStatusLabel.TextColor3 = THEME.dim
            task.delay(2, function() gui.SaveStatusLabel.Text = "" end)
            return
        end
        local loaded = 0
        local function restoreBool(key)
            if result[key] ~= nil then ctx[key] = result[key]; loaded = loaded + 1 end
        end
        restoreBool("noClipEnabled")
        restoreBool("infJumpEnabled")
        if result.flySpeed then ctx.flySpeed = tonumber(result.flySpeed) or ctx.flySpeed; loaded = loaded + 1 end
        if result.walkSpeed then ctx.walkSpeed = tonumber(result.walkSpeed) or ctx.walkSpeed; loaded = loaded + 1 end
        -- Update GUI
        applyToggle(gui.NoClipToggle.btn, ctx.noClipEnabled, "NoClip")
        applyToggle(gui.InfJumpToggle.btn, ctx.infJumpEnabled, "Infinite Jump")
        gui.FlySpeedLabel.Text = "Fly Speed: " .. ctx.flySpeed
        gui.SpeedLabel.Text = "Walk Speed: " .. ctx.walkSpeed
        gui.SaveStatusLabel.Text = "Loaded " .. loaded .. " settings"
        gui.SaveStatusLabel.TextColor3 = THEME.success
        task.delay(3, function() gui.SaveStatusLabel.Text = "" end)
    end
    ctx.loadSettings = loadSettings

    local function resetSettings()
        pcall(function() if delfile and isfile and isfile(SETTINGS_FILE) then delfile(SETTINGS_FILE) end end)
        gui.SaveStatusLabel.Text = "Reset — reload to apply"
        gui.SaveStatusLabel.TextColor3 = THEME.warn
        task.delay(3, function() gui.SaveStatusLabel.Text = "" end)
    end
    ctx.resetSettings = resetSettings

    -- ═══════════════════════════════════════════
    -- DESTROY
    -- ═══════════════════════════════════════════
    local function destroyAll()
        ctx.destroyed = true
        ctx.clicking = false

        ctx.flyEnabled = false
        ctx.noClipEnabled = false
        ctx.infJumpEnabled = false
        if ctx.flyBodyVelocity and ctx.flyBodyVelocity.Parent then ctx.flyBodyVelocity:Destroy() end
        if ctx.flyBodyGyro and ctx.flyBodyGyro.Parent then ctx.flyBodyGyro:Destroy() end
        if ctx.noclipConnection then pcall(function() ctx.noclipConnection:Disconnect() end) end
        if ctx.infJumpConnection then pcall(function() ctx.infJumpConnection:Disconnect() end) end
        for i = #ctx.connections, 1, -1 do pcall(function() ctx.connections[i]:Disconnect() end); table.remove(ctx.connections, i) end
        pcall(function() gui.ScreenGui:Destroy() end)
    end
    ctx.destroyAll = destroyAll
    _G.__SilentAutoclick_Destroy = destroyAll

    -- Auto-load settings
    task.spawn(function() task.wait(0.5); loadSettings() end)

    return ctx
end
