-- IndoHangout/bootstrap.lua
-- Small loader: fetches main.lua from the local project URL and runs it.
-- The BASE_URL is passed as vararg so main.lua receives it via `...`.

local function fetch(url, name)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or not result or result == "404: Not Found" or result == "Not Found" then
        error("Failed to fetch " .. tostring(name) .. " from " .. tostring(url))
    end
    return result
end

local function compile(source, name)
    local fn, err = loadstring(source)
    if not fn then
        error("Failed to compile " .. tostring(name) .. ": " .. tostring(err))
    end
    return fn
end

-- The URL where this bootstrap was loaded from (works when pasted from an
-- external executor's hosted file). If loaded from a local file, use the
-- provided BASE_URL constant.
local BASE_URL = (...) or "http://localhost/IndoHangout/"

local mainChunk = compile(fetch(BASE_URL .. "main.lua", "main.lua"), "main.lua")
mainChunk(BASE_URL)
