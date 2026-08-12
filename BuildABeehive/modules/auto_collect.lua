-- modules/auto_collect.lua
-- Auto Collect feature: extracts honey from every hive in the player's plot

return function(ctx)
    ctx.setButtonState(ctx.gui.CollectButton, ctx.AutoCollect, "Collect")
    ctx.updateStatus()

    local lastRun = os.clock()

    ctx.gui.CollectButton.MouseButton1Click:Connect(function()
        ctx.AutoCollect = not ctx.AutoCollect
        ctx.setButtonState(ctx.gui.CollectButton, ctx.AutoCollect, "Collect")
        ctx.updateStatus()
    end)

    task.spawn(function()
        while task.wait(0.25) do
            if ctx.Destroyed then
                break
            end
            if not ctx.AutoCollect then
                lastRun = os.clock()
                continue
            end

            ctx.syncIntervals()

            local now = os.clock()
            if now - lastRun < (ctx.collectInterval or 2) then
                continue
            end
            lastRun = now

            local hives = ctx.getMyHives()
            if hives then
                for _, hive in ipairs(hives:GetChildren()) do
                    pcall(function()
                        ctx.ExtractRemote:FireServer("ExtractHoney", {hive})
                        ctx.addCount("collect", 1)
                    end)
                    task.wait(0.15)
                end
                ctx.updateStats()
            end
        end
    end)
end