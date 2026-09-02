-- DeepFishing/modules/utility.lua
-- Anti-AFK, Codes, Rewards, and utility functions
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -- ═══════════════════════════════════════════
    -- ANTI-AFK
    -- ═══════════════════════════════════════════
    local antiIdleConnections = {}

    local function enableAntiAfk()
        ctx.antiAfkEnabled = true
        local VirtualUser = game:GetService("VirtualUser")

        -- Try to disable idle detection via connections
        local success = pcall(function()
            if getconnections then
                for _, connection in pairs(getconnections(lp.Idled)) do
                    if connection["Disable"] then
                        connection["Disable"](connection)
                    elseif connection["Disconnect"] then
                        connection["Disconnect"](connection)
                    end
                end
            end
        end)

        -- Fallback: use VirtualUser
        if not success then
            local c = lp.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
            table.insert(antiIdleConnections, c)
        end

        log("Anti AFK: ON", THEME.success)
    end

    local function disableAntiAfk()
        ctx.antiAfkEnabled = false
        for _, c in ipairs(antiIdleConnections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(antiIdleConnections)
        log("Anti AFK: OFF", THEME.dim)
    end

    -- Start anti-afk if enabled by default
    if ctx.config.AntiAfk.Enabled then
        enableAntiAfk()
    end

    bind(gui.Player.AntiAfkToggle.btn.MouseButton1Click, function()
        local enabled = gui.Player.AntiAfkToggle.toggle()
        if enabled then
            enableAntiAfk()
        else
            disableAntiAfk()
        end
    end)

    -- ═══════════════════════════════════════════
    -- ANTI GAMEPLAY PAUSE
    -- ═══════════════════════════════════════════
    bind(gui.Player.AntiPauseToggle.btn.MouseButton1Click, function()
        ctx.antiPauseEnabled = gui.Player.AntiPauseToggle.toggle()
        if ctx.antiPauseEnabled then
            -- Try to disable gameplay pause notifications
            pcall(function()
                local StarterGui = game:GetService("StarterGui")
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
            end)
            log("Anti Gameplay Pause: ON", THEME.success)
        else
            log("Anti Gameplay Pause: OFF", THEME.dim)
        end
    end)

    -- ═══════════════════════════════════════════
    -- CODES REDEMPTION
    -- ═══════════════════════════════════════════
    -- Deep Fishing codes (may change over time)
    local deepFishingCodes = {
        "WELCOME",
        "FISHING",
        "100K",
        "UPDATE",
        "RELEASE",
        "THANKS",
        "LIKE",
        "SUBSCRIBE",
        "DISCORD",
        "GROUP",
    }

    local function redeemAllCodes()
        gui.Rewards.CodesStatusLabel.Text = "Status: Redeeming codes..."
        gui.Rewards.CodesStatusLabel.TextColor3 = THEME.warn

        local redeemed = 0
        local skipped = 0

        -- Find the redeem code remote
        local redeemRemote = nil
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

        redeemRemote = findRemote("RedeemCode") or findRemote("Redeem") or findRemote("Code")

        if not redeemRemote then
            gui.Rewards.CodesStatusLabel.Text = "Status: Code remote not found"
            gui.Rewards.CodesStatusLabel.TextColor3 = THEME.danger
            log("Codes: Remote not found", THEME.danger)
            return
        end

        for _, code in ipairs(deepFishingCodes) do
            if ctx.destroyed then break end

            local ok, result = pcall(function()
                if redeemRemote:IsA("RemoteFunction") then
                    return redeemRemote:InvokeServer(code)
                elseif redeemRemote:IsA("RemoteEvent") then
                    redeemRemote:FireServer(code)
                    return "Fired"
                end
            end)

            if ok then
                redeemed = redeemed + 1
                log("Code '" .. code .. "': " .. tostring(result or "redeemed"), THEME.success)
            else
                skipped = skipped + 1
                log("Code '" .. code .. "': " .. tostring(result), THEME.dim)
            end

            task.wait(0.5) -- Delay between attempts
        end

        gui.Rewards.CodesStatusLabel.Text = "Status: Redeemed " .. redeemed .. ", skipped " .. skipped
        gui.Rewards.CodesStatusLabel.TextColor3 = THEME.success
        log("Codes: Redeemed " .. redeemed .. ", skipped " .. skipped, THEME.success)
    end
    ctx.redeemAllCodes = redeemAllCodes

    bind(gui.Rewards.RedeemCodesBtn.MouseButton1Click, function()
        task.spawn(redeemAllCodes)
    end)

    -- ═══════════════════════════════════════════
    -- REWARD CLAIMING
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

    local function claimReward(remoteName, displayName)
        local remote = findRemote(remoteName)
        if remote then
            local ok, result = pcall(function()
                if remote:IsA("RemoteFunction") then
                    return remote:InvokeServer()
                elseif remote:IsA("RemoteEvent") then
                    remote:FireServer()
                    return "Fired"
                end
            end)
            if ok then
                log(displayName .. ": Claimed - " .. tostring(result or "ok"), THEME.success)
                return true, result
            else
                log(displayName .. ": " .. tostring(result), THEME.warn)
                return false, result
            end
        else
            log(displayName .. ": Remote not found", THEME.warn)
            return false, "Remote not found"
        end
    end

    -- Claim Playtime Gift
    local function claimPlaytimeGift()
        gui.Rewards.RewardsStatusLabel.Text = "Status: Claiming playtime gift..."
        gui.Rewards.RewardsStatusLabel.TextColor3 = THEME.warn
        local ok, result = claimReward("ClaimPlaytime", "Playtime Gift")
        gui.Rewards.RewardsStatusLabel.Text = ok and "Status: Claimed!" or "Status: " .. tostring(result)
        gui.Rewards.RewardsStatusLabel.TextColor3 = ok and THEME.success or THEME.danger
    end

    -- Claim Next Day Reward
    local function claimNextDayReward()
        gui.Rewards.RewardsStatusLabel.Text = "Status: Claiming next day reward..."
        gui.Rewards.RewardsStatusLabel.TextColor3 = THEME.warn
        local ok, result = claimReward("ClaimNextDay", "Next Day Reward")
        gui.Rewards.RewardsStatusLabel.Text = ok and "Status: Claimed!" or "Status: " .. tostring(result)
        gui.Rewards.RewardsStatusLabel.TextColor3 = ok and THEME.success or THEME.danger
    end

    -- Claim Group Reward
    local function claimGroupReward()
        gui.Rewards.RewardsStatusLabel.Text = "Status: Claiming group reward..."
        gui.Rewards.RewardsStatusLabel.TextColor3 = THEME.warn
        local ok, result = claimReward("ClaimGroup", "Group Reward")
        gui.Rewards.RewardsStatusLabel.Text = ok and "Status: Claimed!" or "Status: " .. tostring(result)
        gui.Rewards.RewardsStatusLabel.TextColor3 = ok and THEME.success or THEME.danger
    end

    bind(gui.Rewards.ClaimPlaytimeBtn.MouseButton1Click, function()
        task.spawn(claimPlaytimeGift)
    end)

    bind(gui.Rewards.ClaimNextDayBtn.MouseButton1Click, function()
        task.spawn(claimNextDayReward)
    end)

    bind(gui.Rewards.ClaimGroupBtn.MouseButton1Click, function()
        task.spawn(claimGroupReward)
    end)

    -- ═══════════════════════════════════════════
    -- AUTO CLAIM LOOPS
    -- ═══════════════════════════════════════════
    -- Auto Claim Free Rewards
    bind(gui.Fishing.AutoClaimFreeToggle.btn.MouseButton1Click, function()
        ctx.autoClaimFreeEnabled = gui.Fishing.AutoClaimFreeToggle.toggle()
        if ctx.autoClaimFreeEnabled then
            task.spawn(function()
                log("Auto Claim Free Rewards: ON", THEME.success)
                while ctx.autoClaimFreeEnabled and not ctx.destroyed do
                    claimReward("ClaimFreeReward", "Free Reward")
                    task.wait(3600) -- Check every hour
                end
            end)
        end
    end)

    -- Auto Claim Big Fish
    bind(gui.Fishing.AutoClaimBigFishToggle.btn.MouseButton1Click, function()
        ctx.autoClaimBigFishEnabled = gui.Fishing.AutoClaimBigFishToggle.toggle()
        if ctx.autoClaimBigFishEnabled then
            task.spawn(function()
                log("Auto Claim Big Fish: ON", THEME.success)
                while ctx.autoClaimBigFishEnabled and not ctx.destroyed do
                    claimReward("ClaimBigFish", "Big Fish Reward")
                    task.wait(300) -- Check every 5 minutes
                end
            end)
        end
    end)

    -- Auto Claim Playtime
    bind(gui.Fishing.AutoClaimPlaytimeToggle.btn.MouseButton1Click, function()
        ctx.autoClaimPlaytimeEnabled = gui.Fishing.AutoClaimPlaytimeToggle.toggle()
        if ctx.autoClaimPlaytimeEnabled then
            task.spawn(function()
                log("Auto Claim Playtime: ON", THEME.success)
                while ctx.autoClaimPlaytimeEnabled and not ctx.destroyed do
                    claimPlaytimeGift()
                    task.wait(3600)
                end
            end)
        end
    end)

    -- Auto Claim Next Day
    bind(gui.Fishing.AutoClaimNextDayToggle.btn.MouseButton1Click, function()
        ctx.autoClaimNextDayEnabled = gui.Fishing.AutoClaimNextDayToggle.toggle()
        if ctx.autoClaimNextDayEnabled then
            task.spawn(function()
                log("Auto Claim Next Day: ON", THEME.success)
                while ctx.autoClaimNextDayEnabled and not ctx.destroyed do
                    claimNextDayReward()
                    task.wait(3600)
                end
            end)
        end
    end)

    -- Auto Claim Group
    bind(gui.Fishing.AutoClaimGroupToggle.btn.MouseButton1Click, function()
        ctx.autoClaimGroupEnabled = gui.Fishing.AutoClaimGroupToggle.toggle()
        if ctx.autoClaimGroupEnabled then
            task.spawn(function()
                log("Auto Claim Group: ON", THEME.success)
                while ctx.autoClaimGroupEnabled and not ctx.destroyed do
                    claimGroupReward()
                    task.wait(3600)
                end
            end)
        end
    end)

    -- ═══════════════════════════════════════════
    -- UNLOAD BUTTON
    -- ═══════════════════════════════════════════
    bind(gui.Settings.UnloadBtn.MouseButton1Click, function()
        if _G.__DeepFishing_Destroy then
            _G.__DeepFishing_Destroy()
        end
    end)
end
