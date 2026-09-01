-- SilentAutoclick/gui.lua
-- GUI built with the LyraHub UI kit (shared primitives + component factories).
-- Keeps the same external contract the core/modules use (StatusLbl, ToggleBtn,
-- Stats.*, MiniStats.*, DragHit, ...) so the engine layer stays untouched.

return function(config, components)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    local shared = components.shared
    local THEME = config.Theme
    local W, H = config.Window.Size.X, config.Window.Size.Y

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
        if opts.Visible ~= nil then
            l.Visible = opts.Visible
        end
        l.Parent = opts.Parent
        return l
    end

    local Main = Instance.new("Frame")
    Main.Size = UDim2.fromOffset(W, H)
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.BackgroundColor3 = THEME.bg
    Main.BorderSizePixel = 0
    Main.ZIndex = 2
    Main.ClipsDescendants = true
    Main.Parent = ScreenGui
    shared.corner(Main, UDim.new(0, 12))
    shared.stroke(Main, THEME.divider, 1, 0.45)
    shared.glow(Main, THEME.glow, 4, 0.92)
    shared.gradient(Main, THEME.bg, THEME.bg2, 90)
    view.Main = Main
    view.Shadow = shared.shadow(Main)

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 48)
    TopBar.BackgroundTransparency = 1
    TopBar.ZIndex = 2
    TopBar.Parent = Main

    local logo = Instance.new("Frame")
    logo.Size = UDim2.fromOffset(10, 10)
    logo.Position = UDim2.fromOffset(16, 19)
    logo.BackgroundColor3 = THEME.accent
    logo.BorderSizePixel = 0
    logo.Parent = TopBar
    shared.corner(logo, UDim.new(1, 0))
    shared.glow(logo, THEME.glow, 2, 0.55)

    local TopBarTitle = label({
        Parent = TopBar, Text = config.Window.Title, Position = UDim2.fromOffset(34, 10),
        Size = UDim2.fromOffset(220, 22), TextSize = 14, Font = Enum.Font.GothamBold,
        Color = THEME.accent2,
    })
    label({
        Parent = TopBar, Text = string.upper(config.Window.Subtitle), Position = UDim2.fromOffset(34, 30),
        Size = UDim2.fromOffset(240, 12), TextSize = 7, Color = THEME.faint, Font = Enum.Font.GothamBold,
    })

    local minBtn = components.button({
        Parent = Main, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(W - 76, 10),
        Text = "—", TextSize = 13, Color = THEME.panel2, TextColor = THEME.text,
        HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 8), ZIndex = 3, Glow = false,
    })
    local closeBtn = components.button({
        Parent = Main, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(W - 40, 10),
        Text = "✕", TextSize = 12, Color = Color3.fromRGB(64, 28, 34), TextColor = THEME.danger,
        HoverColor = Color3.fromRGB(96, 38, 46), CornerRadius = UDim.new(0, 8), ZIndex = 3, Glow = false,
    })
    view.MinBtn = minBtn.Instance
    view.CloseBtn = closeBtn.Instance

    local DragHit = Instance.new("TextButton")
    DragHit.Size = UDim2.new(1, 0, 0, 48)
    DragHit.BackgroundTransparency = 1
    DragHit.Text = ""
    DragHit.AutoButtonColor = false
    DragHit.BorderSizePixel = 0
    DragHit.ZIndex = 2
    DragHit.Parent = Main
    view.DragHit = DragHit

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.Position = UDim2.fromOffset(0, 48)
    divider.BackgroundColor3 = THEME.divider
    divider.BorderSizePixel = 0
    divider.Parent = Main

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -24, 1, -68)
    Content.Position = UDim2.new(0, 12, 0, 56)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local StatusLbl = label({
        Parent = Content, Text = "Status: OFF", Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 20), TextSize = 15, Font = Enum.Font.GothamBold, Color = THEME.danger,
    })
    view.StatusLbl = StatusLbl

    local MethodLbl = label({
        Parent = Content, Text = "Mode: -", Position = UDim2.fromOffset(0, 21),
        Size = UDim2.new(1, 0, 0, 12), TextSize = 10, Color = THEME.warn,
    })
    view.MethodLbl = MethodLbl

    label({
        Parent = Content, Text = "CLICK MODE", Position = UDim2.fromOffset(0, 39),
        Size = UDim2.new(1, 0, 0, 10), TextSize = 9, Color = THEME.faint, Font = Enum.Font.GothamBold,
    })
    local ModeDropdown = components.dropdown({
        Parent = Content, Size = UDim2.fromOffset(230, 30), Position = UDim2.fromOffset(0, 50),
        Items = { "Follow Cursor", "Fixed Position" }, Default = "Follow Cursor", ItemHeight = 30,
    })
    view.ModeDropdown = ModeDropdown

    local PosLbl = label({
        Parent = Content, Text = "Target: Not set (press P to pick)", Position = UDim2.fromOffset(0, 86),
        Size = UDim2.new(1, 0, 0, 14), TextSize = 10, Color = THEME.dim, Visible = false,
    })
    view.PosLbl = PosLbl

    local TimingPanel = Instance.new("Frame")
    TimingPanel.Size = UDim2.new(1, 0, 0, 72)
    TimingPanel.Position = UDim2.fromOffset(0, 96)
    TimingPanel.BackgroundColor3 = THEME.panel
    TimingPanel.BackgroundTransparency = 0.4
    TimingPanel.BorderSizePixel = 0
    TimingPanel.Parent = Content
    shared.corner(TimingPanel, UDim.new(0, 10))
    shared.stroke(TimingPanel, THEME.divider, 1, 0.5)

    local TimingTitle = label({
        Parent = TimingPanel, Text = "CLICK TIMING", Position = UDim2.fromOffset(10, 8),
        Size = UDim2.new(1, -20, 0, 10), TextSize = 8, Color = THEME.faint, Font = Enum.Font.GothamBold,
    })

    local IntervalLbl = label({
        Parent = TimingPanel, Text = "Delay: 1.00s / click", Position = UDim2.fromOffset(10, 20),
        Size = UDim2.new(1, -20, 0, 14), TextSize = 11, Font = Enum.Font.GothamBold, Color = THEME.accent2,
    })
    view.IntervalLbl = IntervalLbl

    local TimingInput = components.textinput({
        Parent = TimingPanel,
        Size = UDim2.new(1, -20, 0, 28),
        Position = UDim2.fromOffset(10, 36),
        Default = tostring(config.Clicker.IntervalSeconds or config.Clicker.DefaultIntervalSeconds or 1),
        Placeholder = "1-360 seconds",
        CornerRadius = UDim.new(0, 7),
    })
    view.TimingInput = TimingInput

    local CPSLbl = label({
        Parent = Content, Text = "CPS: 20", Position = UDim2.fromOffset(0, 176),
        Size = UDim2.new(1, 0, 0, 14), TextSize = 12, Font = Enum.Font.GothamBold,
    })
    view.CPSLbl = CPSLbl

    local CPSSlider = components.slider({
        Parent = Content, Size = UDim2.fromOffset(230, 6), Position = UDim2.fromOffset(0, 192),
        Default = config.Clicker.DefaultCPS / 100,
    })
    view.CPSSlider = CPSSlider

    local StatsFrame = Instance.new("Frame")
    StatsFrame.Size = UDim2.new(1, 0, 0, 160)
    StatsFrame.Position = UDim2.fromOffset(0, 206)
    StatsFrame.BackgroundColor3 = THEME.panel
    StatsFrame.BackgroundTransparency = 0.5
    StatsFrame.BorderSizePixel = 0
    StatsFrame.Parent = Content
    shared.corner(StatsFrame, UDim.new(0, 10))
    shared.stroke(StatsFrame, THEME.divider, 1, 0.5)

    local StatsGrid = Instance.new("UIGridLayout")
    StatsGrid.CellSize = UDim2.new(0.5, -6, 0, 44)
    StatsGrid.CellPadding = UDim2.new(0, 8, 0, 8)
    StatsGrid.SortOrder = Enum.SortOrder.LayoutOrder
    StatsGrid.Parent = StatsFrame
    local StatsPadding = Instance.new("UIPadding")
    StatsPadding.PaddingTop = UDim.new(0, 8)
    StatsPadding.PaddingBottom = UDim.new(0, 8)
    StatsPadding.PaddingLeft = UDim.new(0, 8)
    StatsPadding.PaddingRight = UDim.new(0, 8)
    StatsPadding.Parent = StatsFrame

    local function makeStatCard(title, order)
        local card = Instance.new("Frame")
        card.BackgroundColor3 = THEME.panel2
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.Parent = StatsFrame
        shared.corner(card, UDim.new(0, 8))
        shared.stroke(card, THEME.divider, 1, 0.5)

        label({
            Parent = card, Text = title, Position = UDim2.fromOffset(8, 5),
            Size = UDim2.new(1, -16, 0, 12), TextSize = 8, Color = THEME.faint,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        })
        return label({
            Parent = card, Text = "0", Position = UDim2.fromOffset(8, 18),
            Size = UDim2.new(1, -16, 0, 20), TextSize = 14, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
    end

    local Stats = {
        TotalClicksVal = makeStatCard("TOTAL CLICKS", 1),
        ActualCPSVal = makeStatCard("CPS (ACTUAL)", 2),
        FPSVal = makeStatCard("FPS", 3),
        PingVal = makeStatCard("PING", 4),
    }
    view.Stats = Stats

    -- ═══ Live sparkline: actual CPS vs target ═══
    -- 60 vertical bars, one per 0.5s sample (30s of history), heights scaled
    -- against a fixed 150 CPS ceiling so the target line stays stable while
    -- the bars show how close the clicker actually gets.
    local SPARK_MAX = 150
    local SPARK_SAMPLES = 60
    -- Bar area = canvas height (40) minus bottom inset (3) minus the caption
    -- band (y 2..12) so the tallest bars never slide under the caption text.
    local SPARK_MAX_BAR = 22

    local SparklineCanvas = Instance.new("Frame")
    SparklineCanvas.Size = UDim2.new(1, -16, 0, 40)
    SparklineCanvas.Position = UDim2.new(0, 8, 0, 110)
    SparklineCanvas.BackgroundColor3 = THEME.panel
    SparklineCanvas.BackgroundTransparency = 0.35
    SparklineCanvas.BorderSizePixel = 0
    SparklineCanvas.ClipsDescendants = true
    SparklineCanvas.Parent = StatsFrame
    shared.corner(SparklineCanvas, UDim.new(0, 6))
    shared.stroke(SparklineCanvas, THEME.divider, 1, 0.5)

    label({
        Parent = SparklineCanvas, Text = "CPS  ·  actual vs target", Position = UDim2.fromOffset(8, 2),
        Size = UDim2.new(1, -16, 0, 10), TextSize = 7, Color = THEME.faint, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    })

    -- Target line: horizontal marker at the target CPS height (warn color)
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

    -- Bars: one per sample, anchored to the canvas bottom. Canvas width is
    -- (W - 24 window padding - 16 StatsFrame padding), derived from W so the
    -- bars fill the strip instead of a hardcoded width.
    local sparkBars = {}
    local canvasW = W - 24 - 16
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

    -- Toggle + keybind
    local ToggleBtn = components.button({
        Parent = Content, Size = UDim2.fromOffset(190, 36), Position = UDim2.fromOffset(0, 300),
        Text = "Start [F]", TextSize = 12, Color = THEME.accent, HoverColor = THEME.accent2, Glow = false,
    })
    view.ToggleBtn = ToggleBtn

    local KeybindBtn = components.keybind({
        Parent = Content, Size = UDim2.fromOffset(122, 36), Position = UDim2.fromOffset(202, 300),
        Default = config.Keys.ToggleClicker,
    })
    view.KeybindBtn = KeybindBtn

    local HintLbl = label({
        Parent = Content, Text = "P: pick target · K: hide/show UI", Position = UDim2.fromOffset(0, 338),
        Size = UDim2.new(1, 0, 0, 12), TextSize = 9, Color = THEME.faint,
    })
    view.HintLbl = HintLbl

    -- ═══════════════════════════════════════════
    -- MINIMIZED PANEL (Status / CPS / FPS / Ping)
    -- ═══════════════════════════════════════════
    local MinimizedPanel = Instance.new("Frame")
    MinimizedPanel.Name = "MinimizedPanel"
    MinimizedPanel.Size = UDim2.fromOffset(240, 62)
    MinimizedPanel.Position = UDim2.fromOffset(20, 20)
    MinimizedPanel.BackgroundColor3 = THEME.bg
    MinimizedPanel.BorderSizePixel = 0
    MinimizedPanel.Active = true
    MinimizedPanel.Visible = false
    MinimizedPanel.Parent = ScreenGui
    shared.corner(MinimizedPanel, UDim.new(0, 10))
    shared.stroke(MinimizedPanel, THEME.accent, 1, 0.4)
    shared.glow(MinimizedPanel, THEME.glow, 3, 0.9)
    view.MinimizedPanel = MinimizedPanel

    local MiniHeader = label({
        Parent = MinimizedPanel, Text = "AutoClicker", Position = UDim2.fromOffset(8, 4),
        Size = UDim2.new(1, -28, 0, 16), TextSize = 10, Color = THEME.accent2, Font = Enum.Font.GothamBold,
    })
    view.MiniHeader = MiniHeader

    local ExpandBtn = components.button({
        Parent = MinimizedPanel, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(240 - 24, 3),
        Text = "▢", TextSize = 11, Color = THEME.panel2, TextColor = THEME.dim,
        HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 5), ZIndex = 3, Glow = false,
    })
    view.ExpandBtn = ExpandBtn.Instance

    local MiniCardsRow = Instance.new("Frame")
    MiniCardsRow.Size = UDim2.new(1, -16, 0, 34)
    MiniCardsRow.Position = UDim2.fromOffset(8, 24)
    MiniCardsRow.BackgroundTransparency = 1
    MiniCardsRow.Parent = MinimizedPanel

    local MiniListLayout = Instance.new("UIListLayout")
    MiniListLayout.FillDirection = Enum.FillDirection.Horizontal
    MiniListLayout.Padding = UDim.new(0, 4)
    MiniListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MiniListLayout.Parent = MiniCardsRow

    local function makeMiniCard(title, order)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 53, 1, 0)
        card.BackgroundColor3 = THEME.panel2
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.Parent = MiniCardsRow
        shared.corner(card, UDim.new(0, 6))
        shared.stroke(card, THEME.divider, 1, 0.5)

        label({
            Parent = card, Text = title, Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 0, 10), TextSize = 8, Color = THEME.dim,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        return label({
            Parent = card, Text = "-", Position = UDim2.fromOffset(2, 13),
            Size = UDim2.new(1, -4, 0, 16), TextSize = 11, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end

    view.MiniStats = {
        StatusVal = makeMiniCard("STATUS", 1),
        CPSVal = makeMiniCard("CPS", 2),
        FPSVal = makeMiniCard("FPS", 3),
        PingVal = makeMiniCard("PING", 4),
    }

    view.TopBarTitle = TopBarTitle
    view.Content = Content
    view.Theme = THEME
    view.Toast = components.toast -- kit toast component (gui.Toast.show({ Text=..., Variant=... }))

    return view
end
