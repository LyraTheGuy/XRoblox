-- modules/gacha.lua
-- Auto Gacha System (Blind Box)
return function(ctx)
    local gui = ctx.gui
    local THEME = ctx.THEME
    local lp = ctx.lp
    local bind = ctx.bind
    local log = ctx.log
    local sendWebhookRaw = ctx.sendWebhookRaw

    local autoGachaRolls = 0
    local gachaStopRarities = {}
    local selectedGachaBox = gui.Gacha.SelectedBox.Value

    -- Box selection buttons
    for boxName, btn in pairs(gui.Gacha.BoxButtons) do
        bind(btn.MouseButton1Click, function()
            selectedGachaBox = boxName
            gui.Gacha.SelectedBox.Value = boxName
            for bName, bBtn in pairs(gui.Gacha.BoxButtons) do
                if bName == boxName then
                    bBtn.BackgroundColor3 = THEME.accent
                    bBtn.BackgroundTransparency = 0.2
                    bBtn.TextColor3 = Color3.new(1, 1, 1)
                else
                    bBtn.BackgroundColor3 = THEME.panel2
                    bBtn.BackgroundTransparency = 0.6
                    bBtn.TextColor3 = THEME.dim
                end
            end
            log("Gacha: Selected box → " .. boxName, THEME.dim)
        end)
    end

    -- Stop rarity toggle buttons
    for rarity, btn in pairs(gui.Gacha.StopButtons) do
        bind(btn.MouseButton1Click, function()
            gachaStopRarities[rarity] = not gachaStopRarities[rarity]
            if gachaStopRarities[rarity] then
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

    local function autoGachaLoop()
        log("AutoGacha: Started [" .. selectedGachaBox .. "]", THEME.success)
        gui.Gacha.Status.Text = "Status: Running | Rolls: 0"
        gui.Gacha.Status.TextColor3 = THEME.success

        while ctx.autoGachaEnabled and not ctx.destroyed do
            local boxName = selectedGachaBox

            if boxName == "" then
                gui.Gacha.Status.Text = "Status: Select a box first!"
                gui.Gacha.Status.TextColor3 = THEME.warn
                task.wait(2)
                continue
            end

            -- Listen for rarity result from the reward event
            local receivedRarities = {}
            local receivedNames = {}
            local completionConn
            pcall(function()
                local gre = game:GetService("ReplicatedStorage"):FindFirstChild("GameRemoteEvents")
                local rewardEvent = gre and gre:FindFirstChild("CreateBlindBoxRewardInfoEvent")
                if rewardEvent and rewardEvent:IsA("RemoteEvent") then
                    completionConn = rewardEvent.OnClientEvent:Connect(function(info, _, rarity, petId, ...)
                        local r = rarity or (info and info.Rarity)
                        local name = (info and info.Name) or petId or "?"
                        if r and type(r) == "string" then
                            table.insert(receivedRarities, r)
                            table.insert(receivedNames, name)
                        end
                    end)
                end
            end)

            -- Roll 10x
            gui.Gacha.Status.Text = "Status: Rolling 10x [" .. boxName .. "]..."
            local rollOk, rollResult = pcall(function()
                return game:GetService("ReplicatedStorage").GameRemoteFunctions.BlindBoxRollFunction:InvokeServer("Pet", boxName, 10)
            end)

            task.wait(1)

            if completionConn then completionConn:Disconnect() end

            if not rollOk then
                gui.Gacha.Status.Text = "Status: Roll failed!"
                gui.Gacha.Status.TextColor3 = THEME.danger
                log("AutoGacha: Error - " .. tostring(rollResult), THEME.danger)
                task.wait(3)
                continue
            end

            autoGachaRolls = autoGachaRolls + 10
            gui.Gacha.Status.Text = "Status: Running | Rolls: " .. autoGachaRolls

            -- Destroy blind box animation/UI
            pcall(function()
                local playerGui = lp:FindFirstChild("PlayerGui")
                if playerGui then
                    for _, g in pairs(playerGui:GetChildren()) do
                        if g:IsA("ScreenGui") then
                            if g:FindFirstChild("BlindBox", true) or g:FindFirstChild("GachaHolder", true)
                                or g:FindFirstChild("Gacha", true) or string.find(g.Name, "BlindBox")
                                or string.find(g.Name, "Gacha") or string.find(g.Name, "Roll") then
                                g:Destroy()
                            end
                        end
                    end
                end
            end)

            -- Check received rarities
            local gotStopRarity = false
            local lastRarity = "?"
            local lastPetName = "?"

            if #receivedRarities > 0 then
                for i, r in ipairs(receivedRarities) do
                    lastRarity = r
                    lastPetName = receivedNames[i] or "?"
                    if gachaStopRarities[r] then
                        gotStopRarity = true
                    end
                end
            else
                if type(rollResult) == "table" then
                    for _, item in ipairs(rollResult) do
                        local r = type(item) == "table" and (item.Rarity or item.rarity) or nil
                        if r then
                            lastRarity = tostring(r)
                            if gachaStopRarities[lastRarity] then
                                gotStopRarity = true
                            end
                        end
                    end
                end
            end

            gui.Gacha.LastResult.Text = "Last: " .. lastPetName .. " [" .. lastRarity .. "]"
            if #receivedRarities > 0 then
                log("AutoGacha: Roll #" .. autoGachaRolls .. " → " .. table.concat(receivedRarities, ", "), THEME.dim)
            else
                log("AutoGacha: Roll #" .. autoGachaRolls .. " (no rarity data)", THEME.dim)
            end

            -- Check stop condition
            if gotStopRarity then
                gui.Gacha.Status.Text = "Status: STOPPED! Got " .. lastPetName .. " [" .. lastRarity .. "]!"
                gui.Gacha.Status.TextColor3 = THEME.success
                log("AutoGacha: STOPPED - obtained " .. lastPetName .. " (" .. lastRarity .. ") after " .. autoGachaRolls .. " rolls!", THEME.success)
                ctx.autoGachaEnabled = false
                gui.Gacha.ToggleBtn.Text = "Auto Gacha: OFF"
                gui.Gacha.ToggleBtn.BackgroundColor3 = THEME.accent

                sendWebhookRaw({
                    embeds = {{
                        title = "🎰 Gacha Target Obtained!",
                        description = "**" .. lp.Name .. "** hit the jackpot!",
                        color = 16766720,
                        thumbnail = {url = "https://tr.rbxcdn.com/180DAY-0250e05e2ec3e54faf2791022401a956/150/150/Image/Webp/noFilter"},
                        fields = {
                            {name = "Pet :", value = "```" .. lastPetName .. "```", inline = false},
                            {name = "Rarity :", value = "```" .. lastRarity .. "```", inline = true},
                            {name = "Total Rolls :", value = "```" .. tostring(autoGachaRolls) .. "```", inline = true},
                            {name = "Box :", value = "```Pet / " .. boxName .. "```", inline = false},
                        },
                        footer = {text = "LyraHub • " .. lp.Name .. " • " .. os.date("%m/%d/%Y %I:%M %p")},
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    }}
                })
                break
            end

            task.wait(1.5)
        end

        if ctx.autoGachaEnabled then
            gui.Gacha.Status.Text = "Status: Idle | Rolls: " .. autoGachaRolls
            gui.Gacha.Status.TextColor3 = THEME.dim
        end
    end

    bind(gui.Gacha.ToggleBtn.MouseButton1Click, function()
        ctx.autoGachaEnabled = not ctx.autoGachaEnabled
        if ctx.autoGachaEnabled then
            gui.Gacha.ToggleBtn.Text = "Auto Gacha: ON"
            gui.Gacha.ToggleBtn.BackgroundColor3 = THEME.success
            task.spawn(autoGachaLoop)
        else
            gui.Gacha.ToggleBtn.Text = "Auto Gacha: OFF"
            gui.Gacha.ToggleBtn.BackgroundColor3 = THEME.accent
            gui.Gacha.Status.Text = "Status: Stopped | Rolls: " .. autoGachaRolls
            gui.Gacha.Status.TextColor3 = THEME.dim
        end
        if gui.Toast and gui.Toast.show then
            local msg = ctx.autoGachaEnabled and "Auto Gacha started" or "Auto Gacha stopped"
            gui.Toast.show({Text = msg, Variant = ctx.autoGachaEnabled and "success" or "info", Duration = 1.5})
        end
    end)
end
