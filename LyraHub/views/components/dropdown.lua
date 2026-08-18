-- LyraHub/views/components/dropdown.lua
-- View layer: dropdown with smooth open/close (height + fade + scale) and a
-- rotating chevron. Controllers subscribe with OnSelected.

return function(theme, shared)
    -- Accept the full config table (colors nested under .Theme) or a flat
    -- theme table. Kit convention: factory(config, shared).
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    return function(opts)
        opts = opts or {}
        local listeners = {}
        local items = opts.Items or {}
        local selected = opts.Default or items[1]
        local itemHeight = opts.ItemHeight or 34

        local frame = Instance.new("Frame")
        frame.Name = "LyraDropdown"
        frame.Size = opts.Size or UDim2.new(0, 180, 0, 36)
        frame.Position = opts.Position or UDim2.new(0, 0, 0, 0)
        frame.AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0)
        frame.BackgroundTransparency = 1
        frame.ZIndex = opts.ZIndex or 10
        frame.Parent = opts.Parent

        -- Header (always visible)
        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 1, 0)
        header.BackgroundColor3 = theme.panel2
        header.Text = tostring(selected or "")
        header.TextColor3 = theme.text
        header.Font = Enum.Font.GothamBold
        header.TextSize = 12
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.AutoButtonColor = false
        header.BorderSizePixel = 0
        header.Parent = frame
        shared.corner(header, opts.CornerRadius or UDim.new(0, 8))
        shared.stroke(header, theme.divider, 1, 0.55)
        local headerPad = Instance.new("UIPadding")
        headerPad.PaddingLeft = UDim.new(0, 12)
        headerPad.Parent = header

        local chevron = Instance.new("TextLabel")
        chevron.Size = UDim2.new(0, 24, 1, 0)
        chevron.Position = UDim2.new(1, -30, 0, 0)
        chevron.BackgroundTransparency = 1
        chevron.Text = "▾"
        chevron.TextColor3 = theme.dim
        chevron.Font = Enum.Font.Gotham
        chevron.TextSize = 14
        chevron.Parent = header

        -- Animated list panel
        local list = Instance.new("Frame")
        list.Size = UDim2.new(1, 0, 0, 0)
        list.Position = UDim2.new(0, 0, 1, 6)
        list.BackgroundColor3 = theme.panel
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.ZIndex = frame.ZIndex + 20
        list.Visible = false
        list.ClipsDescendants = true
        list.Parent = frame
        shared.corner(list, UDim.new(0, 8))
        shared.stroke(list, theme.divider, 1, 0.4)

        local listScale = Instance.new("UIScale")
        listScale.Scale = 0.96
        listScale.Parent = list

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 2)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = list

        local itemButtons = {}

        local function refresh()
            for item, row in pairs(itemButtons) do
                local isSelected = item == selected
                row.BackgroundColor3 = isSelected and theme.accent or theme.panel2
                row.BackgroundTransparency = isSelected and 0.45 or 0.6
                row.TextColor3 = isSelected and Color3.new(1, 1, 1) or theme.dim
            end
        end

        local function notify(item)
            for _, fn in ipairs(listeners) do
                pcall(fn, item)
            end
            if opts.OnSelected then
                pcall(opts.OnSelected, item)
            end
        end

        -- Forward declaration so item clicks can call close()
        local close

        for i, item in ipairs(items) do
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, -8, 0, itemHeight)
            row.Position = UDim2.new(0, 4, 0, 0)
            row.BackgroundColor3 = theme.panel2
            row.BackgroundTransparency = 0.6
            row.Text = tostring(item)
            row.TextColor3 = theme.dim
            row.Font = Enum.Font.Gotham
            row.TextSize = 12
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.AutoButtonColor = false
            row.BorderSizePixel = 0
            row.LayoutOrder = i
            row.Parent = list
            shared.corner(row, UDim.new(0, 6))
            local rowPad = Instance.new("UIPadding")
            rowPad.PaddingLeft = UDim.new(0, 10)
            rowPad.Parent = row

            row.MouseEnter:Connect(function()
                shared.tween(row, { BackgroundTransparency = 0.2, TextColor3 = theme.text }, 0.1)
            end)
            row.MouseLeave:Connect(function()
                local isSelected = item == selected
                shared.tween(row, {
                    BackgroundTransparency = isSelected and 0.45 or 0.6,
                    TextColor3 = isSelected and Color3.new(1, 1, 1) or theme.dim,
                }, 0.15)
            end)

            row.MouseButton1Click:Connect(function()
                selected = item
                header.Text = tostring(item)
                refresh()
                close()
                notify(item)
            end)

            itemButtons[item] = row
        end

        local open = false

        local function openList()
            if open then
                return
            end
            open = true
            local total = #items * itemHeight + (#items - 1) * 2 + 4
            list.Visible = true
            shared.tween(list, {
                Size = UDim2.new(1, 0, 0, total),
                BackgroundTransparency = 0.08,
            }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            shared.tween(listScale, { Scale = 1 }, 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            shared.tween(chevron, { Rotation = 180 }, 0.16)
            refresh()
        end

        function close()
            if not open then
                return
            end
            open = false
            shared.tween(list, {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
            }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            shared.tween(chevron, { Rotation = 0 }, 0.12)
            task.delay(0.12, function()
                if not open then
                    list.Visible = false
                end
            end)
        end

        header.MouseButton1Click:Connect(function()
            if open then
                close()
            else
                openList()
            end
        end)
        header.MouseEnter:Connect(function()
            shared.tween(header, { BackgroundColor3 = theme.accent }, 0.12)
        end)
        header.MouseLeave:Connect(function()
            shared.tween(header, { BackgroundColor3 = theme.panel2 }, 0.2)
        end)

        refresh()

        -- Controller-facing API
        local view = {}
        view.Instance = frame
        view.Header = header
        function view.GetSelected()
            return selected
        end
        function view.SetSelected(item, notifyChange)
            selected = item
            header.Text = tostring(item)
            refresh()
            if notifyChange ~= false then
                notify(item)
            end
        end
        function view.Close()
            close()
        end
        function view.OnSelected(fn)
            table.insert(listeners, fn)
        end
        return view
    end
end
