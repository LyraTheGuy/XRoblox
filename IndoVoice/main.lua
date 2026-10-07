-- IndoVoice/main.lua
-- Shared loader, same file for both staging and main
--
-- ============================================================================
-- MODIFICATIONS: PASSWORD BYPASS + AUTO RE-EXECUTION ON REJOIN
-- ============================================================================
-- 1) PASSWORD BYPASS: the first time the user types the correct password,
--    a per-place session file is saved (see session.lua). On every rejoin /
--    server hop inside the SAME place, the gate UI is skipped entirely and
--    the script auto-executes (no password prompt).
-- 2) AUTO RE-EXECUTION: hooks below detect rejoining the same place
--    (teleport into the same PlaceId, e.g. server hop or the script's own
--    auto-reconnect) and re-execute the bootstrap automatically via
--    queue_on_teleport (with a getgenv flag + on-disk marker as fallbacks).
-- 3) DUPLICATE-RUN GUARD: prevents two copies of the script running at once
--    (protects against infinite loops / double loops / memory leaks).
-- All persistence and detection logic is pcall-wrapped so any missing
-- executor function degrades gracefully instead of crashing.
-- ============================================================================

local BASE_URL = ...

-- ----------------------------------------------------------------------------
-- DUPLICATE-RUN GUARD ("script already running" edge case)
-- ----------------------------------------------------------------------------
-- If a previous copy is still alive, core.lua's destroyAll is registered in
-- _G.__AhzencalESP_Destroy. If that's present, a live copy exists -> abort.
-- If the flag is set but destroyAll is gone, the previous copy died mid-load
-- (crash / manual re-exec) -> clear the stale flag and continue.
do
	if _G.INDOVOICE_RUNNING then
		if type(_G.__AhzencalESP_Destroy) == "function" then
			warn("[IndoVoice] Script is already running — skipping duplicate execution.")
			return
		end
		warn("[IndoVoice] Stale run flag found (previous copy crashed) — continuing.")
		_G.INDOVOICE_RUNNING = nil
	end
	_G.INDOVOICE_RUNNING = true
end

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

