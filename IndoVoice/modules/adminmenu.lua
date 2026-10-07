-- ============================================================================
-- IndoVoice/modules/adminmenu.lua
-- ============================================================================
-- PLAYER ADMIN MENU  (ESP / BEAM / VIEW / TP)
-- ----------------------------------------------------------------------------
-- Revamps the old per-player row buttons (ESP / Beam / TP / View) into a single
-- admin panel mounted in the Players tab. The menu reads the live player list
-- straight from the shared Players service (ctx.Players) and drives four
-- features against a selected target:
--
--   ESP  -> global overlay: name, color-coded health bar, distance text and a
--           box / highlight outline. Updates are throttled.
--   BEAM -> visual beam from your character to the target. Customizable color,
--           thickness, transparency and style (solid / pulse / rainbow).
--   VIEW -> scriptable camera: smooth third-person follow, first-person or an
--           orbiting camera around the target, with exponential smoothing.
--   TP   -> guarded teleport with a "disable condition" submenu. Every guard
--           (confirm click, cooldown, dead target, dead self, staff target,
--           safe-zone target, in-combat) is a toggle with LIVE status, and all
--           guards default ON so a misclick can never fire a teleport.
--
-- Everything heavy (ESP refresh, beam rebuild, camera step, TP status) runs on
-- ONE throttled RenderStepped loop. Every feature exposes its own cleanup and
-- the module registers ctx.adminMenuCleanup so a global unload tears it down.
--
-- CUSTOMIZE: the CFG tables below hold every tunable. No other file needs edits.
-- ============================================================================

