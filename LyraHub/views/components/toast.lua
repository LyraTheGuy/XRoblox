-- LyraHub/views/components/toast.lua
-- View layer: animated, stackable notification toasts (info / warn / error /
-- success). They render into a bottom-center stack, slide in, auto-fade out,
-- and dismiss on click. Creates its own ScreenGui when none is given, so any
-- layer holding the component can show a toast with one call.

return function(theme, shared)
    -- Accept the full config table (colors nested under .Theme) or a flat
    -- theme table. Kit convention: factory(config, shared).
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    local VARIANTS = {
        info    = { icon = "ℹ", color = theme.accent2 or theme.accent },
        warn    = { icon = "⚠", color = theme.warn },
        error   = { icon = "✕", color = theme.danger },
        success = { icon = "✓", color = theme.success },
    }

    local stacks = {} -- ScreenGui -> stack frame

    local function stackFor(gui)
        local stack = stacks[gui]
        if stack and stack.Parent then
            return stack
        end
        stack = gui:FindFirstChild("LyraToastStack")
        if not stack then
            stack = Instance.new("Frame")
            stack.Name = "LyraToastStack"
            stack.Size = UDim2.new(1, -40, 0, 0)
            stack.Position = UDim2.new(0.5, 0, 1, -24)
            stack.AnchorPoint = Vector2.new(0.5, 1)
            stack.BackgroundTransparency = 1
            stack.BorderSizePixel = 0
            stack.AutomaticSize = Enum.AutomaticSize.Y
            stack.ZIndex = 10
            stack.Parent = gui

            local layout = Instance.new("UIListLayout")
            layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            layout.Padding = UDim.new(0, 6)
            layout.Parent = stack
        end
        stacks[gui] = stack
        return stack
    end

    local function ensureGui(opts)
        local gui = opts.ScreenGui
        if gui then
            return gui
        end
        gui = Instance.new("ScreenGui")
        gui.Name = "LyraKitToast"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 9998
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not gui.Parent then
            gui.Parent = lp:WaitForChild("PlayerGui")
        end
        return gui
    end

    local function show(opts)
        opts = opts or {}
        local variant = VARIANTS[opts.Variant or "warn"] or VARIANTS.warn
        local duration = opts.Duration or 10
        local gui = ensureGui(opts)
        local stack = stackFor(gui)

        local toast = Instance.new("TextButton")
        toast.Size = opts.Size or UDim2.new(0, 400, 0, 46)
        toast.BackgroundColor3 = theme.panel2 or Color3.fromRGB(26, 22, 16)
        toast.BackgroundTransparency = 0.05
        toast.AutoButtonColor = false
        toast.BorderSizePixel = 0
        toast.Text = ""
        toast.ZIndex = 11
        toast.Parent = stack
        shared.corner(toast, UDim.new(0, 10))
        shared.stroke(toast, variant.color, 1, 0.25)

        local icon = Instance.new("TextLabel")
        icon.Text = variant.icon
        icon.Size = UDim2.new(0, 30, 1, 0)
        icon.Position = UDim2.new(0, 10, 0, 0)
        icon.BackgroundTransparency = 1
        icon.TextColor3 = variant.color
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 15
        icon.Parent = toast

        local text = Instance.new("TextLabel")
        text.Text = opts.Text or ""
        text.Size = UDim2.new(1, -48, 1, -8)
        text.Position = UDim2.new(0, 42, 0, 4)
        text.BackgroundTransparency = 1
        text.TextColor3 = theme.text or Color3.new(1, 1, 1)
        text.Font = Enum.Font.Gotham
        text.TextSize = opts.TextSize or 11
        text.TextWrapped = true
        text.TextXAlignment = Enum.TextXAlignment.Left
        text.TextYAlignment = Enum.TextYAlignment.Center
        text.Parent = toast

        -- Entrance: fade in with a slight rise
        toast.BackgroundTransparency = 1
        text.TextTransparency = 1
        icon.TextTransparency = 1
        shared.tween(toast, { BackgroundTransparency = 0.05 }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        shared.tween(text, { TextTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        shared.tween(icon, { TextTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        local closed = false
        local function close()
            if closed then
                return
            end
            closed = true
            -- The toast may have been destroyed externally (e.g. the host
            -- cleared the ScreenGui) before the auto-close fired — bail.
            if not toast.Parent then
                pcall(function() toast:Destroy() end)
                return
            end
            shared.tween(toast, { BackgroundTransparency = 1 }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            shared.tween(text, { TextTransparency = 1 }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            shared.tween(icon, { TextTransparency = 1 }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.3, function()
                pcall(function() toast:Destroy() end)
            end)
        end

        toast.MouseButton1Click:Connect(close)
        task.delay(duration, close)

        return { Instance = toast, Close = close }
    end

    return {
        Show = show,
        show = show,
        CloseAll = function(gui)
            local stack = gui and stacks[gui]
            if not stack then
                return
            end
            for _, child in ipairs(stack:GetChildren()) do
                pcall(function() child:Destroy() end)
            end
        end,
    }
end
