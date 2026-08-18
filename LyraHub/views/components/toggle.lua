-- LyraHub/views/components/toggle.lua
-- View layer: pill toggle switch. The knob slides with a smooth tween and the
-- track cross-fades between off/on colors. Controllers subscribe with OnChanged.

return function(theme, shared)
    -- Accept the full config table (colors nested under .Theme) or a flat
    -- theme table. Kit convention: factory(config, shared).
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    return function(opts)
        opts = opts or {}
        local listeners = {}
        local enabled = opts.Default or false
        local knobPad = opts.KnobPad or 2
        local knobSize = opts.KnobSize or UDim2.new(0, 20, 0, 20)

        local track = Instance.new("TextButton")
        track.Name = "LyraToggle"
        track.Size = opts.Size or UDim2.new(0, 46, 0, 24)
        track.Position = opts.Position or UDim2.new(0, 0, 0, 0)
        track.AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0.5)
        track.BackgroundColor3 = opts.OffColor or theme.panel2
        track.AutoButtonColor = false
        track.BorderSizePixel = 0
        track.Text = ""
        track.ZIndex = opts.ZIndex or 2
        track.Parent = opts.Parent
        shared.corner(track, UDim.new(1, 0)) -- pill shape
        shared.stroke(track, theme.divider, 1, 0.5)

        local knob = Instance.new("Frame")
        knob.Size = knobSize
        knob.AnchorPoint = Vector2.new(0, 0.5)
        knob.Position = UDim2.new(0, knobPad, 0.5, 0)
        knob.BackgroundColor3 = theme.dim
        knob.BorderSizePixel = 0
        knob.Parent = track
        shared.corner(knob, UDim.new(1, 0))

        -- Subtle glow that brightens when enabled
        local glow = shared.glow(track, theme.glow, 2, 0.95)

        local function notify(value)
            for _, fn in ipairs(listeners) do
                pcall(fn, value)
            end
            if opts.OnChanged then
                pcall(opts.OnChanged, value)
            end
        end

        local function apply()
            local goalPos = enabled
                and UDim2.new(1, -knobPad - knobSize.X.Offset, 0.5, 0)
                or UDim2.new(0, knobPad, 0.5, 0)
            shared.tween(track, {
                BackgroundColor3 = enabled and (opts.OnColor or theme.success) or (opts.OffColor or theme.panel2),
            }, 0.16)
            shared.tween(knob, {
                Position = goalPos,
                BackgroundColor3 = enabled and (opts.KnobOnColor or Color3.new(1, 1, 1)) or (opts.KnobOffColor or theme.dim),
            }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            shared.tween(glow, { Transparency = enabled and 0.8 or 0.95 }, 0.18)
        end

        track.MouseButton1Click:Connect(function()
            enabled = not enabled
            apply()
            notify(enabled)
        end)
        track.MouseEnter:Connect(function()
            shared.tween(track, { BackgroundTransparency = 0.05 }, 0.12)
        end)
        track.MouseLeave:Connect(function()
            shared.tween(track, { BackgroundTransparency = 0 }, 0.18)
        end)

        apply()

        -- Controller-facing API
        local view = {}
        view.Instance = track
        function view.Get()
            return enabled
        end
        function view.Set(value, notifyChange)
            value = not not value
            if value == enabled then
                return
            end
            enabled = value
            apply()
            if notifyChange ~= false then
                notify(enabled)
            end
        end
        function view.Toggle()
            view.Set(not enabled)
        end
        function view.OnChanged(fn)
            table.insert(listeners, fn)
        end
        return view
    end
end