local function deepClone(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepClone(v)
    end
    return copy
end

local function loadModule(name)
    return compile(fetch(BASE_URL .. "modules/" .. name .. ".lua", name), name)
end

local configChunk = compile(fetch(BASE_URL .. "config.lua", "config.lua"), "config.lua")
local config = deepClone(configChunk())
assert(type(config) == "table", "config.lua must return a table")

-- ----------------------------------------------------------------------------
-- PERSISTENT SESSION (password bypass + auto re-exec coordination)
-- ----------------------------------------------------------------------------
-- Loads session.lua with the same fetch/compile/factory pattern as other
-- modules. Session persistence is OPTIONAL: if it fails to load (missing
-- executor FS functions, network hiccup, etc.) the gate simply behaves as it
-- did before this modification — the script never crashes over it.
local Session = nil
do
	local ok, result = pcall(function()
		local chunk = compile(fetch(BASE_URL .. "session.lua", "session.lua"), "session.lua")
		local factory = chunk()
		assert(type(factory) == "function", "session.lua must return a function")
		return factory(config)
	end)
	if ok then
		Session = result
	else
		warn("[IndoVoice] Session persistence unavailable: " .. tostring(result))
	end
end

-- ----------------------------------------------------------------------------
-- PASSWORD BYPASS CHECK + RE-EXEC FLAG CONSUMPTION (run BEFORE the gate)
-- ----------------------------------------------------------------------------
-- pendingReexec : previous run asked to auto re-execute (rejoin detected)
-- trustedSession: saved session exists -> skip the password gate this join
local pendingReexec = false
local trustedSession = false
if Session then
	pcall(function()
		-- One-shot: consume a pending re-exec flag left by the previous run.
		pendingReexec = Session.ShouldReexecute() == true
		-- Bypass the gate if this place has a valid (non-expired) session.
		local saved = Session.Load()
		trustedSession = (saved ~= nil and saved.authenticated == true)
	end)
	-- A pending re-exec flag can only be set by a run that already passed the
	-- gate (main.lua arms it after a successful load), so it also proves the
	-- password was typed once -> trust it even if no session file exists
	-- (executors without writefile still get the bypass within one session).
	if pendingReexec then
		trustedSession = true
	end
end

-- Auto-execution decision for THIS run:
--   * trusted session  -> always auto-run (password was typed once before)
--   * pending re-exec  -> auto-run even without a saved session (same-session
--     rejoin); the session gets re-saved below after the (skipped) gate.
--   * brand-new user   -> show the gate once, then remember it forever.
local autoExecuted = trustedSession or pendingReexec
if autoExecuted then
	print("[IndoVoice] " .. (pendingReexec and "Rejoin detected — auto-executing (re-exec flag)."
		or "Trusted session found — bypassing password gate."))
end

-- ----------------------------------------------------------------------------
-- PASSWORD GATE (blocks until authenticated — unless bypassed)
-- ----------------------------------------------------------------------------
-- PASSWORD BYPASS: gate.lua accepts { trusted = true } and returns true
-- immediately without building the UI, when a saved session exists.
local gateChunk = compile(fetch(BASE_URL .. "gate.lua", "gate.lua"), "gate.lua")
local gateFactory = gateChunk()
assert(type(gateFactory) == "function", "gate.lua must return a function")
local gateOk, gateErr = pcall(gateFactory, config, { trusted = trustedSession })
if not gateOk then
	-- A broken gate must not take the whole script down; a trusted session
	-- means the user already proved ownership of the password once.
	if trustedSession then
		warn("[IndoVoice] Gate errored but session is trusted — continuing: " .. tostring(gateErr))
	else
		error("[IndoVoice] Gate failed: " .. tostring(gateErr))
	end
end

-- ----------------------------------------------------------------------------
-- SAVE SESSION (password bypass anchor point)
-- ----------------------------------------------------------------------------
-- Runs after the gate passes — whether the user typed the password manually
-- (first join) or the gate was bypassed (rejoin). Refreshing the timestamp
-- on every run keeps the session alive forever for active users.
if Session then
	pcall(function()
		Session.Save({ reexec = autoExecuted and "true" or "false" })
	end)
end

-- Error recovery: show error GUI if something fails
local function showErrorGui(msg)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local errGui = Instance.new("ScreenGui")
    errGui.Name = "LyraHub_Error"
    errGui.ResetOnSpawn = false
    errGui.DisplayOrder = 9999
    pcall(function() errGui.Parent = game:GetService("CoreGui") end)
    if not errGui.Parent then errGui.Parent = lp:WaitForChild("PlayerGui") end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 120)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
    frame.BorderSizePixel = 0
    frame.Parent = errGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(255, 80, 80)
    stroke.Thickness = 1.5

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 1, -20)
    lbl.Position = UDim2.new(0, 10, 0, 10)
    lbl.BackgroundTransparency = 1
    lbl.Text = "LyraHub Error:\n" .. tostring(msg)
    lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Parent = frame

    task.delay(15, function() pcall(function() errGui:Destroy() end) end)
end

