-- modules/auto_sell.lua
-- Auto Sell feature: sells honey on a timer

return function(ctx)
    ctx.setButtonState(ctx.gui.SellButton, ctx.AutoSell, "Sell")
    ctx.updateStatus()

    local lastRun = os.clock()

    ctx.gui.SellButton.MouseButton1Click:Connect(function()
        ctx.AutoSell = not ctx.AutoSell
        ctx.setButtonState(ctx.gui.SellButton, ctx.AutoSell, "Sell")
        ctx.updateStatus()
    end)

    task.spawn(function()
        while task.wait(0.25) do
            if ctx.Destroyed then
                break
            end
            if not ctx.AutoSell then
                lastRun = os.clock()
                continue
            end

            ctx.syncIntervals()

            local now = os.clock()
            if now - lastRun < (ctx.sellInterval or 5) then
                continue
            end
            lastRun = now

            pcall(function()
                ctx.SellRemote:FireServer("SellHoney", "Honey")
                ctx.addCount("sell", 1)
            end)
            ctx.updateStats()
        end
    end)
end