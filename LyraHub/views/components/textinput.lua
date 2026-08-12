-- LyraHub/views/components/textinput.lua
-- View layer: rounded text input with placeholder, focus highlight, and a
-- clear (×) button that appears while the field has text. Commits on focus
-- lost. Controllers subscribe with OnChanged(value: string).

return function(theme, shared)
    -- Accept the full config table (colors nested under .Theme) or a flat
    -- theme table. Kit convention: factory(config, shared).
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    return function(opts)
        opts = opts or {}
        local listeners = {}
        local value = opts.Default or ""

        local frame = Instance.new("Frame")
        frame.Name = "LyraTextInput"
        frame.Size = opts.Size or UDim2.new(0, 260, 0, 36)
        frame.Position = opts.Position or UDim2.new(0, 0, 0, 0)
        frame.AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0)
        frame.BackgroundColor3 = theme.panel2
        frame.BorderSizePixel = 0
        frame.ZIndex = opts.ZIndex or 2
        frame.Parent = opts.Parent
        shared.corner(frame, opts.CornerRadius or UDim.new(0, 8))
        local frameStroke = shared.stroke(frame, theme.divider, 1, 0.55)

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -36, 1, 0)
        box.Position = UDim2.new(0, 0, 0, 0)
        box.BackgroundTransparency = 1
        box.Text = value
        box.TextColor3 = theme.text
        box.PlaceholderText = opts.Placeholder or "Type here…"
        box.PlaceholderColor3 = theme.faint
        box.Font = Enum.Font.Gotham
        box.TextSize = 12
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.ClearTextOnFocus = false
        box.BorderSizePixel = 0
        box.Parent = frame
        local boxPad = Instance.new("UIPadding")
        boxPad.PaddingLeft = UDim.new(0, 12)
        boxPad.PaddingRight = UDim.new(0, 4)
        boxPad.Parent = box

        -- Clear button, visible while there is text
        local clearBtn = Instance.new("TextButton")
        clearBtn.Size = UDim2.fromOffset(24, 24)
        clearBtn.Position = UDim2.new(1, -30, 0.5, -12)
        clearBtn.BackgroundTransparency = 1
        clearBtn.Text = "×"
        clearBtn.TextColor3 = theme.dim
        clearBtn.Font = Enum.Font.GothamBold
        clearBtn.TextSize = 14
        clearBtn.AutoButtonColor = false
        clearBtn.BorderSizePixel = 0
        clearBtn.Visible = value ~= ""
        clearBtn.Parent = frame

        local function refreshClear()
            clearBtn.Visible = box.Text ~= ""
        end

        local function notify(v)
            for _, fn in ipairs(listeners) do
                pcall(fn, v)
            end
            if opts.OnChanged then
                pcall(opts.OnChanged, v)
            end
        end

        box.Focused:Connect(function()
            shared.tween(frameStroke, { Transparency = 0.1, Color = theme.accent2 }, 0.14)
            shared.tween(frame, { BackgroundColor3 = theme.panel }, 0.14)
        end)
        box.FocusLost:Connect(function()
            shared.tween(frameStroke, { Transparency = 0.55, Color = theme.divider }, 0.18)
            shared.tween(frame, { BackgroundColor3 = theme.panel2 }, 0.18)
            refreshClear()
            value = box.Text
            notify(value)
        end)
        box:GetPropertyChangedSignal("Text"):Connect(refreshClear)

        clearBtn.MouseButton1Click:Connect(function()
            box.Text = ""
            refreshClear()
            value = ""
            notify("")
            box:CaptureFocus()
        end)

        -- Controller-facing API
        local view = {}
        view.Instance = frame
        view.Box = box
        function view.GetText()
            return box.Text
        end
        function view.SetText(text, notifyChange)
            text = tostring(text or "")
            box.Text = text
            value = text
            refreshClear()
            if notifyChange ~= false then
                notify(text)
            end
        end
        function view.OnChanged(fn)
            table.insert(listeners, fn)
        end
        return view
    end
end
