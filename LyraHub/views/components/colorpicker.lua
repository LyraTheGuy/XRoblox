-- LyraHub/views/components/colorpicker.lua
-- View layer: color picker. A swatch button opens a popup with HSV sliders
-- (hue gradient + saturation + value gradients), a live preview and hex
-- readout, copy-to-clipboard and Done. Opens upward when it would overflow
-- the container bottom. Controllers subscribe with OnChanged(color: Color3).

return function(theme, shared)
    -- Accept the full config table (colors nested under .Theme) or a flat
    -- theme table. Kit convention: factory(config, shared).
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    local UserInputService = game:GetService("UserInputService")

    local function toHex(c)
        return string.format(
            "#%02X%02X%02X",
            math.floor(c.R * 255 + 0.5),
            math.floor(c.G * 255 + 0.5),
            math.floor(c.B * 255 + 0.5)
        )
    end

    local HUE_SEQUENCE = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
    })

    -- Gradient track slider used for hue/saturation/value
    local function makeTrack(parent, opts)
        local onChange = opts.OnChange
        local ratio = math.clamp(opts.Ratio or 0, 0, 1)

        local track = Instance.new("TextButton")
        track.Size = opts.Size
        track.Position = opts.Position
        track.BackgroundColor3 = Color3.new(1, 1, 1)
        track.BackgroundTransparency = 0.8
        track.BorderSizePixel = 0
        track.AutoButtonColor = false
        track.Text = ""
        track.Parent = parent
        shared.corner(track, UDim.new(1, 0))
        shared.stroke(track, theme.divider, 1, 0.5)
        local gradient = Instance.new("UIGradient")
        gradient.Color = opts.Sequence
        gradient.Parent = track

        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(14, 14)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.BorderSizePixel = 0
        knob.Parent = track
        shared.corner(knob, UDim.new(1, 0))
        shared.stroke(knob, theme.panel, 1.5, 0.2)

        local dragging = false
        local moveConn, endConn

        local function apply()
            knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        end

        local function setFromPos(x)
            local abs = track.AbsolutePosition
            local w = math.max(track.AbsoluteSize.X, 1)
            ratio = math.clamp((x - abs.X) / w, 0, 1)
            apply()
        end

        local function beginDrag(input)
            if dragging then
                return
            end
            dragging = true
            setFromPos(input.Position.X)
            if onChange then onChange(ratio) end
            if not moveConn then
                moveConn = UserInputService.InputChanged:Connect(function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        setFromPos(i.Position.X)
                        if onChange then onChange(ratio) end
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
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                beginDrag(input)
            end
        end)

        apply()
        return { Track = track, Gradient = gradient, Get = function() return ratio end, Set = function(r) ratio = math.clamp(r, 0, 1) apply() end }
    end

    return function(opts)
        opts = opts or {}
        local listeners = {}
        local current = opts.Default or Color3.fromHSV(0.58, 0.45, 1)
        local h, s, v = current:ToHSV()

        -- Swatch button -------------------------------------------------------
        local button = Instance.new("TextButton")
        button.Name = "LyraColorPicker"
        button.Size = opts.Size or UDim2.new(0, 180, 0, 36)
        button.Position = opts.Position or UDim2.new(0, 0, 0, 0)
        button.AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0)
        button.BackgroundColor3 = theme.panel2
        button.TextColor3 = theme.text
        button.Font = Enum.Font.GothamBold
        button.TextSize = 12
        button.AutoButtonColor = false
        button.BorderSizePixel = 0
        button.ZIndex = opts.ZIndex or 2
        button.Parent = opts.Parent
        shared.corner(button, opts.CornerRadius or UDim.new(0, 8))
        shared.stroke(button, theme.divider, 1, 0.55)

        local swatch = Instance.new("Frame")
        swatch.Size = UDim2.fromOffset(20, 20)
        swatch.Position = UDim2.fromOffset(8, 8)
        swatch.BackgroundColor3 = current
        swatch.BorderSizePixel = 0
        swatch.Parent = button
        shared.corner(swatch, UDim.new(0, 5))
        shared.stroke(swatch, theme.divider, 1, 0.35)

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 36)
        pad.Parent = button

        -- Popup ---------------------------------------------------------------
        local popup = Instance.new("Frame")
        popup.Name = "ColorPopup"
        popup.Size = UDim2.fromOffset(240, 196)
        popup.BackgroundColor3 = theme.panel
        popup.BorderSizePixel = 0
        popup.Visible = false
        popup.ZIndex = 100 -- above the scrim (90) and the window canvas (1)
        -- Hosted at ScreenGui level so it floats over the window (and is not
        -- clipped by main). Positioned in screen coordinates on open.
        popup.Parent = button:FindFirstAncestorOfClass("ScreenGui") or opts.Parent
        shared.corner(popup, UDim.new(0, 10))
        shared.stroke(popup, theme.divider, 1, 0.4)
        shared.glow(popup, theme.glow, 3, 0.85)

        local preview = Instance.new("Frame")
        preview.Size = UDim2.fromOffset(44, 44)
        preview.Position = UDim2.fromOffset(12, 12)
        preview.BackgroundColor3 = current
        preview.BorderSizePixel = 0
        preview.Parent = popup
        shared.corner(preview, UDim.new(0, 8))
        shared.stroke(preview, theme.divider, 1, 0.4)

        local hexLbl = Instance.new("TextLabel")
        hexLbl.Size = UDim2.fromOffset(160, 18)
        hexLbl.Position = UDim2.fromOffset(66, 14)
        hexLbl.BackgroundTransparency = 1
        hexLbl.Text = toHex(current)
        hexLbl.TextColor3 = theme.text
        hexLbl.Font = Enum.Font.GothamBold
        hexLbl.TextSize = 13
        hexLbl.Parent = popup

        local function trackLabel(text, y)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.fromOffset(30, 12)
            lbl.Position = UDim2.fromOffset(12, y)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = theme.faint
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 8
            lbl.Parent = popup
        end

        trackLabel("HUE", 50)
        trackLabel("SAT", 78)
        trackLabel("VAL", 106)

        -- Forward-declared: the track OnChange closures below call these at
        -- runtime, so they must be captured as upvalues, not resolved as
        -- (nil) globals. Defined right after the tracks are built.
        local currentColor, refresh, notify

        local hueTrack = makeTrack(popup, {
            Size = UDim2.fromOffset(176, 8), Position = UDim2.fromOffset(52, 50),
            Sequence = HUE_SEQUENCE, Ratio = h,
            OnChange = function(r) h = r refresh() notify(currentColor()) end,
        })
        local satTrack = makeTrack(popup, {
            Size = UDim2.fromOffset(176, 8), Position = UDim2.fromOffset(52, 78),
            Sequence = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)), Ratio = s,
            OnChange = function(r) s = r refresh() notify(currentColor()) end,
        })
        local valTrack = makeTrack(popup, {
            Size = UDim2.fromOffset(176, 8), Position = UDim2.fromOffset(52, 106),
            Sequence = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0)), Ratio = v,
            OnChange = function(r) v = r refresh() notify(currentColor()) end,
        })

        currentColor = function()
            return Color3.fromHSV(h, s, v)
        end

        refresh = function()
            local c = currentColor()
            swatch.BackgroundColor3 = c
            preview.BackgroundColor3 = c
            hexLbl.Text = toHex(c)
            button.Text = toHex(c)
            satTrack.Gradient.Color = ColorSequence.new(Color3.fromHSV(h, 0, 1), Color3.fromHSV(h, 1, 1))
            valTrack.Gradient.Color = ColorSequence.new(Color3.fromHSV(h, s, 0), Color3.fromHSV(h, s, 1))
        end

        notify = function(c)
            for _, fn in ipairs(listeners) do
                pcall(fn, c)
            end
            if opts.OnChanged then
                pcall(opts.OnChanged, c)
            end
        end

        local copyBtn = Instance.new("TextButton")
        copyBtn.Size = UDim2.fromOffset(70, 26)
        copyBtn.Position = UDim2.fromOffset(12, 154)
        copyBtn.BackgroundColor3 = theme.panel2
        copyBtn.Text = "Copy hex"
        copyBtn.TextColor3 = theme.dim
        copyBtn.Font = Enum.Font.GothamBold
        copyBtn.TextSize = 10
        copyBtn.AutoButtonColor = false
        copyBtn.BorderSizePixel = 0
        copyBtn.Parent = popup
        shared.corner(copyBtn, UDim.new(0, 6))
        shared.stroke(copyBtn, theme.divider, 1, 0.5)

        local doneBtn = Instance.new("TextButton")
        doneBtn.Size = UDim2.fromOffset(70, 26)
        doneBtn.Position = UDim2.fromOffset(158, 154)
        doneBtn.BackgroundColor3 = theme.accent
        doneBtn.Text = "Done"
        doneBtn.TextColor3 = Color3.new(1, 1, 1)
        doneBtn.Font = Enum.Font.GothamBold
        doneBtn.TextSize = 10
        doneBtn.AutoButtonColor = false
        doneBtn.BorderSizePixel = 0
        doneBtn.Parent = popup
        shared.corner(doneBtn, UDim.new(0, 6))


        -- Open / close -----------------------------------------------------------
        local open = false
        local escapeConn
        local scrim

        local function close()
            if not open then
                return
            end
            open = false
            popup.Visible = false
            if scrim then
                scrim:Destroy()
                scrim = nil
            end
            if escapeConn then
                escapeConn:Disconnect()
                escapeConn = nil
            end
            shared.tween(button, { BackgroundColor3 = theme.panel2 }, 0.15)
        end

        local function openPopup()
            if open then
                return
            end
            open = true
            refresh()
            -- Click-anywhere-to-close scrim (below the popup, above the window)
            local screenGui = button:FindFirstAncestorOfClass("ScreenGui")
            if screenGui then
                scrim = Instance.new("TextButton")
                scrim.Name = "ColorScrim"
                scrim.Size = UDim2.new(1, 0, 1, 0)
                scrim.BackgroundTransparency = 1
                scrim.Text = ""
                scrim.AutoButtonColor = false
                scrim.BorderSizePixel = 0
                scrim.ZIndex = 90
                scrim.Parent = screenGui
                scrim.MouseButton1Click:Connect(close)
            end
            -- Screen-space positioning (survives window drags); opens upward
            -- when the popup would overflow the swatch's container below.
            local popupH = popup.Size.Y.Offset
            local popupW = popup.Size.X.Offset
            local below = button.AbsolutePosition.Y + button.AbsoluteSize.Y + 8
            local openUp = false
            local parent = button.Parent
            if parent then
                openUp = (below + popupH) > (parent.AbsolutePosition.Y + parent.AbsoluteSize.Y)
            end
            local posX = button.AbsolutePosition.X
            local posY = openUp and (button.AbsolutePosition.Y - popupH - 8) or below
            -- Clamp to the viewport so the popup stays fully on screen even
            -- when the window has been dragged to an edge.
            if screenGui then
                local vs = screenGui.AbsoluteSize
                local margin = 8
                posX = math.clamp(posX, margin, math.max(margin, vs.X - popupW - margin))
                posY = math.clamp(posY, margin, math.max(margin, vs.Y - popupH - margin))
            end
            popup.Position = UDim2.fromOffset(posX, posY)
            popup.Visible = true
            shared.tween(button, { BackgroundColor3 = theme.accent }, 0.15)
            if not escapeConn then
                escapeConn = UserInputService.InputBegan:Connect(function(input)
                    if open and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape then
                        close()
                    end
                end)
            end
        end

        button.MouseButton1Click:Connect(function()
            if open then
                close()
            else
                openPopup()
            end
        end)
        doneBtn.MouseButton1Click:Connect(close)

        copyBtn.MouseButton1Click:Connect(function()
            pcall(function()
                game:GetService("Clipboard"):settext(toHex(currentColor()))
            end)
        end)

        refresh()

        -- Controller-facing API
        local view = {}
        view.Instance = button
        view.Swatch = swatch
        function view.Get()
            return currentColor()
        end
        function view.Set(color, notifyChange)
            color = color or currentColor()
            if color == currentColor() then
                return
            end
            h, s, v = color:ToHSV()
            hueTrack.Set(h)
            satTrack.Set(s)
            valTrack.Set(v)
            refresh()
            if notifyChange ~= false then
                notify(color)
            end
        end
        function view.Close()
            -- Closes the popup + destroys the scrim. Safe to call anytime.
            close()
        end
        function view.OnChanged(fn)
            table.insert(listeners, fn)
        end
        return view
    end
end
