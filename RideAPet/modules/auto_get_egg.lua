-- RideAPet/modules/auto_get_egg.lua
-- Auto Get Egg: collect eggs from map, NEVER auto-place them
-- Eggs stay in inventory so you can infinitely stack the rarest ones
-- Features: rarity tracker, session stats, sound alerts, nearby ESP,
--           smart routing, auto-discard, webhook, hotkey toggle
return function(ctx)
    local gui = ctx.gui
    local config = ctx.config
    local THEME = config.Theme
    local Players = ctx.Players
    local lp = ctx.lp
    local RunService = ctx.RunService
    local TweenService = ctx.TweenService
    local UserInputService = ctx.UserInputService

    local EGG_CONFIG = config.Egg
    local WHITELIST = EGG_CONFIG.WhitelistRarities or {}
    local BLACKLIST = EGG_CONFIG.BlacklistPets or {}
    local COLLECT_INTERVAL = EGG_CONFIG.CollectInterval or 0.5
    local AUTO_TP = EGG_CONFIG.AutoTPToEggs
    local COLLECT_RADIUS = EGG_CONFIG.CollectRadius or 0
    local SOUND_ALERTS = EGG_CONFIG.SoundAlerts
    local NEARBY_ESP = EGG_CONFIG.NearbyESP
    local ESP_MAX_DIST = EGG_CONFIG.ESPMaxDistance or 150
    local SMART_ROUTING = EGG_CONFIG.SmartRouting
    local AUTO_DISCARD = EGG_CONFIG.AutoDiscard
    local DISCARD_RARITIES = EGG_CONFIG.DiscardRarities or {}
    local WEBHOOK_ENABLED = EGG_CONFIG.WebhookEnabled
    local WEBHOOK_URL = EGG_CONFIG.WebhookURL or ""
    local WEBHOOK_MIN_RARITY = EGG_CONFIG.WebhookMinRarity or "Legendary"
    local SHOW_STATS = EGG_CONFIG.ShowSessionStats

    local eggConnection = nil
    local eggCooldowns = {}
    local espObjects = {} -- nearby egg ESP highlights
    local sessionStartTime = tick()

    -- ═══════════════════════════════════════════
    -- RARITY DISTRIBUTION TRACKER
    -- ═══════════════════════════════════════════
    local rarityCounts = {}
    for _, r in ipairs(EGG_CONFIG.Rarities) do
        rarityCounts[string.lower(r)] = 0
    end

    local function updateRarityDisplay()
        local parts = {}
        local emojis = {divine="🟣", mythical="🔴", legendary="🟡", epic="🟠", rare="🔵", uncommon="🟢", common="⚪"}
        for _, r in ipairs(EGG_CONFIG.Rarities) do
            local rl = string.lower(r)
            local emoji = emojis[rl] or "•"
            table.insert(parts, emoji .. " " .. r .. ": " .. (rarityCounts[rl] or 0))
        end
        gui.EggRarityDist.Text = table.concat(parts, " | ")
    end

    -- ═══════════════════════════════════════════
    -- SESSION STATS
    -- ═══════════════════════════════════════════
    local function updateSessionStats(nearbyCount)
        if not SHOW_STATS then return end
        local elapsed = tick() - sessionStartTime
        local minutes = elapsed / 60
        local perMin = minutes > 0 and (ctx.perfEggCount / minutes) or 0
        gui.EggSessionStats.Text = string.format(
            "Session: %d eggs | %.1f/min | %ds elapsed | Near: %d eggs",
            ctx.perfEggCount, perMin, math.floor(elapsed), nearbyCount or 0
        )
    end

    -- ═══════════════════════════════════════════
    -- RARITY SOUND ALERTS
    -- ═══════════════════════════════════════════
    local function playRaritySound(rarity)
        if not SOUND_ALERTS then return end
        local rl = string.lower(rarity)
        local volume = EGG_CONFIG.AlertVolumes and EGG_CONFIG.AlertVolumes[rarity] or 0.3
        if volume <= 0 then return end

        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://6042053626" -- notification sound
            sound.Volume = volume
            -- Pitch shift: rarer = higher pitch
            local pitchMap = {divine=1.5, mythical=1.3, legendary=1.1, epic=0.9}
            sound.PlaybackSpeed = pitchMap[rl] or 0.7
            sound.Parent = workspace.CurrentCamera
            sound:Play()
            game:GetService("Debris"):AddItem(sound, 3)
        end)
    end

    -- ═══════════════════════════════════════════
    -- DISCORD WEBHOOK FOR RARE FINDS
    -- ═══════════════════════════════════════════
    local rarityOrder = {}
    for i, r in ipairs(EGG_CONFIG.Rarities) do
        rarityOrder[string.lower(r)] = i
    end

    local function shouldWebhook(rarity)
        if not WEBHOOK_ENABLED or WEBHOOK_URL == "" then return false end
        local rl = string.lower(rarity)
        local minRl = string.lower(WEBHOOK_MIN_RARITY)
        return (rarityOrder[rl] or 999) <= (rarityOrder[minRl] or 999)
    end

    local function sendWebhook(eggData)
        if not shouldWebhook(eggData.rarity) then return end
        task.spawn(function()
            pcall(function()
                local HttpService = game:GetService("HttpService")
                local payload = {
                    embeds = {{
                        title = "🥚 Rare Egg Collected!",
                        description = string.format("**%s** [%s]", eggData.name, eggData.rarity),
                        color = eggData.rarity:lower() == "divine" and 0x9B59FF
                            or eggData.rarity:lower() == "mythical" and 0xFF608C
                            or eggData.rarity:lower() == "legendary" and 0xFFC850
                            or 0xFF8C3C,
                        fields = {
                            {name = "Player", value = lp.Name, inline = true},
                            {name = "Total", value = tostring(ctx.perfEggCount), inline = true},
                            {name = "Time", value = os.date("%H:%M:%S"), inline = true},
                        },
                        footer = {text = "LyraHub — Ride A Pet"},
                    }},
                }
                local data = HttpService:JSONEncode(payload)
                local request = (syn and syn.request) or (http and http.request) or http_request or request
                if request then
                    request({
                        Url = WEBHOOK_URL,
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = data,
                    })
                end
            end)
        end)
    end

    -- ═══════════════════════════════════════════
    -- NEARBY EGG ESP
    -- ═══════════════════════════════════════════
    local function getRarityColor(rarity)
        local rl = string.lower(rarity)
        if rl == "divine" then return Color3.fromRGB(155, 89, 255)
        elseif rl == "mythical" then return Color3.fromRGB(255, 96, 140)
        elseif rl == "legendary" then return Color3.fromRGB(255, 200, 80)
        elseif rl == "epic" then return Color3.fromRGB(255, 140, 60)
        elseif rl == "rare" then return Color3.fromRGB(100, 180, 255)
        elseif rl == "uncommon" then return Color3.fromRGB(67, 214, 125)
        else return Color3.fromRGB(180, 180, 180)
        end
    end

    local function clearNearbyESP()
        for key, obj in pairs(espObjects) do
            pcall(function()
                if obj.highlight then obj.highlight:Destroy() end
                if obj.billboard then obj.billboard:Destroy() end
            end)
            espObjects[key] = nil
        end
    end

    local function updateNearbyESP(eggs)
        if not NEARBY_ESP then clearNearbyESP() return end

        -- Track which eggs are still nearby
        local activeKeys = {}
        for _, egg in ipairs(eggs) do
            local key = egg.part:GetFullName()
            activeKeys[key] = true

            if not espObjects[key] then
                local color = getRarityColor(egg.rarity)

                -- Highlight box
                local highlight = Instance.new("SelectionBox")
                highlight.Adornee = egg.part
                highlight.Color3 = color
                highlight.LineThickness = 0.04
                highlight.SurfaceTransparency = 0.7
                highlight.SurfaceColor3 = color
                highlight.Parent = workspace

                -- Name label
                local bb = Instance.new("BillboardGui")
                bb.Adornee = egg.part
                bb.AlwaysOnTop = true
                bb.Size = UDim2.new(0, 100, 0, 24)
                bb.StudsOffset = Vector3.new(0, 2.5, 0)
                bb.Parent = workspace

                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = egg.name .. " [" .. egg.rarity .. "]"
                lbl.TextColor3 = color
                lbl.TextStrokeTransparency = 0
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 11
                lbl.Parent = bb

                espObjects[key] = { highlight = highlight, billboard = bb }
            end
        end

        -- Remove ESP for eggs no longer nearby
        for key, obj in pairs(espObjects) do
            if not activeKeys[key] then
                pcall(function()
                    if obj.highlight then obj.highlight:Destroy() end
                    if obj.billboard then obj.billboard:Destroy() end
                end)
                espObjects[key] = nil
            end
        end
    end

    -- ═══════════════════════════════════════════
    -- RARITY MATCHING
    -- ═══════════════════════════════════════════
    local function getEggRarity(eggObj)
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
        if #WHITELIST == 0 then return true end
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

    local function isDiscardable(rarity)
        if not AUTO_DISCARD then return false end
        for _, r in ipairs(DISCARD_RARITIES) do
            if string.lower(r) == string.lower(rarity) then
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
        local hrp = ctx.getHRP(lp.Character)

        local function processEgg(obj)
            if not (obj:IsA("BasePart") or obj:IsA("MeshPart")) then return end
            if COLLECT_RADIUS > 0 and hrp then
                local dist = (obj.Position - hrp.Position).Magnitude
                if dist > COLLECT_RADIUS then return end
            end

            local rarity = getEggRarity(obj)
            local petName = getEggName(obj)

            local isEgg = obj:GetAttribute("IsEgg")
                or obj:GetAttribute("Collectible")
                or obj:GetAttribute("Pickup")
                or obj.Name:lower():find("egg")
                or obj:GetAttribute("PetType")

            if isEgg and isWhitelisted(rarity) and not isBlacklisted(petName) then
                local key = obj:GetFullName()
                if not eggCooldowns[key] or (tick() - eggCooldowns[key]) > 3 then
                    local dist = hrp and (obj.Position - hrp.Position).Magnitude or 0
                    table.insert(eggs, {
                        part = obj,
                        rarity = rarity,
                        name = petName,
                        position = obj.Position,
                        distance = dist,
                    })
                end
            end
        end

        -- Scan workspace folders
        local searchPaths = {}
        local main = workspace:FindFirstChild("Main")
        if main then
            for _, folderName in ipairs({"EggSpawns", "Eggs", "Egg", "PetEggs", "Spawns"}) do
                local folder = main:FindFirstChild(folderName)
                if folder then table.insert(searchPaths, folder) end
            end
        end
        for _, child in ipairs(workspace:GetChildren()) do
            local name = child.Name:lower()
            if (name:find("egg") or name:find("pet") or name:find("spawn"))
                and (child:IsA("Folder") or child:IsA("Model")) then
                table.insert(searchPaths, child)
            end
        end

        for _, path in ipairs(searchPaths) do
            local function scan(parent, depth)
                if depth > 5 then return end
                for _, obj in ipairs(parent:GetChildren()) do
                    if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                        processEgg(obj)
                    elseif obj:IsA("Model") or obj:IsA("Folder") then
                        scan(obj, depth + 1)
                    end
                end
            end
            scan(path, 0)
        end

        -- Proximity scan
        if hrp then
            local scanDist = NEARBY_ESP and ESP_MAX_DIST or (COLLECT_RADIUS > 0 and COLLECT_RADIUS or 100)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if (obj:IsA("BasePart") or obj:IsA("MeshPart")) then
                    local dist = (obj.Position - hrp.Position).Magnitude
                    if dist < scanDist then
                        processEgg(obj)
                    end
                end
            end
        end

        -- Sort: smart routing (distance + rarity combined) or rarity only
        if SMART_ROUTING and hrp then
            table.sort(eggs, function(a, b)
                local ra = rarityOrder[string.lower(a.rarity)] or 999
                local rb = rarityOrder[string.lower(b.rarity)] or 999
                -- Weight: rarity matters more than distance
                local scoreA = ra * 1000 + a.distance
                local scoreB = rb * 1000 + b.distance
                return scoreA < scoreB
            end)
        else
            table.sort(eggs, function(a, b)
                local ra = rarityOrder[string.lower(a.rarity)] or 999
                local rb = rarityOrder[string.lower(b.rarity)] or 999
                return ra < rb
            end)
        end

        return eggs
    end

    -- ═══════════════════════════════════════════
    -- AUTO-DISCARD LOW RARITY
    -- ═══════════════════════════════════════════
    local function discardEgg(eggData)
        if not isDiscardable(eggData.rarity) then return false end
        pcall(function()
            -- Try to find and destroy the egg from backpack/character
            local backpack = lp:FindFirstChild("Backpack")
            if backpack then
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool.Name == eggData.name then
                        tool:Destroy()
                        ctx.log("Discarded: " .. eggData.name .. " [" .. eggData.rarity .. "]", THEME.dim)
                        return true
                    end
                end
            end
            -- Try remote-based discard
            local rf = ctx.ReplicatedStorage:FindFirstChild("GameRemoteFunctions")
                or ctx.ReplicatedStorage:FindFirstChild("Remotes")
            if rf then
                for _, remote in ipairs(rf:GetChildren()) do
                    local name = remote.Name:lower()
                    if name:find("discard") or name:find("delete") or name:find("remove") then
                        if remote:IsA("RemoteFunction") then
                            remote:InvokeServer(eggData.name)
                        elseif remote:IsA("RemoteEvent") then
                            remote:FireServer(eggData.name)
                        end
                        ctx.log("Discarded via remote: " .. eggData.name, THEME.dim)
                        return true
                    end
                end
            end
        end)
        return false
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

        -- Auto-discard if configured and this rarity is discardable
        if isDiscardable(eggData.rarity) then
            discardEgg(eggData)
        end

        -- Teleport to egg if enabled
        if AUTO_TP then
            local targetPos = part.Position + Vector3.new(0, 3, 0)
            hrp.CFrame = CFrame.new(targetPos)
            task.wait(0.2)
        end

        local collected = false

        -- Method 1: Proximity prompt
        local prompt = part:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            pcall(function()
                if fireproximityprompt then
                    fireproximityprompt(prompt)
                    collected = true
                end
            end)
        end

        -- Method 2: Touch the part
        if not collected then
            pcall(function()
                hrp.CFrame = CFrame.new(part.Position)
                task.wait(0.1)
                if part:CanCollide() then
                    part.CanCollide = false
                    task.wait(0.05)
                    part.CanCollide = true
                end
            end)
        end

        -- Method 3: Fire remote
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

        -- Method 4: Direct CFrame
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
        while #ctx.eggRarityLog > 5 do
            table.remove(ctx.eggRarityLog)
        end

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
        if eggConnection then return end

        ctx.autoGetEggEnabled = true
        sessionStartTime = tick()
        gui.EggToggleBtn.Text = "Stop Auto Get Egg [G]"
        gui.EggToggleBtn.BackgroundColor3 = THEME.danger
        gui.EggStatusLabel.Text = "Status: ON"
        gui.EggStatusLabel.TextColor3 = THEME.success
        ctx.log("Auto Get Egg: ON (no placement — eggs stay in inventory)", THEME.success)

        eggConnection = task.spawn(function()
            while ctx.autoGetEggEnabled and not ctx.destroyed do
                local eggs = findEggSpawns()

                -- Update nearby ESP
                updateNearbyESP(eggs)

                -- Update session stats
                updateSessionStats(#eggs)

                if #eggs > 0 then
                    gui.EggStatusLabel.Text = "Status: ON — " .. #eggs .. " eggs found"
                    gui.EggStatusLabel.TextColor3 = THEME.success

                    for _, eggData in ipairs(eggs) do
                        if not ctx.autoGetEggEnabled or ctx.destroyed then break end

                        local ok, err = pcall(function()
                            collectEgg(eggData)
                        end)

                        if ok then
                            ctx.perfEggCount = ctx.perfEggCount + 1

                            -- Update rarity distribution
                            local rl = string.lower(eggData.rarity)
                            rarityCounts[rl] = (rarityCounts[rl] or 0) + 1
                            updateRarityDisplay()

                            -- Update GUI
                            gui.EggCountLabel.Text = "Eggs Collected: " .. ctx.perfEggCount
                            gui.EggLastLabel.Text = "Last: " .. eggData.name .. " (" .. eggData.rarity .. ")"

                            -- Color the last label by rarity
                            gui.EggLastLabel.TextColor3 = getRarityColor(eggData.rarity)

                            updateRarityLog(eggData)
                            updateSessionStats(#eggs)
                            ctx.log("Collected: " .. eggData.name .. " [" .. eggData.rarity .. "]", THEME.success)

                            -- Sound alert
                            playRaritySound(eggData.rarity)

                            -- Discord webhook
                            sendWebhook(eggData)
                        else
                            ctx.log("Collect failed: " .. tostring(err), THEME.danger)
                        end

                        task.wait(COLLECT_INTERVAL)
                    end
                else
                    gui.EggStatusLabel.Text = "Status: Scanning..."
                    gui.EggStatusLabel.TextColor3 = THEME.warn
                    updateSessionStats(0)
                    task.wait(2)
                end

                if ctx.autoGetEggEnabled then
                    gui.EggStatusLabel.Text = "Status: ON"
                    gui.EggStatusLabel.TextColor3 = THEME.success
                end
            end
        end)
    end

    local function stopEggLoop()
        ctx.autoGetEggEnabled = false
        eggConnection = nil
        clearNearbyESP()
        gui.EggToggleBtn.Text = "Start Auto Get Egg [G]"
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

    -- Hotkey toggle
    ctx.bind(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == config.Keys.ToggleEgg then
            if ctx.autoGetEggEnabled then
                stopEggLoop()
            else
                startEggLoop()
            end
        end
    end)

    -- Update whitelist display
    if #WHITELIST > 0 then
        gui.EggWhitelistInfo.Text = "Collecting: " .. table.concat(WHITELIST, ", ")
    else
        gui.EggWhitelistInfo.Text = "Collecting: ALL rarities"
    end

    -- Initialize rarity display
    updateRarityDisplay()

    ctx.log("Auto Get Egg module loaded (features: ESP, alerts, smart routing, webhook)", THEME.success)
end
