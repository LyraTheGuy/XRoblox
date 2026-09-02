-- DeepFishing/modules/autobuy.lua
-- Auto buy bait, rods, and upgrades
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log

    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -- ═══════════════════════════════════════════
    -- REMOTE ACCESS
    -- ═══════════════════════════════════════════
    local function findRemote(name)
        local ok, result = pcall(function()
            return ReplicatedStorage:WaitForChild(name, 3)
        end)
        if ok and result then return result end

        for _, folder in ipairs(ReplicatedStorage:GetChildren()) do
            if folder:IsA("Folder") then
                local child = folder:FindFirstChild(name, true)
                if child then return child end
            end
        end
        return nil
    end

    local buyBaitRemote = findRemote("BuyBait") or findRemote("BuyBestBait")
    local buyRodRemote = findRemote("BuyRod") or findRemote("BuyBestRod")
    local buyUpgradeRemote = findRemote("BuyUpgrade") or findRemote("BuyUpgrades")

    -- ═══════════════════════════════════════════
    -- BUY FUNCTIONS
    -- ═══════════════════════════════════════════
    local function buyBestBait()
        if buyBaitRemote then
            local ok, result = pcall(function()
                if buyBaitRemote:IsA("RemoteFunction") then
                    return buyBaitRemote:InvokeServer()
                elseif buyBaitRemote:IsA("RemoteEvent") then
                    buyBaitRemote:FireServer()
                    return "Fired"
                end
            end)
            if ok then
                log("Bought best bait: " .. tostring(result or "ok"), THEME.success)
                return true, result
            else
                log("Buy bait failed: " .. tostring(result), THEME.danger)
                return false, result
            end
        end
        log("Buy bait remote not found", THEME.warn)
        return false, "Remote not found"
    end
    ctx.buyBestBait = buyBestBait

    local function buyBestRod()
        if buyRodRemote then
            local ok, result = pcall(function()
                if buyRodRemote:IsA("RemoteFunction") then
                    return buyRodRemote:InvokeServer()
                elseif buyRodRemote:IsA("RemoteEvent") then
                    buyRodRemote:FireServer()
                    return "Fired"
                end
            end)
            if ok then
                log("Bought best rod: " .. tostring(result or "ok"), THEME.success)
                return true, result
            else
                log("Buy rod failed: " .. tostring(result), THEME.danger)
                return false, result
            end
        end
        log("Buy rod remote not found", THEME.warn)
        return false, "Remote not found"
    end
    ctx.buyBestRod = buyBestRod

    local function buyUpgrades()
        if buyUpgradeRemote then
            local ok, result = pcall(function()
                if buyUpgradeRemote:IsA("RemoteFunction") then
                    return buyUpgradeRemote:InvokeServer()
                elseif buyUpgradeRemote:IsA("RemoteEvent") then
                    buyUpgradeRemote:FireServer()
                    return "Fired"
                end
            end)
            if ok then
                log("Bought upgrades: " .. tostring(result or "ok"), THEME.success)
                return true, result
            else
                log("Buy upgrades failed: " .. tostring(result), THEME.danger)
                return false, result
            end
        end
        log("Buy upgrades remote not found", THEME.warn)
        return false, "Remote not found"
    end
    ctx.buyUpgrades = buyUpgrades

    -- ═══════════════════════════════════════════
    -- AUTO BUY LOOPS
    -- ═══════════════════════════════════════════
    local function autoBuyBaitLoop()
        log("Auto Buy Bait: Started", THEME.success)
        gui.Shop.BaitStatusLabel.Text = "Status: Auto buying..."
        gui.Shop.BaitStatusLabel.TextColor3 = THEME.success

        while ctx.autoBuyBaitEnabled and not ctx.destroyed do
            local ok, result = buyBestBait()
            if ok then
                gui.Shop.BaitStatusLabel.Text = "Status: Bought bait"
                gui.Shop.BaitStatusLabel.TextColor3 = THEME.success
            else
                gui.Shop.BaitStatusLabel.Text = "Status: " .. tostring(result)
                gui.Shop.BaitStatusLabel.TextColor3 = THEME.danger
            end
            task.wait(60) -- Buy every 60 seconds
        end
    end

    local function autoBuyRodLoop()
        log("Auto Buy Rod: Started", THEME.success)
        gui.Shop.RodStatusLabel.Text = "Status: Auto buying..."
        gui.Shop.RodStatusLabel.TextColor3 = THEME.success

        while ctx.autoBuyRodEnabled and not ctx.destroyed do
            local ok, result = buyBestRod()
            if ok then
                gui.Shop.RodStatusLabel.Text = "Status: Bought rod"
                gui.Shop.RodStatusLabel.TextColor3 = THEME.success
            else
                gui.Shop.RodStatusLabel.Text = "Status: " .. tostring(result)
                gui.Shop.RodStatusLabel.TextColor3 = THEME.danger
            end
            task.wait(120) -- Buy every 2 minutes
        end
    end

    local function autoBuyUpgradesLoop()
        log("Auto Buy Upgrades: Started", THEME.success)
        gui.Shop.UpgradeStatusLabel.Text = "Status: Auto buying..."
        gui.Shop.UpgradeStatusLabel.TextColor3 = THEME.success

        while ctx.autoBuyUpgradesEnabled and not ctx.destroyed do
            local ok, result = buyUpgrades()
            if ok then
                gui.Shop.UpgradeStatusLabel.Text = "Status: Bought upgrades"
                gui.Shop.UpgradeStatusLabel.TextColor3 = THEME.success
            else
                gui.Shop.UpgradeStatusLabel.Text = "Status: " .. tostring(result)
                gui.Shop.UpgradeStatusLabel.TextColor3 = THEME.danger
            end
            task.wait(180) -- Buy every 3 minutes
        end
    end

    -- ═══════════════════════════════════════════
    -- GUI BINDINGS
    -- ═══════════════════════════════════════════
    bind(gui.Shop.AutoBuyBaitToggle.btn.MouseButton1Click, function()
        ctx.autoBuyBaitEnabled = gui.Shop.AutoBuyBaitToggle.toggle()
        if ctx.autoBuyBaitEnabled then
            task.spawn(autoBuyBaitLoop)
        else
            gui.Shop.BaitStatusLabel.Text = "Status: Ready"
            gui.Shop.BaitStatusLabel.TextColor3 = THEME.dim
        end
    end)

    bind(gui.Shop.BuyBaitNowBtn.MouseButton1Click, function()
        log("Buy Bait Now: Attempting...", THEME.warn)
        local ok, result = buyBestBait()
        gui.Shop.BaitStatusLabel.Text = ok and "Status: Bought!" or "Status: Failed"
        gui.Shop.BaitStatusLabel.TextColor3 = ok and THEME.success or THEME.danger
    end)

    bind(gui.Shop.AutoBuyRodToggle.btn.MouseButton1Click, function()
        ctx.autoBuyRodEnabled = gui.Shop.AutoBuyRodToggle.toggle()
        if ctx.autoBuyRodEnabled then
            task.spawn(autoBuyRodLoop)
        else
            gui.Shop.RodStatusLabel.Text = "Status: Ready"
            gui.Shop.RodStatusLabel.TextColor3 = THEME.dim
        end
    end)

    bind(gui.Shop.BuyRodNowBtn.MouseButton1Click, function()
        log("Buy Rod Now: Attempting...", THEME.warn)
        local ok, result = buyBestRod()
        gui.Shop.RodStatusLabel.Text = ok and "Status: Bought!" or "Status: Failed"
        gui.Shop.RodStatusLabel.TextColor3 = ok and THEME.success or THEME.danger
    end)

    bind(gui.Shop.AutoBuyUpgradesToggle.btn.MouseButton1Click, function()
        ctx.autoBuyUpgradesEnabled = gui.Shop.AutoBuyUpgradesToggle.toggle()
        if ctx.autoBuyUpgradesEnabled then
            task.spawn(autoBuyUpgradesLoop)
        else
            gui.Shop.UpgradeStatusLabel.Text = "Status: Ready"
            gui.Shop.UpgradeStatusLabel.TextColor3 = THEME.dim
        end
    end)

    bind(gui.Shop.BuyUpgradesNowBtn.MouseButton1Click, function()
        log("Buy Upgrades Now: Attempting...", THEME.warn)
        local ok, result = buyUpgrades()
        gui.Shop.UpgradeStatusLabel.Text = ok and "Status: Bought!" or "Status: Failed"
        gui.Shop.UpgradeStatusLabel.TextColor3 = ok and THEME.success or THEME.danger
    end)
end
