-- modules/shopgacha.lua
-- Shop Gacha System (Pet / Aura / Trail)
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log
    local sendWebhookRaw = ctx.sendWebhookRaw

    local shopGachaRolls = 0
    local shopGachaType = "Pet"
    local shopGachaStopRarities = {}

    -- Type selection buttons
    for typeName, btn in pairs(gui.ShopGacha.TypeButtons) do
        bind(btn.MouseButton1Click, function()
            shopGachaType = typeName
            for tName, tBtn in pairs(gui.ShopGacha.TypeButtons) do
                if tName == typeName then
                    tBtn.BackgroundColor3 = THEME.accent
                    tBtn.BackgroundTransparency = 0.2
                    tBtn.TextColor3 = Color3.new(1, 1, 1)
                else
                    tBtn.BackgroundColor3 = THEME.panel2
                    tBtn.BackgroundTransparency = 0.6
                    tBtn.TextColor3 = THEME.dim
                end
            end
            log("ShopGacha: Type → " .. typeName, THEME.dim)
        end)
    end

    -- Stop rarity buttons
    for rarity, btn in pairs(gui.ShopGacha.StopButtons) do
        bind(btn.MouseButton1Click, function()
            shopGachaStopRarities[rarity] = not shopGachaStopRarities[rarity]
            if shopGachaStopRarities[rarity] then
                btn.BackgroundColor3 = THEME.success
                btn.BackgroundTransparency = 0.2
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                btn.BackgroundColor3 = THEME.panel2
                btn.BackgroundTransparency = 0.6
                btn.TextColor3 = THEME.dim
            end
        end)
    end

    local function shopGachaLoop()
        log("ShopGacha: Started [" .. shopGachaType .. "]", THEME.success)
        gui.ShopGacha.Status.Text = "Status: Running | Rolls: 0"
        gui.ShopGacha.Status.TextColor3 = THEME.success

        -- Mute game sounds during gacha
        pcall(function()
            for _, sound in ipairs(game:GetService("SoundService"):GetDescendants()) do
                if sound:IsA("Sound") then
                    sound.Volume = 0
                end
            end
        end)

        local function destroyGachaUI()
            pcall(function()
                local playerGui = lp:FindFirstChild("PlayerGui")
                if playerGui then
                    for _, g in pairs(playerGui:GetChildren()) do
                        if g:IsA("ScreenGui") and g.Name ~= "LyraHub_Main" and g.Name ~= "Chat" then
                            local n = g.Name
                            if string.find(n, "Roll") or string.find(n, "Reward")
                                or string.find(n, "Gacha") or string.find(n, "Blind")
                                or string.find(n, "Animation") or string.find(n, "Popup")
                                or string.find(n, "Shop") or string.find(n, "Spin")
                                or string.find(n, "Notif") then
                                g:Destroy()
                            end
                        end
                    end
                end
            end)
            pcall(function()
                for _, sound in ipairs(workspace:GetDescendants()) do
                    if sound:IsA("Sound") and sound.Playing then
                        sound:Stop()
                        sound.Volume = 0
                    end
                end
            end)
        end

        while ctx.shopGachaEnabled and not ctx.destroyed do
            destroyGachaUI()
            task.wait(0.2)

            -- Listen for reward event
            local receivedRarities = {}
            local receivedNames = {}
            local rewardConn
            pcall(function()
                local gre = game:GetService("ReplicatedStorage"):FindFirstChild("GameRemoteEvents")
                local rewardEvent = gre and gre:FindFirstChild("CreateRewardInfoEvent")
                if rewardEvent and rewardEvent:IsA("RemoteEvent") then
                    rewardConn = rewardEvent.OnClientEvent:Connect(function(info, typeStr, rarity, itemId, ...)
                        local r = rarity or (info and info.Rarity)
                        local name = (info and info.Name) or itemId or "?"
                        if r and type(r) == "string" then
                            table.insert(receivedRarities, r)
                            table.insert(receivedNames, name)
                        end
                    end)
                end
            end)

            -- Roll 10x
            gui.ShopGacha.Status.Text = "Status: Rolling 10x [" .. shopGachaType .. "]..."
            local rollOk, rollResult = pcall(function()
                return game:GetService("ReplicatedStorage").GameRemoteFunctions.RollShopFunction:InvokeServer(shopGachaType, 10)
            end)

            destroyGachaUI()
            task.wait(0.5)
            destroyGachaUI()

            if rewardConn then rewardConn:Disconnect() end

            if not rollOk then
                gui.ShopGacha.Status.Text = "Status: Retrying..."
                gui.ShopGacha.Status.TextColor3 = THEME.warn
                log("ShopGacha: " .. tostring(rollResult), THEME.warn)
                destroyGachaUI()
                task.wait(1)
                continue
            end

            shopGachaRolls = shopGachaRolls + 10
            gui.ShopGacha.Status.Text = "Status: Running | Rolls: " .. shopGachaRolls
            gui.ShopGacha.Status.TextColor3 = THEME.success

            -- Check results
            local gotStopRarity = false
            local lastRarity = "?"
            local lastItemName = "?"

            if #receivedRarities > 0 then
                for i, r in ipairs(receivedRarities) do
                    lastRarity = r
                    lastItemName = receivedNames[i] or "?"
                    if shopGachaStopRarities[r] then
                        gotStopRarity = true
                    end
                end
            end

            gui.ShopGacha.LastResult.Text = "Last: " .. lastItemName .. " [" .. lastRarity .. "]"
            if #receivedRarities > 0 then
                log("ShopGacha: Roll #" .. shopGachaRolls .. " → " .. table.concat(receivedRarities, ", "), THEME.dim)
            else
                log("ShopGacha: Roll #" .. shopGachaRolls .. " (done)", THEME.dim)
            end

            -- Stop condition
            if gotStopRarity then
                gui.ShopGacha.Status.Text = "Status: STOPPED! Got " .. lastItemName .. " [" .. lastRarity .. "]!"
                gui.ShopGacha.Status.TextColor3 = THEME.success
                log("ShopGacha: STOPPED - " .. lastItemName .. " (" .. lastRarity .. ") after " .. shopGachaRolls .. " rolls!", THEME.success)
                ctx.shopGachaEnabled = false
                gui.ShopGacha.ToggleBtn.Text = "Shop Gacha: OFF"
                gui.ShopGacha.ToggleBtn.BackgroundColor3 = THEME.accent

                sendWebhookRaw({
                    embeds = {{
                        title = "🛒 Shop Gacha Target!",
                        description = "**" .. lp.Name .. "** got the target from shop rolls!",
                        color = 16766720,
                        thumbnail = {url = "https://tr.rbxcdn.com/180DAY-0250e05e2ec3e54faf2791022401a956/150/150/Image/Webp/noFilter"},
                        fields = {
                            {name = "Item :", value = "```" .. lastItemName .. "```", inline = false},
                            {name = "Rarity :", value = "```" .. lastRarity .. "```", inline = true},
                            {name = "Total Rolls :", value = "```" .. tostring(shopGachaRolls) .. "```", inline = true},
                            {name = "Type :", value = "```" .. shopGachaType .. "```", inline = false},
                        },
                        footer = {text = "LyraHub • " .. lp.Name .. " • " .. os.date("%m/%d/%Y %I:%M %p")},
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    }}
                })
                break
            end

            task.wait(0.5)
        end

        if ctx.shopGachaEnabled then
            gui.ShopGacha.Status.Text = "Status: Idle | Rolls: " .. shopGachaRolls
            gui.ShopGacha.Status.TextColor3 = THEME.dim
        end
        log("ShopGacha: Stopped", THEME.dim)
    end

    bind(gui.ShopGacha.ToggleBtn.MouseButton1Click, function()
        ctx.shopGachaEnabled = not ctx.shopGachaEnabled
        if ctx.shopGachaEnabled then
            gui.ShopGacha.ToggleBtn.Text = "Shop Gacha: ON"
            gui.ShopGacha.ToggleBtn.BackgroundColor3 = THEME.success
            task.spawn(shopGachaLoop)
        else
            gui.ShopGacha.ToggleBtn.Text = "Shop Gacha: OFF"
            gui.ShopGacha.ToggleBtn.BackgroundColor3 = THEME.accent
            gui.ShopGacha.Status.Text = "Status: Stopped | Rolls: " .. shopGachaRolls
            gui.ShopGacha.Status.TextColor3 = THEME.dim
        end
        if gui.Toast and gui.Toast.show then
            local msg = ctx.shopGachaEnabled and "Shop Gacha started" or "Shop Gacha stopped"
            gui.Toast.show({Text = msg, Variant = ctx.shopGachaEnabled and "success" or "info", Duration = 1.5})
        end
    end)
end
