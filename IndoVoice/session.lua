-- IndoVoice/session.lua
-- ============================================================================
-- PERSISTENT SESSION (PASSWORD BYPASS + AUTO RE-EXECUTION HELPERS)
-- ============================================================================
-- PURPOSE:
--   Remembers (per game place) that the user already typed the gate password
--   once. On every rejoin / server hop inside the SAME place, the gate is
--   bypassed and the script auto-executes without asking for the password.
--
-- HOW IT WORKS (in order of preference, best-effort with graceful fallback):
--   1. writefile/readfile/isfile  — executor filesystem (Synapse, KRNL, etc.)
--      Stores a flat key/value blob in `IndoVoiceSession/<placeId>.json`.
--   2. getgenv() shared table     — in-memory fallback, survives re-execution
--      within the SAME Roblox session (e.g. reconnect after a disconnect).
--   3. Plain Lua table            — last-resort fallback (never crashes; the
--      gate simply asks for the password again on the next full restart).
--
-- The returned factory is called as:  local Session = factory(config)
-- ============================================================================

return function(config)
	local Players = game:GetService("Players")

	-- Folder inside the executor workspace where session files live.
	local SESSION_FOLDER = "IndoVoiceSession"

	-- How long a saved session stays valid (seconds). 7 days by default.
	-- After expiry the gate asks for the password again (safety measure).
	local SESSION_TTL = (config and config.Gate and config.Gate.SessionTTL) or (7 * 24 * 60 * 60)

	-- ---------------------------------------------------------------
	-- Executor capability detection (all pcall-wrapped so missing
	-- globals on any executor never crash the script)
	-- ---------------------------------------------------------------
	local hasFS = pcall(function()
		assert(type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")
	end)

	local genv = nil
	pcall(function()
		if type(getgenv) == "function" then
			genv = getgenv()
			if type(genv) ~= "table" then genv = nil end
		end
	end)

	-- Last-resort in-memory fallback (per VM instance only).
	local memoryStore = {}

	-- ---------------------------------------------------------------
	-- Serialization: flat string/number/boolean tables only.
	-- A tiny hand-rolled encoder + matcher-based decoder keeps this
	-- dependency-free and crash-proof.
	-- ---------------------------------------------------------------
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
			-- NOTE: nested tables / nil / Roblox datatypes are not supported.
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end

	local KEYS = { "authenticated", "timestamp", "placeId", "userId", "playerName" }

	local function parseSession(str)
		local out = {}
		if type(str) ~= "string" then return out end
		pcall(function()
			for _, key in ipairs(KEYS) do
				local pat = '"' .. key .. '"%s*:%s*'
				local s = str:match(pat .. '"(.-)"')          -- string value
				if s ~= nil then
					out[key] = s:gsub('\\"', '"'):gsub("\\\\", "\\")
				else
					local n = str:match(pat .. '(-?%d+%.?%d*)') -- number value
					if n then
						out[key] = tonumber(n)
					elseif str:match(pat .. "true") then        -- boolean value
						out[key] = true
					elseif str:match(pat .. "false") then
						out[key] = false
					end
				end
			end
		end)
		return out
	end

	-- ---------------------------------------------------------------
	-- Storage backends (each one is independent and pcall-guarded)
	-- ---------------------------------------------------------------
	local function fsPath(placeId)
		return SESSION_FOLDER .. "/" .. tostring(placeId) .. ".json"
	end

	local function reexecPath(placeId)
		return SESSION_FOLDER .. "/_reexec_" .. tostring(placeId)
	end

	local function readFromFS(placeId)
		if not hasFS then return nil end
		local ok, content = pcall(function()
			if isfile(fsPath(placeId)) then
				return readfile(fsPath(placeId))
			end
			return nil
		end)
		if ok then return content end
		return nil
	end

	local function writeToFS(placeId, data)
		if not hasFS then return false end
		-- Some executors require the folder to exist before writefile
		pcall(function()
			if type(isfolder) == "function" and type(makefolder) == "function" then
				if not isfolder(SESSION_FOLDER) then
					makefolder(SESSION_FOLDER)
				end
			end
		end)
		return pcall(function()
			writefile(fsPath(placeId), data)
		end)
	end

	local function readFromGenv(placeId)
		if not genv then return nil end
		local ok, store = pcall(function()
			genv.__IndoVoiceSessions = genv.__IndoVoiceSessions or {}
			return genv.__IndoVoiceSessions[placeId]
		end)
		if ok and type(store) == "table" then return store end
		return nil
	end

	local function writeToGenv(placeId, data)
		if not genv then return false end
		return pcall(function()
			genv.__IndoVoiceSessions = genv.__IndoVoiceSessions or {}
			genv.__IndoVoiceSessions[placeId] = data
		end)
	end

	-- ---------------------------------------------------------------
	-- Public API
	-- ---------------------------------------------------------------
	local Session = {}

	-- The place we're currently in. All session data is keyed by PlaceId so
	-- joining a DIFFERENT game never inherits another game's session.
	local currentPlaceId = 0
	pcall(function()
		if tonumber(game.PlaceId) then
			currentPlaceId = tonumber(game.PlaceId)
		end
	end)

	-- Load the saved session for this place (nil if none / expired).
	function Session.Load()
		local data = nil

		-- 1) Filesystem first (survives full game restarts)
		local raw = readFromFS(currentPlaceId)
		if raw and raw ~= "" then
			data = parseSession(raw)
		end

		-- 2) getgenv() fallback (survives re-execution in the same session)
		if not data or not next(data) then
			local g = readFromGenv(currentPlaceId)
			if g then
				data = g
			end
		end

		-- 3) Plain memory fallback (same VM instance only)
		if not data or not next(data) then
			if next(memoryStore) then
				data = memoryStore
			end
		end

		if not data or not next(data) then
			return nil
		end

		-- Sanity: the saved PlaceId must match the current one.
		if tonumber(data.placeId) and tonumber(currentPlaceId) ~= 0
			and tonumber(data.placeId) ~= tonumber(currentPlaceId) then
			return nil
		end

		-- Expiry check: reject sessions older than SESSION_TTL.
		-- os.time() is used because the file may be read after a full
		-- restart where os.clock() would have reset.
		local ts = tonumber(data.timestamp) or 0
		if os.time() - ts > SESSION_TTL then
			pcall(function() Session.Clear() end) -- wipe expired session
			return nil
		end

		return data
	end

	-- Persist the session for this place. Called right after a successful
	-- password entry or a trusted bypass, so future joins skip the gate.
	function Session.Save(extra)
		local lp = Players.LocalPlayer
		local data = {
			authenticated = true,
			timestamp = os.time(), -- wall-clock, survives restarts
			placeId = currentPlaceId,
			userId = (lp and lp.UserId) or 0,
			playerName = (lp and lp.Name) or "unknown",
		}
		if extra and type(extra) == "table" then
			for k, v in pairs(extra) do
				if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
					data[k] = v
				end
			end
		end

		-- Write to every backend we can (best effort, never throws)
		writeToFS(currentPlaceId, jsonEncode(data))
		writeToGenv(currentPlaceId, data)
		memoryStore = data

		return true
	end

	-- Delete the saved session (e.g. a future "logout" button).
	function Session.Clear()
		pcall(function()
			if hasFS and isfile(fsPath(currentPlaceId)) and type(delfile) == "function" then
				delfile(fsPath(currentPlaceId))
			end
		end)
		pcall(function()
			if genv and genv.__IndoVoiceSessions then
				genv.__IndoVoiceSessions[currentPlaceId] = nil
			end
		end)
		memoryStore = {}
		return true
	end

	-- ---------------------------------------------------------------
	-- AUTO RE-EXECUTION FLAG
	-- ---------------------------------------------------------------
	-- The flag lives in getgenv() (and optionally on disk) and survives
	-- re-execution. When the player teleports back into this place (server
	-- hop) or rejoins after a disconnect, main.lua reads this flag and knows
	-- the previous run wanted the script to come back up automatically.
	function Session.ShouldReexecute()
		local flag = false
		pcall(function()
			if genv and type(genv.__IndoVoiceAutoReexec) == "boolean" then
				flag = genv.__IndoVoiceAutoReexec
			end
			-- Filesystem fallback: a pending one-shot re-exec marker file.
			if not flag and hasFS and isfile(reexecPath(currentPlaceId)) then
				flag = true
			end
			-- Consume the flag (one-shot) so we never loop forever.
			if flag then
				genv.__IndoVoiceAutoReexec = false
				if hasFS and isfile(reexecPath(currentPlaceId)) and type(delfile) == "function" then
					delfile(reexecPath(currentPlaceId))
				end
			end
		end)
		return flag
	end function Session.SetReexecute(flag)
	flag = flag and true or false
	pcall(function()
		if genv then
			genv.__IndoVoiceAutoReexec = flag
			-- Place-aware: the queued payload checks this so a teleport into a
			-- DIFFERENT game never auto-runs IndoVoice there.
			if flag then
				genv.__IndoVoiceReexecPlaceId = currentPlaceId
			else
				genv.__IndoVoiceReexecPlaceId = nil
			end
		end
		if hasFS then
			if flag then
				pcall(function()
					if type(isfolder) == "function" and type(makefolder) == "function" then
						if not isfolder(SESSION_FOLDER) then
							makefolder(SESSION_FOLDER)
						end
					end
					writefile(reexecPath(currentPlaceId), "1")
				end)
			elseif isfile(reexecPath(currentPlaceId)) and type(delfile) == "function" then
				delfile(reexecPath(currentPlaceId))
			end
		end
	end)
	return true
end

	-- ---------------------------------------------------------------
	-- Debug helper (see the testing notes at the bottom of main.lua)
	-- ---------------------------------------------------------------
	function Session.DebugInfo()
		return {
			placeId = currentPlaceId,
			hasFS = hasFS,
			hasGenv = (genv ~= nil),
			session = Session.Load(),
			shouldReexec = (genv and genv.__IndoVoiceAutoReexec) or false,
		}
	end

	return Session
end
