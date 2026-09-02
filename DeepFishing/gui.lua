-- DeepFishing/gui.lua
-- Tabbed GUI for Deep Fishing automation
return function(config, components)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local lp = Players.LocalPlayer

    local shared = components and components.shared
    local LYRA = config.Theme

    local function tweenProp(obj, props, t, style, dir)
        style = style or Enum.EasingStyle.Quart
        dir = dir or Enum.EasingDirection.Out
        TweenService:Create(obj, TweenInfo.new(t, style, dir), props):Play()
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
    LoadTitle.Text = "DEEP FISHING"
    LoadTitle.Size = UDim2.new(1, 0, 0, 44)
    LoadTitle.Position = UDim2.new(0, 0, 0, 120)
    LoadTitle.BackgroundTransparency = 1
    LoadTitle.TextColor3 = LYRA.accentGlow
    LoadTitle.Font = Enum.Font.GothamBold
    LoadTitle.TextSize = 30
    LoadTitle.TextTransparency = 1
    LoadTitle.Parent = LoadBG

    local LoadQuote = Instance.new("TextLabel")
    LoadQuote.Text = "LyraHub · Deep Fishing Automation"
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
            { text = "Loading modules...", pct = 0.20 },
            { text = "Connecting to game...", pct = 0.45 },
            { text = "Building GUI...", pct = 0.70 },
            { text = "Welcome.", pct = 1.00 },
        }
        task.wait(0.1)
        tweenProp(LoadTitle, { TextTransparency = 0 }, 0.6)
        task.wait(0.4)
        tweenProp(LoadQuote, { TextTransparency = 0 }, 0.5)
        task.wait(0.2)
        for _, stage in ipairs(stages) do
            LoadStatus.Text = stage.text
            tweenProp(BarFill, { Size = UDim2.new(stage.pct, 0, 1, 0) }, 0.4, Enum.EasingStyle.Quint)
            task.wait(0.35)
        end
        task.wait(0.3)
        tweenProp(LoadBG, { BackgroundTransparency = 1 }, 0.5)
        tweenProp(LoadStroke, { Transparency = 1 }, 0.5)
        tweenProp(LoadTitle, { TextTransparency = 1 }, 0.4)
        tweenProp(LoadQuote, { TextTransparency = 1 }, 0.4)
        tweenProp(LoadStatus, { TextTransparency = 1 }, 0.4)
        tweenProp(BarTrack, { BackgroundTransparency = 1 }, 0.4)
        tweenProp(BarFill, { BackgroundTransparency = 1 }, 0.4)
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

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 620, 0, 420)
    Main.Position = UDim2.new(0.5, -310, 0.5, -210)
    Main.BackgroundColor3 = LYRA.bg
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = true
    Main.Parent = ScreenGui
    shared.corner(Main, UDim.new(0, 12))
    local MainStroke = shared.stroke(Main, LYRA.accent, 1.2, 0.6)

    -- Header
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 48)
    Header.BackgroundColor3 = LYRA.bg2
    Header.BorderSizePixel = 0
    Header.Parent = Main
    shared.corner(Header, UDim.new(0, 12))

    local HeaderMask = Instance.new("Frame")
    HeaderMask.Size = UDim2.new(1, 0, 0, 14)
    HeaderMask.Position = UDim2.new(0, 0, 1, -14)
    HeaderMask.BackgroundColor3 = LYRA.bg2
    HeaderMask.BorderSizePixel = 0
    HeaderMask.Parent = Header

    local Title = Instance.new("TextLabel")
    Title.Text = "🎣 Deep Fishing"
    Title.Size = UDim2.new(0, 200, 1, 0)
    Title.Position = UDim2.new(0, 16, 0, 0)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = LYRA.text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Text = "LyraHub v1.0"
    Subtitle.Size = UDim2.new(0, 120, 1, 0)
    Subtitle.Position = UDim2.new(0, 220, 0, 0)
    Subtitle.BackgroundTransparency = 1
    Subtitle.TextColor3 = LYRA.dim
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextSize = 11
    Subtitle.TextXAlignment = Enum.TextXAlignment.Left
    Subtitle.Parent = Header

    -- Drag bar
    local DragBar = Instance.new("Frame")
    DragBar.Size = UDim2.new(0, 40, 0, 3)
    DragBar.AnchorPoint = Vector2.new(0.5, 0)
    DragBar.Position = UDim2.new(0.5, 0, 1, 8)
    DragBar.BackgroundColor3 = LYRA.accent
    DragBar.BorderSizePixel = 0
    DragBar.Parent = Main
    shared.corner(DragBar, UDim.new(1, 0))

    -- Minimize button
    local MinBtn = Instance.new("TextButton")
    MinBtn.Text = "—"
    MinBtn.Size = UDim2.new(0, 28, 0, 28)
    MinBtn.Position = UDim2.new(1, -68, 0, 10)
    MinBtn.BackgroundColor3 = LYRA.panel2
    MinBtn.TextColor3 = LYRA.dim
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 14
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = Header
    shared.corner(MinBtn, UDim.new(0, 6))

    -- Close button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Text = "×"
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -34, 0, 10)
    CloseBtn.BackgroundColor3 = LYRA.danger
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 16
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = Header
    shared.corner(CloseBtn, UDim.new(0, 6))

    -- Content area
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -12, 1, -80)
    Content.Position = UDim2.new(0, 6, 0, 56)
    Content.BackgroundColor3 = LYRA.panel
    Content.BorderSizePixel = 0
    Content.ClipsDescendants = true
    Content.Parent = Main
    shared.corner(Content, UDim.new(0, 8))
    local ContentStroke = shared.stroke(Content, LYRA.accent, 0.8, 0.8)

    -- Tab bar
    local TabsBar = Instance.new("Frame")
    TabsBar.Size = UDim2.new(1, 0, 0, 36)
    TabsBar.Position = UDim2.new(0, 0, 0, 0)
    TabsBar.BackgroundColor3 = LYRA.panel
    TabsBar.BorderSizePixel = 0
    TabsBar.Parent = Content

    local tabNames = { "Fishing", "Shop", "Player", "Rewards", "Settings" }
    local tabIcons = { "🎣", "🛒", "🏃", "🎁", "⚙️" }
    local TabButtons = {}
    local Tabs = {}
    local activeTab = "Fishing"

    for i, name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Text = tabIcons[i] .. " " .. name
        btn.Size = UDim2.new(0, 110, 0, 28)
        btn.Position = UDim2.new(0, (i - 1) * 114 + 8, 0, 4)
        btn.BackgroundColor3 = (i == 1) and LYRA.accent or LYRA.panel2
        btn.TextColor3 = (i == 1) and Color3.new(1, 1, 1) or LYRA.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.Parent = TabsBar
        shared.corner(btn, UDim.new(0, 6))
        TabButtons[name] = btn

        local tabFrame = Instance.new("ScrollingFrame")
        tabFrame.Size = UDim2.new(1, -12, 1, -44)
        tabFrame.Position = UDim2.new(0, 6, 0, 40)
        tabFrame.BackgroundTransparency = 1
        tabFrame.ScrollBarThickness = 4
        tabFrame.ScrollBarImageColor3 = LYRA.accent
        tabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tabFrame.Parent = Content
        tabFrame.Visible = (i == 1)

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = tabFrame

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 4)
        padding.PaddingLeft = UDim.new(0, 4)
        padding.PaddingRight = UDim.new(0, 4)
        padding.Parent = tabFrame

        Tabs[name] = tabFrame
    end

    -- ═══════════════════════════════════════════
    -- HELPER: Create section frame
    -- ═══════════════════════════════════════════
    local function makeSection(parent, title, order)
        local section = Instance.new("Frame")
        section.Size = UDim2.new(1, 0, 0, 0)
        section.AutomaticSize = Enum.AutomaticSize.Y
        section.BackgroundColor3 = LYRA.bg2
        section.BorderSizePixel = 0
        section.LayoutOrder = order or 0
        section.Parent = parent
        shared.corner(section, UDim.new(0, 8))

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Text = title
        titleLabel.Size = UDim2.new(1, -16, 0, 24)
        titleLabel.Position = UDim2.new(0, 8, 0, 4)
        titleLabel.BackgroundTransparency = 1
        titleLabel.TextColor3 = LYRA.accent
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 12
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = section

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 4)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = section

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 28)
        pad.PaddingBottom = UDim.new(0, 6)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        pad.Parent = section

        return section
    end

    -- ═══════════════════════════════════════════
    -- HELPER: Toggle button
    -- ═══════════════════════════════════════════
    local function makeToggle(parent, text, default, order)
        local btn = Instance.new("TextButton")
        btn.Text = text .. ": OFF"
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = LYRA.panel2
        btn.TextColor3 = LYRA.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.LayoutOrder = order or 0
        btn.AutoButtonColor = false
        btn.Parent = parent
        shared.corner(btn, UDim.new(0, 6))

        local state = default or false
        if state then
            btn.Text = text .. ": ON"
            btn.BackgroundColor3 = LYRA.success
            btn.TextColor3 = Color3.new(1, 1, 1)
        end

        return btn, function()
            state = not state
            if state then
                btn.Text = text .. ": ON"
                btn.BackgroundColor3 = LYRA.success
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                btn.Text = text .. ": OFF"
                btn.BackgroundColor3 = LYRA.panel2
                btn.TextColor3 = LYRA.dim
            end
            return state
        end
    end

    -- ═══════════════════════════════════════════
    -- HELPER: Action button
    -- ═══════════════════════════════════════════
    local function makeButton(parent, text, color, order)
        local btn = Instance.new("TextButton")
        btn.Text = text
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = color or LYRA.accent
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.LayoutOrder = order or 0
        btn.AutoButtonColor = false
        btn.Parent = parent
        shared.corner(btn, UDim.new(0, 6))
        return btn
    end

    -- ═══════════════════════════════════════════
    -- HELPER: Label
    -- ═══════════════════════════════════════════
    local function makeLabel(parent, text, color, order)
        local lbl = Instance.new("TextLabel")
        lbl.Text = text
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or LYRA.dim
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order or 0
        lbl.Parent = parent
        return lbl
    end

    -- ═══════════════════════════════════════════
    -- FISHING TAB
    -- ═══════════════════════════════════════════
    local fishSection = makeSection(Tabs.Fishing, "🎯 Auto Fishing", 1)
    local autoFishToggle, toggleAutoFish = makeToggle(fishSection, "Auto Perfect Fish", false, 1)
    local instantCollectToggle, toggleInstantCollect = makeToggle(fishSection, "Instant Collect", true, 2)
    local autoStopToggle, toggleAutoStop = makeToggle(fishSection, "Auto Stop When Empty", true, 3)
    local collectRaritiesToggle, toggleCollectRarities = makeToggle(fishSection, "Collect All Rarities", true, 4)
    local collectMutationsToggle, toggleCollectMutations = makeToggle(fishSection, "Collect Mutations", true, 5)
    local fishStatusLabel = makeLabel(fishSection, "Status: Idle", LYRA.dim, 6)

    local rewardSection = makeSection(Tabs.Fishing, "🏆 Auto Rewards", 10)
    local autoClaimFreeToggle, toggleAutoClaimFree = makeToggle(rewardSection, "Auto Claim Free Rewards", true, 11)
    local autoClaimBigFishToggle, toggleAutoClaimBigFish = makeToggle(rewardSection, "Auto Claim Big Fish", true, 12)
    local autoClaimPlaytimeToggle, toggleAutoClaimPlaytime = makeToggle(rewardSection, "Auto Claim Playtime Gift", true, 13)
    local autoClaimNextDayToggle, toggleAutoClaimNextDay = makeToggle(rewardSection, "Auto Claim Next Day Reward", true, 14)
    local autoClaimGroupToggle, toggleAutoClaimGroup = makeToggle(rewardSection, "Auto Claim Group Reward", true, 15)

    -- ═══════════════════════════════════════════
    -- SHOP TAB
    -- ═══════════════════════════════════════════
    local baitSection = makeSection(Tabs.Shop, "🪱 Bait Shop", 1)
    local autoBuyBaitToggle, toggleAutoBuyBait = makeToggle(baitSection, "Auto Buy Best Bait", true, 1)
    local buyBaitNowBtn = makeButton(baitSection, "Buy Best Bait Now", LYRA.accent, 2)
    local baitStatusLabel = makeLabel(baitSection, "Status: Ready", LYRA.dim, 3)

    local rodSection = makeSection(Tabs.Shop, "🎣 Rod Shop", 10)
    local autoBuyRodToggle, toggleAutoBuyRod = makeToggle(rodSection, "Auto Buy Best Rod", true, 11)
    local buyRodNowBtn = makeButton(rodSection, "Buy Best Rod Now", LYRA.accent, 12)
    local rodStatusLabel = makeLabel(rodSection, "Status: Ready", LYRA.dim, 13)

    local upgradeSection = makeSection(Tabs.Shop, "⬆️ Upgrades", 20)
    local autoBuyUpgradesToggle, toggleAutoBuyUpgrades = makeToggle(upgradeSection, "Auto Buy Upgrades", true, 21)
    local buyUpgradesNowBtn = makeButton(upgradeSection, "Buy Upgrades Now", LYRA.accent, 22)
    local upgradeStatusLabel = makeLabel(upgradeSection, "Status: Ready", LYRA.dim, 23)

    local sellSection = makeSection(Tabs.Shop, "💰 Sell", 30)
    local autoSellToggle, toggleAutoSell = makeToggle(sellSection, "Auto Sell Fish", false, 31)
    local sellNowBtn = makeButton(sellSection, "Sell All Fish Now", LYRA.warn, 32)
    local autoDeleteToggle, toggleAutoDelete = makeToggle(sellSection, "Auto Delete Low Rarity", false, 33)
    local sellStatusLabel = makeLabel(sellSection, "Status: Ready", LYRA.dim, 34)

    -- ═══════════════════════════════════════════
    -- PLAYER TAB
    -- ═══════════════════════════════════════════
    local moveSection = makeSection(Tabs.Player, "🏃 Movement", 1)
    local flyToggle, toggleFly = makeToggle(moveSection, "Fly", false, 1)
    local flySpeedLabel = makeLabel(moveSection, "Fly Speed: 50", LYRA.dim, 2)
    local noclipToggle, toggleNoClip = makeToggle(moveSection, "NoClip", false, 3)
    local infJumpToggle, toggleInfJump = makeToggle(moveSection, "Infinite Jump", false, 4)
    local speedLabel = makeLabel(moveSection, "Walk Speed: 16", LYRA.dim, 5)

    local antiSection = makeSection(Tabs.Player, "🛡️ Anti-Detection", 10)
    local antiAfkToggle, toggleAntiAfk = makeToggle(antiSection, "Anti AFK", true, 11)
    local antiPauseToggle, toggleAntiPause = makeToggle(antiSection, "Anti Gameplay Pause", true, 12)

    -- ═══════════════════════════════════════════
    -- REWARDS TAB
    -- ═══════════════════════════════════════════
    local codeSection = makeSection(Tabs.Rewards, "🎟️ Codes", 1)
    local redeemCodesBtn = makeButton(codeSection, "Redeem All Codes", LYRA.success, 1)
    local codesStatusLabel = makeLabel(codeSection, "Status: Ready", LYRA.dim, 2)

    local playtimeSection = makeSection(Tabs.Rewards, "⏰ Playtime Rewards", 10)
    local claimPlaytimeBtn = makeButton(playtimeSection, "Claim Playtime Gift", LYRA.accent, 11)
    local claimNextDayBtn = makeButton(playtimeSection, "Claim Next Day Reward", LYRA.accent, 12)
    local claimGroupBtn = makeButton(playtimeSection, "Claim Group Reward", LYRA.accent, 13)
    local rewardsStatusLabel = makeLabel(playtimeSection, "Status: Ready", LYRA.dim, 14)

    -- ═══════════════════════════════════════════
    -- SETTINGS TAB
    -- ═══════════════════════════════════════════
    local keySection = makeSection(Tabs.Settings, "🔑 Keybinds", 1)
    local hideKeyLabel = makeLabel(keySection, "Hide UI: K", LYRA.text, 1)

    local infoSection = makeSection(Tabs.Settings, "ℹ️ Info", 10)
    makeLabel(infoSection, "Deep Fishing Automation v1.0", LYRA.accent, 11)
    makeLabel(infoSection, "By LyraHub", LYRA.dim, 12)
    local unloadBtn = makeButton(infoSection, "Unload Script", LYRA.danger, 13)

    local settingsSection = makeSection(Tabs.Settings, "💾 Persistent Settings", 5)
    local saveBtn = makeButton(settingsSection, "Save Settings", LYRA.success, 6)
    local loadBtn = makeButton(settingsSection, "Load Settings", LYRA.tp, 7)
    local resetBtn = makeButton(settingsSection, "Reset to Defaults", LYRA.warn, 8)
    local saveStatusLabel = makeLabel(settingsSection, "", LYRA.dim, 9)

    local logSection = makeSection(Tabs.Settings, "📋 Logs", 20)
    local logScroll = Instance.new("ScrollingFrame")
    logScroll.Size = UDim2.new(1, 0, 0, 120)
    logScroll.BackgroundTransparency = 1
    logScroll.ScrollBarThickness = 3
    logScroll.ScrollBarImageColor3 = LYRA.accent
    logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    logScroll.LayoutOrder = 21
    logScroll.Parent = logSection
    local logLayout = Instance.new("UIListLayout")
    logLayout.Padding = UDim.new(0, 2)
    logLayout.SortOrder = Enum.SortOrder.LayoutOrder
    logLayout.Parent = logScroll
    local logCountLabel = makeLabel(logSection, "0 entries", LYRA.dim, 22)

    -- ═══════════════════════════════════════════
    -- DRAG FUNCTIONALITY
    -- ═══════════════════════════════════════════
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(input)
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
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- ═══════════════════════════════════════════
    -- TAB SWITCHING
    -- ═══════════════════════════════════════════
    for name, btn in pairs(TabButtons) do
        btn.MouseButton1Click:Connect(function()
            activeTab = name
            for tabName, tabFrame in pairs(Tabs) do
                tabFrame.Visible = (tabName == name)
            end
            for tabName, tabBtn in pairs(TabButtons) do
                if tabName == name then
                    tabBtn.BackgroundColor3 = LYRA.accent
                    tabBtn.TextColor3 = Color3.new(1, 1, 1)
                else
                    tabBtn.BackgroundColor3 = LYRA.panel2
                    tabBtn.TextColor3 = LYRA.dim
                end
            end
        end)
    end

    -- ═══════════════════════════════════════════
    -- MINIMIZE
    -- ═══════════════════════════════════════════
    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tweenProp(Main, { Size = UDim2.new(0, 620, 0, 48) }, 0.25)
            MinBtn.Text = "+"
        else
            tweenProp(Main, { Size = UDim2.new(0, 620, 0, 420) }, 0.25)
            MinBtn.Text = "—"
        end
    end)

    -- ═══════════════════════════════════════════
    -- CLOSE / UNLOAD
    -- ═══════════════════════════════════════════
    local function playCloseAnimation()
        task.spawn(function()
            tweenProp(Main, { BackgroundTransparency = 1 }, 0.4)
            tweenProp(MainStroke, { Transparency = 1 }, 0.4)
            task.wait(0.45)
            pcall(function() ScreenGui:Destroy() end)
        end)
    end

    CloseBtn.MouseButton1Click:Connect(function()
        if _G.__DeepFishing_Destroy then
            _G.__DeepFishing_Destroy()
        end
        playCloseAnimation()
    end)

    -- Return GUI object table
    return {
        ScreenGui = ScreenGui,
        Main = Main,
        Theme = LYRA,
        TabButtons = TabButtons,
        Tabs = Tabs,
        Title = Title,
        Subtitle = Subtitle,

        -- Fishing tab
        Fishing = {
            AutoFishToggle = { btn = autoFishToggle, toggle = toggleAutoFish },
            InstantCollectToggle = { btn = instantCollectToggle, toggle = toggleInstantCollect },
            AutoStopToggle = { btn = autoStopToggle, toggle = toggleAutoStop },
            CollectRaritiesToggle = { btn = collectRaritiesToggle, toggle = toggleCollectRarities },
            CollectMutationsToggle = { btn = collectMutationsToggle, toggle = toggleCollectMutations },
            StatusLabel = fishStatusLabel,
            AutoClaimFreeToggle = { btn = autoClaimFreeToggle, toggle = toggleAutoClaimFree },
            AutoClaimBigFishToggle = { btn = autoClaimBigFishToggle, toggle = toggleAutoClaimBigFish },
            AutoClaimPlaytimeToggle = { btn = autoClaimPlaytimeToggle, toggle = toggleAutoClaimPlaytime },
            AutoClaimNextDayToggle = { btn = autoClaimNextDayToggle, toggle = toggleAutoClaimNextDay },
            AutoClaimGroupToggle = { btn = autoClaimGroupToggle, toggle = toggleAutoClaimGroup },
        },

        -- Shop tab
        Shop = {
            AutoBuyBaitToggle = { btn = autoBuyBaitToggle, toggle = toggleAutoBuyBait },
            BuyBaitNowBtn = buyBaitNowBtn,
            BaitStatusLabel = baitStatusLabel,
            AutoBuyRodToggle = { btn = autoBuyRodToggle, toggle = toggleAutoBuyRod },
            BuyRodNowBtn = buyRodNowBtn,
            RodStatusLabel = rodStatusLabel,
            AutoBuyUpgradesToggle = { btn = autoBuyUpgradesToggle, toggle = toggleAutoBuyUpgrades },
            BuyUpgradesNowBtn = buyUpgradesNowBtn,
            UpgradeStatusLabel = upgradeStatusLabel,
            AutoSellToggle = { btn = autoSellToggle, toggle = toggleAutoSell },
            SellNowBtn = sellNowBtn,
            AutoDeleteToggle = { btn = autoDeleteToggle, toggle = toggleAutoDelete },
            SellStatusLabel = sellStatusLabel,
        },

        -- Player tab
        Player = {
            FlyToggle = { btn = flyToggle, toggle = toggleFly },
            FlySpeedLabel = flySpeedLabel,
            NoClipToggle = { btn = noclipToggle, toggle = toggleNoClip },
            InfJumpToggle = { btn = infJumpToggle, toggle = toggleInfJump },
            SpeedLabel = speedLabel,
            AntiAfkToggle = { btn = antiAfkToggle, toggle = toggleAntiAfk },
            AntiPauseToggle = { btn = antiPauseToggle, toggle = toggleAntiPause },
        },

        -- Rewards tab
        Rewards = {
            RedeemCodesBtn = redeemCodesBtn,
            CodesStatusLabel = codesStatusLabel,
            ClaimPlaytimeBtn = claimPlaytimeBtn,
            ClaimNextDayBtn = claimNextDayBtn,
            ClaimGroupBtn = claimGroupBtn,
            RewardsStatusLabel = rewardsStatusLabel,
        },

        -- Settings tab
        Settings = {
            UnloadBtn = unloadBtn,
            LogScroll = logScroll,
            LogCountLabel = logCountLabel,
            SaveBtn = saveBtn,
            LoadBtn = loadBtn,
            ResetBtn = resetBtn,
            SaveStatusLabel = saveStatusLabel,
        },
    }
end