-- Pre-kit fallback status hint: only used when the LyraHub kit itself failed
-- to load (you can't show the kit toast when the kit link is down). At
-- runtime, notifications go through the kit toast component (gui.Toast).
local function showKitToast(msg)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "LyraHubKitToast"
    toastGui.ResetOnSpawn = false
    toastGui.DisplayOrder = 9998
    pcall(function() toastGui.Parent = game:GetService("CoreGui") end)
    if not toastGui.Parent then toastGui.Parent = lp:WaitForChild("PlayerGui") end

    local toast = Instance.new("TextButton")
    toast.Size = UDim2.new(0, 420, 0, 54)
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.Position = UDim2.new(0.5, 0, 1, -64)
    toast.BackgroundColor3 = Color3.fromRGB(26, 22, 14)
    toast.AutoButtonColor = false
    toast.BorderSizePixel = 0
    toast.Parent = toastGui
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
    local toastStroke = Instance.new("UIStroke", toast)
    toastStroke.Color = Color3.fromRGB(240, 190, 90)
    toastStroke.Thickness = 1

    local toastIcon = Instance.new("TextLabel")
    toastIcon.Text = "⚠"
    toastIcon.Size = UDim2.new(0, 24, 1, 0)
    toastIcon.Position = UDim2.new(0, 8, 0, 0)
    toastIcon.BackgroundTransparency = 1
    toastIcon.TextColor3 = Color3.fromRGB(240, 190, 90)
    toastIcon.Font = Enum.Font.GothamBold
    toastIcon.TextSize = 16
    toastIcon.Parent = toast

    local toastText = Instance.new("TextLabel")
    toastText.Size = UDim2.new(1, -36, 1, -8)
    toastText.Position = UDim2.new(0, 34, 0, 4)
    toastText.BackgroundTransparency = 1
    toastText.Text = msg
    toastText.TextColor3 = Color3.fromRGB(250, 240, 215)
    toastText.Font = Enum.Font.Gotham
    toastText.TextSize = 11
    toastText.TextWrapped = true
    toastText.TextXAlignment = Enum.TextXAlignment.Left
    toastText.TextYAlignment = Enum.TextYAlignment.Center
    toastText.Parent = toast

    toast.MouseButton1Click:Connect(function() pcall(function() toastGui:Destroy() end) end)
    task.delay(12, function() pcall(function() toastGui:Destroy() end) end)
end

-- LyraHub UI kit: shared primitives + button component from the raw GitHub
-- link (same repo, LyraHub/ folder) so this project renders with kit styling.
local LYRAHUB_URL = BASE_URL:gsub("/IndoVoice/", "/LyraHub/")
local components = {}
local kitOk, kitErr = pcall(function()
    local sharedChunk = compile(fetch(LYRAHUB_URL .. "views/components/shared.lua", "shared.lua"), "shared.lua")
    local sharedFactory = sharedChunk()
    assert(type(sharedFactory) == "function", "shared.lua must return a function")
    local shared = sharedFactory(config)
    local buttonChunk = compile(fetch(LYRAHUB_URL .. "views/components/button.lua", "button.lua"), "button.lua")
    local buttonFactory = buttonChunk()
    assert(type(buttonFactory) == "function", "button.lua must return a function")
    components.shared = shared
    components.button = buttonFactory(config, shared)
    for _, name in ipairs({ "toast", "updatecheck", "keybind" }) do
        local chunk = compile(fetch(LYRAHUB_URL .. "views/components/" .. name .. ".lua", name), name)
        components[name] = chunk()(config, shared)
    end
end)
if not kitOk then
    warn("[LyraHub] Kit load failed: " .. tostring(kitErr))
    showKitToast("LyraHub UI kit failed to load from the raw GitHub link.\nPush the latest LyraHub/ folder to GitHub, then re-run.")
    return
end

-- Load main UI after authentication
local guiChunk = compile(fetch(BASE_URL .. "gui.lua", "gui.lua"), "gui.lua")
local coreChunk = compile(fetch(BASE_URL .. "core.lua", "core.lua"), "core.lua")
local guiFactory = guiChunk()
local coreFactory = coreChunk()

if type(guiFactory) ~= "function" then
    showErrorGui("gui.lua returned: " .. type(guiFactory) .. " (expected function)")
    return
end
if type(coreFactory) ~= "function" then
    showErrorGui("core.lua returned: " .. type(coreFactory) .. " (expected function)")
    return
end

local guiOk, gui = pcall(guiFactory, config, components)
if not guiOk then
    showErrorGui("gui.lua execution failed:\n" .. tostring(gui))
    return
end

local coreOk, ctx = pcall(coreFactory, gui, config)
if not coreOk then
    showErrorGui("core.lua execution failed:\n" .. tostring(ctx))
    return
end

-- teleportConn is declared BEFORE the ctx.destroyAll wrapper below so the
-- wrapper's closure captures it as an upvalue (assigned in the do-block at
-- the bottom of this file, disconnected on manual unload).
local teleportConn = nil

