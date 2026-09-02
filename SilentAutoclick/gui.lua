-- SilentAutoclick/gui.lua
-- GUI built with the LyraHub UI kit — horizontal tab bar layout
-- (top bar → horizontal tabs → content area). Keeps the same external contract
-- the core/modules use (StatusLbl, ToggleBtn, Stats.*, MiniStats.*, ...) so
-- the engine layer stays untouched.

return function(config, components)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    local shared = components.shared
    local THEME = config.Theme
    local W, H = config.Window.Size.X, config.Window.Size.Y -- 620, 420

    -- Kill any previous instance
    if _G.__SilentAutoclick_Destroy then
        pcall(_G.__SilentAutoclick_Destroy)
    end
    _G.__SilentAutoclick_Destroy = nil

    local view = {}

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SilentAutoclick_GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then ScreenGui.Parent = lp:WaitForChild("PlayerGui") end
    view.ScreenGui = ScreenGui

    local function label(opts)
        local l = Instance.new("TextLabel")
        l.Size = opts.Size or UDim2.new(0, 200, 0, 20)
        l.Position = opts.Position or UDim2.new(0, 0, 0, 0)
        l.AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0)
        l.BackgroundTransparency = 1
        l.Text = opts.Text or ""
        l.TextColor3 = opts.Color or THEME.text
        l.Font = opts.Font or Enum.Font.Gotham
        l.TextSize = opts.TextSize or 12
        l.TextXAlignment = opts.TextXAlignment or Enum.TextXAlignment.Left
        l.TextYAlignment = opts.TextYAlignment or Enum.TextYAlignment.Center
        l.ZIndex = opts.ZIndex or 1
        if opts.Visible ~= nil then l.Visible = opts.Visible end
        if opts.LayoutOrder then l.LayoutOrder = opts.LayoutOrder end
        l.Parent = opts.Parent
        return l
    end

    -- ═══════════════════════════════════════════
    -- MAIN WINDOW
    -- ═══════════════════════════════════════════
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.fromOffset(W, H)
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.BackgroundColor3 = THEME.bg
    Main.BorderSizePixel = 0
    Main.ZIndex = 2
    Main.ClipsDescendants = true
    Main.Parent = ScreenGui
    shared.corner(Main, UDim.new(0, 10))
    shared.stroke(Main, THEME.divider, 1, 0.45)
    shared.glow(Main, THEME.glow or THEME.accent, 4, 0.92)
    shared.gradient(Main, THEME.bg, THEME.bg2, 90)
    view.Main = Main

    -- Drop shadow (ui.lua references view.Shadow)
    local Shadow = shared.shadow(Main, { ExtendX = 10, ExtendY = 10, Transparency = 0.72, OffsetY = 0 })
    view.Shadow = Shadow

    -- ═══════════════════════════════════════════
    -- TOP BAR
    -- ═══════════════════════════════════════════
    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 36)
    TopBar.BackgroundTransparency = 1
    TopBar.ZIndex = 2
    TopBar.Parent = Main

    local logo = Instance.new("Frame")
    logo.Size = UDim2.fromOffset(8, 8)
    logo.Position = UDim2.fromOffset(14, 14)
    logo.BackgroundColor3 = THEME.accent
    logo.BorderSizePixel = 0
    logo.Parent = TopBar
    shared.corner(logo, UDim.new(1, 0))
    shared.glow(logo, THEME.glow or THEME.accent, 2, 0.55)

    local TopBarTitle = label({
        Parent = TopBar, Text = config.Window.Title, Position = UDim2.fromOffset(28, 8),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
        Color = THEME.accent2,
    })
    view.TopBarTitle = TopBarTitle
    label({
        Parent = TopBar, Text = string.upper(config.Window.Subtitle), Position = UDim2.fromOffset(28, 23),
        Size = UDim2.fromOffset(220, 10), TextSize = 7, Color = THEME.faint, Font = Enum.Font.GothamBold,
    })

    local minBtn = components.button({
        Parent = Main, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -68, 0, 6),
        Text = "—", TextSize = 12, Color = THEME.panel2, TextColor = THEME.text,
        HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 7), ZIndex = 3, Glow = false,
    })
    local closeBtn = components.button({
        Parent = Main, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -38, 0, 6),
        Text = "✕", TextSize = 11, Color = Color3.fromRGB(64, 28, 34), TextColor = THEME.danger,
        HoverColor = Color3.fromRGB(96, 38, 46), CornerRadius = UDim.new(0, 7), ZIndex = 3, Glow = false,
    })
    view.MinBtn = minBtn.Instance
    view.CloseBtn = closeBtn.Instance

    local DragHit = Instance.new("TextButton")
    DragHit.Size = UDim2.new(1, 0, 0, 36)
    DragHit.BackgroundTransparency = 1
    DragHit.Text = ""
    DragHit.AutoButtonColor = false
    DragHit.BorderSizePixel = 0
    DragHit.ZIndex = 2
    DragHit.Parent = Main
    view.DragHit = DragHit

    local topDivider = Instance.new("Frame")
    topDivider.Size = UDim2.new(1, 0, 0, 1)
    topDivider.Position = UDim2.fromOffset(0, 36)
    topDivider.BackgroundColor3 = THEME.divider
    topDivider.BorderSizePixel = 0
    topDivider.Parent = Main

    -- ═══════════════════════════════════════════
    -- HORIZONTAL TAB BAR
    -- ═══════════════════════════════════════════
    local TAB_BAR_H = 34
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, 0, 0, TAB_BAR_H)
    tabBar.Position = UDim2.new(0, 0, 0, 37)
    tabBar.BackgroundColor3 = THEME.sidebar
    tabBar.BorderSizePixel = 0
    tabBar.ZIndex = 2
    tabBar.Parent = Main

    local tabBarLayout = Instance.new("UIListLayout")
    tabBarLayout.FillDirection = Enum.FillDirection.Horizontal
    tabBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    tabBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabBarLayout.Padding = UDim.new(0, 4)
    tabBarLayout.Parent = tabBar

    local tabBarPadding = Instance.new("UIPadding")
    tabBarPadding.PaddingLeft = UDim.new(0, 10)
    tabBarPadding.PaddingRight = UDim.new(0, 10)
    tabBarPadding.PaddingTop = UDim.new(0, 0)
    tabBarPadding.PaddingBottom = UDim.new(0, 0)
    tabBarPadding.Parent = tabBar

    -- Tab buttons
    local tabButtons = {}
    local tabActive = {}
    local tabIndicators = {}

    local function makeTabBtn(name, icon)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 0, 0, 26)
        btn.AutomaticSize = Enum.AutomaticSize.X
        btn.BackgroundColor3 = THEME.panel2
        btn.Text = icon .. "  " .. name
        btn.TextColor3 = THEME.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.AutoButtonColor = false
        btn.TextXAlignment = Enum.TextXAlignment.Center
        btn.BorderSizePixel = 0
        btn.ZIndex = 3
        btn.Parent = tabBar
        shared.corner(btn, UDim.new(0, 7))
        shared.stroke(btn, THEME.divider, 1, 0.5)

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(1, -12, 0, 2)
        indicator.AnchorPoint = Vector2.new(0.5, 0)
        indicator.Position = UDim2.new(0.5, 0, 1, -4)
        indicator.BackgroundColor3 = THEME.accent
        indicator.BackgroundTransparency = 1
        indicator.BorderSizePixel = 0
        indicator.ZIndex = 4
        indicator.Parent = btn
        shared.corner(indicator, UDim.new(1, 0))

        btn.MouseEnter:Connect(function()
            if not tabActive[btn] then
                shared.tween(btn, { TextColor3 = THEME.text }, 0.12)
            end
        end)
        btn.MouseLeave:Connect(function()
            if not tabActive[btn] then
                shared.tween(btn, { TextColor3 = THEME.dim }, 0.18)
            end
        end)

        tabButtons[name] = btn
        tabActive[btn] = false
        tabIndicators[name] = indicator
        return btn, indicator
    end

    local tabClickingBtn   = makeTabBtn("Clicking",  "●")
    local tabTimingBtn     = makeTabBtn("Timing",    "◎")
    local tabStatsBtn      = makeTabBtn("Stats",     "▤")
    local tabSettingsBtn   = makeTabBtn("Settings",  "⚙")

    -- Tab bar bottom divider
    local tabDivider = Instance.new("Frame")
    tabDivider.Size = UDim2.new(1, 0, 0, 1)
    tabDivider.Position = UDim2.new(0, 0, 0, 37 + TAB_BAR_H)
    tabDivider.BackgroundColor3 = THEME.divider
    tabDivider.BorderSizePixel = 0
    tabDivider.Parent = Main

    -- ═══════════════════════════════════════════
    -- CONTENT AREA
    -- ═══════════════════════════════════════════
    local CONTENT_TOP = 37 + TAB_BAR_H + 1
    local CPAD = 14

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -(CPAD * 2), 1, -(CONTENT_TOP + CPAD))
    content.Position = UDim2.new(0, CPAD, 0, CONTENT_TOP)
    content.BackgroundColor3 = THEME.panel
    content.BackgroundTransparency = 0.35
    content.BorderSizePixel = 0
    content.ClipsDescendants = true
    content.Parent = Main
    shared.corner(content, UDim.new(0, 10))
    shared.stroke(content, THEME.divider, 1, 0.5)

    -- Tab frames (all same size, stacked on top of each other)
    local clickingTab = Instance.new("Frame")
    clickingTab.Name = "ClickingTab"
    clickingTab.Size = UDim2.new(1, 0, 1, 0)
    clickingTab.BackgroundTransparency = 1
    clickingTab.Parent = content

    local timingTab = Instance.new("Frame")
    timingTab.Name = "TimingTab"
    timingTab.Size = UDim2.new(1, 0, 1, 0)
    timingTab.BackgroundTransparency = 1
    timingTab.Visible = false
    timingTab.Parent = content

    local statsTab = Instance.new("Frame")
    statsTab.Name = "StatsTab"
    statsTab.Size = UDim2.new(1, 0, 1, 0)
    statsTab.BackgroundTransparency = 1
    statsTab.Visible = false
    statsTab.Parent = content

    local settingsTab = Instance.new("Frame")
    settingsTab.Name = "SettingsTab"
    settingsTab.Size = UDim2.new(1, 0, 1, 0)
    settingsTab.BackgroundTransparency = 1
    settingsTab.Visible = false
    settingsTab.Parent = content

    -- Tab switching
    local function applyTab(activeName)
        clickingTab.Visible  = (activeName == "Clicking")
        timingTab.Visible    = (activeName == "Timing")
        statsTab.Visible     = (activeName == "Stats")
        settingsTab.Visible  = (activeName == "Settings")

        local states = {
            Clicking = activeName == "Clicking",
            Timing   = activeName == "Timing",
            Stats    = activeName == "Stats",
            Settings = activeName == "Settings",
        }
        for name, btn in pairs(tabButtons) do
            local active = states[name]
            tabActive[btn] = active
            shared.tween(btn, {
                BackgroundColor3 = active and THEME.accent or THEME.panel2,
                BackgroundTransparency = active and 0.1 or 0,
                TextColor3 = active and THEME.text or THEME.dim,
            }, 0.14)
            shared.tween(tabIndicators[name], { BackgroundTransparency = active and 0 or 1 }, 0.14)
        end
    end

    local function setTab(name) applyTab(name) end

    tabClickingBtn.MouseButton1Click:Connect(function() setTab("Clicking") end)
    tabTimingBtn.MouseButton1Click:Connect(function() setTab("Timing") end)
    tabStatsBtn.MouseButton1Click:Connect(function() setTab("Stats") end)
    tabSettingsBtn.MouseButton1Click:Connect(function() setTab("Settings") end)

    setTab("Clicking")

    -- ═══════════════════════════════════════════
    -- CLICKING TAB
    -- ═══════════════════════════════════════════
    local StatusLbl = label({
        Parent = clickingTab, Text = "Status: OFF",
        Position = UDim2.fromOffset(CPAD, 10),
        Size = UDim2.new(1, -(CPAD * 2), 0, 18), TextSize = 14, Font = Enum.Font.GothamBold,
        Color = THEME.danger,
    })
    view.StatusLbl = StatusLbl

    local MethodLbl = label({
        Parent = clickingTab, Text = "Mode: -",
        Position = UDim2.fromOffset(CPAD, 30),
        Size = UDim2.new(1, -(CPAD * 2), 0, 12), TextSize = 9, Color = THEME.warn,
    })
    view.MethodLbl = MethodLbl

    label({
        Parent = clickingTab, Text = "CLICK MODE",
        Position = UDim2.fromOffset(CPAD, 52),
        Size = UDim2.new(1, -(CPAD * 2), 0, 10), TextSize = 8, Color = THEME.faint, Font = Enum.Font.GothamBold,
    })
    local ModeDropdown = components.dropdown({
        Parent = clickingTab,
        Size = UDim2.new(1, -(CPAD * 2), 0, 30),
        Position = UDim2.fromOffset(CPAD, 64),
        Items = { "Follow Cursor", "Fixed Position" }, Default = "Follow Cursor", ItemHeight = 30,
    })
    view.ModeDropdown = ModeDropdown

    local PosLbl = label({
        Parent = clickingTab, Text = "Target: Not set (press P to pick)",
        Position = UDim2.fromOffset(CPAD, 100),
        Size = UDim2.new(1, -(CPAD * 2), 0, 12), TextSize = 9, Color = THEME.dim, Visible = false,
    })
    view.PosLbl = PosLbl

    -- Toggle button + keybind (side by side at bottom)
    local ToggleBtn = components.button({
        Parent = clickingTab,
        Size = UDim2.new(1, -(CPAD * 2) - 130, 0, 36),
        Position = UDim2.new(0, CPAD, 1, -(CPAD + 36)),
        Text = "Start [F]", TextSize = 12, Color = THEME.accent, HoverColor = THEME.accent2, Glow = false,
    })
    view.ToggleBtn = ToggleBtn

    local KeybindBtn = components.keybind({
        Parent = clickingTab,
        Size = UDim2.fromOffset(120, 36),
        Position = UDim2.new(1, -(CPAD + 120), 1, -(CPAD + 36)),
        Default = config.Keys.ToggleClicker,
    })
    view.KeybindBtn = KeybindBtn

    -- ═══════════════════════════════════════════
    -- TIMING TAB
    -- ═══════════════════════════════════════════
    local TimingPanel = Instance.new("Frame")
    TimingPanel.Size = UDim2.new(1, -(CPAD * 2), 0, 130)
    TimingPanel.Position = UDim2.fromOffset(CPAD, 10)
    TimingPanel.BackgroundColor3 = THEME.panel
    TimingPanel.BackgroundTransparency = 0.4
    TimingPanel.BorderSizePixel = 0
    TimingPanel.Parent = timingTab
    shared.corner(TimingPanel, UDim.new(0, 8))
    shared.stroke(TimingPanel, THEME.divider, 1, 0.5)

    label({
        Parent = TimingPanel, Text = "CLICK TIMING",
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 10), TextSize = 8, Color = THEME.faint, Font = Enum.Font.GothamBold,
    })

    local IntervalLbl = label({
        Parent = TimingPanel, Text = "Delay: 1.00s / click",
        Position = UDim2.fromOffset(12, 22),
        Size = UDim2.new(1, -24, 0, 16), TextSize = 13, Font = Enum.Font.GothamBold, Color = THEME.accent2,
    })
    view.IntervalLbl = IntervalLbl

    local TimingInput = components.textinput({
        Parent = TimingPanel,
        Size = UDim2.new(1, -120, 0, 28),
        Position = UDim2.fromOffset(12, 42),
        Default = tostring(config.Clicker.IntervalSeconds or config.Clicker.DefaultIntervalSeconds or 1),
        Placeholder = "1-360s",
        CornerRadius = UDim.new(0, 6),
    })
    view.TimingInput = TimingInput

    local ResetTimingBtn = components.button({
        Parent = TimingPanel,
        Size = UDim2.fromOffset(60, 28),
        Position = UDim2.new(1, -72, 0, 42),
        Text = "Reset", TextSize = 9, Color = THEME.panel2, TextColor = THEME.text,
        HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 6), ZIndex = 3, Glow = false,
    })
    view.ResetTimingBtn = ResetTimingBtn

    local TimingStatus = label({
        Parent = TimingPanel, Text = "Range: 1s - 360s",
        Position = UDim2.fromOffset(12, 74),
        Size = UDim2.new(1, -24, 0, 10), TextSize = 8, Color = THEME.dim,
    })
    view.TimingStatus = TimingStatus

    -- CPS section
    local CPSLbl = label({
        Parent = timingTab, Text = "CPS: 20",
        Position = UDim2.fromOffset(CPAD, 152),
        Size = UDim2.new(1, -(CPAD * 2), 0, 14), TextSize = 12, Font = Enum.Font.GothamBold,
    })
    view.CPSLbl = CPSLbl

    local CPSSlider = components.slider({
        Parent = timingTab,
        Size = UDim2.new(1, -(CPAD * 2), 0, 6),
        Position = UDim2.fromOffset(CPAD, 170),
        Default = config.Clicker.DefaultCPS / 100,
    })
    view.CPSSlider = CPSSlider

    -- CPS Preset Buttons
    local PresetsContainer = Instance.new("Frame")
    PresetsContainer.Size = UDim2.new(1, -(CPAD * 2), 0, 24)
    PresetsContainer.Position = UDim2.fromOffset(CPAD, 184)
    PresetsContainer.BackgroundTransparency = 1
    PresetsContainer.Parent = timingTab

    local presetsLayout = Instance.new("UIListLayout")
    presetsLayout.FillDirection = Enum.FillDirection.Horizontal
    presetsLayout.Padding = UDim.new(0, 4)
    presetsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    presetsLayout.Parent = PresetsContainer

    local presetValues = { 5, 10, 20, 50, 100 }
    local presetBtns = {}
    for _, cpsValue in ipairs(presetValues) do
        local btn = components.button({
            Parent = PresetsContainer, Size = UDim2.fromOffset(44, 22),
            Text = tostring(cpsValue), TextSize = 9,
            Color = THEME.panel2, TextColor = THEME.dim,
            HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 5),
            ZIndex = 2, Glow = false,
        })
        presetBtns[cpsValue] = btn.Instance
    end
    view.CPSPresetBtns = presetBtns

    -- ═══════════════════════════════════════════
    -- STATS TAB
    -- ═══════════════════════════════════════════
    local StatsFrame = Instance.new("Frame")
    StatsFrame.Size = UDim2.new(1, -(CPAD * 2), 0, 118)
    StatsFrame.Position = UDim2.fromOffset(CPAD, 10)
    StatsFrame.BackgroundColor3 = THEME.panel
    StatsFrame.BackgroundTransparency = 0.5
    StatsFrame.BorderSizePixel = 0
    StatsFrame.Parent = statsTab
    shared.corner(StatsFrame, UDim.new(0, 8))
    shared.stroke(StatsFrame, THEME.divider, 1, 0.5)

    local StatsGrid = Instance.new("UIGridLayout")
    StatsGrid.CellSize = UDim2.new(0.5, -6, 0, 34)
    StatsGrid.CellPadding = UDim2.new(0, 6, 0, 6)
    StatsGrid.SortOrder = Enum.SortOrder.LayoutOrder
    StatsGrid.Parent = StatsFrame
    local StatsPadding = Instance.new("UIPadding")
    StatsPadding.PaddingTop = UDim.new(0, 6)
    StatsPadding.PaddingBottom = UDim.new(0, 6)
    StatsPadding.PaddingLeft = UDim.new(0, 6)
    StatsPadding.PaddingRight = UDim.new(0, 6)
    StatsPadding.Parent = StatsFrame

    local function makeStatCard(title, order)
        local card = Instance.new("Frame")
        card.BackgroundColor3 = THEME.panel2
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.Parent = StatsFrame
        shared.corner(card, UDim.new(0, 6))
        shared.stroke(card, THEME.divider, 1, 0.5)

        label({
            Parent = card, Text = title, Position = UDim2.fromOffset(6, 4),
            Size = UDim2.new(1, -12, 0, 10), TextSize = 7, Color = THEME.faint,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        })
        return label({
            Parent = card, Text = "0", Position = UDim2.fromOffset(6, 15),
            Size = UDim2.new(1, -12, 0, 15), TextSize = 12, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
    end

    local Stats = {
        TotalClicksVal = makeStatCard("TOTAL CLICKS", 1),
        ActualCPSVal   = makeStatCard("CPS (ACTUAL)", 2),
        FPSVal         = makeStatCard("FPS", 3),
        PingVal        = makeStatCard("PING", 4),
    }
    view.Stats = Stats

    -- Sparkline
    local SPARK_MAX = 150
    local SPARK_SAMPLES = 60
    local SPARK_MAX_BAR = 24

    local SparklineCanvas = Instance.new("Frame")
    SparklineCanvas.Size = UDim2.new(1, -(CPAD * 2), 0, 34)
    SparklineCanvas.Position = UDim2.fromOffset(CPAD, 136)
    SparklineCanvas.BackgroundColor3 = THEME.panel
    SparklineCanvas.BackgroundTransparency = 0.35
    SparklineCanvas.BorderSizePixel = 0
    SparklineCanvas.ClipsDescendants = true
    SparklineCanvas.Parent = statsTab
    shared.corner(SparklineCanvas, UDim.new(0, 5))
    shared.stroke(SparklineCanvas, THEME.divider, 1, 0.5)

    label({
        Parent = SparklineCanvas, Text = "CPS  ·  actual vs target",
        Position = UDim2.fromOffset(6, 1),
        Size = UDim2.new(1, -12, 0, 10), TextSize = 7, Color = THEME.faint,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    })

    local TargetLine = Instance.new("Frame")
    TargetLine.Size = UDim2.new(1, 0, 0, 2)
    TargetLine.AnchorPoint = Vector2.new(0, 1)
    TargetLine.BackgroundColor3 = THEME.warn
    TargetLine.BackgroundTransparency = 0.1
    TargetLine.BorderSizePixel = 0
    TargetLine.ZIndex = 3
    TargetLine.Parent = SparklineCanvas
    shared.corner(TargetLine, UDim.new(1, 0))

    local function setTargetLine(cps)
        local ratio = math.clamp((tonumber(cps) or 0) / SPARK_MAX, 0, 1)
        TargetLine.Position = UDim2.new(0, 0, 1, -3 - ratio * SPARK_MAX_BAR)
    end
    setTargetLine(config.Clicker.DefaultCPS)

    local sparkBars = {}
    local canvasW = W - (CPAD * 2)
    local barStep = canvasW / SPARK_SAMPLES
    local barWidth = math.max(2, math.floor(barStep) - 1)
    for i = 1, SPARK_SAMPLES do
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, barWidth, 0, 0)
        bar.AnchorPoint = Vector2.new(0, 1)
        bar.Position = UDim2.new(0, math.floor((i - 1) * barStep), 1, -3)
        bar.BackgroundColor3 = THEME.accent
        bar.BackgroundTransparency = 0.35
        bar.BorderSizePixel = 0
        bar.ZIndex = 2
        bar.Parent = SparklineCanvas
        shared.corner(bar, UDim.new(0, 2))
        sparkBars[i] = bar
    end

    view.Sparkline = {
        Bars = sparkBars,
        TargetLine = TargetLine,
        Canvas = SparklineCanvas,
        Max = SPARK_MAX,
        MaxBar = SPARK_MAX_BAR,
        SetTarget = setTargetLine,
    }

    -- ═══════════════════════════════════════════
    -- SETTINGS (HOTKEYS) TAB
    -- ═══════════════════════════════════════════
    local KeybindsPanel = Instance.new("Frame")
    KeybindsPanel.Size = UDim2.new(1, -(CPAD * 2), 0, 160)
    KeybindsPanel.Position = UDim2.fromOffset(CPAD, 10)
    KeybindsPanel.BackgroundColor3 = THEME.panel
    KeybindsPanel.BackgroundTransparency = 0.4
    KeybindsPanel.BorderSizePixel = 0
    KeybindsPanel.Parent = settingsTab
    shared.corner(KeybindsPanel, UDim.new(0, 8))
    shared.stroke(KeybindsPanel, THEME.divider, 1, 0.5)

    label({
        Parent = KeybindsPanel, Text = "HOTKEYS",
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 10), TextSize = 8, Color = THEME.faint, Font = Enum.Font.GothamBold,
    })

    local kbDivider = Instance.new("Frame")
    kbDivider.Size = UDim2.new(1, -20, 0, 1)
    kbDivider.Position = UDim2.fromOffset(10, 22)
    kbDivider.BackgroundColor3 = THEME.divider
    kbDivider.BorderSizePixel = 0
    kbDivider.Parent = KeybindsPanel

    local function makeHotkeyRow(labelText, yPos)
        local rowBg = Instance.new("Frame")
        rowBg.Size = UDim2.new(1, 0, 0, 32)
        rowBg.Position = UDim2.fromOffset(0, yPos)
        rowBg.BackgroundColor3 = THEME.panel2
        rowBg.BackgroundTransparency = 0.5
        rowBg.BorderSizePixel = 0
        rowBg.Parent = KeybindsPanel

        label({
            Parent = rowBg, Text = labelText,
            Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -140, 1, 0),
            TextSize = 10, Color = THEME.text, Font = Enum.Font.GothamBold,
        })
        return rowBg
    end

    -- Row 1: Toggle Clicker
    makeHotkeyRow("Toggle Clicker", 26)
    local PickTargetKey = components.keybind({
        Parent = KeybindsPanel,
        Size = UDim2.new(0, 110, 0, 24),
        Position = UDim2.new(1, -(CPAD + 110), 0, 34),
        Default = config.Keys.ToggleClicker,
    })
    view.PickTargetKey = PickTargetKey

    -- Row 2: Pick Target
    makeHotkeyRow("Pick Target", 62)
    local HideShowKey = components.keybind({
        Parent = KeybindsPanel,
        Size = UDim2.new(0, 110, 0, 24),
        Position = UDim2.new(1, -(CPAD + 110), 0, 70),
        Default = "P",
    })
    view.HideShowKey = HideShowKey

    -- Row 3: Hide/Show UI
    makeHotkeyRow("Hide / Show UI", 98)
    local HideUIKey = components.keybind({
        Parent = KeybindsPanel,
        Size = UDim2.new(0, 110, 0, 24),
        Position = UDim2.new(1, -(CPAD + 110), 0, 106),
        Default = "K",
    })

    -- ═══════════════════════════════════════════
    -- MINIMIZED PANEL
    -- ═══════════════════════════════════════════
    local MinimizedPanel = Instance.new("Frame")
    MinimizedPanel.Name = "MinimizedPanel"
    MinimizedPanel.Size = UDim2.fromOffset(220, 52)
    MinimizedPanel.Position = UDim2.fromOffset(20, 20)
    MinimizedPanel.BackgroundColor3 = THEME.bg
    MinimizedPanel.BorderSizePixel = 0
    MinimizedPanel.Active = true
    MinimizedPanel.Visible = false
    MinimizedPanel.Parent = ScreenGui
    shared.corner(MinimizedPanel, UDim.new(0, 8))
    shared.stroke(MinimizedPanel, THEME.accent, 1, 0.4)
    shared.glow(MinimizedPanel, THEME.glow or THEME.accent, 3, 0.9)
    local MiniShadow = shared.shadow(MinimizedPanel, { ExtendX = 8, ExtendY = 8, Transparency = 0.72 })
    view.MinimizedPanel = MinimizedPanel

    local MiniHeader = Instance.new("TextButton")
    MiniHeader.Text = "AutoClicker"
    MiniHeader.Size = UDim2.new(1, -24, 0, 14)
    MiniHeader.Position = UDim2.fromOffset(6, 3)
    MiniHeader.BackgroundTransparency = 1
    MiniHeader.TextColor3 = THEME.accent2
    MiniHeader.Font = Enum.Font.GothamBold
    MiniHeader.TextSize = 9
    MiniHeader.TextXAlignment = Enum.TextXAlignment.Left
    MiniHeader.AutoButtonColor = false
    MiniHeader.BorderSizePixel = 0
    MiniHeader.Parent = MinimizedPanel
    view.MiniHeader = MiniHeader

    local ExpandBtn = components.button({
        Parent = MinimizedPanel, Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, -22, 0, 2),
        Text = "▢", TextSize = 10, Color = THEME.panel2, TextColor = THEME.dim,
        HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 4), ZIndex = 3, Glow = false,
    })
    view.ExpandBtn = ExpandBtn.Instance

    local MiniCardsRow = Instance.new("Frame")
    MiniCardsRow.Size = UDim2.new(1, -12, 0, 28)
    MiniCardsRow.Position = UDim2.fromOffset(6, 20)
    MiniCardsRow.BackgroundTransparency = 1
    MiniCardsRow.Parent = MinimizedPanel

    local MiniListLayout = Instance.new("UIListLayout")
    MiniListLayout.FillDirection = Enum.FillDirection.Horizontal
    MiniListLayout.Padding = UDim.new(0, 3)
    MiniListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MiniListLayout.Parent = MiniCardsRow

    local function makeMiniCard(title, order)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 48, 1, 0)
        card.BackgroundColor3 = THEME.panel2
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.Parent = MiniCardsRow
        shared.corner(card, UDim.new(0, 5))
        shared.stroke(card, THEME.divider, 1, 0.5)

        label({
            Parent = card, Text = title, Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 0, 9), TextSize = 7, Color = THEME.dim,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        return label({
            Parent = card, Text = "-", Position = UDim2.fromOffset(2, 11),
            Size = UDim2.new(1, -4, 0, 14), TextSize = 10, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end

    view.MiniStats = {
        StatusVal  = makeMiniCard("STATUS", 1),
        CPSVal     = makeMiniCard("CPS", 2),
        FPSVal     = makeMiniCard("FPS", 3),
        PingVal    = makeMiniCard("PING", 4),
    }

    view.Theme = THEME
    view.Toast = components.toast
    view.Content = content

    return view
end
