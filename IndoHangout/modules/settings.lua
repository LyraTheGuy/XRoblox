-- IndoHangout/modules/settings.lua
-- JSON configuration profiles: save, load, delete, refresh, autoload.
-- Self-contained storage layer (filesystem -> memory) plus Settings tab UI.

return function(ctx)
    local HttpService = game:GetService("HttpService")
    local THEME = ctx.config.Theme
    local PROFILES = ctx.config.Profiles or {}
    local FOLDER = PROFILES.Folder or "IndoHangout/Profiles"
    local FORMAT = PROFILES.Format or "IndoHangoutProfile"
    local VERSION = tonumber(PROFILES.Version) or 1
    local MAX_NAME = tonumber(PROFILES.MaxNameLength) or 24
    local MAX_PROFILES = tonumber(PROFILES.MaxProfiles) or 50
    local DEFAULT_NAME = PROFILES.DefaultName or "Default"

    -- Feature module handles (may be nil early; settings UI builds immediately)
    local fishingMod = ctx.fishing
    local miningMod = ctx.mining
    local miscMod = ctx.misc

    local gui = ctx.gui
    local page = gui.TabPages.Settings

    ---------------------------------------------------------------------
    -- UI COMPONENT REFS
    ---------------------------------------------------------------------
    local profileNameInput = nil
    local savedDropdown = nil
    local statusLabel = nil
    local autoloadToggle = nil
    local autoloadSelector = nil

    ---------------------------------------------------------------------
    -- STORAGE CAPABILITY DETECTION
    ---------------------------------------------------------------------
    local hasFS = pcall(function()
        assert(type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")
    end)
    local hasDelete = pcall(function() assert(type(delfile) == "function") end)
    local hasList = pcall(function() assert(type(listfiles) == "function") end)

    -- In-memory index fallback
    local memoryIndex = { profiles = {}, current = nil, autoLoad = nil }

    ---------------------------------------------------------------------
    -- HELPERS
    ---------------------------------------------------------------------
    local function sanitizeName(name)
        if type(name) ~= "string" then return nil, "Invalid name" end
        name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
        if name == "" then return nil, "Name cannot be empty" end
        if #name > MAX_NAME then name = name:sub(1, MAX_NAME) end
        return name, nil
    end

    local function slugOf(name)
        local s = tostring(name):lower():gsub("[^%w]+", "_") :gsub("^_+", "") :gsub("_+$", "")
        if s == "" then s = "profile" end
        return s
    end

    local function filePath(name)
        return FOLDER .. "/" .. slugOf(name) .. ".json"
    end

    local function indexPath()
        return FOLDER .. "/index.json"
    end

    local function ensureFolder()
        if not hasFS then return end
        pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" then
                if not isfolder(FOLDER) then makefolder(FOLDER) end
            end
        end)
    end

    local function readFile(path)
        if not hasFS then return nil end
        local ok, content = pcall(function()
            if isfile(path) then return readfile(path) end
            return nil
        end)
        if ok then return content end
        return nil
    end

    local function writeFile(path, data)
        if not hasFS then return false end
        ensureFolder()
        return pcall(function() writefile(path, data) end)
    end

    local function removeFile(path)
        if not hasFS or not hasDelete then return false end
        return pcall(function()
            if isfile(path) then delfile(path) end
        end)
    end

    ---------------------------------------------------------------------
    -- JSON (DE)SERIALIZATION WITH ROBLOX DATATYPE SUPPORT
    ---------------------------------------------------------------------
    local function isArray(t)
        local n = 0
        for k in pairs(t) do
            if type(k) ~= "number" then return false end
            n = n + 1
        end
        return n == #t
    end

    local function encode(v)
        local t = type(v)
        if t == "number" or t == "string" or t == "boolean" then
            return v
        end
        if t == "table" then
            if isArray(v) then
                local out = {}
                for i = 1, #v do
                    out[i] = encode(v[i])
                end
                return out
            end
            local out = {}
            for k, val in pairs(v) do
                if type(k) == "string" or type(k) == "number" then
                    local ev = encode(val)
                    if ev ~= nil then out[tostring(k)] = ev end
                end
            end
            return out
        end
        if type(typeof) == "function" then
            local ty = typeof(v)
            if ty == "CFrame" then
                local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = v:GetComponents()
                return { __type = "CFrame", X = x, Y = y, Z = z,
                    R00 = R00, R01 = R01, R02 = R02,
                    R10 = R10, R11 = R11, R12 = R12,
                    R20 = R20, R21 = R21, R22 = R22 }
            elseif ty == "Vector3" then
                return { __type = "Vector3", X = v.X, Y = v.Y, Z = v.Z }
            elseif ty == "Color3" then
                return { __type = "Color3", R = v.R, G = v.G, B = v.B }
            elseif ty == "EnumItem" then
                return { __type = "EnumItem", EnumType = tostring(v.EnumType), Name = tostring(v.Name) }
            end
        end
        return nil
    end

    local function decode(v)
        if type(v) ~= "table" then return v end
        if type(v.__type) == "string" then
            local ty = v.__type
            if ty == "CFrame" then
                return CFrame.new(
                    tonumber(v.X) or 0, tonumber(v.Y) or 0, tonumber(v.Z) or 0,
                    tonumber(v.R00) or 1, tonumber(v.R01) or 0, tonumber(v.R02) or 0,
                    tonumber(v.R10) or 0, tonumber(v.R11) or 1, tonumber(v.R12) or 0,
                    tonumber(v.R20) or 0, tonumber(v.R21) or 0, tonumber(v.R22) or 1
                )
            elseif ty == "Vector3" then
                return Vector3.new(tonumber(v.X) or 0, tonumber(v.Y) or 0, tonumber(v.Z) or 0)
            elseif ty == "Color3" then
                return Color3.new(tonumber(v.R) or 0, tonumber(v.G) or 0, tonumber(v.B) or 0)
            elseif ty == "EnumItem" then
                return Enum[v.EnumType] and Enum[v.EnumType][v.Name] or nil
            end
            return nil
        end
        local out = {}
        if isArray(v) then
            for i = 1, #v do out[i] = decode(v[i]) end
        else
            for k, val in pairs(v) do out[k] = decode(val)
            end
        end
        return out
    end

    ---------------------------------------------------------------------
    -- INDEX (ls + discover)
    ---------------------------------------------------------------------
    local index = { profiles = {}, current = nil, autoLoad = nil }

    local function normalizeList(list)
        local out = {}
        local seen = {}
        if type(list) == "table" then
            for _, name in ipairs(list) do
                if type(name) == "string" and name ~= "" and not seen[slugOf(name)] then
                    seen[slugOf(name)] = true
                    table.insert(out, name)
                end
            end
        end
        return out
    end

    local function loadIndex()
        index = { profiles = {}, current = nil, autoLoad = nil }
        local raw = readFile(indexPath())
        if raw and raw ~= "" then
            local ok, obj = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(obj) == "table" and obj.__format == FORMAT then
                index.profiles = normalizeList(obj.profiles)
                index.current = (type(obj.current) == "string") and obj.current or nil
                index.autoLoad = (type(obj.autoLoad) == "string") and obj.autoLoad or nil
                return
            end
        end
        -- fallback to memory index
        index.profiles = normalizeList(memoryIndex.profiles)
        index.current = memoryIndex.current
        index.autoLoad = memoryIndex.autoLoad
    end

    local function persistIndex()
        local payload = HttpService:JSONEncode({
            __format = FORMAT,
            version = VERSION,
            profiles = index.profiles,
            current = index.current,
            autoLoad = index.autoLoad,
        })
        writeFile(indexPath(), payload)
        memoryIndex.profiles = index.profiles
        memoryIndex.current = index.current
        memoryIndex.autoLoad = index.autoLoad
    end

    local function discoverFromDisk()
        if not (hasFS and hasList) then return end
        pcall(function()
            local files = listfiles(FOLDER)
            if type(files) ~= "table" then return end
            local known = {}
            for _, n in ipairs(index.profiles) do known[slugOf(n)] = true end
            for _, path in ipairs(files) do
                if type(path) == "string" then
                    local base = path:match("([^/\\]+)%.json$")
                    if base and base ~= "index" and not known[base] then
                        local raw = readFile(FOLDER .. "/" .. base .. ".json")
                        local display = nil
                        if raw and raw ~= "" then
                            local ok, obj = pcall(function() return HttpService:JSONDecode(raw) end)
                            if ok and type(obj) == "table" and type(obj.name) == "string" and obj.name ~= "" then
                                display = obj.name
                            end
                        end
                        display = display or base
                        table.insert(index.profiles, display)
                        known[slugOf(display)] = true
                    end
                end
            end
        end)
    end

    local function findStoredName(name)
        if type(name) ~= "string" then return nil end
        local target = slugOf(name)
        for _, n in ipairs(index.profiles) do
            if slugOf(n) == target then return n end
        end
        return nil
    end

    ---------------------------------------------------------------------
    -- COLLECTOR / APPLIER
    ---------------------------------------------------------------------
    -- The collector gathers all editable settings into a plain table.
    local function collectSettings()
        local data = {
            Fishing = {
                AutoFish = ctx.config.Fishing.AutoFish,
                StreakProtection = ctx.config.Fishing.StreakProtection,
                StreakThreshold = ctx.config.Fishing.StreakThreshold,
                AutoSellFish = ctx.config.Fishing.AutoSellFish,
                SellAtCount = ctx.config.Fishing.SellAtCount,
                ProtectedFish = {},
                LockedSpot = ctx.config.Fishing.LockedSpot,
            },
            Mining = {
                AutoMine = ctx.config.Mining.AutoMine,
                MaxDistance = ctx.config.Mining.MaxDistance,
                AutoSellCrystals = ctx.config.Mining.AutoSellCrystals,
                SellEveryX = ctx.config.Mining.SellEveryX,
                SellCooldown = ctx.config.Mining.SellCooldown,
                SellCategory = ctx.config.Mining.SellCategory,
            },
            Misc = {
                Fly = ctx.config.Misc.Fly,
                FlySpeed = ctx.config.Misc.FlySpeed,
                WalkSpeed = ctx.config.Misc.WalkSpeed,
                WalkSpeedEnabled = ctx.config.Misc.WalkSpeedEnabled,
                Noclip = ctx.config.Misc.Noclip,
            },
        }

        -- Protected fish list — prefer live module getter when available.
        pcall(function()
            if fishingMod and type(fishingMod.getProtectedFish) == "function" then
                data.Fishing.ProtectedFish = fishingMod.getProtectedFish()
            else
                data.Fishing.ProtectedFish = ctx.config.Fishing.ProtectedFish or {}
            end
        end)
        -- Locked spot — prefer live module getter when available.
        pcall(function()
            if fishingMod and type(fishingMod.getLockedSpot) == "function" then
                data.Fishing.LockedSpot = fishingMod.getLockedSpot()
            end
        end)
        return data
    end

    -- The applier writes a loaded table back into ctx.config + live modules.
    local function applySettings(data)
        if type(data) ~= "table" then return false, "Invalid data" end

        local function safeNum(v, default)
            local n = tonumber(v)
            return (n and n > 0) and n or default
        end

        -- Mining
        if data.Mining then
            ctx.config.Mining.AutoMine = data.Mining.AutoMine and true or false
            ctx.config.Mining.MaxDistance = safeNum(data.Mining.MaxDistance, ctx.config.Mining.MaxDistance)
            ctx.config.Mining.AutoSellCrystals = data.Mining.AutoSellCrystals and true or false
            ctx.config.Mining.SellEveryX = math.max(1, math.floor(safeNum(data.Mining.SellEveryX, ctx.config.Mining.SellEveryX)))
            ctx.config.Mining.SellCooldown = safeNum(data.Mining.SellCooldown, ctx.config.Mining.SellCooldown)
            if data.Mining.SellCategory then
                ctx.config.Mining.SellCategory = data.Mining.SellCategory
            end
            pcall(function()
                if miningMod then
                    miningMod.applySettings(data.Mining)
                end
            end)
        end

        -- Misc
        if data.Misc then
            ctx.config.Misc.Fly = data.Misc.Fly and true or false
            ctx.config.Misc.FlySpeed = safeNum(data.Misc.FlySpeed, ctx.config.Misc.FlySpeed)
            ctx.config.Misc.WalkSpeed = safeNum(data.Misc.WalkSpeed, ctx.config.Misc.WalkSpeed)
            ctx.config.Misc.WalkSpeedEnabled = data.Misc.WalkSpeedEnabled and true or false
            ctx.config.Misc.Noclip = data.Misc.Noclip and true or false
            pcall(function()
                if miscMod then
                    miscMod.applySettings(data.Misc)
                end
            end)
        end

        -- Fishing
        if data.Fishing then
            ctx.config.Fishing.AutoFish = data.Fishing.AutoFish and true or false
            ctx.config.Fishing.StreakProtection = data.Fishing.StreakProtection and true or false
            ctx.config.Fishing.StreakThreshold = safeNum(data.Fishing.StreakThreshold, ctx.config.Fishing.StreakThreshold)
            ctx.config.Fishing.AutoSellFish = data.Fishing.AutoSellFish and true or false
            ctx.config.Fishing.SellAtCount = math.max(1, math.floor(safeNum(data.Fishing.SellAtCount, ctx.config.Fishing.SellAtCount)))
            if type(data.Fishing.ProtectedFish) == "table" then
                ctx.config.Fishing.ProtectedFish = data.Fishing.ProtectedFish
            end
            pcall(function()
                if fishingMod then
                    fishingMod.applySettings(data.Fishing)
                end
            end)
        end

        return true
    end

    ---------------------------------------------------------------------
    -- PROFILE CRUD
    ---------------------------------------------------------------------
    local function writeProfile(name, data)
        local clean, err = sanitizeName(name)
        if not clean then return false, err end
        local payload = HttpService:JSONEncode({
            __format = FORMAT,
            version = VERSION,
            name = clean,
            savedAt = os.time(),
            data = encode(data or {}),
        })
        local ok = writeFile(filePath(clean), payload)
        if ok then
            if not findStoredName(clean) then
                table.insert(index.profiles, clean)
            end
            index.current = clean
            persistIndex()
        end
        return ok, clean
    end

    local function readProfile(name)
        local raw = readFile(filePath(name))
        if not raw or raw == "" then return nil, "Profile not found" end
        local ok, obj = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok or type(obj) ~= "table" then return nil, "Corrupted JSON" end
        if obj.__format ~= FORMAT then return nil, "Unrecognised format" end
        return obj.data, obj.name
    end

    local function saveProfile(name, data)
        data = data or collectSettings()
        return writeProfile(name, data)
    end

    local function loadProfile(name)
        local stored = findStoredName(name)
        if not stored then return nil, "Profile not found" end
        local data, _ = readProfile(stored)
        if not data then return nil, "Failed to read profile" end
        if applySettings(data) then
            index.current = stored
            persistIndex()
            return data, stored
        end
        return nil, "Failed to apply settings"
    end

    local function deleteProfile(name)
        local stored = findStoredName(name)
        if not stored then return false, "Profile not found" end
        removeFile(filePath(stored))
        for i, n in ipairs(index.profiles) do
            if n == stored then table.remove(index.profiles, i); break end
        end
        if index.current and slugOf(index.current) == slugOf(stored) then index.current = nil end
        if index.autoLoad and slugOf(index.autoLoad) == slugOf(stored) then index.autoLoad = nil end
        persistIndex()
        return true, nil
    end

    local function setAutoload(name)
        if name == nil or name == "" then
            index.autoLoad = nil
            persistIndex()
            return true, nil
        end
        local stored = findStoredName(name)
        if not stored then return false, "Profile not found" end
        index.autoLoad = stored
        persistIndex()
        return true, nil
    end

    local function listProfiles()
        local out = {}
        for _, n in ipairs(index.profiles) do
            table.insert(out, n)
        end
        table.sort(out, function(a, b) return a:lower() < b:lower() end)
        return out
    end

    ---------------------------------------------------------------------
    -- UI BUILD
    ---------------------------------------------------------------------
    local function buildUI()
        if not page then return end
        gui.components.createSectionLabel(page.container, "Profile Management")
        profileNameInput = gui.components.createTextbox(page.container, "Profile Name", "My Profile")
        gui.components.createButton(page.container, "Save Profile", function()
            local name = profileNameInput.text()
            local ok, res = saveProfile(name)
            if ok then
                statusLabel.Text = "Saved: " .. res
                ctx.log("Profile saved: " .. res, THEME.success)
                refreshDropdown()
            else
                statusLabel.Text = "Save failed: " .. tostring(res)
                ctx.log("Profile save failed: " .. tostring(res), THEME.danger)
            end
        end)
        savedDropdown = gui.components.createDropdown(page.container, "Saved Profiles", {"(empty)"}, nil, function(_) end)
        gui.components.createButton(page.container, "Load Profile", function()
            local name = savedDropdown.get()
            if name == "(empty)" then return end
            local data, err = loadProfile(name)
            if data then
                statusLabel.Text = "Loaded: " .. err
                ctx.log("Profile loaded: " .. err, THEME.success)
            else
                statusLabel.Text = "Load failed: " .. tostring(err)
                ctx.log("Profile load failed: " .. tostring(err), THEME.danger)
            end
        end)
        gui.components.createButton(page.container, "Delete Profile", function()
            local name = savedDropdown.get()
            if name == "(empty)" then return end
            local ok, err = deleteProfile(name)
            if ok then
                statusLabel.Text = "Deleted: " .. name
                ctx.log("Profile deleted: " .. name, THEME.success)
                refreshDropdown()
            else
                statusLabel.Text = "Delete failed: " .. tostring(err)
            end
        end)
        autoloadToggle = gui.components.createToggle(page.container, "Autoload Profile", false, function(val)
            if val then
                setAutoload(autoloadSelector and autoloadSelector.get() or nil)
            else
                setAutoload(nil)
            end
        end)
        autoloadSelector = gui.components.createDropdown(page.container, "Autoload Profile", {"(none)"}, nil, function(opt)
            if opt and opt ~= "(none)" then
                setAutoload(opt)
                if autoloadToggle then autoloadToggle.set(true) end
            end
        end)
        gui.components.createButton(page.container, "Refresh Profiles", function()
            refreshDropdown()
            statusLabel.Text = "Profiles refreshed."
        end)
        gui.components.createSectionLabel(page.container, "")
        statusLabel = gui.components.createSectionLabel(page.container, "")
    end

    local function refreshDropdown()
        local profiles = listProfiles()
        if #profiles == 0 then
            savedDropdown.set("(empty)")
            savedDropdown.setOptions({"(empty)"})
            autoloadSelector.set("(none)")
            autoloadSelector.setOptions({"(none)"})
        else
            savedDropdown.set(profiles[1])
            savedDropdown.setOptions(profiles)
            local opts = { "(none)" }
            for _, p in ipairs(profiles) do table.insert(opts, p) end
            autoloadSelector.setOptions(opts)
            autoloadSelector.set(index.autoLoad or "(none)")
        end
        if autoloadToggle then
            autoloadToggle.set(index.autoLoad ~= nil)
        end
    end

    ---------------------------------------------------------------------
    -- INIT
    ---------------------------------------------------------------------
    local function Init()
        buildUI()
        loadIndex()
        discoverFromDisk()
        persistIndex()
        refreshDropdown()

        -- Autoload selected profile on startup (after feature modules have had
        -- a chance to register their applySettings functions).
        if index.autoLoad then
            task.defer(function()
                task.wait(1.5) -- let feature modules initialize first
                local stored = findStoredName(index.autoLoad)
                if stored then
                    local data, err = loadProfile(stored)
                    if data then
                        ctx.log("Autoloaded profile: " .. err, THEME.success)
                        if statusLabel then statusLabel.Text = "Autoloaded: " .. err end
                    else
                        ctx.log("Autoload failed: " .. tostring(err), THEME.danger)
                        if statusLabel then statusLabel.Text = "Autoload failed: " .. tostring(err) end
                    end
                else
                    setAutoload(nil)
                end
            end)
        end
    end

    ---------------------------------------------------------------------
    -- PUBLIC API
    ---------------------------------------------------------------------
    local Settings = {
        Init = Init,
        Start = function() end,
        Stop = function() end,
        Destroy = function() end,
        collectSettings = collectSettings,
        applySettings = applySettings,
        saveProfile = saveProfile,
        loadProfile = loadProfile,
        deleteProfile = deleteProfile,
        listProfiles = listProfiles,
        setAutoload = setAutoload,
        getAutoload = function() return index.autoLoad end,
        refreshDropdown = refreshDropdown,
    }

    return Settings
end