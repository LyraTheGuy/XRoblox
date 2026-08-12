-- LyraHub/views/components/slider.lua
-- View layer: draggable slider — horizontal or vertical. Knob + fill track the
-- ratio (0..1). Controllers subscribe with OnChanged.

return function(theme, shared)
    -- Accept the full config table (colors nested under .Theme) or a flat
    -- theme table. Kit convention: factory(config, shared).
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    local UserInputService = game:GetService("UserInputService")

    return function(opts)
        opts = opts or {}
        local listeners = {}
        local vertical = (opts.Orientation or "horizontal") == "vertical"
        local value = math.clamp(opts.Default or 0, 0, 1)
        local trackThickness = opts.TrackThickness or 6

        local track = Instance.new("TextButton")
        track.Name = "LyraSlider"
        track.BackgroundColor3 = theme.panel2
        track.BorderSizePixel = 0
        track.AutoButtonColor = false
        track.Text = ""
        track.ZIndex = opts.ZIndex or 2
        track.Parent = opts.Parent
        if vertical then
            track.Size = opts.Size or UDim2.new(0, trackThickness, 0, 120)
            track.AnchorPoint = opts.AnchorPoint or Vector2.new(0.5, 0)
        else
            track.Size = opts.Size or UDim2.new(0, 220, 0, trackThickness)
            track.AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0.5)
        end
        track.Position = opts.Position or UDim2.new(0, 0, 0, 0)
        shared.corner(track, UDim.new(1, 0))

        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = opts.FillColor or theme.accent
        fill.BorderSizePixel = 0
        fill.Parent = track
        shared.corner(fill, UDim.new(1, 0))
        if vertical then
            fill.AnchorPoint = Vector2.new(0, 1)
            fill.Position = UDim2.new(0, 0, 1, 0)
            fill.Size = UDim2.new(1, 0, value, 0)
        else
            fill.AnchorPoint = Vector2.new(0, 0.5)
            fill.Position = UDim2.new(0, 0, 0.5, 0)
            fill.Size = UDim2.new(value, 0, 1, 0)
        end

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, opts.KnobSize or 16, 0, opts.KnobSize or 16)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.BorderSizePixel = 0
        knob.Parent = track
        shared.corner(knob, UDim.new(1, 0))
        shared.stroke(knob, theme.accent, 1.5, 0.3)

        local function applyPosition()
            if vertical then
                fill.Size = UDim2.new(1, 0, value, 0)
                knob.Position = UDim2.new(0.5, 0, value, 0)
            else
                fill.Size = UDim2.new(value, 0, 1, 0)
                knob.Position = UDim2.new(value, 0, 0.5, 0)
            end
        end

        local function notify(ratio)
            for _, fn in ipairs(listeners) do
                pcall(fn, ratio)
            end
            if opts.OnChanged then
                pcall(opts.OnChanged, ratio)
            end
        end

        local function setFromInput(position)
            local absPos = track.AbsolutePosition
            local absSize = track.AbsoluteSize
            local ratio
            if vertical then
                ratio = (position.Y - absPos.Y) / math.max(absSize.Y, 1)
            else
                ratio = (position.X - absPos.X) / math.max(absSize.X, 1)
            end
            value = math.clamp(ratio, 0, 1)
            applyPosition()
            notify(value)
        end

        -- Drag handling (connections live only while dragging)
        local dragging = false
        local moveConn, endConn

        local function beginDrag(input)
            dragging = true
            setFromInput(input.Position)
            if not moveConn then
                moveConn = UserInputService.InputChanged:Connect(function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        setFromInput(i.Position)
                    end
                end)
            end
            if not endConn then
                endConn = UserInputService.InputEnded:Connect(function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
                        dragging = false
                        if moveConn then
                            moveConn:Disconnect()
                            moveConn = nil
                        end
                        if endConn then
                            endConn:Disconnect()
                            endConn = nil
                        end
                    end
                end)
            end
        end

        knob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                beginDrag(input)
            end
        end)

        -- Click anywhere on the track to jump the value. Uses setFromInput
        -- directly instead of beginDrag: MouseButton1Click fires after this
        -- click's InputEnded, so beginDrag's endConn would never see the
        -- release and the drag connections would leak until the next click.
        track.MouseButton1Click:Connect(function(input)
            if input then
                setFromInput(input.Position)
            end
        end)

        applyPosition()

        -- Controller-facing API
        local view = {}
        view.Instance = track
        view.Knob = knob
        function view.Get()
            return value
        end
        function view.Set(ratio, notifyChange)
            ratio = math.clamp(tonumber(ratio) or 0, 0, 1)
            if math.abs(ratio - value) < 0.001 then
                return
            end
            value = ratio
            applyPosition()
            if notifyChange ~= false then
                notify(value)
            end
        end
        function view.OnChanged(fn)
            table.insert(listeners, fn)
        end
        return view
    end
end
