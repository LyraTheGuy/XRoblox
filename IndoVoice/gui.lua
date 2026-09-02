-- LyraHub/gui.lua
-- Wide sleek GUI with Lyra violet theme, draggable from top bar + bottom line.
-- Consumes the LyraHub UI kit (raw GitHub link) for primitives; the palette
-- comes from config.Theme. Modules still drive raw widgets, so the return
-- contract is unchanged.
return function(config, components)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local lp = Players.LocalPlayer

    -- LyraHub kit primitives (corner/stroke/glow/gradient/shadow/tween)
    local shared = components and components.shared
    -- Lyra Theme (violet/purple palette) — from config, not hardcoded
    local LYRA = config.Theme

    if _G.__LyraHub_Destroy then
        pcall(_G.__LyraHub_Destroy)
    end
    _G.__LyraHub_Destroy = nil

    local function tweenProp(obj, props, t, style, dir)
        style = style or Enum.EasingStyle.Quart
        dir = dir or Enum.EasingDirection.Out
        TweenService:Create(obj, TweenInfo.new(t, style, dir), props):Play()
    end

    -- Kit-style hover animation for chrome buttons (their colors never change
    -- programmatically, so restoring the captured base color is safe)
    local function hoverButton(btn, base, over)
        btn.MouseEnter:Connect(function() shared.tween(btn, { BackgroundColor3 = over }, 0.12) end)
        btn.MouseLeave:Connect(function() shared.tween(btn, { BackgroundColor3 = base }, 0.2) end)
    end

    -- ═══════════════════════════════════════════
    -- LOADING SCREEN
    -- ═══════════════════════════════════════════
    local LoadGui = Instance.new("ScreenGui")
    LoadGui.Name = "LyraLoader"
    LoadGui.ResetOnSpawn = false
    LoadGui.DisplayOrder = 9999
    pcall(function() LoadGui.Parent = game:GetService("CoreGui") end)
    if not LoadGui.Parent then LoadGui.Parent = lp:WaitForChild("PlayerGui") end

    local LoadBG = Instance.new("Frame")
    LoadBG.Size = UDim2.new(0, 620, 0, 420)
    LoadBG.AnchorPoint = Vector2.new(0.5, 0.5)
    LoadBG.Position = UDim2.new(0.5, 0, 0.5, 0)
    LoadBG.BackgroundColor3 = LYRA.bg
    LoadBG.BorderSizePixel = 0
    LoadBG.Parent = LoadGui
    shared.corner(LoadBG, UDim.new(0, 12))
    shared.gradient(LoadBG, LYRA.bg, LYRA.bg2, 90)
    local LoadStroke = shared.stroke(LoadBG, LYRA.accent, 1.5, 0)

    local LoadTitle = Instance.new("TextLabel")
    LoadTitle.Text = "LYRA HUB"
    LoadTitle.Size = UDim2.new(1, 0, 0, 44)
    LoadTitle.Position = UDim2.new(0, 0, 0, 120)
    LoadTitle.BackgroundTransparency = 1
    LoadTitle.TextColor3 = LYRA.accentGlow
    LoadTitle.Font = Enum.Font.GothamBold
    LoadTitle.TextSize = 30
    LoadTitle.TextTransparency = 1
    LoadTitle.Parent = LoadBG

    local LoadQuote = Instance.new("TextLabel")
    LoadQuote.Text = "Precision tools for the bold"
    LoadQuote.Size = UDim2.new(1, 0, 0, 24)
    LoadQuote.Position = UDim2.new(0, 0, 0, 170)
    LoadQuote.BackgroundTransparency = 1
    LoadQuote.TextColor3 = LYRA.dim
    LoadQuote.Font = Enum.Font.Gotham
    LoadQuote.TextSize = 13
    LoadQuote.TextTransparency = 1
    LoadQuote.Parent = LoadBG

    local BarTrack = Instance.new("Frame")
    BarTrack.Size = UDim2.new(0, 360, 0, 4)
    BarTrack.AnchorPoint = Vector2.new(0.5, 0)
    BarTrack.Position = UDim2.new(0.5, 0, 0, 230)
    BarTrack.BackgroundColor3 = LYRA.panel2
    BarTrack.BorderSizePixel = 0
    BarTrack.Parent = LoadBG
    shared.corner(BarTrack, UDim.new(1, 0))

    local BarFill = Instance.new("Frame")
    BarFill.Size = UDim2.new(0, 0, 1, 0)
    BarFill.BackgroundColor3 = LYRA.accent
    BarFill.BorderSizePixel = 0
    BarFill.Parent = BarTrack
    shared.corner(BarFill, UDim.new(1, 0))

    local LoadStatus = Instance.new("TextLabel")
    LoadStatus.Text = "Initializing..."
    LoadStatus.Size = UDim2.new(1, 0, 0, 20)
    LoadStatus.Position = UDim2.new(0, 0, 0, 248)
    LoadStatus.BackgroundTransparency = 1
    LoadStatus.TextColor3 = LYRA.dim
    LoadStatus.Font = Enum.Font.Gotham
    LoadStatus.TextSize = 11
    LoadStatus.Parent = LoadBG

    task.spawn(function()
        local stages = {
            {text = "Loading modules...", pct = 0.20},
            {text = "Setting up ESP...", pct = 0.45},
            {text = "Connecting FishZone...", pct = 0.65},
            {text = "Building GUI...", pct = 0.85},
            {text = "Welcome.", pct = 1.00},
        }
        task.wait(0.1)
        tweenProp(LoadTitle, {TextTransparency = 0}, 0.6)
        task.wait(0.4)
        tweenProp(LoadQuote, {TextTransparency = 0}, 0.5)
        task.wait(0.2)
        for _, stage in ipairs(stages) do
            LoadStatus.Text = stage.text
            tweenProp(BarFill, {Size = UDim2.new(stage.pct, 0, 1, 0)}, 0.4, Enum.EasingStyle.Quint)
            task.wait(0.35)
        end
        task.wait(0.3)
        tweenProp(LoadBG, {BackgroundTransparency = 1}, 0.5)
        tweenProp(LoadStroke, {Transparency = 1}, 0.5)
        tweenProp(LoadTitle, {TextTransparency = 1}, 0.4)
        tweenProp(LoadQuote, {TextTransparency = 1}, 0.4)
        tweenProp(LoadStatus, {TextTransparency = 1}, 0.4)
        tweenProp(BarTrack, {BackgroundTransparency = 1}, 0.4)
        tweenProp(BarFill, {BackgroundTransparency = 1}, 0.4)
        task.wait(0.55)
        pcall(function() LoadGui:Destroy() end)
    end)

    -- ═══════════════════════════════════════════
    -- MAIN GUI
    -- ═══════════════════════════════════════════
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LyraHub_Main"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then ScreenGui.Parent = lp:WaitForChild("PlayerGui") end

    -- Main frame: wider (620x420)
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 620, 0, 420)
    Main.Position = UDim2.new(0.5, -310, 0.5, -210)
    Main.BackgroundColor3 = LYRA.bg
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = true
    Main.ZIndex = 2
    Main.Parent = ScreenGui
    shared.corner(Main, UDim.new(0, 12))
    shared.gradient(Main, LYRA.bg, LYRA.bg2, 90)
    shared.glow(Main, LYRA.accent, 3, 0.9)
    local MainStroke = shared.stroke(Main, LYRA.accentDark, 1, 0)
    -- Soft drop shadow behind the window (follows on drag, hides on minimize)
    local MainShadow = shared.shadow(Main, { ExtendX = 10, ExtendY = 10, Transparency = 0.72, OffsetY = 0 })

    -- ═══════════════════════════════════════════
    -- TOP BAR (draggable)
    -- ═══════════════════════════════════════════
    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 36)
    TopBar.Position = UDim2.new(0, 0, 0, 0)
    TopBar.BackgroundColor3 = LYRA.topbar
    TopBar.BorderSizePixel = 0
    TopBar.Parent = Main

    local TopBarTitle = Instance.new("TextLabel")
    TopBarTitle.Text = "LYRA HUB"
    TopBarTitle.Size = UDim2.new(0, 200, 1, 0)
    TopBarTitle.Position = UDim2.new(0, 14, 0, 0)
    TopBarTitle.BackgroundTransparency = 1
    TopBarTitle.TextColor3 = LYRA.accentGlow
    TopBarTitle.Font = Enum.Font.GothamBold
    TopBarTitle.TextSize = 13
    TopBarTitle.TextXAlignment = Enum.TextXAlignment.Left
    TopBarTitle.Parent = TopBar

    -- Minimize button
    local MinBtn = Instance.new("TextButton")
    MinBtn.Text = "—"
    MinBtn.Size = UDim2.new(0, 30, 0, 24)
    MinBtn.Position = UDim2.new(1, -68, 0, 6)
    MinBtn.BackgroundColor3 = LYRA.panel2
    MinBtn.TextColor3 = LYRA.dim
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 14
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TopBar
    shared.corner(MinBtn, UDim.new(0, 6))
    hoverButton(MinBtn, LYRA.panel2, LYRA.accent2)

    -- Close button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Text = "x"
    CloseBtn.Size = UDim2.new(0, 30, 0, 24)
    CloseBtn.Position = UDim2.new(1, -34, 0, 6)
    CloseBtn.BackgroundColor3 = LYRA.danger
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 13
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = TopBar
    shared.corner(CloseBtn, UDim.new(0, 6))
    hoverButton(CloseBtn, LYRA.danger, LYRA.danger:Lerp(Color3.new(1, 1, 1), 0.15))

    -- ═══════════════════════════════════════════
    -- DRAG LOGIC (top bar + bottom line)
    -- ═══════════════════════════════════════════
    local dragging, dragStart, startPos

    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end

    local function updateDrag(input)
        if dragging then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            if MainShadow then
                MainShadow.Position = UDim2.new(Main.Position.X.Scale, Main.Position.X.Offset - 5, Main.Position.Y.Scale, Main.Position.Y.Offset - 5)
            end
        end
    end

    TopBar.InputBegan:Connect(beginDrag)
    UserInputService.InputChanged:Connect(updateDrag)

    -- Bottom drag line
    local DragBar = Instance.new("Frame")
    DragBar.Size = UDim2.new(0, 80, 0, 4)
    DragBar.AnchorPoint = Vector2.new(0.5, 0)
    DragBar.Position = UDim2.new(0.5, 0, 1, -10)
    DragBar.BackgroundColor3 = LYRA.accentDark
    DragBar.BorderSizePixel = 0
    DragBar.Parent = Main
    shared.corner(DragBar, UDim.new(1, 0))

    local DragHit = Instance.new("TextButton")
    DragHit.Size = UDim2.new(0, 140, 0, 16)
    DragHit.AnchorPoint = Vector2.new(0.5, 0)
    DragHit.Position = UDim2.new(0.5, 0, 1, -14)
    DragHit.Text = ""
    DragHit.BackgroundTransparency = 1
    DragHit.Parent = Main
    DragHit.InputBegan:Connect(beginDrag)

    -- Minimized orb (circular "L" button, hidden by default)
    local MinimizedOrb = Instance.new("TextButton")
    MinimizedOrb.Size = UDim2.new(0, 44, 0, 44)
    MinimizedOrb.Position = UDim2.new(0, 20, 0, 20)
    MinimizedOrb.AnchorPoint = Vector2.new(0, 0)
    MinimizedOrb.BackgroundColor3 = LYRA.accent
    MinimizedOrb.Text = "L"
    MinimizedOrb.TextColor3 = Color3.new(1, 1, 1)
    MinimizedOrb.Font = Enum.Font.GothamBold
    MinimizedOrb.TextSize = 18
    MinimizedOrb.BorderSizePixel = 0
    MinimizedOrb.Visible = false
    MinimizedOrb.Parent = ScreenGui
    shared.corner(MinimizedOrb, UDim.new(1, 0))
    local OrbStroke = shared.stroke(MinimizedOrb, LYRA.accentGlow, 1.5, 0)

    -- ═══════════════════════════════════════════
    -- SIDEBAR (wider: 130px)
    -- ═══════════════════════════════════════════
    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 130, 1, -36)
    Sidebar.Position = UDim2.new(0, 0, 0, 36)
    Sidebar.BackgroundColor3 = LYRA.sidebar
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = Main

    -- Hub name in sidebar
    local Title = Instance.new("TextLabel")
    Title.Text = "LyraHub"
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Position = UDim2.new(0, 0, 0, 10)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = LYRA.accentGlow
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.Parent = Sidebar

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Text = "v1.2 | LyraHub UI"
    Subtitle.Size = UDim2.new(1, 0, 0, 14)
    Subtitle.Position = UDim2.new(0, 0, 0, 46)
    Subtitle.BackgroundTransparency = 1
    Subtitle.TextColor3 = LYRA.dim
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextSize = 10
    Subtitle.Parent = Sidebar

    -- Sidebar separator
    local SepLine = Instance.new("Frame")
    SepLine.Size = UDim2.new(0.7, 0, 0, 1)
    SepLine.AnchorPoint = Vector2.new(0.5, 0)
    SepLine.Position = UDim2.new(0.5, 0, 0, 64)
    SepLine.BackgroundColor3 = LYRA.panel2
    SepLine.BorderSizePixel = 0
    SepLine.Parent = Sidebar

    -- Header / HeaderMask (API contract)
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 64)
    Header.Position = UDim2.new(0, 0, 0, 0)
    Header.BackgroundTransparency = 1
    Header.BorderSizePixel = 0
    Header.Parent = Sidebar

    local HeaderMask = Instance.new("Frame")
    HeaderMask.Size = UDim2.new(1, 0, 0, 1)
    HeaderMask.Position = UDim2.new(0, 0, 0, 64)
    HeaderMask.BackgroundTransparency = 1
    HeaderMask.BorderSizePixel = 0
    HeaderMask.Parent = Sidebar

    -- TabsBar (nav area)
    local TabsBar = Instance.new("Frame")
    TabsBar.Size = UDim2.new(1, 0, 1, -74)
    TabsBar.Position = UDim2.new(0, 0, 0, 74)
    TabsBar.BackgroundTransparency = 1
    TabsBar.BorderSizePixel = 0
    TabsBar.ClipsDescendants = true
    TabsBar.Parent = Sidebar

    -- Sidebar nav buttons (full text, vertical)
    local tabNames = {"About", "Players", "Fishing", "Mining", "Fun", "Settings", "Logs"}
    local tabIcons = {"About", "Players", "Fishing", "Mining", "Fun", "Settings", "Logs"}
    local TabButtons = {}

    for i, name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Text = tabIcons[i]
        btn.Size = UDim2.new(1, -16, 0, 34)
        btn.Position = UDim2.new(0, 8, 0, (i - 1) * 42)
        btn.BackgroundColor3 = (i == 1) and LYRA.accent or LYRA.panel2
        btn.BackgroundTransparency = (i == 1) and 0.15 or 0.6
        btn.TextColor3 = (i == 1) and LYRA.text or LYRA.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.Parent = TabsBar
        shared.corner(btn, UDim.new(0, 8))
        TabButtons[name] = btn
    end

    -- ═══════════════════════════════════════════
    -- CONTENT AREA
    -- ═══════════════════════════════════════════
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -142, 1, -48)
    Content.Position = UDim2.new(0, 136, 0, 42)
    Content.BackgroundColor3 = LYRA.panel
    Content.BorderSizePixel = 0
    Content.ClipsDescendants = true
    Content.Parent = Main
    shared.corner(Content, UDim.new(0, 10))
    local ContentStroke = shared.stroke(Content, LYRA.panel2, 1, 0)

    -- Tab content frames
    local Tabs = {}
    for i, name in ipairs(tabNames) do
        local f = Instance.new("Frame")
        f.Name = name .. "Tab"
        f.Size = UDim2.new(1, 0, 1, 0)
        f.BackgroundTransparency = 1
        f.Visible = (i == 1)
        f.Parent = Content
        Tabs[name] = f
    end

    -- ═══════════════════════════════════════════
    -- ABOUT TAB
    -- ═══════════════════════════════════════════
    local AboutTitle = Instance.new("TextLabel")
    AboutTitle.Size = UDim2.new(1, -20, 0, 30)
    AboutTitle.Position = UDim2.new(0, 10, 0, 20)
    AboutTitle.BackgroundTransparency = 1
    AboutTitle.Text = "LyraHub"
    AboutTitle.TextColor3 = LYRA.accentGlow
    AboutTitle.Font = Enum.Font.GothamBold
    AboutTitle.TextSize = 22
    AboutTitle.TextXAlignment = Enum.TextXAlignment.Left
    AboutTitle.Parent = Tabs.About

    local AboutSub = Instance.new("TextLabel")
    AboutSub.Size = UDim2.new(1, -20, 0, 18)
    AboutSub.Position = UDim2.new(0, 10, 0, 52)
    AboutSub.BackgroundTransparency = 1
    AboutSub.Text = "Automation tools for IndoVoice"
    AboutSub.TextColor3 = LYRA.dim
    AboutSub.Font = Enum.Font.Gotham
    AboutSub.TextSize = 12
    AboutSub.TextXAlignment = Enum.TextXAlignment.Left
    AboutSub.Parent = Tabs.About

    local AboutSep = Instance.new("Frame")
    AboutSep.Size = UDim2.new(1, -20, 0, 1)
    AboutSep.Position = UDim2.new(0, 10, 0, 80)
    AboutSep.BackgroundColor3 = LYRA.panel2
    AboutSep.BorderSizePixel = 0
    AboutSep.Parent = Tabs.About

    local AboutDiscord = Instance.new("TextLabel")
    AboutDiscord.Size = UDim2.new(1, -20, 0, 20)
    AboutDiscord.Position = UDim2.new(0, 10, 0, 94)
    AboutDiscord.BackgroundTransparency = 1
    AboutDiscord.Text = "Discord: Ahzencal"
    AboutDiscord.TextColor3 = LYRA.text
    AboutDiscord.Font = Enum.Font.GothamBold
    AboutDiscord.TextSize = 13
    AboutDiscord.TextXAlignment = Enum.TextXAlignment.Left
    AboutDiscord.Parent = Tabs.About

    local AboutSaweria = Instance.new("TextLabel")
    AboutSaweria.Size = UDim2.new(1, -20, 0, 20)
    AboutSaweria.Position = UDim2.new(0, 10, 0, 120)
    AboutSaweria.BackgroundTransparency = 1
    AboutSaweria.Text = "Saweria: saweria.co/ahzencal"
    AboutSaweria.TextColor3 = LYRA.text
    AboutSaweria.Font = Enum.Font.GothamBold
    AboutSaweria.TextSize = 13
    AboutSaweria.TextXAlignment = Enum.TextXAlignment.Left
    AboutSaweria.Parent = Tabs.About

    local CopySaweriaBtn = Instance.new("TextButton")
    CopySaweriaBtn.Size = UDim2.new(0, 80, 0, 24)
    CopySaweriaBtn.Position = UDim2.new(1, -90, 0, 118)
    CopySaweriaBtn.BackgroundColor3 = LYRA.accent
    CopySaweriaBtn.Text = "Copy"
    CopySaweriaBtn.TextColor3 = Color3.new(1, 1, 1)
    CopySaweriaBtn.Font = Enum.Font.GothamBold
    CopySaweriaBtn.TextSize = 11
    CopySaweriaBtn.BorderSizePixel = 0
    CopySaweriaBtn.Parent = Tabs.About
    shared.corner(CopySaweriaBtn, UDim.new(0, 6))

    local AboutSep2 = Instance.new("Frame")
    AboutSep2.Size = UDim2.new(1, -20, 0, 1)
    AboutSep2.Position = UDim2.new(0, 10, 0, 154)
    AboutSep2.BackgroundColor3 = LYRA.panel2
    AboutSep2.BorderSizePixel = 0
    AboutSep2.Parent = Tabs.About

    local AboutDesc = Instance.new("TextLabel")
    AboutDesc.Size = UDim2.new(1, -20, 0, 60)
    AboutDesc.Position = UDim2.new(0, 10, 0, 164)
    AboutDesc.BackgroundTransparency = 1
    AboutDesc.Text = "LyraHub is a multi-feature automation hub for IndoVoice. Features include auto fishing, auto mining, zone TP, ore/fish selling, gacha rolling, player ESP/TP/beam, hotspot ESP, auto clicker, webhook logging, and more — all in a custom UI with persistent settings."
    AboutDesc.TextColor3 = LYRA.dim
    AboutDesc.Font = Enum.Font.Gotham
    AboutDesc.TextSize = 11
    AboutDesc.TextWrapped = true
    AboutDesc.TextXAlignment = Enum.TextXAlignment.Left
    AboutDesc.TextYAlignment = Enum.TextYAlignment.Top
    AboutDesc.Parent = Tabs.About

    local AboutCreator = Instance.new("TextLabel")
    AboutCreator.Size = UDim2.new(1, -20, 0, 36)
    AboutCreator.Position = UDim2.new(0, 10, 0, 230)
    AboutCreator.BackgroundTransparency = 1
    AboutCreator.Text = "Created By: Ahzencal\nLyraHub est. 2026"
    AboutCreator.TextColor3 = LYRA.dim
    AboutCreator.Font = Enum.Font.Gotham
    AboutCreator.TextSize = 11
    AboutCreator.TextXAlignment = Enum.TextXAlignment.Left
    AboutCreator.TextYAlignment = Enum.TextYAlignment.Top
    AboutCreator.Parent = Tabs.About

    -- ── Session Stats Dashboard ──
    local DashboardCard = Instance.new("Frame")
    DashboardCard.Size = UDim2.new(1, -20, 0, 70)
    DashboardCard.Position = UDim2.new(0, 10, 0, 270)
    DashboardCard.BackgroundColor3 = LYRA.bg2
    DashboardCard.BorderSizePixel = 0
    DashboardCard.Parent = Tabs.About
    shared.corner(DashboardCard, UDim.new(0, 8))
    shared.stroke(DashboardCard, LYRA.divider, 1, 0)

    local DashTitle = Instance.new("TextLabel")
    DashTitle.Size = UDim2.new(1, -16, 0, 18)
    DashTitle.Position = UDim2.new(0, 8, 0, 6)
    DashTitle.BackgroundTransparency = 1
    DashTitle.Text = "📊 Session Overview"
    DashTitle.TextColor3 = LYRA.accentGlow
    DashTitle.Font = Enum.Font.GothamBold
    DashTitle.TextSize = 11
    DashTitle.TextXAlignment = Enum.TextXAlignment.Left
    DashTitle.Parent = DashboardCard

    local DashEarnings = Instance.new("TextLabel")
    DashEarnings.Size = UDim2.new(0.5, -8, 0, 16)
    DashEarnings.Position = UDim2.new(0, 8, 0, 26)
    DashEarnings.BackgroundTransparency = 1
    DashEarnings.Text = "Ropiah Earned: 0"
    DashEarnings.TextColor3 = LYRA.text
    DashEarnings.Font = Enum.Font.Gotham
    DashEarnings.TextSize = 10
    DashEarnings.TextXAlignment = Enum.TextXAlignment.Left
    DashEarnings.Parent = DashboardCard

    local DashSessionTime = Instance.new("TextLabel")
    DashSessionTime.Size = UDim2.new(0.5, -8, 0, 16)
    DashSessionTime.Position = UDim2.new(0.5, 0, 0, 26)
    DashSessionTime.BackgroundTransparency = 1
    DashSessionTime.Text = "Uptime: 00:00:00"
    DashSessionTime.TextColor3 = LYRA.dim
    DashSessionTime.Font = Enum.Font.Gotham
    DashSessionTime.TextSize = 10
    DashSessionTime.TextXAlignment = Enum.TextXAlignment.Left
    DashSessionTime.Parent = DashboardCard

    local DashActions = Instance.new("TextLabel")
    DashActions.Size = UDim2.new(1, -16, 0, 16)
    DashActions.Position = UDim2.new(0, 8, 0, 46)
    DashActions.BackgroundTransparency = 1
    DashActions.Text = "Catches: 0  |  Mined: 0  |  Gachas: 0"
    DashActions.TextColor3 = LYRA.dim
    DashActions.Font = Enum.Font.Gotham
    DashActions.TextSize = 10
    DashActions.TextXAlignment = Enum.TextXAlignment.Left
    DashActions.Parent = DashboardCard

    local AboutVersion = Instance.new("TextLabel")
    AboutVersion.Size = UDim2.new(1, -20, 0, 20)
    AboutVersion.Position = UDim2.new(0, 10, 1, -24)
    AboutVersion.BackgroundTransparency = 1
    AboutVersion.Text = "v1.2 | LyraHub UI"
    AboutVersion.TextColor3 = LYRA.dim
    AboutVersion.Font = Enum.Font.Code
    AboutVersion.TextSize = 10
    AboutVersion.TextXAlignment = Enum.TextXAlignment.Left
    AboutVersion.Parent = Tabs.About

    -- ═══════════════════════════════════════════
    -- PLAYERS TAB
    -- ═══════════════════════════════════════════
    local SearchBox = Instance.new("TextBox")
    SearchBox.PlaceholderText = "Search player..."
    SearchBox.Text = ""
    SearchBox.ClearTextOnFocus = false
    SearchBox.Size = UDim2.new(1, -20, 0, 32)
    SearchBox.Position = UDim2.new(0, 10, 0, 10)
    SearchBox.BackgroundColor3 = LYRA.bg2
    SearchBox.TextColor3 = LYRA.text
    SearchBox.PlaceholderColor3 = LYRA.dim
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 13
    SearchBox.BorderSizePixel = 0
    SearchBox.Parent = Tabs.Players
    shared.corner(SearchBox, UDim.new(0, 8))

    local PlayerList = Instance.new("ScrollingFrame")
    PlayerList.Size = UDim2.new(1, -20, 1, -70)
    PlayerList.Position = UDim2.new(0, 10, 0, 48)
    PlayerList.BackgroundColor3 = LYRA.bg2
    PlayerList.BorderSizePixel = 0
    PlayerList.ScrollBarThickness = 3
    PlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    PlayerList.Parent = Tabs.Players
    shared.corner(PlayerList, UDim.new(0, 8))
    Instance.new("UIListLayout", PlayerList).Padding = UDim.new(0, 4)

    local PlayerHint = Instance.new("TextLabel")
    PlayerHint.Text = "Scroll for more players"
    PlayerHint.Size = UDim2.new(1, -20, 0, 16)
    PlayerHint.Position = UDim2.new(0, 10, 1, -20)
    PlayerHint.BackgroundTransparency = 1
    PlayerHint.TextColor3 = LYRA.dim
    PlayerHint.Font = Enum.Font.Gotham
    PlayerHint.TextSize = 10
    PlayerHint.TextXAlignment = Enum.TextXAlignment.Left
    PlayerHint.Parent = Tabs.Players

    -- ═══════════════════════════════════════════
    -- FISHING TAB (combined FishZone + AutoFish)
    -- ═══════════════════════════════════════════
    local function makeActionButton(parent, text, y, color)
        local b = Instance.new("TextButton")
        b.Text = text
        b.Size = UDim2.new(1, -20, 0, 30)
        b.Position = UDim2.new(0, 10, 0, y)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.BorderSizePixel = 0
        b.Parent = parent
        shared.corner(b, UDim.new(0, 8))
        return b
    end

    local FishScroll = Instance.new("ScrollingFrame")
    FishScroll.Size = UDim2.new(1, 0, 1, 0)
    FishScroll.BackgroundTransparency = 1
    FishScroll.BorderSizePixel = 0
    FishScroll.ScrollBarThickness = 3
    FishScroll.CanvasSize = UDim2.new(0, 0, 0, 620)
    FishScroll.Parent = Tabs.Fishing

    local FishingTitle = Instance.new("TextLabel")
    FishingTitle.Size = UDim2.new(1, -100, 0, 16)
    FishingTitle.Position = UDim2.new(0, 10, 0, 8)
    FishingTitle.BackgroundTransparency = 1
    FishingTitle.Text = "🎣 Auto Fishing"
    FishingTitle.TextColor3 = LYRA.accentGlow
    FishingTitle.Font = Enum.Font.GothamBold
    FishingTitle.TextSize = 11
    FishingTitle.TextXAlignment = Enum.TextXAlignment.Left
    FishingTitle.Parent = FishScroll

    local FishingBadge = Instance.new("Frame")
    FishingBadge.Size = UDim2.new(0, 68, 0, 18)
    FishingBadge.Position = UDim2.new(1, -78, 0, 8)
    FishingBadge.BackgroundColor3 = LYRA.panel2
    FishingBadge.BorderSizePixel = 0
    FishingBadge.Parent = FishScroll
    shared.corner(FishingBadge, UDim.new(0, 9))
    shared.stroke(FishingBadge, LYRA.divider, 1, 0.5)

    local FishingBadgeText = Instance.new("TextLabel")
    FishingBadgeText.Size = UDim2.new(1, 0, 1, 0)
    FishingBadgeText.BackgroundTransparency = 1
    FishingBadgeText.Text = "LIVE"
    FishingBadgeText.TextColor3 = LYRA.accentGlow
    FishingBadgeText.Font = Enum.Font.GothamBold
    FishingBadgeText.TextSize = 9
    FishingBadgeText.Parent = FishingBadge

    -- Buttons
    local ZoneESPBtn = makeActionButton(FishScroll, "FishZone ESP: OFF", 34, LYRA.accent)
    local AutoTPBtn = makeActionButton(FishScroll, "Auto TP Active FishZone: OFF", 68, LYRA.tp)
    local AutoFishToggleBtn = makeActionButton(FishScroll, "Auto Fish: OFF", 102, LYRA.success)
    local AutoSellBtn = makeActionButton(FishScroll, "Auto Sell Fish: OFF", 136, LYRA.warn)
    local SellNowBtn = makeActionButton(FishScroll, "Sell All Now", 170, LYRA.accent)
    local RefreshCharBtn = makeActionButton(FishScroll, "Refresh Character", 204, LYRA.danger)

    -- AutoFish Status
    local AutoFishStatus = Instance.new("TextLabel")
    AutoFishStatus.Size = UDim2.new(1, -20, 0, 18)
    AutoFishStatus.Position = UDim2.new(0, 10, 0, 242)
    AutoFishStatus.BackgroundTransparency = 1
    AutoFishStatus.TextColor3 = LYRA.dim
    AutoFishStatus.Text = "Fish: Idle"
    AutoFishStatus.Font = Enum.Font.GothamBold
    AutoFishStatus.TextSize = 11
    AutoFishStatus.TextXAlignment = Enum.TextXAlignment.Left
    AutoFishStatus.Parent = FishScroll

    local AutoFishLastCatch = Instance.new("TextLabel")
    AutoFishLastCatch.Size = UDim2.new(1, -20, 0, 16)
    AutoFishLastCatch.Position = UDim2.new(0, 10, 0, 262)
    AutoFishLastCatch.BackgroundTransparency = 1
    AutoFishLastCatch.TextColor3 = LYRA.dim
    AutoFishLastCatch.Text = "Last: -"
    AutoFishLastCatch.Font = Enum.Font.Gotham
    AutoFishLastCatch.TextSize = 10
    AutoFishLastCatch.TextXAlignment = Enum.TextXAlignment.Left
    AutoFishLastCatch.Parent = FishScroll

    -- Zone Status
    local ZoneStatus = Instance.new("TextLabel")
    ZoneStatus.Size = UDim2.new(1, -20, 0, 16)
    ZoneStatus.Position = UDim2.new(0, 10, 0, 280)
    ZoneStatus.BackgroundTransparency = 1
    ZoneStatus.TextColor3 = LYRA.text
    ZoneStatus.Text = "Zone: Idle"
    ZoneStatus.Font = Enum.Font.Gotham
    ZoneStatus.TextSize = 10
    ZoneStatus.TextXAlignment = Enum.TextXAlignment.Left
    ZoneStatus.Parent = FishScroll

    -- Separator
    local FishSep1 = Instance.new("Frame")
    FishSep1.Size = UDim2.new(1, -20, 0, 1)
    FishSep1.Position = UDim2.new(0, 10, 0, 304)
    FishSep1.BackgroundColor3 = LYRA.panel2
    FishSep1.BorderSizePixel = 0
    FishSep1.Parent = FishScroll

    -- Config section
    local SellIntervalLbl = Instance.new("TextLabel")
    SellIntervalLbl.Size = UDim2.new(0, 100, 0, 20)
    SellIntervalLbl.Position = UDim2.new(0, 10, 0, 312)
    SellIntervalLbl.BackgroundTransparency = 1
    SellIntervalLbl.Text = "Sell Interval (s):"
    SellIntervalLbl.TextColor3 = LYRA.dim
    SellIntervalLbl.Font = Enum.Font.Gotham
    SellIntervalLbl.TextSize = 10
    SellIntervalLbl.TextXAlignment = Enum.TextXAlignment.Left
    SellIntervalLbl.Parent = FishScroll

    local SellIntervalInput = Instance.new("TextBox")
    SellIntervalInput.Size = UDim2.new(0, 60, 0, 20)
    SellIntervalInput.Position = UDim2.new(0, 112, 0, 312)
    SellIntervalInput.BackgroundColor3 = LYRA.bg2
    SellIntervalInput.TextColor3 = LYRA.text
    SellIntervalInput.Text = tostring(config.AutoSell and config.AutoSell.Interval or 3600)
    SellIntervalInput.Font = Enum.Font.Code
    SellIntervalInput.TextSize = 10
    SellIntervalInput.ClearTextOnFocus = false
    SellIntervalInput.BorderSizePixel = 0
    SellIntervalInput.Parent = FishScroll
    shared.corner(SellIntervalInput, UDim.new(0, 4))

    -- Sell Rarity selection (moved from Settings)
    local SellRarityTitle = Instance.new("TextLabel")
    SellRarityTitle.Size = UDim2.new(1, -20, 0, 16)
    SellRarityTitle.Position = UDim2.new(0, 10, 0, 340)
    SellRarityTitle.BackgroundTransparency = 1
    SellRarityTitle.Text = "Sell Rarities:"
    SellRarityTitle.TextColor3 = LYRA.dim
    SellRarityTitle.Font = Enum.Font.Gotham
    SellRarityTitle.TextSize = 10
    SellRarityTitle.TextXAlignment = Enum.TextXAlignment.Left
    SellRarityTitle.Parent = FishScroll

    local allRarities = {"Common", "Uncommon", "Rare", "Epic", "Legend", "Mythic", "Ancient"}
    local SellRarityButtons = {}
    for i, rarity in ipairs(allRarities) do
        local btn = Instance.new("TextButton")
        btn.Text = rarity
        btn.Size = UDim2.new(0, 56, 0, 20)
        btn.Position = UDim2.new(0, 10 + ((i - 1) % 5) * 62, 0, 360 + math.floor((i - 1) / 5) * 26)
        btn.BackgroundColor3 = LYRA.success
        btn.BackgroundTransparency = 0.2
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.BorderSizePixel = 0
        btn.Parent = FishScroll
        shared.corner(btn, UDim.new(0, 5))
        SellRarityButtons[rarity] = btn
    end

    -- Separator 2
    local FishSep2 = Instance.new("Frame")
    FishSep2.Size = UDim2.new(1, -20, 0, 1)
    FishSep2.Position = UDim2.new(0, 10, 0, 418)
    FishSep2.BackgroundColor3 = LYRA.panel2
    FishSep2.BorderSizePixel = 0
    FishSep2.Parent = FishScroll

    -- Fish Caught Stats
    local FishStatsTitle = Instance.new("TextLabel")
    FishStatsTitle.Size = UDim2.new(1, -20, 0, 18)
    FishStatsTitle.Position = UDim2.new(0, 10, 0, 426)
    FishStatsTitle.BackgroundTransparency = 1
    FishStatsTitle.Text = "📊 Catch Stats"
    FishStatsTitle.TextColor3 = LYRA.accentGlow
    FishStatsTitle.Font = Enum.Font.GothamBold
    FishStatsTitle.TextSize = 11
    FishStatsTitle.TextXAlignment = Enum.TextXAlignment.Left
    FishStatsTitle.Parent = FishScroll

    local FishTotalLbl = Instance.new("TextLabel")
    FishTotalLbl.Size = UDim2.new(1, -20, 0, 16)
    FishTotalLbl.Position = UDim2.new(0, 10, 0, 448)
    FishTotalLbl.BackgroundTransparency = 1
    FishTotalLbl.Text = "Total Fish: 0"
    FishTotalLbl.TextColor3 = LYRA.text
    FishTotalLbl.Font = Enum.Font.GothamBold
    FishTotalLbl.TextSize = 11
    FishTotalLbl.TextXAlignment = Enum.TextXAlignment.Left
    FishTotalLbl.Parent = FishScroll

    local FishRarityStats = Instance.new("TextLabel")
    FishRarityStats.Size = UDim2.new(1, -20, 0, 100)
    FishRarityStats.Position = UDim2.new(0, 10, 0, 468)
    FishRarityStats.BackgroundTransparency = 1
    FishRarityStats.TextColor3 = LYRA.dim
    FishRarityStats.Text = "Mythic: 0 | Legend: 0 | Epic: 0\nRare: 0 | Uncommon: 0 | Common: 0"
    FishRarityStats.Font = Enum.Font.Code
    FishRarityStats.TextSize = 10
    FishRarityStats.TextWrapped = true
    FishRarityStats.TextXAlignment = Enum.TextXAlignment.Left
    FishRarityStats.TextYAlignment = Enum.TextYAlignment.Top
    FishRarityStats.Parent = FishScroll

    -- Hidden elements for API compatibility
    local AutoFishCasts = Instance.new("StringValue")
    AutoFishCasts.Value = ""
    local AFPerfStats = Instance.new("Frame")
    AFPerfStats.Visible = false

    -- ═══════════════════════════════════════════
    -- MINING TAB
    -- ═══════════════════════════════════════════
    local MiningScroll = Instance.new("ScrollingFrame")
    MiningScroll.Size = UDim2.new(1, 0, 1, 0)
    MiningScroll.BackgroundTransparency = 1
    MiningScroll.BorderSizePixel = 0
    MiningScroll.ScrollBarThickness = 3
    MiningScroll.CanvasSize = UDim2.new(0, 0, 0, 520)
    MiningScroll.Parent = Tabs.Mining

    local MiningTitle = Instance.new("TextLabel")
    MiningTitle.Size = UDim2.new(1, -100, 0, 16)
    MiningTitle.Position = UDim2.new(0, 10, 0, 8)
    MiningTitle.BackgroundTransparency = 1
    MiningTitle.Text = "⛏ Auto Mining"
    MiningTitle.TextColor3 = LYRA.accentGlow
    MiningTitle.Font = Enum.Font.GothamBold
    MiningTitle.TextSize = 11
    MiningTitle.TextXAlignment = Enum.TextXAlignment.Left
    MiningTitle.Parent = MiningScroll

    local MiningBadge = Instance.new("Frame")
    MiningBadge.Size = UDim2.new(0, 68, 0, 18)
    MiningBadge.Position = UDim2.new(1, -78, 0, 8)
    MiningBadge.BackgroundColor3 = LYRA.panel2
    MiningBadge.BorderSizePixel = 0
    MiningBadge.Parent = MiningScroll
    shared.corner(MiningBadge, UDim.new(0, 9))
    shared.stroke(MiningBadge, LYRA.divider, 1, 0.5)

    local MiningBadgeText = Instance.new("TextLabel")
    MiningBadgeText.Size = UDim2.new(1, 0, 1, 0)
    MiningBadgeText.BackgroundTransparency = 1
    MiningBadgeText.Text = "LIVE"
    MiningBadgeText.TextColor3 = LYRA.accentGlow
    MiningBadgeText.Font = Enum.Font.GothamBold
    MiningBadgeText.TextSize = 9
    MiningBadgeText.Parent = MiningBadge

    -- Buttons (same style as fishing)
    local AutoMineESPBtn = makeActionButton(MiningScroll, "Hotspot ESP: OFF", 34, LYRA.warn)
    local AutoMineTPBtn = makeActionButton(MiningScroll, "Auto TP to Stones: OFF", 68, LYRA.tp)
    local AutoMineToggleBtn = makeActionButton(MiningScroll, "Auto Mine: OFF", 102, LYRA.success)
    local AutoSellOreBtn = makeActionButton(MiningScroll, "Auto Sell Ore: OFF", 136, LYRA.warn)
    local SellOreNowBtn = makeActionButton(MiningScroll, "Sell Ore Now", 170, LYRA.accent)
    local AutoMineHotspotBtn = makeActionButton(MiningScroll, "Hotspot Only: OFF", 204, LYRA.tp)

    -- Status labels
    local AutoMineStatus = Instance.new("TextLabel")
    AutoMineStatus.Size = UDim2.new(1, -20, 0, 18)
    AutoMineStatus.Position = UDim2.new(0, 10, 0, 242)
    AutoMineStatus.BackgroundTransparency = 1
    AutoMineStatus.TextColor3 = LYRA.dim
    AutoMineStatus.Text = "Mine: Idle"
    AutoMineStatus.Font = Enum.Font.GothamBold
    AutoMineStatus.TextSize = 11
    AutoMineStatus.TextXAlignment = Enum.TextXAlignment.Left
    AutoMineStatus.Parent = MiningScroll

    local AutoMineLastOre = Instance.new("TextLabel")
    AutoMineLastOre.Size = UDim2.new(1, -20, 0, 16)
    AutoMineLastOre.Position = UDim2.new(0, 10, 0, 262)
    AutoMineLastOre.BackgroundTransparency = 1
    AutoMineLastOre.TextColor3 = LYRA.dim
    AutoMineLastOre.Text = "Last: —"
    AutoMineLastOre.Font = Enum.Font.Gotham
    AutoMineLastOre.TextSize = 10
    AutoMineLastOre.TextXAlignment = Enum.TextXAlignment.Left
    AutoMineLastOre.Parent = MiningScroll

    -- Separator
    local MineSep1 = Instance.new("Frame")
    MineSep1.Size = UDim2.new(1, -20, 0, 1)
    MineSep1.Position = UDim2.new(0, 10, 0, 286)
    MineSep1.BackgroundColor3 = LYRA.panel2
    MineSep1.BorderSizePixel = 0
    MineSep1.Parent = MiningScroll

    -- Sell interval
    local OreSellIntervalLbl = Instance.new("TextLabel")
    OreSellIntervalLbl.Size = UDim2.new(0, 100, 0, 20)
    OreSellIntervalLbl.Position = UDim2.new(0, 10, 0, 294)
    OreSellIntervalLbl.BackgroundTransparency = 1
    OreSellIntervalLbl.Text = "Sell Interval (s):"
    OreSellIntervalLbl.TextColor3 = LYRA.dim
    OreSellIntervalLbl.Font = Enum.Font.Gotham
    OreSellIntervalLbl.TextSize = 10
    OreSellIntervalLbl.TextXAlignment = Enum.TextXAlignment.Left
    OreSellIntervalLbl.Parent = MiningScroll

    local OreSellIntervalInput = Instance.new("TextBox")
    OreSellIntervalInput.Size = UDim2.new(0, 60, 0, 20)
    OreSellIntervalInput.Position = UDim2.new(0, 112, 0, 294)
    OreSellIntervalInput.BackgroundColor3 = LYRA.bg2
    OreSellIntervalInput.TextColor3 = LYRA.text
    OreSellIntervalInput.Text = "3600"
    OreSellIntervalInput.Font = Enum.Font.Code
    OreSellIntervalInput.TextSize = 10
    OreSellIntervalInput.ClearTextOnFocus = false
    OreSellIntervalInput.BorderSizePixel = 0
    OreSellIntervalInput.Parent = MiningScroll
    shared.corner(OreSellIntervalInput, UDim.new(0, 4))

    -- Sell Rarities
    local OreSellRarityTitle = Instance.new("TextLabel")
    OreSellRarityTitle.Size = UDim2.new(1, -20, 0, 16)
    OreSellRarityTitle.Position = UDim2.new(0, 10, 0, 322)
    OreSellRarityTitle.BackgroundTransparency = 1
    OreSellRarityTitle.Text = "Sell Rarities:"
    OreSellRarityTitle.TextColor3 = LYRA.dim
    OreSellRarityTitle.Font = Enum.Font.Gotham
    OreSellRarityTitle.TextSize = 10
    OreSellRarityTitle.TextXAlignment = Enum.TextXAlignment.Left
    OreSellRarityTitle.Parent = MiningScroll

    local oreRarities = {"Common", "Uncommon", "Rare", "Epic", "Legend", "Mythic", "Ancient"}
    local OreSellRarityButtons = {}
    for i, rarity in ipairs(oreRarities) do
        local btn = Instance.new("TextButton")
        btn.Text = rarity
        btn.Size = UDim2.new(0, 56, 0, 20)
        btn.Position = UDim2.new(0, 10 + ((i - 1) % 5) * 62, 0, 342 + math.floor((i - 1) / 5) * 26)
        btn.BackgroundColor3 = LYRA.success
        btn.BackgroundTransparency = 0.2
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.BorderSizePixel = 0
        btn.Parent = MiningScroll
        shared.corner(btn, UDim.new(0, 5))
        OreSellRarityButtons[rarity] = btn
    end

    -- Separator 2
    local MineSep2 = Instance.new("Frame")
    MineSep2.Size = UDim2.new(1, -20, 0, 1)
    MineSep2.Position = UDim2.new(0, 10, 0, 400)
    MineSep2.BackgroundColor3 = LYRA.panel2
    MineSep2.BorderSizePixel = 0
    MineSep2.Parent = MiningScroll

    -- Mine Stats
    local MineStatsTitle = Instance.new("TextLabel")
    MineStatsTitle.Size = UDim2.new(1, -20, 0, 18)
    MineStatsTitle.Position = UDim2.new(0, 10, 0, 408)
    MineStatsTitle.BackgroundTransparency = 1
    MineStatsTitle.Text = "📊 Mine Stats"
    MineStatsTitle.TextColor3 = LYRA.accentGlow
    MineStatsTitle.Font = Enum.Font.GothamBold
    MineStatsTitle.TextSize = 11
    MineStatsTitle.TextXAlignment = Enum.TextXAlignment.Left
    MineStatsTitle.Parent = MiningScroll

    local MineOreStats = Instance.new("TextLabel")
    MineOreStats.Size = UDim2.new(1, -20, 0, 100)
    MineOreStats.Position = UDim2.new(0, 10, 0, 430)
    MineOreStats.BackgroundTransparency = 1
    MineOreStats.TextColor3 = LYRA.dim
    MineOreStats.Text = "Total Mined: 0"
    MineOreStats.Font = Enum.Font.Code
    MineOreStats.TextSize = 10
    MineOreStats.TextWrapped = true
    MineOreStats.TextXAlignment = Enum.TextXAlignment.Left
    MineOreStats.TextYAlignment = Enum.TextYAlignment.Top
    MineOreStats.Parent = MiningScroll

    -- ═══════════════════════════════════════════
    -- FUN THINGS TAB (Auto Clicker + Auto Gacha)
    -- ═══════════════════════════════════════════
    local FunScroll = Instance.new("ScrollingFrame")
    FunScroll.Size = UDim2.new(1, 0, 1, 0)
    FunScroll.Position = UDim2.new(0, 0, 0, 0)
    FunScroll.BackgroundTransparency = 1
    FunScroll.BorderSizePixel = 0
    FunScroll.ScrollBarThickness = 3
    FunScroll.CanvasSize = UDim2.new(0, 0, 0, 520)
    FunScroll.Parent = Tabs.Fun

    -- ── Auto Clicker Section ──
    local ClickerTitle = Instance.new("TextLabel")
    ClickerTitle.Size = UDim2.new(1, -100, 0, 16)
    ClickerTitle.Position = UDim2.new(0, 10, 0, 8)
    ClickerTitle.BackgroundTransparency = 1
    ClickerTitle.Text = "🖱 Auto Clicker"
    ClickerTitle.TextColor3 = LYRA.accentGlow
    ClickerTitle.Font = Enum.Font.GothamBold
    ClickerTitle.TextSize = 11
    ClickerTitle.TextXAlignment = Enum.TextXAlignment.Left
    ClickerTitle.Parent = FunScroll

    local ClickerBadge = Instance.new("Frame")
    ClickerBadge.Size = UDim2.new(0, 68, 0, 18)
    ClickerBadge.Position = UDim2.new(1, -78, 0, 8)
    ClickerBadge.BackgroundColor3 = LYRA.panel2
    ClickerBadge.BorderSizePixel = 0
    ClickerBadge.Parent = FunScroll
    shared.corner(ClickerBadge, UDim.new(0, 9))
    shared.stroke(ClickerBadge, LYRA.divider, 1, 0.5)

    local ClickerBadgeText = Instance.new("TextLabel")
    ClickerBadgeText.Size = UDim2.new(1, 0, 1, 0)
    ClickerBadgeText.BackgroundTransparency = 1
    ClickerBadgeText.Text = "LIVE"
    ClickerBadgeText.TextColor3 = LYRA.accentGlow
    ClickerBadgeText.Font = Enum.Font.GothamBold
    ClickerBadgeText.TextSize = 9
    ClickerBadgeText.Parent = ClickerBadge

    -- Row: Status + Mode
    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.Size = UDim2.new(0.5, -10, 0, 14)
    StatusLbl.Position = UDim2.new(0, 10, 0, 28)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Text = "Status: OFF"
    StatusLbl.TextColor3 = LYRA.danger
    StatusLbl.Font = Enum.Font.GothamBold
    StatusLbl.TextSize = 10
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    StatusLbl.Parent = FunScroll

    local MethodLbl = Instance.new("TextLabel")
    MethodLbl.Size = UDim2.new(0.5, -10, 0, 14)
    MethodLbl.Position = UDim2.new(0.5, 0, 0, 28)
    MethodLbl.BackgroundTransparency = 1
    MethodLbl.Text = "Mode: Loading..."
    MethodLbl.TextColor3 = LYRA.warn
    MethodLbl.Font = Enum.Font.Gotham
    MethodLbl.TextSize = 10
    MethodLbl.TextXAlignment = Enum.TextXAlignment.Left
    MethodLbl.Parent = FunScroll

    local PosLbl = Instance.new("TextLabel")
    PosLbl.Size = UDim2.new(1, -20, 0, 14)
    PosLbl.Position = UDim2.new(0, 10, 0, 44)
    PosLbl.BackgroundTransparency = 1
    PosLbl.Text = "Target: Not set (press P)"
    PosLbl.TextColor3 = LYRA.dim
    PosLbl.Font = Enum.Font.Gotham
    PosLbl.TextSize = 10
    PosLbl.TextXAlignment = Enum.TextXAlignment.Left
    PosLbl.Parent = FunScroll

    -- CPS slider
    local CPSLbl = Instance.new("TextLabel")
    CPSLbl.Size = UDim2.new(0, 60, 0, 14)
    CPSLbl.Position = UDim2.new(0, 10, 0, 62)
    CPSLbl.BackgroundTransparency = 1
    CPSLbl.Text = "CPS: " .. tostring(config.Clicker.DefaultCPS)
    CPSLbl.TextColor3 = LYRA.text
    CPSLbl.Font = Enum.Font.GothamBold
    CPSLbl.TextSize = 10
    CPSLbl.TextXAlignment = Enum.TextXAlignment.Left
    CPSLbl.Parent = FunScroll

    local SliderTrack = Instance.new("Frame")
    SliderTrack.Size = UDim2.new(1, -90, 0, 6)
    SliderTrack.Position = UDim2.new(0, 70, 0, 66)
    SliderTrack.BackgroundColor3 = LYRA.bg2
    SliderTrack.BorderSizePixel = 0
    SliderTrack.Parent = FunScroll
    shared.corner(SliderTrack, UDim.new(1, 0))

    local ratio = math.clamp(config.Clicker.DefaultCPS / 100, 0, 1)
    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new(ratio, 0, 1, 0)
    SliderFill.BackgroundColor3 = LYRA.accent
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderTrack
    shared.corner(SliderFill, UDim.new(1, 0))

    local SliderKnob = Instance.new("Frame")
    SliderKnob.Size = UDim2.new(0, 14, 0, 14)
    SliderKnob.Position = UDim2.new(ratio, -7, 0.5, -7)
    SliderKnob.BackgroundColor3 = LYRA.accentGlow
    SliderKnob.BorderSizePixel = 0
    SliderKnob.Parent = SliderTrack
    shared.corner(SliderKnob, UDim.new(1, 0))

    -- Start + Keybind buttons (side by side)
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Text = "Start [F]"
    ToggleBtn.Size = UDim2.new(0.55, -14, 0, 28)
    ToggleBtn.Position = UDim2.new(0, 10, 0, 84)
    ToggleBtn.BackgroundColor3 = LYRA.accent
    ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 11
    ToggleBtn.BorderSizePixel = 0
    ToggleBtn.Parent = FunScroll
    shared.corner(ToggleBtn, UDim.new(0, 6))

    local KeybindBtn = Instance.new("TextButton")
    KeybindBtn.Text = "Key: F"
    KeybindBtn.Size = UDim2.new(0.45, -14, 0, 28)
    KeybindBtn.Position = UDim2.new(0.55, 4, 0, 84)
    KeybindBtn.BackgroundColor3 = LYRA.panel2
    KeybindBtn.TextColor3 = LYRA.dim
    KeybindBtn.Font = Enum.Font.Gotham
    KeybindBtn.TextSize = 10
    KeybindBtn.BorderSizePixel = 0
    KeybindBtn.Parent = FunScroll
    shared.corner(KeybindBtn, UDim.new(0, 6))

    -- ── Auto Gacha Section ──
    local GachaSep = Instance.new("Frame")
    GachaSep.Size = UDim2.new(1, -20, 0, 1)
    GachaSep.Position = UDim2.new(0, 10, 0, 122)
    GachaSep.BackgroundColor3 = LYRA.panel2
    GachaSep.BorderSizePixel = 0
    GachaSep.Parent = FunScroll

    local GachaTitle = Instance.new("TextLabel")
    GachaTitle.Size = UDim2.new(1, -20, 0, 18)
    GachaTitle.Position = UDim2.new(0, 10, 0, 130)
    GachaTitle.BackgroundTransparency = 1
    GachaTitle.Text = "🎰 Auto Gacha (10x BlindBox)"
    GachaTitle.TextColor3 = LYRA.accentGlow
    GachaTitle.Font = Enum.Font.GothamBold
    GachaTitle.TextSize = 12
    GachaTitle.TextXAlignment = Enum.TextXAlignment.Left
    GachaTitle.Parent = FunScroll

    local GachaToggleBtn = makeActionButton(FunScroll, "Auto Gacha: OFF", 152, LYRA.accent)

    local GachaStatus = Instance.new("TextLabel")
    GachaStatus.Size = UDim2.new(1, -20, 0, 18)
    GachaStatus.Position = UDim2.new(0, 10, 0, 190)
    GachaStatus.BackgroundTransparency = 1
    GachaStatus.Text = "Status: Idle | Rolls: 0"
    GachaStatus.TextColor3 = LYRA.dim
    GachaStatus.Font = Enum.Font.Gotham
    GachaStatus.TextSize = 11
    GachaStatus.TextXAlignment = Enum.TextXAlignment.Left
    GachaStatus.Parent = FunScroll

    local GachaLastResult = Instance.new("TextLabel")
    GachaLastResult.Size = UDim2.new(1, -20, 0, 18)
    GachaLastResult.Position = UDim2.new(0, 10, 0, 210)
    GachaLastResult.BackgroundTransparency = 1
    GachaLastResult.Text = "Last: -"
    GachaLastResult.TextColor3 = LYRA.dim
    GachaLastResult.Font = Enum.Font.Gotham
    GachaLastResult.TextSize = 11
    GachaLastResult.TextXAlignment = Enum.TextXAlignment.Left
    GachaLastResult.Parent = FunScroll

    -- Box selection (auto-detected from ReplicatedStorage.Content.BlindBox)
    local GachaBoxTitle = Instance.new("TextLabel")
    GachaBoxTitle.Size = UDim2.new(1, -20, 0, 16)
    GachaBoxTitle.Position = UDim2.new(0, 10, 0, 234)
    GachaBoxTitle.BackgroundTransparency = 1
    GachaBoxTitle.Text = "Select Box:"
    GachaBoxTitle.TextColor3 = LYRA.text
    GachaBoxTitle.Font = Enum.Font.GothamBold
    GachaBoxTitle.TextSize = 10
    GachaBoxTitle.TextXAlignment = Enum.TextXAlignment.Left
    GachaBoxTitle.Parent = FunScroll

    -- Read available boxes
    local availableBoxes = {}
    pcall(function()
        local blindBoxFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Content")
        blindBoxFolder = blindBoxFolder and blindBoxFolder:FindFirstChild("BlindBox")
        if blindBoxFolder then
            for _, child in ipairs(blindBoxFolder:GetChildren()) do
                table.insert(availableBoxes, child.Name)
            end
        end
    end)

    local GachaBoxButtons = {}
    local GachaSelectedBox = Instance.new("StringValue")
    GachaSelectedBox.Value = availableBoxes[1] or ""

    for i, boxName in ipairs(availableBoxes) do
        local btn = Instance.new("TextButton")
        btn.Text = boxName
        btn.Size = UDim2.new(0, 90, 0, 22)
        btn.Position = UDim2.new(0, 10 + ((i - 1) % 3) * 96, 0, 254 + math.floor((i - 1) / 3) * 28)
        btn.BackgroundColor3 = (i == 1) and LYRA.accent or LYRA.panel2
        btn.BackgroundTransparency = (i == 1) and 0.2 or 0.6
        btn.TextColor3 = (i == 1) and Color3.new(1, 1, 1) or LYRA.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.BorderSizePixel = 0
        btn.Parent = FunScroll
        shared.corner(btn, UDim.new(0, 6))
        GachaBoxButtons[boxName] = btn
    end

    -- Calculate Y offset based on number of box rows
    local boxRows = math.ceil(#availableBoxes / 3)
    local stopY = 254 + boxRows * 28 + 10

    -- Stop rarity selection
    local GachaStopTitle = Instance.new("TextLabel")
    GachaStopTitle.Size = UDim2.new(1, -20, 0, 16)
    GachaStopTitle.Position = UDim2.new(0, 10, 0, stopY)
    GachaStopTitle.BackgroundTransparency = 1
    GachaStopTitle.Text = "Stop when rarity obtained:"
    GachaStopTitle.TextColor3 = LYRA.text
    GachaStopTitle.Font = Enum.Font.GothamBold
    GachaStopTitle.TextSize = 10
    GachaStopTitle.TextXAlignment = Enum.TextXAlignment.Left
    GachaStopTitle.Parent = FunScroll

    local gachaRarities = {"Common", "Uncommon", "Rare", "Epic", "Legend", "Mythic"}
    local GachaStopButtons = {}
    for i, rarity in ipairs(gachaRarities) do
        local btn = Instance.new("TextButton")
        btn.Text = rarity
        btn.Size = UDim2.new(0, 62, 0, 22)
        btn.Position = UDim2.new(0, 10 + ((i - 1) % 4) * 68, 0, stopY + 20 + math.floor((i - 1) / 4) * 28)
        btn.BackgroundColor3 = LYRA.panel2
        btn.BackgroundTransparency = 0.6
        btn.TextColor3 = LYRA.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.BorderSizePixel = 0
        btn.Parent = FunScroll
        shared.corner(btn, UDim.new(0, 6))
        GachaStopButtons[rarity] = btn
    end

    -- Update canvas size to fit everything
    local shopGachaY = stopY + 100

    -- ── Shop Gacha Section (Pet / Aura / Trail) ──
    local ShopGachaSep = Instance.new("Frame")
    ShopGachaSep.Size = UDim2.new(1, -20, 0, 1)
    ShopGachaSep.Position = UDim2.new(0, 10, 0, stopY + 90)
    ShopGachaSep.BackgroundColor3 = LYRA.panel2
    ShopGachaSep.BorderSizePixel = 0
    ShopGachaSep.Parent = FunScroll

    local ShopGachaTitle = Instance.new("TextLabel")
    ShopGachaTitle.Size = UDim2.new(1, -20, 0, 18)
    ShopGachaTitle.Position = UDim2.new(0, 10, 0, shopGachaY)
    ShopGachaTitle.BackgroundTransparency = 1
    ShopGachaTitle.Text = "🛒 Shop Gacha (10x Roll)"
    ShopGachaTitle.TextColor3 = LYRA.accentGlow
    ShopGachaTitle.Font = Enum.Font.GothamBold
    ShopGachaTitle.TextSize = 12
    ShopGachaTitle.TextXAlignment = Enum.TextXAlignment.Left
    ShopGachaTitle.Parent = FunScroll

    local ShopGachaToggleBtn = makeActionButton(FunScroll, "Shop Gacha: OFF", shopGachaY + 24, LYRA.accent)

    local ShopGachaStatus = Instance.new("TextLabel")
    ShopGachaStatus.Size = UDim2.new(1, -20, 0, 18)
    ShopGachaStatus.Position = UDim2.new(0, 10, 0, shopGachaY + 64)
    ShopGachaStatus.BackgroundTransparency = 1
    ShopGachaStatus.Text = "Status: Idle | Rolls: 0"
    ShopGachaStatus.TextColor3 = LYRA.dim
    ShopGachaStatus.Font = Enum.Font.Gotham
    ShopGachaStatus.TextSize = 11
    ShopGachaStatus.TextXAlignment = Enum.TextXAlignment.Left
    ShopGachaStatus.Parent = FunScroll

    local ShopGachaLastResult = Instance.new("TextLabel")
    ShopGachaLastResult.Size = UDim2.new(1, -20, 0, 18)
    ShopGachaLastResult.Position = UDim2.new(0, 10, 0, shopGachaY + 84)
    ShopGachaLastResult.BackgroundTransparency = 1
    ShopGachaLastResult.Text = "Last: -"
    ShopGachaLastResult.TextColor3 = LYRA.dim
    ShopGachaLastResult.Font = Enum.Font.Gotham
    ShopGachaLastResult.TextSize = 11
    ShopGachaLastResult.TextXAlignment = Enum.TextXAlignment.Left
    ShopGachaLastResult.Parent = FunScroll

    -- Type selection: Pet / Aura / Trail
    local ShopGachaTypeTitle = Instance.new("TextLabel")
    ShopGachaTypeTitle.Size = UDim2.new(1, -20, 0, 16)
    ShopGachaTypeTitle.Position = UDim2.new(0, 10, 0, shopGachaY + 108)
    ShopGachaTypeTitle.BackgroundTransparency = 1
    ShopGachaTypeTitle.Text = "Roll Type:"
    ShopGachaTypeTitle.TextColor3 = LYRA.text
    ShopGachaTypeTitle.Font = Enum.Font.GothamBold
    ShopGachaTypeTitle.TextSize = 10
    ShopGachaTypeTitle.TextXAlignment = Enum.TextXAlignment.Left
    ShopGachaTypeTitle.Parent = FunScroll

    local shopGachaTypes = {"Pet", "Aura", "Trail"}
    local ShopGachaTypeButtons = {}
    for i, typeName in ipairs(shopGachaTypes) do
        local btn = Instance.new("TextButton")
        btn.Text = typeName
        btn.Size = UDim2.new(0, 80, 0, 26)
        btn.Position = UDim2.new(0, 10 + (i - 1) * 88, 0, shopGachaY + 128)
        btn.BackgroundColor3 = (i == 1) and LYRA.accent or LYRA.panel2
        btn.BackgroundTransparency = (i == 1) and 0.2 or 0.6
        btn.TextColor3 = (i == 1) and Color3.new(1, 1, 1) or LYRA.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.Parent = FunScroll
        shared.corner(btn, UDim.new(0, 6))
        ShopGachaTypeButtons[typeName] = btn
    end

    -- Stop rarity selection for shop gacha
    local ShopGachaStopTitle = Instance.new("TextLabel")
    ShopGachaStopTitle.Size = UDim2.new(1, -20, 0, 16)
    ShopGachaStopTitle.Position = UDim2.new(0, 10, 0, shopGachaY + 162)
    ShopGachaStopTitle.BackgroundTransparency = 1
    ShopGachaStopTitle.Text = "Stop when rarity:"
    ShopGachaStopTitle.TextColor3 = LYRA.text
    ShopGachaStopTitle.Font = Enum.Font.GothamBold
    ShopGachaStopTitle.TextSize = 10
    ShopGachaStopTitle.TextXAlignment = Enum.TextXAlignment.Left
    ShopGachaStopTitle.Parent = FunScroll

    local shopGachaRarities = {"Common", "Uncommon", "Rare", "Epic"}
    local ShopGachaStopButtons = {}
    for i, rarity in ipairs(shopGachaRarities) do
        local btn = Instance.new("TextButton")
        btn.Text = rarity
        btn.Size = UDim2.new(0, 62, 0, 22)
        btn.Position = UDim2.new(0, 10 + ((i - 1) % 4) * 68, 0, shopGachaY + 182 + math.floor((i - 1) / 4) * 28)
        btn.BackgroundColor3 = LYRA.panel2
        btn.BackgroundTransparency = 0.6
        btn.TextColor3 = LYRA.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.BorderSizePixel = 0
        btn.Parent = FunScroll
        shared.corner(btn, UDim.new(0, 6))
        ShopGachaStopButtons[rarity] = btn
    end

    -- ── Rod Shop Section ──
    local rodShopY = shopGachaY + 250

    local RodShopSep = Instance.new("Frame")
    RodShopSep.Size = UDim2.new(1, -20, 0, 1)
    RodShopSep.Position = UDim2.new(0, 10, 0, rodShopY - 10)
    RodShopSep.BackgroundColor3 = LYRA.panel2
    RodShopSep.BorderSizePixel = 0
    RodShopSep.Parent = FunScroll

    local RodShopTitle = Instance.new("TextLabel")
    RodShopTitle.Size = UDim2.new(1, -20, 0, 18)
    RodShopTitle.Position = UDim2.new(0, 10, 0, rodShopY)
    RodShopTitle.BackgroundTransparency = 1
    RodShopTitle.Text = "🎣 Buy Rod (Ropiah)"
    RodShopTitle.TextColor3 = LYRA.accentGlow
    RodShopTitle.Font = Enum.Font.GothamBold
    RodShopTitle.TextSize = 12
    RodShopTitle.TextXAlignment = Enum.TextXAlignment.Left
    RodShopTitle.Parent = FunScroll

    -- Search bar
    local RodSearchBox = Instance.new("TextBox")
    RodSearchBox.Size = UDim2.new(1, -20, 0, 22)
    RodSearchBox.Position = UDim2.new(0, 10, 0, rodShopY + 22)
    RodSearchBox.BackgroundColor3 = LYRA.bg2
    RodSearchBox.TextColor3 = LYRA.text
    RodSearchBox.PlaceholderText = "Search rod..."
    RodSearchBox.PlaceholderColor3 = LYRA.dim
    RodSearchBox.Text = ""
    RodSearchBox.Font = Enum.Font.Gotham
    RodSearchBox.TextSize = 10
    RodSearchBox.ClearTextOnFocus = false
    RodSearchBox.BorderSizePixel = 0
    RodSearchBox.Parent = FunScroll
    shared.corner(RodSearchBox, UDim.new(0, 4))

    local RodShopStatus = Instance.new("TextLabel")
    RodShopStatus.Size = UDim2.new(1, -20, 0, 16)
    RodShopStatus.Position = UDim2.new(0, 10, 0, rodShopY + 48)
    RodShopStatus.BackgroundTransparency = 1
    RodShopStatus.Text = ""
    RodShopStatus.TextColor3 = LYRA.dim
    RodShopStatus.Font = Enum.Font.Gotham
    RodShopStatus.TextSize = 10
    RodShopStatus.TextXAlignment = Enum.TextXAlignment.Left
    RodShopStatus.Parent = FunScroll

    -- Scan for rods (exclude gold-only: only include if rod uses script/Ropiah)
    local availableRods = {}
    local rarityOrder = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legend = 5, Mythic = 6}
    pcall(function()
        local toolFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Content")
        toolFolder = toolFolder and toolFolder:FindFirstChild("Tool")
        if toolFolder then
            for _, category in ipairs(toolFolder:GetChildren()) do
                if category:IsA("Folder") then
                    for _, rarity in ipairs(category:GetChildren()) do
                        if rarity:IsA("Folder") then
                            for _, rod in ipairs(rarity:GetChildren()) do
                                if string.find(rod.Name, "Rod$") then
                                    -- Only include rods with positive Ropiah price
                                    local shouldInclude = false
                                    local price = 0
                                    pcall(function()
                                        local data = nil
                                        if rod:IsA("ModuleScript") then
                                            data = require(rod)
                                        else
                                            local ms = rod:FindFirstChildOfClass("ModuleScript")
                                            if ms then data = require(ms) end
                                        end
                                        if not data then data = require(rod) end
                                        if data and type(data) == "table" then
                                            price = tonumber(data.Price) or 0
                                            local goldPrice = tonumber(data.GoldPrice) or 0
                                            -- Include only if price > 0 (buyable with Ropiah)
                                            if price > 0 then
                                                shouldInclude = true
                                            end
                                        end
                                    end)
                                    -- If we couldn't read the data at all, skip it
                                    if shouldInclude then
                                        table.insert(availableRods, {
                                            name = rod.Name,
                                            category = category.Name,
                                            rarity = rarity.Name,
                                            order = rarityOrder[rarity.Name] or 99,
                                            price = price,
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    -- Sort by rarity (highest first)
    table.sort(availableRods, function(a, b) return a.order > b.order end)

    -- Rod list
    local RodListFrame = Instance.new("Frame")
    RodListFrame.Size = UDim2.new(1, -20, 0, 180)
    RodListFrame.Position = UDim2.new(0, 10, 0, rodShopY + 68)
    RodListFrame.BackgroundColor3 = LYRA.bg2
    RodListFrame.BorderSizePixel = 0
    RodListFrame.ClipsDescendants = true
    RodListFrame.Parent = FunScroll
    shared.corner(RodListFrame, UDim.new(0, 6))

    local RodListScroll = Instance.new("ScrollingFrame")
    RodListScroll.Size = UDim2.new(1, 0, 1, 0)
    RodListScroll.BackgroundTransparency = 1
    RodListScroll.BorderSizePixel = 0
    RodListScroll.ScrollBarThickness = 3
    RodListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    RodListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    RodListScroll.Parent = RodListFrame
    Instance.new("UIListLayout", RodListScroll).Padding = UDim.new(0, 2)

    local RodBuyButtons = {}
    local RodRows = {}
    for _, rod in ipairs(availableRods) do
        local row = Instance.new("Frame")
        row.Name = rod.name
        row.Size = UDim2.new(1, -4, 0, 26)
        row.BackgroundColor3 = LYRA.panel2
        row.BackgroundTransparency = 0.5
        row.BorderSizePixel = 0
        row.Parent = RodListScroll
        shared.corner(row, UDim.new(0, 4))

        local displayName = rod.name:gsub("Tool_", ""):gsub("Rod$", "")
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -70, 1, 0)
        lbl.Position = UDim2.new(0, 6, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = displayName .. " [" .. rod.rarity .. "]"
        lbl.TextColor3 = LYRA.text
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Parent = row

        local buyBtn = Instance.new("TextButton")
        buyBtn.Size = UDim2.new(0, 50, 0, 20)
        buyBtn.Position = UDim2.new(1, -54, 0.5, -10)
        buyBtn.BackgroundColor3 = LYRA.accent
        buyBtn.Text = "Buy"
        buyBtn.TextColor3 = Color3.new(1, 1, 1)
        buyBtn.Font = Enum.Font.GothamBold
        buyBtn.TextSize = 9
        buyBtn.BorderSizePixel = 0
        buyBtn.Parent = row
        shared.corner(buyBtn, UDim.new(0, 4))

        RodBuyButtons[rod.name] = buyBtn
        RodRows[rod.name] = row
    end

    -- Final canvas size
    FunScroll.CanvasSize = UDim2.new(0, 0, 0, rodShopY + 68 + 180 + 20)

    -- ═══════════════════════════════════════════
    -- SETTINGS TAB
    -- ═══════════════════════════════════════════
    local SettingsScroll = Instance.new("ScrollingFrame")
    SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
    SettingsScroll.Position = UDim2.new(0, 0, 0, 0)
    SettingsScroll.BackgroundTransparency = 1
    SettingsScroll.BorderSizePixel = 0
    SettingsScroll.ScrollBarThickness = 3
    SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 680)
    SettingsScroll.Parent = Tabs.Settings

    local HideKeyLbl = Instance.new("TextLabel")
    HideKeyLbl.Size = UDim2.new(1, -20, 0, 22)
    HideKeyLbl.Position = UDim2.new(0, 10, 0, 10)
    HideKeyLbl.BackgroundTransparency = 1
    HideKeyLbl.Text = "Hide/Show UI: " .. tostring(config.Keys.HideUI):gsub("Enum.KeyCode.", "")
    HideKeyLbl.TextColor3 = LYRA.text
    HideKeyLbl.Font = Enum.Font.GothamBold
    HideKeyLbl.TextSize = 12
    HideKeyLbl.TextXAlignment = Enum.TextXAlignment.Left
    HideKeyLbl.Parent = SettingsScroll

    -- ──── Hotkeys Customization ────
    local HotkeysTitle = Instance.new("TextLabel")
    HotkeysTitle.Size = UDim2.new(1, -20, 0, 18)
    HotkeysTitle.Position = UDim2.new(0, 10, 0, 38)
    HotkeysTitle.BackgroundTransparency = 1
    HotkeysTitle.Text = "🔑 Hotkeys"
    HotkeysTitle.TextColor3 = LYRA.accentGlow
    HotkeysTitle.Font = Enum.Font.GothamBold
    HotkeysTitle.TextSize = 13
    HotkeysTitle.TextXAlignment = Enum.TextXAlignment.Left
    HotkeysTitle.Parent = SettingsScroll

    local function makeHotkeyRow(label, y, default)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, -10, 0, 14)
        lbl.Position = UDim2.new(0, 10, 0, y)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = LYRA.dim
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = SettingsScroll

        local keybind = components.keybind({
            Parent = SettingsScroll,
            Size = UDim2.fromOffset(70, 22),
            Position = UDim2.new(1, -80, 0, y - 2),
            Default = default,
        })
        return keybind
    end

    local hideUIKey = makeHotkeyRow("Toggle UI", 58, tostring(config.Keys.HideUI):gsub("Enum.KeyCode.", "") or "K")
    local espKey = makeHotkeyRow("Toggle ESP", 76, config.Keys.ESP or "E")
    local tpKey = makeHotkeyRow("Teleport", 94, config.Keys.Teleport or "T")

    local UnloadBtn = makeActionButton(SettingsScroll, "Unload Script", 120, LYRA.danger)
    local AutoClaimDailyRewardBtn = makeActionButton(SettingsScroll, "Auto Claim Daily Reward: OFF", 160, LYRA.accent)
    local AutoClaimSessionRewardBtn = makeActionButton(SettingsScroll, "Auto Claim Session Reward: OFF", 200, LYRA.tp)
    -- Anti Idle (Roblox platform 20-min disconnect) and Anti AFK (the game's
    -- own "Still There?" prompt) share a row to avoid shifting the layout.
    local AntiIdleBtn = makeActionButton(SettingsScroll, "Anti Idle: OFF", 240, LYRA.warn)
    AntiIdleBtn.Size = UDim2.new(0.48, -10, 0, 30)
    AntiIdleBtn.Position = UDim2.new(0, 10, 0, 240)

    local AntiAfkBtn = makeActionButton(SettingsScroll, "Anti AFK: OFF", 240, LYRA.warn)
    AntiAfkBtn.Size = UDim2.new(0.48, -10, 0, 30)
    AntiAfkBtn.Position = UDim2.new(0.5, 5, 0, 240)

    -- ── Webhook Section ──
    local WebhookSep = Instance.new("Frame")
    WebhookSep.Size = UDim2.new(1, -20, 0, 1)
    WebhookSep.Position = UDim2.new(0, 10, 0, 280)
    WebhookSep.BackgroundColor3 = LYRA.panel2
    WebhookSep.BorderSizePixel = 0
    WebhookSep.Parent = SettingsScroll

    local WebhookTitle = Instance.new("TextLabel")
    WebhookTitle.Size = UDim2.new(1, -20, 0, 18)
    WebhookTitle.Position = UDim2.new(0, 10, 0, 288)
    WebhookTitle.BackgroundTransparency = 1
    WebhookTitle.Text = "Webhook (Fish Caught)"
    WebhookTitle.TextColor3 = LYRA.text
    WebhookTitle.Font = Enum.Font.GothamBold
    WebhookTitle.TextSize = 11
    WebhookTitle.TextXAlignment = Enum.TextXAlignment.Left
    WebhookTitle.Parent = SettingsScroll

    local WebhookURLLabel = Instance.new("TextLabel")
    WebhookURLLabel.Size = UDim2.new(0, 34, 0, 22)
    WebhookURLLabel.Position = UDim2.new(0, 10, 0, 310)
    WebhookURLLabel.BackgroundTransparency = 1
    WebhookURLLabel.Text = "URL:"
    WebhookURLLabel.TextColor3 = LYRA.dim
    WebhookURLLabel.Font = Enum.Font.Gotham
    WebhookURLLabel.TextSize = 10
    WebhookURLLabel.TextXAlignment = Enum.TextXAlignment.Left
    WebhookURLLabel.Parent = SettingsScroll

    local WebhookInput = Instance.new("TextBox")
    WebhookInput.Size = UDim2.new(1, -60, 0, 22)
    WebhookInput.Position = UDim2.new(0, 46, 0, 310)
    WebhookInput.BackgroundColor3 = LYRA.bg2
    WebhookInput.TextColor3 = LYRA.text
    WebhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
    WebhookInput.PlaceholderColor3 = LYRA.dim
    WebhookInput.Text = config.Webhook and config.Webhook.URL or ""
    WebhookInput.Font = Enum.Font.Code
    WebhookInput.TextSize = 9
    WebhookInput.TextXAlignment = Enum.TextXAlignment.Left
    WebhookInput.ClearTextOnFocus = false
    WebhookInput.BorderSizePixel = 0
    WebhookInput.ClipsDescendants = true
    WebhookInput.Parent = SettingsScroll
    shared.corner(WebhookInput, UDim.new(0, 4))
    local WebhookInputPad = Instance.new("UIPadding", WebhookInput)
    WebhookInputPad.PaddingLeft = UDim.new(0, 6)

    -- Webhook rarity filter
    local WebhookRarityTitle = Instance.new("TextLabel")
    WebhookRarityTitle.Size = UDim2.new(1, -20, 0, 16)
    WebhookRarityTitle.Position = UDim2.new(0, 10, 0, 338)
    WebhookRarityTitle.BackgroundTransparency = 1
    WebhookRarityTitle.Text = "Log Rarities (tap to toggle)"
    WebhookRarityTitle.TextColor3 = LYRA.dim
    WebhookRarityTitle.Font = Enum.Font.Gotham
    WebhookRarityTitle.TextSize = 10
    WebhookRarityTitle.TextXAlignment = Enum.TextXAlignment.Left
    WebhookRarityTitle.Parent = SettingsScroll

    local WebhookRarityButtons = {}
    for i, rarity in ipairs(allRarities) do
        local btn = Instance.new("TextButton")
        btn.Text = rarity
        btn.Size = UDim2.new(0, 62, 0, 22)
        btn.Position = UDim2.new(0, 10 + ((i - 1) % 4) * 68, 0, 358 + math.floor((i - 1) / 4) * 28)
        btn.BackgroundColor3 = LYRA.panel2
        btn.BackgroundTransparency = 0.4
        btn.TextColor3 = LYRA.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.BorderSizePixel = 0
        btn.Parent = SettingsScroll
        shared.corner(btn, UDim.new(0, 6))
        WebhookRarityButtons[rarity] = btn
    end

    -- Buttons row: Toggle + Test + Save
    local WebhookToggleBtn = makeActionButton(SettingsScroll, "Webhook: OFF", 420, LYRA.panel2)
    WebhookToggleBtn.Size = UDim2.new(0.48, -10, 0, 28)
    WebhookToggleBtn.Position = UDim2.new(0, 10, 0, 420)

    local WebhookTestBtn = makeActionButton(SettingsScroll, "Test Webhook", 420, LYRA.warn)
    WebhookTestBtn.Size = UDim2.new(0.48, -10, 0, 28)
    WebhookTestBtn.Position = UDim2.new(0.5, 5, 0, 420)

    local SaveSettingsBtn = makeActionButton(SettingsScroll, "Save All Settings", 458, LYRA.success)
    SaveSettingsBtn.Size = UDim2.new(0.48, -10, 0, 30)
    SaveSettingsBtn.Position = UDim2.new(0, 10, 0, 458)

    local LoadSettingsBtn = makeActionButton(SettingsScroll, "Load Config", 458, LYRA.tp)
    LoadSettingsBtn.Size = UDim2.new(0.48, -10, 0, 30)
    LoadSettingsBtn.Position = UDim2.new(0.5, 5, 0, 458)

    local SaveStatus = Instance.new("TextLabel")
    SaveStatus.Size = UDim2.new(1, -20, 0, 18)
    SaveStatus.Position = UDim2.new(0, 10, 0, 450)
    SaveStatus.BackgroundTransparency = 1
    SaveStatus.Text = ""
    SaveStatus.TextColor3 = LYRA.success
    SaveStatus.Font = Enum.Font.Gotham
    SaveStatus.TextSize = 10
    SaveStatus.TextXAlignment = Enum.TextXAlignment.Left
    SaveStatus.Parent = SettingsScroll

    -- ── Theme section (Dark / Light) ──
    local ThemeSep = Instance.new("Frame")
    ThemeSep.Size = UDim2.new(1, -20, 0, 1)
    ThemeSep.Position = UDim2.new(0, 10, 0, 554)
    ThemeSep.BackgroundColor3 = LYRA.panel2
    ThemeSep.BorderSizePixel = 0
    ThemeSep.Parent = SettingsScroll

    local ColorTitle = Instance.new("TextLabel")
    ColorTitle.Size = UDim2.new(1, -20, 0, 18)
    ColorTitle.Position = UDim2.new(0, 10, 0, 562)
    ColorTitle.BackgroundTransparency = 1
    ColorTitle.Text = "Theme"
    ColorTitle.TextColor3 = LYRA.text
    ColorTitle.Font = Enum.Font.GothamBold
    ColorTitle.TextSize = 11
    ColorTitle.TextXAlignment = Enum.TextXAlignment.Left
    ColorTitle.Parent = SettingsScroll

    local AccentPreview = Instance.new("Frame")
    AccentPreview.Size = UDim2.new(0, 18, 0, 18)
    AccentPreview.Position = UDim2.new(1, -30, 0, 562)
    AccentPreview.BackgroundColor3 = LYRA.accent
    AccentPreview.BorderSizePixel = 0
    AccentPreview.Parent = SettingsScroll
    shared.corner(AccentPreview, UDim.new(0, 4))

    local DarkThemeBtn = Instance.new("TextButton")
    DarkThemeBtn.Text = "Dark (Lyra)"
    DarkThemeBtn.Size = UDim2.new(0.48, -10, 0, 28)
    DarkThemeBtn.Position = UDim2.new(0, 10, 0, 586)
    DarkThemeBtn.BackgroundColor3 = LYRA.accent
    DarkThemeBtn.TextColor3 = Color3.new(1, 1, 1)
    DarkThemeBtn.Font = Enum.Font.GothamBold
    DarkThemeBtn.TextSize = 11
    DarkThemeBtn.BorderSizePixel = 0
    DarkThemeBtn.Parent = SettingsScroll
    shared.corner(DarkThemeBtn, UDim.new(0, 6))

    local LightThemeBtn = Instance.new("TextButton")
    LightThemeBtn.Text = "Light (Lyra)"
    LightThemeBtn.Size = UDim2.new(0.48, -10, 0, 28)
    LightThemeBtn.Position = UDim2.new(0.5, 5, 0, 586)
    LightThemeBtn.BackgroundColor3 = LYRA.panel2
    LightThemeBtn.TextColor3 = LYRA.dim
    LightThemeBtn.Font = Enum.Font.GothamBold
    LightThemeBtn.TextSize = 11
    LightThemeBtn.BorderSizePixel = 0
    LightThemeBtn.Parent = SettingsScroll
    shared.corner(LightThemeBtn, UDim.new(0, 6))

    local ColorButtons = {}

    local SettingsInfo = Instance.new("TextLabel")
    SettingsInfo.Size = UDim2.new(1, -20, 0, 30)
    SettingsInfo.Position = UDim2.new(0, 10, 0, 624)
    SettingsInfo.BackgroundTransparency = 1
    SettingsInfo.Text = "Settings are saved locally and auto-loaded on next run."
    SettingsInfo.TextColor3 = LYRA.dim
    SettingsInfo.Font = Enum.Font.Gotham
    SettingsInfo.TextSize = 11
    SettingsInfo.TextWrapped = true
    SettingsInfo.TextXAlignment = Enum.TextXAlignment.Left
    SettingsInfo.TextYAlignment = Enum.TextYAlignment.Top
    SettingsInfo.Parent = SettingsScroll

    -- ═══════════════════════════════════════════
    -- LOGS TAB
    -- ═══════════════════════════════════════════
    local LogScroll = Instance.new("ScrollingFrame")
    LogScroll.Size = UDim2.new(1, -20, 1, -50)
    LogScroll.Position = UDim2.new(0, 10, 0, 10)
    LogScroll.BackgroundColor3 = LYRA.bg2
    LogScroll.BorderSizePixel = 0
    LogScroll.ScrollBarThickness = 3
    LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogScroll.Parent = Tabs.Logs
    shared.corner(LogScroll, UDim.new(0, 8))
    Instance.new("UIListLayout", LogScroll).Padding = UDim.new(0, 2)

    local ClearLogsBtn = Instance.new("TextButton")
    ClearLogsBtn.Text = "Clear Logs"
    ClearLogsBtn.Size = UDim2.new(0, 100, 0, 26)
    ClearLogsBtn.Position = UDim2.new(1, -110, 1, -36)
    ClearLogsBtn.BackgroundColor3 = LYRA.danger
    ClearLogsBtn.TextColor3 = Color3.new(1, 1, 1)
    ClearLogsBtn.Font = Enum.Font.GothamBold
    ClearLogsBtn.TextSize = 11
    ClearLogsBtn.BorderSizePixel = 0
    ClearLogsBtn.Parent = Tabs.Logs
    shared.corner(ClearLogsBtn, UDim.new(0, 6))

    local LogCount = Instance.new("TextLabel")
    LogCount.Size = UDim2.new(0, 200, 0, 26)
    LogCount.Position = UDim2.new(0, 10, 1, -36)
    LogCount.BackgroundTransparency = 1
    LogCount.Text = "0 entries"
    LogCount.TextColor3 = LYRA.dim
    LogCount.Font = Enum.Font.Gotham
    LogCount.TextSize = 10
    LogCount.TextXAlignment = Enum.TextXAlignment.Left
    LogCount.Parent = Tabs.Logs

    -- ═══════════════════════════════════════════
    -- RETURN TABLE (API contract preserved)
    -- ═══════════════════════════════════════════
    return {
        Theme = LYRA,
        Toast = components.toast, -- kit toast component (gui.Toast.show({ Text=..., Variant=... }))
        MainGui = ScreenGui,
        Main = Main,
        MainShadow = MainShadow,
        Header = Header,
        HeaderMask = HeaderMask,
        MainStroke = MainStroke,
        Content = Content,
        ContentStroke = ContentStroke,
        TabsBar = TabsBar,
        DragBar = DragBar,
        DragHit = DragHit,
        MinimizedOrb = MinimizedOrb,
        Title = Title,
        Subtitle = Subtitle,
        MinBtn = MinBtn,
        CloseBtn = CloseBtn,
        TabButtons = TabButtons,
        Tabs = Tabs,
        About = {
            CopySaweriaBtn = CopySaweriaBtn,
            DashEarnings = DashEarnings,
            DashSessionTime = DashSessionTime,
            DashActions = DashActions,
        },
        Players = {
            SearchBox = SearchBox,
            PlayerList = PlayerList,
            PlayerHint = PlayerHint,
        },
        FishZone = {
            ZoneESPBtn = ZoneESPBtn,
            AutoTPBtn = AutoTPBtn,
            RefreshCharBtn = RefreshCharBtn,
            AutoSellBtn = AutoSellBtn,
            SellNowBtn = SellNowBtn,
            ZoneStatus = ZoneStatus,
            SellIntervalInput = SellIntervalInput,
            SellRarityButtons = SellRarityButtons,
            FishTotalLbl = FishTotalLbl,
            FishRarityStats = FishRarityStats,
        },
        AutoFish = {
            ToggleBtn = AutoFishToggleBtn,
            Status = AutoFishStatus,
            Casts = AutoFishCasts,
            LastCatch = AutoFishLastCatch,
            PerfStats = AFPerfStats,
        },
        Clicker = {
            StatusLbl = StatusLbl,
            PosLbl = PosLbl,
            MethodLbl = MethodLbl,
            CPSLbl = CPSLbl,
            SliderTrack = SliderTrack,
            SliderFill = SliderFill,
            SliderKnob = SliderKnob,
            ToggleBtn = ToggleBtn,
            KeybindBtn = KeybindBtn,
        },
        Gacha = {
            ToggleBtn = GachaToggleBtn,
            Status = GachaStatus,
            LastResult = GachaLastResult,
            StopButtons = GachaStopButtons,
            BoxButtons = GachaBoxButtons,
            SelectedBox = GachaSelectedBox,
        },
        ShopGacha = {
            ToggleBtn = ShopGachaToggleBtn,
            Status = ShopGachaStatus,
            LastResult = ShopGachaLastResult,
            TypeButtons = ShopGachaTypeButtons,
            StopButtons = ShopGachaStopButtons,
        },
        RodShop = {
            BuyButtons = RodBuyButtons,
            RodRows = RodRows,
            Status = RodShopStatus,
            SearchBox = RodSearchBox,
        },
        Mining = {
            ToggleBtn = AutoMineToggleBtn,
            Status = AutoMineStatus,
            LastOre = AutoMineLastOre,
            HotspotBtn = AutoMineHotspotBtn,
            TPBtn = AutoMineTPBtn,
            ESPBtn = AutoMineESPBtn,
            OreStats = MineOreStats,
            AutoSellBtn = AutoSellOreBtn,
            SellNowBtn = SellOreNowBtn,
            SellIntervalInput = OreSellIntervalInput,
            SellRarityButtons = OreSellRarityButtons,
        },
        Settings = {
            HideKeyLbl = HideKeyLbl,
            HideUIKeybind = hideUIKey,
            ESPKeybind = espKey,
            TPKeybind = tpKey,
            UnloadBtn = UnloadBtn,
            AutoClaimDailyRewardBtn = AutoClaimDailyRewardBtn,
            AutoClaimSessionRewardBtn = AutoClaimSessionRewardBtn,
            AntiIdleBtn = AntiIdleBtn,
            AntiAfkBtn = AntiAfkBtn,
            WebhookInput = WebhookInput,
            WebhookToggleBtn = WebhookToggleBtn,
            WebhookTestBtn = WebhookTestBtn,
            WebhookRarityButtons = WebhookRarityButtons,
            SaveSettingsBtn = SaveSettingsBtn,
            LoadSettingsBtn = LoadSettingsBtn,
            SaveStatus = SaveStatus,
            ColorTitle = ColorTitle,
            AccentPreview = AccentPreview,
            ColorButtons = ColorButtons,
            DarkThemeBtn = DarkThemeBtn,
            LightThemeBtn = LightThemeBtn,
            SettingsInfo = SettingsInfo,
        },
        Logs = {
            LogScroll = LogScroll,
            ClearLogsBtn = ClearLogsBtn,
            LogCount = LogCount,
        },
    }
end
