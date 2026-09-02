-- DeepFishing/modules/autosell.lua
-- Auto sell fish and auto delete low-rarity fish
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log
    local performSell = ctx.performSell

    local sellCount = 0
    local deleteCount = 0

    -- ═══════════════════════════════════════════
    -- AUTO SELL LOOP
    -- ═══════════════════════════════════════════
    local function autoSellLoop()
        log("Auto Sell: Started (interval: " .. ctx.config.AutoSell.Interval .. "s)", THEME.success)
        gui.Shop.SellStatusLabel.Text = "Status: Auto sell ON"
        gui.Shop.SellStatusLabel.TextColor3 = THEME.success

        while ctx.autoSellEnabled and not ctx.destroyed do
            task.wait(ctx.config.AutoSell.Interval)

            if ctx.autoSellEnabled and not ctx.destroyed then
                local ok, result = performSell()
                if ok then
                    sellCount = sellCount + 1
                    gui.Shop.SellStatusLabel.Text = "Status: Sold! Total: " .. sellCount
                    gui.Shop.SellStatusLabel.TextColor3 = THEME.success
                    log("Auto Sell #" .. sellCount .. ": " .. tostring(result or "ok"), THEME.success)
                else
                    gui.Shop.SellStatusLabel.Text = "Status: Sell failed - " .. tostring(result)
                    gui.Shop.SellStatusLabel.TextColor3 = THEME.danger
                    log("Auto Sell failed: " .. tostring(result), THEME.danger)
                end
            end
        end

        gui.Shop.SellStatusLabel.Text = "Status: Ready"
        gui.Shop.SellStatusLabel.TextColor3 = THEME.dim
    end

    -- ═══════════════════════════════════════════
    -- AUTO DELETE LOOP
    -- ═══════════════════════════════════════════
    local function autoDeleteLoop()
        log("Auto Delete: Started", THEME.success)

        while ctx.autoDeleteEnabled and not ctx.destroyed do
            task.wait(5) -- Check every 5 seconds

            if ctx.autoDeleteEnabled and not ctx.destroyed then
                -- Try to find and delete low-rarity fish
                -- This is game-specific - Deep Fishing stores fish in a specific location
                local char = lp.Character
                if char then
                    for _, item in ipairs(char:GetChildren()) do
                        if item:IsA("Tool") and item:GetAttribute("Rarity") then
                            local rarity = item:GetAttribute("Rarity")
                            if ctx.config.AutoDelete.Rarities[rarity] then
                                item:Destroy()
                                deleteCount = deleteCount + 1
                                log("Deleted " .. item.Name .. " [" .. rarity .. "]", THEME.dim)
                            end
                        end
                    end
                end

                -- Also check backpack
                local backpack = lp:FindFirstChild("Backpack")
                if backpack then
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") and item:GetAttribute("Rarity") then
                            local rarity = item:GetAttribute("Rarity")
                            if ctx.config.AutoDelete.Rarities[rarity] then
                                item:Destroy()
                                deleteCount = deleteCount + 1
                                log("Deleted " .. item.Name .. " [" .. rarity .. "]", THEME.dim)
                            end
                        end
                    end
                end
            end
        end
    end

    -- ═══════════════════════════════════════════
    -- GUI BINDINGS
    -- ═══════════════════════════════════════════
    bind(gui.Shop.AutoSellToggle.btn.MouseButton1Click, function()
        ctx.autoSellEnabled = gui.Shop.AutoSellToggle.toggle()
        if ctx.autoSellEnabled then
            task.spawn(autoSellLoop)
        else
            gui.Shop.SellStatusLabel.Text = "Status: Ready"
            gui.Shop.SellStatusLabel.TextColor3 = THEME.dim
        end
    end)

    bind(gui.Shop.SellNowBtn.MouseButton1Click, function()
        log("Sell Now: Attempting...", THEME.warn)
        local ok, result = performSell()
        if ok then
            sellCount = sellCount + 1
            gui.Shop.SellStatusLabel.Text = "Status: Sold! Total: " .. sellCount
            gui.Shop.SellStatusLabel.TextColor3 = THEME.success
            log("Sell Now: SUCCESS - " .. tostring(result or "done"), THEME.success)
        else
            gui.Shop.SellStatusLabel.Text = "Status: Failed - " .. tostring(result)
            gui.Shop.SellStatusLabel.TextColor3 = THEME.danger
            log("Sell Now: FAILED - " .. tostring(result), THEME.danger)
        end
    end)

    bind(gui.Shop.AutoDeleteToggle.btn.MouseButton1Click, function()
        ctx.autoDeleteEnabled = gui.Shop.AutoDeleteToggle.toggle()
        if ctx.autoDeleteEnabled then
            task.spawn(autoDeleteLoop)
        end
    end)
end
