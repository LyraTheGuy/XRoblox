-- LyraHub/views/components/keybind.lua
-- View layer: keybind picker. Shows the current key; clicking enters capture
-- mode ("Press any key…" with a pulsing red REC dot) and the next keyboard key
-- is bound. Esc or clicking anywhere cancels. Controllers subscribe with
-- OnChanged(key: Enum.KeyCode).

return function(theme, shared)
    -- Accept the full config table (colors nested under .Theme) or a flat
    -- theme table. Kit convention: factory(config, shared).
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")

    return function(opts)
        opts = opts or {}
        local listeners = {}
        local current = opts.Default or Enum.KeyCode.X
        local listening = false
        local captureConn
        local scrim
        local pulseTween

        local button = Instance.new("TextButton")
        button.Name = "LyraKeybind"
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
        local buttonStroke = shared.stroke(button, theme.divider, 1, 0.55)

        -- Small key icon so it reads as a keybind at a glance
        local icon = Instance.new("Frame")
        icon.Size = UDim2.fromOffset(20, 20)
        icon.Position = UDim2.fromOffset(8, 8)
        icon.BackgroundColor3 = theme.accent
        icon.BackgroundTransparency = 0.25
        icon.BorderSizePixel = 0
        icon.Parent = button
        shared.corner(icon, UDim.new(0, 5))
        local iconText = Instance.new("TextLabel")
        iconText.Size = UDim2.new(1, 0, 1, 0)
        iconText.BackgroundTransparency = 1
        iconText.Text = "KEY"
        iconText.TextColor3 = Color3.new(1, 1, 1)
        iconText.Font = Enum.Font.GothamBold
        iconText.TextSize = 6
        iconText.Parent = icon

        -- REC dot — blinks while listening
        local recDot = Instance.new("Frame")
        recDot.Size = UDim2.fromOffset(8, 8)
        recDot.Position = UDim2.new(1, -14, 0.5, -4)
        recDot.BackgroundColor3 = theme.danger
        recDot.BackgroundTransparency = 0.3
        recDot.BorderSizePixel = 0
        recDot.Visible = false
        recDot.Parent = button
        shared.corner(recDot, UDim.new(1, 0))
        shared.glow(recDot, theme.danger, 2, 0.4)

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 36)
        pad.Parent = button

        local function refreshText()
            button.Text = listening and "Press any key…" or (current and current.Name or "None")
        end

        -- Pulse animation (infinite tween on the REC dot)
        local function stopPulse()
            if pulseTween then
                pulseTween:Cancel()
                pulseTween = nil
            end
            recDot.Visible = false
            recDot.BackgroundTransparency = 0.3
        end

        local function startPulse()
            stopPulse()
            recDot.Visible = true
            pulseTween = TweenService:Create(
                recDot,
                -- repeatCount=-1 (infinite) + reverses=true (smooth ping-pong)
                TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
                { BackgroundTransparency = 0.75 }
            )
            pulseTween:Play()
        end

        -- Full-screen transparent scrim so clicking anywhere cancels listening
        local function showScrim()
            if scrim then
                return
            end
            local gui = button:FindFirstAncestorOfClass("ScreenGui")
            if not gui then
                return
            end
            scrim = Instance.new("TextButton")
            scrim.Name = "KeybindScrim"
            scrim.Size = UDim2.new(1, 0, 1, 0)
            scrim.BackgroundTransparency = 1
            scrim.Text = ""
            scrim.AutoButtonColor = false
            scrim.BorderSizePixel = 0
            scrim.ZIndex = 90
            scrim.Parent = gui
            scrim.MouseButton1Click:Connect(stopListening)
        end

        local function hideScrim()
            if scrim then
                scrim:Destroy()
                scrim = nil
            end
        end

        local function stopListening()
            if not listening then
                return
            end
            listening = false
            refreshText()
            stopPulse()
            hideScrim()
            shared.tween(button, { BackgroundColor3 = theme.panel2 }, 0.15)
            shared.tween(buttonStroke, { Transparency = 0.55, Color = theme.divider }, 0.15)
            if captureConn then
                captureConn:Disconnect()
                captureConn = nil
            end
        end

        local function startListening()
            if listening then
                return
            end
            listening = true
            refreshText()
            startPulse()
            showScrim()
            shared.tween(button, { BackgroundColor3 = theme.accent }, 0.15)
            shared.tween(buttonStroke, { Transparency = 0.2, Color = theme.danger }, 0.15)
            if not captureConn then
                captureConn = UserInputService.InputBegan:Connect(function(input)
                    if not listening then
                        return
                    end
                    if input.UserInputType ~= Enum.UserInputType.Keyboard then
                        return
                    end
                    local key = input.KeyCode
                    if key == Enum.KeyCode.Unknown then
                        return
                    end
                    if key == Enum.KeyCode.Escape then
                        pcall(stopListening) -- Esc cancels without rebinding
                        return
                    end
                    current = key
                    pcall(stopListening) -- pcall guards teardown mid-capture
                    for _, fn in ipairs(listeners) do
                        pcall(fn, current)
                    end
                    if opts.OnChanged then
                        pcall(opts.OnChanged, current)
                    end
                end)
            end
        end

        button.MouseButton1Click:Connect(function()
            if listening then
                stopListening()
            else
                startListening()
            end
        end)
        button.MouseEnter:Connect(function()
            if not listening then
                shared.tween(button, { BackgroundColor3 = theme.accent }, 0.12)
            end
        end)
        button.MouseLeave:Connect(function()
            if not listening then
                shared.tween(button, { BackgroundColor3 = theme.panel2 }, 0.2)
            end
        end)

        refreshText()

        -- Controller-facing API
        local view = {}
        view.Instance = button
        function view.Get()
            return current
        end
        function view.Set(key, notifyChange)
            if key == current then
                return
            end
            current = key
            if not listening then
                refreshText()
            end
            if notifyChange ~= false then
                for _, fn in ipairs(listeners) do
                    pcall(fn, current)
                end
                if opts.OnChanged then
                    pcall(opts.OnChanged, current)
                end
            end
        end
        function view.Cancel()
            -- Stops listening + hides the scrim. Safe to call anytime.
            stopListening()
        end
        function view.OnChanged(fn)
            table.insert(listeners, fn)
        end
        return view
    end
end
