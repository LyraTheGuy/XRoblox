-- BuildABeehive/gui.lua
-- IndoVoice-style split layout with real tabs, a clean overview, and a simple
-- actions pane — now built with the LyraHub UI kit (shared primitives + the
-- button and textinput component factories). Keeps the same external contract
-- (Stats.*, ActionStats.*, CollectButton, *IntervalInput, DragHit, ...) so the
-- core/modules layer stays intact.

return function(config, components)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    local shared = components.shared
    local theme = config.Theme or {}
    local W, H = config.Window.Size.X, config.Window.Size.Y

    if _G.__BuildABeehive_Destroy then
        pcall(_G.__BuildABeehive_Destroy)
    end
    _G.__BuildABeehive_Destroy = nil

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BuildABeehive_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999
    pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
    if not screenGui.Parent then
        screenGui.Parent = lp:WaitForChild("PlayerGui")
    end

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
        l.ZIndex = opts.ZIndex or 1
        l.TextWrapped = opts.Wrapped or false
        if opts.LayoutOrder then
            l.LayoutOrder = opts.LayoutOrder
        end
        if opts.Visible ~= nil then
            l.Visible = opts.Visible
        end
        l.Parent = opts.Parent
        return l
    end

    -- ═══════════════════════════════════════════
    -- MAIN WINDOW
    -- ═══════════════════════════════════════════
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(W, H)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.BackgroundColor3 = theme.bg or Color3.fromRGB(18, 18, 24)
    main.BorderSizePixel = 0
    main.ZIndex = 2
    main.ClipsDescendants = true
    main.Parent = screenGui
    shared.corner(main, UDim.new(0, 12))
    shared.stroke(main, theme.divider or theme.panel2, 1, 0.45)
    shared.glow(main, theme.glow or theme.accent, 4, 0.92)
    shared.gradient(main, theme.bg, theme.bg2, 90)

    local shadow = shared.shadow(main)

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 36)
    topBar.BackgroundTransparency = 1
    topBar.Active = true
    topBar.ZIndex = 2
    topBar.Parent = main

    local logo = Instance.new("Frame")
    logo.Size = UDim2.fromOffset(10, 10)
    logo.Position = UDim2.fromOffset(16, 13)
    logo.BackgroundColor3 = theme.accent or Color3.fromRGB(80, 180, 255)
    logo.BorderSizePixel = 0
    logo.Parent = topBar
    shared.corner(logo, UDim.new(1, 0))
    shared.glow(logo, theme.glow or theme.accent, 2, 0.55)

    local title = label({
        Parent = topBar, Text = config.Window.Title, Position = UDim2.fromOffset(34, 6),
        Size = UDim2.fromOffset(240, 18), TextSize = 13, Font = Enum.Font.GothamBold,
        Color = theme.text,
    })

    label({
        Parent = topBar, Text = config.Window.Subtitle, Position = UDim2.fromOffset(34, 24),
        Size = UDim2.fromOffset(340, 10), TextSize = 8, Color = theme.faint or theme.dim,
    })

    local minBtn = components.button({
        Parent = topBar, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -64, 0, 4),
        Text = "—", TextSize = 13, Color = theme.panel2, TextColor = theme.text,
        HoverColor = theme.accent2, CornerRadius = UDim.new(0, 8), ZIndex = 3, Glow = false,
    })
    local closeBtn = components.button({
        Parent = topBar, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -32, 0, 4),
        Text = "✕", TextSize = 12, Color = Color3.fromRGB(64, 28, 34), TextColor = theme.danger,
        HoverColor = Color3.fromRGB(96, 38, 46), CornerRadius = UDim.new(0, 8), ZIndex = 3, Glow = false,
    })

    -- Drag hit area — stops short of the window buttons so it never covers them
    local dragHit = Instance.new("TextButton")
    dragHit.Size = UDim2.new(1, -96, 1, 0)
    dragHit.BackgroundTransparency = 1
    dragHit.Text = ""
    dragHit.AutoButtonColor = false
    dragHit.BorderSizePixel = 0
    dragHit.ZIndex = 2
    dragHit.Parent = topBar

    -- ═══════════════════════════════════════════
    -- SIDEBAR + TABS
    -- ═══════════════════════════════════════════
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 130, 1, -36)
    sidebar.Position = UDim2.new(0, 0, 0, 36)
    sidebar.BackgroundColor3 = theme.sidebar or theme.bg2
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    shared.corner(sidebar, UDim.new(0, 10))
    shared.stroke(sidebar, theme.divider or theme.panel2, 1, 0.4)

    label({
        Parent = sidebar, Text = "Beehive", Position = UDim2.fromOffset(14, 10),
        Size = UDim2.new(1, -28, 0, 32), TextSize = 15, Font = Enum.Font.GothamBold,
        Color = theme.text,
    })
    label({
        Parent = sidebar, Text = "Auto tools", Position = UDim2.fromOffset(14, 42),
        Size = UDim2.new(1, -28, 0, 14), TextSize = 10, Color = theme.dim,
    })

    local sidebarLine = Instance.new("Frame")
    sidebarLine.Size = UDim2.new(0.72, 0, 0, 1)
    sidebarLine.AnchorPoint = Vector2.new(0.5, 0)
    sidebarLine.Position = UDim2.new(0.5, 0, 0, 64)
    sidebarLine.BackgroundColor3 = theme.panel2
    sidebarLine.BorderSizePixel = 0
    sidebarLine.Parent = sidebar

    -- Tab buttons (LyraHub-styled raw buttons with hover + active indicator).
    local tabButtons = {}
    local tabActive = {}

    local function makeTabButton(name, y)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -16, 0, 34)
        btn.Position = UDim2.new(0, 8, 0, y)
        btn.BackgroundColor3 = theme.panel2
        btn.Text = name
        btn.TextColor3 = theme.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Parent = sidebar
        shared.corner(btn, UDim.new(0, 8))
        shared.stroke(btn, theme.divider or theme.panel2, 1, 0.5)

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.fromOffset(3, 18)
        indicator.Position = UDim2.new(1, -10, 0.5, -9)
        indicator.BackgroundColor3 = theme.accent
        indicator.BackgroundTransparency = 1
        indicator.BorderSizePixel = 0
        indicator.Parent = btn
        shared.corner(indicator, UDim.new(1, 0))

        btn.MouseEnter:Connect(function()
            if not tabActive[btn] then
                shared.tween(btn, { TextColor3 = theme.text }, 0.12)
            end
        end)
        btn.MouseLeave:Connect(function()
            if not tabActive[btn] then
                shared.tween(btn, { TextColor3 = theme.dim }, 0.18)
            end
        end)

        tabButtons[name] = btn
        tabActive[btn] = false
        return btn, indicator
    end

    local tabOverviewBtn, tabOverviewIndicator = makeTabButton("Overview", 76)
    local tabActionsBtn, tabActionsIndicator = makeTabButton("Actions", 118)
    local tabBuyBtn, tabBuyIndicator = makeTabButton("Buy", 160)

    local tabIndicators = {
        Overview = tabOverviewIndicator,
        Actions = tabActionsIndicator,
        Buy = tabBuyIndicator,
    }

    -- ═══════════════════════════════════════════
    -- CONTENT + TABS
    -- ═══════════════════════════════════════════
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -142, 1, -48)
    content.Position = UDim2.new(0, 136, 0, 42)
    content.BackgroundColor3 = theme.panel
    content.BackgroundTransparency = 0.35
    content.BorderSizePixel = 0
    content.ClipsDescendants = true
    content.Parent = main
    shared.corner(content, UDim.new(0, 10))
    shared.stroke(content, theme.divider or theme.panel2, 1, 0.5)

    local overviewTab = Instance.new("Frame")
    overviewTab.Name = "OverviewTab"
    overviewTab.Size = UDim2.new(1, 0, 1, 0)
    overviewTab.BackgroundTransparency = 1
    overviewTab.Parent = content

    local actionsTab = Instance.new("Frame")
    actionsTab.Name = "ActionsTab"
    actionsTab.Size = UDim2.new(1, 0, 1, 0)
    actionsTab.BackgroundTransparency = 1
    actionsTab.Visible = false
    actionsTab.Parent = content

    local buyTab = Instance.new("ScrollingFrame")
    buyTab.Name = "BuyTab"
    buyTab.Size = UDim2.new(1, 0, 1, 0)
    buyTab.BackgroundTransparency = 1
    buyTab.BorderSizePixel = 0
    buyTab.Visible = false
    buyTab.ScrollBarThickness = 3
    buyTab.ScrollBarImageTransparency = 0.6
    buyTab.CanvasSize = UDim2.new(0, 0, 0, 560)
    buyTab.Parent = content

    local function applyTab(activeTab)
        local showOverview = activeTab == "Overview"
        local showActions = activeTab == "Actions"
        local showBuy = activeTab == "Buy"
        overviewTab.Visible = showOverview
        actionsTab.Visible = showActions
        buyTab.Visible = showBuy

        local states = { Overview = showOverview, Actions = showActions, Buy = showBuy }
        for name, btn in pairs(tabButtons) do
            local active = states[name]
            tabActive[btn] = active
            shared.tween(btn, {
                BackgroundColor3 = active and theme.accent or theme.panel2,
                BackgroundTransparency = active and 0.1 or 0,
                TextColor3 = active and theme.text or theme.dim,
            }, 0.14)
            shared.tween(tabIndicators[name], { BackgroundTransparency = active and 0 or 1 }, 0.14)
        end
    end

    local function setTab(tabName)
        applyTab(tabName)
    end

    -- ═══════════════════════════════════════════
    -- OVERVIEW TAB
    -- ═══════════════════════════════════════════
    local status = label({
        Parent = overviewTab, Text = "Status: OFF", Position = UDim2.new(0, 12, 0, 10),
        Size = UDim2.new(1, -24, 0, 18), TextSize = 13, Font = Enum.Font.GothamBold, Color = theme.danger,
    })

    label({
        Parent = overviewTab, Text = "Automation dashboard", Position = UDim2.new(0, 12, 0, 34),
        Size = UDim2.new(1, -24, 0, 26), TextSize = 18, Font = Enum.Font.GothamBold, Color = theme.text,
    })
    label({
        Parent = overviewTab, Text = "Stats at a glance. Actions on the next tab.", Position = UDim2.new(0, 12, 0, 58),
        Size = UDim2.new(1, -24, 0, 16), TextSize = 10, Color = theme.dim,
    })

    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(0, 300, 0, 118)
    statsFrame.Position = UDim2.new(0, 12, 0, 82)
    statsFrame.BackgroundColor3 = theme.panel
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = overviewTab
    shared.corner(statsFrame, UDim.new(0, 10))
    shared.stroke(statsFrame, theme.divider or theme.panel2, 1, 0.5)

    local statsGrid = Instance.new("UIGridLayout")
    statsGrid.CellPadding = UDim2.new(0, 8, 0, 8)
    statsGrid.CellSize = UDim2.new(0.5, -4, 0.5, -4)
    statsGrid.SortOrder = Enum.SortOrder.LayoutOrder
    statsGrid.Parent = statsFrame

    local statsPadding = Instance.new("UIPadding")
    statsPadding.PaddingTop = UDim.new(0, 8)
    statsPadding.PaddingBottom = UDim.new(0, 8)
    statsPadding.PaddingLeft = UDim.new(0, 8)
    statsPadding.PaddingRight = UDim.new(0, 8)
    statsPadding.Parent = statsFrame

    local function makeStatCard(labelText, order, parent)
        local card = Instance.new("Frame")
        card.BackgroundColor3 = theme.panel2
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.Parent = parent or statsFrame
        shared.corner(card, UDim.new(0, 8))
        shared.stroke(card, theme.divider or theme.panel2, 1, 0.5)

        label({
            Parent = card, Text = labelText, Position = UDim2.new(0, 8, 0, 5),
            Size = UDim2.new(1, -16, 0, 12), TextSize = 9, Color = theme.dim,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        })
        return label({
            Parent = card, Text = "0", Position = UDim2.new(0, 8, 0, 20),
            Size = UDim2.new(1, -16, 0, 20), TextSize = 14, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
    end

    local fpsValue = makeStatCard("FPS", 1)
    local pingValue = makeStatCard("PING", 2)
    local playerCountValue = makeStatCard("PLAYER COUNT", 3)
    local totalHiveValue = makeStatCard("TOTAL HIVE", 4)

    -- Action counters section (fed by ctx.counts via core.lua updateStats)
    label({
        Parent = overviewTab, Text = "ACTIONS PERFORMED", Position = UDim2.new(0, 12, 0, 210),
        Size = UDim2.new(1, -24, 0, 14), TextSize = 9, Color = theme.dim, Font = Enum.Font.GothamBold,
    })

    local resetCountersBtn = components.button({
        Parent = overviewTab, Size = UDim2.fromOffset(56, 18), Position = UDim2.new(1, -68, 0, 210),
        Text = "Reset", TextSize = 9, Color = theme.panel2, TextColor = theme.dim,
        HoverColor = theme.accent2, CornerRadius = UDim.new(0, 6), Glow = false,
    })

    local actionStatsFrame = Instance.new("Frame")
    actionStatsFrame.Size = UDim2.new(0, 300, 0, 118)
    actionStatsFrame.Position = UDim2.new(0, 12, 0, 228)
    actionStatsFrame.BackgroundColor3 = theme.panel
    actionStatsFrame.BorderSizePixel = 0
    actionStatsFrame.Parent = overviewTab
    shared.corner(actionStatsFrame, UDim.new(0, 10))
    shared.stroke(actionStatsFrame, theme.divider or theme.panel2, 1, 0.5)

    local actionStatsGrid = Instance.new("UIGridLayout")
    actionStatsGrid.CellPadding = UDim2.new(0, 8, 0, 8)
    actionStatsGrid.CellSize = UDim2.new(0.5, -4, 0.5, -4)
    actionStatsGrid.SortOrder = Enum.SortOrder.LayoutOrder
    actionStatsGrid.Parent = actionStatsFrame

    local actionStatsPadding = Instance.new("UIPadding")
    actionStatsPadding.PaddingTop = UDim.new(0, 8)
    actionStatsPadding.PaddingBottom = UDim.new(0, 8)
    actionStatsPadding.PaddingLeft = UDim.new(0, 8)
    actionStatsPadding.PaddingRight = UDim.new(0, 8)
    actionStatsPadding.Parent = actionStatsFrame

    local collectVal = makeStatCard("COLLECTED", 1, actionStatsFrame)
    local sellVal = makeStatCard("SOLD", 2, actionStatsFrame)
    local auroraVal = makeStatCard("AURORA", 3, actionStatsFrame)
    local buySeedVal = makeStatCard("SEEDS BOUGHT", 4, actionStatsFrame)

    -- ═══════════════════════════════════════════
    -- ACTIONS TAB
    -- ═══════════════════════════════════════════
    label({
        Parent = actionsTab, Text = "Actions", Position = UDim2.new(0, 12, 0, 16),
        Size = UDim2.new(1, -24, 0, 24), TextSize = 18, Font = Enum.Font.GothamBold, Color = theme.text,
    })
    label({
        Parent = actionsTab, Text = "Keep each automation toggle separate.", Position = UDim2.new(0, 12, 0, 40),
        Size = UDim2.new(1, -24, 0, 16), TextSize = 10, Color = theme.dim,
    })

    local actionCard = Instance.new("Frame")
    actionCard.Size = UDim2.new(1, -24, 0, 248)
    actionCard.Position = UDim2.new(0, 12, 0, 64)
    actionCard.BackgroundColor3 = theme.panel
    actionCard.BackgroundTransparency = 0.35
    actionCard.BorderSizePixel = 0
    actionCard.Parent = actionsTab
    shared.corner(actionCard, UDim.new(0, 10))
    shared.stroke(actionCard, theme.divider or theme.panel2, 1, 0.5)

    local actionCardPad = Instance.new("UIPadding")
    actionCardPad.PaddingTop = UDim.new(0, 10)
    actionCardPad.PaddingBottom = UDim.new(0, 10)
    actionCardPad.PaddingLeft = UDim.new(0, 10)
    actionCardPad.PaddingRight = UDim.new(0, 10)
    actionCardPad.Parent = actionCard

    local actionRows = Instance.new("Frame")
    actionRows.Size = UDim2.new(1, 0, 1, 0)
    actionRows.BackgroundTransparency = 1
    actionRows.Parent = actionCard

    local actionList = Instance.new("UIListLayout")
    actionList.Padding = UDim.new(0, 8)
    actionList.SortOrder = Enum.SortOrder.LayoutOrder
    actionList.Parent = actionRows

    local function makeIntervalSetting(labelText, placeholder, default, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.Parent = actionRows

        label({
            Parent = row, Text = labelText, Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, -92, 1, 0), TextSize = 10, Color = theme.dim,
        })

        return components.textinput({
            Parent = row, Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(1, -80, 0, 0),
            Default = default or "", Placeholder = placeholder, CornerRadius = UDim.new(0, 6),
        })
    end

    local collectIntervalInput = makeIntervalSetting("Collect interval (s)", "2", "2", 1)
    local sellIntervalInput = makeIntervalSetting("Sell interval (s)", "5", "5", 2)
    local auroraIntervalInput = makeIntervalSetting("Aurora interval (s)", "5", "5", 3)

    -- Action toggle buttons: kept as raw TextButtons (LyraHub-styled) because the
    -- modules bind MouseButton1Click and core.setButtonState writes Text/Color
    -- directly; hover/press only animate scale + transparency, never the color.
    local function makeActionButton(text, order, color)
        local shell = Instance.new("Frame")
        shell.Size = UDim2.new(1, 0, 0, 34)
        shell.BackgroundColor3 = theme.panel2
        shell.BorderSizePixel = 0
        shell.LayoutOrder = order
        shell.Parent = actionRows
        shared.corner(shell, UDim.new(0, 9))
        shared.stroke(shell, theme.divider or theme.panel2, 1, 0.5)

        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 4, 1, -10)
        accent.Position = UDim2.new(0, 8, 0.5, 0)
        accent.AnchorPoint = Vector2.new(0, 0.5)
        accent.BackgroundColor3 = color
        accent.BorderSizePixel = 0
        accent.Parent = shell
        shared.corner(accent, UDim.new(1, 0))

        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 1, 0)
        button.BackgroundTransparency = 1
        button.AutoButtonColor = false
        button.BackgroundColor3 = color
        button.Text = text
        button.TextColor3 = theme.text
        button.Font = Enum.Font.GothamBold
        button.TextSize = 11
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.BorderSizePixel = 0
        button.ClipsDescendants = true
        button.Parent = shell

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 24)
        padding.PaddingRight = UDim.new(0, 12)
        padding.PaddingTop = UDim.new(0, 1)
        padding.Parent = button

        local scale = Instance.new("UIScale")
        scale.Parent = button

        -- State color: the button body is transparent, so make the accent bar
        -- follow the button's BackgroundColor3 (written by core.setButtonState)
        -- so toggling ON/OFF visibly flips the accent between success/danger.
        accent.BackgroundColor3 = button.BackgroundColor3
        button:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            shared.tween(accent, { BackgroundColor3 = button.BackgroundColor3 }, 0.15)
        end)

        -- Hover: slight lift + dim, never touching the state color
        button.MouseEnter:Connect(function()
            shared.tween(scale, { Scale = 1.02 }, 0.12)
            shared.tween(button, { BackgroundTransparency = 0.18 }, 0.12)
        end)
        button.MouseLeave:Connect(function()
            shared.tween(scale, { Scale = 1 }, 0.18)
            shared.tween(button, { BackgroundTransparency = 1 }, 0.18)
        end)
        button.MouseButton1Down:Connect(function()
            shared.tween(scale, { Scale = 0.97 }, 0.06)
        end)
        button.MouseButton1Up:Connect(function()
            shared.tween(scale, { Scale = 1 }, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end)

        return button
    end

    local collectButton = makeActionButton("Collect: OFF", 4, theme.danger)
    local sellButton = makeActionButton("Sell: OFF", 5, theme.danger)
    local depositAuroraButton = makeActionButton("Aurora: OFF", 6, theme.danger)

    -- ═══════════════════════════════════════════
    -- BUY TAB
    -- ═══════════════════════════════════════════
    label({
        Parent = buyTab, Text = "Buy", Position = UDim2.new(0, 12, 0, 24),
        Size = UDim2.new(1, -24, 0, 26), TextSize = 18, Font = Enum.Font.GothamBold, Color = theme.text,
    })

    local buyCard = Instance.new("Frame")
    buyCard.Size = UDim2.new(1, -24, 0, 220)
    buyCard.Position = UDim2.new(0, 12, 0, 60)
    buyCard.BackgroundColor3 = theme.panel
    buyCard.BackgroundTransparency = 0.35
    buyCard.BorderSizePixel = 0
    buyCard.Parent = buyTab
    shared.corner(buyCard, UDim.new(0, 10))
    shared.stroke(buyCard, theme.divider or theme.panel2, 1, 0.5)

    local buyPad = Instance.new("UIPadding")
    buyPad.PaddingTop = UDim.new(0, 10)
    buyPad.PaddingBottom = UDim.new(0, 10)
    buyPad.PaddingLeft = UDim.new(0, 10)
    buyPad.PaddingRight = UDim.new(0, 10)
    buyPad.Parent = buyCard

    local buyRows = Instance.new("Frame")
    buyRows.Size = UDim2.new(1, 0, 1, 0)
    buyRows.BackgroundTransparency = 1
    buyRows.Parent = buyCard

    local buyList = Instance.new("UIListLayout")
    buyList.Padding = UDim.new(0, 8)
    buyList.SortOrder = Enum.SortOrder.LayoutOrder
    buyList.Parent = buyRows

    label({
        Parent = buyRows, Text = "Buys selected seed every interval. If stock value is missing, it still attempts to buy.",
        Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 30), TextSize = 10,
        Color = theme.dim, Wrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1,
    })

    local buySeedRow = Instance.new("Frame")
    buySeedRow.Size = UDim2.new(1, 0, 0, 28)
    buySeedRow.BackgroundTransparency = 1
    buySeedRow.LayoutOrder = 2
    buySeedRow.Parent = buyRows

    label({
        Parent = buySeedRow, Text = "Flower/Seed Id", Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, -92, 1, 0), TextSize = 10, Color = theme.dim,
    })
    local buySeedInput = components.textinput({
        Parent = buySeedRow, Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(1, -80, 0, 0),
        Default = "Bamboo", Placeholder = "Bamboo", CornerRadius = UDim.new(0, 6),
    })

    local buyIntervalRow = Instance.new("Frame")
    buyIntervalRow.Size = UDim2.new(1, 0, 0, 28)
    buyIntervalRow.BackgroundTransparency = 1
    buyIntervalRow.LayoutOrder = 3
    buyIntervalRow.Parent = buyRows

    label({
        Parent = buyIntervalRow, Text = "Buy interval (s)", Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, -92, 1, 0), TextSize = 10, Color = theme.dim,
    })
    local buySeedIntervalInput = components.textinput({
        Parent = buyIntervalRow, Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(1, -80, 0, 0),
        Default = "120", Placeholder = "120", CornerRadius = UDim.new(0, 6),
    })

    -- Buy Seed toggle (raw + LyraHub-styled, same as the action buttons; the
    -- auto_buy_seed module anchors its flower checklist to this button)
    local buyButtonShell = Instance.new("Frame")
    buyButtonShell.Size = UDim2.new(1, 0, 0, 34)
    buyButtonShell.BackgroundColor3 = theme.panel2
    buyButtonShell.BorderSizePixel = 0
    buyButtonShell.LayoutOrder = 4
    buyButtonShell.Parent = buyRows
    shared.corner(buyButtonShell, UDim.new(0, 9))
    shared.stroke(buyButtonShell, theme.divider or theme.panel2, 1, 0.5)

    local buyButtonAccent = Instance.new("Frame")
    buyButtonAccent.Size = UDim2.new(0, 4, 1, -10)
    buyButtonAccent.Position = UDim2.new(0, 8, 0.5, 0)
    buyButtonAccent.AnchorPoint = Vector2.new(0, 0.5)
    buyButtonAccent.BackgroundColor3 = theme.danger
    buyButtonAccent.BorderSizePixel = 0
    buyButtonAccent.Parent = buyButtonShell
    shared.corner(buyButtonAccent, UDim.new(1, 0))

    local buySeedButton = Instance.new("TextButton")
    buySeedButton.Size = UDim2.new(1, 0, 1, 0)
    buySeedButton.BackgroundTransparency = 1
    buySeedButton.AutoButtonColor = false
    buySeedButton.BackgroundColor3 = theme.danger
    buySeedButton.Text = "Buy Seed: OFF"
    buySeedButton.TextColor3 = theme.text
    buySeedButton.Font = Enum.Font.GothamBold
    buySeedButton.TextSize = 11
    buySeedButton.TextXAlignment = Enum.TextXAlignment.Left
    buySeedButton.BorderSizePixel = 0
    buySeedButton.ClipsDescendants = true
    buySeedButton.Parent = buyButtonShell

    local buySeedButtonPadding = Instance.new("UIPadding")
    buySeedButtonPadding.PaddingLeft = UDim.new(0, 24)
    buySeedButtonPadding.PaddingRight = UDim.new(0, 12)
    buySeedButtonPadding.PaddingTop = UDim.new(0, 1)
    buySeedButtonPadding.Parent = buySeedButton

    -- Same state-color treatment: the accent bar follows the button's color
    buyButtonAccent.BackgroundColor3 = buySeedButton.BackgroundColor3
    buySeedButton:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
        shared.tween(buyButtonAccent, { BackgroundColor3 = buySeedButton.BackgroundColor3 }, 0.15)
    end)

    local buyScale = Instance.new("UIScale")
    buyScale.Parent = buySeedButton
    buySeedButton.MouseEnter:Connect(function()
        shared.tween(buyScale, { Scale = 1.02 }, 0.12)
        shared.tween(buySeedButton, { BackgroundTransparency = 0.18 }, 0.12)
    end)
    buySeedButton.MouseLeave:Connect(function()
        shared.tween(buyScale, { Scale = 1 }, 0.18)
        shared.tween(buySeedButton, { BackgroundTransparency = 1 }, 0.18)
    end)
    buySeedButton.MouseButton1Down:Connect(function()
        shared.tween(buyScale, { Scale = 0.97 }, 0.06)
    end)
    buySeedButton.MouseButton1Up:Connect(function()
        shared.tween(buyScale, { Scale = 1 }, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)

    -- Flower checklist host: auto_buy_seed fills this with the checkbox rows.
    -- (Previously the checklist was anchored below the toggle inside the card,
    -- where content.ClipsDescendants cut it off — the "list not shown" bug.)
    local flowerCheckListHost = Instance.new("Frame")
    flowerCheckListHost.Name = "FlowerCheckListHost"
    flowerCheckListHost.Size = UDim2.new(1, -24, 0, 236)
    flowerCheckListHost.Position = UDim2.new(0, 12, 0, 296)
    flowerCheckListHost.BackgroundColor3 = theme.panel
    flowerCheckListHost.BackgroundTransparency = 0.35
    flowerCheckListHost.BorderSizePixel = 0
    flowerCheckListHost.Parent = buyTab
    shared.corner(flowerCheckListHost, UDim.new(0, 10))
    shared.stroke(flowerCheckListHost, theme.divider or theme.panel2, 1, 0.5)

    -- ═══════════════════════════════════════════
    -- MINIMIZED PANEL (header + 2 rows of stat cards)
    -- ═══════════════════════════════════════════
    local mini = Instance.new("Frame")
    mini.Name = "MinimizedPanel"
    mini.Size = UDim2.new(0, 260, 0, 112)
    mini.Position = UDim2.new(0, 20, 0, 20)
    mini.BackgroundColor3 = theme.bg
    mini.BorderSizePixel = 0
    mini.Visible = false
    mini.Active = true
    mini.ZIndex = 5
    mini.Parent = screenGui
    shared.corner(mini, UDim.new(0, 12))
    shared.stroke(mini, theme.accent, 1, 0.4)
    shared.glow(mini, theme.glow or theme.accent, 3, 0.9)

    local miniLogo = Instance.new("Frame")
    miniLogo.Size = UDim2.fromOffset(6, 6)
    miniLogo.Position = UDim2.new(0, 12, 0, 10)
    miniLogo.BackgroundColor3 = theme.accent
    miniLogo.BorderSizePixel = 0
    miniLogo.Parent = mini
    shared.corner(miniLogo, UDim.new(1, 0))
    shared.glow(miniLogo, theme.glow or theme.accent, 2, 0.5)

    local miniHeader = label({
        Parent = mini, Text = config.Window.Title, Position = UDim2.new(0, 24, 0, 4),
        Size = UDim2.new(1, -56, 0, 16), TextSize = 10, Font = Enum.Font.GothamBold, Color = theme.text,
    })

    local miniExpand = components.button({
        Parent = mini, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -26, 0, 3),
        Text = "▢", TextSize = 11, Color = theme.panel2, TextColor = theme.dim,
        HoverColor = theme.accent2, CornerRadius = UDim.new(0, 6), ZIndex = 3, Glow = false,
    })

    local miniDragHit = Instance.new("TextButton")
    miniDragHit.Size = UDim2.new(1, -32, 0, 26)
    miniDragHit.BackgroundTransparency = 1
    miniDragHit.Text = ""
    miniDragHit.AutoButtonColor = false
    miniDragHit.BorderSizePixel = 0
    miniDragHit.Parent = mini

    local function makeMiniCard(labelText, order, parent)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 56, 1, 0)
        card.BackgroundColor3 = theme.panel2
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.Parent = parent or miniCards
        shared.corner(card, UDim.new(0, 6))
        shared.stroke(card, theme.divider or theme.panel2, 1, 0.5)

        label({
            Parent = card, Text = labelText, Position = UDim2.new(0, 2, 0, 2),
            Size = UDim2.new(1, -4, 0, 10), TextSize = 7, Color = theme.dim,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        return label({
            Parent = card, Text = "0", Position = UDim2.new(0, 2, 0, 14),
            Size = UDim2.new(1, -4, 0, 18), TextSize = 13, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end

    local miniCards = Instance.new("Frame")
    miniCards.Size = UDim2.new(1, -16, 0, 36)
    miniCards.Position = UDim2.new(0, 8, 0, 24)
    miniCards.BackgroundTransparency = 1
    miniCards.Parent = mini

    local miniLayout = Instance.new("UIListLayout")
    miniLayout.FillDirection = Enum.FillDirection.Horizontal
    miniLayout.Padding = UDim.new(0, 4)
    miniLayout.SortOrder = Enum.SortOrder.LayoutOrder
    miniLayout.Parent = miniCards

    local miniFps = makeMiniCard("FPS", 1)
    local miniPing = makeMiniCard("PING", 2)
    local miniPlayers = makeMiniCard("PLAYERS", 3)
    local miniHive = makeMiniCard("HIVE", 4)

    -- Second row: action counters (fed by ctx.counts via core.lua updateStats)
    local miniActionCards = Instance.new("Frame")
    miniActionCards.Size = UDim2.new(1, -16, 0, 36)
    miniActionCards.Position = UDim2.new(0, 8, 0, 66)
    miniActionCards.BackgroundTransparency = 1
    miniActionCards.Parent = mini

    local miniActionLayout = Instance.new("UIListLayout")
    miniActionLayout.FillDirection = Enum.FillDirection.Horizontal
    miniActionLayout.Padding = UDim.new(0, 4)
    miniActionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    miniActionLayout.Parent = miniActionCards

    local miniCollectVal = makeMiniCard("COLL", 1, miniActionCards)
    local miniSellVal = makeMiniCard("SELL", 2, miniActionCards)
    local miniAuroraVal = makeMiniCard("AURA", 3, miniActionCards)
    local miniBuySeedVal = makeMiniCard("SEED", 4, miniActionCards)

    -- Wire tab clicks (core also binds these via gui.TabButtons — idempotent)
    tabOverviewBtn.MouseButton1Click:Connect(function()
        setTab("Overview")
    end)
    tabActionsBtn.MouseButton1Click:Connect(function()
        setTab("Actions")
    end)
    tabBuyBtn.MouseButton1Click:Connect(function()
        setTab("Buy")
    end)

    setTab("Overview")

    return {
        Theme = theme,
        ScreenGui = screenGui,
        Main = main,
        Frame = main,
        Shadow = shadow,
        SetTab = setTab,
        TabButtons = {
            Overview = tabOverviewBtn,
            Actions = tabActionsBtn,
            Buy = tabBuyBtn,
        },
        MinBtn = minBtn.Instance,
        CloseBtn = closeBtn.Instance,
        DragHit = dragHit,
        StatusLbl = status,
        Stats = {
            FPSVal = fpsValue,
            PingVal = pingValue,
            PlayerCountVal = playerCountValue,
            TotalHiveVal = totalHiveValue,
        },
        ActionStats = {
            CollectVal = collectVal,
            SellVal = sellVal,
            AuroraVal = auroraVal,
            BuySeedVal = buySeedVal,
        },
        ResetCountersBtn = resetCountersBtn.Instance,
        CollectButton = collectButton,
        SellButton = sellButton,
        DepositAuroraButton = depositAuroraButton,
        BuySeedButton = buySeedButton,
        CollectIntervalInput = collectIntervalInput,
        SellIntervalInput = sellIntervalInput,
        AuroraIntervalInput = auroraIntervalInput,
        BuySeedIntervalInput = buySeedIntervalInput,
        BuySeedInput = buySeedInput,
        FlowerCheckListHost = flowerCheckListHost,
        MinimizedPanel = mini,
        MiniHeader = miniHeader,
        MiniExpand = miniExpand.Instance,
        MiniDragHit = miniDragHit,
        MiniStats = {
            FPSVal = miniFps,
            PingVal = miniPing,
            PlayerCountVal = miniPlayers,
            TotalHiveVal = miniHive,
        },
        MiniActionStats = {
            CollectVal = miniCollectVal,
            SellVal = miniSellVal,
            AuroraVal = miniAuroraVal,
            BuySeedVal = miniBuySeedVal,
        },
    }
end
