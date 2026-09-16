-- RideAPet/modules/esp.lua
-- Player ESP: box highlight, name tag, auto-refresh on join/leave
return function(ctx)
    local gui = ctx.gui
    local config = ctx.config
    local THEME = config.Theme
    local Players = ctx.Players
    local lp = ctx.lp

    -- Auto-add ESP for players joining after ESP was toggled on
    ctx.bind(Players.PlayerAdded, function(player)
        if ctx.espEnabled and not ctx.destroyed then
            ctx.makeESPForPlayer(player)
        end
    end)

    -- Clean up ESP when player leaves
    ctx.bind(Players.PlayerRemoving, function(player)
        ctx.removeESPForPlayer(player)
        if ctx.playerRows[player] then
            ctx.playerRows[player]:Destroy()
            ctx.playerRows[player] = nil
        end
        if ctx.playerConnections[player] then
            ctx.disconnectList(ctx.playerConnections[player])
            ctx.playerConnections[player] = nil
        end
    end)

    ctx.log("ESP module loaded", THEME.success)
end
