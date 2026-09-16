-- RideAPet/modules/auto_ride.lua
-- Auto Ride system: mounts pets and controls ride speed
return function(ctx)
    local gui = ctx.gui
    local config = ctx.config
    local THEME = config.Theme
    local Players = ctx.Players
    local lp = ctx.lp
    local RunService = ctx.RunService
    local TweenService = ctx.TweenService

    local AUTO_MOUNT = config.Ride.AutoMount
    local PREFERRED_PET = config.Ride.PreferredPet
    local rideConnection = nil

    -- ═══════════════════════════════════════════
    -- PET DETECTION
    -- ═══════════════════════════════════════════
    local function getPets()
        local pets = {}
        local背包 = lp:FindFirstChild("Backpack")
        if背包 then
            for _, tool in ipairs(背包:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("PetType") then
                    table.insert(pets, tool)
                end
            end
        end
        local char = lp.Character
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("PetType") then
                    table.insert(pets, tool)
                end
            end
        end
        return pets
    end

    local function selectBestPet(pets)
        if #pets == 0 then return nil end
        if PREFERRED_PET ~= "" then
            for _, pet in ipairs(pets) do
                if pet.Name:lower():find(PREFERRED_PET:lower(), 1, true) then
                    return pet
                end
            end
        end
        return pets[1]
    end

    -- ═══════════════════════════════════════════
    -- MOUNT LOGIC
    -- ═══════════════════════════════════════════
    local function mountPet(pet)
        if not pet then return false end
        local char = lp.Character
        if not char then return false end
        local hum = ctx.getHum(char)
        if not hum then return false end

        pcall(function()
            char.Humanoid:EquipTool(pet)
        end)

        task.wait(0.3)
        ctx.log("Mounted pet: " .. pet.Name, THEME.success)
        ctx.perfRideCount = ctx.perfRideCount + 1
        return true
    end

    local function applySpeed(speed)
        local char = lp.Character
        if not char then return end
        local hum = ctx.getHum(char)
        if hum then
            hum.WalkSpeed = speed
        end
    end

    -- ═══════════════════════════════════════════
    -- RIDE LOOP
    -- ═══════════════════════════════════════════
    local function startRideLoop()
        if rideConnection then rideConnection:Disconnect() end

        rideConnection = RunService.Heartbeat:Connect(function()
            if ctx.destroyed or not ctx.rideEnabled then
                if rideConnection then
                    rideConnection:Disconnect()
                    rideConnection = nil
                end
                return
            end

            applySpeed(ctx.rideSpeed)

            -- Auto mount if enabled and not currently riding
            if AUTO_MOUNT then
                local pets = getPets()
                if #pets > 0 then
                    local best = selectBestPet(pets)
                    if best then
                        local char = lp.Character
                        local currentlyHolding = false
                        if char then
                            for _, tool in ipairs(char:GetChildren()) do
                                if tool == best then currentlyHolding = true break end
                            end
                        end
                        if not currentlyHolding then
                            mountPet(best)
                        end
                    end
                end
            end
        end)
    end

    local function stopRideLoop()
        if rideConnection then
            rideConnection:Disconnect()
            rideConnection = nil
        end
        applySpeed(16) -- reset to default
    end

    -- ═══════════════════════════════════════════
    -- HOOK INTO RIDE TOGGLE
    -- ═══════════════════════════════════════════
    local origToggleRide = ctx.toggleRide
    ctx.toggleRide = function()
        origToggleRide()
        if ctx.rideEnabled then
            startRideLoop()
        else
            stopRideLoop()
        end
    end

    -- Update pet count display
    task.spawn(function()
        while not ctx.destroyed do
            local pets = getPets()
            gui.PetCountLabel.Text = "Detected Pets: " .. #pets
            task.wait(2)
        end
    end)

    ctx.log("Auto Ride module loaded", THEME.success)
end
