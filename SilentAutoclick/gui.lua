-- SilentAutoclick/gui.lua
-- Builds the GUI layout and returns a table of element references
return function(config)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    local THEME = config.Theme

    if _G.__SilentAutoclick_Destroy then
        pcall(_G.__SilentAutoclick_Destroy)
    end
    _G.__SilentAutoclick_Destroy = nil

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SilentAutoclick_GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then ScreenGui.Parent = lp:WaitForChild("PlayerGui") end

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 300, 0, 336)
    Main.Position = UDim2.new(0.5, -150, 0.5, -168)
    Main.BackgroundColor3 = THEME.bg
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = true
    Main.Parent = ScreenGui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
    local MainStroke = Instance.new("UIStroke", Main)
    MainStroke.Color = THEME.accent
    MainStroke.Transparency = 0.4
    MainStroke.Thickness = 1

    -- ═══════════════════════════════════════════
    -- TOP BAR (draggable)
    -- ═══════════════════════════════════════════
    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 32)
    TopBar.BackgroundColor3 = THEME.topbar
    TopBar.BorderSizePixel = 0
    TopBar.Parent = Main

    local TopBarTitle = Instance.new("TextLabel")
    TopBarTitle.Text = "Silent AutoClicker"
    TopBarTitle.Size = UDim2.new(1, -70, 1, 0)
    TopBarTitle.Position = UDim2.new(0, 12, 0, 0)
    TopBarTitle.BackgroundTransparency = 1
    TopBarTitle.TextColor3 = THEME.accentGlow
    TopBarTitle.Font = Enum.Font.GothamBold
    TopBarTitle.TextSize = 13
    TopBarTitle.TextXAlignment = Enum.TextXAlignment.Left
    TopBarTitle.Parent = TopBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Text = "—"
    MinBtn.Size = UDim2.new(0, 26, 0, 22)
    MinBtn.Position = UDim2.new(1, -60, 0, 5)
    MinBtn.BackgroundColor3 = THEME.panel2
    MinBtn.TextColor3 = THEME.dim
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 13
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TopBar
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Text = "x"
    CloseBtn.Size = UDim2.new(0, 26, 0, 22)
    CloseBtn.Position = UDim2.new(1, -30, 0, 5)
    CloseBtn.BackgroundColor3 = THEME.danger
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 12
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = TopBar
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    -- Bottom drag hit area (extra grab zone) — stops short of MinBtn/CloseBtn
    -- so it never covers them (that overlap was blocking their clicks).
    local DragHit = Instance.new("TextButton")
    DragHit.Size = UDim2.new(1, -68, 0, 32)
    DragHit.Position = UDim2.new(0, 0, 0, 0)
    DragHit.BackgroundTransparency = 1
    DragHit.Text = ""
    DragHit.Parent = TopBar

    -- ═══════════════════════════════════════════
    -- MINIMIZED PANEL (compact: Status / CPS / FPS / Ping)
    -- ═══════════════════════════════════════════
    local MinimizedPanel = Instance.new("Frame")
    MinimizedPanel.Name = "MinimizedPanel"
    MinimizedPanel.Size = UDim2.new(0, 240, 0, 62)
    MinimizedPanel.Position = UDim2.new(0, 20, 0, 20)
    MinimizedPanel.BackgroundColor3 = THEME.bg
    MinimizedPanel.BorderSizePixel = 0
    MinimizedPanel.Active = true
    MinimizedPanel.Visible = false
    MinimizedPanel.Parent = ScreenGui
    Instance.new("UICorner", MinimizedPanel).CornerRadius = UDim.new(0, 10)
    local MiniStroke = Instance.new("UIStroke", MinimizedPanel)
    MiniStroke.Color = THEME.accent
    MiniStroke.Transparency = 0.4
    MiniStroke.Thickness = 1

    local MiniHeader = Instance.new("TextLabel")
    MiniHeader.Text = "AutoClicker"
    MiniHeader.Size = UDim2.new(1, -28, 0, 16)
    MiniHeader.Position = UDim2.new(0, 8, 0, 4)
    MiniHeader.BackgroundTransparency = 1
    MiniHeader.TextColor3 = THEME.accentGlow
    MiniHeader.Font = Enum.Font.GothamBold
    MiniHeader.TextSize = 10
    MiniHeader.TextXAlignment = Enum.TextXAlignment.Left
    MiniHeader.Parent = MinimizedPanel

    local ExpandBtn = Instance.new("TextButton")
    ExpandBtn.Text = "▢"
    ExpandBtn.Size = UDim2.new(0, 18, 0, 18)
    ExpandBtn.Position = UDim2.new(1, -24, 0, 3)
    ExpandBtn.BackgroundColor3 = THEME.panel2
    ExpandBtn.TextColor3 = THEME.dim
    ExpandBtn.Font = Enum.Font.GothamBold
    ExpandBtn.TextSize = 11
    ExpandBtn.BorderSizePixel = 0
    ExpandBtn.Parent = MinimizedPanel
    Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 5)

    local MiniCardsRow = Instance.new("Frame")
    MiniCardsRow.Size = UDim2.new(1, -16, 0, 34)
    MiniCardsRow.Position = UDim2.new(0, 8, 0, 24)
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
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        local t = Instance.new("TextLabel")
        t.Text = title
        t.Size = UDim2.new(1, -4, 0, 10)
        t.Position = UDim2.new(0, 2, 0, 2)
        t.BackgroundTransparency = 1
        t.TextColor3 = THEME.dim
        t.Font = Enum.Font.Gotham
        t.TextSize = 8
        t.TextXAlignment = Enum.TextXAlignment.Center
        t.Parent = card

        local v = Instance.new("TextLabel")
        v.Text = "-"
        v.Size = UDim2.new(1, -4, 0, 16)
        v.Position = UDim2.new(0, 2, 0, 13)
        v.BackgroundTransparency = 1
        v.TextColor3 = THEME.text
        v.Font = Enum.Font.GothamBold
        v.TextSize = 11
        v.TextXAlignment = Enum.TextXAlignment.Center
        v.Parent = card

        return v
    end

    local MiniStatusVal = makeMiniCard("STATUS", 1)
    local MiniCPSVal = makeMiniCard("CPS", 2)
    local MiniFPSVal = makeMiniCard("FPS", 3)
    local MiniPingVal = makeMiniCard("PING", 4)

    -- ═══════════════════════════════════════════
    -- CONTENT
    -- ═══════════════════════════════════════════
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -20, 1, -44)
    Content.Position = UDim2.new(0, 10, 0, 40)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.Text = "Status: OFF"
    StatusLbl.Size = UDim2.new(1, 0, 0, 20)
    StatusLbl.Position = UDim2.new(0, 0, 0, 0)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.TextColor3 = THEME.danger
    StatusLbl.Font = Enum.Font.GothamBold
    StatusLbl.TextSize = 13
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    StatusLbl.Parent = Content

    local MethodLbl = Instance.new("TextLabel")
    MethodLbl.Text = "Mode: -"
    MethodLbl.Size = UDim2.new(1, 0, 0, 16)
    MethodLbl.Position = UDim2.new(0, 0, 0, 20)
    MethodLbl.BackgroundTransparency = 1
    MethodLbl.TextColor3 = THEME.warn
    MethodLbl.Font = Enum.Font.Gotham
    MethodLbl.TextSize = 11
    MethodLbl.TextXAlignment = Enum.TextXAlignment.Left
    MethodLbl.Parent = Content

    -- Mode toggle (Cursor / Fixed)
    local ModeBtn = Instance.new("TextButton")
    ModeBtn.Text = "Click Mode: Follow Cursor"
    ModeBtn.Size = UDim2.new(1, 0, 0, 30)
    ModeBtn.Position = UDim2.new(0, 0, 0, 42)
    ModeBtn.BackgroundColor3 = THEME.panel2
    ModeBtn.TextColor3 = THEME.text
    ModeBtn.Font = Enum.Font.GothamBold
    ModeBtn.TextSize = 11
    ModeBtn.BorderSizePixel = 0
    ModeBtn.Parent = Content
    Instance.new("UICorner", ModeBtn).CornerRadius = UDim.new(0, 8)

    local PosLbl = Instance.new("TextLabel")
    PosLbl.Text = "Target: Not set (press P to pick)"
    PosLbl.Size = UDim2.new(1, 0, 0, 16)
    PosLbl.Position = UDim2.new(0, 0, 0, 76)
    PosLbl.BackgroundTransparency = 1
    PosLbl.TextColor3 = THEME.dim
    PosLbl.Font = Enum.Font.Gotham
    PosLbl.TextSize = 10
    PosLbl.TextXAlignment = Enum.TextXAlignment.Left
    PosLbl.Visible = false
    PosLbl.Parent = Content

    -- CPS Slider (target CPS setting)
    local CPSLbl = Instance.new("TextLabel")
    CPSLbl.Text = "CPS: 20"
    CPSLbl.Size = UDim2.new(1, 0, 0, 16)
    CPSLbl.Position = UDim2.new(0, 0, 0, 98)
    CPSLbl.BackgroundTransparency = 1
    CPSLbl.TextColor3 = THEME.text
    CPSLbl.Font = Enum.Font.GothamBold
    CPSLbl.TextSize = 11
    CPSLbl.TextXAlignment = Enum.TextXAlignment.Left
    CPSLbl.Parent = Content

    local SliderTrack = Instance.new("Frame")
    SliderTrack.Size = UDim2.new(1, 0, 0, 6)
    SliderTrack.Position = UDim2.new(0, 0, 0, 118)
    SliderTrack.BackgroundColor3 = THEME.panel2
    SliderTrack.BorderSizePixel = 0
    SliderTrack.Parent = Content
    Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(1, 0)

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new(0.2, 0, 1, 0)
    SliderFill.BackgroundColor3 = THEME.accent
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderTrack
    Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

    local SliderKnob = Instance.new("TextButton")
    SliderKnob.Text = ""
    SliderKnob.Size = UDim2.new(0, 16, 0, 16)
    SliderKnob.AnchorPoint = Vector2.new(0, 0.5)
    SliderKnob.Position = UDim2.new(0.2, -8, 0.5, 0)
    SliderKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    SliderKnob.BorderSizePixel = 0
    SliderKnob.Parent = SliderTrack
    Instance.new("UICorner", SliderKnob).CornerRadius = UDim.new(1, 0)

    -- ═══════════════════════════════════════════
    -- LIVE STATS GRID (Total Clicks / Actual CPS / FPS / Ping)
    -- ═══════════════════════════════════════════
    local StatsFrame = Instance.new("Frame")
    StatsFrame.Size = UDim2.new(1, 0, 0, 62)
    StatsFrame.Position = UDim2.new(0, 0, 0, 134)
    StatsFrame.BackgroundColor3 = THEME.panel
    StatsFrame.BorderSizePixel = 0
    StatsFrame.Parent = Content
    Instance.new("UICorner", StatsFrame).CornerRadius = UDim.new(0, 8)

    local StatsGrid = Instance.new("UIGridLayout")
    StatsGrid.CellSize = UDim2.new(0.5, -6, 0.5, -6)
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
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Text = title
        titleLbl.Size = UDim2.new(1, -8, 0, 12)
        titleLbl.Position = UDim2.new(0, 4, 0, 2)
        titleLbl.BackgroundTransparency = 1
        titleLbl.TextColor3 = THEME.dim
        titleLbl.Font = Enum.Font.Gotham
        titleLbl.TextSize = 9
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = card

        local valueLbl = Instance.new("TextLabel")
        valueLbl.Text = "0"
        valueLbl.Size = UDim2.new(1, -8, 0, 16)
        valueLbl.Position = UDim2.new(0, 4, 0, 13)
        valueLbl.BackgroundTransparency = 1
        valueLbl.TextColor3 = THEME.text
        valueLbl.Font = Enum.Font.GothamBold
        valueLbl.TextSize = 13
        valueLbl.TextXAlignment = Enum.TextXAlignment.Left
        valueLbl.Parent = card

        return valueLbl
    end

    local TotalClicksVal = makeStatCard("TOTAL CLICKS", 1)
    local ActualCPSVal = makeStatCard("CPS (ACTUAL)", 2)
    local FPSVal = makeStatCard("FPS", 3)
    local PingVal = makeStatCard("PING", 4)

    -- ═══════════════════════════════════════════
    -- TOGGLE + KEYBIND
    -- ═══════════════════════════════════════════
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Text = "Start [F]"
    ToggleBtn.Size = UDim2.new(0.62, 0, 0, 32)
    ToggleBtn.Position = UDim2.new(0, 0, 0, 204)
    ToggleBtn.BackgroundColor3 = THEME.accent
    ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 12
    ToggleBtn.BorderSizePixel = 0
    ToggleBtn.Parent = Content
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

    local KeybindBtn = Instance.new("TextButton")
    KeybindBtn.Text = "Key: F"
    KeybindBtn.Size = UDim2.new(0.35, 0, 0, 32)
    KeybindBtn.Position = UDim2.new(0.65, 0, 0, 204)
    KeybindBtn.BackgroundColor3 = THEME.panel2
    KeybindBtn.TextColor3 = THEME.dim
    KeybindBtn.Font = Enum.Font.GothamBold
    KeybindBtn.TextSize = 12
    KeybindBtn.BorderSizePixel = 0
    KeybindBtn.Parent = Content
    Instance.new("UICorner", KeybindBtn).CornerRadius = UDim.new(0, 8)

    local HintLbl = Instance.new("TextLabel")
    HintLbl.Text = "P: pick fixed target   |   K: hide/show UI"
    HintLbl.Size = UDim2.new(1, 0, 0, 16)
    HintLbl.Position = UDim2.new(0, 0, 0, 244)
    HintLbl.BackgroundTransparency = 1
    HintLbl.TextColor3 = THEME.dim
    HintLbl.Font = Enum.Font.Gotham
    HintLbl.TextSize = 9
    HintLbl.TextXAlignment = Enum.TextXAlignment.Left
    HintLbl.Parent = Content

    return {
        Theme = THEME,
        ScreenGui = ScreenGui,
        Main = Main,
        MainStroke = MainStroke,
        TopBar = TopBar,
        TopBarTitle = TopBarTitle,
        MinBtn = MinBtn,
        CloseBtn = CloseBtn,
        DragHit = DragHit,
        MinimizedPanel = MinimizedPanel,
        MiniHeader = MiniHeader,
        ExpandBtn = ExpandBtn,
        Content = Content,
        StatusLbl = StatusLbl,
        MethodLbl = MethodLbl,
        ModeBtn = ModeBtn,
        PosLbl = PosLbl,
        CPSLbl = CPSLbl,
        SliderTrack = SliderTrack,
        SliderFill = SliderFill,
        SliderKnob = SliderKnob,
        ToggleBtn = ToggleBtn,
        KeybindBtn = KeybindBtn,
        HintLbl = HintLbl,
        Stats = {
            TotalClicksVal = TotalClicksVal,
            ActualCPSVal = ActualCPSVal,
            FPSVal = FPSVal,
            PingVal = PingVal,
        },
        MiniStats = {
            StatusVal = MiniStatusVal,
            CPSVal = MiniCPSVal,
            FPSVal = MiniFPSVal,
            PingVal = MiniPingVal,
        },
    }
end
