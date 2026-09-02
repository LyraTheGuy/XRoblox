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
    -- ROD DETECTION HELPER
    -- ═══════════════════════════════════════════
    local function hasRodEquipped()
        local char = lp.Character
        if not char then return false end
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

    -- ═══════════════════════════════════════════
    -- ENSURE ROD — must succeed before fishing starts
    -- ═══════════════════════════════════════════
    local function ensureRod()
        -- Already equipped
        if hasRodEquipped() then
            return true
        end

        -- Try to equip from backpack
        if equipRod() then
            task.wait(0.3) -- brief wait for tool to parent into Character
            return hasRodEquipped()
        end

        return false
    end

    -- ═══════════════════════════════════════════
    -- AUTO FISH LOOP
    -- ═══════════════════════════════════════════
    local function autoFishLoop()
        -- ── GATE: must equip rod before anything else ──
        gui.Fishing.StatusLabel.Text = "Status: Equipping rod..."
        gui.Fishing.StatusLabel.TextColor3 = THEME.warn
        log("Auto Fish: Attempting to equip rod...", THEME.warn)

        if not ensureRod() then
            gui.Fishing.StatusLabel.Text = "Status: No rod found — cannot fish!"
            gui.Fishing.StatusLabel.TextColor3 = THEME.danger
            log("Auto Fish: ABORT — no fishing rod in Backpack or equipped", THEME.danger)
            -- Toggle back OFF so the button reflects reality
            ctx.autoFishEnabled = false
            gui.Fishing.AutoFishToggle.btn.Text = "Auto Perfect Fish: OFF"
            gui.Fishing.AutoFishToggle.btn.BackgroundColor3 = THEME.panel2
            gui.Fishing.AutoFishToggle.btn.TextColor3 = THEME.dim
            return
        end

        log("Auto Fish: Rod equipped, starting fishing loop", THEME.success)
        gui.Fishing.StatusLabel.Text = "Status: Fishing..."
        gui.Fishing.StatusLabel.TextColor3 = THEME.success

        while ctx.autoFishEnabled and not ctx.destroyed do
            -- Re-check rod is still equipped (could have been unequipped)
            if not hasRodEquipped() then
                gui.Fishing.StatusLabel.Text = "Status: Rod lost — re-equipping..."
                gui.Fishing.StatusLabel.TextColor3 = THEME.warn
                log("Auto Fish: Rod lost, re-equipping", THEME.warn)
                if not ensureRod() then
                    gui.Fishing.StatusLabel.Text = "Status: Rod lost — stopping!"
                    gui.Fishing.StatusLabel.TextColor3 = THEME.danger
                    log("Auto Fish: ABORT — could not re-equip rod", THEME.danger)
                    ctx.autoFishEnabled = false
                    gui.Fishing.AutoFishToggle.btn.Text = "Auto Perfect Fish: OFF"
                    gui.Fishing.AutoFishToggle.btn.BackgroundColor3 = THEME.panel2
                    gui.Fishing.AutoFishToggle.btn.TextColor3 = THEME.dim
                    return
                end
                gui.Fishing.StatusLabel.Text = "Status: Fishing..."
                gui.Fishing.StatusLabel.TextColor3 = THEME.success
            end

            -- Check if bait is available
            if ctx.autoStopWhenEmptyEnabled then
                local now = tick()
                if now - lastBaitCheck > 5 then
                    lastBaitCheck = now
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

            -- Throw line
            throwLine()
            task.wait(1)

            -- Wait for fish to bite
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

                if ctx.instantCollectEnabled then
                    task.wait(0.1)
                end
            end

            task.wait(0.5)
        end

        gui.Fishing.StatusLabel.Text = "Status: Stopped | Fish: " .. fishCount
        gui.Fishing.StatusLabel.TextColor3 = THEME.dim
        log("Auto Fish: Stopped (caught " .. fishCount .. " fish)", THEME.dim)
    end

    -- ═══════════════════════════════════════════
    -- GUI BINDINGS
    -- ═══════════════════════════════════════════
    bind(gui.Fishing.AutoFishToggle.btn.MouseButton1Click, function()
        ctx.autoFishEnabled = gui.Fishing.AutoFishToggle.toggle()
        if ctx.autoFishEnabled then
            -- Equip rod FIRST, then start the loop (autoFishLoop also re-checks)
            task.spawn(function()
                gui.Fishing.StatusLabel.Text = "Status: Equipping rod..."
                gui.Fishing.StatusLabel.TextColor3 = THEME.warn
                if not ensureRod() then
                    gui.Fishing.StatusLabel.Text = "Status: No rod found — cannot start!"
                    gui.Fishing.StatusLabel.TextColor3 = THEME.danger
                    log("Auto Fish: Cannot start — no fishing rod", THEME.danger)
                    ctx.autoFishEnabled = false
                    gui.Fishing.AutoFishToggle.btn.Text = "Auto Perfect Fish: OFF"
                    gui.Fishing.AutoFishToggle.btn.BackgroundColor3 = THEME.panel2
                    gui.Fishing.AutoFishToggle.btn.TextColor3 = THEME.dim
                    return
                end
                autoFishLoop()
            end)
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
