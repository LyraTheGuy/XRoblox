-- BuildABeehive/gui.lua
-- IndoVoice-style split layout with real tabs, a clean overview, and a simple actions pane.

return function(config)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local theme = config.Theme or {}

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

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 620, 0, 420)
    main.Position = UDim2.new(0.5, -310, 0.5, -210)
    main.BackgroundColor3 = theme.bg or Color3.fromRGB(18, 18, 24)
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = screenGui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    local mainStroke = Instance.new("UIStroke", main)
    mainStroke.Color = theme.accent or Color3.fromRGB(80, 180, 255)
    mainStroke.Transparency = 0.25
    mainStroke.Thickness = 1

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 36)
    topBar.BackgroundColor3 = theme.topbar or Color3.fromRGB(20, 20, 28)
    topBar.BorderSizePixel = 0
    topBar.Active = true
    topBar.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 200, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Build A Beehive"
    title.TextColor3 = theme.text or Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0, 300, 1, 0)
    subtitle.Position = UDim2.new(0, 14, 0, 14)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Clean honey tools with the same wide layout as IndoVoice"
    subtitle.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 9
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = topBar

    local minBtn = Instance.new("TextButton")
    minBtn.Text = "-"
    minBtn.Size = UDim2.new(0, 28, 0, 22)
    minBtn.Position = UDim2.new(1, -64, 0, 6)
    minBtn.BackgroundColor3 = theme.panel2 or Color3.fromRGB(40, 40, 52)
    minBtn.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.BorderSizePixel = 0
    minBtn.Parent = topBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "x"
    closeBtn.Size = UDim2.new(0, 28, 0, 22)
    closeBtn.Position = UDim2.new(1, -32, 0, 6)
    closeBtn.BackgroundColor3 = theme.danger or Color3.fromRGB(255, 80, 100)
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = topBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    local dragHit = Instance.new("TextButton")
    dragHit.Size = UDim2.new(1, -96, 1, 0)
    dragHit.BackgroundTransparency = 1
    dragHit.Text = ""
    dragHit.Parent = topBar

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 130, 1, -36)
    sidebar.Position = UDim2.new(0, 0, 0, 36)
    sidebar.BackgroundColor3 = theme.sidebar or theme.bg2 or Color3.fromRGB(22, 22, 30)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main

    local sideTitle = Instance.new("TextLabel")
    sideTitle.Size = UDim2.new(1, 0, 0, 32)
    sideTitle.Position = UDim2.new(0, 0, 0, 10)
    sideTitle.BackgroundTransparency = 1
    sideTitle.Text = "Beehive"
    sideTitle.TextColor3 = theme.text or Color3.new(1, 1, 1)
    sideTitle.Font = Enum.Font.GothamBold
    sideTitle.TextSize = 15
    sideTitle.Parent = sidebar

    local sideSub = Instance.new("TextLabel")
    sideSub.Size = UDim2.new(1, 0, 0, 14)
    sideSub.Position = UDim2.new(0, 0, 0, 42)
    sideSub.BackgroundTransparency = 1
    sideSub.Text = "Auto tools"
    sideSub.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    sideSub.Font = Enum.Font.Gotham
    sideSub.TextSize = 10
    sideSub.Parent = sidebar

    local sidebarLine = Instance.new("Frame")
    sidebarLine.Size = UDim2.new(0.72, 0, 0, 1)
    sidebarLine.AnchorPoint = Vector2.new(0.5, 0)
    sidebarLine.Position = UDim2.new(0.5, 0, 0, 64)
    sidebarLine.BackgroundColor3 = theme.panel2 or Color3.fromRGB(40, 40, 52)
    sidebarLine.BorderSizePixel = 0
    sidebarLine.Parent = sidebar

    local tabOverviewBtn = Instance.new("TextButton")
    tabOverviewBtn.Size = UDim2.new(1, -16, 0, 34)
    tabOverviewBtn.Position = UDim2.new(0, 8, 0, 76)
    tabOverviewBtn.BackgroundColor3 = theme.accent or Color3.fromRGB(80, 180, 255)
    tabOverviewBtn.BackgroundTransparency = 0.1
    tabOverviewBtn.Text = "Overview"
    tabOverviewBtn.TextColor3 = theme.text or Color3.new(1, 1, 1)
    tabOverviewBtn.Font = Enum.Font.GothamBold
    tabOverviewBtn.TextSize = 12
    tabOverviewBtn.BorderSizePixel = 0
    tabOverviewBtn.Parent = sidebar
    Instance.new("UICorner", tabOverviewBtn).CornerRadius = UDim.new(0, 8)

    local tabActionsBtn = Instance.new("TextButton")
    tabActionsBtn.Size = UDim2.new(1, -16, 0, 34)
    tabActionsBtn.Position = UDim2.new(0, 8, 0, 118)
    tabActionsBtn.BackgroundColor3 = theme.panel2 or Color3.fromRGB(40, 40, 52)
    tabActionsBtn.Text = "Actions"
    tabActionsBtn.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    tabActionsBtn.Font = Enum.Font.GothamBold
    tabActionsBtn.TextSize = 12
    tabActionsBtn.BorderSizePixel = 0
    tabActionsBtn.Parent = sidebar
    Instance.new("UICorner", tabActionsBtn).CornerRadius = UDim.new(0, 8)

    local tabBuyBtn = Instance.new("TextButton")
    tabBuyBtn.Size = UDim2.new(1, -16, 0, 34)
    tabBuyBtn.Position = UDim2.new(0, 8, 0, 160)
    tabBuyBtn.BackgroundColor3 = theme.panel2 or Color3.fromRGB(40, 40, 52)
    tabBuyBtn.Text = "Buy"
    tabBuyBtn.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    tabBuyBtn.Font = Enum.Font.GothamBold
    tabBuyBtn.TextSize = 12
    tabBuyBtn.BorderSizePixel = 0
    tabBuyBtn.Parent = sidebar
    Instance.new("UICorner", tabBuyBtn).CornerRadius = UDim.new(0, 8)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -142, 1, -48)
    content.Position = UDim2.new(0, 136, 0, 42)
    content.BackgroundColor3 = theme.panel or Color3.fromRGB(24, 24, 32)
    content.BorderSizePixel = 0
    content.ClipsDescendants = true
    content.Parent = main
    Instance.new("UICorner", content).CornerRadius = UDim.new(0, 10)

    local contentStroke = Instance.new("UIStroke", content)
    contentStroke.Color = theme.panel2 or Color3.fromRGB(40, 40, 52)
    contentStroke.Thickness = 1

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

    local buyTab = Instance.new("Frame")
    buyTab.Name = "BuyTab"
    buyTab.Size = UDim2.new(1, 0, 1, 0)
    buyTab.BackgroundTransparency = 1
    buyTab.Visible = false
    buyTab.Parent = content

    local function applyTab(activeTab)
        local showOverview = activeTab == "Overview"
        local showActions = activeTab == "Actions"
        local showBuy = activeTab == "Buy"
        overviewTab.Visible = showOverview
        actionsTab.Visible = showActions
        buyTab.Visible = showBuy

        tabOverviewBtn.BackgroundColor3 = showOverview and (theme.accent or Color3.fromRGB(80, 180, 255)) or (theme.panel2 or Color3.fromRGB(40, 40, 52))
        tabOverviewBtn.BackgroundTransparency = showOverview and 0.1 or 0
        tabOverviewBtn.TextColor3 = showOverview and (theme.text or Color3.new(1, 1, 1)) or (theme.dim or Color3.fromRGB(130, 130, 145))

        tabActionsBtn.BackgroundColor3 = showActions and (theme.accent or Color3.fromRGB(80, 180, 255)) or (theme.panel2 or Color3.fromRGB(40, 40, 52))
        tabActionsBtn.BackgroundTransparency = showActions and 0.1 or 0
        tabActionsBtn.TextColor3 = showActions and (theme.text or Color3.new(1, 1, 1)) or (theme.dim or Color3.fromRGB(130, 130, 145))

        tabBuyBtn.BackgroundColor3 = showBuy and (theme.accent or Color3.fromRGB(80, 180, 255)) or (theme.panel2 or Color3.fromRGB(40, 40, 52))
        tabBuyBtn.BackgroundTransparency = showBuy and 0.1 or 0
        tabBuyBtn.TextColor3 = showBuy and (theme.text or Color3.new(1, 1, 1)) or (theme.dim or Color3.fromRGB(130, 130, 145))
    end

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -24, 0, 18)
    status.Position = UDim2.new(0, 12, 0, 10)
    status.BackgroundTransparency = 1
    status.Text = "Status: OFF"
    status.TextColor3 = theme.danger or Color3.fromRGB(255, 80, 80)
    status.Font = Enum.Font.GothamBold
    status.TextSize = 13
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = overviewTab

    local hero = Instance.new("TextLabel")
    hero.Size = UDim2.new(1, -24, 0, 26)
    hero.Position = UDim2.new(0, 12, 0, 34)
    hero.BackgroundTransparency = 1
    hero.Text = "Automation dashboard"
    hero.TextColor3 = theme.text or Color3.new(1, 1, 1)
    hero.Font = Enum.Font.GothamBold
    hero.TextSize = 18
    hero.TextXAlignment = Enum.TextXAlignment.Left
    hero.Parent = overviewTab

    local helper = Instance.new("TextLabel")
    helper.Size = UDim2.new(1, -24, 0, 16)
    helper.Position = UDim2.new(0, 12, 0, 58)
    helper.BackgroundTransparency = 1
    helper.Text = "Stats at a glance. Actions on the next tab."
    helper.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    helper.Font = Enum.Font.Gotham
    helper.TextSize = 10
    helper.TextXAlignment = Enum.TextXAlignment.Left
    helper.Parent = overviewTab

    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(0, 300, 0, 118)
    statsFrame.Position = UDim2.new(0, 12, 0, 82)
    statsFrame.BackgroundColor3 = theme.panel or Color3.fromRGB(24, 24, 32)
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = overviewTab
    Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 10)

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
        card.BackgroundColor3 = theme.panel2 or Color3.fromRGB(34, 34, 44)
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.Parent = parent or statsFrame
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -8, 0, 12)
        label.Position = UDim2.new(0, 4, 0, 4)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
        label.Font = Enum.Font.Gotham
        label.TextSize = 9
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = card

        local value = Instance.new("TextLabel")
        value.Size = UDim2.new(1, -8, 0, 18)
        value.Position = UDim2.new(0, 4, 0, 18)
        value.BackgroundTransparency = 1
        value.Text = "0"
        value.TextColor3 = theme.text or Color3.new(1, 1, 1)
        value.Font = Enum.Font.GothamBold
        value.TextSize = 14
        value.TextXAlignment = Enum.TextXAlignment.Left
        value.Parent = card

        return value
    end

    local fpsValue = makeStatCard("FPS", 1)
    local pingValue = makeStatCard("PING", 2)
    local playerCountValue = makeStatCard("PLAYER COUNT", 3)
    local totalHiveValue = makeStatCard("TOTAL HIVE", 4)

    -- Action counters section (fed by ctx.counts via core.lua updateStats)
    local actionTitle = Instance.new("TextLabel")
    actionTitle.Size = UDim2.new(1, -24, 0, 14)
    actionTitle.Position = UDim2.new(0, 12, 0, 210)
    actionTitle.BackgroundTransparency = 1
    actionTitle.Text = "ACTIONS PERFORMED"
    actionTitle.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    actionTitle.Font = Enum.Font.GothamBold
    actionTitle.TextSize = 9
    actionTitle.TextXAlignment = Enum.TextXAlignment.Left
    actionTitle.Parent = overviewTab

    local resetCountersBtn = Instance.new("TextButton")
    resetCountersBtn.Text = "Reset"
    resetCountersBtn.Size = UDim2.new(0, 56, 0, 18)
    resetCountersBtn.Position = UDim2.new(1, -68, 0, 210)
    resetCountersBtn.BackgroundColor3 = theme.panel2 or Color3.fromRGB(40, 40, 52)
    resetCountersBtn.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    resetCountersBtn.Font = Enum.Font.GothamBold
    resetCountersBtn.TextSize = 9
    resetCountersBtn.BorderSizePixel = 0
    resetCountersBtn.Parent = overviewTab
    Instance.new("UICorner", resetCountersBtn).CornerRadius = UDim.new(0, 6)

    local actionStatsFrame = Instance.new("Frame")
    actionStatsFrame.Size = UDim2.new(0, 300, 0, 118)
    actionStatsFrame.Position = UDim2.new(0, 12, 0, 228)
    actionStatsFrame.BackgroundColor3 = theme.panel or Color3.fromRGB(24, 24, 32)
    actionStatsFrame.BorderSizePixel = 0
    actionStatsFrame.Parent = overviewTab
    Instance.new("UICorner", actionStatsFrame).CornerRadius = UDim.new(0, 10)

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

    local actionHeader = Instance.new("TextLabel")
    actionHeader.Size = UDim2.new(1, -24, 0, 24)
    actionHeader.Position = UDim2.new(0, 12, 0, 16)
    actionHeader.BackgroundTransparency = 1
    actionHeader.Text = "Actions"
    actionHeader.TextColor3 = theme.text or Color3.new(1, 1, 1)
    actionHeader.Font = Enum.Font.GothamBold
    actionHeader.TextSize = 18
    actionHeader.TextXAlignment = Enum.TextXAlignment.Left
    actionHeader.Parent = actionsTab

    local actionSub = Instance.new("TextLabel")
    actionSub.Size = UDim2.new(1, -24, 0, 16)
    actionSub.Position = UDim2.new(0, 12, 0, 40)
    actionSub.BackgroundTransparency = 1
    actionSub.Text = "Keep each automation toggle separate."
    actionSub.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    actionSub.Font = Enum.Font.Gotham
    actionSub.TextSize = 10
    actionSub.TextXAlignment = Enum.TextXAlignment.Left
    actionSub.Parent = actionsTab

    local actionCard = Instance.new("Frame")
    actionCard.Size = UDim2.new(1, -24, 0, 248)
    actionCard.Position = UDim2.new(0, 12, 0, 64)
    actionCard.BackgroundColor3 = theme.panel or Color3.fromRGB(24, 24, 32)
    actionCard.BorderSizePixel = 0
    actionCard.Parent = actionsTab
    Instance.new("UICorner", actionCard).CornerRadius = UDim.new(0, 10)

    local actionCardStroke = Instance.new("UIStroke", actionCard)
    actionCardStroke.Color = theme.panel2 or Color3.fromRGB(40, 40, 52)
    actionCardStroke.Thickness = 1

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

    local function makeIntervalSetting(labelText, placeholder, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.Parent = actionRows

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -92, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
        label.Font = Enum.Font.Gotham
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        local input = Instance.new("TextBox")
        input.Size = UDim2.new(0, 80, 1, 0)
        input.Position = UDim2.new(1, -80, 0, 0)
        input.BackgroundColor3 = theme.bg2 or Color3.fromRGB(22, 22, 30)
        input.TextColor3 = theme.text or Color3.new(1, 1, 1)
        input.PlaceholderText = placeholder
        input.PlaceholderColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
        input.ClearTextOnFocus = false
        input.Font = Enum.Font.Code
        input.TextSize = 11
        input.TextXAlignment = Enum.TextXAlignment.Center
        input.BorderSizePixel = 0
        input.Parent = row
        Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)

        return label, input
    end

    local collectIntervalLbl, collectIntervalInput = makeIntervalSetting("Collect interval (s)", "2", 1)
    local sellIntervalLbl, sellIntervalInput = makeIntervalSetting("Sell interval (s)", "5", 2)
    local auroraIntervalLbl, auroraIntervalInput = makeIntervalSetting("Aurora interval (s)", "5", 3)

    local function makeActionButton(text, order, color)
        local shell = Instance.new("Frame")
        shell.Size = UDim2.new(1, 0, 0, 34)
        shell.BackgroundColor3 = theme.panel2 or Color3.fromRGB(40, 40, 52)
        shell.BorderSizePixel = 0
        shell.LayoutOrder = order
        shell.Parent = actionRows
        Instance.new("UICorner", shell).CornerRadius = UDim.new(0, 9)

        local shellStroke = Instance.new("UIStroke", shell)
        shellStroke.Color = theme.panel2 or Color3.fromRGB(40, 40, 52)
        shellStroke.Thickness = 1

        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 4, 1, -10)
        accent.Position = UDim2.new(0, 8, 0.5, 0)
        accent.AnchorPoint = Vector2.new(0, 0.5)
        accent.BackgroundColor3 = color
        accent.BorderSizePixel = 0
        accent.Parent = shell
        Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 1, 0)
        button.BackgroundTransparency = 1
        button.AutoButtonColor = false
        button.BackgroundColor3 = color
        button.Text = text
        button.TextColor3 = theme.text or Color3.new(1, 1, 1)
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

        return button
    end

    local collectButton = makeActionButton("Collect: OFF", 4, theme.danger or Color3.fromRGB(180, 60, 60))
    local sellButton = makeActionButton("Sell: OFF", 5, theme.danger or Color3.fromRGB(180, 60, 60))
    local depositAuroraButton = makeActionButton("Aurora: OFF", 6, theme.danger or Color3.fromRGB(180, 60, 60))

    local buyTitle = Instance.new("TextLabel")
    buyTitle.Size = UDim2.new(1, -24, 0, 26)
    buyTitle.Position = UDim2.new(0, 12, 0, 24)
    buyTitle.BackgroundTransparency = 1
    buyTitle.Text = "Buy"
    buyTitle.TextColor3 = theme.text or Color3.new(1, 1, 1)
    buyTitle.Font = Enum.Font.GothamBold
    buyTitle.TextSize = 18
    buyTitle.TextXAlignment = Enum.TextXAlignment.Left
    buyTitle.Parent = buyTab

    local buyCard = Instance.new("Frame")
    buyCard.Size = UDim2.new(1, -24, 0, 220)
    buyCard.Position = UDim2.new(0, 12, 0, 60)
    buyCard.BackgroundColor3 = theme.panel or Color3.fromRGB(24, 24, 32)
    buyCard.BorderSizePixel = 0
    buyCard.Parent = buyTab
    Instance.new("UICorner", buyCard).CornerRadius = UDim.new(0, 10)

    local buyCardStroke = Instance.new("UIStroke", buyCard)
    buyCardStroke.Color = theme.panel2 or Color3.fromRGB(40, 40, 52)
    buyCardStroke.Thickness = 1

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

    local buyInfo = Instance.new("TextLabel")
    buyInfo.Size = UDim2.new(1, 0, 0, 30)
    buyInfo.BackgroundTransparency = 1
    buyInfo.LayoutOrder = 1
    buyInfo.Text = "Buys selected seed every interval. If stock value is missing, it still attempts to buy."
    buyInfo.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    buyInfo.Font = Enum.Font.Gotham
    buyInfo.TextSize = 10
    buyInfo.TextWrapped = true
    buyInfo.TextXAlignment = Enum.TextXAlignment.Left
    buyInfo.TextYAlignment = Enum.TextYAlignment.Top
    buyInfo.Parent = buyRows

    local buySeedRow = Instance.new("Frame")
    buySeedRow.Size = UDim2.new(1, 0, 0, 28)
    buySeedRow.BackgroundTransparency = 1
    buySeedRow.LayoutOrder = 2
    buySeedRow.Parent = buyRows

    local buySeedLbl = Instance.new("TextLabel")
    buySeedLbl.Size = UDim2.new(1, -92, 1, 0)
    buySeedLbl.BackgroundTransparency = 1
    buySeedLbl.Text = "Flower/Seed Id"
    buySeedLbl.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    buySeedLbl.Font = Enum.Font.Gotham
    buySeedLbl.TextSize = 10
    buySeedLbl.TextXAlignment = Enum.TextXAlignment.Left
    buySeedLbl.Parent = buySeedRow

    local buySeedInput = Instance.new("TextBox")
    buySeedInput.Size = UDim2.new(0, 80, 1, 0)
    buySeedInput.Position = UDim2.new(1, -80, 0, 0)
    buySeedInput.BackgroundColor3 = theme.bg2 or Color3.fromRGB(22, 22, 30)
    buySeedInput.TextColor3 = theme.text or Color3.new(1, 1, 1)
    buySeedInput.PlaceholderText = "Bamboo"
    buySeedInput.PlaceholderColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    buySeedInput.ClearTextOnFocus = false
    buySeedInput.Font = Enum.Font.Code
    buySeedInput.Text = "Bamboo"
    buySeedInput.TextSize = 11
    buySeedInput.TextXAlignment = Enum.TextXAlignment.Center
    buySeedInput.BorderSizePixel = 0
    buySeedInput.Parent = buySeedRow
    Instance.new("UICorner", buySeedInput).CornerRadius = UDim.new(0, 6)

    local buyIntervalRow = Instance.new("Frame")
    buyIntervalRow.Size = UDim2.new(1, 0, 0, 28)
    buyIntervalRow.BackgroundTransparency = 1
    buyIntervalRow.LayoutOrder = 3
    buyIntervalRow.Parent = buyRows

    local buyIntervalLbl = Instance.new("TextLabel")
    buyIntervalLbl.Size = UDim2.new(1, -92, 1, 0)
    buyIntervalLbl.BackgroundTransparency = 1
    buyIntervalLbl.Text = "Buy interval (s)"
    buyIntervalLbl.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    buyIntervalLbl.Font = Enum.Font.Gotham
    buyIntervalLbl.TextSize = 10
    buyIntervalLbl.TextXAlignment = Enum.TextXAlignment.Left
    buyIntervalLbl.Parent = buyIntervalRow

    local buySeedIntervalInput = Instance.new("TextBox")
    buySeedIntervalInput.Size = UDim2.new(0, 80, 1, 0)
    buySeedIntervalInput.Position = UDim2.new(1, -80, 0, 0)
    buySeedIntervalInput.BackgroundColor3 = theme.bg2 or Color3.fromRGB(22, 22, 30)
    buySeedIntervalInput.TextColor3 = theme.text or Color3.new(1, 1, 1)
    buySeedIntervalInput.PlaceholderText = "120"
    buySeedIntervalInput.PlaceholderColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    buySeedIntervalInput.ClearTextOnFocus = false
    buySeedIntervalInput.Font = Enum.Font.Code
    buySeedIntervalInput.Text = "120"
    buySeedIntervalInput.TextSize = 11
    buySeedIntervalInput.TextXAlignment = Enum.TextXAlignment.Center
    buySeedIntervalInput.BorderSizePixel = 0
    buySeedIntervalInput.Parent = buyIntervalRow
    Instance.new("UICorner", buySeedIntervalInput).CornerRadius = UDim.new(0, 6)

    local buyButtonShell = Instance.new("Frame")
    buyButtonShell.Size = UDim2.new(1, 0, 0, 34)
    buyButtonShell.BackgroundColor3 = theme.panel2 or Color3.fromRGB(40, 40, 52)
    buyButtonShell.BorderSizePixel = 0
    buyButtonShell.LayoutOrder = 4
    buyButtonShell.Parent = buyRows
    Instance.new("UICorner", buyButtonShell).CornerRadius = UDim.new(0, 9)

    local buyButtonAccent = Instance.new("Frame")
    buyButtonAccent.Size = UDim2.new(0, 4, 1, -10)
    buyButtonAccent.Position = UDim2.new(0, 8, 0.5, 0)
    buyButtonAccent.AnchorPoint = Vector2.new(0, 0.5)
    buyButtonAccent.BackgroundColor3 = theme.danger or Color3.fromRGB(180, 60, 60)
    buyButtonAccent.BorderSizePixel = 0
    buyButtonAccent.Parent = buyButtonShell
    Instance.new("UICorner", buyButtonAccent).CornerRadius = UDim.new(1, 0)

    local buySeedButton = Instance.new("TextButton")
    buySeedButton.Size = UDim2.new(1, 0, 1, 0)
    buySeedButton.BackgroundTransparency = 1
    buySeedButton.AutoButtonColor = false
    buySeedButton.Text = "Buy Seed: OFF"
    buySeedButton.TextColor3 = theme.text or Color3.new(1, 1, 1)
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

    local mini = Instance.new("Frame")
    mini.Name = "MinimizedPanel"
    mini.Size = UDim2.new(0, 240, 0, 96)
    mini.Position = UDim2.new(0, 20, 0, 20)
    mini.BackgroundColor3 = theme.bg or Color3.fromRGB(18, 18, 24)
    mini.BorderSizePixel = 0
    mini.Visible = false
    mini.Active = true
    mini.Parent = screenGui
    Instance.new("UICorner", mini).CornerRadius = UDim.new(0, 12)

    local miniStroke = Instance.new("UIStroke", mini)
    miniStroke.Color = mainStroke.Color
    miniStroke.Transparency = mainStroke.Transparency
    miniStroke.Thickness = 1

    local miniHeader = Instance.new("TextLabel")
    miniHeader.Size = UDim2.new(1, -28, 0, 16)
    miniHeader.Position = UDim2.new(0, 8, 0, 4)
    miniHeader.BackgroundTransparency = 1
    miniHeader.Text = "Build A Beehive"
    miniHeader.TextColor3 = theme.text or Color3.new(1, 1, 1)
    miniHeader.Font = Enum.Font.GothamBold
    miniHeader.TextSize = 10
    miniHeader.TextXAlignment = Enum.TextXAlignment.Left
    miniHeader.Parent = mini

    local miniExpand = Instance.new("TextButton")
    miniExpand.Text = "▢"
    miniExpand.Size = UDim2.new(0, 18, 0, 18)
    miniExpand.Position = UDim2.new(1, -24, 0, 3)
    miniExpand.BackgroundColor3 = theme.panel2 or Color3.fromRGB(40, 40, 52)
    miniExpand.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
    miniExpand.Font = Enum.Font.GothamBold
    miniExpand.TextSize = 11
    miniExpand.BorderSizePixel = 0
    miniExpand.Parent = mini
    Instance.new("UICorner", miniExpand).CornerRadius = UDim.new(0, 5)

    local miniDragHit = Instance.new("TextButton")
    miniDragHit.Size = UDim2.new(1, -24, 0, 26)
    miniDragHit.BackgroundTransparency = 1
    miniDragHit.Text = ""
    miniDragHit.Parent = mini

    local miniCards = Instance.new("Frame")
    miniCards.Size = UDim2.new(1, -16, 0, 34)
    miniCards.Position = UDim2.new(0, 8, 0, 24)
    miniCards.BackgroundTransparency = 1
    miniCards.Parent = mini

    local miniLayout = Instance.new("UIListLayout")
    miniLayout.FillDirection = Enum.FillDirection.Horizontal
    miniLayout.Padding = UDim.new(0, 4)
    miniLayout.SortOrder = Enum.SortOrder.LayoutOrder
    miniLayout.Parent = miniCards

    local function makeMiniCard(labelText, order, parent)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 53, 1, 0)
        card.BackgroundColor3 = theme.panel2 or Color3.fromRGB(34, 34, 44)
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.Parent = parent or miniCards
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -4, 0, 10)
        label.Position = UDim2.new(0, 2, 0, 2)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = theme.dim or Color3.fromRGB(130, 130, 145)
        label.Font = Enum.Font.Gotham
        label.TextSize = 8
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.Parent = card

        local value = Instance.new("TextLabel")
        value.Size = UDim2.new(1, -4, 0, 16)
        value.Position = UDim2.new(0, 2, 0, 14)
        value.BackgroundTransparency = 1
        value.Text = "0"
        value.TextColor3 = theme.text or Color3.new(1, 1, 1)
        value.Font = Enum.Font.GothamBold
        value.TextSize = 12
        value.TextXAlignment = Enum.TextXAlignment.Center
        value.Parent = card

        return value
    end

    local miniFps = makeMiniCard("FPS", 1)
    local miniPing = makeMiniCard("PING", 2)
    local miniPlayers = makeMiniCard("PLAYERS", 3)
    local miniHive = makeMiniCard("HIVE", 4)

    -- Second row: action counters (fed by ctx.counts via core.lua updateStats)
    local miniActionCards = Instance.new("Frame")
    miniActionCards.Size = UDim2.new(1, -16, 0, 34)
    miniActionCards.Position = UDim2.new(0, 8, 0, 60)
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

    local function setTab(tabName)
        applyTab(tabName)
    end

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
        MainStroke = mainStroke,
        TopBar = topBar,
        Sidebar = sidebar,
        Content = content,
        OverviewTab = overviewTab,
        ActionsTab = actionsTab,
        SetTab = setTab,
        TabButtons = {
            Overview = tabOverviewBtn,
            Actions = tabActionsBtn,
            Buy = tabBuyBtn,
        },
        Title = title,
        Subtitle = subtitle,
        MinBtn = minBtn,
        CloseBtn = closeBtn,
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
        ResetCountersBtn = resetCountersBtn,
        CollectButton = collectButton,
        SellButton = sellButton,
        DepositAuroraButton = depositAuroraButton,
        BuySeedButton = buySeedButton,
        CollectIntervalInput = collectIntervalInput,
        SellIntervalInput = sellIntervalInput,
        AuroraIntervalInput = auroraIntervalInput,
        BuySeedIntervalInput = buySeedIntervalInput,
        BuySeedInput = buySeedInput,
        MinimizedPanel = mini,
        MiniHeader = miniHeader,
        MiniExpand = miniExpand,
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
