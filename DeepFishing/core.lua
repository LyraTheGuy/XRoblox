-- DeepFishing/core.lua
-- Shared context: services, utilities, game interaction, logging
return function(gui, config)
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local StarterGui = game:GetService("StarterGui")

    local lp = Players.LocalPlayer
    local mouse = lp:GetMouse()
    local cam = workspace.CurrentCamera

    local THEME = gui.Theme

    -- ═══════════════════════════════════════════
    -- SHARED MUTABLE STATE (ctx table)
    -- ═══════════════════════════════════════════
    local ctx = {}

    ctx.gui = gui
    ctx.config = config
    ctx.THEME = THEME
    ctx.lp = lp
    ctx.cam = cam
    ctx.mouse = mouse
    ctx.Players = Players
    ctx.UserInputService = UserInputService
    ctx.RunService = RunService
    ctx.TweenService = TweenService
    ctx.ReplicatedStorage = ReplicatedStorage

    -- Mutable state flags
    ctx.destroyed = false
    ctx.autoFishEnabled = false
    ctx.autoSellEnabled = false
    ctx.autoDeleteEnabled = false
    ctx.autoBuyBaitEnabled = false
    ctx.autoBuyRodEnabled = false
    ctx.autoBuyUpgradesEnabled = false
    ctx.flyEnabled = false
    ctx.noClipEnabled = false
    ctx.infJumpEnabled = false
    ctx.antiAfkEnabled = false
    ctx.antiPauseEnabled = false
    ctx.autoClaimFreeEnabled = false
    ctx.autoClaimBigFishEnabled = false
    ctx.autoClaimPlaytimeEnabled = false
    ctx.autoClaimNextDayEnabled = false
    ctx.autoClaimGroupEnabled = false
    ctx.instantCollectEnabled = true
    ctx.autoStopWhenEmptyEnabled = true
    ctx.collectAllRaritiesEnabled = true
    ctx.collectMutationsEnabled = true

    -- Movement state
    ctx.flySpeed = config.Movement.FlySpeed or 50
    ctx.walkSpeed = config.Movement.WalkSpeed or 16
    ctx.flyBodyVelocity = nil
    ctx.flyBodyGyro = nil
    ctx.noclipConnection = nil
    ctx.infJumpConnection = nil

    -- Performance tracking
    ctx.perfStartTime = tick()
    ctx.perfFishCaught = 0
    ctx.perfTotalEarnings = 0

    -- Collections
    ctx.connections = {}

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

    -- ═══════════════════════════════════════════
    -- LOGGING SYSTEM
    -- ═══════════════════════════════════════════
    local logEntries = 0
    local MAX_LOG_ENTRIES = 200

    local function log(msg, color)
        color = color or THEME.dim
        logEntries = logEntries + 1
        if logEntries > MAX_LOG_ENTRIES then
            local children = gui.Settings.LogScroll:GetChildren()
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
        entry.Size = UDim2.new(1, -8, 0, 14)
        entry.BackgroundTransparency = 1
        entry.Text = "[" .. timestamp .. "] " .. tostring(msg)
        entry.TextColor3 = color
        entry.Font = Enum.Font.Code
        entry.TextSize = 10
        entry.TextXAlignment = Enum.TextXAlignment.Left
        entry.TextWrapped = true
        entry.AutomaticSize = Enum.AutomaticSize.Y
        entry.Parent = gui.Settings.LogScroll

        gui.Settings.LogCountLabel.Text = logEntries .. " entries"

        task.defer(function()
            gui.Settings.LogScroll.CanvasPosition = Vector2.new(0, gui.Settings.LogScroll.AbsoluteCanvasSize.Y)
        end)
    end
    ctx.log = log

    -- Clear logs
    bind(gui.Settings.LogScroll.Parent.ClearLogsBtn and gui.Settings.LogScroll.Parent.ClearLogsBtn.MouseButton1Click or Instance.new("BindableEvent").Event, function() end)

    -- ═══════════════════════════════════════════
    -- CHARACTER UTILITIES
    -- ═══════════════════════════════════════════
    local function getHRP(char)
        return char and char:FindFirstChild("HumanoidRootPart")
    end
    ctx.getHRP = getHRP

    local function getHum(char)
        return char and char:FindFirstChildOfClass("Humanoid")
    end
    ctx.getHum = getHum

    local function getCharacter()
        return lp.Character or lp.CharacterAdded:Wait()
    end
    ctx.getCharacter = getCharacter

    -- ═══════════════════════════════════════════
    -- GAME MODULE ACCESS
    -- Deep Fishing uses ReplicatedStorage modules
    -- ═══════════════════════════════════════════
    local gameModules = {}
    ctx.gameModules = gameModules

    -- Try to find and cache game modules
    task.spawn(function()
        local rs = ReplicatedStorage
        -- Wait for game modules to load
        local success, err = pcall(function()
            -- Try common module paths for Deep Fishing
            local modulesFolder = rs:WaitForChild("Modules", 10)
            if modulesFolder then
                gameModules.Fishing = modulesFolder:FindFirstChild("Fishing")
                gameModules.Bait = modulesFolder:FindFirstChild("Bait")
                gameModules.Shop = modulesFolder:FindFirstChild("Shop")
                gameModules.Data = modulesFolder:FindFirstChild("Data")
            end

            -- Try to find remotes
            local remotesFolder = rs:WaitForChild("Remotes", 10)
                or rs:WaitForChild("RemoteEvents", 10)
                or rs:WaitForChild("RemoteFunctions", 10)
            if remotesFolder then
                gameModules.Remotes = remotesFolder
            end

            -- Try to find fishing controller
            local controllersFolder = rs:WaitForChild("Controllers", 10)
                or rs:WaitForChild("Modules"):FindFirstChild("Controllers", 5)
            if controllersFolder then
                gameModules.FishingController = controllersFolder:FindFirstChild("FishingController")
                    or controllersFolder:FindFirstChild("Fishing")
            end
        end)
        if not success then
            log("Game modules: " .. tostring(err), THEME.warn)
        end
    end)

    -- ═══════════════════════════════════════════
    -- FISHING REMOTE ACCESS
    -- ═══════════════════════════════════════════
    local fishingRemotes = {}
    ctx.fishingRemotes = fishingRemotes

    task.spawn(function()
        local rs = ReplicatedStorage
        -- Deep Fishing remotes are typically under ReplicatedStorage
        local function findRemote(name)
            local ok, result = pcall(function()
                return rs:WaitForChild(name, 5)
            end)
            if ok and result then return result end

            -- Search in subfolders
            for _, folder in ipairs(rs:GetChildren()) do
                if folder:IsA("Folder") then
                    local child = folder:FindFirstChild(name, true)
                    if child then return child end
                end
            end
            return nil
        end

        -- Common Deep Fishing remote names
        local remoteNames = {
            "SellAll", "SellFish", "Sell",
            "BuyBait", "BuyRod", "BuyUpgrade",
            "RedeemCode", "ClaimReward", "ClaimPlaytime",
            "ClaimNextDay", "ClaimGroup",
            "UseBait", "Throw", "Reel",
            "EquipRod", "StartFishing", "StopFishing",
        }

        for _, name in ipairs(remoteNames) do
            local remote = findRemote(name)
            if remote then
                fishingRemotes[name] = remote
            end
        end

        log("Found " .. tostring(#remoteNames) .. " remote candidates", THEME.dim)
    end)

    -- ═══════════════════════════════════════════
    -- SELL UTILITIES
    -- ═══════════════════════════════════════════
    ctx.SellRemote = nil

    task.spawn(function()
        -- Wait for sell remote
        local sellNames = { "SellAll", "SellFish", "Sell", "SellAllFish" }
        for _, name in ipairs(sellNames) do
            local ok, remote = pcall(function()
                return ReplicatedStorage:WaitForChild(name, 5)
            end)
            if ok and remote then
                ctx.SellRemote = remote
                log("Sell remote found: " .. name, THEME.success)
                break
            end
        end

        -- Also search in subfolders
        if not ctx.SellRemote then
            for _, folder in ipairs(ReplicatedStorage:GetChildren()) do
                if folder:IsA("Folder") then
                    for _, name in ipairs(sellNames) do
                        local child = folder:FindFirstChild(name, true)
                        if child then
                            ctx.SellRemote = child
                            log("Sell remote found: " .. folder.Name .. "/" .. name, THEME.success)
                            break
                        end
                    end
                    if ctx.SellRemote then break end
                end
            end
        end
    end)

    local function performSell()
        local hrp = getHRP(lp.Character)
        if not hrp then return false, "No character" end

        if ctx.SellRemote then
            local ok, result = pcall(function()
                if ctx.SellRemote:IsA("RemoteFunction") then
                    return ctx.SellRemote:InvokeServer()
                elseif ctx.SellRemote:IsA("RemoteEvent") then
                    ctx.SellRemote:FireServer()
                    return "Fired"
                end
            end)
            if ok then
                ctx.perfTotalEarnings = ctx.perfTotalEarnings + 1
                return true, result
            end
            return false, tostring(result)
        end
        return false, "Sell remote not found"
    end
    ctx.performSell = performSell

    -- ═══════════════════════════════════════════
    -- ANTI-IDLE
    -- ═══════════════════════════════════════════
    ctx.antiIdleConnections = {}

    local function enableAntiIdle()
        ctx.antiAfkEnabled = true
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
        log("Anti AFK: ON", THEME.success)
    end

    local function disableAntiIdle()
        ctx.antiAfkEnabled = false
        for _, c in ipairs(ctx.antiIdleConnections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(ctx.antiIdleConnections)
        log("Anti AFK: OFF", THEME.dim)
    end
    ctx.enableAntiIdle = enableAntiIdle
    ctx.disableAntiIdle = disableAntiIdle

    -- ═══════════════════════════════════════════
    -- THEME APPLICATION
    -- ═══════════════════════════════════════════
    local function applyTheme()
        gui.Main.BackgroundColor3 = THEME.bg
        gui.MainStroke.Color = THEME.accent
        gui.Title.TextColor3 = THEME.text
        gui.Subtitle.TextColor3 = THEME.dim
    end
    ctx.applyTheme = applyTheme

    -- ═══════════════════════════════════════════
    -- DESTROY ALL
    -- ═══════════════════════════════════════════
    local function destroyAll()
        log("Script unloading...", THEME.danger)
        ctx.destroyed = true
        ctx.autoFishEnabled = false
        ctx.autoSellEnabled = false
        ctx.autoDeleteEnabled = false
        ctx.autoBuyBaitEnabled = false
        ctx.autoBuyRodEnabled = false
        ctx.autoBuyUpgradesEnabled = false
        ctx.flyEnabled = false
        ctx.noClipEnabled = false
        ctx.infJumpEnabled = false
        ctx.antiAfkEnabled = false
        ctx.antiPauseEnabled = false

        -- Clean up fly
        if ctx.flyBodyVelocity and ctx.flyBodyVelocity.Parent then ctx.flyBodyVelocity:Destroy() end
        if ctx.flyBodyGyro and ctx.flyBodyGyro.Parent then ctx.flyBodyGyro:Destroy() end

        -- Clean up noclip
        if ctx.noclipConnection then pcall(function() ctx.noclipConnection:Disconnect() end) end

        -- Clean up inf jump
        if ctx.infJumpConnection then pcall(function() ctx.infJumpConnection:Disconnect() end) end

        -- Clean up anti-idle
        for _, c in ipairs(ctx.antiIdleConnections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(ctx.antiIdleConnections)

        -- Disconnect all
        disconnectList(ctx.connections)

        pcall(function() gui.ScreenGui:Destroy() end)
    end
    ctx.destroyAll = destroyAll
    _G.__DeepFishing_Destroy = destroyAll

    return ctx
end
