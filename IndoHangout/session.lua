-- IndoHangout/session.lua
-- Lightweight persistent session: small key/value blobs stored per place.
-- Used for the autoload profile index; NOT for profile data itself (that
-- lives in modules/settings.lua). Multi-backend: filesystem -> getgenv -> memory.

return function(config)
    local SESSION_FOLDER = (config and config.Session and config.Session.Folder) or "IndoHangoutSession"

    local hasFS = pcall(function()
        assert(type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")
    end)

    local genv = nil
    pcall(function()
        if type(getgenv) == "function" then
            local g = getgenv()
            if type(g) == "table" then genv = g end
        end
    end)

    local memory = {}

    local function jsonEncode(tbl)
        local parts = {}
        for k, v in pairs(tbl) do
            local key = tostring(k):gsub('"', '\\"')
            if type(v) == "number" then
                table.insert(parts, ('"%s":%s'):format(key, tostring(v)))
            elseif type(v) == "boolean" then
                table.insert(parts, ('"%s":%s'):format(key, tostring(v)))
            elseif type(v) == "string" then
                local val = v:gsub("\\", "\\\\"):gsub('"', '\\"')
                table.insert(parts, ('"%s":"%s"'):format(key, val))
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end

    local function jsonDecode(str)
        -- Decode via a simple key/value scanner (mirrors IndoVoice session.lua).
        if type(str) ~= "string" or str == "" then return {} end
        local out = {}
        pcall(function()
            for key, val in str:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
                val = val:gsub("^%s+", ""):gsub("%s+$", "")
                if val:sub(1, 1) == '"' then
                    out[key] = val:sub(2, -2):gsub('\\"', '"'):gsub("\\\\", "\\")
                elseif val == "true" then
                    out[key] = true
                elseif val == "false" then
                    out[key] = false
                else
                    local n = tonumber(val)
                    out[key] = n
                end
            end
        end)
        return out
    end

    local function filePath(key)
        return SESSION_FOLDER .. "/" .. tostring(key) .. ".json"
    end

    local function readFromFS(key)
        if not hasFS then return nil end
        local ok, content = pcall(function()
            if isfile(filePath(key)) then
                return readfile(filePath(key))
            end
            return nil
        end)
        if ok then return content end
        return nil
    end

    local function writeToFS(key, data)
        if not hasFS then return false end
        pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" then
                if not isfolder(SESSION_FOLDER) then makefolder(SESSION_FOLDER) end
            end
        end)
        return pcall(function()
            writefile(filePath(key), jsonEncode(data))
        end)
    end

    local Session = {}

    function Session.Get(key, default)
        local data = nil
        local raw = readFromFS(key)
        if raw and raw ~= "" then
            data = jsonDecode(raw)
        end
        if (not data or not next(data)) and genv and type(genv.__IndoHangoutSession) == "table" then
            data = genv.__IndoHangoutSession[key]
        end
        if (not data or not next(data)) then
            data = memory[key]
        end
        if not data then
            return default
        end
        return data.value or data
    end

    function Session.Set(key, value)
        local data = { value = value, timestamp = os.time() }
        writeToFS(key, data)
        pcall(function()
            if genv then
                genv.__IndoHangoutSession = genv.__IndoHangoutSession or {}
                genv.__IndoHangoutSession[key] = data
            end
        end)
        memory[key] = data
        return true
    end

    function Session.Delete(key)
        pcall(function()
            if hasFS and isfile(filePath(key)) and type(delfile) == "function" then
                delfile(filePath(key))
            end
        end)
        pcall(function()
            if genv and genv.__IndoHangoutSession then
                genv.__IndoHangoutSession[key] = nil
            end
        end)
        memory[key] = nil
        return true
    end

    return Session
end