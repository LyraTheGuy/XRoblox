-- FishZone/core.lua
-- Shared context: services, utilities, ESP, clicker, webhook, settings, sell, rewards, anti-idle
-- Modules are loaded separately via main.lua
return function(gui, config)
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TextChatService = game:FindService("TextChatService")

    local lp = Players.LocalPlayer
    local mouse = lp:GetMouse()
    local cam = workspace.CurrentCamera

    local AUTO_SELL_INTERVAL = config.AutoSell and config.AutoSell.Interval or 300
    local AUTO_SELL_RARITIES = config.AutoSell and config.AutoSell.Rarities or
    { "Legend", "Epic", "Rare", "Uncommon", "Common" }
    local TOGGLE_KEY = config.Keys.ToggleClicker
    local HIDE_KEY = config.Keys.HideUI
    local PICK_KEY = config.Keys.PickPosition
    local DEFAULT_CPS = config.Clicker.DefaultCPS
    local POSITION_MODE = config.Clicker.PositionMode
    local FIXED_X, FIXED_Y = config.Clicker.FixedX, config.Clicker.FixedY
    local FISHING_ZONE_PATH = config.FishZone.Path
    local FLOAT_HEIGHT = config.FishZone.FloatHeight
    local BLACKLISTED_POSITIONS = config.FishZone.BlacklistedPositions
    local BLACKLIST_THRESHOLD = config.FishZone.BlacklistThreshold

    -- ═══════════════════════════════════════════
    -- SHARED MUTABLE STATE (ctx table)
    -- ═══════════════════════════════════════════
    -- All mutable booleans/state live in ctx so modules can read/write them in sync
    local ctx = {}

    ctx.gui = gui
    ctx.config = config
    ctx.THEME = gui.Theme
    ctx.lp = lp
    ctx.cam = cam
    ctx.mouse = mouse
    ctx.Players = Players
    ctx.UserInputService = UserInputService
    ctx.RunService = RunService
    ctx.TweenService = TweenService
    ctx.ReplicatedStorage = ReplicatedStorage
    ctx.TextChatService = TextChatService

    -- Mutable state flags
    ctx.clicking = false
    ctx.destroyed = false
    ctx.clickCPS = DEFAULT_CPS
    ctx.clickDelay = 1 / DEFAULT_CPS
    ctx.savedX = FIXED_X
    ctx.savedY = FIXED_Y
    ctx.autoTPEnabled = false
    ctx.autoSellEnabled = false
    ctx.autoFishEnabled = false
    ctx.autoMineEnabled = false
    ctx.autoSellOreEnabled = false
    ctx.autoGachaEnabled = false
    ctx.shopGachaEnabled = false
    ctx.autoClaimDailyRewardEnabled = false
    ctx.autoClaimSessionRewardEnabled = false
    ctx.antiIdleEnabled = false
    ctx.currentZone = nil
    ctx.frozenAnchor = nil
    ctx.frozenGyro = nil
    ctx.hideUI = false
    ctx.zoneESPOn = false
    ctx.playerSearchText = ""
    ctx.minimized = false
    ctx.draggingUI = false
    ctx.draggingSlider = false
    ctx.dragStart = nil
    ctx.startPos = nil
    ctx.lastClick = 0
    ctx.activeTab = "Players"
    ctx.mineESPOn = false
    ctx.mineESPObjects = {}

    -- Mining defaults (module fills in behavior; declared here so Settings
    -- load/save works correctly even before modules/mining.lua has loaded)
    ctx.autoMineHotspotOnly = false
    ctx.autoMineTPEnabled = false
    ctx.ORE_SELL_INTERVAL = 3600
    ctx.oreSellRarities = {
        Common = true, Uncommon = true, Rare = true,
        Epic = true, Legend = true, Mythic = false, Ancient = false,
    }

    -- Performance/sell tracking
    ctx.perfStartTime = tick()
    ctx.perfRarityCounts = {}
    ctx.perfTotalSellValue = 0
    ctx.perfTotalEarnings = 0
    ctx.webhookSellEnabled = false

    -- Collections
    ctx.espObjects = {}
    ctx.zoneObjects = {}
    ctx.playerRows = {}
    ctx.beamStates = {}
    ctx.connections = {}
    ctx.playerConnections = {}
    ctx.zoneAttributeConnections = {}
    ctx.antiIdleConnections = {}
    ctx.antiAfkConnections = {}

    -- Config values exposed for modules
    ctx.AUTO_SELL_INTERVAL = AUTO_SELL_INTERVAL
    ctx.AUTO_SELL_RARITIES = AUTO_SELL_RARITIES
    ctx.TOGGLE_KEY = TOGGLE_KEY
    ctx.HIDE_KEY = HIDE_KEY
    ctx.PICK_KEY = PICK_KEY
    ctx.DEFAULT_CPS = DEFAULT_CPS
    ctx.POSITION_MODE = POSITION_MODE
    ctx.FIXED_X = FIXED_X
    ctx.FIXED_Y = FIXED_Y
    ctx.FISHING_ZONE_PATH = FISHING_ZONE_PATH
    ctx.FLOAT_HEIGHT = FLOAT_HEIGHT
    ctx.BLACKLISTED_POSITIONS = BLACKLISTED_POSITIONS
    ctx.BLACKLIST_THRESHOLD = BLACKLIST_THRESHOLD

    local THEME = ctx.THEME

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
            local children = gui.Logs.LogScroll:GetChildren()
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
        entry.Size = UDim2.new(1, -8, 0, 16)
        entry.BackgroundTransparency = 1
        entry.Text = "[" .. timestamp .. "] " .. tostring(msg)
        entry.TextColor3 = color
        entry.Font = Enum.Font.Code
        entry.TextSize = 11
        entry.TextXAlignment = Enum.TextXAlignment.Left
        entry.TextWrapped = true
        entry.AutomaticSize = Enum.AutomaticSize.Y
        entry.Parent = gui.Logs.LogScroll

        gui.Logs.LogCount.Text = logEntries .. " entries"

        task.defer(function()
            gui.Logs.LogScroll.CanvasPosition = Vector2.new(0, gui.Logs.LogScroll.AbsoluteCanvasSize.Y)
        end)
    end
    ctx.log = log

    -- Clear logs button
    bind(gui.Logs.ClearLogsBtn.MouseButton1Click, function()
        for _, child in ipairs(gui.Logs.LogScroll:GetChildren()) do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        logEntries = 0
        gui.Logs.LogCount.Text = "0 entries"
    end)

    local function getHRP(char)
        return char and char:FindFirstChild("HumanoidRootPart")
    end
    ctx.getHRP = getHRP

    local function getHum(char)
        return char and char:FindFirstChildOfClass("Humanoid")
    end
    ctx.getHum = getHum

    local function resolvePosition()
        if POSITION_MODE == "center" then
            local vp = cam.ViewportSize
            return vp.X / 2, vp.Y / 2
        elseif POSITION_MODE == "custom" then
            return FIXED_X or 960, FIXED_Y or 540
        else
            return ctx.savedX, ctx.savedY
        end
    end
    ctx.resolvePosition = resolvePosition

    local function lower(s)
        return string.lower(tostring(s or ""))
    end
    ctx.lower = lower

    local function isBlacklisted(part)
        for _, bpos in ipairs(BLACKLISTED_POSITIONS) do
            if (part.Position - bpos).Magnitude <= BLACKLIST_THRESHOLD then
                return true
            end
        end
        return false
    end
    ctx.isBlacklisted = isBlacklisted

    local function isActiveZone(part)
        return part and part:IsA("BasePart") and part:GetAttribute("IsActive") == true and not isBlacklisted(part)
    end
    ctx.isActiveZone = isActiveZone

    local function getZoneParts()
        local parts = {}
        for _, part in ipairs(FISHING_ZONE_PATH:GetChildren()) do
            if part:IsA("BasePart") then
                table.insert(parts, part)
            end
        end
        return parts
    end
    ctx.getZoneParts = getZoneParts

    local function getActiveZoneParts()
        local parts = {}
        for _, part in ipairs(getZoneParts()) do
            if isActiveZone(part) then
                table.insert(parts, part)
            end
        end
        return parts
    end
    ctx.getActiveZoneParts = getActiveZoneParts

    local function isInsidePart(hrp, part)
        if not hrp or not part then return false end
        local rel = part.CFrame:PointToObjectSpace(hrp.Position)
        local half = part.Size / 2
        return math.abs(rel.X) <= half.X
            and math.abs(rel.Y) <= half.Y + FLOAT_HEIGHT + 1.5
            and math.abs(rel.Z) <= half.Z
    end
    ctx.isInsidePart = isInsidePart

    local function isInsideAnyActiveZone(hrp)
        if not hrp then return false, nil end
        for _, part in ipairs(getActiveZoneParts()) do
            if isInsidePart(hrp, part) then
                return true, part
            end
        end
        return false, nil
    end
    ctx.isInsideAnyActiveZone = isInsideAnyActiveZone

    local function nearestActiveZonePart()
        local hrp = getHRP(lp.Character)
        if not hrp then return nil end
        local best, bestDist = nil, math.huge
        for _, part in ipairs(getActiveZoneParts()) do
            local d = (hrp.Position - part.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = part
            end
        end
        return best
    end
    ctx.nearestActiveZonePart = nearestActiveZonePart

    local VIM = pcall(function()
        return cloneref(game:GetService("VirtualInputManager"))
    end) and cloneref(game:GetService("VirtualInputManager")) or game:GetService("VirtualInputManager")
    ctx.VIM = VIM

    local useVIM = pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
    ctx.useVIM = useVIM

    local function silentClick(x, y)
        if useVIM then
            VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
            VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
        else
            local cx, cy = mouse.X, mouse.Y
            mousemoveabs(x, y)
            mouse1press()
            mouse1release()
            mousemoveabs(cx, cy)
        end
    end
    ctx.silentClick = silentClick

    local function unfreezeCharacter()
        if ctx.frozenAnchor and ctx.frozenAnchor.Parent then ctx.frozenAnchor:Destroy() end
        ctx.frozenAnchor = nil
        if ctx.frozenGyro and ctx.frozenGyro.Parent then ctx.frozenGyro:Destroy() end
        ctx.frozenGyro = nil
        local hum = getHum(lp.Character)
        if hum then hum.PlatformStand = false end
    end
    ctx.unfreezeCharacter = unfreezeCharacter

    local function freezeAt(pos)
        local char = lp.Character
        local hrp = getHRP(char)
        local hum = getHum(char)
        if not hrp then return end

        local rotCF = CFrame.new(pos) * CFrame.Angles(0, math.rad(89), 0)
        hrp.CFrame = rotCF
        if hum then hum.PlatformStand = true end

        if ctx.frozenAnchor and ctx.frozenAnchor.Parent then ctx.frozenAnchor:Destroy() end
        local bp = Instance.new("BodyPosition")
        bp.Name = "AhzencalZoneFreeze"
        bp.Position = pos
        bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bp.P = 2e4
        bp.D = 1200
        bp.Parent = hrp
        ctx.frozenAnchor = bp

        if ctx.frozenGyro and ctx.frozenGyro.Parent then ctx.frozenGyro:Destroy() end
        local bg = Instance.new("BodyGyro")
        bg.Name = "AhzencalZoneGyro"
        bg.CFrame = CFrame.Angles(0, math.rad(89), 0)
        bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bg.P = 1e5
        bg.D = 500
        bg.Parent = hrp
        ctx.frozenGyro = bg
    end
    ctx.freezeAt = freezeAt

    local function tpToZone(part)
        if not isActiveZone(part) then return false end
        local pos = part.Position + Vector3.new(0, part.Size.Y / 2 + FLOAT_HEIGHT, 0)
        freezeAt(pos)
        ctx.currentZone = part
        return true
    end
    ctx.tpToZone = tpToZone

    local function tpToPlayer(target)
        local hrp = getHRP(lp.Character)
        local targetHRP = getHRP(target.Character)
        if hrp and targetHRP then
            hrp.CFrame = targetHRP.CFrame
        end
    end
    ctx.tpToPlayer = tpToPlayer


    -- ═══════════════════════════════════════════
    -- PLAYER ESP / BEAM / ROWS
    -- ═══════════════════════════════════════════
    local function sendAdonisRefresh(msg)
        pcall(function()
            local defaultEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local sayEvent = defaultEvent and defaultEvent:FindFirstChild("SayMessageRequest")
            if sayEvent then sayEvent:FireServer(msg, "All") end
        end)
        pcall(function()
            if TextChatService and TextChatService.TextChannels then
                local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
                if channel then channel:SendAsync(msg) end
            end
        end)
        pcall(function()
            game:GetService("Players"):Chat(msg)
        end)
    end

    local function refreshCharacterAdonis()
        unfreezeCharacter()
        task.spawn(function()
            task.wait(0.15)
            sendAdonisRefresh("!refresh")
            task.wait(0.4)
            sendAdonisRefresh("/refresh")
        end)
    end
    ctx.refreshCharacterAdonis = refreshCharacterAdonis

    local function removeESPForPlayer(player)
        local obj = ctx.espObjects[player]
        if not obj then return end
        if obj.billboard then obj.billboard:Destroy() end
        if obj.box then obj.box:Destroy() end
        ctx.espObjects[player] = nil
    end
    ctx.removeESPForPlayer = removeESPForPlayer

    local function makeESPForPlayer(player)
        if ctx.espObjects[player] then return end

        local box = Instance.new("BoxHandleAdornment")
        box.Name = "ESP_Box"
        box.Size = Vector3.new(2, 5, 1)
        box.Color3 = THEME.accent
        box.AlwaysOnTop = true
        box.Transparency = 0.45
        box.ZIndex = 5
        box.SizeRelativeOffset = Vector3.new(0, 0.5, 0)

        local bb = Instance.new("BillboardGui")
        bb.Name = "ESP_Tag"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 120, 0, 28)
        bb.StudsOffset = Vector3.new(0, 3, 0)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = player.Name
        lbl.TextColor3 = THEME.accent
        lbl.TextStrokeTransparency = 0
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.Parent = bb

        local function attach(char)
            local hrp = getHRP(char)
            if hrp then
                box.Adornee = hrp
                box.Parent = hrp
                bb.Adornee = hrp
                bb.Parent = hrp
            end
        end

        if player.Character then attach(player.Character) end
        ctx.playerConnections[player] = ctx.playerConnections[player] or {}
        table.insert(ctx.playerConnections[player], player.CharacterAdded:Connect(attach))
        ctx.espObjects[player] = { box = box, billboard = bb }
    end
    ctx.makeESPForPlayer = makeESPForPlayer

    local function stopBeam(player)
        local state = ctx.beamStates[player]
        if not state then return end
        state.enabled = false
        if state.beam then state.beam:Destroy() end
        if state.a0 then state.a0:Destroy() end
        if state.a1 then state.a1:Destroy() end
        ctx.beamStates[player] = nil
    end
    ctx.stopBeam = stopBeam

    local function startBeam(player)
        stopBeam(player)
        local state = { enabled = true }
        ctx.beamStates[player] = state
        task.spawn(function()
            while state.enabled and not ctx.destroyed do
                local myHRP = getHRP(lp.Character)
                local targetHRP = getHRP(player.Character)
                if myHRP and targetHRP then
                    if state.a0 and state.a0.Parent ~= myHRP then
                        state.a0:Destroy(); state.a0 = nil
                    end
                    if state.a1 and state.a1.Parent ~= targetHRP then
                        state.a1:Destroy(); state.a1 = nil
                    end
                    if not state.a0 then state.a0 = Instance.new("Attachment", myHRP) end
                    if not state.a1 then state.a1 = Instance.new("Attachment", targetHRP) end
                    if not state.beam or not state.beam.Parent then
                        local beam = Instance.new("Beam")
                        beam.Attachment0 = state.a0
                        beam.Attachment1 = state.a1
                        beam.Color = ColorSequence.new(THEME.accent)
                        beam.Width0 = 0.12
                        beam.Width1 = 0.12
                        beam.FaceCamera = true
                        beam.Parent = workspace
                        state.beam = beam
                    end
                end
                task.wait(0.25)
            end
            stopBeam(player)
        end)
    end
    ctx.startBeam = startBeam

    local function passesSearch(player)
        if player == lp then return false end
        if ctx.playerSearchText == "" then return true end
        return lower(player.Name):find(lower(ctx.playerSearchText), 1, true) ~= nil
            or lower(player.DisplayName):find(lower(ctx.playerSearchText), 1, true) ~= nil
    end
    ctx.passesSearch = passesSearch

    local function refreshPlayerRows()
        for player, row in pairs(ctx.playerRows) do
            row.Visible = passesSearch(player)
        end
    end
    ctx.refreshPlayerRows = refreshPlayerRows

    local function makePlayerRow(player)
        if player == lp or ctx.playerRows[player] then return end

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 38)
        row.BackgroundColor3 = THEME.panel2
        row.BorderSizePixel = 0
        row.Parent = gui.Players.PlayerList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

        local name = Instance.new("TextLabel")
        name.Text = player.Name
        name.Size = UDim2.new(0, 140, 1, 0)
        name.Position = UDim2.new(0, 10, 0, 0)
        name.BackgroundTransparency = 1
        name.TextColor3 = THEME.text
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.Font = Enum.Font.GothamBold
        name.TextSize = 12
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.Parent = row

        local function miniBtn(txt, offsetFromRight, color)
            local b = Instance.new("TextButton")
            b.Text = txt
            b.Size = UDim2.new(0, 50, 0, 24)
            b.Position = UDim2.new(1, -offsetFromRight, 0.5, -12)
            b.BackgroundColor3 = color
            b.TextColor3 = Color3.new(1, 1, 1)
            b.Font = Enum.Font.GothamBold
            b.TextSize = 10
            b.BorderSizePixel = 0
            b.Parent = row
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
            return b
        end

        local inspectBtn = miniBtn("View", 56, THEME.dim)
        local beamBtn = miniBtn("Beam", 112, THEME.beam)
        local tpBtn = miniBtn("TP", 168, THEME.tp)
        local espBtn = miniBtn("ESP", 224, THEME.accent)
        local espOn = false
        local beamOn = false

        bind(espBtn.MouseButton1Click, function()
            espOn = not espOn
            if espOn then
                makeESPForPlayer(player)
                espBtn.Text = "ESP ✓"
                espBtn.BackgroundColor3 = THEME.success
            else
                removeESPForPlayer(player)
                espBtn.Text = "ESP"
                espBtn.BackgroundColor3 = THEME.accent
            end
        end)

        bind(tpBtn.MouseButton1Click, function()
            tpToPlayer(player)
        end)

        bind(beamBtn.MouseButton1Click, function()
            beamOn = not beamOn
            if beamOn then
                startBeam(player)
                beamBtn.Text = "Beam✓"
                beamBtn.BackgroundColor3 = THEME.warn
            else
                stopBeam(player)
                beamBtn.Text = "Beam"
                beamBtn.BackgroundColor3 = THEME.beam
            end
        end)

        bind(inspectBtn.MouseButton1Click, function()
            pcall(function()
                game:GetService("GuiService"):InspectPlayerFromUserId(player.UserId)
            end)
        end)

        ctx.playerRows[player] = row
        row.Visible = passesSearch(player)
    end
    ctx.makePlayerRow = makePlayerRow

    local function removePlayerRow(player)
        if ctx.playerRows[player] then
            ctx.playerRows[player]:Destroy(); ctx.playerRows[player] = nil
        end
        removeESPForPlayer(player)
        stopBeam(player)
        if ctx.playerConnections[player] then
            disconnectList(ctx.playerConnections[player]); ctx.playerConnections[player] = nil
        end
    end
    ctx.removePlayerRow = removePlayerRow

    -- ═══════════════════════════════════════════
    -- ZONE ESP
    -- ═══════════════════════════════════════════
    local function removeZoneESP(part)
        local obj = ctx.zoneObjects[part]
        if not obj then return end
        if obj.highlight then obj.highlight:Destroy() end
        if obj.billboard then obj.billboard:Destroy() end
        ctx.zoneObjects[part] = nil
    end
    ctx.removeZoneESP = removeZoneESP

    local function addZoneESP(part)
        if ctx.zoneObjects[part] or not isActiveZone(part) then return end

        local sb = Instance.new("SelectionBox")
        sb.Adornee = part
        sb.Color3 = THEME.accent
        sb.LineThickness = 0.06
        sb.SurfaceTransparency = 0.82
        sb.SurfaceColor3 = THEME.accent
        sb.Parent = workspace

        local bb = Instance.new("BillboardGui")
        bb.Adornee = part
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 140, 0, 28)
        bb.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 4, 0)
        bb.Parent = workspace

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Active Zone"
        lbl.TextColor3 = THEME.accent
        lbl.TextStrokeTransparency = 0
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.Parent = bb

        ctx.zoneObjects[part] = { highlight = sb, billboard = bb }
    end
    ctx.addZoneESP = addZoneESP

    local function refreshZoneESP()
        for _, part in ipairs(getZoneParts()) do
            if ctx.zoneESPOn and isActiveZone(part) then
                addZoneESP(part)
            else
                removeZoneESP(part)
            end
        end
    end
    ctx.refreshZoneESP = refreshZoneESP

    local function moveToNearestActiveZone()
        local nearest = nearestActiveZonePart()
        if nearest then
            tpToZone(nearest)
            return true, nearest
        end
        return false, nil
    end
    ctx.moveToNearestActiveZone = moveToNearestActiveZone

    local function stopAutoTP()
        ctx.autoTPEnabled = false
        ctx.currentZone = nil
        unfreezeCharacter()
        gui.FishZone.AutoTPBtn.Text = "Auto TP Active FishZone: OFF"
        gui.FishZone.AutoTPBtn.BackgroundColor3 = THEME.tp
    end
    ctx.stopAutoTP = stopAutoTP

    local function startAutoTP()
        ctx.autoTPEnabled = true
        gui.FishZone.AutoTPBtn.Text = "Auto TP Active FishZone: ON"
        gui.FishZone.AutoTPBtn.BackgroundColor3 = THEME.success
    end
    ctx.startAutoTP = startAutoTP


    -- ═══════════════════════════════════════════
    -- CLICKER UI HELPERS
    -- ═══════════════════════════════════════════
    local function updateClickerUI()
        if ctx.clicking then
            gui.Clicker.StatusLbl.Text = "Status: ON"
            gui.Clicker.StatusLbl.TextColor3 = THEME.success
            gui.Clicker.ToggleBtn.Text = "Stop [" .. tostring(ctx.TOGGLE_KEY):gsub("Enum.KeyCode.", "") .. "]"
            gui.Clicker.ToggleBtn.BackgroundColor3 = THEME.danger
        else
            gui.Clicker.StatusLbl.Text = "Status: OFF"
            gui.Clicker.StatusLbl.TextColor3 = THEME.danger
            gui.Clicker.ToggleBtn.Text = "Start [" .. tostring(ctx.TOGGLE_KEY):gsub("Enum.KeyCode.", "") .. "]"
            gui.Clicker.ToggleBtn.BackgroundColor3 = THEME.accent
        end

        gui.Clicker.MethodLbl.Text = useVIM and "Mode: Silent" or "Mode: Fallback"
        gui.Clicker.MethodLbl.TextColor3 = useVIM and THEME.success or THEME.warn

        local x, y = resolvePosition()
        if x and y then
            gui.Clicker.PosLbl.Text = string.format("Target: (%d, %d)", math.floor(x), math.floor(y))
            gui.Clicker.PosLbl.TextColor3 = THEME.success
        else
            gui.Clicker.PosLbl.Text = "Target: Not set (press " .. tostring(ctx.PICK_KEY):gsub("Enum.KeyCode.", "") .. ")"
            gui.Clicker.PosLbl.TextColor3 = THEME.dim
        end
    end
    ctx.updateClickerUI = updateClickerUI

    local function updateRewardButtons()
        if gui.Settings.AutoClaimDailyRewardBtn then
            gui.Settings.AutoClaimDailyRewardBtn.Text = ctx.autoClaimDailyRewardEnabled and "Auto Claim Daily Reward: ON" or
            "Auto Claim Daily Reward: OFF"
            gui.Settings.AutoClaimDailyRewardBtn.BackgroundColor3 = ctx.autoClaimDailyRewardEnabled and THEME.success or
            THEME.accent
        end
        if gui.Settings.AutoClaimSessionRewardBtn then
            gui.Settings.AutoClaimSessionRewardBtn.Text = ctx.autoClaimSessionRewardEnabled and
            "Auto Claim Session Reward: ON" or "Auto Claim Session Reward: OFF"
            gui.Settings.AutoClaimSessionRewardBtn.BackgroundColor3 = ctx.autoClaimSessionRewardEnabled and THEME.success or
            THEME.tp
        end
    end
    ctx.updateRewardButtons = updateRewardButtons

    local function toggleClicker()
        local x, y = resolvePosition()
        if not x or not y then
            gui.Clicker.PosLbl.Text = "Hover target and press " ..
            tostring(ctx.PICK_KEY):gsub("Enum.KeyCode.", "") .. " first"
            gui.Clicker.PosLbl.TextColor3 = THEME.warn
            log("Clicker: No target position set", THEME.warn)
            return
        end
        ctx.clicking = not ctx.clicking
        if ctx.clicking then
            log("Clicker: ON at (" .. math.floor(x) .. ", " .. math.floor(y) .. ") CPS=" .. ctx.clickCPS, THEME.success)
        else
            log("Clicker: OFF", THEME.danger)
        end
        updateClickerUI()
    end
    ctx.toggleClicker = toggleClicker

    local function applyTheme()
        gui.Main.BackgroundColor3 = THEME.bg
        gui.Header.BackgroundColor3 = THEME.bg2
        gui.HeaderMask.BackgroundColor3 = THEME.bg2
        gui.TabsBar.BackgroundColor3 = THEME.panel
        gui.Content.BackgroundColor3 = THEME.panel
        gui.DragBar.BackgroundColor3 = THEME.accent
        gui.Title.TextColor3 = THEME.text
        gui.Subtitle.TextColor3 = THEME.dim
        gui.MainStroke.Color = THEME.accent:Lerp(Color3.new(1, 1, 1), 0.75)
        gui.ContentStroke.Color = THEME.accent:Lerp(Color3.new(0, 0, 0), 0.45)
        gui.Settings.AccentPreview.BackgroundColor3 = THEME.accent
        gui.Players.SearchBox.BackgroundColor3 = THEME.panel2
        gui.Players.SearchBox.TextColor3 = THEME.text
        gui.Clicker.SliderFill.BackgroundColor3 = THEME.accent

        for name, btn in pairs(gui.TabButtons) do
            if name == ctx.activeTab then
                btn.BackgroundColor3 = THEME.accent
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                btn.BackgroundColor3 = THEME.panel2
                btn.TextColor3 = THEME.dim
            end
        end

        for _, obj in pairs(ctx.espObjects) do
            if obj.box then obj.box.Color3 = THEME.accent end
            if obj.billboard and obj.billboard:FindFirstChildOfClass("TextLabel") then
                obj.billboard:FindFirstChildOfClass("TextLabel").TextColor3 = THEME.accent
            end
        end

        for _, obj in pairs(ctx.zoneObjects) do
            if obj.highlight then
                obj.highlight.Color3 = THEME.accent
                obj.highlight.SurfaceColor3 = THEME.accent
            end
            if obj.billboard and obj.billboard:FindFirstChildOfClass("TextLabel") then
                obj.billboard:FindFirstChildOfClass("TextLabel").TextColor3 = THEME.accent
            end
        end

        updateClickerUI()
        updateRewardButtons()
    end
    ctx.applyTheme = applyTheme

    local function switchTab(name)
        ctx.activeTab = name
        for tabName, frame in pairs(gui.Tabs) do
            frame.Visible = (tabName == name)
        end
        applyTheme()
    end
    ctx.switchTab = switchTab

    local function beginDrag(input)
        ctx.draggingUI = true
        ctx.dragStart = input.Position
        ctx.startPos = gui.Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                ctx.draggingUI = false
            end
        end)
    end
    ctx.beginDrag = beginDrag

    local function playCloseAnimation()
        task.spawn(function()
            local CloseGui = Instance.new("ScreenGui")
            CloseGui.Name = "LyraHubClose"
            CloseGui.ResetOnSpawn = false
            CloseGui.DisplayOrder = 9999
            pcall(function() CloseGui.Parent = game:GetService("CoreGui") end)
            if not CloseGui.Parent then CloseGui.Parent = lp:WaitForChild("PlayerGui") end

            local CloseFrame = Instance.new("Frame")
            CloseFrame.Size = UDim2.new(0, 620, 0, 420)
            CloseFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            CloseFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
            CloseFrame.BackgroundColor3 = Color3.fromRGB(12, 10, 20)
            CloseFrame.BackgroundTransparency = 1
            CloseFrame.BorderSizePixel = 0
            CloseFrame.ClipsDescendants = true
            CloseFrame.Parent = CloseGui
            Instance.new("UICorner", CloseFrame).CornerRadius = UDim.new(0, 12)
            local CloseStroke = Instance.new("UIStroke", CloseFrame)
            CloseStroke.Color = Color3.fromRGB(110, 60, 200)
            CloseStroke.Thickness = 1

            local CloseText = Instance.new("TextLabel")
            CloseText.Text = "Unloaded. Stay safe."
            CloseText.Size = UDim2.new(0, 400, 0, 40)
            CloseText.AnchorPoint = Vector2.new(0.5, 0.5)
            CloseText.Position = UDim2.new(0.5, 0, 0.5, 0)
            CloseText.BackgroundTransparency = 1
            CloseText.TextColor3 = Color3.fromRGB(180, 130, 255)
            CloseText.Font = Enum.Font.GothamBold
            CloseText.TextSize = 24
            CloseText.TextTransparency = 1
            CloseText.Parent = CloseFrame

            TweenService:Create(CloseFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart),
                { BackgroundTransparency = 0.08 }):Play()
            task.wait(0.15)
            TweenService:Create(CloseText, TweenInfo.new(0.35, Enum.EasingStyle.Quart), { TextTransparency = 0 }):Play()
            task.wait(0.8)
            TweenService:Create(CloseFrame, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                { BackgroundTransparency = 1 }):Play()
            TweenService:Create(CloseText, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                { TextTransparency = 1 }):Play()
            task.wait(0.5)
            CloseGui:Destroy()
        end)
    end
    ctx.playCloseAnimation = playCloseAnimation

    local function destroyAll()
        log("Script unloading...", THEME.danger)
        ctx.clicking = false
        ctx.destroyed = true
        ctx.autoTPEnabled = false
        ctx.autoSellEnabled = false
        ctx.autoFishEnabled = false
        ctx.autoMineEnabled = false
        ctx.autoSellOreEnabled = false
        ctx.autoGachaEnabled = false
        ctx.shopGachaEnabled = false
        ctx.autoClaimDailyRewardEnabled = false
        ctx.autoClaimSessionRewardEnabled = false
        ctx.antiIdleEnabled = false
        _G.__AhzencalESP_Destroy = nil
        unfreezeCharacter()
        disconnectList(ctx.connections)
        disconnectList(ctx.zoneAttributeConnections)
        disconnectList(ctx.antiIdleConnections)
        disconnectList(ctx.antiAfkConnections)
        for player in pairs(ctx.espObjects) do removeESPForPlayer(player) end
        for part in pairs(ctx.zoneObjects) do removeZoneESP(part) end
        for player in pairs(ctx.beamStates) do stopBeam(player) end
        for _, list in pairs(ctx.playerConnections) do disconnectList(list) end
        -- Cleanup mine ESP
        pcall(function()
            if ctx.removeMineESP then
                for stone in pairs(ctx.mineESPObjects) do
                    ctx.removeMineESP(stone)
                end
            end
        end)
        playCloseAnimation()
        task.wait(0.05)
        pcall(function() gui.MainGui:Destroy() end)
    end
    ctx.destroyAll = destroyAll

    _G.__AhzencalESP_Destroy = destroyAll


    -- ═══════════════════════════════════════════
    -- SELL / REWARDS
    -- ═══════════════════════════════════════════
    ctx.SellRemote = nil
    ctx.DailyRewardRemote = nil
    ctx.SessionRewardRemote = nil

    task.spawn(function()
        local rf = ReplicatedStorage:WaitForChild("GameRemoteFunctions", 10)
        if rf then
            ctx.SellRemote = rf:WaitForChild("SellAllFishFunction", 10)
            ctx.DailyRewardRemote = rf:WaitForChild("CollectDailyRewardFunction", 10)
            ctx.SessionRewardRemote = rf:WaitForChild("CollectSessionRewardFunctionEvent", 10)
        end
    end)

    local function claimDailyReward()
        if not ctx.DailyRewardRemote then
            return false, "Daily reward remote not loaded"
        end
        local ok, a, b = pcall(function()
            return ctx.DailyRewardRemote:InvokeServer()
        end)
        if not ok then
            return false, tostring(a)
        end
        return a, b
    end
    ctx.claimDailyReward = claimDailyReward

    local function claimSessionReward()
        local rf = game:GetService("ReplicatedStorage"):FindFirstChild("GameRemoteFunctions")
        if not rf then
            return false, "GameRemoteFunctions folder not found"
        end

        local remote = rf:FindFirstChild("CollectSessionRewardFunctionEvent")
            or rf:FindFirstChild("CollectSessionRewardFunction")
            or rf:FindFirstChild("CollectSessionReward")

        if not remote then
            local names = {}
            for _, child in ipairs(rf:GetChildren()) do
                if string.find(string.lower(child.Name), "session") then
                    table.insert(names, child.Name .. " [" .. child.ClassName .. "]")
                end
            end
            local found = #names > 0 and table.concat(names, ", ") or "none with 'session'"
            return false, "Remote not found. Matches: " .. found
        end

        local claimed = 0
        local skipped = 0
        for slot = 1, 12 do
            local ok, result = pcall(function()
                if remote:IsA("RemoteFunction") then
                    return remote:InvokeServer(slot)
                elseif remote:IsA("RemoteEvent") then
                    remote:FireServer(slot)
                    return "fired"
                end
            end)
            if ok and result then
                claimed = claimed + 1
                log("Session slot " .. slot .. ": claimed", THEME.success)
            else
                skipped = skipped + 1
                log("Session slot " .. slot .. ": on cooldown", THEME.dim)
            end
            task.wait(1)
        end
        if claimed > 0 then
            return true, "Claimed " .. claimed .. "/12 (skipped " .. skipped .. ")"
        end
        return false, "All slots on cooldown (" .. skipped .. "/12)"
    end
    ctx.claimSessionReward = claimSessionReward

    local function performSell()
        local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return false, "No HumanoidRootPart found"
        end

        local char = lp.Character
        local isFishing = false
        local rodTool = nil

        if char then
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Tool") and obj:FindFirstChild("Cast") then
                    rodTool = obj
                    break
                end
            end
        end

        if rodTool then
            local isCasting = rodTool:GetAttribute("IsCasting")
            local baitInWater = rodTool:GetAttribute("BaitLandedInWater")
            if isCasting == true or baitInWater == true then
                isFishing = true
            end
        end

        if isFishing then
            return false, "Cannot sell while casting or bait is in water"
        end

        local shopPart = nil
        local world = workspace:FindFirstChild("World")
        if world then
            for _, mapName in ipairs({ "Map_01", "Map_02", "Map_03" }) do
                local currentMap = world:FindFirstChild(mapName)
                if currentMap then
                    local s = currentMap:FindFirstChild("Asset")
                    if s then s = s:FindFirstChild("ShopNPC") end
                    if s then s = s:FindFirstChild("FishShop") end
                    if s then
                        shopPart = s
                        break
                    end
                end
            end
        end

        if not shopPart then
            return false, "FishShop not found!"
        end

        local shopPivot = shopPart:GetPivot()
        local wasAutoTP = ctx.autoTPEnabled
        ctx.autoTPEnabled = false
        local oldCFrame = hrp.CFrame
        local oldAnchorPos = ctx.frozenAnchor and ctx.frozenAnchor.Position
        local targetPos = (shopPivot * CFrame.new(0, 3, 12)).Position

        hrp.CFrame = CFrame.new(targetPos)
        if ctx.frozenAnchor and ctx.frozenAnchor.Parent then
            ctx.frozenAnchor.Position = targetPos
        end

        task.wait(0.3)

        local result
        local sold = false
        local success, err = pcall(function()
            if ctx.SellRemote then
                if ctx.SellRemote:IsA("RemoteFunction") then
                    result = ctx.SellRemote:InvokeServer(ctx.AUTO_SELL_RARITIES)
                    sold = true
                elseif ctx.SellRemote:IsA("RemoteEvent") then
                    ctx.SellRemote:FireServer(ctx.AUTO_SELL_RARITIES)
                    result = "Fired RemoteEvent Payload"
                    sold = true
                end
            end
        end)

        hrp.CFrame = oldCFrame
        if ctx.frozenAnchor and ctx.frozenAnchor.Parent and oldAnchorPos then
            ctx.frozenAnchor.Position = oldAnchorPos
        end
        ctx.autoTPEnabled = wasAutoTP

        if not success then
            return false, result or err
        end
        if not sold then
            -- Nothing was actually sold (remote nil or unexpected class) —
            -- don't report a false SUCCESS.
            return false, "Sell remote not available"
        end

        ctx.perfTotalSellValue = ctx.perfTotalSellValue + 1

        return true, result
    end
    ctx.performSell = performSell

    -- Sell interval input
    bind(gui.FishZone.SellIntervalInput.FocusLost, function()
        local val = tonumber(gui.FishZone.SellIntervalInput.Text)
        if val and val >= 10 then
            ctx.AUTO_SELL_INTERVAL = val
            log("Auto Sell interval: " .. val .. "s", THEME.dim)
        else
            gui.FishZone.SellIntervalInput.Text = tostring(ctx.AUTO_SELL_INTERVAL)
        end
    end)

    bind(gui.FishZone.AutoSellBtn.MouseButton1Click, function()
        ctx.autoSellEnabled = not ctx.autoSellEnabled
        if ctx.autoSellEnabled then
            gui.FishZone.AutoSellBtn.Text = "Auto Sell Fish: ON"
            gui.FishZone.AutoSellBtn.BackgroundColor3 = THEME.success
            log("Auto Sell: ON (interval " .. ctx.AUTO_SELL_INTERVAL .. "s)", THEME.success)
            task.spawn(function()
                while ctx.autoSellEnabled and not ctx.destroyed do
                    if ctx.SellRemote then
                        local ok, msg = performSell()
                        -- msg can be nil when the server returns no result (e.g.
                        -- nothing to sell) — log a friendly value instead of "nil".
                        log("Auto Sell executed: " .. tostring(msg or "ok"), ok and THEME.success or THEME.danger)
                    end
                    task.wait(ctx.AUTO_SELL_INTERVAL)
                end
            end)
        else
            gui.FishZone.AutoSellBtn.Text = "Auto Sell Fish: OFF"
            gui.FishZone.AutoSellBtn.BackgroundColor3 = THEME.warn
            log("Auto Sell: OFF", THEME.dim)
        end
    end)

    bind(gui.FishZone.SellNowBtn.MouseButton1Click, function()
        log("Sell Now: Attempting TP & sell...", THEME.warn)
        if not ctx.SellRemote then
            log("Sell Now: FAILED - remote not loaded", THEME.danger)
            return
        end
        local success, msg = performSell()
        if success then
            log("Sell Now: SUCCESS - " .. tostring(msg or "done"), THEME.success)
        else
            log("Sell Now: FAILED - " .. tostring(msg), THEME.danger)
        end
    end)

    if gui.Settings.AutoClaimDailyRewardBtn then
        bind(gui.Settings.AutoClaimDailyRewardBtn.MouseButton1Click, function()
            ctx.autoClaimDailyRewardEnabled = not ctx.autoClaimDailyRewardEnabled
            updateRewardButtons()
            if ctx.autoClaimDailyRewardEnabled then
                log("Daily Reward: Auto-claim ON (every 1h)", THEME.success)
                task.spawn(function()
                    while ctx.autoClaimDailyRewardEnabled and not ctx.destroyed do
                        local success, message = claimDailyReward()
                        if success then
                            log("Daily Reward: CLAIMED - " .. tostring(message), THEME.success)
                        else
                            log("Daily Reward: " .. tostring(message), THEME.dim)
                        end
                        task.wait(3600)
                    end
                end)
            else
                log("Daily Reward: Auto-claim OFF", THEME.dim)
            end
        end)
    end

    if gui.Settings.AutoClaimSessionRewardBtn then
        bind(gui.Settings.AutoClaimSessionRewardBtn.MouseButton1Click, function()
            ctx.autoClaimSessionRewardEnabled = not ctx.autoClaimSessionRewardEnabled
            updateRewardButtons()
            if ctx.autoClaimSessionRewardEnabled then
                log("Session Reward: Auto-claim ON (every 1h)", THEME.success)
                task.spawn(function()
                    while ctx.autoClaimSessionRewardEnabled and not ctx.destroyed do
                        local success, message = claimSessionReward()
                        if success then
                            log("Session Reward: " .. tostring(message), THEME.success)
                        else
                            log("Session Reward: " .. tostring(message), THEME.dim)
                        end
                        task.wait(3600)
                    end
                end)
            else
                log("Session Reward: Auto-claim OFF", THEME.dim)
            end
        end)
    end

    -- ═══════════════════════════════════════════
    -- ANTI IDLE
    -- ═══════════════════════════════════════════
    local function enableAntiIdle()
        ctx.antiIdleEnabled = true
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
        gui.Settings.AntiIdleBtn.Text = "Anti Idle: ON"
        gui.Settings.AntiIdleBtn.BackgroundColor3 = THEME.success
        log("Anti Idle: ON", THEME.success)
    end

    local function disableAntiIdle()
        ctx.antiIdleEnabled = false
        for _, c in ipairs(ctx.antiIdleConnections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(ctx.antiIdleConnections)
        gui.Settings.AntiIdleBtn.Text = "Anti Idle: OFF"
        gui.Settings.AntiIdleBtn.BackgroundColor3 = THEME.warn
        log("Anti Idle: OFF", THEME.dim)
    end

    if gui.Settings.AntiIdleBtn then
        bind(gui.Settings.AntiIdleBtn.MouseButton1Click, function()
            if ctx.antiIdleEnabled then
                disableAntiIdle()
            else
                enableAntiIdle()
            end
        end)
    end

    -- ═══════════════════════════════════════════
    -- AUTO-RECONNECT (works for private servers)
    -- ═══════════════════════════════════════════
    ctx.autoReconnectEnabled = false
    local savedJobId = game.JobId
    local savedPlaceId = game.PlaceId

    local function attemptReconnect()
        pcall(function()
            local TeleportService = game:GetService("TeleportService")
            TeleportService:TeleportToPlaceInstance(savedPlaceId, savedJobId, lp)
        end)
    end
    ctx.attemptReconnect = attemptReconnect

    -- Listen for kick/disconnect. Tracked in ctx.connections so destroyAll
    -- disconnects it on unload.
    task.spawn(function()
        local conn = ctx.bind(lp.OnTeleport, function(state)
            if state == Enum.TeleportState.Failed and ctx.autoReconnectEnabled then
                task.wait(5)
                attemptReconnect()
            end
        end)
        -- If the script was already unloaded before this spawn ran, undo it.
        if ctx.destroyed then
            pcall(function() conn:Disconnect() end)
        end
    end)


    -- ═══════════════════════════════════════════
    -- WEBHOOK & PERFORMANCE MONITOR
    -- ═══════════════════════════════════════════
    ctx.webhookEnabled = config.Webhook and config.Webhook.Enabled or false
    ctx.webhookURL = config.Webhook and config.Webhook.URL or ""
    ctx.webhookLogRarities = config.Webhook and config.Webhook.LogRarities or {"Ancient"}
    ctx.webhookLogSells = config.Webhook and config.Webhook.LogSells or false

    local function shouldLogRarity(rarity)
        for _, r in ipairs(ctx.webhookLogRarities) do
            if string.lower(r) == string.lower(tostring(rarity)) then
                return true
            end
        end
        return false
    end
    ctx.shouldLogRarity = shouldLogRarity

    local function sendWebhookRaw(payload)
        if not ctx.webhookEnabled or ctx.webhookURL == "" then return end
        task.spawn(function()
            local ok, err = pcall(function()
                local HttpService = game:GetService("HttpService")
                local data = HttpService:JSONEncode(payload)
                local request = (syn and syn.request) or (http and http.request) or http_request or request
                if request then
                    request({
                        Url = ctx.webhookURL,
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = data,
                    })
                end
            end)
            if not ok then
                log("Webhook error: " .. tostring(err), THEME.danger)
            end
        end)
    end
    ctx.sendWebhookRaw = sendWebhookRaw

    local function sendWebhook(title, description, color)
        sendWebhookRaw({
            embeds = {{
                title = title,
                description = description,
                color = color or 10181631,
                thumbnail = {url = "https://tr.rbxcdn.com/180DAY-0250e05e2ec3e54faf2791022401a956/150/150/Image/Webp/noFilter"},
                footer = {text = "LyraHub • " .. lp.Name .. " • " .. os.date("%m/%d/%Y %I:%M %p")},
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        })
    end
    ctx.sendWebhook = sendWebhook

    local function webhookFishCaught(fishName, rarity, weight, price)
        -- Use ctx.shouldLogRarity (not the local captured at definition time) so
        -- the Settings webhook rarity toggles apply to fishing notifications too.
        if not ctx.shouldLogRarity(rarity) then return end
        local priceStr = price and ("Rp." .. tostring(math.floor(tonumber(price) or 0))) or "?"
        local weightStr = weight and (tostring(weight) .. " Kg") or "?"
        local colors = {ancient = 16711680, mythic = 16753920, legend = 16766720, epic = 10494192, secret = 10040115, rare = 3447003}
        local c = colors[string.lower(tostring(rarity))] or 10181631

        sendWebhookRaw({
            embeds = {{
                title = "LyraHub Fish caught!",
                description = "Congrats! **" .. lp.Name .. "** You obtained new **" .. tostring(rarity) .. "** here for full detail fish :",
                color = c,
                thumbnail = {url = "https://tr.rbxcdn.com/180DAY-0250e05e2ec3e54faf2791022401a956/150/150/Image/Webp/noFilter"},
                fields = {
                    {name = "Name Fish :", value = "```" .. tostring(fishName) .. "```", inline = false},
                    {name = "Rarity :", value = "```" .. tostring(rarity) .. "```", inline = false},
                    {name = "Weight :", value = "```" .. weightStr .. "```", inline = false},
                    {name = "Sell Price :", value = "```" .. priceStr .. "```", inline = false},
                },
                footer = {text = "LyraHub • " .. lp.Name .. " • " .. os.date("%m/%d/%Y %I:%M %p")},
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        })
    end
    ctx.webhookFishCaught = webhookFishCaught

    local function formatNumber(n)
        n = tonumber(n) or 0
        if n >= 1e12 then return string.format("%.1fT", n / 1e12)
        elseif n >= 1e9 then return string.format("%.1fB", n / 1e9)
        elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
        elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
        else return tostring(math.floor(n))
        end
    end
    ctx.formatNumber = formatNumber

    local function updatePerfMonitor()
        local totalCaught = 0
        for _, count in pairs(ctx.perfRarityCounts) do
            totalCaught = totalCaught + count
        end

        -- Earnings per hour calculation
        local elapsed = tick() - ctx.perfStartTime
        local earningsPerHour = 0
        if elapsed > 0 then
            earningsPerHour = (ctx.perfTotalEarnings / elapsed) * 3600
        end

        pcall(function()
            gui.FishZone.FishTotalLbl.Text = "Total Fish: " .. tostring(totalCaught) .. " | Rp/hr: " .. formatNumber(earningsPerHour)
        end)

        local mythic = ctx.perfRarityCounts["Mythic"] or 0
        local legend = ctx.perfRarityCounts["Legend"] or 0
        local epic = ctx.perfRarityCounts["Epic"] or 0
        local rare = ctx.perfRarityCounts["Rare"] or 0
        local uncommon = ctx.perfRarityCounts["Uncommon"] or 0
        local common = ctx.perfRarityCounts["Common"] or 0
        local ancient = ctx.perfRarityCounts["Ancient"] or 0

        local statsText = "Mythic: " .. mythic .. " | Legend: " .. legend .. " | Epic: " .. epic
            .. "\nRare: " .. rare .. " | Uncommon: " .. uncommon .. " | Common: " .. common
        if ancient > 0 then
            statsText = "Ancient: " .. ancient .. "\n" .. statsText
        end
        statsText = statsText .. "\nTotal Earnings: Rp " .. formatNumber(ctx.perfTotalEarnings)

        pcall(function()
            gui.FishZone.FishRarityStats.Text = statsText
        end)
    end
    ctx.updatePerfMonitor = updatePerfMonitor

    -- ═══════════════════════════════════════════
    -- SETTINGS SAVE/LOAD (local file persistence)
    -- ═══════════════════════════════════════════
    local SETTINGS_FILE = "LyraHub_Settings.json"

    -- Sell rarity state
    ctx.sellRarities = {}
    for _, r in ipairs(ctx.AUTO_SELL_RARITIES) do
        ctx.sellRarities[r] = true
    end

    -- Webhook rarity state
    ctx.webhookRarityState = {}
    for _, r in ipairs(ctx.webhookLogRarities) do
        ctx.webhookRarityState[r] = true
    end

    local function getActiveSellRarities()
        local list = {}
        for r, on in pairs(ctx.sellRarities) do
            if on then table.insert(list, r) end
        end
        return list
    end
    ctx.getActiveSellRarities = getActiveSellRarities

    local function getActiveWebhookRarities()
        local list = {}
        for r, on in pairs(ctx.webhookRarityState) do
            if on then table.insert(list, r) end
        end
        return list
    end
    ctx.getActiveWebhookRarities = getActiveWebhookRarities

    -- Override shouldLogRarity to use dynamic state
    ctx.shouldLogRarity = function(rarity)
        return ctx.webhookRarityState[tostring(rarity)] == true
    end

    local function updateSellRarityUI()
        for rarity, btn in pairs(gui.FishZone.SellRarityButtons) do
            if ctx.sellRarities[rarity] then
                btn.BackgroundColor3 = THEME.success
                btn.BackgroundTransparency = 0.2
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                btn.BackgroundColor3 = THEME.panel2
                btn.BackgroundTransparency = 0.6
                btn.TextColor3 = THEME.dim
            end
        end
    end
    ctx.updateSellRarityUI = updateSellRarityUI

    local function updateWebhookRarityUI()
        for rarity, btn in pairs(gui.Settings.WebhookRarityButtons) do
            if ctx.webhookRarityState[rarity] then
                btn.BackgroundColor3 = THEME.accent
                btn.BackgroundTransparency = 0.2
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                btn.BackgroundColor3 = THEME.panel2
                btn.BackgroundTransparency = 0.6
                btn.TextColor3 = THEME.dim
            end
        end
    end
    ctx.updateWebhookRarityUI = updateWebhookRarityUI

    -- Bind sell rarity toggles
    for rarity, btn in pairs(gui.FishZone.SellRarityButtons) do
        bind(btn.MouseButton1Click, function()
            ctx.sellRarities[rarity] = not ctx.sellRarities[rarity]
            updateSellRarityUI()
            ctx.AUTO_SELL_RARITIES = getActiveSellRarities()
        end)
    end

    -- Bind webhook rarity toggles
    for rarity, btn in pairs(gui.Settings.WebhookRarityButtons) do
        bind(btn.MouseButton1Click, function()
            ctx.webhookRarityState[rarity] = not ctx.webhookRarityState[rarity]
            updateWebhookRarityUI()
            ctx.webhookLogRarities = getActiveWebhookRarities()
        end)
    end

    local function saveSettings()
        -- Ore sell rarities: convert bool-map to a name list (mirrors getActiveSellRarities)
        local oreSellRaritiesList = {}
        if ctx.oreSellRarities then
            for r, on in pairs(ctx.oreSellRarities) do
                if on then table.insert(oreSellRaritiesList, r) end
            end
        end

        local data = {
            -- Webhook
            webhookURL = ctx.webhookURL,
            webhookEnabled = ctx.webhookEnabled,
            webhookLogSells = ctx.webhookLogSells,
            webhookRarities = getActiveWebhookRarities(),

            -- Fishing: sell interval + rarities
            sellRarities = getActiveSellRarities(),
            sellInterval = ctx.AUTO_SELL_INTERVAL,

            -- Mining: sell interval + rarities + toggles
            oreSellInterval = ctx.ORE_SELL_INTERVAL,
            oreSellRarities = oreSellRaritiesList,
            autoMineHotspotOnly = ctx.autoMineHotspotOnly,
            autoMineTPEnabled = ctx.autoMineTPEnabled,
            mineESPOn = ctx.mineESPOn,

            -- Settings tab toggles
            antiIdleEnabled = ctx.antiIdleEnabled,
            antiAfkEnabled = ctx.antiAfkEnabled,
            autoClaimDailyRewardEnabled = ctx.autoClaimDailyRewardEnabled,
            autoClaimSessionRewardEnabled = ctx.autoClaimSessionRewardEnabled,

            -- Auto Clicker (Fun tab)
            clickCPS = ctx.clickCPS,
            toggleKey = tostring(ctx.TOGGLE_KEY):gsub("Enum.KeyCode.", ""),

            -- Fishing/mining stats persistence
            perfRarityCounts = ctx.perfRarityCounts,
            perfTotalEarnings = ctx.perfTotalEarnings,
        }
        local ok, err = pcall(function()
            local HttpService = game:GetService("HttpService")
            local json = HttpService:JSONEncode(data)
            writefile(SETTINGS_FILE, json)
        end)
        if ok then
            gui.Settings.SaveStatus.Text = "Settings saved!"
            gui.Settings.SaveStatus.TextColor3 = THEME.success
            log("Settings saved", THEME.success)
        else
            gui.Settings.SaveStatus.Text = "Save failed: " .. tostring(err)
            gui.Settings.SaveStatus.TextColor3 = THEME.danger
            log("Settings save failed: " .. tostring(err), THEME.danger)
        end
        task.delay(3, function()
            if gui.Settings.SaveStatus and gui.Settings.SaveStatus.Parent then
                gui.Settings.SaveStatus.Text = ""
            end
        end)
    end
    ctx.saveSettings = saveSettings

    local function loadSettings()
        local ok, result = pcall(function()
            if isfile and isfile(SETTINGS_FILE) then
                local raw = readfile(SETTINGS_FILE)
                local HttpService = game:GetService("HttpService")
                return HttpService:JSONDecode(raw)
            end
            return nil
        end)
        if ok and result then
            if result.webhookURL then
                ctx.webhookURL = result.webhookURL
                gui.Settings.WebhookInput.Text = ctx.webhookURL
            end
            if result.webhookEnabled ~= nil then
                ctx.webhookEnabled = result.webhookEnabled
            end
            if result.webhookLogSells ~= nil then
                ctx.webhookLogSells = result.webhookLogSells
            end
            if result.webhookRarities then
                ctx.webhookRarityState = {}
                for _, r in ipairs(result.webhookRarities) do
                    ctx.webhookRarityState[r] = true
                end
                ctx.webhookLogRarities = result.webhookRarities
            end
            if result.sellRarities then
                ctx.sellRarities = {}
                for _, r in ipairs(result.sellRarities) do
                    ctx.sellRarities[r] = true
                end
                ctx.AUTO_SELL_RARITIES = result.sellRarities
            end
            if result.sellInterval then
                ctx.AUTO_SELL_INTERVAL = tonumber(result.sellInterval) or ctx.AUTO_SELL_INTERVAL
                gui.FishZone.SellIntervalInput.Text = tostring(ctx.AUTO_SELL_INTERVAL)
            end

            -- Mining: sell rarities + interval
            if result.oreSellRarities then
                ctx.oreSellRarities = {}
                for _, r in ipairs(result.oreSellRarities) do
                    ctx.oreSellRarities[r] = true
                end
                if ctx.updateOreSellRarityUI then ctx.updateOreSellRarityUI() end
            end
            if result.oreSellInterval and gui.Mining then
                ctx.ORE_SELL_INTERVAL = tonumber(result.oreSellInterval) or ctx.ORE_SELL_INTERVAL
                gui.Mining.SellIntervalInput.Text = tostring(ctx.ORE_SELL_INTERVAL)
            end

            -- Mining toggles
            if result.autoMineHotspotOnly ~= nil then
                ctx.autoMineHotspotOnly = result.autoMineHotspotOnly
                if ctx.updateHotspotBtnUI then ctx.updateHotspotBtnUI() end
            end
            if result.autoMineTPEnabled ~= nil then
                ctx.autoMineTPEnabled = result.autoMineTPEnabled
                if ctx.updateMineTPBtnUI then ctx.updateMineTPBtnUI() end
            end
            if result.mineESPOn ~= nil then
                ctx.mineESPOn = result.mineESPOn
                if gui.Mining then
                    if ctx.mineESPOn then
                        gui.Mining.ESPBtn.Text = "Hotspot ESP: ON"
                        gui.Mining.ESPBtn.BackgroundColor3 = THEME.success
                    else
                        gui.Mining.ESPBtn.Text = "Hotspot ESP: OFF"
                        gui.Mining.ESPBtn.BackgroundColor3 = THEME.warn
                    end
                end
            end

            -- Settings tab: Anti-Idle / Auto Claim toggles are restored by calling
            -- the same enable logic used by their buttons (defined earlier in this scope).
            if result.antiIdleEnabled and not ctx.antiIdleEnabled then
                enableAntiIdle()
            end
            -- Anti AFK is applied by modules/antiafk.lua, which reads
            -- ctx.antiAfkEnabled when it loads (after this runs).
            if result.antiAfkEnabled ~= nil then
                ctx.antiAfkEnabled = result.antiAfkEnabled
            end
            if result.autoClaimDailyRewardEnabled and not ctx.autoClaimDailyRewardEnabled then
                ctx.autoClaimDailyRewardEnabled = true
                updateRewardButtons()
                log("Daily Reward: Auto-claim ON (restored, every 1h)", THEME.success)
                task.spawn(function()
                    while ctx.autoClaimDailyRewardEnabled and not ctx.destroyed do
                        local success, message = claimDailyReward()
                        if success then
                            log("Daily Reward: CLAIMED - " .. tostring(message), THEME.success)
                        else
                            log("Daily Reward: " .. tostring(message), THEME.dim)
                        end
                        task.wait(3600)
                    end
                end)
            end
            if result.autoClaimSessionRewardEnabled and not ctx.autoClaimSessionRewardEnabled then
                ctx.autoClaimSessionRewardEnabled = true
                updateRewardButtons()
                log("Session Reward: Auto-claim ON (restored, every 1h)", THEME.success)
                task.spawn(function()
                    while ctx.autoClaimSessionRewardEnabled and not ctx.destroyed do
                        local success, message = claimSessionReward()
                        if success then
                            log("Session Reward: " .. tostring(message), THEME.success)
                        else
                            log("Session Reward: " .. tostring(message), THEME.dim)
                        end
                        task.wait(3600)
                    end
                end)
            end

            -- Auto Clicker (Fun tab): CPS + keybind
            if result.clickCPS then
                ctx.clickCPS = tonumber(result.clickCPS) or ctx.clickCPS
                ctx.clickDelay = 1 / ctx.clickCPS
                if ctx.updateClickerSliderUI then ctx.updateClickerSliderUI() end
            end
            if result.toggleKey and Enum.KeyCode[result.toggleKey] then
                ctx.TOGGLE_KEY = Enum.KeyCode[result.toggleKey]
                if ctx.updateKeybindUI then ctx.updateKeybindUI() end
            end

            -- Load mining/fishing stats
            if result.perfRarityCounts and type(result.perfRarityCounts) == "table" then
                ctx.perfRarityCounts = result.perfRarityCounts
            end
            if result.perfTotalEarnings then
                ctx.perfTotalEarnings = tonumber(result.perfTotalEarnings) or 0
            end
            gui.Settings.WebhookToggleBtn.Text = ctx.webhookEnabled and "Webhook: ON" or "Webhook: OFF"
            gui.Settings.WebhookToggleBtn.BackgroundColor3 = ctx.webhookEnabled and THEME.success or THEME.panel2
            updateSellRarityUI()
            updateWebhookRarityUI()
            log("Settings loaded", THEME.dim)
        end
    end
    ctx.loadSettings = loadSettings

    -- Webhook toggle button
    bind(gui.Settings.WebhookToggleBtn.MouseButton1Click, function()
        ctx.webhookEnabled = not ctx.webhookEnabled
        gui.Settings.WebhookToggleBtn.Text = ctx.webhookEnabled and "Webhook: ON" or "Webhook: OFF"
        gui.Settings.WebhookToggleBtn.BackgroundColor3 = ctx.webhookEnabled and THEME.success or THEME.panel2
        log("Webhook: " .. (ctx.webhookEnabled and "ON" or "OFF"), ctx.webhookEnabled and THEME.success or THEME.dim)
    end)

    -- Test webhook button
    bind(gui.Settings.WebhookTestBtn.MouseButton1Click, function()
        ctx.webhookURL = gui.Settings.WebhookInput.Text
        if ctx.webhookURL == "" then
            log("Webhook test: No URL set!", THEME.danger)
            return
        end
        local oldEnabled = ctx.webhookEnabled
        ctx.webhookEnabled = true
        sendWebhookRaw({
            embeds = {{
                title = "🧪 LyraHub Webhook Test",
                description = "Congrats! **" .. lp.Name .. "** your webhook is working!",
                color = 10181631,
                thumbnail = {url = "https://tr.rbxcdn.com/180DAY-0250e05e2ec3e54faf2791022401a956/150/150/Image/Webp/noFilter"},
                fields = {
                    {name = "Status :", value = "```Connected```", inline = true},
                    {name = "Log Rarities :", value = "```" .. table.concat(getActiveWebhookRarities(), ", ") .. "```", inline = false},
                },
                footer = {text = "LyraHub • " .. lp.Name .. " • " .. os.date("%m/%d/%Y %I:%M %p")},
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        })
        ctx.webhookEnabled = oldEnabled
        log("Webhook test sent!", THEME.success)
    end)

    -- Webhook URL input
    bind(gui.Settings.WebhookInput.FocusLost, function()
        ctx.webhookURL = gui.Settings.WebhookInput.Text
    end)

    -- Save settings button
    bind(gui.Settings.SaveSettingsBtn.MouseButton1Click, function()
        ctx.webhookURL = gui.Settings.WebhookInput.Text
        saveSettings()
    end)

    -- Load config button: re-reads LyraHub_Settings.json and re-applies it
    if gui.Settings.LoadSettingsBtn then
        bind(gui.Settings.LoadSettingsBtn.MouseButton1Click, function()
            loadSettings()
            updateSellRarityUI()
            updateWebhookRarityUI()
            gui.Settings.SaveStatus.Text = "Config loaded!"
            gui.Settings.SaveStatus.TextColor3 = THEME.success
            task.delay(3, function()
                if gui.Settings.SaveStatus and gui.Settings.SaveStatus.Parent then
                    gui.Settings.SaveStatus.Text = ""
                end
            end)
        end)
    end

    -- Auto-load settings on start
    loadSettings()
    updateSellRarityUI()
    updateWebhookRarityUI()

    -- About tab: copy saweria link
    bind(gui.About.CopySaweriaBtn.MouseButton1Click, function()
        pcall(function()
            setclipboard("https://saweria.co/ahzencal")
        end)
        gui.About.CopySaweriaBtn.Text = "Copied!"
        gui.About.CopySaweriaBtn.BackgroundColor3 = THEME.success
        task.delay(2, function()
            if gui.About.CopySaweriaBtn and gui.About.CopySaweriaBtn.Parent then
                gui.About.CopySaweriaBtn.Text = "Copy"
                gui.About.CopySaweriaBtn.BackgroundColor3 = THEME.accent
            end
        end)
    end)

    return ctx
end
