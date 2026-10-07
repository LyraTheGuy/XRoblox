-- IndoVoice/modules/settingsintegration.lua
-- ============================================================================
-- SAVED SETTINGS PROFILES — INTEGRATION
-- ============================================================================
-- The dedicated integration module described by the saved-settings design:
--   * gathers every user-configurable setting from `ctx` / the modules
--     (`ctx.collectProfileSettings`)
--   * applies a loaded profile back onto `ctx`, the UI and each feature
--     (`ctx.applyProfileSettings`) using the per-feature setters the modules
--     expose (ctx.setAutoFish, ctx.setAutoMine, ctx.adminMenu.setConfig, ...)
--   * wires the Settings-menu profile widgets built by gui.lua to
--     ctx.SettingsProfiles (storage lives in modules/SettingsProfiles.lua)
--
-- Loaded LAST (after every feature module) so all setters/UI exist.
-- ============================================================================

return function(ctx)
    local Players = ctx.Players
    local bind = ctx.bind
    local log = ctx.log
    local THEME = ctx.THEME
    local config = ctx.config

    local SP = ctx.SettingsProfiles
    local P = ctx.gui and ctx.gui.Settings and ctx.gui.Settings.Profiles
    if not P or not P.Dropdown then
        warn("[SettingsProfiles] Profile UI not found — skipping integration.")
        return
    end
    if not SP then
        warn("[SettingsProfiles] Storage module not loaded — skipping integration.")
        return
    end

    -- ------------------------------------------------------------------
    -- SMALL HELPERS
    -- ------------------------------------------------------------------
    local function keyName(k)
        return tostring(k):gsub("Enum.KeyCode.", "")
    end

    local function keyFromName(name)
        return type(name) == "string" and Enum.KeyCode[name] or nil
    end

    local function listToMap(list)
        local map = {}
        if type(list) == "table" then
            for _, v in ipairs(list) do map[v] = true end
        end
        return map
    end

    local function mapToList(map)
        local list = {}
        if type(map) == "table" then
            for k, v in pairs(map) do
                if v then table.insert(list, k) end
            end
        end
        return list
    end

    local function shallowCopy(t)
        local out = {}
        if type(t) == "table" then
            for k, v in pairs(t) do out[k] = v end
        end
        return out
    end

    local function deepCopy(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do out[k] = deepCopy(v) end
        return out
    end

    local function findPlayerByName(name)
        if type(name) ~= "string" or name == "" or name == "None" then return nil end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == name or plr.DisplayName == name then return plr end
        end
        return nil
    end

    -- ------------------------------------------------------------------
    -- COLLECT — snapshot every user-configurable setting
    -- ------------------------------------------------------------------
    local function collect()
        local data = {}

        -- General: hotkeys + theme
        data.hideKey = keyName(ctx.HIDE_KEY)
        data.theme = ctx.activeThemeVariant or "Dark"

        -- Auto Clicker
        data.clicker = {
            cps = ctx.clickCPS,
            toggleKey = keyName(ctx.TOGGLE_KEY),
            positionMode = ctx.POSITION_MODE,
            savedX = ctx.savedX,
            savedY = ctx.savedY,
        }

        -- Auto Fish + FishZone (fishing delays are read from config.FishTiming)
        data.fishing = {
            zoneESP = ctx.zoneESPOn and true or false,
            autoTP = ctx.autoTPEnabled and true or false,
            autoFish = ctx.autoFishEnabled and true or false,
            autoSell = ctx.autoSellEnabled and true or false,
            sellInterval = ctx.AUTO_SELL_INTERVAL,
            sellRarities = (ctx.getActiveSellRarities and ctx.getActiveSellRarities()) or {},
            follow = ctx.followEnabled and true or false,
            followTarget = ctx.followTargetName,
        }

        -- Auto Mine
        data.mining = {
            autoMine = ctx.autoMineEnabled and true or false,
            hotspotESP = ctx.mineESPOn and true or false,
            autoTP = ctx.autoMineTPEnabled and true or false,
            hotspotOnly = ctx.autoMineHotspotOnly and true or false,
            autoSellOre = ctx.autoSellOreEnabled and true or false,
            sellInterval = ctx.ORE_SELL_INTERVAL,
            sellRarities = mapToList(ctx.oreSellRarities),
            follow = ctx.mineFollowEnabled and true or false,
            followTarget = ctx.mineFollowTargetName,
        }

        -- Gacha (selected box / roll type / stop rarities are user values)
        data.gacha = {
            auto = ctx.autoGachaEnabled and true or false,
            box = ctx.selectedGachaBox,
            stop = shallowCopy(ctx.gachaStopRarities),
        }
        data.shopGacha = {
            auto = ctx.shopGachaEnabled and true or false,
            type = ctx.shopGachaType,
            stop = shallowCopy(ctx.shopGachaStopRarities),
        }

        -- Settings toggles
        data.toggles = {
            antiIdle = ctx.antiIdleEnabled and true or false,
            antiAfk = ctx.antiAfkEnabled and true or false,
            autoClaimDaily = ctx.autoClaimDailyRewardEnabled and true or false,
            autoClaimSession = ctx.autoClaimSessionRewardEnabled and true or false,
        }

        -- Webhook
        data.webhook = {
            url = ctx.webhookURL,
            enabled = ctx.webhookEnabled and true or false,
            logSells = ctx.webhookLogSells and true or false,
            rarities = (ctx.getActiveWebhookRarities and ctx.getActiveWebhookRarities()) or {},
        }

        -- Players tab: camera / beam / ESP / TP + selected target
        if ctx.adminMenu and ctx.adminMenu.getConfig then
            data.players = ctx.adminMenu.getConfig()
            local state = ctx.adminMenu.getState and ctx.adminMenu.getState()
            data.players.targetName = (state and state.target) and state.target.Name or nil
        end

        return data
    end
    ctx.collectProfileSettings = collect

    -- ------------------------------------------------------------------
    -- APPLY — restore a loaded profile
    -- ------------------------------------------------------------------
    local function apply(data)
        if type(data) ~= "table" then
            return false, "Invalid settings data"
        end

        local applied, failed = 0, 0
        local function run(fn)
            if type(fn) ~= "function" then return end
            local ok, err = pcall(fn)
            if ok then
                applied = applied + 1
            else
                failed = failed + 1
                log("Profile restore warning: " .. tostring(err), THEME.warn)
            end
        end

        -- General: theme + hide key
        if data.theme and ctx.applyThemeVariant then
            run(function() ctx.applyThemeVariant(data.theme) end)
        end
        if data.hideKey then
            local kc = keyFromName(data.hideKey)
            if kc then
                run(function()
                    ctx.config.Keys.HideUI = kc
                    ctx.HIDE_KEY = kc
                    if ctx.gui.Settings.HideKeyLbl then
                        ctx.gui.Settings.HideKeyLbl.Text = "Hide/Show UI: " .. data.hideKey
                    end
                    if ctx.gui.Settings.HideUIKeybind and ctx.gui.Settings.HideUIKeybind.Set then
                        ctx.gui.Settings.HideUIKeybind.Set(kc, false)
                    end
                end)
            end
        end

        -- Auto Clicker (settings only — clicking is transient and not saved)
        local c = data.clicker
        if type(c) == "table" then
            if tonumber(c.cps) then
                run(function()
                    ctx.clickCPS = math.clamp(math.floor(tonumber(c.cps)), 1, 100)
                    ctx.clickDelay = 1 / ctx.clickCPS
                    if ctx.updateClickerSliderUI then ctx.updateClickerSliderUI() end
                end)
            end
            if c.toggleKey and keyFromName(c.toggleKey) then
                run(function()
                    ctx.TOGGLE_KEY = keyFromName(c.toggleKey)
                    if ctx.updateKeybindUI then ctx.updateKeybindUI() end
                end)
            end
            if tonumber(c.savedX) and tonumber(c.savedY) then
                run(function()
                    ctx.savedX = tonumber(c.savedX)
                    ctx.savedY = tonumber(c.savedY)
                    if ctx.updateClickerUI then ctx.updateClickerUI() end
                end)
            end
        end

        -- Auto Fish / FishZone
        local f = data.fishing
        if type(f) == "table" then
            if f.sellInterval then
                run(function()
                    ctx.AUTO_SELL_INTERVAL = tonumber(f.sellInterval) or ctx.AUTO_SELL_INTERVAL
                    ctx.gui.FishZone.SellIntervalInput.Text = tostring(ctx.AUTO_SELL_INTERVAL)
                end)
            end
            if type(f.sellRarities) == "table" then
                run(function()
                    ctx.sellRarities = listToMap(f.sellRarities)
                    ctx.AUTO_SELL_RARITIES = f.sellRarities
                    if ctx.updateSellRarityUI then ctx.updateSellRarityUI() end
                end)
            end
            if ctx.setZoneESP and f.zoneESP ~= nil then
                run(function() ctx.setZoneESP(f.zoneESP) end)
            end
            if ctx.setAutoFish and f.autoFish ~= nil then
                run(function() ctx.setAutoFish(f.autoFish) end)
            end
            if ctx.setAutoSellFish and f.autoSell ~= nil then
                run(function() ctx.setAutoSellFish(f.autoSell) end)
            end
            if f.autoTP ~= nil then
                if f.autoTP then
                    run(function()
                        ctx.startAutoTP()
                        if ctx.moveToNearestActiveZone then ctx.moveToNearestActiveZone() end
                    end)
                else
                    run(function() ctx.stopAutoTP() end)
                end
            end
            if ctx.setFishFollow then
                local target = f.follow and findPlayerByName(f.followTarget) or nil
                if f.follow then
                    run(function() ctx.setFishFollow(true, target) end)
                else
                    run(function() ctx.setFishFollow(false) end)
                end
            end
        end

        -- Auto Mine
        local m = data.mining
        if type(m) == "table" then
            if m.sellInterval then
                run(function()
                    ctx.ORE_SELL_INTERVAL = tonumber(m.sellInterval) or ctx.ORE_SELL_INTERVAL
                    ctx.gui.Mining.SellIntervalInput.Text = tostring(ctx.ORE_SELL_INTERVAL)
                end)
            end
            if type(m.sellRarities) == "table" then
                run(function()
                    ctx.oreSellRarities = listToMap(m.sellRarities)
                    if ctx.updateOreSellRarityUI then ctx.updateOreSellRarityUI() end
                end)
            end
            if ctx.setMineESP and m.hotspotESP ~= nil then
                run(function() ctx.setMineESP(m.hotspotESP) end)
            end
            if ctx.setAutoMineTP and m.autoTP ~= nil then
                run(function() ctx.setAutoMineTP(m.autoTP) end)
            end
            if ctx.setAutoSellOre and m.autoSellOre ~= nil then
                run(function() ctx.setAutoSellOre(m.autoSellOre) end)
            end
            if ctx.setMineFollow then
                local target = m.follow and findPlayerByName(m.followTarget) or nil
                if m.follow then
                    run(function() ctx.setMineFollow(true, target) end)
                else
                    run(function() ctx.setMineFollow(false) end)
                end
            end
            if ctx.setAutoMine and m.autoMine ~= nil then
                run(function() ctx.setAutoMine(m.autoMine) end)
            end
        end

        -- Gacha
        local g = data.gacha
        if type(g) == "table" then
            if g.box and ctx.setGachaBox then
                run(function() ctx.setGachaBox(g.box) end)
            end
            if type(g.stop) == "table" and ctx.applyGachaStopRarities then
                run(function() ctx.applyGachaStopRarities(g.stop) end)
            end
            if ctx.setAutoGacha and g.auto ~= nil then
                run(function() ctx.setAutoGacha(g.auto) end)
            end
        end
        local sg = data.shopGacha
        if type(sg) == "table" then
            if sg.type and ctx.setShopGachaType then
                run(function() ctx.setShopGachaType(sg.type) end)
            end
            if type(sg.stop) == "table" and ctx.applyShopGachaStopRarities then
                run(function() ctx.applyShopGachaStopRarities(sg.stop) end)
            end
            if ctx.setShopGacha and sg.auto ~= nil then
                run(function() ctx.setShopGacha(sg.auto) end)
            end
        end

        -- Settings toggles
        local t = data.toggles
        if type(t) == "table" then
            if ctx.setAntiIdle and t.antiIdle ~= nil then run(function() ctx.setAntiIdle(t.antiIdle) end) end
            if ctx.setAntiAfk and t.antiAfk ~= nil then run(function() ctx.setAntiAfk(t.antiAfk) end) end
            if ctx.setAutoClaimDaily and t.autoClaimDaily ~= nil then run(function() ctx.setAutoClaimDaily(t.autoClaimDaily) end) end
            if ctx.setAutoClaimSession and t.autoClaimSession ~= nil then run(function() ctx.setAutoClaimSession(t.autoClaimSession) end) end
        end

        -- Webhook
        local w = data.webhook
        if type(w) == "table" then
            if w.url then
                run(function()
                    ctx.webhookURL = w.url
                    ctx.gui.Settings.WebhookInput.Text = w.url
                end)
            end
            if w.enabled ~= nil then
                run(function()
                    ctx.webhookEnabled = w.enabled and true or false
                    ctx.gui.Settings.WebhookToggleBtn.Text = ctx.webhookEnabled and "Webhook: ON" or "Webhook: OFF"
                    ctx.gui.Settings.WebhookToggleBtn.BackgroundColor3 = ctx.webhookEnabled and THEME.success or THEME.panel2
                end)
            end
            if w.logSells ~= nil then
                run(function() ctx.webhookLogSells = w.logSells and true or false end)
            end
            if type(w.rarities) == "table" then
                run(function()
                    ctx.webhookRarityState = listToMap(w.rarities)
                    ctx.webhookLogRarities = w.rarities
                    if ctx.updateWebhookRarityUI then ctx.updateWebhookRarityUI() end
                end)
            end
        end

        -- Players tab: camera / beam / ESP / TP + target
        local p = data.players
        if type(p) == "table" and ctx.adminMenu then
            if ctx.adminMenu.setConfig then
                run(function() ctx.adminMenu.setConfig(p) end)
            end
            if p.targetName then
                local target = findPlayerByName(p.targetName)
                if target and ctx.adminMenu.selectTarget then
                    run(function() ctx.adminMenu.selectTarget(target) end)
                end
            end
        end

        local ok = (failed == 0)
        return ok, string.format("applied %d setting(s)%s", applied,
            failed > 0 and (", " .. failed .. " skipped") or "")
    end
    ctx.applyProfileSettings = apply

    -- Wire the storage module's "save current settings" hook to our collector.
    SP.SetCollector(collect)

    -- ------------------------------------------------------------------
    -- UI STATE
    -- ------------------------------------------------------------------
    local selected = SP.GetCurrent() -- dropdown selection (may differ from current)
    local confirmDelete = false
    local lastSnapshot = SP.Signature and SP.Signature()
    local lastDirtyCheck = 0
    local dirtyShown = false
    -- Session bookkeeping:哪些 profile 已在本次会话中 loaded/saved 到 ctx
    local lastLoadedSession, lastSavedSession = {}, {}
    local loadProfile -- forward declaration (used by the dropdown row closures)

    local function setStatus(msg, color)
        P.StatusLabel.Text = msg
        P.StatusLabel.TextColor3 = color or THEME.dim
    end

    local function refreshCurrentLabel()
        local current = SP.GetCurrent()
        P.CurrentLabel.Text = "Current Profile: " .. (current or "—")
    end

    local function refreshDropdown()
        for _, child in ipairs(P.DropdownList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local names = SP.List()
        P.Empty.Visible = (#names == 0)
        P.DropdownList.CanvasSize = UDim2.new(0, 0, 0, math.max(#names * 26, 26))
        P.Dropdown.Text = (selected or "Select profile…") .. "   ▼"

        local active = SP.GetCurrent()
        for _, name in ipairs(names) do
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, -6, 0, 24)
            row.BackgroundColor3 = (name == active) and THEME.accentDark or THEME.panel2
            row.BackgroundTransparency = 0.25
            row.Text = name .. ((name == active) and "  ●" or "")
            row.TextColor3 = (name == active) and THEME.text or THEME.dim
            row.Font = Enum.Font.GothamBold
            row.TextSize = 10
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.AutoButtonColor = false
            row.BorderSizePixel = 0
            row.ZIndex = 31
            row.Parent = P.DropdownList
            local corner = Instance.new("UICorner", row)
            corner.CornerRadius = UDim.new(0, 5)
            local pad = Instance.new("UIPadding", row)
            pad.PaddingLeft = UDim.new(0, 8)

            row.MouseButton1Click:Connect(function()
                selected = name
                P.DropdownList.Visible = false
                loadProfile(name)
            end)
        end
    end

    local function resetDirty()
        lastSnapshot = SP.Signature and SP.Signature()
        dirtyShown = false
    end

    -- ------------------------------------------------------------------
    -- PROFILE OPERATIONS
    -- ------------------------------------------------------------------
    loadProfile = function(name)
        if not name or name == "" then
            setStatus("Select a profile first", THEME.warn)
            return
        end
        setStatus("Loading '" .. name .. "'…", THEME.dim)
        local data, err = SP.Load(name)
        if not data then
            setStatus("Load failed: " .. tostring(err), THEME.danger)
            return
        end
        local ok, summary = apply(data)
        lastLoadedSession[name] = os.clock()
        lastSavedSession[name] = nil
        resetDirty()
        refreshDropdown()
        refreshCurrentLabel()
        if ok then
            setStatus("Loaded profile '" .. name .. "' (" .. tostring(summary) .. ")", THEME.success)
            log("Settings profile loaded: " .. name, THEME.success)
        else
            setStatus("Profile '" .. name .. "' loaded with warnings: " .. tostring(summary), THEME.warn)
            log("Settings profile loaded with warnings: " .. name, THEME.warn)
        end
    end

    local function saveProfile(name)
        name = (name and name ~= "") and name
            or (P.NameInput.Text ~= "" and P.NameInput.Text)
            or selected
            or SP.GetCurrent()
            or (config.Profiles and config.Profiles.DefaultName)
            or "Default"
        setStatus("Saving '" .. name .. "'…", THEME.dim)
        local ok, err = SP.Save(name)
        if not ok then
            setStatus("Save failed: " .. tostring(err), THEME.danger)
            return
        end
        selected = name
        P.NameInput.Text = ""
        lastSavedSession[name] = os.clock()
        lastLoadedSession[name] = nil
        resetDirty()
        refreshDropdown()
        refreshCurrentLabel()
        setStatus("Saved current settings to '" .. name .. "'", THEME.success)
        log("Settings profile saved: " .. name, THEME.success)
    end

    local function createProfile(name)
        name = (name and name ~= "") and name or P.NameInput.Text
        if not name or name == "" then
            setStatus("Enter a profile name first", THEME.warn)
            return
        end
        local ok, err = SP.Create(name)
        if not ok then
            setStatus("Create failed: " .. tostring(err), THEME.danger)
            return
        end
        selected = name
        P.NameInput.Text = ""
        refreshDropdown()
        refreshCurrentLabel()
        setStatus("Created profile '" .. name .. "' — press Save to fill it", THEME.success)
        log("Settings profile created: " .. name, THEME.accentGlow)
    end

    local function renameProfile(newName)
        local old = selected or SP.GetCurrent()
        newName = (newName and newName ~= "") and newName or P.NameInput.Text
        if not old then
            setStatus("Select a profile to rename", THEME.warn)
            return
        end
        if not newName or newName == "" then
            setStatus("Enter the new name in the box above", THEME.warn)
            return
        end
        local ok, err = SP.Rename(old, newName)
        if not ok then
            setStatus("Rename failed: " .. tostring(err), THEME.danger)
            return
        end
        selected = newName
        P.NameInput.Text = ""
        refreshDropdown()
        refreshCurrentLabel()
        setStatus("Renamed '" .. old .. "' → '" .. newName .. "'", THEME.success)
        log("Settings profile renamed: " .. old .. " → " .. newName, THEME.accentGlow)
    end

    local function deleteProfile()
        local target = selected or SP.GetCurrent()
        if not target then
            setStatus("Select a profile to delete", THEME.warn)
            return
        end
        if SP.GetCurrent() == target then
            setStatus("Cannot delete the active profile — load another first", THEME.danger)
            return
        end
        if not confirmDelete then
            confirmDelete = true
            P.DeleteButton.Text = "Confirm Delete?"
            setStatus("Click Delete again to confirm removing '" .. target .. "'", THEME.warn)
            task.delay(4, function()
                if confirmDelete then
                    confirmDelete = false
                    if P.DeleteButton.Parent then P.DeleteButton.Text = "Delete Profile" end
                end
            end)
            return
        end
        confirmDelete = false
        P.DeleteButton.Text = "Delete Profile"
        local ok, err = SP.Delete(target)
        if not ok then
            setStatus("Delete failed: " .. tostring(err), THEME.danger)
            return
        end
        if selected == target then selected = nil end
        refreshDropdown()
        refreshCurrentLabel()
        setStatus("Deleted '" .. target .. "'", THEME.success)
        log("Settings profile deleted: " .. target, THEME.danger)
    end

    -- Returns the most recently saved/loaded profile (for startup auto-restore).
    -- Values are os.clock() timestamps (set in loadProfile/saveProfile below).
    local function latestSessionProfile()
        local picked, bestAt
        for _, entry in ipairs({ lastSavedSession, lastLoadedSession }) do
            for name in pairs(entry) do
                local at = entry[name]
                if at and at ~= true and (not bestAt or at > bestAt) then
                    bestAt, picked = at, name
                end
            end
        end
        return picked
    end

    local function loadLastProfile()
        -- Session map first; fall back to the persisted active profile
        -- (index.json's "current" survives executor restarts).
        local name = latestSessionProfile() or SP.GetCurrent()
        if not name then
            setStatus("No profile was loaded or saved last run", THEME.dim)
            return
        end
        loadProfile(name)
    end

    ctx.settingsProfilesUI = {
        Refresh = function() refreshDropdown(); refreshCurrentLabel() end,
        Load = loadProfile,
        Save = saveProfile,
        Create = createProfile,
        Rename = renameProfile,
        Delete = deleteProfile,
        GetSelected = function() return selected end,
        LoadLast = loadLastProfile,
    }

    -- ------------------------------------------------------------------
    -- WIRE UI
    -- ------------------------------------------------------------------
    bind(P.Dropdown.MouseButton1Click, function()
        P.DropdownList.Visible = not P.DropdownList.Visible
        if P.DropdownList.Visible then refreshDropdown() end
    end)
    -- "Save Current Settings" replaces the old "Save All Settings" button:
    -- it snapshots every setting (incl. a freshly typed webhook URL) into the
    -- selected/new profile and marks it for auto-restore on the next run.
    bind(P.SaveButton.MouseButton1Click, function()
        if ctx.gui.Settings.WebhookInput then
            ctx.webhookURL = ctx.gui.Settings.WebhookInput.Text
        end
        saveProfile()
    end)
    bind(P.LoadButton.MouseButton1Click, function() loadProfile(selected) end)
    bind(P.CreateButton.MouseButton1Click, function() createProfile() end)
    bind(P.RenameButton.MouseButton1Click, function() renameProfile() end)
    bind(P.DeleteButton.MouseButton1Click, function() deleteProfile() end)

    -- Unsaved-changes watchdog (throttled; compares encoded signatures).
    bind(ctx.RunService.Heartbeat, function()
        if ctx.destroyed then return end
        local now = tick()
        if now - lastDirtyCheck < 2 then return end
        lastDirtyCheck = now
        local sig = SP.Signature and SP.Signature()
        if not sig or not lastSnapshot then return end
        local isDirty = (sig ~= lastSnapshot)
        if isDirty and not dirtyShown then
            dirtyShown = true
            setStatus("Unsaved changes — press Save Current Settings to keep them", THEME.warn)
        end
    end)

    -- Initial render
    refreshDropdown()
    refreshCurrentLabel()
    local restoreName = latestSessionProfile() or SP.GetCurrent()
    setStatus("Profiles ready — " .. SP.Count() .. " saved"
        .. (restoreName and (" — auto-restoring '" .. restoreName .. "'") or ""), THEME.dim)
    log("Settings profiles ready (" .. SP.Count() .. " saved)", THEME.accentGlow)

    -- Startup auto-restore: if the previous run ended on a saved/loaded
    -- profile, re-apply it shortly after boot (config-defaults load ran
    -- earlier in core.lua; this layers the profile's state on top).
    if restoreName then
        task.delay(1.0, function()
            if not ctx.destroyed then loadLastProfile() end
        end)
    end
end