return function(ctx)
    -- ------------------------------------------------------------------
    -- Shared references (from the ctx created in core.lua)
    -- ------------------------------------------------------------------
    local Players = ctx.Players
    local RunService = ctx.RunService
    local UserInputService = ctx.UserInputService
    local lp = ctx.lp
    local cam = ctx.cam
    local gui = ctx.gui
    local THEME = ctx.THEME
    local config = ctx.config
    local bind = ctx.bind
    local log = ctx.log
    local getHRP = ctx.getHRP
    local getHum = ctx.getHum

    -- ==================================================================
    -- CUSTOMIZATION TABLES
    -- ==================================================================
    -- ESP options -------------------------------------------------------
    local ESP_CFG = {
        Interval = 0.12,               -- seconds between ESP refreshes (throttle)
        MaxDistance = 1500,            -- hide ESP beyond this many studs
        Outline = "box",               -- "box" | "highlight" | "both" | "none"
        Scope = "target",              -- "target" (selected player only) | "all"
        UseInGameName = true,          -- show the name the GAME displays overhead
        ShowName = true,
        ColorMode = "health",          -- "health" | "accent" | "static"
        StaticColor = Color3.fromRGB(155, 89, 255),
        RequireLineOfSight = false,    -- raycast wall check (off = cheaper)
    }

    -- Health colour coding (green / yellow / red)
    local HEALTH_COLORS = {
        high = Color3.fromRGB(80, 220, 140),
        mid = Color3.fromRGB(255, 200, 80),
        low = Color3.fromRGB(255, 80, 100),
    }
    local HEALTH_HIGH = 0.66 -- >= this fraction => green
    local HEALTH_LOW = 0.33  -- <  this fraction => red

    -- Beam options ------------------------------------------------------
    local BEAM_CFG = {
        Interval = 0.05,               -- seconds between beam updates (throttle)
        Color = THEME.beam or Color3.fromRGB(255, 130, 90),
        Thickness = 0.15,              -- Width0 / Width1 in studs
        Transparency = 0.15,           -- 0 = opaque, 1 = invisible
        Style = "solid",               -- "solid" | "pulse" | "rainbow"
    }

    -- View camera options ----------------------------------------------
    local VIEW_CFG = {
        Smoothness = 8,                -- exponential smoothing factor
        Mode = "follow",               -- "follow" | "firstperson" | "orbit"
        Distance = 12,                 -- third-person follow distance
        Height = 4,                    -- third-person follow height
        OrbitSpeed = 25,               -- degrees / second (orbit mode)
        OrbitRadius = 14,              -- studs (orbit mode)
    }

    -- Temporary teleport (TP) guard defaults. All guards default ON so a
    -- misclick cannot teleport you; the player explicitly opts out.
    local TP = {
        RequireConfirm = true,         -- first click arms, second click fires
        ConfirmWindow = 2.0,           -- seconds the confirmation stays armed
        Cooldown = 3,                  -- minimum seconds between teleports
        BlockTargetDead = true,
        BlockSelfDead = true,
        BlockStaff = true,
        BlockSafeZone = true,
        BlockInCombat = false,
    }

    -- Colour palette used by the beam / ESP colour swatches.
    local PALETTE = (config and config.ThemePresets) or {
        Color3.fromRGB(0, 170, 255),
        Color3.fromRGB(132, 97, 255),
        Color3.fromRGB(255, 96, 140),
        Color3.fromRGB(67, 214, 125),
        Color3.fromRGB(255, 170, 0),
        Color3.fromRGB(255, 120, 84),
    }

    -- ==================================================================
    -- STATE
    -- ==================================================================
    -- S holds everything mutable. Keeping it in one table keeps the module
    -- function below well under Luau's 200-local register limit.
    local S = {
        target = nil,             -- currently selected Player
        selectedFeature = "ESP",  -- which options panel is visible
        espOn = false,
        beamOn = false,
        viewOn = false,
        lastTP = -1e9,            -- tick of last successful teleport (never on cooldown at start)
        confirmUntil = 0,         -- tick until which a confirm is armed
        confirmArmed = false,     -- whether the current confirm click was armed
        esp = {},                 -- [player] = { billboard = ..., box = ..., hl = ... }
        beam = nil,               -- { target = player, a0 = ..., a1 = ..., beam = ..., t = 0 }
        view = nil,               -- { target = player, angle = 0, savedType = ..., savedSubject = ... }
        rows = {},                -- [player] = { button = ..., hp = ... }
        rowMeta = {},             -- [player] = { hp = TextLabel, dist = TextLabel }
        nameScan = {},            -- [player] = { char, text } — overhead tag scan (once per character)
    }

    -- Forward declarations (these are defined further down but referenced by
    -- closures above them, so they must exist as locals up front).
    local refreshPlayerList, healthColor, refreshToolbar, syncToggles, setBeam, setView, updateESP, toggleTargetVisuals, stopBeam, startBeam

    -- ==================================================================
    -- SMALL UI HELPERS
    -- ==================================================================
    local function corner(obj, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 8)
        c.Parent = obj
        return c
    end

    local function stroke(obj, color, thickness)
        local s = Instance.new("UIStroke")
        s.Color = color or THEME.divider
        s.Thickness = thickness or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = obj
        return s
    end

    local function makeLabel(parent, props)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.TextColor3 = THEME.text
        l.Font = Enum.Font.Gotham
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Center
        for k, v in pairs(props) do
            if k ~= "Parent" then l[k] = v end
        end
        l.Parent = parent
        return l
    end

    local function makeButton(parent, props)
        local b = Instance.new("TextButton")
        b.AutoButtonColor = false
        b.BackgroundColor3 = THEME.panel2
        b.TextColor3 = THEME.text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.BorderSizePixel = 0
        for k, v in pairs(props) do
            if k ~= "Parent" then b[k] = v end
        end
        b.Parent = parent
        corner(b, 6)
        return b
    end

    -- ==================================================================
    -- ROOT CONTAINER (supplied by gui.lua Players tab)
    -- ==================================================================
    local root = gui.Players and gui.Players.Admin
    if not root then
        -- Graceful degradation: build into the raw tab if the container is
        -- missing (older gui.lua). Never error out the whole script over UI.
        root = gui.Tabs and gui.Tabs.Players
    end
    if not root then
        warn("[AdminMenu] No Players container found — module skipped.")
        return
    end

    local U = { featureBtns = {}, panels = {}, condRows = {} }

    -- Title -----------------------------------------------------------------
    makeLabel(root, {
        Text = "👤 Player Admin Menu",
        Position = UDim2.new(0, 10, 0, 6),
        Size = UDim2.new(1, -20, 0, 14),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.accentGlow or THEME.accent,
    })

    -- Toolbar (4 feature buttons) ------------------------------------------
    local toolbar = Instance.new("Frame")
    toolbar.BackgroundTransparency = 1
    toolbar.Position = UDim2.new(0, 10, 0, 24)
    toolbar.Size = UDim2.new(1, -20, 0, 30)
    toolbar.Parent = root

    local FEATURES = { "ESP", "BEAM", "VIEW", "TP" }
    for i, name in ipairs(FEATURES) do
        local btn = makeButton(toolbar, {
            Text = name,
            Size = UDim2.new(0.25, -5, 1, 0),
            Position = UDim2.new((i - 1) * 0.25, (i - 1) * 2 + 1, 0, 0),
            TextSize = 11,
        })
        U.featureBtns[name] = btn
    end

    -- Body: left = target list, right = options panels ---------------------
    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 10, 0, 60)
    body.Size = UDim2.new(1, -20, 1, -70)
    body.Parent = root

    -- Left: target selection
    local targetPanel = Instance.new("Frame")
    targetPanel.BackgroundColor3 = THEME.bg2
    targetPanel.BackgroundTransparency = 0.35
    targetPanel.BorderSizePixel = 0
    targetPanel.Size = UDim2.new(0, 168, 1, 0)
    targetPanel.Parent = body
    corner(targetPanel, 8)

    U.search = Instance.new("TextBox")
    U.search.PlaceholderText = "Search player..."
    U.search.Text = ""
    U.search.ClearTextOnFocus = false
    U.search.Size = UDim2.new(1, -12, 0, 24)
    U.search.Position = UDim2.new(0, 6, 0, 6)
    U.search.BackgroundColor3 = THEME.panel2
    U.search.TextColor3 = THEME.text
    U.search.PlaceholderColor3 = THEME.dim
    U.search.Font = Enum.Font.Gotham
    U.search.TextSize = 11
    U.search.BorderSizePixel = 0
    U.search.Parent = targetPanel
    corner(U.search, 6)

    local list = Instance.new("ScrollingFrame")
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.Position = UDim2.new(0, 6, 0, 34)
    list.Size = UDim2.new(1, -12, 1, -40)
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Parent = targetPanel
    U.list = list

    -- Right: feature options panel
    local optionsPanel = Instance.new("Frame")
    optionsPanel.BackgroundColor3 = THEME.bg2
    optionsPanel.BackgroundTransparency = 0.35
    optionsPanel.BorderSizePixel = 0
    optionsPanel.Position = UDim2.new(0, 176, 0, 0)
    optionsPanel.Size = UDim2.new(1, -176, 1, 0)
    optionsPanel.Parent = body
    corner(optionsPanel, 8)

    local function makeSubPanel(name)
        local p = Instance.new("ScrollingFrame")
        p.Name = name .. "Panel"
        p.BackgroundTransparency = 1
        p.BorderSizePixel = 0
        p.ScrollBarThickness = 3
        p.Size = UDim2.new(1, -8, 1, -8)
        p.Position = UDim2.new(0, 4, 0, 4)
        p.CanvasSize = UDim2.new(0, 0, 0, 0)
        p.AutomaticCanvasSize = Enum.AutomaticSize.Y
        p.Visible = false
        p.Parent = optionsPanel
        U.panels[name] = p
        return p
    end

    -- ==================================================================
    -- REUSABLE OPTION WIDGETS
    -- ==================================================================
    -- Toggle row: checkbox + label. onChange(state) fires on click.
    local function toggleRow(parent, y, text, initial, onChange)
        local row = makeButton(parent, {
            Text = "",
            Size = UDim2.new(1, -8, 0, 24),
            Position = UDim2.new(0, 4, 0, y),
            BackgroundTransparency = 0.4,
        })
        local box = Instance.new("Frame")
        box.Size = UDim2.new(0, 14, 0, 14)
        box.Position = UDim2.new(0, 6, 0.5, -7)
        box.BackgroundColor3 = THEME.panel
        box.BorderSizePixel = 0
        box.Parent = row
        corner(box, 4)
        local boxStroke = stroke(box, THEME.dim, 1)
        local tick = makeLabel(box, { Text = "", Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
        makeLabel(row, { Text = text, Position = UDim2.new(0, 28, 0, 0), Size = UDim2.new(1, -34, 1, 0), TextSize = 10 })

        local state = initial and true or false
        local function refresh()
            if state then
                box.BackgroundColor3 = THEME.success
                boxStroke.Color = THEME.success
                tick.Text = "✓"
                tick.TextColor3 = Color3.new(1, 1, 1)
            else
                box.BackgroundColor3 = THEME.panel
                boxStroke.Color = THEME.dim
                tick.Text = ""
            end
        end
        local function setState(v, fire)
            state = v and true or false
            refresh()
            if fire and onChange then onChange(state) end
        end
        refresh()
        bind(row.MouseButton1Click, function()
            setState(not state, true)
        end)
        return setState, function()
            return state
        end
    end

    -- Segmented row: mutually exclusive option buttons.
    local function segRow(parent, y, text, options, initial, onChange)
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, -8, 0, 42)
        row.Position = UDim2.new(0, 4, 0, y)
        row.Parent = parent
        makeLabel(row, { Text = text, Size = UDim2.new(1, 0, 0, 14), TextSize = 10, TextColor3 = THEME.dim })

        local btns = {}
        local current = initial
        local function refresh()
            for value, b in pairs(btns) do
                if value == current then
                    b.BackgroundColor3 = THEME.accent
                    b.TextColor3 = Color3.new(1, 1, 1)
                else
                    b.BackgroundColor3 = THEME.panel2
                    b.TextColor3 = THEME.dim
                end
            end
        end
        local n = #options
        for i, opt in ipairs(options) do
            local b = makeButton(row, {
                Text = opt.label,
                Size = UDim2.new(1 / n, -4, 0, 22),
                Position = UDim2.new((i - 1) / n, 2, 0, 18),
                TextSize = 9,
            })
            btns[opt.value] = b
            bind(b.MouseButton1Click, function()
                current = opt.value
                refresh()
                if onChange then onChange(opt.value) end
            end)
        end
        refresh()
        return function(v)
            current = v
            refresh()
        end
    end

    -- Slider row with a draggable knob. fmt controls the value readout.
    local activeSlider = nil
    local function sliderRow(parent, y, text, min, max, value, fmt, onChange)
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, -8, 0, 36)
        row.Position = UDim2.new(0, 4, 0, y)
        row.Parent = parent
        local lbl = makeLabel(row, { Text = text, Size = UDim2.new(1, 0, 0, 14), TextSize = 10, TextColor3 = THEME.dim })

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -8, 0, 6)
        track.Position = UDim2.new(0, 4, 0, 22)
        track.BackgroundColor3 = THEME.panel2
        track.BorderSizePixel = 0
        track.Parent = row
        corner(track, 3)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = THEME.accent
        fill.BorderSizePixel = 0
        fill.Parent = track
        corner(fill, 3)

        local knob = makeButton(track, {
            Text = "",
            Size = UDim2.new(0, 14, 0, 14),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = THEME.accentGlow or THEME.accent,
        })
        corner(knob, 7)

        fmt = fmt or "%.2f"
        local function setValue(v, fire)
            v = math.clamp(v, min, max)
            local ratio = (v - min) / (max - min)
            fill.Size = UDim2.new(ratio, 0, 1, 0)
            knob.Position = UDim2.new(ratio, 0, 0.5, 0)
            lbl.Text = text .. ": " .. string.format(fmt, v)
            if fire and onChange then onChange(v) end
        end
        setValue(value, false)
        bind(knob.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                activeSlider = { track = track, min = min, max = max, setValue = setValue }
            end
        end)
        return setValue
    end

    -- One shared InputChanged / InputEnded pair drives every slider.
    bind(UserInputService.InputChanged, function(i)
        if activeSlider and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local rel = (i.Position.X - activeSlider.track.AbsolutePosition.X) /
                math.max(1, activeSlider.track.AbsoluteSize.X)
            activeSlider.setValue(activeSlider.min + rel * (activeSlider.max - activeSlider.min), true)
        end
    end)
    bind(UserInputService.InputEnded, function(i)
        if activeSlider and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            activeSlider = nil
        end
    end)

    -- A row of colour swatches.
    local function swatchRow(parent, y, text, initial, onChange)
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, -8, 0, 40)
        row.Position = UDim2.new(0, 4, 0, y)
        row.Parent = parent
        makeLabel(row, { Text = text, Size = UDim2.new(1, 0, 0, 14), TextSize = 10, TextColor3 = THEME.dim })
        for i, col in ipairs(PALETTE) do
            local sw = makeButton(row, {
                Text = "",
                Size = UDim2.new(0, 22, 0, 18),
                Position = UDim2.new(0, (i - 1) * 26, 0, 18),
                BackgroundColor3 = col,
            })
            bind(sw.MouseButton1Click, function()
                if onChange then onChange(col) end
            end)
        end
    end

    -- ==================================================================
    -- PLAYER DETECTION / TARGETING  (reads the shared Players service)
    -- ==================================================================
    local function isStaff(player)
        if not player then
            return false
        end
        for _, attr in ipairs({ "IsAdmin", "IsStaff", "Admin", "Staff", "isAdmin", "isStaff" }) do
            if player:GetAttribute(attr) == true then
                return true
            end
        end
        local char = player.Character
        if char then
            if char:FindFirstChild("AdminTag") or char:FindFirstChild("ModTag") or char:FindFirstChild("StaffTag") then
                return true
            end
        end
        return false
    end

    local function inSafeZone(target)
        if not target then
            return false
        end
        local char = target.Character
        if not char then
            return false
        end
        if char:GetAttribute("InSafeZone") == true or char:GetAttribute("SafeZone") == true then
            return true
        end
        local hrp = getHRP(char)
        if not hrp then
            return false
        end
        for _, name in ipairs({ "SafeZones", "SafeZone", "NoTPZones", "NoTeleportZones" }) do
            local folder = workspace:FindFirstChild(name)
            if folder then
                for _, part in ipairs(folder:GetDescendants()) do
                    if part:IsA("BasePart") then
                        local rel = part.CFrame:PointToObjectSpace(hrp.Position)
                        local half = part.Size / 2
                        if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- Combat tracking: flag "in combat" for 3s after the local player loses HP.
    local lastCombat = 0
    local COMBAT_MEMORY = 3
    local function hookCombat(char)
        local hum = getHum(char)
        if not hum then
            return
        end
        local prev
        bind(hum.HealthChanged, function(hp)
            if prev and hp < prev then
                lastCombat = tick()
            end
            prev = hp
        end)
    end
    hookCombat(lp.Character)
    bind(lp.CharacterAdded, hookCombat)

    local function selectTarget(player)
        if player == lp then
            return
        end
        S.target = player
        log("AdminMenu: target → " .. player.Name, THEME.accentGlow or THEME.accent)
        -- Re-point an already-running beam / view at the new target.
        -- IMPORTANT: destroy the old beam FIRST. Replacing S.beam directly
        -- orphans the old Beam instance in workspace (the "stuck beam").
        if S.beamOn then
            stopBeam()
            startBeam(player)
        end
        if S.viewOn and S.view then
            S.view.target = player
            S.view.angle = 0
        end
        -- ESP follows the selection, so refresh it right away.
        if S.espOn then
            updateESP()
        end
        refreshPlayerList()
    end

    local function buildPlayerRow(player, y)
        local row = makeButton(list, {
            Text = "",
            Size = UDim2.new(1, -4, 0, 26),
            Position = UDim2.new(0, 2, 0, y),
            BackgroundColor3 = THEME.panel2,
            BackgroundTransparency = 0.3,
        })
        local selected = (player == S.target)
        if selected then
            row.BackgroundColor3 = THEME.accent
            row.BackgroundTransparency = 0
        end
        makeLabel(row, {
            Text = player.DisplayName,
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(1, -70, 1, 0),
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextColor3 = selected and Color3.new(1, 1, 1) or THEME.text,
        })
        local hp = makeLabel(row, {
            Text = "",
            Position = UDim2.new(1, -58, 0, 0),
            Size = UDim2.new(0, 52, 1, 0),
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = THEME.dim,
        })
        -- The name row IS the switch: click = ESP + Beam on for this player,
        -- click again = off. VIEW / TP keep using the selected target.
        bind(row.MouseButton1Click, function()
            toggleTargetVisuals(player)
        end)
        S.rows[player] = row
        S.rowMeta[player] = { hp = hp }
    end

    refreshPlayerList = function()
        for _, row in pairs(S.rows) do
            row:Destroy()
        end
        S.rows = {}
        S.rowMeta = {}

        local query = string.lower(U.search.Text or "")
        local list_players = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                table.insert(list_players, p)
            end
        end
        table.sort(list_players, function(a, b)
            return string.lower(a.Name) < string.lower(b.Name)
        end)

        local y = 2
        for _, p in ipairs(list_players) do
            local match = query == "" or string.find(string.lower(p.Name), query, 1, true) ~=
                nil or string.find(string.lower(p.DisplayName), query, 1, true) ~= nil
            if match then
                buildPlayerRow(p, y)
                y = y + 30
            end
        end
    end
    ctx.adminRefreshPlayerList = refreshPlayerList

    -- Live HP readout on each row (called from the throttled loop).
    local function updateRows()
        for player, meta in pairs(S.rowMeta) do
            local hum = getHum(player.Character)
            if hum then
                local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                meta.hp.Text = string.format("%d%%", math.floor(ratio * 100))
                meta.hp.TextColor3 = healthColor(ratio)
            else
                meta.hp.Text = "--"
                meta.hp.TextColor3 = THEME.dim
            end
        end
    end

    -- ==================================================================
    -- HEALTH COLOUR HELPERS
    -- ==================================================================
    healthColor = function(ratio)
        if ratio >= HEALTH_HIGH then
            return HEALTH_COLORS.high
        elseif ratio >= HEALTH_LOW then
            return HEALTH_COLORS.mid
        end
        return HEALTH_COLORS.low
    end

    local function espColor(player, ratio)
        if ESP_CFG.ColorMode == "accent" then
            return THEME.accent
        elseif ESP_CFG.ColorMode == "static" then
            return ESP_CFG.StaticColor
        elseif ESP_CFG.ColorMode == "health" and player and isStaff(player) then
            -- Make staff pop in a distinct colour so you don't wander into them.
            return Color3.fromRGB(255, 60, 60)
        end
        return healthColor(ratio)
    end

    -- Name the GAME displays overhead. Roblox's standard overhead name is
    -- Humanoid.DisplayName (games often override it); other games use
    -- character attributes or their own BillboardGui tag. Falls back to the
    -- account DisplayName.
    local NAME_ATTRS = { "DisplayName", "Nickname", "NickName", "CustomName", "GameName", "OverheadName" }

    local function resolveInGameName(player)
        local char = player.Character
        if not char then
            return player.DisplayName
        end
        -- 1) Humanoid.DisplayName — the standard in-game overhead name.
        local hum = getHum(char)
        if hum then
            local d = hum.DisplayName
            if type(d) == "string" and d ~= "" then
                return d
            end
        end
        -- 2) Game-specific attributes.
        for _, attr in ipairs(NAME_ATTRS) do
            local v = char:GetAttribute(attr) or player:GetAttribute(attr)
            if type(v) == "string" and v ~= "" then
                return v
            end
        end
        -- 3) A BillboardGui tag above the head (scanned once per character).
        local cached = S.nameScan[player]
        if not (cached and cached.char == char) then
            local text
            local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            if head then
                for _, child in ipairs(head:GetChildren()) do
                    -- never pick up our own ESP tag
                    if child:IsA("BillboardGui") and child.Name ~= "AdminESP_Tag" then
                        local lbl = child:FindFirstChildOfClass("TextLabel")
                        if lbl and type(lbl.Text) == "string" and lbl.Text ~= "" then
                            text = lbl.Text
                            break
                        end
                    end
                end
            end
            cached = { char = char, text = text }
            S.nameScan[player] = cached
        end
        if cached.text then
            return cached.text
        end
        return player.DisplayName
    end

    -- ==================================================================
    -- FEATURE 1 — ESP  (overlay for the selected player, or everyone)
    -- ==================================================================
    local function destroyESP(player)
        local e = S.esp[player]
        if not e then
            return
        end
        S.esp[player] = nil
        S.nameScan[player] = nil
        if e.conn then
            e.conn:Disconnect()
        end
        if e.billboard then
            e.billboard:Destroy()
        end
        if e.box then
            e.box:Destroy()
        end
        if e.hl then
            e.hl:Destroy()
        end
    end

    local function buildESP(player)
        if player == lp or S.esp[player] then
            return
        end
        local char = player.Character
        local hrp = char and getHRP(char)
        if not hrp then
            return
        end

        local bb = Instance.new("BillboardGui")
        bb.Name = "AdminESP_Tag"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 170, 0, 20)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.Adornee = hrp
        bb.Parent = hrp

        -- DisplayName ONLY — no health bar, no studs/distance text.
        local name = makeLabel(bb, {
            Text = player.DisplayName,
            Size = UDim2.new(1, 0, 1, 0),
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        stroke(name, Color3.new(0, 0, 0), 1.5)

        local entry = { billboard = bb, name = name }

        -- Box / highlight outline styles
        if ESP_CFG.Outline == "box" or ESP_CFG.Outline == "both" then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "AdminESP_Box"
            box.Adornee = hrp
            box.Size = Vector3.new(2, 5, 1)
            box.SizeRelativeOffset = Vector3.new(0, 0.5, 0)
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Transparency = 0.45
            box.Color3 = THEME.accent
            box.Parent = hrp
            entry.box = box
        end
        if ESP_CFG.Outline == "highlight" or ESP_CFG.Outline == "both" then
            local hl = Instance.new("Highlight")
            hl.Name = "AdminESP_HL"
            hl.FillTransparency = 0.7
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
            entry.hl = hl
        end

        S.esp[player] = entry

        -- Rebuild after a respawn (destroy then re-create once the HRP exists).
        entry.conn = player.CharacterAdded:Connect(function()
            destroyESP(player)
            task.defer(function()
                local tries = 0
                while tries < 30 and S.espOn and player.Parent and
                    (not player.Character or not getHRP(player.Character)) do
                    task.wait(0.1)
                    tries = tries + 1
                end
                if S.espOn and player.Parent then
                    buildESP(player)
                end
            end)
        end)
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    -- Refresh the overlay for ONE player (create / update / destroy as needed).
    local function updateESPFor(player, myHRP)
        local char = player.Character
        local hrp = char and getHRP(char)
        if not hrp then
            destroyESP(player)
            return
        end
        if not S.esp[player] then
            buildESP(player)
        end
        local e = S.esp[player]
        if not e then
            return
        end
        local hum = getHum(char)
        local hp, maxHp = 100, 100
        if hum then
            hp = hum.Health
            maxHp = math.max(hum.MaxHealth, 1)
        end
        local ratio = math.clamp(hp / maxHp, 0, 1)
        local dist = myHRP and (myHRP.Position - hrp.Position).Magnitude or 0
        local col = espColor(player, ratio)

        -- Tag text = in-game name (DisplayName fallback); colour tracks health.
        local label = player.DisplayName
        if ESP_CFG.UseInGameName then
            label = resolveInGameName(player)
        end
        e.name.Text = ESP_CFG.ShowName and label or ""
        e.name.TextColor3 = col
        if e.box then
            e.box.Color3 = col
        end
        if e.hl then
            e.hl.FillColor = col
            e.hl.OutlineColor = col
        end

        -- Distance culling + optional line-of-sight raycast.
        local visible = dist <= ESP_CFG.MaxDistance
        if visible and ESP_CFG.RequireLineOfSight and myHRP then
            rayParams.FilterDescendantsInstances = { lp.Character, char }
            local hit = workspace:Raycast(myHRP.Position, hrp.Position - myHRP.Position, rayParams)
            visible = (hit == nil)
        end
        e.billboard.Enabled = visible
        if e.box then
            e.box.Visible = visible
        end
        if e.hl then
            e.hl.Enabled = visible
        end
    end

    updateESP = function()
        local myHRP = getHRP(lp.Character)
        -- Drop entries for players who left the server.
        for player in pairs(S.esp) do
            if not player.Parent then
                destroyESP(player)
            end
        end

        if ESP_CFG.Scope == "target" then
            -- Overlay ONLY the selected player; clear everyone else.
            local target = S.target
            for player in pairs(S.esp) do
                if player ~= target then
                    destroyESP(player)
                end
            end
            if target and target.Parent and target ~= lp then
                updateESPFor(target, myHRP)
            end
            return
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lp then
                updateESPFor(player, myHRP)
            end
        end
    end

    local function setESP(on)
        S.espOn = on and true or false
        if not S.espOn then
            for player in pairs(S.esp) do
                destroyESP(player)
            end
        else
            if ESP_CFG.Scope == "target" and not S.target then
                log("ESP: scope is Target only — click a name on the left first", THEME.warn)
            end
            updateESP()
        end
        if U.espSet then
            U.espSet(S.espOn, false)
        end
        refreshToolbar()
    end

    -- ==================================================================
    -- FEATURE 2 — BEAM  (from local player to the target)
    -- ==================================================================
    stopBeam = function()
        local b = S.beam
        if not b then
            return
        end
        S.beam = nil
        if b.beam then
            b.beam:Destroy()
        end
        if b.a0 then
            b.a0:Destroy()
        end
        if b.a1 then
            b.a1:Destroy()
        end
    end

    startBeam = function(target)
        stopBeam()
        S.beam = { target = target, t = 0 }
    end

    local function updateBeam(step)
        local b = S.beam
        if not b then
            return
        end
        local target = b.target
        if not target or not target.Parent then
            stopBeam()
            S.beamOn = false
            syncToggles()
            refreshToolbar()
            return
        end
        local myHRP = getHRP(lp.Character)
        local tHRP = getHRP(target.Character)
        if not myHRP or not tHRP then
            if b.beam then
                b.beam.Enabled = false
            end
            return
        end

        b.t = b.t + step
        -- Re-home attachments when either character respawns.
        if b.a0 and b.a0.Parent ~= myHRP then
            b.a0:Destroy()
            b.a0 = nil
        end
        if b.a1 and b.a1.Parent ~= tHRP then
            b.a1:Destroy()
            b.a1 = nil
        end
        if not b.a0 then
            b.a0 = Instance.new("Attachment", myHRP)
        end
        if not b.a1 then
            b.a1 = Instance.new("Attachment", tHRP)
        end
        if not b.beam or not b.beam.Parent then
            local beam = Instance.new("Beam")
            beam.Name = "AdminMenu_Beam"
            beam.Attachment0 = b.a0
            beam.Attachment1 = b.a1
            beam.FaceCamera = true
            beam.Parent = workspace
            b.beam = beam
        end

        local beam = b.beam
        beam.Enabled = true
        beam.FaceCamera = true
        beam.Transparency = NumberSequence.new(BEAM_CFG.Transparency)

        if BEAM_CFG.Style == "pulse" then
            local w = math.max(0.02, BEAM_CFG.Thickness * (1 + 0.6 * math.sin(b.t * 6)))
            beam.Width0 = w
            beam.Width1 = w
            beam.Color = ColorSequence.new(BEAM_CFG.Color)
        elseif BEAM_CFG.Style == "rainbow" then
            beam.Color = ColorSequence.new(Color3.fromHSV((b.t * 0.25) % 1, 1, 1))
            beam.Width0 = BEAM_CFG.Thickness
            beam.Width1 = BEAM_CFG.Thickness
        else
            beam.Color = ColorSequence.new(BEAM_CFG.Color)
            beam.Width0 = BEAM_CFG.Thickness
            beam.Width1 = BEAM_CFG.Thickness
        end
    end

    -- Programmatic beam toggle (the BEAM panel and ctx.adminMenu use this).
    setBeam = function(on)
        if on and not S.target then
            log("Beam: select a target first", THEME.warn)
            if U.beamSet then
                U.beamSet(false, false)
            end
            return false
        end
        S.beamOn = on and true or false
        if S.beamOn then
            startBeam(S.target)
            log("Beam: ON → " .. S.target.Name, THEME.success)
        else
            stopBeam()
            log("Beam: OFF", THEME.dim)
        end
        if U.beamSet then
            U.beamSet(S.beamOn, false)
        end
        refreshToolbar()
        return true
    end

    -- ==================================================================
    -- FEATURE 3 — VIEW  (scriptable camera)
    -- ==================================================================
    local function stopView()
        local v = S.view
        if not v then
            return
        end
        S.view = nil
        pcall(function()
            cam.CameraType = v.savedType or Enum.CameraType.Custom
            cam.CameraSubject = v.savedSubject or getHum(lp.Character) or lp.Character
        end)
    end

    local function startView(target)
        stopView()
        S.view = {
            target = target,
            angle = 0,
            savedType = cam.CameraType,
            savedSubject = cam.CameraSubject,
        }
        cam.CameraType = Enum.CameraType.Scriptable
    end

    local function updateView(dt)
        local v = S.view
        if not v then
            return
        end
        local target = v.target
        if not target or not target.Parent then
            stopView()
            S.viewOn = false
            syncToggles()
            refreshToolbar()
            return
        end
        local char = target.Character
        local tHRP = char and getHRP(char)
        if not tHRP then
            return
        end

        local tPos = tHRP.Position
        local desired
        if VIEW_CFG.Mode == "firstperson" then
            local head = char:FindFirstChild("Head")
            desired = head and (head.CFrame * CFrame.new(0, 0.2, -0.4)) or (tHRP.CFrame * CFrame.new(0, 0.5, 0))
        elseif VIEW_CFG.Mode == "orbit" then
            v.angle = v.angle + math.rad(VIEW_CFG.OrbitSpeed) * dt
            local offset = Vector3.new(
                math.cos(v.angle) * VIEW_CFG.OrbitRadius,
                VIEW_CFG.Height,
                math.sin(v.angle) * VIEW_CFG.OrbitRadius
            )
            desired = CFrame.lookAt(tPos + offset, tPos + Vector3.new(0, 1, 0))
        else
            local behind = tHRP.CFrame * CFrame.new(0, VIEW_CFG.Height, VIEW_CFG.Distance)
            desired = CFrame.lookAt(behind.Position, tPos + Vector3.new(0, 1, 0))
        end

        -- Frame-rate independent exponential smoothing.
        local alpha = 1 - math.exp(-VIEW_CFG.Smoothness * dt)
        cam.CFrame = cam.CFrame:Lerp(desired, alpha)
    end

    -- Programmatic view toggle (the VIEW panel and ctx.adminMenu use this).
    setView = function(on)
        if on and not S.target then
            log("View: select a target first", THEME.warn)
            if U.viewSet then
                U.viewSet(false, false)
            end
            return false
        end
        S.viewOn = on and true or false
        if S.viewOn then
            startView(S.target)
            log("View: ON (" .. VIEW_CFG.Mode .. ") → " .. S.target.Name, THEME.success)
        else
            stopView()
            log("View: OFF", THEME.dim)
        end
        if U.viewSet then
            U.viewSet(S.viewOn, false)
        end
        refreshToolbar()
        return true
    end

    -- Clicking a player's name toggles ESP + Beam for them: the row IS the
    -- switch (click = on, click again = off), no checkbox needed.
    toggleTargetVisuals = function(player)
        if not player or player == lp then
            return false
        end
        if S.target == player and (S.espOn or S.beamOn) then
            -- setESP / setBeam keep the panel checkboxes in sync themselves.
            setESP(false)
            setBeam(false)
            log("ESP + Beam OFF for " .. player.DisplayName, THEME.dim)
            return false
        end
        selectTarget(player)
        setESP(true)
        setBeam(true)
        log("ESP + Beam ON for " .. player.DisplayName, THEME.success)
        return true
    end

    -- ==================================================================
    -- FEATURE 4 — TP  (guarded teleport + condition submenu)
    -- ==================================================================
    -- Each guard entry: key, label shown in the menu, default state.
    local CONDITIONS = {
        { key = "RequireConfirm", label = "Require confirm click" },
        { key = "Cooldown", label = "Cooldown between TPs" },
        { key = "BlockTargetDead", label = "Block if target is dead" },
        { key = "BlockSelfDead", label = "Block if you are dead" },
        { key = "BlockStaff", label = "Block if target is staff" },
        { key = "BlockSafeZone", label = "Block if in a safe zone" },
        { key = "BlockInCombat", label = "Block if you are in combat" },
    }

    -- Evaluate every guard against the target. Returns:
    --   allowed (bool), reason (string|nil), checks (key -> {enabled, ok, note})
    local function evalTP(target)
        local now = tick()
        local myHum = getHum(lp.Character)
        local tChar = target and target.Character
        local tHum = tChar and getHum(tChar)

        local checks = {}
        local function add(key, enabled, ok, note)
            checks[key] = { enabled = enabled, ok = ok, note = note }
        end
        add("RequireConfirm", TP.RequireConfirm, true, "click again to confirm")
        add("Cooldown", TP.Cooldown > 0, (now - S.lastTP) >= TP.Cooldown,
            string.format("wait %.1fs", math.max(0, TP.Cooldown - (now - S.lastTP))))
        add("BlockTargetDead", TP.BlockTargetDead, (tHum ~= nil and tHum.Health > 0), "target is dead")
        add("BlockSelfDead", TP.BlockSelfDead, (myHum ~= nil and myHum.Health > 0), "you are dead")
        add("BlockStaff", TP.BlockStaff, not (target and isStaff(target)), "target is staff")
        add("BlockSafeZone", TP.BlockSafeZone, not (target and inSafeZone(target)), "target in safe zone")
        add("BlockInCombat", TP.BlockInCombat, (now - lastCombat) > COMBAT_MEMORY, "you are in combat")

        if not target or not target.Parent then
            return false, "No target selected", checks
        end
        if not tChar or not getHRP(tChar) then
            return false, "Target has no character", checks
        end
        for _, key in ipairs({ "BlockTargetDead", "BlockSelfDead", "BlockStaff", "BlockSafeZone", "BlockInCombat" }) do
            local c = checks[key]
            if c.enabled and not c.ok then
                return false, c.note or key, checks
            end
        end
        if checks.Cooldown.enabled and not checks.Cooldown.ok then
            return false, checks.Cooldown.note or "cooldown", checks
        end
        return true, nil, checks
    end

    local function teleportTo(target)
        local allowed, reason = evalTP(target)
        local now = tick()

        -- Confirmation step: first click arms, second click (within window) fires.
        local armed = S.confirmArmed and now <= S.confirmUntil
        if allowed and TP.RequireConfirm and not armed then
            S.confirmArmed = true
            S.confirmUntil = now + TP.ConfirmWindow
            log("TP: click again within " .. string.format("%.1f", TP.ConfirmWindow) .. "s to teleport to " .. target.Name,
                THEME.warn)
            return false
        end

        if not allowed then
            log("TP blocked: " .. tostring(reason), THEME.danger)
            return false
        end

        local tHRP = getHRP(target.Character)
        local myHRP = getHRP(lp.Character)
        if not tHRP or not myHRP then
            log("TP blocked: missing character", THEME.danger)
            return false
        end

        -- Offset slightly behind/above so you do not clip into the target.
        myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 1.5, 3)
        S.lastTP = now
        S.confirmUntil = 0
        S.confirmArmed = false
        log("TP: teleported to " .. target.Name, THEME.success)
        return true
    end

    -- Make the guarded teleport reachable from outside the module if wanted.
    ctx.tpToPlayerGuarded = function(target)
        return teleportTo(target or S.target)
    end

    -- ==================================================================
    -- PANEL BUILDING
    -- ==================================================================
    -- ---- ESP panel --------------------------------------------------------
    do
        local p = makeSubPanel("ESP")
        local y = 6
        U.espToggle = toggleRow(p, y, "Enable ESP", false, function(state)
            setESP(state)
            log("ESP: " .. (state and "ON" or "OFF"), state and THEME.success or THEME.dim)
        end)
        U.espSet = U.espToggle
        y = y + 30
        segRow(p, y, "ESP scope", {
            { label = "Target only", value = "target" },
            { label = "All players", value = "all" },
        }, ESP_CFG.Scope, function(v)
            ESP_CFG.Scope = v
            if S.espOn then
                for player in pairs(S.esp) do
                    destroyESP(player)
                end
                updateESP()
            end
            log("ESP scope: " .. (v == "target" and "selected player only" or "all players"), THEME.dim)
        end)
        y = y + 46
        toggleRow(p, y, "Show name tag", ESP_CFG.ShowName, function(v) ESP_CFG.ShowName = v end)
        y = y + 28
        toggleRow(p, y, "Use in-game name tag", ESP_CFG.UseInGameName, function(v)
            ESP_CFG.UseInGameName = v
        end)
        y = y + 28
        toggleRow(p, y, "Line of sight only (raycast)", ESP_CFG.RequireLineOfSight, function(v)
            ESP_CFG.RequireLineOfSight = v
        end)
        y = y + 32
        segRow(p, y, "Outline style", {
            { label = "Box", value = "box" },
            { label = "Highlight", value = "highlight" },
            { label = "Both", value = "both" },
            { label = "None", value = "none" },
        }, ESP_CFG.Outline, function(v)
            ESP_CFG.Outline = v
            if S.espOn then
                for player in pairs(S.esp) do
                    destroyESP(player)
                end
                updateESP()
            end
        end)
        y = y + 46
        segRow(p, y, "Colour mode", {
            { label = "Health", value = "health" },
            { label = "Accent", value = "accent" },
            { label = "Custom", value = "static" },
        }, ESP_CFG.ColorMode, function(v) ESP_CFG.ColorMode = v end)
        y = y + 46
        swatchRow(p, y, "Custom colour", ESP_CFG.StaticColor, function(col)
            ESP_CFG.StaticColor = col
            ESP_CFG.ColorMode = "static"
        end)
        y = y + 44
        sliderRow(p, y, "Max distance", 100, 5000, ESP_CFG.MaxDistance, "%.0f", function(v)
            ESP_CFG.MaxDistance = v
        end)
        y = y + 40
        makeLabel(p, {
            Text = "Tag shows the DisplayName ONLY (no health / studs) — the colour\n"
                .. "still tracks health. Click a name on the left to toggle ESP +\n"
                .. "Beam for that player; click again to turn them off.\n"
                .. "Staff get a red outline. Raycast hides wall-hidden tags.",
            Size = UDim2.new(1, -8, 0, 40),
            Position = UDim2.new(0, 4, 0, y),
            TextSize = 9,
            TextColor3 = THEME.dim,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
    end

    -- ---- BEAM panel -------------------------------------------------------
    do
        local p = makeSubPanel("BEAM")
        local y = 6
        U.beamToggle = toggleRow(p, y, "Enable beam to target", false, function(state)
            setBeam(state)
        end)
        U.beamSet = U.beamToggle
        y = y + 32
        swatchRow(p, y, "Beam colour", BEAM_CFG.Color, function(col)
            BEAM_CFG.Color = col
        end)
        y = y + 44
        sliderRow(p, y, "Thickness", 0.02, 1, BEAM_CFG.Thickness, "%.2f", function(v)
            BEAM_CFG.Thickness = v
        end)
        y = y + 40
        sliderRow(p, y, "Transparency", 0, 0.9, BEAM_CFG.Transparency, "%.2f", function(v)
            BEAM_CFG.Transparency = v
        end)
        y = y + 40
        segRow(p, y, "Beam style", {
            { label = "Solid", value = "solid" },
            { label = "Pulse", value = "pulse" },
            { label = "Rainbow", value = "rainbow" },
        }, BEAM_CFG.Style, function(v) BEAM_CFG.Style = v end)
        y = y + 50
        makeLabel(p, {
            Text = "Beam draws from your character to the selected target and follows\n"
                .. "respawns. Pick a target on the left first.",
            Size = UDim2.new(1, -8, 0, 34),
            Position = UDim2.new(0, 4, 0, y),
            TextSize = 9,
            TextColor3 = THEME.dim,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
    end

    -- ---- VIEW panel -------------------------------------------------------
    do
        local p = makeSubPanel("VIEW")
        local y = 6
        U.viewToggle = toggleRow(p, y, "Enable camera view", false, function(state)
            setView(state)
        end)
        U.viewSet = U.viewToggle
        y = y + 32
        segRow(p, y, "Camera mode", {
            { label = "Follow", value = "follow" },
            { label = "First-person", value = "firstperson" },
            { label = "Orbit", value = "orbit" },
        }, VIEW_CFG.Mode, function(v)
            VIEW_CFG.Mode = v
            if S.viewOn and S.view then
                S.view.angle = 0
            end
            log("View mode: " .. v, THEME.dim)
        end)
        y = y + 46
        sliderRow(p, y, "Smoothness", 1, 20, VIEW_CFG.Smoothness, "%.1f", function(v) VIEW_CFG.Smoothness = v end)
        y = y + 40
        sliderRow(p, y, "Follow distance", 4, 40, VIEW_CFG.Distance, "%.0f", function(v) VIEW_CFG.Distance = v end)
        y = y + 40
        sliderRow(p, y, "Height", -5, 15, VIEW_CFG.Height, "%.0f", function(v) VIEW_CFG.Height = v end)
        y = y + 40
        sliderRow(p, y, "Orbit speed", 0, 120, VIEW_CFG.OrbitSpeed, "%.0f°/s", function(v) VIEW_CFG.OrbitSpeed = v end)
        y = y + 40
        sliderRow(p, y, "Orbit radius", 4, 40, VIEW_CFG.OrbitRadius, "%.0f", function(v) VIEW_CFG.OrbitRadius = v end)
        y = y + 44
        makeLabel(p, {
            Text = "Camera is scriptable while active and restored on disable.\n"
                .. "Lower smoothness = lazier, smoother follow.",
            Size = UDim2.new(1, -8, 0, 34),
            Position = UDim2.new(0, 4, 0, y),
            TextSize = 9,
            TextColor3 = THEME.dim,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
    end

    -- ---- TP panel (conditional submenu) -----------------------------------
    do
        local p = makeSubPanel("TP")
        local y = 6

        local tpNow = makeButton(p, {
            Text = "⚡ TELEPORT TO TARGET",
            Size = UDim2.new(1, -8, 0, 30),
            Position = UDim2.new(0, 4, 0, y),
            BackgroundColor3 = THEME.tp or THEME.accent,
        })
        bind(tpNow.MouseButton1Click, function()
            if not S.target then
                log("TP: select a target first", THEME.warn)
                return
            end
            teleportTo(S.target)
        end)
        y = y + 36

        U.tpStatusLbl = makeLabel(p, {
            Text = "TP: no target",
            Size = UDim2.new(1, -8, 0, 16),
            Position = UDim2.new(0, 4, 0, y),
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            TextColor3 = THEME.dim,
        })
        y = y + 20

        makeLabel(p, {
            Text = "DISABLE CONDITIONS (all default ON to prevent misclicks)",
            Size = UDim2.new(1, -8, 0, 14),
            Position = UDim2.new(0, 4, 0, y),
            TextSize = 9,
            Font = Enum.Font.GothamBold,
            TextColor3 = THEME.dim,
        })
        y = y + 18

        -- Each condition: checkbox (enabled) + live status text.
        for _, def in ipairs(CONDITIONS) do
            local row = makeButton(p, {
                Text = "",
                Size = UDim2.new(1, -8, 0, 26),
                Position = UDim2.new(0, 4, 0, y),
                BackgroundTransparency = 0.5,
            })
            local box = Instance.new("Frame")
            box.Size = UDim2.new(0, 14, 0, 14)
            box.Position = UDim2.new(0, 6, 0.5, -7)
            box.BackgroundColor3 = THEME.panel
            box.BorderSizePixel = 0
            box.Parent = row
            corner(box, 4)
            local boxStroke = stroke(box, THEME.dim, 1)
            local tick = makeLabel(box, { Text = "", Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })

            makeLabel(row, {
                Text = def.label,
                Position = UDim2.new(0, 28, 0, 0),
                Size = UDim2.new(1, -104, 1, 0),
                TextSize = 9,
            })
            local status = makeLabel(row, {
                Text = "",
                Position = UDim2.new(1, -72, 0, 0),
                Size = UDim2.new(0, 66, 1, 0),
                TextSize = 9,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
            })

            local function refreshBox()
                if TP[def.key] then
                    box.BackgroundColor3 = THEME.success
                    boxStroke.Color = THEME.success
                    tick.Text = "✓"
                    tick.TextColor3 = Color3.new(1, 1, 1)
                else
                    box.BackgroundColor3 = THEME.panel
                    boxStroke.Color = THEME.dim
                    tick.Text = ""
                end
            end
            refreshBox()
            bind(row.MouseButton1Click, function()
                TP[def.key] = not TP[def.key]
                refreshBox()
            end)

            U.condRows[def.key] = {
                setStatus = function(text, color)
                    status.Text = text
                    status.TextColor3 = color
                end,
            }
            y = y + 28
        end

        y = y + 4
        makeLabel(p, {
            Text = "Guards on = the teleport simply refuses and tells you why.\n"
                .. "Staff detection also trusts an AdminTag in the character.",
            Size = UDim2.new(1, -8, 0, 34),
            Position = UDim2.new(0, 4, 0, y),
            TextSize = 9,
            TextColor3 = THEME.dim,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
    end

    -- ==================================================================
    -- TOOLBAR / PANEL SYNC + LIVE STATUS
    -- ==================================================================
    refreshToolbar = function()
        for name, btn in pairs(U.featureBtns) do
            local on = (name == "ESP" and S.espOn) or (name == "BEAM" and S.beamOn) or (name == "VIEW" and S.viewOn)
            local selected = (S.selectedFeature == name)
            btn.BackgroundColor3 = on and THEME.success or (selected and THEME.accent or THEME.panel2)
            btn.TextColor3 = (on or selected) and Color3.new(1, 1, 1) or THEME.dim
            if name == "TP" and selected then
                btn.BackgroundColor3 = THEME.tp or THEME.accent
                btn.TextColor3 = Color3.new(1, 1, 1)
            end
        end
        for name, panel in pairs(U.panels) do
            panel.Visible = (name == S.selectedFeature)
        end
    end
    ctx.adminRefreshToolbar = refreshToolbar

    -- Keep the panel toggles visually in sync when a feature auto-disables.
    syncToggles = function()
        if U.espSet then
            U.espSet(S.espOn, false)
        end
        if U.beamSet then
            U.beamSet(S.beamOn, false)
        end
        if U.viewSet then
            U.viewSet(S.viewOn, false)
        end
    end

    local function selectFeature(name)
        S.selectedFeature = name
        refreshToolbar()
    end

    for name, btn in pairs(U.featureBtns) do
        bind(btn.MouseButton1Click, function()
            selectFeature(name)
        end)
    end

    -- Live TP condition status.
    local function updateTPStatus()
        local allowed, reason, checks = evalTP(S.target)
        for key, rowUI in pairs(U.condRows) do
            local c = checks[key]
            if not c then
                rowUI.setStatus("", THEME.dim)
            elseif not c.enabled then
                rowUI.setStatus("OFF", THEME.faint or THEME.dim)
            elseif key == "RequireConfirm" then
                if S.confirmArmed and tick() <= S.confirmUntil then
                    rowUI.setStatus("ARMED", THEME.warn)
                else
                    rowUI.setStatus("OK", THEME.success)
                end
            elseif c.ok then
                rowUI.setStatus("OK", THEME.success)
            else
                rowUI.setStatus("BLOCKED", THEME.danger)
            end
        end

        if not S.target or not S.target.Parent then
            U.tpStatusLbl.Text = "TP: no target (pick one on the left)"
            U.tpStatusLbl.TextColor3 = THEME.dim
        elseif allowed then
            U.tpStatusLbl.Text = "TP: READY → " .. S.target.Name
            U.tpStatusLbl.TextColor3 = THEME.success
        else
            U.tpStatusLbl.Text = "TP: BLOCKED — " .. tostring(reason)
            U.tpStatusLbl.TextColor3 = THEME.danger
        end
    end

    -- ==================================================================
    -- MAIN LOOP (single throttled RenderStepped)
    -- ==================================================================
    local espAcc, beamAcc, rowAcc, tpAcc = 0, 0, 0, 0
    bind(RunService.RenderStepped, function(dt)
        if ctx.destroyed then
            return
        end

        if S.espOn then
            espAcc = espAcc + dt
            if espAcc >= ESP_CFG.Interval then
                espAcc = 0
                updateESP()
            end
        end
        -- Watchdog: beam state and instances must stay in sync, otherwise a
        -- re-point / respawn can leave an orphaned Beam rendering forever.
        if S.beamOn then
            if not S.target or not S.target.Parent then
                setBeam(false)
            elseif not S.beam then
                startBeam(S.target)
            end
        elseif S.beam then
            stopBeam()
        end
        if S.beamOn then
            beamAcc = beamAcc + dt
            if beamAcc >= BEAM_CFG.Interval then
                updateBeam(beamAcc)
                beamAcc = 0
            end
        end
        if S.viewOn then
            updateView(dt)
        end

        rowAcc = rowAcc + dt
        if rowAcc >= 0.4 then
            rowAcc = 0
            updateRows()
        end
        tpAcc = tpAcc + dt
        if tpAcc >= 0.15 then
            tpAcc = 0
            updateTPStatus()
        end
    end)

    -- ==================================================================
    -- PLAYER LIFECYCLE
    -- ==================================================================
    bind(Players.PlayerAdded, function()
        refreshPlayerList()
    end)
    bind(Players.PlayerRemoving, function(player)
        destroyESP(player)
        if S.target == player then
            S.target = nil
            if S.beamOn then
                stopBeam()
                S.beamOn = false
            end
            if S.viewOn then
                stopView()
                S.viewOn = false
            end
            syncToggles()
            refreshToolbar()
            log("AdminMenu: target left — features disabled", THEME.warn)
        end
        refreshPlayerList()
    end)
    bind(U.search:GetPropertyChangedSignal("Text"), function()
        refreshPlayerList()
    end)

    -- Optional keybind: config.Keys.ESP toggles the ESP overlay (current scope).
    if config and config.Keys and config.Keys.ESP then
        bind(UserInputService.InputBegan, function(input, gpe)
            if gpe or ctx.destroyed then
                return
            end
            if input.KeyCode == config.Keys.ESP then
                setESP(not S.espOn)
            end
        end)
    end

    -- ==================================================================
    -- CLEANUP (registered for the global unload path in core.destroyAll)
    -- ==================================================================
    local function cleanup()
        S.espOn, S.beamOn, S.viewOn = false, false, false
        for player in pairs(S.esp) do
            pcall(function()
                destroyESP(player)
            end)
        end
        pcall(stopBeam)
        pcall(stopView)
        activeSlider = nil
        -- Safety sweep: nothing ESP / beam related may survive an unload, even
        -- if the internal state table got out of sync (orphaned instances).
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name == "AdminMenu_Beam" or obj.Name == "AdminESP_Box"
                    or obj.Name == "AdminESP_Tag" or obj.Name == "AdminESP_HL" then
                    obj:Destroy()
                end
            end
        end)
    end
    ctx.adminMenuCleanup = cleanup

    -- Public API so any module or keybind can drive the menu without the UI.
    ctx.adminMenu = {
        setESP = setESP,
        setBeam = setBeam,
        setView = setView,
        teleport = function(target)
            return teleportTo(target or S.target)
        end,
        selectTarget = selectTarget,
        -- Clicking a name toggles ESP + Beam; this is the same switch.
        toggleTarget = function(player)
            return toggleTargetVisuals(player or S.target)
        end,
        setESPScope = function(v)
            ESP_CFG.Scope = (v == "all") and "all" or "target"
            if S.espOn then
                for player in pairs(S.esp) do
                    destroyESP(player)
                end
                updateESP()
            end
            return ESP_CFG.Scope
        end,
        getState = function()
            local n = 0
            for _ in pairs(S.esp) do
                n = n + 1
            end
            return {
                target = S.target,
                espOn = S.espOn,
                beamOn = S.beamOn,
                viewOn = S.viewOn,
                espCount = n,
                espScope = ESP_CFG.Scope,
            }
        end,
        cleanup = cleanup,
    }

    -- ==================================================================
    -- INITIAL RENDER
    -- ==================================================================
    refreshPlayerList()
    refreshToolbar()
    updateTPStatus()
    log("AdminMenu ready — ESP / BEAM / VIEW / TP", THEME.accentGlow or THEME.accent)
end
