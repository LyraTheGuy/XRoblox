-- RideAPet/modules/auto_get_egg.lua
-- Auto Get Egg: collect eggs from map, NEVER auto-place them
-- Eggs stay in inventory so you can infinitely stack the rarest ones
return function(ctx)
    local gui = ctx.gui
    local config = ctx.config
    local THEME = config.Theme
    local Players = ctx.Players
    local lp = ctx.lp
    local RunService = ctx.RunService
    local TweenService = ctx.TweenService

    local EGG_CONFIG = config.Egg
    local WHITELIST = EGG_CONFIG.WhitelistRarities or {}
    local BLACKLIST = EGG_CONFIG.BlacklistPets or {}
    local COLLECT_INTERVAL = EGG_CONFIG.CollectInterval or 0.5
    local AUTO_TP = EGG_CONFIG.AutoTPToEggs

    local eggConnection = nil
    local eggCooldowns = {} -- track collected eggs to avoid re-collecting too fast

    -- ═══════════════════════════════════════════
    -- RARITY MATCHING
    -- ═══════════════════════════════════════════
    local function getEggRarity(eggObj)
        -- Try multiple attribute names for rarity
        local rarity = eggObj:GetAttribute("Rarity")
            or eggObj:GetAttribute("rarity")
            or eggObj:GetAttribute("PetRarity")
            or eggObj:GetAttribute("RarityType")
            or ""
        return tostring(rarity)
    end

    local function getEggName(eggObj)
        local name = eggObj:GetAttribute("PetName")
            or eggObj:GetAttribute("PetType")
            or eggObj:GetAttribute("Name")
            or eggObj.Name
        return tostring(name)
    end

    local function isWhitelisted(rarity)
        if #WHITELIST == 0 then return true end -- empty = collect all
        for _, r in ipairs(WHITELIST) do
            if string.lower(r) == string.lower(rarity) then
                return true
            end
        end
        return false
    end

    local function isBlacklisted(petName)
        for _, b in ipairs(BLACKLIST) do
            if string.lower(b) == string.lower(petName) then
                return true
            end
        end
        return false
    end

    -- ═══════════════════════════════════════════
    -- EGG SCANNING
    -- ═══════════════════════════════════════════
    local function findEggSpawns()
        local eggs = {}

        -- Scan common egg spawn locations in workspace
        local searchPaths = {}

        -- Check for egg-related folders/objects
        local main = workspace:FindFirstChild("Main")
        if main then
            local eggFolder = main:FindFirstChild("EggSpawns")
                or main:FindFirstChild("Eggs")
                or main:FindFirstChild("Egg")
                or main:FindFirstChild("PetEggs")
            if eggFolder then
                table.insert(searchPaths, eggFolder)
            end
        end

        -- Check workspace directly
        for _, child in ipairs(workspace:GetChildren()) do
            local name = child.Name:lower()
            if name:find("egg") or name:find("pet") then
                if child:IsA("Folder") or child:IsA("Model") then
                    table.insert(searchPaths, child)
                end
            end
        end

        -- Scan all found paths for collectible egg parts
        for _, path in ipairs(searchPaths) do
            local function scan(parent, depth)
                if depth > 5 then return end -- prevent deep recursion
                for _, obj in ipairs(parent:GetChildren()) do
                    if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                        local rarity = getEggRarity(obj)
                        local petName = getEggName(obj)

                        -- Check if this looks like an egg
                        local isEgg = obj:GetAttribute("IsEgg")
                            or obj:GetAttribute("Collectible")
                            or obj:GetAttribute("Pickup")
                            or obj.Name:lower():find("egg")
                            or obj:GetAttribute("PetType")

                        if isEgg and isWhitelisted(rarity) and not isBlacklisted(petName) then
                            -- Check cooldown
                            local key = obj:GetFullName()
                            if not eggCooldowns[key] or (tick() - eggCooldowns[key]) > 3 then
                                table.insert(eggs, {
                                    part = obj,
                                    rarity = rarity,
                                    name = petName,
                                    position = obj.Position,
                                })
                            end
                        end
                    elseif obj:IsA("Model") or obj:IsA("Folder") then
                        scan(obj, depth + 1)
                    end
                end
            end
            scan(path, 0)
        end

        -- Also scan for proximity-based collection points
        local char = lp.Character
        local hrp = ctx.getHRP(char)
        if hrp then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if (obj:IsA("BasePart") or obj:IsA("MeshPart")) then
                    local dist = (obj.Position - hrp.Position).Magnitude
                    if dist < 100 then -- only nearby
                        local rarity = getEggRarity(obj)
                        local petName = getEggName(obj)
                        local isEgg = obj:GetAttribute("IsEgg")
                            or obj:GetAttribute("Collectible")
                            or obj:GetAttribute("Pickup")
                            or obj:GetAttribute("PetType")

                        if isEgg and isWhitelisted(rarity) and not isBlacklisted(petName) then
                            local key = obj:GetFullName()
                            if not eggCooldowns[key] or (tick() - eggCooldowns[key]) > 3 then
                                -- Avoid duplicates
                                local exists = false
                                for _, e in ipairs(eggs) do
                                    if e.part == obj then exists = true break end
                                end
                                if not exists then
                                    table.insert(eggs, {
                                        part = obj,
                                        rarity = rarity,
                                        name = petName,
                                        position = obj.Position,
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Sort by rarity (rarer first)
        local rarityOrder = {}
        for i, r in ipairs(EGG_CONFIG.Rarities) do
            rarityOrder[string.lower(r)] = i
        end
        table.sort(eggs, function(a, b)
            local ra = rarityOrder[string.lower(a.rarity)] or 999
            local rb = rarityOrder[string.lower(b.rarity)] or 999
            return ra < rb
        end)

        return eggs
    end

    -- ═══════════════════════════════════════════
    -- EGG COLLECTION (NO PLACEMENT!)
    -- ═══════════════════════════════════════════
    local function collectEgg(eggData)
        local char = lp.Character
        local hrp = ctx.getHRP(char)
        if not hrp then return false end

        local part = eggData.part
        if not part or not part.Parent then return false end

        -- Teleport to egg if enabled
        if AUTO_TP then
            local targetPos = part.Position + Vector3.new(0, 3, 0)
            hrp.CFrame = CFrame.new(targetPos)
            task.wait(0.2)
        end

        -- Fire touch event / proximity prompt to collect
        local collected = false

        -- Method 1: Try proximity prompt
        local prompt = part:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            pcall(function()
                -- Simulate proximity prompt activation
                if fireproximityprompt then
                    fireproximityprompt(prompt)
                    collected = true
                end
            end)
        end

        -- Method 2: Try clicking/touching the part
        if not collected then
            pcall(function()
                -- Move directly onto the egg to trigger collection
                local pos = part.Position
                hrp.CFrame = CFrame.new(pos)
                task.wait(0.1)

                -- Try touching
                if part:CanCollide() then
                    part.CanCollide = false
                    task.wait(0.05)
                    part.CanCollide = true
                end
            end)
        end

        -- Method 3: Fire remote if available
        if not collected then
            pcall(function()
                local rf = ctx.ReplicatedStorage:FindFirstChild("GameRemoteFunctions")
                    or ctx.ReplicatedStorage:FindFirstChild("Remotes")
                if rf then
                    for _, remote in ipairs(rf:GetChildren()) do
                        local name = remote.Name:lower()
                        if name:find("collect") or name:find("pickup") or name:find("egg")
                            or name:find("get") or name:find("grab") then
                            if remote:IsA("RemoteFunction") then
                                remote:InvokeServer(part)
                                collected = true
                                break
                            elseif remote:IsA("RemoteEvent") then
                                remote:FireServer(part)
                                collected = true
                                break
                            end
                        end
                    end
                end
            end)
        end

        -- Method 4: Touch the part directly with character
        if not collected then
            pcall(function()
                hrp.CFrame = part.CFrame
                task.wait(0.15)
            end)
        end

        -- Mark cooldown
        local key = part:GetFullName()
        eggCooldowns[key] = tick()

        return true
    end

    -- ═══════════════════════════════════════════
    -- RARITY LOG UPDATE
    -- ═══════════════════════════════════════════
    local function updateRarityLog(eggData)
        table.insert(ctx.eggRarityLog, 1, {
            name = eggData.name,
            rarity = eggData.rarity,
            time = os.date("%H:%M:%S"),
        })
        -- Keep only last 5
        while #ctx.eggRarityLog > 5 do
            table.remove(ctx.eggRarityLog)
        end

        -- Update GUI log
        local lines = {}
        for _, entry in ipairs(ctx.eggRarityLog) do
            local color = "⚪"
            local rl = entry.rarity:lower()
            if rl == "divine" then color = "🟣"
            elseif rl == "mythical" then color = "🔴"
            elseif rl == "legendary" then color = "🟡"
            elseif rl == "epic" then color = "🟠"
            elseif rl == "rare" then color = "🔵"
            elseif rl == "uncommon" then color = "🟢"
            end
            table.insert(lines, string.format("[%s] %s %s (%s)", entry.time, color, entry.name, entry.rarity))
        end
        gui.EggRarityLog.Text = #lines > 0 and table.concat(lines, "\n") or "— No eggs collected yet —"
    end

    -- ═══════════════════════════════════════════
    -- MAIN EGG LOOP
    -- ═══════════════════════════════════════════
    local function startEggLoop()
        if eggConnection then eggConnection:Disconnect() end

        ctx.autoGetEggEnabled = true
        gui.EggToggleBtn.Text = "Stop Auto Get Egg"
        gui.EggToggleBtn.BackgroundColor3 = THEME.danger
        gui.EggStatusLabel.Text = "Status: ON"
        gui.EggStatusLabel.TextColor3 = THEME.success
        ctx.log("Auto Get Egg: ON (no placement — eggs stay in inventory)", THEME.success)

        eggConnection = task.spawn(function()
            while ctx.autoGetEggEnabled and not ctx.destroyed do
                local eggs = findEggSpawns()

                if #eggs > 0 then
                    for _, eggData in ipairs(eggs) do
                        if not ctx.autoGetEggEnabled or ctx.destroyed then break end

                        local ok, err = pcall(function()
                            collectEgg(eggData)
                        end)

                        if ok then
                            ctx.perfEggCount = ctx.perfEggCount + 1
                            gui.EggCountLabel.Text = "Eggs Collected: " .. ctx.perfEggCount
                            gui.EggLastLabel.Text = "Last: " .. eggData.name .. " (" .. eggData.rarity .. ")"

                            -- Color the last label by rarity
                            local rl = eggData.rarity:lower()
                            if rl == "divine" or rl == "mythical" then
                                gui.EggLastLabel.TextColor3 = THEME.accent
                            elseif rl == "legendary" then
                                gui.EggLastLabel.TextColor3 = THEME.warn
                            elseif rl == "epic" then
                                gui.EggLastLabel.TextColor3 = Color3.fromRGB(255, 140, 60)
                            else
                                gui.EggLastLabel.TextColor3 = THEME.dim
                            end

                            updateRarityLog(eggData)
                            ctx.log("Collected: " .. eggData.name .. " [" .. eggData.rarity .. "]", THEME.success)
                        else
                            ctx.log("Collect failed: " .. tostring(err), THEME.danger)
                        end

                        task.wait(COLLECT_INTERVAL)
                    end
                else
                    -- No eggs found, wait longer before scanning again
                    gui.EggStatusLabel.Text = "Status: Scanning..."
                    gui.EggStatusLabel.TextColor3 = THEME.warn
                    task.wait(2)
                end

                -- Update status back
                if ctx.autoGetEggEnabled then
                    gui.EggStatusLabel.Text = "Status: ON"
                    gui.EggStatusLabel.TextColor3 = THEME.success
                end
            end
        end)
    end

    local function stopEggLoop()
        ctx.autoGetEggEnabled = false
        if eggConnection then
            -- eggConnection is a coroutine from task.spawn, we can't disconnect it
            -- but the while loop checks ctx.autoGetEggEnabled so it will stop
        end
        gui.EggToggleBtn.Text = "Start Auto Get Egg"
        gui.EggToggleBtn.BackgroundColor3 = THEME.accent
        gui.EggStatusLabel.Text = "Status: OFF"
        gui.EggStatusLabel.TextColor3 = THEME.danger
        ctx.log("Auto Get Egg: OFF", THEME.dim)
    end

    -- ═══════════════════════════════════════════
    -- TOGGLE HANDLER
    -- ═══════════════════════════════════════════
    ctx.bind(gui.EggToggleBtn.MouseButton1Click, function()
        if ctx.autoGetEggEnabled then
            stopEggLoop()
        else
            startEggLoop()
        end
    end)

    -- Update whitelist display
    if #WHITELIST > 0 then
        gui.EggWhitelistInfo.Text = "Collecting: " .. table.concat(WHITELIST, ", ")
    else
        gui.EggWhitelistInfo.Text = "Collecting: ALL rarities"
    end

    ctx.log("Auto Get Egg module loaded", THEME.success)
end
