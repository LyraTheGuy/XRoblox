-- IndoVoice/modules/SettingsProfiles.lua
-- ============================================================================
-- SAVED SETTINGS PROFILES
-- ============================================================================
-- Named snapshots of every user-configurable setting (Auto Fish, Auto Mine,
-- camera / player settings, auto TP, clicker, keybinds, delays, feature
-- toggles, zones, target players, ...). Loadable on its own and reusable by
-- any other module:  local SettingsProfiles = factory(config)
--
-- This file only holds STORAGE logic: listing, creating, saving, loading,
-- renaming, deleting, validation and (versioned) serialization. It knows
-- nothing about the UI or about individual features:
--   * the Settings-menu UI lives in gui.lua
--   * the "read current settings" / "apply loaded settings" integration is
--     registered from modules/settingsintegration.lua via SetCollector().
--
-- Storage backends (best effort, most durable first, graceful fallback):
--   1. executor filesystem  ->  <Folder>/<slug>.json  (+ index.json)
--   2. getgenv() shared table (survives re-execution in the SAME session)
--   3. in-memory table (this VM only — never persists a restart)
--
-- Versioned on-disk format (safe to extend later):
--   {
--     "__format": "LyraHubProfile",
--     "version": 1,
--     "name": "My Profile",
--     "savedAt": 1712345678,
--     "data": { ...settings... }
--   }
--
-- Public API:
--   List()                  -> { "A", "B", ... }             (sorted)
--   Exists(name)            -> boolean
--   Count()                 -> number
--   GetCurrent()            -> name | nil
--   SetCurrent(name)        -> ok, err
--   Create(name)            -> ok, err
--   Save(name, data?)       -> ok, err     (data defaults to collector)
--   Load(name)              -> data, name  (nil, err on failure)
--   Rename(oldName, newName)-> ok, err
--   Delete(name)            -> ok, err     (refuses the active profile)
--   SetCollector(fn)        -> registers fn() -> current settings table
--   GetRaw(name)            -> data, err   (read without setting current)
-- ============================================================================

