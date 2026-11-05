-- IndoHangout/gui.lua
-- UI factory: builds the modern-minimalist dark interface.
-- Returns a gui object with ScreenGui, pages, and shared component creators.

return function(config)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local THEME = config.Theme
    local CORNER = config.ComponentDefaults and config.ComponentDefaults.CornerRadius or UDim.new(0, 8)

    local gui = {
        ScreenGui = nil,
        MainFrame = nil,
        TabPages = {},
        TabButtons = {},
        dragEnabled = false,
        components = nil,
        Theme = THEME,
    }

    -- ------------------------------------------------------------------------
    -- SAFE DUPLICATE-GUI CLEANUP (_G guard)
    -- ------------------------------------------------------------------------
    pcall(function()
        if _G.__IndoHangout_Gui then
            if _G.__IndoHangout_Gui.Parent then
                _G.__IndoHangout_Gui:Destroy()
            end
        end
    end)

    -- ------------------------------------------------------------------------
    -- CORE GUI
    -- ------------------------------------------------------------------------
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "IndoHangout_Gui"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 1000
    gui.ScreenGui = screenGui

    pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
    if not screenGui.Parent then
        local lp = Players.LocalPlayer
        screenGui.Parent = lp:WaitForChild("PlayerGui")
    end
    _G.__IndoHangout_Gui = screenGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, config.Window.Size.X, 0, config.Window.Size.Y)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.fromScale(0.5, 0.5)
    mainFrame.BackgroundColor3 = THEME.bg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    gui.MainFrame = mainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = CORNER
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.border
    stroke.Thickness = 1
    stroke.Parent = mainFrame

    -- ------------------------------------------------------------------------
    -- DRAG CONTROLS
    -- ------------------------------------------------------------------------
    local dragging = false
    local dragStart = Vector2.zero
    local frameStart = Vector2.zero

    local function startDrag(input)
        dragging = true
        dragStart = input.Position
        frameStart = Vector2.new(mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset)
        input.UserInputType = Enum.UserInputType.MouseMovement
    end

    local function stopDrag()
        dragging = false
    end

    local function updateDrag(input)
        if not dragging then return end
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(0, frameStart.X + delta.X, 0, frameStart.Y + delta.Y)
    end

    -- ------------------------------------------------------------------------
    -- SHARED COMPONENT BUILDERS
    -- ------------------------------------------------------------------------

    local function createSectionLabel(parent, text)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 18)
        label.Position = UDim2.new(0, 5, 0, 4)
        label.BackgroundTransparency = 1
        label.Text = text or ""
        label.TextColor3 = THEME.dim
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = parent
        return label
    end

    local function createToggle(parent, label, default, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 26)
        container.Position = UDim2.new(0, 5, 0, 4)
        container.BackgroundColor3 = THEME.panel
        container.BorderSizePixel = 0
        container.Parent = parent
        Instance.new("UICorner", container).CornerRadius = CORNER

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -34, 1, 0)
        nameLabel.Position = UDim2.new(0, 10, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = label
        nameLabel.TextColor3 = THEME.text
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = container

        local knobFrame = Instance.new("Frame")
        knobFrame.Size = UDim2.new(0, 28, 0, 14)
        knobFrame.AnchorPoint = Vector2.new(0, 0.5)
        knobFrame.Position = UDim2.new(1, -14, 0.5, 0)
        knobFrame.BackgroundColor3 = THEME.accentDark
        knobFrame.BorderSizePixel = 0
        knobFrame.Parent = container
        Instance.new("UICorner", knobFrame).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 10, 0, 10)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(0.5, 0, 0.5, 0)
        knob.BackgroundColor3 = THEME.text
        knob.BorderSizePixel = 0
        knob.Parent = knobFrame
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        container.ZIndex = 1
        local state = default and true or false
        local component = {}

        local function render()
            if state then
                knobFrame.BackgroundColor3 = THEME.accent
                knob.Position = UDim2.new(1, -5, 0.5, 0)
            else
                knobFrame.BackgroundColor3 = THEME.accentDark
                knob.Position = UDim2.new(0, 5, 0.5, 0)
            end
        end

        local function activate(manual)
            state = not state
            render()
            if callback then
                pcall(callback, state)
            end
        end

        component.set = function(val)
            state = val and true or false
            render()
        end
        component.get = function()
            return state
        end
        component.container = container

        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.Parent = container
        clickBtn.MouseButton1Click:Connect(function()
            activate()
        end)

        render()
        return component
    end

    local function createTextbox(parent, label, placeholder)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 28)
        container.Position = UDim2.new(0, 5, 0, 4)
        container.BackgroundColor3 = THEME.panel
        container.BorderSizePixel = 0
        container.Parent = parent
        Instance.new("UICorner", container).CornerRadius = CORNER

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 60, 1, 0)
        nameLabel.Position = UDim2.new(0, 10, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = label or ""
        nameLabel.TextColor3 = THEME.dim
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 10
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = container

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -80, 0, 18)
        box.AnchorPoint = Vector2.new(0, 0.5)
        box.Position = UDim2.new(0, 75, 0.5, 0)
        box.BackgroundColor3 = THEME.surface
        box.BorderSizePixel = 0
        box.Text = ""
        box.PlaceholderText = placeholder or ""
        box.TextColor3 = THEME.text
        box.PlaceholderColor3 = THEME.faint
        box.Font = Enum.Font.Gotham
        box.TextSize = 11
        box.Parent = container
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
        local comp = {
            box = box,
            text = function(s)
                if s ~= nil then box.Text = s end
                return box.Text
            end,
        }
        return comp
    end

    local function createButton(parent, label, callback)
        local container = Instance.new("TextButton")
        container.Size = UDim2.new(1, -10, 0, 28)
        container.Position = UDim2.new(0, 5, 0, 4)
        container.BackgroundColor3 = THEME.accentDark
        container.BorderSizePixel = 0
        container.Text = label or "Button"
        container.TextColor3 = THEME.text
        container.Font = Enum.Font.GothamBold
        container.TextSize = 11
        container.Parent = parent
        Instance.new("UICorner", container).CornerRadius = CORNER
        local comp = {
            btn = container,
            set = function(t) container.Text = t or "" end,
        }
        container.MouseButton1Click:Connect(function()
            if callback then pcall(callback) end
        end)
        return comp
    end

    local function createDropdown(parent, label, options, defaultIndex, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 28)
        container.Position = UDim2.new(0, 5, 0, 4)
        container.BackgroundColor3 = THEME.panel
        container.BorderSizePixel = 0
        container.Parent = parent
        Instance.new("UICorner", container).CornerRadius = CORNER

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 60, 1, 0)
        nameLabel.Position = UDim2.new(0, 10, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = label or ""
        nameLabel.TextColor3 = THEME.dim
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 10
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = container

        local dd = Instance.new("TextButton")
        dd.Size = UDim2.new(1, -80, 0, 18)
        dd.AnchorPoint = Vector2.new(0, 0.5)
        dd.Position = UDim2.new(0, 75, 0.5, 0)
        dd.BackgroundColor3 = THEME.surface
        dd.BorderSizePixel = 0
        dd.Text = options and options[defaultIndex or 1] or "Select"
        dd.TextColor3 = THEME.text
        dd.Font = Enum.Font.Gotham
        dd.TextSize = 11
        dd.Parent = container
        Instance.new("UICorner", dd).CornerRadius = UDim.new(0, 4)

        local listFrame = Instance.new("Frame")
        listFrame.Size = UDim2.new(1, -80, 0, 0)
        listFrame.Position = UDim2.new(0, 75, 0.5, 10)
        listFrame.BackgroundColor3 = THEME.surface
        listFrame.BorderSizePixel = 0
        listFrame.ClipsDescendants = true
        listFrame.Visible = false
        listFrame.Parent = container
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)

        local comp = {
            dd = dd,
            listFrame = listFrame,
            parent = container,
            selected = options and options[defaultIndex or 1] or "",
        }

        local function renderList()
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
            local opts = options or {}
            for i, opt in ipairs(opts) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, -4, 0, 20)
                optBtn.Position = UDim2.new(0, 2, 0, (i - 1) * 22 + 2)
                optBtn.BackgroundColor3 = THEME.panel
                optBtn.BorderSizePixel = 0
                optBtn.Text = opt
                optBtn.TextColor3 = THEME.text
                optBtn.Font = Enum.Font.Gotham
                optBtn.TextSize = 9
                optBtn.Parent = listFrame
                Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 4)
                optBtn.MouseButton1Click:Connect(function()
                    dd.Text = opt
                    comp.selected = opt
                    listFrame.Visible = false
                    if callback then pcall(callback, opt) end
                end)
            end
            listFrame.Size = UDim2.new(1, -80, 0, math.max(0, math.min(150, #opts * 22 + 4)))
        end

        dd.MouseButton1Click:Connect(function()
            listFrame.Visible = not listFrame.Visible
        end)

        comp.set = function(opt)
            dd.Text = opt or ""
            comp.selected = opt or ""
        end
        comp.get = function()
            return comp.selected
        end
        comp.setOptions = function(opts)
            options = opts or {}
            dd.Text = options[1] or "Select"
            comp.selected = options[1] or ""
            renderList()
        end

        renderList()
        return comp
    end

    local function createSlider(parent, label, min, max, default, step, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 34)
        container.Position = UDim2.new(0, 5, 0, 4)
        container.BackgroundColor3 = THEME.panel
        container.BorderSizePixel = 0
        container.Parent = parent
        Instance.new("UICorner", container).CornerRadius = CORNER

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -40, 0, 14)
        nameLabel.Position = UDim2.new(0, 10, 0, 1)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = label .. ""
        nameLabel.TextColor3 = THEME.dim
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 10
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = container

        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.new(0, 36, 0, 14)
        valLabel.Position = UDim2.new(1, -40, 0, 1)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = tostring(default)
        valLabel.TextColor3 = THEME.accentGlow
        valLabel.Font = Enum.Font.GothamBold
        valLabel.TextSize = 10
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.Parent = container

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -20, 0, 6)
        track.AnchorPoint = Vector2.new(0, 0.5)
        track.Position = UDim2.new(0, 10, 0.5, 6)
        track.BackgroundColor3 = THEME.accentDark
        track.BorderSizePixel = 0
        track.Parent = container
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = THEME.accent
        fill.BorderSizePixel = 0
        fill.Parent = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.BackgroundColor3 = THEME.accentGlow
        knob.BorderSizePixel = 0
        knob.Parent = track
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local comp = { container = container }
        local val = default

        local function setVisual(v)
            val = math.clamp(v, min, max)
            valLabel.Text = tostring((type(step) == "number" and step > 0) and math.floor(val / step + 0.5) * step or val)
            local frac = (val - min) / (max - min)
            fill.Size = UDim2.new(frac, 0, 1, 0)
            knob.Position = UDim2.new(frac, 0, 0.5, 0)
        end

        local function updateFromX(x)
            local absX = x - track.AbsolutePosition.X
            local w = track.AbsoluteSize.X
            local frac = math.clamp(absX / math.max(w, 1), 0, 1)
            local raw = min + frac * (max - min)
            if type(step) == "number" and step > 0 then
                raw = math.floor(raw / step + 0.5) * step
            end
            setVisual(raw)
        end

        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.Parent = track

        local dragging = false
        clickBtn.MouseButton1Down:Connect(function()
            dragging = true
            local pos = UserInputService:GetMouseLocation()
            updateFromX(pos.X)
            if callback then pcall(callback, val) end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not dragging or not container.Parent then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local pos = UserInputService:GetMouseLocation()
                updateFromX(pos.X)
                if callback then pcall(callback, val) end
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        comp.set = function(v)
            setVisual(v)
        end
        comp.get = function() return val end
        setVisual(default)
        return comp
    end

    local components = {
        createSectionLabel = createSectionLabel,
        createToggle = createToggle,
        createTextbox = createTextbox,
        createButton = createButton,
        createDropdown = createDropdown,
        createSlider = createSlider,
    }
    gui.components = components

    -- ------------------------------------------------------------------------
    -- TITLE BAR
    -- ------------------------------------------------------------------------
    local titlebar = Instance.new("Frame")
    titlebar.Size = UDim2.new(1, 0, 0, 30)
    titlebar.Position = UDim2.new(0, 0, 0, 0)
    titlebar.BackgroundColor3 = THEME.topbar
    titlebar.BorderSizePixel = 0
    titlebar.Parent = mainFrame

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -70, 1, 0)
    titleText.Position = UDim2.new(0, 12, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = config.Window.Title .. "  ·  " .. config.Window.Subtitle
    titleText.TextColor3 = THEME.text
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 12
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titlebar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 24, 0, 18)
    minBtn.AnchorPoint = Vector2.new(0, 0.5)
    minBtn.Position = UDim2.new(1, -46, 0.5, 0)
    minBtn.BackgroundColor3 = THEME.panel
    minBtn.BorderSizePixel = 0
    minBtn.Text = "–"
    minBtn.TextColor3 = THEME.text
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 12
    minBtn.Parent = titlebar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)
    gui.MinBtn = minBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 24, 0, 18)
    closeBtn.AnchorPoint = Vector2.new(0, 0.5)
    closeBtn.Position = UDim2.new(1, -18, 0.5, 0)
    closeBtn.BackgroundColor3 = THEME.danger
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = THEME.text
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titlebar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
    gui.CloseBtn = closeBtn

    -- Toggle minimize behavior (we collapse the content area, not destroy).
    local contentHolder = Instance.new("Frame")
    contentHolder.Size = UDim2.new(1, 0, 1, -30)
    contentHolder.Position = UDim2.new(0, 0, 0, 30)
    contentHolder.BackgroundTransparency = 1
    contentHolder.BorderSizePixel = 0
    contentHolder.Parent = mainFrame
    gui.ContentHolder = contentHolder
    gui.Minimized = false

    minBtn.MouseButton1Click:Connect(function()
        local isMin = gui.Minimized
        gui.Minimized = not isMin
        if gui.Minimized then
            mainFrame:TweenSize(UDim2.new(0, config.Window.Size.X, 0, 30), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25)
            titleText.Text = config.Window.Title .. " (minimized)"
        else
            mainFrame:TweenSize(UDim2.new(0, config.Window.Size.X, 0, config.Window.Size.Y), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25)
            titleText.Text = config.Window.Title .. "  ·  " .. config.Window.Subtitle
        end
    end)

    -- Drag via title bar
    titlebar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    titlebar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end)
    titlebar.InputChanged:Connect(function(input)
        updateDrag(input)
    end)

    -- ------------------------------------------------------------------------
    -- SIDEBAR
    -- ------------------------------------------------------------------------
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 120, 1, 0)
    sidebar.Position = UDim2.new(0, 0, 0, 0)
    sidebar.BackgroundColor3 = THEME.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.Parent = contentHolder
    gui.Sidebar = sidebar

    -- ------------------------------------------------------------------------
    -- TAB CONTENT AREA
    -- ------------------------------------------------------------------------
    local pagesHolder = Instance.new("Frame")
    pagesHolder.Size = UDim2.new(1, -120, 1, 0)
    pagesHolder.Position = UDim2.new(0, 120, 0, 0)
    pagesHolder.BackgroundColor3 = THEME.bg2
    pagesHolder.BorderSizePixel = 0
    pagesHolder.ClipsDescendants = true
    pagesHolder.Parent = contentHolder
    gui.PagesHolder = pagesHolder

    -- ------------------------------------------------------------------------
    -- TAB SYSTEM
    -- ------------------------------------------------------------------------
    local function addTab(name, order)
        order = order or 99
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.Position = UDim2.new(0, 0, 0, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 6
        scroll.ScrollBarImageColor3 = THEME.accentDark
        scroll.CanvasSize = UDim2.new(0, 0, 0, 900)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Parent = pagesHolder
        scroll.Visible = false
        -- HACK: automatic canvas size requires the scrolling frame to be sized
        -- to the content area; using Y canvas size 0 initially, then adjust
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

        local page = {
            name = name,
            scroll = scroll,
            container = scroll,  -- components parent to this
            order = order,
        }
        gui.TabPages[name] = page
        return page
    end

    local tabNames = { "About", "Fishing", "Mining", "Misc", "Settings" }
    for idx, name in ipairs(tabNames) do
        addTab(name, idx)
    end

    -- Sidebar buttons
    for idx, name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -4, 0, 28)
        btn.Position = UDim2.new(0, 2, 0, 4 + (idx - 1) * 32)
        btn.BackgroundColor3 = (idx == 1) and THEME.accentDark or THEME.panel
        btn.BorderSizePixel = 0
        btn.Text = " " .. name
        btn.TextColor3 = (idx == 1) and THEME.accentGlow or THEME.dim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.Parent = sidebar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        gui.TabButtons[name] = btn
    end

    local function switchTab(name)
        for tabName, page in pairs(gui.TabPages) do
            if page and page.scroll then
                page.scroll.Visible = (tabName == name)
            end
        end
        for tabName, btn in pairs(gui.TabButtons) do
            if tabName == name then
                btn.BackgroundColor3 = THEME.accentDark
                btn.TextColor3 = THEME.accentGlow
            else
                btn.BackgroundColor3 = THEME.panel
                btn.TextColor3 = THEME.dim
            end
        end
        gui.ActiveTab = name
    end

    for name, btn in pairs(gui.TabButtons) do
        btn.MouseButton1Click:Connect(function()
            switchTab(name)
        end)
    end
    gui.switchTab = switchTab
    switchTab("About")

    -- ------------------------------------------------------------------------
    -- ABOUT TAB CONTENT (static)
    -- ------------------------------------------------------------------------
    local aboutPage = gui.TabPages.About
    if aboutPage then
        local function aboutLabel(text, size, color, bold)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -10, 0, (size or 10) + 4)
            lbl.Position = UDim2.new(0, 5, 0, 4)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = color or THEME.text
            lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
            lbl.TextSize = size or 10
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextYAlignment = Enum.TextYAlignment.Top
            lbl.TextWrapped = true
            lbl.Parent = aboutPage.container
            return lbl
        end
        createSectionLabel(aboutPage.container, "")
        aboutLabel("IndoHangout", 18, THEME.accentGlow, true)
        aboutLabel("Version: v1.0.0", 11, THEME.dim)
        createSectionLabel(aboutPage.container, "Overview")
        aboutLabel("Modern-minimalist automation suite for fishing, mining, and player movement.", 10, THEME.dim)
        createSectionLabel(aboutPage.container, "Credits")
        aboutLabel("• Fishing logic reference: https://robloxscripts.com", 10, THEME.dim)
        aboutLabel("• Architecture / UI reference: XRoblox/IndoVoice", 10, THEME.dim)
        createSectionLabel(aboutPage.container, "Usage")
        aboutLabel("1. Open the Fishing tab and toggle Auto Fish to start.", 10, THEME.dim)
        aboutLabel("2. Use Lock Current Spot to pin your fishing position.", 10, THEME.dim)
        aboutLabel("3. Configure profiles in Settings and save your configuration.", 10, THEME.dim)
        aboutLabel("4. Press the close button (✕) to stop all features and cleanly unload.", 10, THEME.dim)
    end

    -- ------------------------------------------------------------------------
    -- STATUS LABEL (bottom of main content)
    -- ------------------------------------------------------------------------
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -130, 0, 16)
    statusLabel.AnchorPoint = Vector2.new(0, 1)
    statusLabel.Position = UDim2.new(0, 124, 1, -4)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Ready"
    statusLabel.TextColor3 = THEME.faint
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 9
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = contentHolder
    gui.StatusLabel = statusLabel

    local function setStatus(text, color)
        statusLabel.Text = text or ""
        statusLabel.TextColor3 = color or THEME.faint
    end
    gui.setStatus = setStatus

    -- Cleanup hook for duplicate GUI prevention
    gui.Destroy = function()
        pcall(function()
            if screenGui and screenGui.Parent then
                screenGui:Destroy()
            end
        end)
        _G.__IndoHangout_Gui = nil
    end

    return gui
end