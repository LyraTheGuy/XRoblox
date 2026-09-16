-- RideAPet/gui.lua
-- Tabbed UI layout for Ride A Pet automation
return function(config, components)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    local shared = components.shared
    local THEME = config.Theme
    local W, H = config.Window.Size.X, config.Window.Size.Y

    if _G.__RideAPet_Destroy then
        pcall(_G.__RideAPet_Destroy)
    end
    _G.__RideAPet_Destroy = nil

    local view = {}
    local CPAD = 12

    -- ═══════════════════════════════════════════
    -- SCREEN GUI
    -- ═══════════════════════════════════════════
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LyraHub_GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then ScreenGui.Parent = lp:WaitForChild("PlayerGui") end
    view.MainGui = ScreenGui

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
    shared.glow(Main, THEME.glow, 4, 0.92)
    shared.gradient(Main, THEME.bg, THEME.bg2, 90)
    view.Main = Main

    -- ═══════════════════════════════════════════
    -- TOP BAR
    -- ═══════════════════════════════════════════
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BackgroundColor3 = THEME.bg2
    TopBar.BorderSizePixel = 0
    TopBar.ZIndex = 3
    TopBar.Parent = Main
    view.TopBar = TopBar

    local Header = TopBar
    view.Header = Header

    local logo = Instance.new("Frame")
    logo.Size = UDim2.fromOffset(8, 8)
    logo.Position = UDim2.fromOffset(14, 16)
    logo.BackgroundColor3 = THEME.accent
    logo.BorderSizePixel = 0
    logo.Parent = TopBar
    shared.corner(logo, UDim.new(1, 0))
    shared.glow(logo, THEME.glow, 2, 0.55)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Text = config.Window.Title
    TitleLabel.Size = UDim2.fromOffset(200, 16)
    TitleLabel.Position = UDim2.fromOffset(28, 10)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextColor3 = THEME.accent2
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 4
    TitleLabel.Parent = TopBar
    view.Title = TitleLabel

    local SubtitleLabel = Instance.new("TextLabel")
    SubtitleLabel.Text = string.upper(config.Window.Subtitle)
    SubtitleLabel.Size = UDim2.fromOffset(250, 10)
    SubtitleLabel.Position = UDim2.fromOffset(28, 26)
    SubtitleLabel.BackgroundTransparency = 1
    SubtitleLabel.TextColor3 = THEME.faint
    SubtitleLabel.Font = Enum.Font.GothamBold
    SubtitleLabel.TextSize = 7
    SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubtitleLabel.ZIndex = 4
    SubtitleLabel.Parent = TopBar
    view.Subtitle = SubtitleLabel

    local DragBar = Instance.new("Frame")
    DragBar.Name = "DragBar"
    DragBar.Size = UDim2.new(1, -130, 0, 40)
    DragBar.BackgroundTransparency = 1
    DragBar.ZIndex = 4
    DragBar.Parent = TopBar
    view.DragBar = DragBar

    local minBtn = components.button({
        Parent = Main, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -68, 0, 8),
        Text = "—", TextSize = 12, Color = THEME.panel2, TextColor = THEME.text,
        HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 7), ZIndex = 4, Glow = false,
    })
    view.MinBtn = minBtn.Instance

    local closeBtn = components.button({
        Parent = Main, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -38, 0, 8),
        Text = "X", TextSize = 11, Color = Color3.fromRGB(64, 28, 34), TextColor = THEME.danger,
        HoverColor = THEME.danger, CornerRadius = UDim.new(0, 7), ZIndex = 4, Glow = false,
    })
    view.CloseBtn = closeBtn.Instance

    -- Header mask
    local HeaderMask = Instance.new("Frame")
    HeaderMask.Name = "HeaderMask"
    HeaderMask.Size = UDim2.new(1, 0, 0, 40)
    HeaderMask.BackgroundColor3 = THEME.bg2
    HeaderMask.BorderSizePixel = 0
    HeaderMask.ZIndex = 3
    HeaderMask.Parent = Main
    view.HeaderMask = HeaderMask

    -- ═══════════════════════════════════════════
    -- SIDEBAR (Tabs)
    -- ═══════════════════════════════════════════
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 110, 1, -40)
    Sidebar.Position = UDim2.new(0, 0, 0, 40)
    Sidebar.BackgroundColor3 = THEME.sidebar
    Sidebar.BorderSizePixel = 0
    Sidebar.ZIndex = 3
    Sidebar.Parent = Main
    view.Sidebar = Sidebar

    local TabsBar = Instance.new("Frame")
    TabsBar.Name = "TabsBar"
    TabsBar.Size = UDim2.new(0, 110, 1, -8)
    TabsBar.Position = UDim2.new(0, 0, 0, 8)
    TabsBar.BackgroundTransparency = 1
    TabsBar.ZIndex = 4
    TabsBar.Parent = Sidebar
    view.TabsBar = TabsBar

    local tabNames = {"Ride", "Eggs", "ESP", "Settings", "Logs"}
    local tabButtons = {}
    local tabs = {}

    for i, name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Name = name .. "Tab"
        btn.Size = UDim2.new(1, -16, 0, 32)
        btn.Position = UDim2.new(0, 8, 0, (i - 1) * 38 + 4)
        btn.BackgroundColor3 = (i == 1) and THEME.accent or THEME.panel2
        btn.Text = name
        btn.TextColor3 = (i == 1) and Color3.new(1, 1, 1) or THEME.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.ZIndex = 5
        btn.Parent = TabsBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        tabButtons[name] = btn

        local tabFrame = Instance.new("ScrollingFrame")
        tabFrame.Name = name
        tabFrame.Size = UDim2.new(1, -130, 1, -16)
        tabFrame.Position = UDim2.new(0, 118, 0, 48)
        tabFrame.BackgroundTransparency = 1
        tabFrame.BorderSizePixel = 0
        tabFrame.ScrollBarThickness = 3
        tabFrame.ScrollBarImageColor3 = THEME.accent
        tabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tabFrame.ZIndex = 3
        tabFrame.Parent = Main
        tabs[name] = tabFrame

        Instance.new("UIListLayout", tabFrame).Padding = UDim.new(0, 6)
        Instance.new("UIPadding", tabFrame).PaddingLeft = UDim.new(0, 4)
        Instance.new("UIPadding", tabFrame).PaddingRight = UDim.new(0, 4)
        Instance.new("UIPadding", tabFrame).PaddingTop = UDim.new(0, 4)
    end

    view.TabButtons = tabButtons
    view.Tabs = tabs

    -- ═══════════════════════════════════════════
    -- RIDE TAB
    -- ═══════════════════════════════════════════
    local RideTab = tabs.Ride

    local RideSection = Instance.new("Frame")
    RideSection.Size = UDim2.new(1, -8, 0, 200)
    RideSection.BackgroundColor3 = THEME.panel
    RideSection.BorderSizePixel = 0
    RideSection.ZIndex = 4
    RideSection.Parent = RideTab
    Instance.new("UICorner", RideSection).CornerRadius = UDim.new(0, 10)

    local RideTitle = Instance.new("TextLabel")
    RideTitle.Text = "Auto Ride"
    RideTitle.Size = UDim2.new(1, -16, 0, 24)
    RideTitle.Position = UDim2.new(0, 8, 0, 4)
    RideTitle.BackgroundTransparency = 1
    RideTitle.TextColor3 = THEME.accent2
    RideTitle.Font = Enum.Font.GothamBold
    RideTitle.TextSize = 12
    RideTitle.TextXAlignment = Enum.TextXAlignment.Left
    RideTitle.ZIndex = 5
    RideTitle.Parent = RideSection

    local RideStatus = Instance.new("TextLabel")
    RideStatus.Text = "Status: OFF"
    RideStatus.Size = UDim2.new(1, -16, 0, 18)
    RideStatus.Position = UDim2.new(0, 8, 0, 32)
    RideStatus.BackgroundTransparency = 1
    RideStatus.TextColor3 = THEME.danger
    RideStatus.Font = Enum.Font.Gotham
    RideStatus.TextSize = 11
    RideStatus.TextXAlignment = Enum.TextXAlignment.Left
    RideStatus.ZIndex = 5
    RideStatus.Parent = RideSection

    local RideToggle = components.button({
        Parent = RideSection, Size = UDim2.new(1, -16, 0, 32),
        Position = UDim2.new(0, 8, 0, 56),
        Text = "Toggle Ride [" .. tostring(config.Keys.ToggleRide):gsub("Enum.KeyCode.", "") .. "]",
        TextSize = 11, Color = THEME.accent, TextColor = Color3.new(1, 1, 1),
        HoverColor = THEME.accentDark, CornerRadius = UDim.new(0, 8), ZIndex = 5,
    })
    view.RideToggleBtn = RideToggle.Instance

    -- Speed slider label
    local SpeedLabel = Instance.new("TextLabel")
    SpeedLabel.Text = "Speed: " .. config.Ride.DefaultSpeed
    SpeedLabel.Size = UDim2.new(1, -16, 0, 18)
    SpeedLabel.Position = UDim2.new(0, 8, 0, 96)
    SpeedLabel.BackgroundTransparency = 1
    SpeedLabel.TextColor3 = THEME.text
    SpeedLabel.Font = Enum.Font.Gotham
    SpeedLabel.TextSize = 11
    SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    SpeedLabel.ZIndex = 5
    SpeedLabel.Parent = RideSection
    view.RideSpeedLabel = SpeedLabel

    -- Pet list label
    local PetLabel = Instance.new("TextLabel")
    PetLabel.Text = "Detected Pets: —"
    PetLabel.Size = UDim2.new(1, -16, 0, 18)
    PetLabel.Position = UDim2.new(0, 8, 0, 120)
    PetLabel.BackgroundTransparency = 1
    PetLabel.TextColor3 = THEME.dim
    PetLabel.Font = Enum.Font.Gotham
    PetLabel.TextSize = 11
    PetLabel.TextXAlignment = Enum.TextXAlignment.Left
    PetLabel.ZIndex = 5
    PetLabel.Parent = RideSection
    view.PetCountLabel = PetLabel

    -- ═══════════════════════════════════════════
    -- EGGS TAB
    -- ═══════════════════════════════════════════
    local EggsTab = tabs.Eggs

    local EggsSection = Instance.new("Frame")
    EggsSection.Size = UDim2.new(1, -8, 0, 300)
    EggsSection.BackgroundColor3 = THEME.panel
    EggsSection.BorderSizePixel = 0
    EggsSection.ZIndex = 4
    EggsSection.Parent = EggsTab
    Instance.new("UICorner", EggsSection).CornerRadius = UDim.new(0, 10)

    local EggsTitle = Instance.new("TextLabel")
    EggsTitle.Text = "Auto Get Egg"
    EggsTitle.Size = UDim2.new(1, -16, 0, 24)
    EggsTitle.Position = UDim2.new(0, 8, 0, 4)
    EggsTitle.BackgroundTransparency = 1
    EggsTitle.TextColor3 = THEME.accent2
    EggsTitle.Font = Enum.Font.GothamBold
    EggsTitle.TextSize = 12
    EggsTitle.TextXAlignment = Enum.TextXAlignment.Left
    EggsTitle.ZIndex = 5
    EggsTitle.Parent = EggsSection

    local EggStatus = Instance.new("TextLabel")
    EggStatus.Text = "Status: OFF"
    EggStatus.Size = UDim2.new(1, -16, 0, 18)
    EggStatus.Position = UDim2.new(0, 8, 0, 30)
    EggStatus.BackgroundTransparency = 1
    EggStatus.TextColor3 = THEME.danger
    EggStatus.Font = Enum.Font.Gotham
    EggStatus.TextSize = 11
    EggStatus.TextXAlignment = Enum.TextXAlignment.Left
    EggStatus.ZIndex = 5
    EggStatus.Parent = EggsSection
    view.EggStatusLabel = EggStatus

    local EggToggle = components.button({
        Parent = EggsSection, Size = UDim2.new(1, -16, 0, 32),
        Position = UDim2.new(0, 8, 0, 52),
        Text = "Start Auto Get Egg",
        TextSize = 11, Color = THEME.accent, TextColor = Color3.new(1, 1, 1),
        HoverColor = THEME.accentDark, CornerRadius = UDim.new(0, 8), ZIndex = 5,
    })
    view.EggToggleBtn = EggToggle.Instance

    local EggCount = Instance.new("TextLabel")
    EggCount.Text = "Eggs Collected: 0"
    EggCount.Size = UDim2.new(1, -16, 0, 18)
    EggCount.Position = UDim2.new(0, 8, 0, 90)
    EggCount.BackgroundTransparency = 1
    EggCount.TextColor3 = THEME.text
    EggCount.Font = Enum.Font.Gotham
    EggCount.TextSize = 11
    EggCount.TextXAlignment = Enum.TextXAlignment.Left
    EggCount.ZIndex = 5
    EggCount.Parent = EggsSection
    view.EggCountLabel = EggCount

    local EggLastLabel = Instance.new("TextLabel")
    EggLastLabel.Text = "Last: —"
    EggLastLabel.Size = UDim2.new(1, -16, 0, 18)
    EggLastLabel.Position = UDim2.new(0, 8, 0, 108)
    EggLastLabel.BackgroundTransparency = 1
    EggLastLabel.TextColor3 = THEME.dim
    EggLastLabel.Font = Enum.Font.Gotham
    EggLastLabel.TextSize = 11
    EggLastLabel.TextXAlignment = Enum.TextXAlignment.Left
    EggLastLabel.ZIndex = 5
    EggLastLabel.Parent = EggsSection
    view.EggLastLabel = EggLastLabel

    -- Rarity whitelist info
    local WhitelistInfo = Instance.new("TextLabel")
    WhitelistInfo.Text = "Collecting: Divine, Mythical, Legendary, Epic"
    WhitelistInfo.Size = UDim2.new(1, -16, 0, 18)
    WhitelistInfo.Position = UDim2.new(0, 8, 0, 132)
    WhitelistInfo.BackgroundTransparency = 1
    WhitelistInfo.TextColor3 = THEME.faint
    WhitelistInfo.Font = Enum.Font.Gotham
    WhitelistInfo.TextSize = 10
    WhitelistInfo.TextXAlignment = Enum.TextXAlignment.Left
    WhitelistInfo.ZIndex = 5
    WhitelistInfo.Parent = EggsSection
    view.EggWhitelistInfo = WhitelistInfo

    -- Rarity log (last 5 collected)
    local RarityLog = Instance.new("TextLabel")
    RarityLog.Text = "— No eggs collected yet —"
    RarityLog.Size = UDim2.new(1, -16, 0, 60)
    RarityLog.Position = UDim2.new(0, 8, 0, 156)
    RarityLog.BackgroundTransparency = 1
    RarityLog.TextColor3 = THEME.dim
    RarityLog.Font = Enum.Font.Code
    RarityLog.TextSize = 10
    RarityLog.TextXAlignment = Enum.TextXAlignment.Left
    RarityLog.TextYAlignment = Enum.TextYAlignment.Top
    RarityLog.TextWrapped = true
    RarityLog.ZIndex = 5
    RarityLog.Parent = EggsSection
    view.EggRarityLog = RarityLog

    -- Rarity distribution
    local RarityDist = Instance.new("TextLabel")
    RarityDist.Text = "🟣 Divine: 0 | 🔴 Mythical: 0 | 🟡 Legendary: 0 | 🟠 Epic: 0 | 🔵 Rare: 0 | 🟢 Uncommon: 0 | ⚪ Common: 0"
    RarityDist.Size = UDim2.new(1, -16, 0, 30)
    RarityDist.Position = UDim2.new(0, 8, 0, 156)
    RarityDist.BackgroundTransparency = 1
    RarityDist.TextColor3 = THEME.text
    RarityDist.Font = Enum.Font.Code
    RarityDist.TextSize = 9
    RarityDist.TextXAlignment = Enum.TextXAlignment.Left
    RarityDist.TextWrapped = true
    RarityDist.ZIndex = 5
    RarityDist.Parent = EggsSection
    view.EggRarityDist = RarityDist

    -- Session stats
    local SessionStats = Instance.new("TextLabel")
    SessionStats.Text = "Session: 0 eggs | 0.0/min | 0s elapsed | Near: 0 eggs"
    SessionStats.Size = UDim2.new(1, -16, 0, 16)
    SessionStats.Position = UDim2.new(0, 8, 0, 190)
    SessionStats.BackgroundTransparency = 1
    SessionStats.TextColor3 = THEME.faint
    SessionStats.Font = Enum.Font.Code
    SessionStats.TextSize = 9
    SessionStats.TextXAlignment = Enum.TextXAlignment.Left
    SessionStats.ZIndex = 5
    SessionStats.Parent = EggsSection
    view.EggSessionStats = SessionStats

    -- Placement warning
    local PlacementWarning = Instance.new("TextLabel")
    PlacementWarning.Text = "⚠ Eggs are NOT auto-placed — they stay in inventory"
    PlacementWarning.Size = UDim2.new(1, -16, 0, 20)
    PlacementWarning.Position = UDim2.new(0, 8, 0, 210)
    PlacementWarning.BackgroundTransparency = 1
    PlacementWarning.TextColor3 = THEME.warn
    PlacementWarning.Font = Enum.Font.GothamBold
    PlacementWarning.TextSize = 10
    PlacementWarning.TextXAlignment = Enum.TextXAlignment.Left
    PlacementWarning.TextWrapped = true
    PlacementWarning.ZIndex = 5
    PlacementWarning.Parent = EggsSection

    -- ═══════════════════════════════════════════
    -- ESP TAB
    -- ═══════════════════════════════════════════
    local ESPTab = tabs.ESP

    local ESPSection = Instance.new("Frame")
    ESPSection.Size = UDim2.new(1, -8, 0, 160)
    ESPSection.BackgroundColor3 = THEME.panel
    ESPSection.BorderSizePixel = 0
    ESPSection.ZIndex = 4
    ESPSection.Parent = ESPTab
    Instance.new("UICorner", ESPSection).CornerRadius = UDim.new(0, 10)

    local ESPTitle = Instance.new("TextLabel")
    ESPTitle.Text = "Player ESP"
    ESPTitle.Size = UDim2.new(1, -16, 0, 24)
    ESPTitle.Position = UDim2.new(0, 8, 0, 4)
    ESPTitle.BackgroundTransparency = 1
    ESPTitle.TextColor3 = THEME.accent2
    ESPTitle.Font = Enum.Font.GothamBold
    ESPTitle.TextSize = 12
    ESPTitle.TextXAlignment = Enum.TextXAlignment.Left
    ESPTitle.ZIndex = 5
    ESPTitle.Parent = ESPSection

    local ESPToggle = components.button({
        Parent = ESPSection, Size = UDim2.new(1, -16, 0, 32),
        Position = UDim2.new(0, 8, 0, 32),
        Text = "Toggle ESP [" .. tostring(config.Keys.ESP):gsub("Enum.KeyCode.", "") .. "]",
        TextSize = 11, Color = THEME.accent, TextColor = Color3.new(1, 1, 1),
        HoverColor = THEME.accentDark, CornerRadius = UDim.new(0, 8), ZIndex = 5,
    })
    view.ESPToggleBtn = ESPToggle.Instance

    -- ═══════════════════════════════════════════
    -- SETTINGS TAB
    -- ═══════════════════════════════════════════
    local SettingsTab = tabs.Settings

    local SettingsSection = Instance.new("Frame")
    SettingsSection.Size = UDim2.new(1, -8, 0, 200)
    SettingsSection.BackgroundColor3 = THEME.panel
    SettingsSection.BorderSizePixel = 0
    SettingsSection.ZIndex = 4
    SettingsSection.Parent = SettingsTab
    Instance.new("UICorner", SettingsSection).CornerRadius = UDim.new(0, 10)

    local SettingsTitle = Instance.new("TextLabel")
    SettingsTitle.Text = "Settings"
    SettingsTitle.Size = UDim2.new(1, -16, 0, 24)
    SettingsTitle.Position = UDim2.new(0, 8, 0, 4)
    SettingsTitle.BackgroundTransparency = 1
    SettingsTitle.TextColor3 = THEME.accent2
    SettingsTitle.Font = Enum.Font.GothamBold
    SettingsTitle.TextSize = 12
    SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    SettingsTitle.ZIndex = 5
    SettingsTitle.Parent = SettingsSection

    local AntiIdleBtn = components.button({
        Parent = SettingsSection, Size = UDim2.new(1, -16, 0, 32),
        Position = UDim2.new(0, 8, 0, 32),
        Text = "Anti Idle: OFF",
        TextSize = 11, Color = THEME.warn, TextColor = Color3.new(1, 1, 1),
        HoverColor = THEME.accentDark, CornerRadius = UDim.new(0, 8), ZIndex = 5,
    })
    view.AntiIdleBtn = AntiIdleBtn.Instance

    -- Unload button
    local UnloadBtn = components.button({
        Parent = SettingsSection, Size = UDim2.new(1, -16, 0, 32),
        Position = UDim2.new(0, 8, 0, 72),
        Text = "Unload Script",
        TextSize = 11, Color = THEME.danger, TextColor = Color3.new(1, 1, 1),
        HoverColor = Color3.fromRGB(180, 40, 60), CornerRadius = UDim.new(0, 8), ZIndex = 5,
    })
    view.UnloadBtn = UnloadBtn.Instance

    -- ═══════════════════════════════════════════
    -- LOGS TAB
    -- ═══════════════════════════════════════════
    local LogsTab = tabs.Logs

    local LogsSection = Instance.new("Frame")
    LogsSection.Size = UDim2.new(1, -8, 1, -8)
    LogsSection.BackgroundColor3 = THEME.panel
    LogsSection.BorderSizePixel = 0
    LogsSection.ZIndex = 4
    LogsSection.Parent = LogsTab
    Instance.new("UICorner", LogsSection).CornerRadius = UDim.new(0, 10)

    local LogCount = Instance.new("TextLabel")
    LogCount.Text = "0 entries"
    LogCount.Size = UDim2.new(1, -16, 0, 20)
    LogCount.Position = UDim2.new(0, 8, 0, 4)
    LogCount.BackgroundTransparency = 1
    LogCount.TextColor3 = THEME.dim
    LogCount.Font = Enum.Font.Gotham
    LogCount.TextSize = 10
    LogCount.TextXAlignment = Enum.TextXAlignment.Left
    LogCount.ZIndex = 5
    LogCount.Parent = LogsSection

    local ClearLogsBtn = components.button({
        Parent = LogsSection, Size = UDim2.new(0, 60, 0, 20),
        Position = UDim2.new(1, -68, 0, 4),
        Text = "Clear", TextSize = 9, Color = THEME.panel2, TextColor = THEME.dim,
        HoverColor = THEME.danger, CornerRadius = UDim.new(0, 6), ZIndex = 5,
    })
    local ClearLogsBtnInst = ClearLogsBtn.Instance

    local LogScroll = Instance.new("ScrollingFrame")
    LogScroll.Name = "LogScroll"
    LogScroll.Size = UDim2.new(1, -16, 1, -32)
    LogScroll.Position = UDim2.new(0, 8, 0, 28)
    LogScroll.BackgroundTransparency = 1
    LogScroll.BorderSizePixel = 0
    LogScroll.ScrollBarThickness = 3
    LogScroll.ScrollBarImageColor3 = THEME.accent
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LogScroll.ZIndex = 5
    LogScroll.Parent = LogsSection
    Instance.new("UIListLayout", LogScroll).Padding = UDim.new(0, 2)

    view.Logs = {
        LogScroll = LogScroll,
        LogCount = LogCount,
        ClearLogsBtn = ClearLogsBtnInst,
    }

    -- ═══════════════════════════════════════════
    -- STROKES
    -- ═══════════════════════════════════════════
    local MainStroke = Instance.new("UIStroke", Main)
    MainStroke.Color = THEME.accent:Lerp(Color3.new(1, 1, 1), 0.75)
    MainStroke.Thickness = 1
    MainStroke.Transparency = 0.6
    view.MainStroke = MainStroke

    local ContentStroke = Instance.new("UIStroke", Sidebar)
    ContentStroke.Color = THEME.accent:Lerp(Color3.new(0, 0, 0), 0.45)
    ContentStroke.Thickness = 1
    ContentStroke.Transparency = 0.5
    view.ContentStroke = ContentStroke

    return view
end
