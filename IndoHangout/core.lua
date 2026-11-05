-- IndoHangout/core.lua
-- Shared context: mutable state, bind/disconnect helpers, cleanup engine.
-- Every feature module receives the same `ctx` and registers cleanup handlers.
-- destroyAll runs all cleanup handlers in reverse order, then destroys the GUI.

return function(gui, config)
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local THEME = config.Theme
    local lp = Players.LocalPlayer

    local ctx = {
        gui = gui,
        config = config,
        destroyed = false,
        connections = {},
        cleanupHandlers = {},
        log = nil,          -- added below
        registerCleanup = nil, -- added below
        destroyAll = nil,   -- added below
        setStatus = gui.setStatus,

        -- Feature module handles (populated as modules load)
        fishing = nil,
        mining = nil,
        misc = nil,
        settings = nil,

        -- Misc runtime state
        originalWalkSpeed = 16,
        originalJumpPower = 50,
    }

    ---------------------------------------------------------------------
    -- LOGGING + STATUS
    ---------------------------------------------------------------------
    local function log(msg, color)
        local text = "[IndoHangout] " .. tostring(msg)
        local c = color or THEME.text
        print(text)
        ctx.setStatus(tostring(msg), c)
    end
    ctx.log = log

    ---------------------------------------------------------------------
    -- CONNECTION TRACKING
    ---------------------------------------------------------------------
    local function bind(signal, fn)
        local ok, conn = pcall(function()
            return signal:Connect(fn)
        end)
        if ok and conn then
            table.insert(ctx.connections, conn)
            return conn
        end
        return nil
    end
    ctx.bind = bind

    local function disconnectList(list)
        if type(list) ~= "table" then return end
        for _, conn in ipairs(list) do
            pcall(function()
                if conn and conn.Connected then
                    conn:Disconnect()
                end
            end)
        end
        table.clear(list)
    end
    ctx.disconnectList = disconnectList

    ---------------------------------------------------------------------
    -- CLEANUP REGISTRY
    ---------------------------------------------------------------------
    local function registerCleanup(fn)
        if type(fn) == "function" then
            table.insert(ctx.cleanupHandlers, fn)
        end
    end
    ctx.registerCleanup = registerCleanup

    ---------------------------------------------------------------------
    -- CHARACTER / RESPAWN TRACKING
    ---------------------------------------------------------------------
    -- Called whenever the local character changes. Feature modules can hook
    -- into ctx.onCharacter to reapply things like walk speed, fly, noclip.
    ctx.onCharacter = nil
    local characterAddedConn = nil
    local function handleCharacter(char)
        if not char then return end
        ctx.character = char
        ctx.humanoid = char:FindFirstChildOfClass("Humanoid")
        pcall(function()
            if ctx.onCharacter then
                ctx.onCharacter(char)
            end
        end)
    end

    local function watchCharacter()
        if characterAddedConn then
            pcall(function() characterAddedConn:Disconnect() end)
        end
        characterAddedConn = lp.CharacterAdded:Connect(handleCharacter)
        ctx.connections = ctx.connections or {}
        table.insert(ctx.connections, characterAddedConn)
        spawn(function()
            local char = lp.Character or lp.CharacterAdded:Wait()
            handleCharacter(char)
        end)
    end
    ctx.watchCharacter = watchCharacter

    ---------------------------------------------------------------------
    -- SIMULATED INPUT HELPER
    ---------------------------------------------------------------------
    -- Tracks currently-pressed mouse buttons so cleanup can release them.
    ctx.pressedButtons = {}
    function ctx.pressVirtualButton(btn, press)
        if type(VirtualInputManager.SendMouseButtonEvent) ~= "function" then
            return false
        end
        local ok = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, btn, press, game, 1)
        end)
        if ok then
            if press then
                table.insert(ctx.pressedButtons, btn)
            else
                for i, v in ipairs(ctx.pressedButtons) do
                    if v == btn then
                        table.remove(ctx.pressedButtons, i)
                        break
                    end
                end
            end
        end
        return ok
    end

    function ctx.releaseAllButtons()
        for idx, btn in ipairs(ctx.pressedButtons) do
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, btn, false, game, 1)
            end)
        end
        table.clear(ctx.pressedButtons)
    end

    ---------------------------------------------------------------------
    -- FEATURE-STOP FUNCTIONS (called by destroyAll)
    ---------------------------------------------------------------------
    -- These call the registered module stoppers if they exist.
    local function stopFishing()
        if ctx.fishing and type(ctx.fishing.stopAll) == "function" then
            pcall(ctx.fishing.stopAll)
        else
            ctx.config.Fishing.AutoFish = false
            pcall(ctx.releaseAllButtons)
        end
    end

    local function stopMining()
        if ctx.mining and type(ctx.mining.stopAll) == "function" then
            pcall(ctx.mining.stopAll)
        else
            ctx.config.Mining.AutoMine = false
        end
    end

    local function stopMisc()
        if ctx.misc and type(ctx.misc.stopAll) == "function" then
            pcall(ctx.misc.stopAll)
        else
            ctx.config.Misc.Fly = false
            ctx.config.Misc.Noclip = false
            ctx.config.Misc.WalkSpeedEnabled = false
        end
    end

    ---------------------------------------------------------------------
    -- HUMAN RESTORATION (always attempt, using base default values)
    ---------------------------------------------------------------------
    local function restoreHumanoid()
        pcall(function()
            local char = lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            hum.WalkSpeed = ctx.originalWalkSpeed or 16
            hum.JumpPower = ctx.originalJumpPower or 50
            hum.Jump = true
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CanCollide = true
            end
        end)
    end
    ctx.restoreHumanoid = restoreHumanoid

    ---------------------------------------------------------------------
    -- DESTROY ALL
    ---------------------------------------------------------------------
    local function destroyAll()
        if ctx.destroyed then return end
        ctx.destroyed = true
        log("Unloading IndoHangout...", THEME.danger)

        -- 1) Flag every feature off so in-flight loops exit on their next check
        ctx.config.Fishing.AutoFish = false
        ctx.config.Fishing.AutoSellFish = false
        ctx.config.Mining.AutoMine = false
        ctx.config.Mining.AutoSellCrystals = false
        ctx.config.Misc.Fly = false
        ctx.config.Misc.Noclip = false
        ctx.config.Misc.WalkSpeedEnabled = false

        -- 2) Explicitly stop each feature group (they also restore state)
        stopFishing()
        stopMining()
        stopMisc()

        -- 3) Restore humanoid state
        restoreHumanoid()

        -- 4) Release any pressed simulated buttons
        pcall(ctx.releaseAllButtons)

        -- 5) Run registered cleanup handlers in REVERSE order (modules unload)
        --    (reverse keeps dependencies ordering safe: last created, first destroyed)
        for i = #ctx.cleanupHandlers, 1, -1 do
            pcall(ctx.cleanupHandlers[i])
        end

        -- 6) Stop feature loops one more time after cleanup handlers ran
        --    (some modules may have re-enabled loops; this makes sure they stop)
        ctx.config.Fishing.AutoFish = false
        ctx.config.Fishing.AutoSellFish = false
        ctx.config.Mining.AutoMine = false
        ctx.config.Mining.AutoSellCrystals = false
        ctx.config.Misc.Fly = false
        ctx.config.Misc.Noclip = false
        ctx.config.Misc.WalkSpeedEnabled = false
        pcall(ctx.releaseAllButtons)
        restoreHumanoid()

        -- 7) Disconnect all connections
        disconnectList(ctx.connections)
        if characterAddedConn then
            pcall(function() characterAddedConn:Disconnect() end)
            characterAddedConn = nil
        end

        -- 8) Destroy the ScreenGui
        pcall(function()
            if gui and gui.Destroy then
                gui.Destroy()
            elseif gui and gui.ScreenGui then
                gui.ScreenGui:Destroy()
            end
        end)

        -- 9) Release global duplicate-GUI guard
        pcall(function()
            _G.__IndoHangout_Destroy = nil
            _G.__IndoHangout_Gui = nil
        end)

        log("IndoHangout unloaded cleanly.")
    end
    ctx.destroyAll = destroyAll

    -- Register global duplicate-run guard
    _G.__IndoHangout_Destroy = destroyAll

    ---------------------------------------------------------------------
    -- STARTUP
    ---------------------------------------------------------------------
    watchCharacter()
    log("IndoHangout loaded", THEME.accentGlow)

    -- Bind close button to ctx.destroyAll so any wrapping in main.lua applies.
    if gui.CloseBtn then
        bind(gui.CloseBtn.MouseButton1Click, function()
            ctx.destroyAll()
        end)
    end

    return ctx
end