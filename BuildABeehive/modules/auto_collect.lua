-- modules/auto_collect.lua
-- Auto Collect feature: extracts honey from every hive in the player's plot

return function(ctx)
    ctx.setButtonState(ctx.gui.CollectButton, ctx.AutoCollect, "Collect")
    ctx.updateStatus()

    local lastRun = os.clock()

    -- Smart collect: when enabled, skip hives we can positively identify as
    -- empty. The probe is adaptive (common value names/attributes); when the
    -- honey layout is unknown it returns nil and we fall back to collecting.
    local smartCollect = true
    if ctx.config and ctx.config.AutoCollect then
        smartCollect = ctx.config.AutoCollect.SmartCollect ~= false
    end

    local function hiveHoney(hive)
        for _, name in ipairs({ "Honey", "HoneyAmount", "Current", "Fill", "Amount" }) do
            local v = hive:FindFirstChild(name)
            if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
                return v.Value
            end
        end
        local attr = hive:GetAttribute("Honey") or hive:GetAttribute("Fill")
        if type(attr) == "number" then
            return attr
        end
        return nil
    end

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
                    if smartCollect then
                        local honey = hiveHoney(hive)
                        if honey ~= nil and honey <= 0 then
                            continue -- positively empty, skip this cycle
                        end
                    end
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