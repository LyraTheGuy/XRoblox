-- IndoHangout/modules/misc.lua
-- Fly, WalkSpeed, and Noclip. All state is toggled via the Misc tab and can
-- be re-applied after respawn. Everything stops cleanly on Stop()/Destroy().

return function(ctx)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local lp = Players.LocalPlayer
    local THEME = ctx.config.Theme
    local gui = ctx.gui

    local page = gui.TabPages.Misc
    local Misc = {}

    -- Runtime state
    local flyEnabled = false
    local flySpeed = ctx.config.Misc.FlySpeed
    local flyConnection = nil
    -- Modern actuators: LinearVelocity + AlignOrientation on an Attachment
    -- (replaces the deprecated BodyVelocity/BodyGyro).
    local flyAttachment = nil
    local flyLinearVelocity = nil
    local flyAlignOrientation = nil

    local walkSpeedEnabled = false
    local walkSpeedValue = ctx.config.Misc.WalkSpeed
    local walkSpeedConnection = nil

    local noclipEnabled = false
    local noclipConnection = nil

    -- Saved defaults (for restoring)
    local originalWalkSpeed = 16
    local originalJumpPower = 50

    ---------------------------------------------------------------------
    -- CHARACTER HELPERS
    ---------------------------------------------------------------------
    local function getCharacter()
        return lp.Character
    end

    local function getHumanoid()
        local char = getCharacter()
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function getRoot()
        local char = getCharacter()
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    ---------------------------------------------------------------------
    -- FLY
    ---------------------------------------------------------------------
    local function stopFly()
        flyEnabled = false
        if flyConnection then
            pcall(function() flyConnection:Disconnect() end)
            flyConnection = nil
        end
        local char = getCharacter()
        if flyAttachment then pcall(function() flyAttachment:Destroy() end); flyAttachment = nil end
        if flyLinearVelocity then pcall(function() flyLinearVelocity:Destroy() end); flyLinearVelocity = nil end
        if flyAlignOrientation then pcall(function() flyAlignOrientation:Destroy() end); flyAlignOrientation = nil end
        local hum = getHumanoid()
        if hum then
            pcall(function()
                hum.PlatformStand = false
                local hrp = getRoot()
                if hrp then
                    -- Remove our actuators plus any legacy Body* handlers
                    for _, v in ipairs(hrp:GetChildren()) do
                        if v.Name == "IndoFlyAttachment" or v.Name == "IndoFlyVelocity"
                            or v.Name == "IndoFlyOrientation"
                            or v:IsA("BodyVelocity") or v:IsA("BodyGyro")
                            or v:IsA("LinearVelocity") or v:IsA("AlignOrientation")
                            or (v:IsA("Attachment") and v.Name:find("IndoFly")) then
                            pcall(function() v:Destroy() end)
                        end
                    end
                end
            end)
        end
    end

    local function startFly()
        local char = getCharacter()
        local hum = getHumanoid()
        local hrp = getRoot()
        if not char or not hum or not hrp then return false end
        local camera = workspace.CurrentCamera

        -- Set character to platform stand to prevent gravity fighting
        pcall(function() hum.PlatformStand = true end)

        -- Create the attachment + modern actuators (LinearVelocity/AlignOrientation)
        local att = Instance.new("Attachment")
        att.Name = "IndoFlyAttachment"
        att.Parent = hrp
        flyAttachment = att

        local lv = Instance.new("LinearVelocity")
        lv.Name = "IndoFlyVelocity"
        lv.Attachment0 = att
        lv.MaxForce = 1e6
        lv.RelativeTo = Enum.ActuatorRelativeTo.World
        lv.Velocity = Vector3.zero
        lv.Parent = hrp
        flyLinearVelocity = lv

        local ao = Instance.new("AlignOrientation")
        ao.Name = "IndoFlyOrientation"
        ao.Attachment0 = att
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.RigidityEnabled = true
        ao.Responsiveness = 50
        ao.MaxTorque = 1e6
        ao.CFrame = camera.CFrame
        ao.Parent = hrp
        flyAlignOrientation = ao

        flyEnabled = true

        -- Update loop
        flyConnection = RunService.Heartbeat:Connect(function()
            if not flyEnabled or ctx.destroyed then return end
            local c = getCharacter()
            local h = getHumanoid()
            local root = getRoot()
            if not c or not h or not root or h.Health <= 0 then return end

            -- Direction from camera-relative inputs
            local camera = workspace.CurrentCamera
            local direction = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                direction += camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                direction -= camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                direction -= camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                direction += camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                direction += Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                direction -= Vector3.new(0, 1, 0)
            end

            if direction.Magnitude > 0 then
                direction = direction.Unit
            end

            lv.Velocity = direction * flySpeed
            ao.CFrame = camera.CFrame
        end)

        ctx.log("Fly: ON", THEME.success)
        return true
    end

    ---------------------------------------------------------------------
    -- WALKSPEED
    ---------------------------------------------------------------------
    local function applyWalkSpeed()
        local hum = getHumanoid()
        if hum and walkSpeedEnabled then
            pcall(function() hum.WalkSpeed = walkSpeedValue end)
        end
    end

    local function startWalkSpeed()
        walkSpeedEnabled = true
        applyWalkSpeed()
        ctx.log("WalkSpeed: ON (" .. tostring(walkSpeedValue) .. ")", THEME.success)
    end

    local function stopWalkSpeed()
        walkSpeedEnabled = false
        local hum = getHumanoid()
        if hum then
            pcall(function()
                local orig = ctx.originalWalkSpeed or 16
                hum.WalkSpeed = orig
            end)
        end
    end

    ---------------------------------------------------------------------
    -- NOCLIP
    ---------------------------------------------------------------------
    local function stopNoclip()
        noclipEnabled = false
        if noclipConnection then
            pcall(function() noclipConnection:Disconnect() end)
            noclipConnection = nil
        end
        local char = getCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function() part.CanCollide = true end)
                end
            end
        end
    end

    local function startNoclip()
        noclipEnabled = true
        noclipConnection = RunService.Stepped:Connect(function()
            if not noclipEnabled or ctx.destroyed then return end
            local char = getCharacter()
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    pcall(function() part.CanCollide = false end)
                end
            end
        end)
        ctx.log("Noclip: ON", THEME.success)
    end

    ---------------------------------------------------------------------
    -- RESPAWN HANDLER
    ---------------------------------------------------------------------
    function Misc.onCharacter(char)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            -- capture defaults from first character
            if ctx.originalWalkSpeed == nil or ctx.originalWalkSpeed == 16 then
                ctx.originalWalkSpeed = hum.WalkSpeed
            end
            if ctx.originalJumpPower == nil or ctx.originalJumpPower == 50 then
                ctx.originalJumpPower = hum.JumpPower
            end
        end
        task.wait(0.5)
        if flyEnabled then
            stopFly()
            task.wait(0.2)
            startFly()
        end
        if walkSpeedEnabled then
            applyWalkSpeed()
        end
    end

    ---------------------------------------------------------------------
    -- PUBLIC CONTROLS
    ---------------------------------------------------------------------
    function Misc.setFlyEnabled(enabled)
        enabled = enabled and true or false
        if enabled then
            startFly()
        else
            stopFly()
        end
    end

    function Misc.setFlySpeed(speed)
        flySpeed = math.max(1, tonumber(speed) or 50)
    end

    function Misc.setWalkSpeedEnabled(enabled)
        enabled = enabled and true or false
        if enabled then
            startWalkSpeed()
        else
            stopWalkSpeed()
        end
    end

    function Misc.setWalkSpeedValue(value)
        walkSpeedValue = math.max(1, tonumber(value) or 16)
        if walkSpeedEnabled then
            applyWalkSpeed()
        end
    end

    function Misc.setNoclipEnabled(enabled)
        enabled = enabled and true or false
        if enabled then
            startNoclip()
        else
            stopNoclip()
        end
    end

    -- Called by settings.applySettings()
    function Misc.applySettings(data)
        if type(data) ~= "table" then return end
        if data.FlySpeed then Misc.setFlySpeed(data.FlySpeed) end
        if data.WalkSpeed then Misc.setWalkSpeedValue(data.WalkSpeed) end
        if data.Fly ~= nil then Misc.setFlyEnabled(data.Fly) end
        if data.WalkSpeedEnabled ~= nil then Misc.setWalkSpeedEnabled(data.WalkSpeedEnabled) end
        if data.Noclip ~= nil then Misc.setNoclipEnabled(data.Noclip) end
    end

    ---------------------------------------------------------------------
    -- UI BUILD
    ---------------------------------------------------------------------
    local function buildUI()
        if not page then return end
        local c = gui.components

        c.createSectionLabel(page.container, "Movement")
        c.createToggle(page.container, "Fly", false, function(val)
            Misc.setFlyEnabled(val)
        end)
        c.createSlider(page.container, "Fly Speed", 10, 200, flySpeed, 1, function(val)
            Misc.setFlySpeed(val)
        end)

        c.createSectionLabel(page.container, "Speed")
        c.createToggle(page.container, "Enable WalkSpeed", false, function(val)
            Misc.setWalkSpeedEnabled(val)
        end)
        c.createSlider(page.container, "WalkSpeed", 1, 200, walkSpeedValue, 1, function(val)
            Misc.setWalkSpeedValue(val)
        end)

        c.createSectionLabel(page.container, "Collision")
        c.createToggle(page.container, "Noclip", false, function(val)
            Misc.setNoclipEnabled(val)
        end)
    end

    ---------------------------------------------------------------------
    -- LIFECYCLE
    ---------------------------------------------------------------------
    function Misc.Init()
        buildUI()
        ctx.onCharacter = Misc.onCharacter
    end

    function Misc.Start() end
    function Misc.Stop()
        stopFly()
        stopWalkSpeed()
        stopNoclip()
    end
    function Misc.Destroy()
        Misc.Stop()
    end

    -- Ensure clean stop on destroy
    ctx.registerCleanup(function() Misc.Stop() end)

    return Misc
end