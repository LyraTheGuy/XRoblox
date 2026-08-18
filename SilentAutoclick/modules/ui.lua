-- modules/ui.lua
-- Window drag, minimize/restore, close, and global hotkeys
return function(ctx)
    local gui = ctx.gui
    local UserInputService = ctx.UserInputService
    local bind = ctx.bind
    local mouse = ctx.mouse
    local updateClickerUI = ctx.updateClickerUI
    local toggleClicker = ctx.toggleClicker
    local destroyAll = ctx.destroyAll

    -- ═══════════════════════════════════════════
    -- DRAG (main window: top bar hit area; minimized panel: its header)
    -- ═══════════════════════════════════════════
    local function beginDragFor(frame)
        return function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                ctx.draggingUI = true
                ctx.dragTarget = frame
                ctx.dragStart = input.Position
                ctx.startPos = frame.Position
            end
        end
    end

    bind(gui.DragHit.InputBegan, beginDragFor(gui.Main))
    bind(gui.MiniHeader.InputBegan, beginDragFor(gui.MinimizedPanel))

    bind(UserInputService.InputChanged, function(input)
        if ctx.draggingUI and ctx.dragTarget and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - ctx.dragStart
            local newPos = UDim2.new(ctx.startPos.X.Scale, ctx.startPos.X.Offset + delta.X, ctx.startPos.Y.Scale, ctx.startPos.Y.Offset + delta.Y)
            ctx.dragTarget.Position = newPos
            -- Keep the drop shadow glued to the main window (offset (-4, 0))
            if ctx.dragTarget == gui.Main and gui.Shadow then
                gui.Shadow.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset - 4, newPos.Y.Scale, newPos.Y.Offset)
            end
        end
    end)

    bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ctx.draggingUI = false
            ctx.dragTarget = nil
        end
    end)

    -- ═══════════════════════════════════════════
    -- MINIMIZE / RESTORE / CLOSE
    -- ═══════════════════════════════════════════
    bind(gui.MinBtn.MouseButton1Click, function()
        ctx.minimized = true
        gui.Main.Visible = false
        if gui.Shadow then gui.Shadow.Visible = false end
        gui.MinimizedPanel.Visible = true
        -- Abort keybind capture so its full-screen scrim can't linger
        if gui.KeybindBtn and gui.KeybindBtn.Cancel then gui.KeybindBtn.Cancel() end
    end)

    bind(gui.ExpandBtn.MouseButton1Click, function()
        ctx.minimized = false
        gui.Main.Visible = true
        if gui.Shadow then gui.Shadow.Visible = true end
        gui.MinimizedPanel.Visible = false
    end)

    bind(gui.CloseBtn.MouseButton1Click, destroyAll)

    -- ═══════════════════════════════════════════
    -- GLOBAL HOTKEYS
    -- ═══════════════════════════════════════════
    bind(UserInputService.InputBegan, function(input, gp)
        if gp or ctx.destroyed then return end
        if input.KeyCode == ctx.toggleKey then
            toggleClicker()
        elseif input.KeyCode == ctx.pickKey then
            ctx.fixedX = mouse.X
            ctx.fixedY = mouse.Y
            updateClickerUI()
        elseif input.KeyCode == ctx.hideKey then
            ctx.hideUI = not ctx.hideUI
            if ctx.hideUI then
                gui.Main.Visible = false
                if gui.Shadow then gui.Shadow.Visible = false end
                gui.MinimizedPanel.Visible = false
                -- Abort keybind capture so its full-screen scrim can't linger
                if gui.KeybindBtn and gui.KeybindBtn.Cancel then gui.KeybindBtn.Cancel() end
            else
                if gui.Shadow then gui.Shadow.Visible = true end
                if ctx.minimized then
                    gui.MinimizedPanel.Visible = true
                else
                    gui.Main.Visible = true
                end
            end
        end
    end)
end
