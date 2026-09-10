-- modules/tokenshop.lua
-- Token Shop (LuckTicket I - VI purchases + game TokenShop GUI opener)
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local bind = ctx.bind
    local log = ctx.log

    -- Same remote family as RodShop: GameRemoteFunctions.*PurchaseFunction,
    -- invoked with the item id only. Server validates the token balance.
    local function purchaseTicket(itemName)
        local Event = game:GetService("ReplicatedStorage"):WaitForChild("GameRemoteFunctions"):WaitForChild("TokenShopPurchaseFunction")
        return Event:InvokeServer(itemName)
    end

    -- Buy buttons: reuse the RodShop feedback pattern ("..." -> OK!/Fail)
    for itemName, btn in pairs(gui.TokenShop.BuyButtons) do
        bind(btn.MouseButton1Click, function()
            btn.Text = "..."
            btn.BackgroundColor3 = THEME.warn
            local ok, success, errMsg = pcall(purchaseTicket, itemName)
            if ok and success == true then
                btn.Text = "OK!"
                btn.BackgroundColor3 = THEME.success
                gui.TokenShop.Status.Text = "Bought: " .. itemName:gsub("UseableItem_Server", "")
                gui.TokenShop.Status.TextColor3 = THEME.success
                log("TokenShop: Purchased " .. itemName, THEME.success)
            else
                local reason = ""
                if not ok then
                    reason = tostring(success)
                elseif success == false then
                    reason = tostring(errMsg or "Not enough Tokens")
                else
                    reason = "Unknown error"
                end
                btn.Text = "Fail"
                btn.BackgroundColor3 = THEME.danger
                gui.TokenShop.Status.Text = reason
                gui.TokenShop.Status.TextColor3 = THEME.danger
                log("TokenShop: " .. itemName .. " → " .. reason, THEME.danger)
            end
            task.delay(3, function()
                if btn and btn.Parent then
                    btn.Text = "Buy"
                    btn.BackgroundColor3 = THEME.accent
                end
            end)
        end)
    end

    -- Search filter (plain find, same as RodShop) + empty-result hint
    bind(gui.TokenShop.SearchBox:GetPropertyChangedSignal("Text"), function()
        local query = string.lower(gui.TokenShop.SearchBox.Text)
        local visibleCount = 0
        for itemName, row in pairs(gui.TokenShop.Rows) do
            local display = string.lower(itemName:gsub("UseableItem_Server", ""))
            local visible = (query == "") or string.find(display, query, 1, true) ~= nil
            row.Visible = visible
            if visible then visibleCount = visibleCount + 1 end
        end
        gui.TokenShop.EmptyHint.Visible = visibleCount == 0
    end)

    -- Open the game's own TokenShop GUI via its ShowFunction BindableFunction
    bind(gui.TokenShop.OpenBtn.MouseButton1Click, function()
        local ok, err = pcall(function()
            local playerGui = ctx.lp:WaitForChild("PlayerGui")
            local tokenShop = playerGui:WaitForChild("TokenShop")
            local controller = tokenShop:WaitForChild("TokenShopUIController")
            local showFn = controller:WaitForChild("ShowFunction")
            showFn:Invoke()
        end)
        if ok then
            gui.TokenShop.Status.Text = "TokenShop GUI opened"
            gui.TokenShop.Status.TextColor3 = THEME.success
            log("TokenShop: Opened game TokenShop GUI", THEME.success)
        else
            gui.TokenShop.Status.Text = "TokenShop GUI not found"
            gui.TokenShop.Status.TextColor3 = THEME.danger
            log("TokenShop: Open failed → " .. tostring(err), THEME.danger)
        end
    end)
end
