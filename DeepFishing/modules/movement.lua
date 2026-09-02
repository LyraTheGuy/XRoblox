-- DeepFishing/modules/movement.lua
-- Fly, NoClip, Infinite Jump, Walk Speed
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log
    local getHRP = ctx.getHRP
    local getHum = ctx.getHum
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local flyBV = nil
    local flyBG = nil
    local noclipConn = nil
    local infJumpConn = nil

    -- ═══════════════════════════════════════════
    -- FLY
    -- ═══════════════════════════════════════════
    local function startFly()
        local char = lp.Character
        local hrp = getHRP(char)
        if not hrp then return end

        -- Create BodyVelocity for flying
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBV.Velocity = Vector3.new(0, 0, 0)
        flyBV.P = 10000
        flyBV.Parent = hrp

        -- Create BodyGyro for orientation
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyBG.P = 10000
        flyBG.D = 500
        flyBG.Parent = hrp

        ctx.flyEnabled = true
        log("Fly: ON (speed: " .. ctx.flySpeed .. ")", THEME.success)
    end

    local function stopFly()
        if flyBV and flyBV.Parent then flyBV:Destroy() end
        flyBV = nil
        if flyBG and flyBG.Parent then flyBG:Destroy() end
        flyBG = nil
        ctx.flyEnabled = false
        log("Fly: OFF", THEME.dim)
    end

    local flyConnection
    local function updateFly()
        if not ctx.flyEnabled then return end

        local char = lp.Character
        local hrp = getHRP(char)
        if not hrp or not flyBV then return end

        local cam = workspace.CurrentCamera
        local moveDir = Vector3.new(0, 0, 0)
        local speed = ctx.flySpeed

        -- WASD movement
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + cam.CFrame.RightVector
        end

        -- Up/Down
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit * speed
        end

        flyBV.Velocity = moveDir
        flyBG.CFrame = cam.CFrame
    end

    -- ═══════════════════════════════════════════
    -- NOCLIP
    -- ═══════════════════════════════════════════
    local function startNoClip()
        noclipConn = RunService.Stepped:Connect(function()
            local char = lp.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        ctx.noClipEnabled = true
        log("NoClip: ON", THEME.success)
    end

    local function stopNoClip()
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = nil
        ctx.noClipEnabled = false
        log("NoClip: OFF", THEME.dim)
    end

    -- ═══════════════════════════════════════════
    -- INFINITE JUMP
    -- ═══════════════════════════════════════════
    local function startInfJump()
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            local char = lp.Character
            local hum = getHum(char)
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        ctx.infJumpEnabled = true
        log("Infinite Jump: ON", THEME.success)
    end

    local function stopInfJump()
        if infJumpConn then infJumpConn:Disconnect() end
        infJumpConn = nil
        ctx.infJumpEnabled = false
        log("Infinite Jump: OFF", THEME.dim)
    end

    -- ═══════════════════════════════════════════
    -- WALK SPEED
    -- ═══════════════════════════════════════════
    local function setWalkSpeed(speed)
        ctx.walkSpeed = speed
        local char = lp.Character
        local hum = getHum(char)
        if hum then
            hum.WalkSpeed = speed
        end
        gui.Player.SpeedLabel.Text = "Walk Speed: " .. speed
        log("Walk Speed: " .. speed, THEME.dim)
    end

    -- ═══════════════════════════════════════════
    -- FLY UPDATE LOOP
    -- ═══════════════════════════════════════════
    flyConnection = RunService.RenderStepped:Connect(function()
        if ctx.flyEnabled then
            updateFly()
        end
    end)
    table.insert(ctx.connections, flyConnection)

    -- ═══════════════════════════════════════════
    -- GUI BINDINGS
    -- ═══════════════════════════════════════════
    bind(gui.Player.FlyToggle.btn.MouseButton1Click, function()
        local enabled = gui.Player.FlyToggle.toggle()
        if enabled then
            startFly()
        else
            stopFly()
        end
    end)

    bind(gui.Player.NoClipToggle.btn.MouseButton1Click, function()
        local enabled = gui.Player.NoClipToggle.toggle()
        if enabled then
            startNoClip()
        else
            stopNoClip()
        end
    end)

    bind(gui.Player.InfJumpToggle.btn.MouseButton1Click, function()
        local enabled = gui.Player.InfJumpToggle.toggle()
        if enabled then
            startInfJump()
        else
            stopInfJump()
        end
    end)

    -- ═══════════════════════════════════════════
    -- CHARACTER RESPAWN HANDLING
    -- ═══════════════════════════════════════════
    lp.CharacterAdded:Connect(function(char)
        task.wait(1)
        -- Re-apply walk speed
        local hum = getHum(char)
        if hum then
            hum.WalkSpeed = ctx.walkSpeed
        end

        -- Re-apply fly if enabled
        if ctx.flyEnabled then
            task.wait(0.5)
            startFly()
        end
    end)
end