return function(config)
    config = config or {}
    local PROFILES = config.Profiles or {}
    local FOLDER = PROFILES.Folder or "LyraHubProfiles"
    local FORMAT = PROFILES.Format or "LyraHubProfile"
    local VERSION = tonumber(PROFILES.Version) or 1
    local MAX_NAME = tonumber(PROFILES.MaxNameLength) or 24
    local MAX_PROFILES = tonumber(PROFILES.MaxProfiles) or 50
    local DEFAULT_NAME = PROFILES.DefaultName or "Default"

    local HttpService = game:GetService("HttpService")

    -- ------------------------------------------------------------------
    -- Executor capability detection (pcall-wrapped so a missing global on
    -- any executor degrades gracefully instead of crashing the script)
    -- ------------------------------------------------------------------
    local hasFS = pcall(function()
        assert(type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")
    end)

    local hasList = pcall(function()
        assert(type(listfiles) == "function")
    end)

    local hasDelete = pcall(function()
        assert(type(delfile) == "function")
    end)

    local genv = nil
    pcall(function()
        if type(getgenv) == "function" then
            local g = getgenv()
            if type(g) == "table" then genv = g end
        end
    end)

    -- Last-resort in-memory fallback (this VM only).
    local memory = { profiles = {}, current = nil }

    -- ------------------------------------------------------------------
    -- (DE)SERIALIZATION
    -- ------------------------------------------------------------------
    -- Roblox datatypes can't be JSON-encoded directly, so tables are walked
    -- and special values are tagged. Decoding restores them. Unknown types
    -- are dropped (never crash). This also makes the format future-proof:
    -- new settings of any supported type persist without code changes.
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
            if ty == "Color3" then
                return { __type = "Color3", R = v.R, G = v.G, B = v.B }
            elseif ty == "Vector3" then
                return { __type = "Vector3", X = v.X, Y = v.Y, Z = v.Z }
            elseif ty == "Vector2" then
                return { __type = "Vector2", X = v.X, Y = v.Y }
            elseif ty == "EnumItem" then
                return { __type = "EnumItem", EnumType = tostring(v.EnumType), Name = tostring(v.Name) }
            end
        end
        return nil -- unsupported value (function / Instance / ...) — dropped
    end

    local function decode(v)
        if type(v) ~= "table" then
            return v
        end
        if type(v.__type) == "string" then
            local ty = v.__type
            if ty == "Color3" then
                return Color3.new(tonumber(v.R) or 0, tonumber(v.G) or 0, tonumber(v.B) or 0)
            elseif ty == "Vector3" then
                return Vector3.new(tonumber(v.X) or 0, tonumber(v.Y) or 0, tonumber(v.Z) or 0)
            elseif ty == "Vector2" then
                return Vector2.new(tonumber(v.X) or 0, tonumber(v.Y) or 0)
            elseif ty == "EnumItem" then
                return Enum[v.EnumType] and Enum[v.EnumType][v.Name] or nil
            end
            return nil
        end
        local out = {}
        if isArray(v) then
            for i = 1, #v do out[i] = decode(v[i]) end
        else
            for k, val in pairs(v) do out[k] = decode(val) end
        end
        return out
    end

    -- ------------------------------------------------------------------
    -- PATH / NAME HELPERS
    -- ------------------------------------------------------------------
    local function sanitizeName(name)
        if type(name) ~= "string" then return nil, "Invalid name" end
        name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
        if name == "" then return nil, "Name cannot be empty" end
        if #name > MAX_NAME then
            name = name:sub(1, MAX_NAME)
        end
        return name, nil
    end

    local function slugOf(name)
        local s = tostring(name):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
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
            if isfile(path) then
                return readfile(path)
            end
            return nil
        end)
        if ok then return content end
        return nil
    end

    local function writeFile(path, data)
        if not hasFS then return false end
        ensureFolder()
        local ok = pcall(function() writefile(path, data) end)
        return ok
    end

    local function removeFile(path)
        if not hasFS or not hasDelete then return false end
        return pcall(function()
            if isfile(path) then delfile(path) end
        end)
    end

    -- ------------------------------------------------------------------
    -- IN-MEMORY INDEX (profiles + current) with multi-backend persistence
    -- ------------------------------------------------------------------
    local index = { profiles = {}, current = nil }

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
        index = { profiles = {}, current = nil }

        -- 1) Filesystem index
        local raw = readFile(indexPath())
        if raw and raw ~= "" then
            local ok, obj = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(obj) == "table" and obj.__format == FORMAT then
                index.profiles = normalizeList(obj.profiles)
                index.current = (type(obj.current) == "string") and obj.current or nil
                return
            end
        end

        -- 2) getgenv fallback
        if genv and type(genv.__LyraHubProfiles) == "table" then
            local g = genv.__LyraHubProfiles
            index.profiles = normalizeList(g.profiles)
            index.current = (type(g.current) == "string") and g.current or nil
            return
        end

        -- 3) In-memory fallback
        index.profiles = normalizeList(memory.profiles)
        index.current = memory.current
    end

    local function persistIndex()
        local payload = HttpService:JSONEncode({
            __format = FORMAT,
            version = VERSION,
            profiles = index.profiles,
            current = index.current,
        })
        writeFile(indexPath(), payload)
        pcall(function()
            if genv then
                genv.__LyraHubProfiles = {
                    version = VERSION,
                    profiles = index.profiles,
                    current = index.current,
                }
            end
        end)
        memory.profiles = index.profiles
        memory.current = index.current
    end

    -- Discover profile files on disk and merge them into the index, so a
    -- freshly-copied profile file shows up even if index.json is missing.
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
                        -- Prefer the display name stored inside the file.
                        local raw = readFile(FOLDER .. "/" .. base .. ".json")
                        local display = nil
                        if raw and raw ~= "" then
                            local ok, obj = pcall(function() return HttpService:JSONDecode(raw) end)
                            if ok and type(obj) == "table" and type(obj.name) == "string" and obj.name ~= "" then
                                display = obj.name
                            end
                        end
                        display = display or base
                        if not index.profiles then index.profiles = {} end
                        table.insert(index.profiles, display)
                        known[slugOf(display)] = true
                    end
                end
            end
        end)
    end

    local function findStoredName(name)
        if type(name) ~= "string" then return nil end
        -- Compare by slug: two display names that map to the same file are the
        -- same profile (prevents on-disk collisions / overwrites).
        local target = slugOf(name)
        for _, n in ipairs(index.profiles) do
            if slugOf(n) == target then return n end
        end
        return nil
    end

    -- ------------------------------------------------------------------
    -- PROFILE FILE (de)serialization
    -- ------------------------------------------------------------------
    local collector = nil

    local function encodeProfile(name, data)
        return HttpService:JSONEncode({
            __format = FORMAT,
            version = VERSION,
            name = name,
            savedAt = os.time(),
            data = encode(data or {}),
        })
    end

    local function decodeProfile(raw)
        if type(raw) ~= "string" or raw == "" then
            return nil, "Profile file is empty"
        end
        local ok, obj = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok or type(obj) ~= "table" then
            return nil, "Profile data is corrupted"
        end
        if obj.__format ~= FORMAT then
            return nil, "Unrecognised profile format"
        end
        local v = tonumber(obj.version) or 0
        if v > VERSION then
            return nil, "Profile was saved by a newer version (" .. tostring(v) .. ")"
        end
        local data = decode(obj.data)
        if type(data) ~= "table" then data = {} end
        return { name = obj.name, version = v, savedAt = obj.savedAt, data = data }, nil
    end

    local function readProfile(name)
        local raw = readFile(filePath(name))
        if not raw then
            -- getgenv fallback
            if genv and type(genv.__LyraHubProfileData) == "table" then
                local entry = genv.__LyraHubProfileData[slugOf(name)]
                if entry then return entry, nil end
            end
            -- memory fallback
            if memory.profilesData and memory.profilesData[slugOf(name)] then
                return memory.profilesData[slugOf(name)], nil
            end
            return nil, "Profile not found"
        end
        return decodeProfile(raw)
    end

    local function writeProfile(name, data)
        local payload = encodeProfile(name, data)
        local wrote = writeFile(filePath(name), payload)
        pcall(function()
            if genv then
                genv.__LyraHubProfileData = genv.__LyraHubProfileData or {}
                genv.__LyraHubProfileData[slugOf(name)] = { name = name, data = data }
            end
        end)
        memory.profilesData = memory.profilesData or {}
        memory.profilesData[slugOf(name)] = { name = name, data = data }
        return wrote
    end

    local function deleteProfileFile(name)
        removeFile(filePath(name))
        pcall(function()
            if genv and type(genv.__LyraHubProfileData) == "table" then
                genv.__LyraHubProfileData[slugOf(name)] = nil
            end
        end)
        if memory.profilesData then
            memory.profilesData[slugOf(name)] = nil
        end
    end

    -- ------------------------------------------------------------------
    -- PUBLIC API
    -- ------------------------------------------------------------------
    local SettingsProfiles = {}

    -- Boot: load + discover the index once.
    loadIndex()
    discoverFromDisk()
    persistIndex()

    function SettingsProfiles.List()
        local out = {}
        for _, n in ipairs(index.profiles) do
            table.insert(out, n)
        end
        table.sort(out, function(a, b) return a:lower() < b:lower() end)
        return out
    end

    function SettingsProfiles.Count()
        return #index.profiles
    end

    function SettingsProfiles.Exists(name)
        return findStoredName(name) ~= nil
    end

    function SettingsProfiles.GetCurrent()
        if index.current and findStoredName(index.current) then
            return findStoredName(index.current)
        end
        return nil
    end

    function SettingsProfiles.SetCurrent(name)
        local stored = findStoredName(name)
        if not stored then
            return false, "Profile '" .. tostring(name) .. "' does not exist"
        end
        index.current = stored
        persistIndex()
        return true, nil
    end

    function SettingsProfiles.Create(name)
        local clean, err = sanitizeName(name)
        if not clean then return false, err end
        if findStoredName(clean) then
            return false, "A profile named '" .. clean .. "' already exists"
        end
        if #index.profiles >= MAX_PROFILES then
            return false, "Profile limit reached (" .. MAX_PROFILES .. ")"
        end
        table.insert(index.profiles, clean)
        writeProfile(clean, {})
        index.current = clean
        persistIndex()
        return true, nil
    end

    -- Register the function that returns the CURRENT settings snapshot.
    function SettingsProfiles.SetCollector(fn)
        collector = (type(fn) == "function") and fn or nil
    end

    function SettingsProfiles.Save(name, data)
        local clean, err = sanitizeName(name)
        if not clean then return false, err end
        if type(data) ~= "table" then
            if collector then
                local ok, result = pcall(collector)
                if ok and type(result) == "table" then
                    data = result
                end
            end
        end
        if type(data) ~= "table" then
            return false, "No settings available to save"
        end
        if not findStoredName(clean) then
            if #index.profiles >= MAX_PROFILES then
                return false, "Profile limit reached (" .. MAX_PROFILES .. ")"
            end
            table.insert(index.profiles, clean)
        else
            clean = findStoredName(clean) -- keep the original casing
        end
        writeProfile(clean, data)
        index.current = clean
        persistIndex()
        return true, nil
    end

    -- Load returns the decoded settings table (integration applies it).
    function SettingsProfiles.Load(name)
        local stored = findStoredName(name)
        if not stored then
            return nil, "Profile '" .. tostring(name) .. "' does not exist"
        end
        local profile, err = readProfile(stored)
        if not profile then
            return nil, err or "Failed to read profile"
        end
        index.current = stored
        persistIndex()
        return profile.data, stored
    end

    function SettingsProfiles.GetRaw(name)
        local stored = findStoredName(name)
        if not stored then return nil, "Profile not found" end
        local profile, err = readProfile(stored)
        if not profile then return nil, err end
        return profile.data, stored
    end

    function SettingsProfiles.Rename(oldName, newName)
        local storedOld = findStoredName(oldName)
        if not storedOld then
            return false, "Profile '" .. tostring(oldName) .. "' does not exist"
        end
        local cleanNew, err = sanitizeName(newName)
        if not cleanNew then return false, err end
        if cleanNew:lower() == storedOld:lower() then
            return true, nil -- no-op rename to the same name
        end
        if slugOf(cleanNew) == slugOf(storedOld) then
            -- Same underlying file — just update the display name.
            local sameProfile = readProfile(storedOld)
            writeProfile(cleanNew, (sameProfile and sameProfile.data) or {})
            for i, n in ipairs(index.profiles) do
                if n == storedOld then
                    index.profiles[i] = cleanNew
                    break
                end
            end
            if index.current and slugOf(index.current) == slugOf(storedOld) then
                index.current = cleanNew
            end
            persistIndex()
            return true, nil
        end
        if findStoredName(cleanNew) then
            return false, "A profile named '" .. cleanNew .. "' already exists"
        end

        -- Move the data across, then drop the old entry.
        local profile = readProfile(storedOld)
        local data = (profile and profile.data) or {}
        writeProfile(cleanNew, data)
        deleteProfileFile(storedOld)

        for i, n in ipairs(index.profiles) do
            if n == storedOld then
                index.profiles[i] = cleanNew
                break
            end
        end
        if index.current and slugOf(index.current) == slugOf(storedOld) then
            index.current = cleanNew
        end
        persistIndex()
        return true, nil
    end

    function SettingsProfiles.Delete(name)
        local stored = findStoredName(name)
        if not stored then
            return false, "Profile '" .. tostring(name) .. "' does not exist"
        end
        if index.current and slugOf(index.current) == slugOf(stored) then
            return false, "Cannot delete the active profile — switch to another first"
        end
        deleteProfileFile(stored)
        for i, n in ipairs(index.profiles) do
            if n == stored then
                table.remove(index.profiles, i)
                break
            end
        end
        persistIndex()
        return true, nil
    end

    -- Encoded signature of a settings table (or of the current snapshot) — the
    -- UI uses this to detect unsaved changes without duplicating the encoder.
    function SettingsProfiles.Signature(data)
        if type(data) ~= "table" then
            if not collector then return nil end
            local ok, result = pcall(collector)
            if not ok or type(result) ~= "table" then return nil end
            data = result
        end
        local ok, str = pcall(function() return HttpService:JSONEncode(encode(data)) end)
        return ok and str or nil
    end

    -- Expose a couple of internals for debugging / other modules.
    SettingsProfiles.Slug = slugOf
    SettingsProfiles.Path = filePath

    return SettingsProfiles
end
