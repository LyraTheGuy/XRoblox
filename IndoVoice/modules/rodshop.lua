-- modules/rodshop.lua
-- Rod Shop (Buy Rod)
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local bind = ctx.bind
    local log = ctx.log

    local shop = ctx.shopCommon

    for rodName, btn in pairs(gui.RodShop.BuyButtons) do
        bind(btn.MouseButton1Click, function()
            shop.runPurchase(
                function()
                    return game:GetService("ReplicatedStorage")
                        .GameRemoteFunctions.RodShopPurchaseFunction:InvokeServer(rodName)
                end,
                btn,
                gui.RodShop.Status,
                {
                    display = rodName:gsub("Tool_", ""):gsub("Rod$", ""),
                    tag = "RodShop",
                    failMsg = "Not enough Ropiah",
                }
            )
        end)
    end
    -- Rod search filter
    bind(gui.RodShop.SearchBox:GetPropertyChangedSignal("Text"), function()
        shop.filterRows(gui.RodShop.RodRows, gui.RodShop.SearchBox.Text, function(rodName)
            return rodName:gsub("Tool_", ""):gsub("Rod$", "")
        end)
    end)
end

