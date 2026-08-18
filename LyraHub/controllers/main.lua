-- LyraHub/controllers/main.lua
-- Controller layer: window chrome behavior — drag, minimize/expand, hide
-- keybind, tab switching, and full teardown. Pure orchestration; it never
-- touches component internals and drives the window purely through the
-- observable store ("visible", "minimized", "uiOpen").

return function(view, model, config)
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")

    -- Tabs ---------------------------------------------------------------------
    for _, name in ipairs(view.TabOrder) do
        view.Tabs[name].Button.MouseButton1Click:Connect(function()
            view.SetActiveTab(name)
        end)
    end

    -- Drag (with the shadow following the window) -------------------------------
    local dragConn
    view.DragHit.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        local startPos = view.Main.Position
        local startMouse = input.Position
        if dragConn then dragConn:Disconnect() end
        dragConn = UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local delta = i.Position - startMouse
            local newPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            view.Main.Position = newPos
            if view.Shadow then
                view.Shadow.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset - 4, newPos.Y.Scale, newPos.Y.Offset)
            end
        end)
        local endConn = UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                if dragConn then
                    dragConn:Disconnect()
                    dragConn = nil
                end
                endConn:Disconnect()
            end
        end)
    end)

    -- Minimize / expand ----------------------------------------------------------
    local function applyMinimized(minimized)
        if minimized then
            local tween = TweenService:Create(view.Canvas, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
            tween:Play()
            tween.Completed:Once(function()
                view.Canvas.Visible = false
                -- Reset the scale each time so the pop-in replays on every expand
                view.MinScale.Scale = 0.9
                view.Minimized.Visible = true
                TweenService:Create(view.MinScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
            end)
        else
            view.Minimized.Visible = false
            view.Canvas.Visible = true
            view.Canvas.GroupTransparency = 1
            TweenService:Create(view.Canvas, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
        end
    end
    model.onChange("minimized", applyMinimized)
    view.MinBtn.MouseButton1Click:Connect(function() model.set("minimized", true) end)
    view.ExpandBtn.Instance.MouseButton1Click:Connect(function() model.set("minimized", false) end)

    -- Hide / show keybind ---------------------------------------------------------
    local function applyVisible(visible)
        if visible then
            view.Canvas.Visible = true
            view.Canvas.GroupTransparency = 1
            TweenService:Create(view.Canvas, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
        else
            local tween = TweenService:Create(view.Canvas, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
            tween:Play()
            tween.Completed:Once(function() view.Canvas.Visible = false end)
        end
    end
    model.onChange("visible", applyVisible)

    -- The hide key is model-driven: the Input tab keybind picker can rebind it
    -- live (falls back to config.Keys.HideUI until the demo seeds the model).
    local hideConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == (model.get("keybind") or config.Keys.HideUI) then
            model.set("visible", not model.get("visible"))
        end
    end)

    -- Close -----------------------------------------------------------------------
    view.CloseBtn.MouseButton1Click:Connect(function()
        model.set("uiOpen", false)
    end)

    -- Teardown ---------------------------------------------------------------------
    local function destroyAll()
        if hideConn then hideConn:Disconnect() end
        if view.Gui then view.Gui:Destroy() end
        model.destroy()
    end
    model.onChange("uiOpen", function(open)
        if open == false then
            destroyAll()
        end
    end)

    -- Initial state
    model.set("visible", true)
    model.set("uiOpen", true)
end
