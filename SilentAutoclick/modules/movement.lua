-- modules/movement.lua
-- Fly, NoClip, Infinite Jump
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local UserInputService = ctx.UserInputService
    local RunService = ctx.RunService

    local function getHRP(char) return char and char:FindFirstChild("HumanoidRootPart") end
    local function getHum(char) return char and char:FindFirstChildOfClass("Humanoid") end

    -- ═══════════════════════════════════════════
    -- FLY
    -- ═══════════════════════════════════════════
    local function startFly()
        local hrp = getHRP(lp.Character)
        if not hrp then return end
        ctx.flyBodyVelocity = Instance.new("BodyVelocity")
        ctx.flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        ctx.flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        ctx.flyBodyVelocity.P = 10000
        ctx.flyBodyVelocity.Parent = hrp
        ctx.flyBodyGyro = Instance.new("BodyGyro")
        ctx.flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        ctx.flyBodyGyro.P = 10000
        ctx.flyBodyGyro.D = 500
        ctx.flyBodyGyro.Parent = hrp
        ctx.flyEnabled = true
    end

    local function stopFly()
        if ctx.flyBodyVelocity and ctx.flyBodyVelocity.Parent then ctx.flyBodyVelocity:Destroy() end
        ctx.flyBodyVelocity = nil
        if ctx.flyBodyGyro and ctx.flyBodyGyro.Parent then ctx.flyBodyGyro:Destroy() end
        ctx.flyBodyGyro = nil
        ctx.flyEnabled = false
    end

    bind(RunService.RenderStepped, function()
        if not ctx.flyEnabled then return end
        local hrp = getHRP(lp.Character)
        if not hrp or not ctx.flyBodyVelocity then return end
        local cam = workspace.CurrentCamera
        local dir = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit * ctx.flySpeed end
        ctx.flyBodyVelocity.Velocity = dir
        ctx.flyBodyGyro.CFrame = cam.CFrame
    end)

    -- ═══════════════════════════════════════════
    -- NOCLIP
    -- ═══════════════════════════════════════════
    local function startNoClip()
        ctx.noclipConnection = RunService.Stepped:Connect(function()
            local char = lp.Character
            if char then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end end
        end)
        ctx.noClipEnabled = true
    end

    local function stopNoClip()
        if ctx.noclipConnection then ctx.noclipConnection:Disconnect() end
        ctx.noclipConnection = nil
        ctx.noClipEnabled = false
    end

    -- ═══════════════════════════════════════════
    -- INFINITE JUMP
    -- ═══════════════════════════════════════════
    local function startInfJump()
        ctx.infJumpConnection = UserInputService.JumpRequest:Connect(function()
            local hum = getHum(lp.Character)
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
        ctx.infJumpEnabled = true
    end

    local function stopInfJump()
        if ctx.infJumpConnection then ctx.infJumpConnection:Disconnect() end
        ctx.infJumpConnection = nil
        ctx.infJumpEnabled = false
    end

    -- ═══════════════════════════════════════════
    -- RESPAWN HANDLING
    -- ═══════════════════════════════════════════
    lp.CharacterAdded:Connect(function(char)
        task.wait(1)
        local hum = getHum(char)
        if hum then hum.WalkSpeed = ctx.walkSpeed end
        if ctx.flyEnabled then task.wait(0.5); startFly() end
    end)

    -- ═══════════════════════════════════════════
    -- GUI BINDINGS
    -- ═══════════════════════════════════════════
    bind(gui.FlyToggle.btn.MouseButton1Click, function()
        if gui.FlyToggle.toggle() then startFly() else stopFly() end
    end)
    bind(gui.NoClipToggle.btn.MouseButton1Click, function()
        if gui.NoClipToggle.toggle() then startNoClip() else stopNoClip() end
    end)
    bind(gui.InfJumpToggle.btn.MouseButton1Click, function()
        if gui.InfJumpToggle.toggle() then startInfJump() else stopInfJump() end
    end)
end
