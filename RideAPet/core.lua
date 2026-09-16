-- RideAPet/core.lua
-- Shared context: services, utilities, ESP, clicker, settings
-- Modules are loaded separately via main.lua
return function(gui, config)
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TextChatService = game:FindService("TextChatService")

    local lp = Players.LocalPlayer
    local mouse = lp:GetMouse()
    local cam = workspace.CurrentCamera

    local TOGGLE_KEY = config.Keys.ToggleRide
    local HIDE_KEY = config.Keys.HideUI
    local PICK_KEY = config.Keys.PickPosition
    local DEFAULT_SPEED = config.Ride.DefaultSpeed

    -- ═══════════════════════════════════════════
    -- SHARED MUTABLE STATE (ctx table)
    -- ═══════════════════════════════════════════
    local ctx = {}

    ctx.gui = gui
    ctx.config = config
    ctx.THEME = gui.Main and gui.Main.BackgroundColor3 and config.Theme or config.Theme
    ctx.lp = lp
    ctx.cam = cam
    ctx.mouse = mouse
    ctx.Players = Players
    ctx.UserInputService = UserInputService
    ctx.RunService = RunService
    ctx.TweenService = TweenService
    ctx.ReplicatedStorage = ReplicatedStorage
    ctx.TextChatService = TextChatService

    -- Mutable state flags
    ctx.rideEnabled = false
    ctx.destroyed = false
    ctx.rideSpeed = DEFAULT_SPEED
    ctx.autoMountEnabled = false
    ctx.espEnabled = false
    ctx.hideUI = false
    ctx.minimized = false
    ctx.draggingUI = false
    ctx.dragStart = nil
    ctx.startPos = nil
    ctx.activeTab = "Ride"
    ctx.antiIdleEnabled = false
    ctx.autoGetEggEnabled = false

    -- Performance tracking
    ctx.perfStartTime = tick()
    ctx.perfRideCount = 0
    ctx.perfEggCount = 0
    ctx.eggRarityLog = {} -- last 5 eggs collected

    -- Collections
    ctx.espObjects = {}
    ctx.playerRows = {}
    ctx.beamStates = {}
    ctx.connections = {}
    ctx.playerConnections = {}
    ctx.antiIdleConnections = {}

    -- ═══════════════════════════════════════════
    -- UTILITY FUNCTIONS
    -- ═══════════════════════════════════════════
    local function bind(signal, fn)
        local c = signal:Connect(fn)
        table.insert(ctx.connections, c)
        return c
    end
    ctx.bind = bind

    local function disconnectList(list)
        for _, c in ipairs(list) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(list)
    end
    ctx.disconnectList = disconnectList

    local function lower(s)
        return string.lower(tostring(s or ""))
    end
    ctx.lower = lower

    local function getHRP(char)
        return char and char:FindFirstChild("HumanoidRootPart")
    end
    ctx.getHRP = getHRP

    local function getHum(char)
        return char and char:FindFirstChildOfClass("Humanoid")
    end
    ctx.getHum = getHum

    -- ═══════════════════════════════════════════
    -- LOGGING SYSTEM
    -- ═══════════════════════════════════════════
    local logEntries = 0
    local MAX_LOG_ENTRIES = 200
    local THEME = config.Theme

    local function log(msg, color)
        color = color or THEME.dim
        logEntries = logEntries + 1
        if logEntries > MAX_LOG_ENTRIES then
            local children = gui.Logs.LogScroll:GetChildren()
            for _, child in ipairs(children) do
                if child:IsA("TextLabel") then
                    child:Destroy()
                    break
                end
            end
            logEntries = logEntries - 1
        end

        local timestamp = os.date("%H:%M:%S")
        local entry = Instance.new("TextLabel")
        entry.Size = UDim2.new(1, -8, 0, 16)
        entry.BackgroundTransparency = 1
        entry.Text = "[" .. timestamp .. "] " .. tostring(msg)
        entry.TextColor3 = color
        entry.Font = Enum.Font.Code
        entry.TextSize = 11
        entry.TextXAlignment = Enum.TextXAlignment.Left
        entry.TextWrapped = true
        entry.AutomaticSize = Enum.AutomaticSize.Y
        entry.Parent = gui.Logs.LogScroll

        gui.Logs.LogCount.Text = logEntries .. " entries"

        task.defer(function()
            gui.Logs.LogScroll.CanvasPosition = Vector2.new(0, gui.Logs.LogScroll.AbsoluteCanvasSize.Y)
        end)
    end
    ctx.log = log

    -- Clear logs button
    bind(gui.Logs.ClearLogsBtn.MouseButton1Click, function()
        for _, child in ipairs(gui.Logs.LogScroll:GetChildren()) do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        logEntries = 0
        gui.Logs.LogCount.Text = "0 entries"
    end)

    -- ═══════════════════════════════════════════
    -- PLAYER ESP
    -- ═══════════════════════════════════════════
    local function removeESPForPlayer(player)
        local obj = ctx.espObjects[player]
        if not obj then return end
        if obj.billboard then obj.billboard:Destroy() end
        if obj.box then obj.box:Destroy() end
        ctx.espObjects[player] = nil
    end
    ctx.removeESPForPlayer = removeESPForPlayer

    local function makeESPForPlayer(player)
        if ctx.espObjects[player] then return end
        if player == lp then return end

        local box = Instance.new("BoxHandleAdornment")
        box.Name = "ESP_Box"
        box.Size = Vector3.new(2, 5, 1)
        box.Color3 = THEME.accent
        box.AlwaysOnTop = true
        box.Transparency = 0.45
        box.ZIndex = 5
        box.SizeRelativeOffset = Vector3.new(0, 0.5, 0)

        local bb = Instance.new("BillboardGui")
        bb.Name = "ESP_Tag"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 120, 0, 28)
        bb.StudsOffset = Vector3.new(0, 3, 0)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = player.Name
        lbl.TextColor3 = THEME.accent
        lbl.TextStrokeTransparency = 0
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.Parent = bb

        local function attach(char)
            local hrp = getHRP(char)
            if hrp then
                box.Adornee = hrp
                box.Parent = hrp
                bb.Adornee = hrp
                bb.Parent = hrp
            end
        end

        if player.Character then attach(player.Character) end
        ctx.playerConnections[player] = ctx.playerConnections[player] or {}
        table.insert(ctx.playerConnections[player], player.CharacterAdded:Connect(attach))
        ctx.espObjects[player] = { box = box, billboard = bb }
    end
    ctx.makeESPForPlayer = makeESPForPlayer

    local function toggleAllESP()
        ctx.espEnabled = not ctx.espEnabled
        if ctx.espEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= lp then
                    makeESPForPlayer(player)
                end
            end
            gui.ESPToggleBtn.Text = "Toggle ESP [" .. tostring(config.Keys.ESP):gsub("Enum.KeyCode.", "") .. "] ✓"
            gui.ESPToggleBtn.BackgroundColor3 = THEME.success
            log("ESP: ON", THEME.success)
        else
            for player in pairs(ctx.espObjects) do
                removeESPForPlayer(player)
            end
            gui.ESPToggleBtn.Text = "Toggle ESP [" .. tostring(config.Keys.ESP):gsub("Enum.KeyCode.", "") .. "]"
            gui.ESPToggleBtn.BackgroundColor3 = THEME.accent
            log("ESP: OFF", THEME.dim)
        end
    end
    ctx.toggleAllESP = toggleAllESP

    bind(gui.ESPToggleBtn.MouseButton1Click, toggleAllESP)

    -- ═══════════════════════════════════════════
    -- RIDE FUNCTIONS
    -- ═══════════════════════════════════════════
    local function updateRideUI()
        if ctx.rideEnabled then
            gui.RideToggleBtn.Text = "Stop Ride [" .. tostring(config.Keys.ToggleRide):gsub("Enum.KeyCode.", "") .. "]"
            gui.RideToggleBtn.BackgroundColor3 = THEME.danger
            gui.RideSpeedLabel.Text = "Speed: " .. ctx.rideSpeed
        else
            gui.RideToggleBtn.Text = "Toggle Ride [" .. tostring(config.Keys.ToggleRide):gsub("Enum.KeyCode.", "") .. "]"
            gui.RideToggleBtn.BackgroundColor3 = THEME.accent
        end
    end
    ctx.updateRideUI = updateRideUI

    local function toggleRide()
        ctx.rideEnabled = not ctx.rideEnabled
        if ctx.rideEnabled then
            log("Ride: ON (speed " .. ctx.rideSpeed .. ")", THEME.success)
        else
            log("Ride: OFF", THEME.danger)
        end
        updateRideUI()
    end
    ctx.toggleRide = toggleRide

    bind(gui.RideToggleBtn.MouseButton1Click, toggleRide)

    -- ═══════════════════════════════════════════
    -- ANTI IDLE
    -- ═══════════════════════════════════════════
    local function enableAntiIdle()
        ctx.antiIdleEnabled = true
        local VirtualUser = game:GetService("VirtualUser")
        local success = pcall(function()
            if getconnections then
                for _, connection in pairs(getconnections(lp.Idled)) do
                    if connection["Disable"] then
                        connection["Disable"](connection)
                    elseif connection["Disconnect"] then
                        connection["Disconnect"](connection)
                    end
                end
            end
        end)
        if not success then
            local c = lp.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
            table.insert(ctx.antiIdleConnections, c)
        end
        gui.AntiIdleBtn.Text = "Anti Idle: ON"
        gui.AntiIdleBtn.BackgroundColor3 = THEME.success
        log("Anti Idle: ON", THEME.success)
    end

    local function disableAntiIdle()
        ctx.antiIdleEnabled = false
        for _, c in ipairs(ctx.antiIdleConnections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(ctx.antiIdleConnections)
        gui.AntiIdleBtn.Text = "Anti Idle: OFF"
        gui.AntiIdleBtn.BackgroundColor3 = THEME.warn
        log("Anti Idle: OFF", THEME.dim)
    end

    if gui.AntiIdleBtn then
        bind(gui.AntiIdleBtn.MouseButton1Click, function()
            if ctx.antiIdleEnabled then
                disableAntiIdle()
            else
                enableAntiIdle()
            end
        end)
    end

    -- ═══════════════════════════════════════════
    -- UNLOAD / DESTROY
    -- ═══════════════════════════════════════════
    local function destroyAll()
        log("Script unloading...", THEME.danger)
        ctx.rideEnabled = false
        ctx.destroyed = true
        ctx.espEnabled = false
        ctx.antiIdleEnabled = false
        ctx.autoGetEggEnabled = false
        ctx.eggRarityLog = {}
        -- Clear nearby egg ESP
        pcall(function()
            if ctx._clearEggESP then ctx._clearEggESP() end
        end)
        _G.__RideAPet_Destroy = nil
        disconnectList(ctx.connections)
        disconnectList(ctx.antiIdleConnections)
        for player in pairs(ctx.espObjects) do removeESPForPlayer(player) end
        for _, list in pairs(ctx.playerConnections) do disconnectList(list) end
        task.wait(0.05)
        pcall(function() gui.MainGui:Destroy() end)
    end
    ctx.destroyAll = destroyAll

    _G.__RideAPet_Destroy = destroyAll

    bind(gui.CloseBtn.MouseButton1Click, destroyAll)

    if gui.UnloadBtn then
        bind(gui.UnloadBtn.MouseButton1Click, destroyAll)
    end

    -- ═══════════════════════════════════════════
    -- KEYBINDS
    -- ═══════════════════════════════════════════
    bind(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == TOGGLE_KEY then
            toggleRide()
        elseif input.KeyCode == HIDE_KEY then
            ctx.hideUI = not ctx.hideUI
            gui.Main.Visible = not ctx.hideUI
        elseif input.KeyCode == config.Keys.ESP then
            toggleAllESP()
        elseif input.KeyCode == config.Keys.ToggleEgg then
            -- Handled by auto_get_egg module
        end
    end)

    -- ═══════════════════════════════════════════
    -- HEARTBEAT LOOP
    -- ═══════════════════════════════════════════
    task.spawn(function()
        while not ctx.destroyed do
            if ctx.rideEnabled then
                -- Ride logic will be handled by auto_ride module
            end
            task.wait(0.1)
        end
    end)

    log("Core initialized", THEME.success)
    return ctx
end