-- ----------------------------------------------------------------------------
-- UNLOAD HOOK (edge case: manual unload must cancel the auto re-exec flag)
-- ----------------------------------------------------------------------------
-- gui.lua's "Unload Script" button and the close button both call
-- ctx.destroyAll directly, so we wrap it HERE (before modules load, which is
-- when ui.lua captures its own reference to ctx.destroyAll). On manual unload:
--   * the OnTeleport listener is disconnected (no orphan connections)
--   * the one-shot re-exec flag is cleared -> no auto-run on next rejoin
--   * the run flag is released -> a fresh manual execute is allowed
-- The saved session itself is KEPT, so the password is still not asked again.
local function cleanupOnUnload()
	pcall(function()
		if teleportConn then
			teleportConn:Disconnect()
			teleportConn = nil
		end
	end)
	pcall(function()
		-- Manual unload = the user asked the script to stop: clear the flag
		-- so the queued teleport payload stays silent on the next rejoin.
		if Session then Session.SetReexecute(false) end
	end)
	_G.INDOVOICE_RUNNING = nil
end

if ctx and type(ctx.destroyAll) == "function" then
	local origDestroyAll = ctx.destroyAll
	ctx.destroyAll = function()
		cleanupOnUnload()
		origDestroyAll()
	end
end
-- Same cleanup for the global ESP destroy hook (a second unload entry point
-- registered by core.lua) so no path can leave the re-exec flag armed.
pcall(function()
	if type(_G.__AhzencalESP_Destroy) == "function" then
		local origGlobalDestroy = _G.__AhzencalESP_Destroy
		_G.__AhzencalESP_Destroy = function()
			cleanupOnUnload()
			origGlobalDestroy()
		end
	end
end)

-- Load modules
local modules = {"adminmenu", "fishing", "mining", "gacha", "shopgacha", "tokenshop", "rodshop", "antiafk", "ui"}
for _, name in ipairs(modules) do
    local ok, err = pcall(function()
        local modChunk = loadModule(name)
        local modFactory = modChunk()
        if type(modFactory) == "function" then
            modFactory(ctx)
        else
            showErrorGui("Module '" .. name .. "' did not return a function")
        end
    end)
    if not ok then
        showErrorGui("Module '" .. name .. "' failed:\n" .. tostring(err))
    end
end

-- Update check: compare the running build against the live raw config
if components.updatecheck and components.updatecheck.Check and config.Build then
    components.updatecheck.Check({ LocalBuild = config.Build, ConfigURL = BASE_URL .. "config.lua" })
end

