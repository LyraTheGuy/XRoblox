-- IndoHangout/views/components/button.lua
-- View layer: rounded button with hover color transition + springy press
-- animation (UIScale squish). Exposes a small controller-facing API.
-- Ported from LyraHub/views/components/button.lua.

return function(theme, shared)
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    return function(opts)
        opts = opts or {}
        local baseTransparency = opts.BackgroundTransparency or 0
        local baseColor = opts.Color or theme.panel2

        local button = Instance.new("TextButton")
        button.Name = "IndoButton"
        button.Size = opts.Size or UDim2.new(0, 160, 0, 40)
        button.Position = opts.Position or UDim2.new(0, 0, 0, 0)
        button.AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0)
        button.BackgroundColor3 = baseColor
        button.BackgroundTransparency = baseTransparency
        button.Text = opts.Text or "Button"
        button.TextColor3 = opts.TextColor or theme.text
        button.Font = opts.Font or Enum.Font.GothamBold
        button.TextSize = opts.TextSize or 13
        button.TextTransparency = opts.TextTransparency or 0
        button.AutoButtonColor = false
        button.BorderSizePixel = 0
        button.ZIndex = opts.ZIndex or 2
        button.Parent = opts.Parent

        shared.corner(button, opts.CornerRadius or theme.ComponentDefaults.CornerRadius)
        shared.stroke(button, opts.StrokeColor or theme.divider, 1, opts.StrokeTransparency or 0.55)
        if opts.Glow ~= false then
            shared.glow(button, opts.GlowColor or theme.glow, 3, opts.GlowTransparency or 0.9)
        end

        local scale = Instance.new("UIScale")
        scale.Parent = button

        local hoverColor = opts.HoverColor or theme.accent

        button.MouseEnter:Connect(function()
            shared.tween(button, {
                BackgroundColor3 = hoverColor,
                BackgroundTransparency = math.max(baseTransparency - 0.06, 0),
            }, 0.12)
        end)
        button.MouseLeave:Connect(function()
            shared.tween(button, { BackgroundColor3 = baseColor, BackgroundTransparency = baseTransparency }, 0.2)
        end)

        button.MouseButton1Down:Connect(function()
            shared.tween(scale, { Scale = opts.PressScale or theme.ComponentDefaults.PressScale }, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
        button.MouseButton1Up:Connect(function()
            shared.tween(scale, { Scale = 1 }, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end)

        if opts.OnClick then
            button.MouseButton1Click:Connect(opts.OnClick)
        end

        local view = {}
        view.Instance = button
        function view.SetText(text)
            button.Text = text
        end
        function view.SetEnabled(enabled)
            button.Active = enabled
            button.TextTransparency = enabled and 0 or 0.55
            shared.tween(button, {
                BackgroundTransparency = enabled and baseTransparency or 0.65,
                BackgroundColor3 = enabled and baseColor or theme.panel,
            }, 0.15)
        end
        function view.SetColor(color)
            color = color or theme.panel2
            baseColor = color
            hoverColor = color:Lerp(Color3.new(1, 1, 1), 0.15)
            shared.tween(button, { BackgroundColor3 = color }, 0.15)
        end
        return view
    end
end
