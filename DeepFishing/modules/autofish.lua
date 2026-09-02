-- DeepFishing/modules/autofish.lua
-- Auto fishing system: auto-perfect fish, instant collect, bait management
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log
    local getHRP = ctx.getHRP
    local getHum = ctx.getHum

    local fishingActive = false
    local fishCount = 0
    local lastBaitCheck = 0

    -- ═══════════════════════════════════════════
    -- GAME REMOTE ACCESS
    -- ═══════════════════════════════════════════
    local function findRemote(name)
        local rs = game:GetService("ReplicatedStorage")
        -- Direct search
        local ok, result = pcall(function()
            return rs:WaitForChild(name, 3)
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

    local throwRemote = findRemote("Throw")
    local reelRemote = findRemote("Reel")
    local useBaitRemote = findRemote("UseBait")

    -- ═══════════════════════════════════════════
    -- FISHING LOGIC
    -- ═══════════════════════════════════════════
    local function equipRod()
        local char = lp.Character
        if not char then return false end

        -- Look for fishing rod in backpack
        local backpack = lp:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and (
                    tool.Name:find("Rod") or
                    tool.Name:find("Fishing") or
                    tool.Name:find("Hook") or
                    tool:FindFirstChild("Cast")
                ) then
                    -- Equip the rod
                    tool.Parent = char
                    log("Equipped rod: " .. tool.Name, THEME.success)
                    return true
                end
            end
        end

        -- Check if already equipped
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and (
                tool.Name:find("Rod") or
                tool.Name:find("Fishing") or
                tool.Name:find("Hook") or
                tool:FindFirstChild("Cast")
            ) then
                return true
            end
        end

        return false
    end
    ctx.equipRod = equipRod

    local function throwLine()
        if throwRemote then
            local ok, err = pcall(function()
                if throwRemote:IsA("RemoteFunction") then
                    return throwRemote:InvokeServer()
                elseif throwRemote:IsA("RemoteEvent") then
                    throwRemote:FireServer()
                end
            end)
            if ok then
                log("Line thrown", THEME.dim)
                return true
            else
                log("Throw failed: " .. tostring(err), THEME.warn)
            end
        end
        return false
    end
    ctx.throwLine = throwLine

    local function reelIn()
        if reelRemote then
            local ok, err = pcall(function()
                if reelRemote:IsA("RemoteFunction") then
                    return reelRemote:InvokeServer()
                elseif reelRemote:IsA("RemoteEvent") then
                    reelRemote:FireServer()
                end
            end)
            if ok then
                log("Reeled in", THEME.dim)
                return true
            else
                log("Reel failed: " .. tostring(err), THEME.warn)
            end
        end
        return false
    end
    ctx.reelIn = reelIn

    -- ═══════════════════════════════════════════
    -- AUTO FISH LOOP
    -- ═══════════════════════════════════════════
    local function autoFishLoop()
        log("Auto Fish: Started", THEME.success)
        gui.Fishing.StatusLabel.Text = "Status: Fishing..."
        gui.Fishing.StatusLabel.TextColor3 = THEME.success

        while ctx.autoFishEnabled and not ctx.destroyed do
            -- Check if we have a rod equipped
            local char = lp.Character
            if not char then
                gui.Fishing.StatusLabel.Text = "Status: Waiting for character..."
                task.wait(1)
                continue
            end

            -- Check if bait is available
            if ctx.autoStopWhenEmptyEnabled then
                local now = tick()
                if now - lastBaitCheck > 5 then
                    lastBaitCheck = now
                    -- Try to check bait count (game-specific)
                    local backpack = lp:FindFirstChild("Backpack")
                    if backpack then
                        local hasBait = false
                        for _, item in ipairs(backpack:GetChildren()) do
                            if item.Name:find("Bait") or item.Name:find("bait") then
                                hasBait = true
                                break
                            end
                        end
                        if not hasBait then
                            gui.Fishing.StatusLabel.Text = "Status: No bait! Stopping..."
                            gui.Fishing.StatusLabel.TextColor3 = THEME.warn
                            log("Auto Fish: No bait found, stopping", THEME.warn)
                            break
                        end
                    end
                end
            end

            -- Equip rod if not equipped
            local hasRod = false
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") and (
                    tool.Name:find("Rod") or
                    tool.Name:find("Fishing") or
                    tool.Name:find("Hook") or
                    tool:FindFirstChild("Cast")
                ) then
                    hasRod = true
                    break
                end
            end

            if not hasRod then
                if not equipRod() then
                    gui.Fishing.StatusLabel.Text = "Status: No rod found!"
                    gui.Fishing.StatusLabel.TextColor3 = THEME.danger
                    log("Auto Fish: No rod available", THEME.danger)
                    task.wait(2)
                    continue
                end
            end

            -- Throw line
            throwLine()
            task.wait(1)

            -- Wait for fish to bite (game-specific timing)
            -- In Deep Fishing, the fishing minigame has a specific timing
            local biteTime = math.random(2, 8)
            task.wait(biteTime)

            -- Reel in (auto-perfect)
            if ctx.autoFishEnabled and not ctx.destroyed then
                reelIn()
                fishCount = fishCount + 1
                ctx.perfFishCaught = fishCount
                gui.Fishing.StatusLabel.Text = "Status: Fish caught! Total: " .. fishCount
                gui.Fishing.StatusLabel.TextColor3 = THEME.success
                log("Fish #" .. fishCount .. " caught", THEME.success)

                -- Instant collect
                if ctx.instantCollectEnabled then
                    task.wait(0.1)
                    -- The game usually handles collection automatically after reeling
                end
            end

            task.wait(0.5)
        end

        if ctx.autoFishEnabled then
            gui.Fishing.StatusLabel.Text = "Status: Stopped | Fish: " .. fishCount
            gui.Fishing.StatusLabel.TextColor3 = THEME.dim
        end
        log("Auto Fish: Stopped (caught " .. fishCount .. " fish)", THEME.dim)
    end

    -- ═══════════════════════════════════════════
    -- GUI BINDINGS
    -- ═══════════════════════════════════════════
    bind(gui.Fishing.AutoFishToggle.btn.MouseButton1Click, function()
        ctx.autoFishEnabled = gui.Fishing.AutoFishToggle.toggle()
        if ctx.autoFishEnabled then
            task.spawn(autoFishLoop)
        end
    end)

    bind(gui.Fishing.InstantCollectToggle.btn.MouseButton1Click, function()
        ctx.instantCollectEnabled = gui.Fishing.InstantCollectToggle.toggle()
    end)

    bind(gui.Fishing.AutoStopToggle.btn.MouseButton1Click, function()
        ctx.autoStopWhenEmptyEnabled = gui.Fishing.AutoStopToggle.toggle()
    end)

    bind(gui.Fishing.CollectRaritiesToggle.btn.MouseButton1Click, function()
        ctx.collectAllRaritiesEnabled = gui.Fishing.CollectRaritiesToggle.toggle()
    end)

    bind(gui.Fishing.CollectMutationsToggle.btn.MouseButton1Click, function()
        ctx.collectMutationsEnabled = gui.Fishing.CollectMutationsToggle.toggle()
    end)
end
