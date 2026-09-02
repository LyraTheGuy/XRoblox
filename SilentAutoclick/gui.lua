-- SilentAutoclick/gui.lua
-- Single-page scrollable layout — all features visible at once, no tabs
return function(config, components)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    local shared = components.shared
    local THEME = config.Theme
    local W, H = config.Window.Size.X, config.Window.Size.Y

    if _G.__SilentAutoclick_Destroy then
        pcall(_G.__SilentAutoclick_Destroy)
    end
    _G.__SilentAutoclick_Destroy = nil

    local view = {}
    local CPAD = 12

    -- ═══════════════════════════════════════════
    -- SCREEN GUI
    -- ═══════════════════════════════════════════
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SilentHub_GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then ScreenGui.Parent = lp:WaitForChild("PlayerGui") end
    view.ScreenGui = ScreenGui

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

    local Shadow = shared.shadow(Main, { ExtendX = 10, ExtendY = 10, Transparency = 0.72, OffsetY = 0 })
    view.Shadow = Shadow

    -- ═══════════════════════════════════════════
    -- TOP BAR (fixed)
    -- ═══════════════════════════════════════════
    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BackgroundColor3 = THEME.bg2
    TopBar.BorderSizePixel = 0
    TopBar.ZIndex = 3
    TopBar.Parent = Main

    local logo = Instance.new("Frame")
    logo.Size = UDim2.fromOffset(8, 8)
    logo.Position = UDim2.fromOffset(14, 16)
    logo.BackgroundColor3 = THEME.accent
    logo.BorderSizePixel = 0
    logo.Parent = TopBar
    shared.corner(logo, UDim.new(1, 0))
    shared.glow(logo, THEME.glow, 2, 0.55)

    local TopTitle = Instance.new("TextLabel")
    TopTitle.Text = config.Window.Title
    TopTitle.Size = UDim2.fromOffset(200, 16)
    TopTitle.Position = UDim2.fromOffset(28, 10)
    TopTitle.BackgroundTransparency = 1
    TopTitle.TextColor3 = THEME.accent2
    TopTitle.Font = Enum.Font.GothamBold
    TopTitle.TextSize = 13
    TopTitle.TextXAlignment = Enum.TextXAlignment.Left
    TopTitle.ZIndex = 4
    TopTitle.Parent = TopBar

    local TopSub = Instance.new("TextLabel")
    TopSub.Text = string.upper(config.Window.Subtitle)
    TopSub.Size = UDim2.fromOffset(250, 10)
    TopSub.Position = UDim2.fromOffset(28, 26)
    TopSub.BackgroundTransparency = 1
    TopSub.TextColor3 = THEME.faint
    TopSub.Font = Enum.Font.GothamBold
    TopSub.TextSize = 7
    TopSub.TextXAlignment = Enum.TextXAlignment.Left
    TopSub.ZIndex = 4
    TopSub.Parent = TopBar

    local minBtn = components.button({
        Parent = Main, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -68, 0, 8),
        Text = "—", TextSize = 12, Color = THEME.panel2, TextColor = THEME.text,
        HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 7), ZIndex = 4, Glow = false,
    })
    local closeBtn = components.button({
        Parent = Main, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -38, 0, 8),
        Text = "✕", TextSize = 11, Color = Color3.fromRGB(64, 28, 34), TextColor = THEME.danger,
        HoverColor = Color3.fromRGB(96, 38, 46), CornerRadius = UDim.new(0, 7), ZIndex = 4, Glow = false,
    })
    view.MinBtn = minBtn.Instance
    view.CloseBtn = closeBtn.Instance

    local DragHit = Instance.new("TextButton")
    DragHit.Size = UDim2.new(1, 0, 0, 40)
    DragHit.BackgroundTransparency = 1
    DragHit.Text = ""
    DragHit.AutoButtonColor = false
    DragHit.BorderSizePixel = 0
    DragHit.ZIndex = 3
    DragHit.Parent = Main
    view.DragHit = DragHit

    -- ═══════════════════════════════════════════
    -- SCROLLABLE CONTENT (single page)
    -- ═══════════════════════════════════════════
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "Content"
    scrollFrame.Size = UDim2.new(1, -(CPAD * 2), 1, -48)
    scrollFrame.Position = UDim2.new(0, CPAD, 0, 44)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = THEME.accent
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.ZIndex = 2
    scrollFrame.Parent = Main
    view.Content = scrollFrame

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = scrollFrame

    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingTop = UDim.new(0, 4)
    contentPadding.PaddingBottom = UDim.new(0, 8)
    contentPadding.Parent = scrollFrame

    -- ═══════════════════════════════════════════
    -- SECTION HELPER
    -- ═══════════════════════════════════════════
    local sectionOrder = 0
    local function makeSection(title)
        sectionOrder = sectionOrder + 1
        local section = Instance.new("Frame")
        section.Size = UDim2.new(1, 0, 0, 0)
        section.AutomaticSize = Enum.AutomaticSize.Y
        section.BackgroundColor3 = THEME.panel
        section.BackgroundTransparency = 0.35
        section.BorderSizePixel = 0
        section.LayoutOrder = sectionOrder
        section.ZIndex = 3
        section.Parent = scrollFrame
        shared.corner(section, UDim.new(0, 8))
        shared.stroke(section, THEME.divider, 1, 0.5)

        local lbl = Instance.new("TextLabel")
        lbl.Text = title
        lbl.Size = UDim2.new(1, -16, 0, 22)
        lbl.Position = UDim2.new(0, 8, 0, 4)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = THEME.accent
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 4
        lbl.Parent = section

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 4)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = section

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 26)
        pad.PaddingBottom = UDim.new(0, 6)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        pad.Parent = section

        return section
    end

    local function makeRow(parent, order)
        sectionOrder = sectionOrder + 1
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order or sectionOrder
        row.ZIndex = 4
        row.Parent = parent
        return row
    end

    local function makeLabel(parent, text, color, order)
        sectionOrder = sectionOrder + 1
        local lbl = Instance.new("TextLabel")
        lbl.Text = text
        lbl.Size = UDim2.new(1, 0, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or THEME.dim
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order or sectionOrder
        lbl.ZIndex = 4
        lbl.Parent = parent
        return lbl
    end

    local function makeToggle(parent, text, default, order)
        sectionOrder = sectionOrder + 1
        local btn = Instance.new("TextButton")
        btn.Text = text .. ": OFF"
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.BackgroundColor3 = THEME.panel2
        btn.TextColor3 = THEME.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        btn.LayoutOrder = order or sectionOrder
        btn.AutoButtonColor = false
        btn.ZIndex = 4
        btn.Parent = parent
        shared.corner(btn, UDim.new(0, 6))

        local state = default or false
        if state then
            btn.Text = text .. ": ON"
            btn.BackgroundColor3 = THEME.success
            btn.TextColor3 = Color3.new(1, 1, 1)
        end

        return btn, function()
            state = not state
            if state then
                btn.Text = text .. ": ON"
                btn.BackgroundColor3 = THEME.success
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                btn.Text = text .. ": OFF"
                btn.BackgroundColor3 = THEME.panel2
                btn.TextColor3 = THEME.dim
            end
            return state
        end
    end

    local function makeActionButton(parent, text, color, order)
        sectionOrder = sectionOrder + 1
        local btn = Instance.new("TextButton")
        btn.Text = text
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.BackgroundColor3 = color or THEME.accent
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        btn.LayoutOrder = order or sectionOrder
        btn.AutoButtonColor = false
        btn.ZIndex = 4
        btn.Parent = parent
        shared.corner(btn, UDim.new(0, 6))
        return btn
    end

    -- ═══════════════════════════════════════════
    -- SECTION 1: AUTO CLICKER
    -- ═══════════════════════════════════════════
    local clickerSection = makeSection("● Auto Clicker")

    local StatusLbl = makeLabel(clickerSection, "Status: OFF", THEME.danger, 1)
    view.StatusLbl = StatusLbl

    local MethodLbl = makeLabel(clickerSection, "Mode: -", THEME.warn, 2)
    view.MethodLbl = MethodLbl

    local ModeDropdown = components.dropdown({
        Parent = clickerSection,
        Size = UDim2.new(1, 0, 0, 28),
        Items = { "Follow Cursor", "Fixed Position" }, Default = "Follow Cursor", ItemHeight = 28,
        LayoutOrder = 3,
    })
    view.ModeDropdown = ModeDropdown

    local PosLbl = makeLabel(clickerSection, "Target: Not set (press P)", THEME.dim, 4)
    PosLbl.Visible = false
    view.PosLbl = PosLbl

    local ToggleBtn = components.button({
        Parent = clickerSection, Size = UDim2.new(1, 0, 0, 32),
        Text = "Start [F]", TextSize = 11, Color = THEME.accent, HoverColor = THEME.accent2, Glow = false,
        LayoutOrder = 5,
    })
    view.ToggleBtn = ToggleBtn

    local KeybindBtn = components.keybind({
        Parent = clickerSection, Size = UDim2.new(1, 0, 0, 28),
        Default = config.Keys.ToggleClicker, LayoutOrder = 6,
    })
    view.KeybindBtn = KeybindBtn

    -- ═══════════════════════════════════════════
    -- SECTION 2: CLICK TIMING
    -- ═══════════════════════════════════════════
    local timingSection = makeSection("◎ Click Timing")

    local IntervalLbl = makeLabel(timingSection, "Delay: 1.00s / click", THEME.accent2, 1)
    view.IntervalLbl = IntervalLbl

    local TimingInput = components.textinput({
        Parent = timingSection, Size = UDim2.new(1, 0, 0, 28),
        Default = tostring(config.Clicker.IntervalSeconds or 1), Placeholder = "1-360s",
        LayoutOrder = 2,
    })
    view.TimingInput = TimingInput

    local ResetTimingBtn = components.button({
        Parent = timingSection, Size = UDim2.new(1, 0, 0, 24),
        Text = "Reset to Default", TextSize = 9, Color = THEME.panel2, TextColor = THEME.text,
        HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 6), Glow = false, LayoutOrder = 3,
    })
    view.ResetTimingBtn = ResetTimingBtn

    local TimingStatus = makeLabel(timingSection, "Range: 1s - 360s", THEME.dim, 4)
    view.TimingStatus = TimingStatus

    local CPSLbl = makeLabel(timingSection, "CPS: 20", THEME.text, 5)
    view.CPSLbl = CPSLbl

    local CPSSlider = components.slider({
        Parent = timingSection, Size = UDim2.new(1, 0, 0, 6),
        Default = config.Clicker.DefaultCPS / 100, LayoutOrder = 6,
    })
    view.CPSSlider = CPSSlider

    -- CPS Presets
    local PresetsRow = Instance.new("Frame")
    PresetsRow.Size = UDim2.new(1, 0, 0, 22)
    PresetsRow.BackgroundTransparency = 1
    PresetsRow.LayoutOrder = 7
    PresetsRow.ZIndex = 4
    PresetsRow.Parent = timingSection
    local presetsLayout = Instance.new("UIListLayout")
    presetsLayout.FillDirection = Enum.FillDirection.Horizontal
    presetsLayout.Padding = UDim.new(0, 4)
    presetsLayout.Parent = PresetsRow

    local presetBtns = {}
    for _, cps in ipairs({ 5, 10, 20, 50, 100 }) do
        local btn = components.button({
            Parent = PresetsRow, Size = UDim2.new(0, 50, 0, 22),
            Text = tostring(cps), TextSize = 9, Color = THEME.panel2, TextColor = THEME.dim,
            HoverColor = THEME.accent2, CornerRadius = UDim.new(0, 5), Glow = false,
        })
        presetBtns[cps] = btn.Instance
    end
    view.CPSPresetBtns = presetBtns

    -- ═══════════════════════════════════════════
    -- SECTION 3: MOVEMENT
    -- ═══════════════════════════════════════════
    local moveSection = makeSection("🏃 Movement")

    local flyToggle, toggleFly = makeToggle(moveSection, "Fly", false, 1)
    local flySpeedLabel = makeLabel(moveSection, "Fly Speed: 50", THEME.dim, 2)
    local noclipToggle, toggleNoClip = makeToggle(moveSection, "NoClip", false, 3)
    local infJumpToggle, toggleInfJump = makeToggle(moveSection, "Infinite Jump", false, 4)
    local speedLabel = makeLabel(moveSection, "Walk Speed: 16", THEME.dim, 5)

    view.FlyToggle = { btn = flyToggle, toggle = toggleFly }
    view.FlySpeedLabel = flySpeedLabel
    view.NoClipToggle = { btn = noclipToggle, toggle = toggleNoClip }
    view.InfJumpToggle = { btn = infJumpToggle, toggle = toggleInfJump }
    view.SpeedLabel = speedLabel

    -- ═══════════════════════════════════════════
    -- SECTION 4: UTILITY
    -- ═══════════════════════════════════════════
    local utilitySection = makeSection("🛡️ Utility")

    local antiAfkToggle, toggleAntiAfk = makeToggle(utilitySection, "Anti AFK", true, 1)
    local antiPauseToggle, toggleAntiPause = makeToggle(utilitySection, "Anti Gameplay Pause", true, 2)

    view.AntiAfkToggle = { btn = antiAfkToggle, toggle = toggleAntiAfk }
    view.AntiPauseToggle = { btn = antiPauseToggle, toggle = toggleAntiPause }

    -- Persistence
    local saveBtn = makeActionButton(utilitySection, "Save Settings", THEME.success, 3)
    local loadBtn = makeActionButton(utilitySection, "Load Settings", THEME.accent, 4)
    local resetBtn = makeActionButton(utilitySection, "Reset to Defaults", THEME.warn, 5)
    local saveStatusLabel = makeLabel(utilitySection, "", THEME.dim, 6)

    view.SaveBtn = saveBtn
    view.LoadBtn = loadBtn
    view.ResetBtn = resetBtn
    view.SaveStatusLabel = saveStatusLabel

    -- Unload
    local unloadBtn = makeActionButton(utilitySection, "Unload Script", THEME.danger, 7)
    view.UnloadBtn = unloadBtn

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
    shared.glow(MinimizedPanel, THEME.glow, 3, 0.9)
    view.MinimizedPanel = MinimizedPanel

    local MiniHeader = Instance.new("TextButton")
    MiniHeader.Text = "Silent Hub"
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
    local miniLayout = Instance.new("UIListLayout")
    miniLayout.FillDirection = Enum.FillDirection.Horizontal
    miniLayout.Padding = UDim.new(0, 3)
    miniLayout.Parent = MiniCardsRow

    local function makeMiniCard(title, order)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 48, 1, 0)
        card.BackgroundColor3 = THEME.panel2
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.Parent = MiniCardsRow
        shared.corner(card, UDim.new(0, 5))

        local t = Instance.new("TextLabel")
        t.Text = title
        t.Size = UDim2.new(1, -4, 0, 9)
        t.Position = UDim2.fromOffset(2, 2)
        t.BackgroundTransparency = 1
        t.TextColor3 = THEME.dim
        t.Font = Enum.Font.GothamBold
        t.TextSize = 7
        t.TextXAlignment = Enum.TextXAlignment.Center
        t.Parent = card

        local v = Instance.new("TextLabel")
        v.Text = "-"
        v.Size = UDim2.new(1, -4, 0, 14)
        v.Position = UDim2.fromOffset(2, 11)
        v.BackgroundTransparency = 1
        v.TextColor3 = THEME.text
        v.Font = Enum.Font.GothamBold
        v.TextSize = 10
        v.TextXAlignment = Enum.TextXAlignment.Center
        v.Parent = card
        return v
    end

    view.MiniStats = {
        StatusVal = makeMiniCard("STATUS", 1),
        CPSVal = makeMiniCard("CPS", 2),
        FPSVal = makeMiniCard("FPS", 3),
        PingVal = makeMiniCard("PING", 4),
    }

    -- Stats (embedded in utilitySection or separate mini section)
    view.Stats = {
        TotalClicksVal = makeLabel(utilitySection, "Clicks: 0", THEME.text, 8),
        ActualCPSVal = makeLabel(utilitySection, "CPS: 0", THEME.text, 9),
        FPSVal = makeLabel(utilitySection, "FPS: 0", THEME.text, 10),
        PingVal = makeLabel(utilitySection, "Ping: 0 ms", THEME.text, 11),
    }

    view.Theme = THEME
    view.Toast = components.toast

    return view
end
