-- RideAPet/modules/ui.lua
-- UI bindings: window drag, minimize, tab switching, startup
return function(ctx)
    local gui = ctx.gui
    local config = ctx.config
    local THEME = config.Theme
    local UserInputService = ctx.UserInputService
    local TweenService = ctx.TweenService

    -- ═══════════════════════════════════════════
    -- WINDOW DRAG
    -- ═══════════════════════════════════════════
    ctx.bind(gui.DragBar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ctx.draggingUI = true
            ctx.dragStart = input.Position
            ctx.startPos = gui.Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    ctx.draggingUI = false
                end
            end)
        end
    end)

    ctx.bind(UserInputService.InputChanged, function(input)
        if ctx.draggingUI and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - ctx.dragStart
            gui.Main.Position = UDim2.new(ctx.startPos.X.Scale, ctx.startPos.X.Offset + delta.X, ctx.startPos.Y.Scale, ctx.startPos.Y.Offset + delta.Y)
        end
    end)

    -- ═══════════════════════════════════════════
    -- MINIMIZE / RESTORE
    -- ═══════════════════════════════════════════
    local function toggleMinimize()
        ctx.minimized = not ctx.minimized
        if ctx.minimized then
            gui.Main.Size = UDim2.new(0, 620, 0, 40)
            gui.Main.Position = UDim2.new(0.5, 0, 0, 20)
            gui.Main.BackgroundTransparency = 0.3
        else
            gui.Main.Size = UDim2.fromOffset(config.Window.Size.X, config.Window.Size.Y)
            gui.Main.Position = UDim2.new(0.5, 0, 0.5, 0)
            gui.Main.BackgroundTransparency = 0
        end
    end

    ctx.bind(gui.MinBtn.MouseButton1Click, toggleMinimize)

    -- ═══════════════════════════════════════════
    -- TAB SWITCHING
    -- ═══════════════════════════════════════════
    local function switchTab(name)
        ctx.activeTab = name
        for tabName, frame in pairs(gui.Tabs) do
            frame.Visible = (tabName == name)
        end
        for tabName, btn in pairs(gui.TabButtons) do
            if tabName == name then
                btn.BackgroundColor3 = THEME.accent
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                btn.BackgroundColor3 = THEME.panel2
                btn.TextColor3 = THEME.dim
            end
        end
    end

    for name, btn in pairs(gui.TabButtons) do
        ctx.bind(btn.MouseButton1Click, function()
            switchTab(name)
        end)
    end

    -- ═══════════════════════════════════════════
    -- STARTUP ANIMATION
    -- ═══════════════════════════════════════════
    task.spawn(function()
        gui.Main.BackgroundTransparency = 1
        gui.Main.Size = UDim2.new(0, config.Window.Size.X, 0, 0)
        gui.Main.Position = UDim2.new(0.5, 0, 0.5, 40)

        TweenService:Create(gui.Main, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {
            BackgroundTransparency = 0,
            Size = UDim2.fromOffset(config.Window.Size.X, config.Window.Size.Y),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }):Play()

        ctx.log("Ride A Pet loaded successfully!", THEME.success)
    end)

    ctx.log("UI module loaded", THEME.success)
end
