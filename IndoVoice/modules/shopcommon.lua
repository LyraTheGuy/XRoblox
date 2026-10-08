-- modules/shopcommon.lua
-- Shared helpers for the shop modules (RodShop, TokenShop, ...).
--
-- Both shops drive a "Buy" button through the same feedback cycle:
--   "..." (pending) -> "OK!" (success) / "Fail" (error) -> "Buy" (reset)
-- and both surface the result on a shared Status label. This module owns that
-- cycle so the two shops stay consistent and we don't duplicate the logic.
return function(ctx)
    local THEME = ctx.THEME
    local log = ctx.log

    -- Runs `invoke` (a function returning success, errMsg) and drives `btn`
    -- plus `statusLabel` through the standard feedback cycle.
    --
    --   invoke        : function() -> success:boolean, errMsg:string?
    --   btn           : the TextButton to animate
    --   statusLabel   : TextLabel showing the result
    --   opts.display  : string shown in the success/status text
    --   opts.tag      : prefix for log lines (e.g. "RodShop")
    --   opts.failMsg  : fallback error text when the server returns false
    local function runPurchase(invoke, btn, statusLabel, opts)
        opts = opts or {}
        local display = opts.display or "item"
        local tag = opts.tag or "Shop"
        local failMsg = opts.failMsg or "Purchase failed"

        btn.Text = "..."
        btn.BackgroundColor3 = THEME.warn

        local ok, success, errMsg = pcall(invoke)

        if ok and success == true then
            btn.Text = "OK!"
            btn.BackgroundColor3 = THEME.success
            statusLabel.Text = "Bought: " .. display
            statusLabel.TextColor3 = THEME.success
            log(tag .. ": Purchased " .. display, THEME.success)
        else
            local reason
            if not ok then
                reason = tostring(success)
            elseif success == false then
                reason = tostring(errMsg or failMsg)
            else
                reason = "Unknown error"
            end
            btn.Text = "Fail"
            btn.BackgroundColor3 = THEME.danger
            statusLabel.Text = reason
            statusLabel.TextColor3 = THEME.danger
            log(tag .. ": " .. display .. " -> " .. reason, THEME.danger)
        end

        task.delay(3, function()
            if btn and btn.Parent then
                btn.Text = "Buy"
                btn.BackgroundColor3 = THEME.accent
            end
        end)
    end

    -- Case-insensitive substring filter over a { key -> row } table.
    -- `transform` maps a key to the string that should be matched against.
    -- Returns the number of rows left visible.
    local function filterRows(rows, query, transform)
        query = string.lower(query or "")
        local visibleCount = 0
        for key, row in pairs(rows) do
            local display = string.lower(transform(key))
            local visible = (query == "") or string.find(display, query, 1, true) ~= nil
            row.Visible = visible
            if visible then visibleCount = visibleCount + 1 end
        end
        return visibleCount
    end

    return {
        runPurchase = runPurchase,
        filterRows = filterRows,
    }
end
