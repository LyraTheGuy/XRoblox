-- IndoHangout/views/main.lua
-- View layer: window chrome + sidebar tab pages, built from the reusable
-- component factories in views/components/. Restructured after LyraHub's
-- views/ pattern (CanvasGroup canvas, drop shadow, pill sidebar tabs with
-- hover/indicator, minimize chip, full-width drag hitbox).
--
-- COMPATIBILITY SURFACE (feature modules + core.lua depend on this):
--   view.TabPages[name].container  → scrolling container a module parents to
--   view.components.createSectionLabel / createToggle / createTextbox /
--     createButton / createDropdown / createSlider (positional-args API)
--   view.CloseBtn / view.MinBtn (raw Instances)
--   view.setStatus(text, color) / view.switchTab(name)
--   view.Destroy()
-- Window behavior (drag / minimize / tab switching) lives at the bottom;
-- Close remains owned by core.lua so ctx.destroyAll stays the single path.

return function(config, components)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")

    local shared = components.shared
    local button = components.button
    local toggle = components.toggle
    local dropdown = components.dropdown
    local slider = components.slider
    local textinput = components.textinput

    local theme = config.Theme
    local win = config.Window
    local W, H = win.Size.X, win.Size.Y

    local view = {}

    --------------------------------------------------------------------
    -- SAFE DUPLICATE-GUI CLEANUP (_G guard, documented per project spec)
    --------------------------------------------------------------------
    pcall(function()
        if _G.__IndoHangout_Gui and _G.__IndoHangout_Gui.Parent then
            _G.__IndoHangout_Gui:Destroy()
        end
    end)

    --------------------------------------------------------------------
    -- SCREENGUI + CANVAS
    --------------------------------------------------------------------
    local gui = Instance.new("ScreenGui")
    gui.Name = "IndoHangout_Gui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000
    -- Sibling keeps ZIndex local to each parent, so a child label can never be
    -- painted over by its own row/panel background. IndoVoice sets this too.
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    _G.__IndoHangout_Gui = gui
    view.ScreenGui = gui
    view.Gui = gui

    local canvas = Instance.new("CanvasGroup")
    canvas.Name = "Canvas"
    canvas.Size = UDim2.fromOffset(W, H)
    canvas.AnchorPoint = Vector2.new(0.5, 0.5)
    canvas.Position = UDim2.new(0.5, 0, 0.5, 0)
    canvas.BackgroundTransparency = 1
    canvas.ClipsDescendants = false
    canvas.Parent = gui
    view.Canvas = canvas

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(W, H)
    main.BackgroundColor3 = theme.bg
    main.BorderSizePixel = 0
    -- Must stay at/below its children: with a global z-index, a higher value
    -- here paints the window background over every label inside it.
    main.ZIndex = 1
    main.ClipsDescendants = true
    main.Parent = canvas
    shared.corner(main, UDim.new(0, 12))
    shared.stroke(main, theme.divider, 1, 0.45)
    shared.glow(main, theme.glow, 4, 0.92)
    shared.gradient(main, theme.bg, theme.bg2, 90)
    view.Main = main
    view.MainFrame = main
    view.Shadow = shared.shadow(main)
    if view.Shadow then
        view.Shadow.ZIndex = 0
    end

    --------------------------------------------------------------------
    -- TOP BAR (title + window buttons; DragHit sits under them)
    --------------------------------------------------------------------
    local topbar = Instance.new("Frame")
    topbar.Name = "TopBar"
    topbar.Size = UDim2.new(1, 0, 0, 48)
    topbar.BackgroundTransparency = 1
    topbar.ZIndex = 2
    topbar.Parent = main
    view.TopBar = topbar

    local logo = Instance.new("Frame")
    logo.Size = UDim2.fromOffset(12, 12)
    logo.Position = UDim2.fromOffset(18, 18)
    logo.BackgroundColor3 = theme.accent
    logo.BorderSizePixel = 0
    logo.ZIndex = 2
    logo.Parent = topbar
    shared.corner(logo, UDim.new(1, 0))
    shared.glow(logo, theme.glow, 2, 0.55)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromOffset(220, 20)
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
    subtitle.Size = UDim2.fromOffset(220, 12)
    subtitle.Position = UDim2.fromOffset(38, 32)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = string.upper(win.Subtitle or "")
    subtitle.TextColor3 = theme.faint
    subtitle.Font = Enum.Font.GothamBold
    subtitle.TextSize = 8
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 2
    subtitle.Parent = topbar

    local minBtn = Instance.new("TextButton")
    minBtn.Name = "MinBtn"
    minBtn.Size = UDim2.fromOffset(28, 28)
    minBtn.Position = UDim2.fromOffset(W - 76, 10)
    minBtn.BackgroundColor3 = theme.panel2
    minBtn.Text = "—"
    minBtn.TextColor3 = theme.text
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 13
    minBtn.AutoButtonColor = false
    minBtn.BorderSizePixel = 0
    minBtn.ZIndex = 3
    minBtn.Parent = main
    shared.corner(minBtn, UDim.new(0, 8))

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.Position = UDim2.fromOffset(W - 40, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(64, 28, 34)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = theme.danger
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.AutoButtonColor = false
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 3
    closeBtn.Parent = main
    shared.corner(closeBtn, UDim.new(0, 8))

    view.MinBtn = minBtn
    view.CloseBtn = closeBtn

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

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.Position = UDim2.fromOffset(0, 48)
    divider.BackgroundColor3 = theme.divider
    divider.BorderSizePixel = 0
    divider.ZIndex = 1
    divider.Parent = main

    --------------------------------------------------------------------
    -- SIDEBAR
    --------------------------------------------------------------------
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
    view.Sidebar = sidebar

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
        if opts.TextTruncate then l.TextTruncate = opts.TextTruncate end
        -- Wrapped copy needs to grow or it is clipped to a single line.
        if opts.Wrapped then l.AutomaticSize = Enum.AutomaticSize.Y end
        l.ZIndex = opts.ZIndex or 1
        l.LayoutOrder = opts.LayoutOrder or 0
        l.Parent = opts.Parent
        return l
    end

    local chip = Instance.new("Frame")
    chip.Size = UDim2.fromOffset(126, 24)
    chip.Position = UDim2.new(0, 12, 1, -36)
    chip.BackgroundColor3 = theme.panel2
    chip.BackgroundTransparency = 0.6
    chip.BorderSizePixel = 0
    chip.Parent = sidebar
    shared.corner(chip, UDim.new(1, 0))
    label({
        Parent = chip, Text = tostring(config.Build or "v1.0.0") .. " · modular",
        Size = UDim2.new(1, 0, 1, 0), TextSize = 8, Color = theme.faint,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    --------------------------------------------------------------------
    -- STATUS STRIP
    --------------------------------------------------------------------
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -174, 0, 16)
    statusLabel.Position = UDim2.new(0, 162, 1, -22)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Ready"
    statusLabel.TextColor3 = theme.faint
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 9
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    statusLabel.Parent = main
    view.StatusLabel = statusLabel

    function view.setStatus(text, color)
        statusLabel.Text = text or ""
        statusLabel.TextColor3 = color or theme.faint
    end

    --------------------------------------------------------------------
    -- TAB SYSTEM (sidebar buttons + indicator + scrollable pages)
    --------------------------------------------------------------------
    local TabOrder = { "About", "Fishing", "Mining", "Misc", "Settings" }
    view.TabOrder = TabOrder
    view.TabPages = {}
    view.TabButtons = {}

    local function makePage()
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "Page"
        scroll.Size = UDim2.new(1, -174, 1, -85)
        scroll.Position = UDim2.fromOffset(162, 61)
        scroll.BackgroundColor3 = theme.panel
        scroll.BackgroundTransparency = 0.55
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = theme.accentDark
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.ZIndex = 1
        scroll.Visible = false
        scroll.Parent = main
        shared.corner(scroll, UDim.new(0, 10))
        shared.stroke(scroll, theme.divider, 1, 0.5)

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.PaddingTop = UDim.new(0, 6)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.Parent = scroll

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll

        local page = { name = "", scroll = scroll, container = scroll }
        return page
    end

    local pages = {}
    for _, name in ipairs(TabOrder) do
        local page = makePage()
        page.name = name
        view.TabPages[name] = page
        pages[name] = page.scroll
    end

    function view.SetActiveTab(name)
        for _, tabName in ipairs(TabOrder) do
            local tab = view.Tabs and view.Tabs[tabName]
            local active = tabName == name
            if tab then
                tab.Active = active
                shared.tween(tab.Button, {
                    TextColor3 = active and Color3.new(1, 1, 1) or theme.dim,
                    BackgroundTransparency = active and 0.88 or 1,
                }, 0.14)
                shared.tween(tab.Indicator, { BackgroundTransparency = active and 0 or 1 }, 0.14)
            end
            if pages[tabName] then
                pages[tabName].Visible = active
            end
        end
        view.ActiveTab = name
    end

    function view.switchTab(name)
        if pages[name] then
            view.SetActiveTab(name)
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
            if not (view.Tabs[name] and view.Tabs[name].Active) then
                shared.tween(btn, { TextColor3 = theme.text, BackgroundTransparency = 0.92 }, 0.12)
            end
        end)
        btn.MouseLeave:Connect(function()
            if not (view.Tabs[name] and view.Tabs[name].Active) then
                shared.tween(btn, { TextColor3 = theme.dim, BackgroundTransparency = 1 }, 0.18)
            end
        end)
        btn.MouseButton1Click:Connect(function()
            view.SetActiveTab(name)
        end)
        return btn, indicator
    end

    view.Tabs = {}
    for i, name in ipairs(TabOrder) do
        local btn, indicator = makeTab(name, i)
        view.Tabs[name] = { Button = btn, Indicator = indicator, Page = pages[name], Active = false }
        view.TabButtons[name] = btn
    end

    --------------------------------------------------------------------
    -- COMPONENT ADAPTER (positional-args API the feature modules use)
    --------------------------------------------------------------------
    -- Wraps LyraHub-style components into flowing rows inside each page's
    -- scrolling container. Fixes the old gui.lua bug where every row was
    -- placed at the same Y offset (overlapping UI).
    local flowOrder = 0
    local function nextOrder()
        flowOrder += 1
        return flowOrder
    end

    local function featureRow(parent, height)
        local row = Instance.new("Frame")
        row.Name = "Feature"
        row.Size = UDim2.new(1, 0, 0, height or 32)
        row.BackgroundColor3 = theme.panel
        row.BackgroundTransparency = 0.35
        row.BorderSizePixel = 0
        row.ZIndex = 2
        row.LayoutOrder = nextOrder()
        row.Parent = parent
        shared.corner(row, UDim.new(0, 8))
        shared.stroke(row, theme.divider, 1, 0.5)
        return row
    end

    local function rowLabel(row, text, width)
        return label({
            Parent = row, Text = text or "", Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(0, width or 110, 1, 0), TextSize = 11, Color = theme.text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            -- above the row's own ZIndex so the panel can never cover the text
            ZIndex = 4,
        })
    end

    local comps = {}

    function comps.createSectionLabel(parent, text)
        local lbl = label({
            Parent = parent, Text = text or "", Position = UDim2.fromOffset(2, 0),
            Size = UDim2.new(1, -6, 0, 18), TextSize = 11, Color = theme.faint,
            Font = Enum.Font.GothamBold,
        })
        lbl.LayoutOrder = nextOrder()
        return lbl
    end

    function comps.createToggle(parent, labelText, default, callback)
        local row = featureRow(parent, 30)
        rowLabel(row, labelText)
        local handle = toggle({
            Parent = row, Default = default and true or false,
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -58, 0.5, 0),
            ZIndex = 3,
        })
        handle.OnChanged(function(val)
            pcall(callback, val)
        end)
        local comp = {
            Instance = handle,
            container = row,
            get = function() return handle.Get() end,
            set = function(v) handle.Set(v, false) end,
        }
        return comp
    end

    function comps.createTextbox(parent, labelText, placeholder)
        local row = featureRow(parent, 32)
        rowLabel(row, labelText)
        local field = textinput({
            Parent = row, Size = UDim2.fromOffset(200, 24),
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
            Placeholder = placeholder or "", ZIndex = 3,
        })
        field.Instance.ZIndex = 3
        local comp = {
            Instance = field,
            box = field.Box,
            container = row,
            text = function(s)
                if s ~= nil then field.SetText(tostring(s), false) end
                return field.GetText()
            end,
        }
        return comp
    end

    function comps.createButton(parent, labelText, callback)
        local row = featureRow(parent, 34)
        local handle = button({
            Parent = row, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 4),
            Text = labelText or "Button", TextSize = 11, ZIndex = 3, Glow = false,
        })
        handle.Instance.MouseButton1Click:Connect(function()
            pcall(callback)
        end)
        local comp = {
            Instance = handle,
            container = row,
            set = function(text) handle.SetText(text) end,
        }
        return comp
    end

    function comps.createDropdown(parent, labelText, options, defaultIndex, callback)
        local row = featureRow(parent, 32)
        rowLabel(row, labelText)
        local handle = dropdown({
            Parent = row, Size = UDim2.fromOffset(200, 26),
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
            Items = options or {}, Default = options and (defaultIndex and options[defaultIndex] or options[1]),
            ItemHeight = 24, ZIndex = 12,
        })
        handle.OnSelected(function(item)
            pcall(callback, item)
        end)
        local comp = {
            Instance = handle,
            dd = handle.Header,
            listFrame = handle.Instance,
            container = row,
            get = function() return handle.GetSelected() end,
            set = function(opt) handle.SetSelected(opt, false) end,
            setOptions = function(list) handle.SetItems(list, false) end,
        }
        return comp
    end

    function comps.createSlider(parent, labelText, min, max, default, step, callback)
        min = tonumber(min) or 0
        max = tonumber(max) or (min + 100)
        if max <= min then max = min + 1 end
        step = tonumber(step) or 0
        local row = featureRow(parent, 34)
        rowLabel(row, labelText, 150)
        local valLabel = label({
            Parent = row, Text = "", AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -44, 0, 4), Size = UDim2.fromOffset(40, 14),
            TextSize = 10, Color = theme.accentGlow, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3,
        })

        local function round(v)
            if step > 0 then
                return math.floor(v / step + 0.5) * step
            end
            return v
        end

        local initialRatio = ((tonumber(default) or min) - min) / (max - min)
        local handle = slider({
            Parent = row,
            Size = UDim2.new(1, -186, 0, 6),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 150, 0.5, -3),
            Default = initialRatio,
            TrackThickness = 6, ZIndex = 3,
        })
        handle.Instance.ZIndex = 3

        local current = round(tonumber(default) or min)
        valLabel.Text = tostring(current)

        handle.OnChanged(function(ratio)
            current = round(min + ratio * (max - min))
            valLabel.Text = tostring(current)
            pcall(callback, current)
        end)

        local comp = {
            Instance = handle,
            container = row,
            get = function() return current end,
            set = function(v)
                local num = tonumber(v) or min
                current = round(math.clamp(num, min, max))
                valLabel.Text = tostring(current)
                handle.Set((current - min) / (max - min), false)
            end,
        }
        return comp
    end

    view.components = comps

    --------------------------------------------------------------------
    -- ABOUT TAB CONTENT
    --------------------------------------------------------------------
    do
        local aboutPage = view.TabPages.About
        local about = aboutPage and aboutPage.container
        if about then
            local function aboutLabel(text, size, color, bold, wrapped)
                return label({
                    Parent = about, Text = text, Size = UDim2.new(1, 0, 0, (size or 10) + 6),
                    TextSize = size or 10, Color = color or theme.text,
                    Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
                    Wrapped = wrapped or false,
                    LayoutOrder = nextOrder(),
                })
            end
            aboutLabel("IndoHangout", 22, theme.accentGlow, true)
            aboutLabel("Automation tools for IndoHangout — Version " .. tostring(config.Build or "v1.0.0"), 11, theme.dim)
            local function aboutSep()
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1, 0, 0, 1)
                sep.BackgroundColor3 = theme.divider
                sep.BorderSizePixel = 0
                sep.LayoutOrder = nextOrder()
                sep.Parent = about
            end
            aboutSep()
            aboutLabel("Discord: Ahzencal", 13, theme.text, true)
            do
                local donateRow = Instance.new("Frame")
                donateRow.Size = UDim2.new(1, 0, 0, 30)
                donateRow.BackgroundColor3 = theme.panel
                donateRow.BackgroundTransparency = 0.5
                donateRow.BorderSizePixel = 0
                donateRow.LayoutOrder = nextOrder()
                donateRow.Parent = about
                shared.corner(donateRow, UDim.new(0, 8))
                label({
                    Parent = donateRow, Text = "Saweria: saweria.co/ahzencal",
                    Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -100, 1, 0),
                    TextSize = 12, Color = theme.text, Font = Enum.Font.GothamBold,
                })
                local copyBtn = Instance.new("TextButton")
                copyBtn.Name = "CopySaweriaBtn"
                copyBtn.Size = UDim2.fromOffset(84, 22)
                copyBtn.AnchorPoint = Vector2.new(1, 0.5)
                copyBtn.Position = UDim2.new(1, -6, 0.5, 0)
                copyBtn.BackgroundColor3 = theme.accent
                copyBtn.TextColor3 = Color3.new(1, 1, 1)
                copyBtn.Font = Enum.Font.GothamBold
                copyBtn.TextSize = 11
                copyBtn.Text = "Copy"
                copyBtn.AutoButtonColor = false
                copyBtn.BorderSizePixel = 0
                copyBtn.Parent = donateRow
                shared.corner(copyBtn, UDim.new(0, 6))
                copyBtn.MouseButton1Click:Connect(function()
                    pcall(function()
                        if setclipboard then
                            setclipboard("https://saweria.co/ahzencal")
                        elseif toclipboard then
                            toclipboard("https://saweria.co/ahzencal")
                        end
                    end)
                    copyBtn.Text = "Copied!"
                    task.delay(1.5, function()
                        if copyBtn and copyBtn.Parent then copyBtn.Text = "Copy" end
                    end)
                end)
            end
            aboutSep()
            aboutLabel("IndoHangout is a multi-feature automation hub. Features include auto fishing, auto mining, fish and crystal selling (with protected fish), locked-spot farming, streak protection, fly, walkspeed, noclip, session stats, and persistent JSON profiles — all in a clean, modular UI.", 11, theme.dim, false, true)
            aboutLabel("Created By: Ahzencal", 13, theme.text, true)
            aboutLabel("IndoHangout est. 2026", 11, theme.dim)
        end
    end

    --------------------------------------------------------------------
    -- WINDOW BEHAVIOR: DRAG + MINIMIZE (IndoVoice-style free drag)
    --------------------------------------------------------------------
    -- `main` lives inside the centered canvas, so its offset is measured from
    -- screen center. Clamp the offset instead of the position: the window can
    -- be dragged anywhere on screen but never fully off it.
    local dragging = false
    local dragConn = nil
    local dragStartMouse = nil
    local dragStartOffset = nil

    local function viewportSize()
        local camera = workspace.CurrentCamera
        return (camera and camera.ViewportSize) or Vector2.new(1920, 1080)
    end

    local function applyWindowOffset(offsetX, offsetY)
        local screen = viewportSize()
        local limitX = math.max((screen.X - W) / 2 - 8, 0)
        local limitY = math.max((screen.Y - H) / 2 - 8, 0)
        offsetX = math.clamp(offsetX, -limitX, limitX)
        offsetY = math.clamp(offsetY, -limitY, limitY)
        main.Position = UDim2.fromOffset(offsetX, offsetY)
        if view.Shadow then
            view.Shadow.Position = UDim2.fromOffset(offsetX - 4, offsetY)
        end
    end

    local function isDragInput(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    local function beginDrag(input)
        if not isDragInput(input) then return end
        dragging = true
        dragStartMouse = Vector2.new(input.Position.X, input.Position.Y)
        dragStartOffset = Vector2.new(main.Position.X.Offset, main.Position.Y.Offset)
        if dragConn then dragConn:Disconnect() end
        dragConn = UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement
                and i.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            -- input.Position is a Vector3; flatten to 2D before subtracting.
            local pointer = Vector2.new(i.Position.X, i.Position.Y)
            local delta = pointer - dragStartMouse
            applyWindowOffset(dragStartOffset.X + delta.X, dragStartOffset.Y + delta.Y)
        end)
    end

    local function endDrag(input)
        if not isDragInput(input) then return end
        dragging = false
        if dragConn then
            dragConn:Disconnect()
            dragConn = nil
        end
    end

    UserInputService.InputEnded:Connect(endDrag)
    view.DisconnectDrag = function()
        dragging = false
        if dragConn then
            dragConn:Disconnect()
            dragConn = nil
        end
    end

    -- Drag from the whole title bar, the invisible hit strip, and the bottom grip.
    topbar.InputBegan:Connect(beginDrag)
    dragHit.InputBegan:Connect(beginDrag)

    local gripBar = Instance.new("Frame")
    gripBar.Name = "DragBar"
    gripBar.Size = UDim2.fromOffset(80, 4)
    gripBar.AnchorPoint = Vector2.new(0.5, 0)
    gripBar.Position = UDim2.new(0.5, 0, 1, -12)
    gripBar.BackgroundColor3 = theme.accentDark
    gripBar.BorderSizePixel = 0
    gripBar.ZIndex = 3
    gripBar.Parent = main
    shared.corner(gripBar, UDim.new(1, 0))

    local gripHit = Instance.new("TextButton")
    gripHit.Name = "DragHitBottom"
    gripHit.Size = UDim2.new(0, 160, 0, 18)
    gripHit.AnchorPoint = Vector2.new(0.5, 0)
    gripHit.Position = UDim2.new(0.5, 0, 1, -18)
    gripHit.BackgroundTransparency = 1
    gripHit.Text = ""
    gripHit.AutoButtonColor = false
    gripHit.BorderSizePixel = 0
    gripHit.ZIndex = 4
    gripHit.Parent = main
    gripHit.InputBegan:Connect(beginDrag)

    -- Minimize chip (LyraHub-style): window fades out, small pill fades in.
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
    view.MinimizedFrame = minimized
    view.ContentHolder = canvas -- legacy alias (old gui.lua exposed this)

    local minScale = Instance.new("UIScale")
    minScale.Scale = 0.9
    minScale.Parent = minimized
    view.MinScale = minScale

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

    local expandBtn = Instance.new("TextButton")
    expandBtn.Name = "ExpandBtn"
    expandBtn.Size = UDim2.fromOffset(28, 28)
    expandBtn.Position = UDim2.fromOffset(162, 7)
    expandBtn.BackgroundColor3 = theme.panel2
    expandBtn.Text = "▲"
    expandBtn.TextColor3 = theme.text
    expandBtn.Font = Enum.Font.GothamBold
    expandBtn.TextSize = 11
    expandBtn.AutoButtonColor = false
    expandBtn.BorderSizePixel = 0
    expandBtn.ZIndex = 6
    expandBtn.Parent = minimized
    shared.corner(expandBtn, UDim.new(1, 0))

    view.Minimized = false

    local function setMinimized(minimized_)
        if minimized_ == view.Minimized then return end
        view.Minimized = minimized_
        if minimized_ then
            local tween = TweenService:Create(canvas, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
            tween:Play()
            tween.Completed:Once(function()
                canvas.Visible = false
                minScale.Scale = 0.9
                minimized.Visible = true
                TweenService:Create(minScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
            end)
        else
            minimized.Visible = false
            canvas.Visible = true
            canvas.GroupTransparency = 1
            TweenService:Create(canvas, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
        end
    end

    minBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
    expandBtn.MouseButton1Click:Connect(function() setMinimized(false) end)

    --------------------------------------------------------------------
    -- TEARDOWN
    --------------------------------------------------------------------
    view.Destroy = function()
        if view.DisconnectDrag then
            pcall(view.DisconnectDrag)
        end
        pcall(function()
            if canvas and canvas.Parent then
                canvas:Destroy()
            end
        end)
        pcall(function()
            if gui and gui.Parent then
                gui:Destroy()
            end
        end)
        _G.__IndoHangout_Gui = nil
    end

    --------------------------------------------------------------------
    -- INITIAL STATE
    --------------------------------------------------------------------
    view.SetActiveTab(TabOrder[1])

    return view
end
