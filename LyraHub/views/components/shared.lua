-- LyraHub/views/components/shared.lua
-- View layer: presentational primitives — corners, strokes, gradients, glow,
-- soft drop shadows and tween helpers. Pure helpers; no state or business logic.

return function(theme)
    -- Accept the full config table (colors nested under .Theme) or a flat
    -- theme table. Kit convention: factory(config, shared).
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    local TweenService = game:GetService("TweenService")

    local shared = {}

    local function defaultRadius()
        return theme.ComponentDefaults and theme.ComponentDefaults.CornerRadius or UDim.new(0, 10)
    end

    -- Rounded corners
    function shared.corner(instance, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = radius or defaultRadius()
        corner.Parent = instance
        return corner
    end

    -- Outlined stroke
    function shared.stroke(instance, color, thickness, transparency)
        local stroke = Instance.new("UIStroke")
        stroke.Color = color or theme.divider
        stroke.Thickness = thickness or 1
        stroke.Transparency = transparency or 0.55
        stroke.Parent = instance
        return stroke
    end

    -- Soft glow: a thick, faint stroke (reads as a subtle bloom on dark UI)
    function shared.glow(instance, color, thickness, transparency)
        local glow = Instance.new("UIStroke")
        glow.Color = color or theme.glow
        glow.Thickness = thickness or 3
        glow.Transparency = transparency or 0.85
        glow.Parent = instance
        return glow
    end

    -- Linear gradient (Rotation 90 = top-to-bottom)
    function shared.gradient(instance, colorA, colorB, rotation)
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new(colorA, colorB)
        gradient.Rotation = rotation or 90
        gradient.Parent = instance
        return gradient
    end

    -- Soft drop shadow: an offset, slightly larger rounded frame placed behind
    -- the element in the same parent. Requires the parent not to clip it.
    function shared.shadow(instance, opts)
        opts = opts or {}
        local extendX = opts.ExtendX or 8
        local extendY = opts.ExtendY or 8
        local pos = instance.Position
        local size = instance.Size
        local shadow = Instance.new("Frame")
        shadow.Name = "Shadow"
        shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        shadow.BackgroundTransparency = opts.Transparency or 0.72
        shadow.BorderSizePixel = 0
        shadow.ZIndex = math.max((instance.ZIndex or 1) - 1, 1)
        shadow.Size = UDim2.new(size.X.Scale, size.X.Offset + extendX, size.Y.Scale, size.Y.Offset + extendY)
        shadow.Position = UDim2.new(
            pos.X.Scale, pos.X.Offset - extendX / 2 + (opts.OffsetX or 0),
            pos.Y.Scale, pos.Y.Offset - extendY / 2 + (opts.OffsetY or 4)
        )
        shared.corner(shadow, (opts.Radius or defaultRadius()) + UDim.new(0, 2))
        shadow.Parent = instance.Parent
        return shadow
    end

    -- One-shot smooth tween
    function shared.tween(instance, goal, time, style, direction)
        local tween = TweenService:Create(
            instance,
            TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
            goal
        )
        tween:Play()
        return tween
    end

    return shared
end