-- ============================================================================
-- AUTO RE-EXECUTION ON REJOIN
-- ============================================================================
-- REJOIN DETECTION MECHANISM:
--   Roblox executors run each place session in a fresh VM, so a plain
--   "rejoin hook" cannot survive the join itself. The standard pattern is:
--
--     1. queue_on_teleport(fn) — executor copies `fn` into the NEXT place's
--        VM. Fires for ANY teleport (server hop, auto-reconnect, rejoin).
--     2. As a portable fallback, Session.SetReexecute(true) drops a one-shot
--        flag in getgenv() AND a marker file on disk. On the next boot,
--        main.lua consumes the flag (one-shot) and knows to auto-run.
--
--   Both are armed below. On boot the flag is consumed exactly once, so the
--   loop is: run -> arm flag -> teleport -> boot -> consume flag -> run.
--   It can never re-trigger itself within a single run.
-- ============================================================================
do
	-- (a) Arm the one-shot re-exec flag for the next boot (fallback path).
	--     Refreshed on every teleport; cleared on manual unload.
	if Session then
		pcall(function() Session.SetReexecute(true) end)
	end

	-- (b) Primary path: queue the bootstrap for the next place VM.
	--     queue_on_teleport exists on most executors; pcall-wrapped because
	--     some don't have it (the marker-file fallback covers those).
	--     The queued payload re-checks the re-exec flag first, so it stays
	--     silent after a manual unload (which clears the flag).
	if type(queue_on_teleport) == "function" then
		pcall(function()
			queue_on_teleport([[
local ok, err = pcall(function()
	-- Respect a manual unload: skip auto-exec when the flag was cleared.
	-- ALSO place-aware: the flag must belong to THIS place, so teleporting
	-- into a DIFFERENT game never auto-runs IndoVoice there.
	local flag = false
	pcall(function()
		local g = (type(getgenv) == "function") and getgenv() or nil
		if g and g.__IndoVoiceAutoReexec == true
			and (g.__IndoVoiceReexecPlaceId == nil or g.__IndoVoiceReexecPlaceId == game.PlaceId) then
			flag = true
		end
	end)
	if not flag then
		pcall(function()
			if type(isfile) == "function" and isfile("IndoVoiceSession/_reexec_" .. tostring(game.PlaceId)) then
				flag = true
			end
		end)
	end
	if not flag then return end
	-- Never double-start if a live copy somehow survived the teleport.
	if _G.INDOVOICE_RUNNING and type(_G.__AhzencalESP_Destroy) == "function" then
		return
	end
	_G.INDOVOICE_RUNNING = nil -- fresh VM: clear stale flag before re-run
	local src = game:HttpGet("]] .. BASE_URL .. [[bootstrap.lua")
	local fn, cerr = loadstring(src)
	if fn then fn() else error(cerr) end
end)
if not ok then warn("[IndoVoice] Auto re-exec failed: " .. tostring(err)) end
]])
		end)
	end

	-- (c) Safety net for executors whose queue_on_teleport drops the payload:
	--     re-arm the one-shot marker the moment a teleport STARTS. This
	--     listener belongs to the CURRENT VM only and is disconnected by the
	--     ctx.destroyAll wrapper on manual unload (no connection leaks).
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		teleportConn = lp.OnTeleport:Connect(function(state)
			if state == Enum.TeleportState.Started and Session then
				pcall(function() Session.SetReexecute(true) end)
			end
		end)
	end)
end

--[[ ========================================================================
     TESTING NOTES
     ========================================================================
     1. FIRST JOIN (password still required):
        - Execute bootstrap.lua. The LYRA HUB gate card must appear.
        - Type the password and press Enter. The main UI must load normally.
        - Check the executor console: no "Session persistence unavailable"
          warning means the session file was written.

     2. REJOIN / SERVER HOP (bypass expected):
        - Leave the game, rejoin the SAME place (or use a server hopper).
        - Execute bootstrap.lua again. Expected: NO gate card; the console
          prints "Trusted session found — bypassing password gate." and the
          main UI loads straight away.

     3. AUTO RE-EXECUTION (no manual execute on rejoin):
        - While the script is running, hop servers (or trigger the built-in
          auto-reconnect). After the teleport completes, the script must
          re-execute by itself and print "Rejoin detected — auto-executing."
        - Verify only ONE copy runs: the console must NOT print
          "Script is already running".

     4. MANUAL UNLOAD (must NOT auto-run afterwards):
        - Click "Unload Script" in Settings, then rejoin manually.
        - Expected: after manual execute the gate is still bypassed (session
          is kept), but the script must NOT re-execute by itself.

     5. DIFFERENT GAME (no cross-game session leak):
        - Join any other game and execute bootstrap.lua. The gate card must
          appear (sessions are keyed by PlaceId).

     6. EXPIRY (optional):
        - Delete IndoVoiceSession/<placeId>.json from the executor workspace
          (or wait out Gate.SessionTTL). The gate must ask for the password
          again.

     7. NO-FS EXECUTOR (optional):
        - On an executor without writefile, everything must still work: the
          gate shows every full restart, but bypass + auto-exec still work
          within a single Roblox session via getgenv().
     ======================================================================== ]]
