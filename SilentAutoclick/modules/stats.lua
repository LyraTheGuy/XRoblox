-- modules/stats.lua
-- Live stats: Total Clicks, actual CPS (measured), FPS, Ping
return function(ctx)
    local gui = ctx.gui
    local RunService = ctx.RunService
    local bind = ctx.bind

    local Stats = ctx.gui.Stats
    local MiniStats = ctx.gui.MiniStats

    -- Rolling window of click timestamps to measure real achieved CPS
    -- (as opposed to the CPS *target* set by the slider).
    local clickTimestamps = {}
    local lastTotalClicks = 0

    -- Sparkline sample history (one per 0.5s tick, drawn by gui.Sparkline)
    local Sparkline = ctx.gui.Sparkline
    local sparkHistory = {}

    -- FPS tracking via frame time deltas
    local frameCount = 0
    local fpsAccum = 0

    -- Ping tracking via Roblox's built-in network stats
    local Stats_Service = game:GetService("Stats")

    local lastUpdate = tick()

    bind(RunService.Heartbeat, function(dt)
        if ctx.destroyed then return end

        frameCount = frameCount + 1
        fpsAccum = fpsAccum + dt

        -- Track new clicks since last frame for the rolling CPS window
        if ctx.totalClicks > lastTotalClicks then
            local now = tick()
            for _ = 1, (ctx.totalClicks - lastTotalClicks) do
                table.insert(clickTimestamps, now)
            end
            lastTotalClicks = ctx.totalClicks
        end

        local now = tick()
        if now - lastUpdate >= 0.5 then
            lastUpdate = now

            -- FPS
            if fpsAccum > 0 then
                ctx.fps = math.floor(frameCount / fpsAccum + 0.5)
            end
            frameCount = 0
            fpsAccum = 0

            -- Prune click timestamps older than 1 second, count remainder = actual CPS
            local cutoff = now - 1
            local i = 1
            while i <= #clickTimestamps do
                if clickTimestamps[i] < cutoff then
                    table.remove(clickTimestamps, i)
                else
                    i = i + 1
                end
            end
            ctx.actualCPS = #clickTimestamps

            -- Push the sample into the sparkline: shift history, then resize
            -- each bar to its CPS ratio. Fill only the used prefix (bars past
            -- the history length stay at height 0 until samples arrive).
            if Sparkline then
                table.insert(sparkHistory, ctx.actualCPS)
                if #sparkHistory > #Sparkline.Bars then
                    table.remove(sparkHistory, 1)
                end
                local maxBar = Sparkline.MaxBar or 28
                for i, cps in ipairs(sparkHistory) do
                    local ratio = math.clamp(cps / Sparkline.Max, 0, 1)
                    local h = ratio > 0 and math.max(2, math.floor(ratio * maxBar)) or 0
                    Sparkline.Bars[i].Size = UDim2.new(0, Sparkline.Bars[i].Size.X.Offset, 0, h)
                end
            end

            -- Ping (ms)
            local ok, pingMs = pcall(function()
                return Stats_Service.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            ctx.ping = ok and math.floor(pingMs + 0.5) or ctx.ping

            -- Push to expanded panel
            Stats.TotalClicksVal.Text = tostring(ctx.totalClicks)
            Stats.ActualCPSVal.Text = tostring(ctx.actualCPS)
            Stats.FPSVal.Text = tostring(ctx.fps)
            Stats.PingVal.Text = tostring(ctx.ping) .. " ms"

            -- Push to compact minimized panel
            MiniStats.StatusVal.Text = ctx.clicking and "ON" or "OFF"
            MiniStats.StatusVal.TextColor3 = ctx.clicking and ctx.THEME.success or ctx.THEME.danger
            MiniStats.CPSVal.Text = tostring(ctx.actualCPS)
            MiniStats.FPSVal.Text = tostring(ctx.fps)
            MiniStats.PingVal.Text = tostring(ctx.ping)
        end
    end)
end
