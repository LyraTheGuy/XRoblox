-- LyraHub/views/main.lua
-- View layer: window chrome + three tab pages, all built from the reusable
-- component factories in views/components/. Pure presentation — state lives
-- in the model and behavior lives in the controllers. Controllers reach the
-- pieces they need through `view.*` (Tabs, Components, Tiles, LogLabel...).

return function(config, components)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local shared = components.shared
    local theme = config.Theme
    local win = config.Window
    local def = config.Defaults

    local view = {}

    -- ScreenGui ----------------------------------------------------------------
    local gui = Instance.new("ScreenGui")
    gui.Name = "LyraHub_Gui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end
    view.Gui = gui

    local W, H = win.Size.X, win.Size.Y

    -- Fadeable root canvas ------------------------------------------------------
    local canvas = Instance.new("CanvasGroup")
    canvas.Name = "Canvas"
    canvas.Size = UDim2.fromOffset(W, H)
    canvas.AnchorPoint = Vector2.new(0.5, 0.5)
    canvas.Position = UDim2.new(0.5, 0, 0.5, 0)
    canvas.BackgroundTransparency = 1
    canvas.ClipsDescendants = false
    canvas.Parent = gui
    view.Canvas = canvas

    -- Main window ---------------------------------------------------------------
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(W, H)
    main.BackgroundColor3 = theme.bg
    main.BorderSizePixel = 0
    main.ZIndex = 2 -- keeps the drop shadow (ZIndex 1) behind the window
    main.ClipsDescendants = true -- keeps the dropdown list inside the window
    main.Parent = canvas
    shared.corner(main, UDim.new(0, 12))
    shared.stroke(main, theme.divider, 1, 0.45)
    shared.glow(main, theme.glow, 4, 0.92)
    shared.gradient(main, theme.bg, theme.bg2, 90)
    view.Main = main
    -- Default OffsetY=4 keeps the shadow at (-4, 0) relative to the window,
    -- which is exactly what the drag handler in controllers/main.lua replays.
    view.Shadow = shared.shadow(main)

    -- Top bar (transparent — title only; window buttons live on main so the
    -- full-width DragHit below can sit under them without stealing clicks) -----
    local topbar = Instance.new("Frame")
    topbar.Name = "TopBar"
    topbar.Size = UDim2.new(1, 0, 0, 48)
    topbar.BackgroundTransparency = 1
    topbar.ZIndex = 2
    topbar.Parent = main

    local logo = Instance.new("Frame")
    logo.Size = UDim2.fromOffset(12, 12)
    logo.Position = UDim2.fromOffset(18, 18)
    logo.BackgroundColor3 = theme.accent
    logo.BorderSizePixel = 0
    logo.ZIndex = 2
    logo.Parent = topbar
    shared.corner(logo, UDim.new(1, 0))
    shared.glow(logo, theme.glow, 2, 0.55)
    view.LogoDot = logo

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromOffset(160, 20)
    title.Position = UDim2.fromOffset(38, 12)
    title.BackgroundTransparency = 1
    title.Text = win.Title
    title.TextColor3 = theme.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 2
    title.Parent = topbar

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.fromOffset(160, 12)
    subtitle.Position = UDim2.fromOffset(38, 32)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = string.upper(win.Subtitle)
    subtitle.TextColor3 = theme.faint
    subtitle.Font = Enum.Font.GothamBold
    subtitle.TextSize = 8
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 2
    subtitle.Parent = topbar

    -- Window buttons (siblings of DragHit, ZIndex 3 -> always clickable) --------
    local minBtn = components.button({
        Parent = main, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(W - 76, 10),
        Text = "—", TextSize = 13, Color = theme.panel2, TextColor = theme.text,
        HoverColor = theme.accent2, CornerRadius = UDim.new(0, 8), ZIndex = 3, Glow = false,
    })
    local closeBtn = components.button({
        Parent = main, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(W - 40, 10),
        Text = "✕", TextSize = 12, Color = Color3.fromRGB(64, 28, 34), TextColor = theme.danger,
        HoverColor = Color3.fromRGB(96, 38, 46), CornerRadius = UDim.new(0, 8), ZIndex = 3, Glow = false,
    })
    view.MinBtn = minBtn.Instance
    view.CloseBtn = closeBtn.Instance

    -- Full-width drag hitbox over the top bar ------------------------------------
    local dragHit = Instance.new("TextButton")
    dragHit.Name = "DragHit"
    dragHit.Size = UDim2.new(1, 0, 0, 48)
    dragHit.BackgroundTransparency = 1
    dragHit.Text = ""
    dragHit.AutoButtonColor = false
    dragHit.BorderSizePixel = 0
    dragHit.ZIndex = 2
    dragHit.Parent = main
    view.DragHit = dragHit

    -- Divider under the top bar --------------------------------------------------
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.Position = UDim2.fromOffset(0, 48)
    divider.BackgroundColor3 = theme.divider
    divider.BorderSizePixel = 0
    divider.ZIndex = 1
    divider.Parent = main

    -- Sidebar --------------------------------------------------------------------
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.fromOffset(150, H - 49)
    sidebar.Position = UDim2.fromOffset(0, 49)
    sidebar.BackgroundColor3 = theme.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 1
    sidebar.Parent = main
    shared.corner(sidebar, UDim.new(0, 10))
    shared.stroke(sidebar, theme.divider, 1, 0.4)

    local function label(opts)
        local l = Instance.new("TextLabel")
        l.Size = opts.Size or UDim2.new(0, 200, 0, 20)
        l.Position = opts.Position or UDim2.new(0, 0, 0, 0)
        l.AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0)
        l.BackgroundTransparency = 1
        l.Text = opts.Text or ""
        l.TextColor3 = opts.Color or theme.text
        l.Font = opts.Font or Enum.Font.Gotham
        l.TextSize = opts.TextSize or 12
        l.TextXAlignment = opts.TextXAlignment or Enum.TextXAlignment.Left
        l.TextYAlignment = opts.TextYAlignment or Enum.TextYAlignment.Center
        l.TextWrapped = opts.Wrapped or false
        l.ZIndex = opts.ZIndex or 1
        l.Parent = opts.Parent
        return l
    end

    -- Sidebar footer chip
    local chip = Instance.new("Frame")
    chip.Size = UDim2.fromOffset(126, 24)
    chip.Position = UDim2.new(0, 12, 1, -36)
    chip.BackgroundColor3 = theme.panel2
    chip.BackgroundTransparency = 0.6
    chip.BorderSizePixel = 0
    chip.Parent = sidebar
    shared.corner(chip, UDim.new(1, 0))
    label({
        Parent = chip, Text = "v1.2 · MVC", Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 1, 0), TextSize = 8, Color = theme.faint,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- Pages ----------------------------------------------------------------------
    local function makePage()
        local page = Instance.new("Frame")
        page.Name = "Page"
        page.Size = UDim2.fromOffset(W - 174, H - 73)
        page.Position = UDim2.fromOffset(162, 61)
        page.BackgroundColor3 = theme.panel
        page.BackgroundTransparency = 0.4
        page.BorderSizePixel = 0
        page.ZIndex = 1
        page.Visible = false
        page.Parent = main
        shared.corner(page, UDim.new(0, 10))
        shared.stroke(page, theme.divider, 1, 0.5)
        return page
    end

    local TabOrder = { "Dashboard", "Controls", "Input", "Advanced" }
    view.TabOrder = TabOrder
    view.Tabs = {}

    function view.SetActiveTab(name)
        for _, t in ipairs(TabOrder) do
            local tab = view.Tabs[t]
            local active = t == name
            tab.Active = active
            shared.tween(tab.Button, {
                TextColor3 = active and Color3.new(1, 1, 1) or theme.dim,
                BackgroundTransparency = active and 0.88 or 1,
            }, 0.14)
            shared.tween(tab.Indicator, { BackgroundTransparency = active and 0 or 1 }, 0.14)
            if tab.Page then
                tab.Page.Visible = active
            end
        end
    end

    local function makeTab(name, index)
        local y = 70 + (index - 1) * 42
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -24, 0, 34)
        btn.Position = UDim2.fromOffset(12, y)
        btn.BackgroundTransparency = 1
        btn.Text = name
        btn.TextColor3 = theme.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.ZIndex = 2
        btn.Parent = sidebar
        shared.corner(btn, UDim.new(0, 6))
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.Parent = btn

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.fromOffset(3, 18)
        indicator.Position = UDim2.new(1, -9, 0.5, -9)
        indicator.BackgroundColor3 = theme.accent
        indicator.BackgroundTransparency = 1
        indicator.BorderSizePixel = 0
        indicator.Parent = btn
        shared.corner(indicator, UDim.new(1, 0))

        btn.MouseEnter:Connect(function()
            if not view.Tabs[name].Active then
                shared.tween(btn, { TextColor3 = theme.text, BackgroundTransparency = 0.92 }, 0.12)
            end
        end)
        btn.MouseLeave:Connect(function()
            if not view.Tabs[name].Active then
                shared.tween(btn, { TextColor3 = theme.dim, BackgroundTransparency = 1 }, 0.18)
            end
        end)
        return btn, indicator
    end

    -- ============================================================================
    -- Dashboard page
    -- ============================================================================
    local dash = makePage()
    dash.Name = "DashboardPage"

    label({
        Parent = dash, Text = "Session Overview", Position = UDim2.fromOffset(16, 14),
        Size = UDim2.fromOffset(280, 20), TextSize = 15, Font = Enum.Font.GothamBold,
    })
    label({
        Parent = dash, Text = "Live bindings — components ⇄ observable store",
        Position = UDim2.fromOffset(16, 36), Size = UDim2.fromOffset(360, 14),
        TextSize = 10, Color = theme.faint,
    })

    local statusPanel = Instance.new("Frame")
    statusPanel.Size = UDim2.fromOffset(414, 96)
    statusPanel.Position = UDim2.fromOffset(16, 58)
    statusPanel.BackgroundColor3 = theme.panel2
    statusPanel.BorderSizePixel = 0
    statusPanel.Parent = dash
    shared.corner(statusPanel, UDim.new(0, 10))
    shared.stroke(statusPanel, theme.divider, 1, 0.55)

    local tileRow = Instance.new("Frame")
    tileRow.Size = UDim2.fromOffset(398, 80)
    tileRow.Position = UDim2.fromOffset(8, 8)
    tileRow.BackgroundTransparency = 1
    tileRow.Parent = statusPanel
    local tileLayout = Instance.new("UIListLayout")
    tileLayout.FillDirection = Enum.FillDirection.Horizontal
    tileLayout.Padding = UDim.new(0, 10)
    tileLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tileLayout.Parent = tileRow

    local function tile(name, order)
        local t = Instance.new("Frame")
        t.Size = UDim2.fromOffset(89, 80)
        t.BackgroundTransparency = 1
        t.LayoutOrder = order
        t.Parent = tileRow
        label({
            Parent = t, Text = name, Position = UDim2.fromOffset(0, 8),
            Size = UDim2.new(1, 0, 0, 12), TextSize = 8, Color = theme.faint,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
        })
        return label({
            Parent = t, Text = "-", Position = UDim2.fromOffset(0, 28),
            Size = UDim2.new(1, 0, 0, 22), TextSize = 15, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end

    view.Tiles = {
        Status = tile("STATUS", 1),
        Accent = tile("ACCENT", 2),
        Scale = tile("SCALE", 3),
        Glow = tile("GLOW", 4),
    }

    label({
        Parent = dash, Text = "Quick actions", Position = UDim2.fromOffset(16, 166),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })

    local actions = Instance.new("Frame")
    actions.Size = UDim2.fromOffset(414, 46)
    actions.Position = UDim2.fromOffset(16, 186)
    actions.BackgroundColor3 = theme.panel2
    actions.BorderSizePixel = 0
    actions.Parent = dash
    shared.corner(actions, UDim.new(0, 10))
    shared.stroke(actions, theme.divider, 1, 0.55)

    local enableBtn = components.button({
        Parent = actions, Size = UDim2.fromOffset(126, 30), Position = UDim2.fromOffset(8, 8),
        Text = "Enable All", TextSize = 12, Color = theme.accent, HoverColor = theme.accent2, Glow = false,
    })
    local disableBtn = components.button({
        Parent = actions, Size = UDim2.fromOffset(126, 30), Position = UDim2.fromOffset(144, 8),
        Text = "Disable All", TextSize = 12, Color = theme.panel2, TextColor = theme.danger,
        HoverColor = Color3.fromRGB(90, 40, 48), Glow = false,
    })
    local resetBtn = components.button({
        Parent = actions, Size = UDim2.fromOffset(126, 30), Position = UDim2.fromOffset(280, 8),
        Text = "Reset", TextSize = 12, Color = theme.panel, TextColor = theme.dim,
        HoverColor = theme.panel2, Glow = false,
    })

    label({
        Parent = dash, Text = "Activity", Position = UDim2.fromOffset(16, 246),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })

    local logPanel = Instance.new("Frame")
    logPanel.Size = UDim2.fromOffset(414, 56)
    logPanel.Position = UDim2.fromOffset(16, 266)
    logPanel.BackgroundColor3 = theme.panel2
    logPanel.BackgroundTransparency = 0.6
    logPanel.BorderSizePixel = 0
    logPanel.Parent = dash
    shared.corner(logPanel, UDim.new(0, 10))
    shared.stroke(logPanel, theme.divider, 1, 0.55)

    view.LogLabel = label({
        Parent = logPanel, Text = "Ready — waiting for actions…",
        Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(390, 40),
        TextSize = 10, Color = theme.dim, Wrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    })

    label({
        Parent = dash, Text = "LyraHub UI Kit · pure MVC demo · [K] toggles UI",
        Position = UDim2.fromOffset(16, 330), Size = UDim2.fromOffset(400, 12),
        TextSize = 8, Color = theme.faint,
    })

    -- ============================================================================
    -- Controls page (component showcase)
    -- ============================================================================
    local ctrl = makePage()
    ctrl.Name = "ControlsPage"

    label({
        Parent = ctrl, Text = "Interactive Components", Position = UDim2.fromOffset(16, 14),
        Size = UDim2.fromOffset(300, 20), TextSize = 15, Font = Enum.Font.GothamBold,
    })
    label({
        Parent = ctrl, Text = "Rounded buttons · toggles · dropdown · sliders",
        Position = UDim2.fromOffset(16, 36), Size = UDim2.fromOffset(360, 14),
        TextSize = 10, Color = theme.faint,
    })

    label({
        Parent = ctrl, Text = "Buttons", Position = UDim2.fromOffset(16, 60),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })

    local primaryBtn = components.button({
        Parent = ctrl, Size = UDim2.fromOffset(110, 32), Position = UDim2.fromOffset(16, 80),
        Text = "Launch", TextSize = 12, Color = theme.accent, HoverColor = theme.accent2, Glow = false,
    })
    local secondaryBtn = components.button({
        Parent = ctrl, Size = UDim2.fromOffset(110, 32), Position = UDim2.fromOffset(134, 80),
        Text = "Secondary", TextSize = 12, Color = theme.panel2, HoverColor = theme.accent, Glow = false,
    })
    local ghostBtn = components.button({
        Parent = ctrl, Size = UDim2.fromOffset(110, 32), Position = UDim2.fromOffset(252, 80),
        Text = "Ghost", TextSize = 12, Color = theme.panel, BackgroundTransparency = 0.5,
        HoverColor = theme.panel2, Glow = false,
    })

    label({
        Parent = ctrl, Text = "Primary toggles off when the master switch is disabled",
        Position = UDim2.fromOffset(16, 114), Size = UDim2.fromOffset(400, 12),
        TextSize = 8, Color = theme.faint,
    })

    label({
        Parent = ctrl, Text = "Toggles", Position = UDim2.fromOffset(16, 140),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })

    label({
        Parent = ctrl, Text = "Push notifications", Position = UDim2.fromOffset(16, 164),
        Size = UDim2.fromOffset(220, 20), TextSize = 12,
    })
    local notifyToggle = components.toggle({
        Parent = ctrl, Position = UDim2.fromOffset(250, 174), Default = def.notifications, ZIndex = 2,
    })

    label({
        Parent = ctrl, Text = "Bold accents", Position = UDim2.fromOffset(16, 200),
        Size = UDim2.fromOffset(220, 20), TextSize = 12,
    })
    local boldToggle = components.toggle({
        Parent = ctrl, Position = UDim2.fromOffset(250, 210), Default = def.bold, ZIndex = 2,
    })

    label({
        Parent = ctrl, Text = "Dropdown", Position = UDim2.fromOffset(16, 236),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })

    local accentDropdown = components.dropdown({
        Parent = ctrl, Size = UDim2.fromOffset(200, 36), Position = UDim2.fromOffset(16, 250),
        Items = config.AccentOrder, Default = def.accent, ItemHeight = 28,
    })

    local accentChip = Instance.new("Frame")
    accentChip.Size = UDim2.fromOffset(20, 20)
    accentChip.Position = UDim2.fromOffset(230, 258)
    accentChip.BackgroundColor3 = config.Accents[def.accent] or theme.accent
    accentChip.BorderSizePixel = 0
    accentChip.Parent = ctrl
    shared.corner(accentChip, UDim.new(1, 0))
    shared.stroke(accentChip, theme.divider, 1, 0.4)

    label({
        Parent = ctrl, Text = "Theme accent", Position = UDim2.fromOffset(258, 258),
        Size = UDim2.fromOffset(140, 20), TextSize = 11, Color = theme.dim,
    })

    label({
        Parent = ctrl, Text = "Horizontal slider", Position = UDim2.fromOffset(16, 300),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })

    local scaleSlider = components.slider({
        Parent = ctrl, Size = UDim2.fromOffset(240, 6), Position = UDim2.fromOffset(16, 320),
        Default = def.scale,
    })
    local scaleValue = label({
        Parent = ctrl, Text = "70%", Position = UDim2.fromOffset(270, 320),
        Size = UDim2.fromOffset(60, 18), TextSize = 11, Color = theme.accent2,
        TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold,
        AnchorPoint = Vector2.new(0, 0.5),
    })

    -- ============================================================================
    -- Advanced page
    -- ============================================================================
    local adv = makePage()
    adv.Name = "AdvancedPage"

    label({
        Parent = adv, Text = "Advanced", Position = UDim2.fromOffset(16, 14),
        Size = UDim2.fromOffset(200, 20), TextSize = 15, Font = Enum.Font.GothamBold,
    })
    label({
        Parent = adv, Text = "Vertical slider · opacity · about",
        Position = UDim2.fromOffset(16, 36), Size = UDim2.fromOffset(340, 14),
        TextSize = 10, Color = theme.faint,
    })

    label({
        Parent = adv, Text = "Glow intensity", Position = UDim2.fromOffset(16, 62),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })
    local glowValue = label({
        Parent = adv, Text = "60%", Position = UDim2.fromOffset(30, 84),
        Size = UDim2.fromOffset(60, 14), TextSize = 10, Color = theme.accent2,
        TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold,
    })
    local glowSlider = components.slider({
        Parent = adv, Orientation = "vertical", Size = UDim2.fromOffset(6, 110),
        Position = UDim2.fromOffset(57, 100), Default = def.glow,
    })

    label({
        Parent = adv, Text = "Panel opacity", Position = UDim2.fromOffset(200, 62),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })
    local opacitySlider = components.slider({
        Parent = adv, Size = UDim2.fromOffset(200, 6), Position = UDim2.fromOffset(200, 100),
        Default = def.opacity,
    })
    local opacityValue = label({
        Parent = adv, Text = "100%", Position = UDim2.fromOffset(394, 100),
        Size = UDim2.fromOffset(52, 18), TextSize = 11, Color = theme.accent2,
        TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold,
        AnchorPoint = Vector2.new(0, 0.5),
    })

    local about = Instance.new("Frame")
    about.Size = UDim2.fromOffset(414, 110)
    about.Position = UDim2.fromOffset(16, 140)
    about.BackgroundColor3 = theme.panel2
    about.BackgroundTransparency = 0.4
    about.BorderSizePixel = 0
    about.Parent = adv
    shared.corner(about, UDim.new(0, 10))
    shared.stroke(about, theme.divider, 1, 0.55)

    label({
        Parent = about, Text = "LyraHub MVC UI Kit", Position = UDim2.fromOffset(16, 12),
        Size = UDim2.fromOffset(300, 18), TextSize = 14, Font = Enum.Font.GothamBold,
    })
    label({
        Parent = about, Text = "Modular Model-View-Controller demo: components stay presentational, controllers drive behavior, and the observable store keeps views in sync.",
        Position = UDim2.fromOffset(16, 34), Size = UDim2.fromOffset(382, 44),
        TextSize = 10, Color = theme.dim, Wrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    })
    label({
        Parent = about, Text = "Free & open · built for LyraHub", Position = UDim2.fromOffset(16, 84),
        Size = UDim2.fromOffset(300, 12), TextSize = 8, Color = theme.faint,
    })

    local unloadBtn = components.button({
        Parent = adv, Size = UDim2.fromOffset(160, 32), Position = UDim2.fromOffset(16, 300),
        Text = "Unload LyraHub", TextSize = 12, Color = Color3.fromRGB(70, 30, 36),
        TextColor = theme.danger, HoverColor = Color3.fromRGB(100, 42, 50), Glow = false,
    })
    label({
        Parent = adv, Text = "Closes the demo UI and cleans up every connection.",
        Position = UDim2.fromOffset(186, 300), Size = UDim2.fromOffset(240, 32),
        TextSize = 9, Color = theme.faint, Wrapped = true,
    })

    -- ============================================================================
    -- Input page (keybind picker · text input · color picker)
    -- ============================================================================
    local inp = makePage()
    inp.Name = "InputPage"

    label({
        Parent = inp, Text = "Inputs", Position = UDim2.fromOffset(16, 14),
        Size = UDim2.fromOffset(200, 20), TextSize = 15, Font = Enum.Font.GothamBold,
    })
    label({
        Parent = inp, Text = "Keybind picker · text input · color picker",
        Position = UDim2.fromOffset(16, 36), Size = UDim2.fromOffset(360, 14),
        TextSize = 10, Color = theme.faint,
    })

    label({
        Parent = inp, Text = "UI toggle key", Position = UDim2.fromOffset(16, 66),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })
    local keybindPicker = components.keybind({
        Parent = inp, Size = UDim2.fromOffset(180, 32), Position = UDim2.fromOffset(16, 84),
        Default = def.keybind,
    })
    label({
        Parent = inp, Text = "Click to rebind · Esc or click-away cancels",
        Position = UDim2.fromOffset(206, 92), Size = UDim2.fromOffset(220, 16),
        TextSize = 9, Color = theme.faint,
    })

    label({
        Parent = inp, Text = "Username", Position = UDim2.fromOffset(16, 130),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })
    local userInput = components.textinput({
        Parent = inp, Size = UDim2.fromOffset(260, 32), Position = UDim2.fromOffset(16, 148),
        Default = def.username, Placeholder = "Type a name…",
    })
    label({
        Parent = inp, Text = "Enter commits · × clears",
        Position = UDim2.fromOffset(286, 156), Size = UDim2.fromOffset(140, 16),
        TextSize = 9, Color = theme.faint,
    })

    label({
        Parent = inp, Text = "Accent color", Position = UDim2.fromOffset(16, 194),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })
    local colorPicker = components.colorpicker({
        Parent = inp, Size = UDim2.fromOffset(180, 32), Position = UDim2.fromOffset(16, 212),
        Default = def.tint,
    })
    label({
        Parent = inp, Text = "Custom override — presets win on dropdown use",
        Position = UDim2.fromOffset(206, 220), Size = UDim2.fromOffset(220, 16),
        TextSize = 9, Color = theme.faint,
    })

    label({
        Parent = inp, Text = "Live values", Position = UDim2.fromOffset(16, 262),
        Size = UDim2.fromOffset(200, 16), TextSize = 13, Font = Enum.Font.GothamBold,
    })
    local livePanel = Instance.new("Frame")
    livePanel.Size = UDim2.fromOffset(414, 62)
    livePanel.Position = UDim2.fromOffset(16, 280)
    livePanel.BackgroundColor3 = theme.panel2
    livePanel.BackgroundTransparency = 0.6
    livePanel.BorderSizePixel = 0
    livePanel.Parent = inp
    shared.corner(livePanel, UDim.new(0, 10))
    shared.stroke(livePanel, theme.divider, 1, 0.55)

    local function liveRow(y, name)
        label({
            Parent = livePanel, Text = name, Position = UDim2.fromOffset(12, y),
            Size = UDim2.fromOffset(60, 16), TextSize = 9, Color = theme.faint,
            Font = Enum.Font.GothamBold,
        })
        return label({
            Parent = livePanel, Text = "-", Position = UDim2.fromOffset(78, y),
            Size = UDim2.fromOffset(320, 16), TextSize = 10, Color = theme.text,
        })
    end

    view.InputStatus = {
        Key = liveRow(6, "KEY"),
        User = liveRow(24, "USER"),
        Color = liveRow(42, "COLOR"),
    }

    -- ============================================================================
    -- Minimized panel
    -- ============================================================================
    local minimized = Instance.new("Frame")
    minimized.Name = "Minimized"
    minimized.Size = UDim2.fromOffset(200, 42)
    minimized.AnchorPoint = Vector2.new(1, 1)
    minimized.Position = UDim2.new(1, -12, 1, -12)
    minimized.BackgroundColor3 = theme.panel
    minimized.BorderSizePixel = 0
    minimized.Visible = false
    minimized.ZIndex = 5
    minimized.Parent = gui
    shared.corner(minimized, UDim.new(1, 0))
    shared.stroke(minimized, theme.divider, 1, 0.5)
    shared.glow(minimized, theme.glow, 3, 0.9)

    local minScale = Instance.new("UIScale")
    minScale.Scale = 0.9
    minScale.Parent = minimized
    view.MinScale = minScale
    view.Minimized = minimized

    local minDot = Instance.new("Frame")
    minDot.Size = UDim2.fromOffset(10, 10)
    minDot.Position = UDim2.fromOffset(16, 16)
    minDot.BackgroundColor3 = theme.accent
    minDot.BorderSizePixel = 0
    minDot.Parent = minimized
    shared.corner(minDot, UDim.new(1, 0))
    shared.glow(minDot, theme.glow, 2, 0.55)

    label({
        Parent = minimized, Text = win.Title, Position = UDim2.fromOffset(34, 12),
        Size = UDim2.fromOffset(110, 18), TextSize = 12, Font = Enum.Font.GothamBold,
    })

    local expandBtn = components.button({
        Parent = minimized, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(162, 7),
        Text = "▲", TextSize = 11, Color = theme.panel2, HoverColor = theme.accent2,
        CornerRadius = UDim.new(1, 0), ZIndex = 6, Glow = false,
    })
    view.ExpandBtn = expandBtn

    -- ============================================================================
    -- Component registry + tab wiring
    -- ============================================================================
    view.Components = {
        EnableBtn = enableBtn, DisableBtn = disableBtn, ResetBtn = resetBtn,
        PrimaryBtn = primaryBtn, SecondaryBtn = secondaryBtn, GhostBtn = ghostBtn,
        NotifyToggle = notifyToggle, BoldToggle = boldToggle,
        AccentDropdown = accentDropdown, AccentChip = accentChip,
        ScaleSlider = scaleSlider, ScaleValue = scaleValue,
        GlowSlider = glowSlider, GlowValue = glowValue,
        OpacitySlider = opacitySlider, OpacityValue = opacityValue,
        KeybindPicker = keybindPicker, UserInput = userInput, ColorPicker = colorPicker,
        UnloadBtn = unloadBtn,
    }

    local pages = { Dashboard = dash, Controls = ctrl, Input = inp, Advanced = adv }
    for i, name in ipairs(TabOrder) do
        local btn, indicator = makeTab(name, i)
        view.Tabs[name] = { Button = btn, Indicator = indicator, Page = pages[name], Active = false }
    end
    view.SetActiveTab(TabOrder[1])

    return view
end
