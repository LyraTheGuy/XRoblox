--[[ ==========================================================================
     STANDALONE ANTI-AFK
     ==========================================================================
     A self-contained anti-AFK that can be executed anywhere (any game),
     with no external dependencies (no GitHub fetch, no gate, no modules).

     Behaviour mirrors IndoVoice/modules/antiafk.lua's three defence layers:
       1) PREVENTION - periodic real input + tiny movement nudge so the game's
                       own idle timer keeps resetting.
       2) REMOTE     - listen for common AFK check remotes and answer them.
       3) GUI        - fallback that finds and clicks/closes the AFK prompt.

     AUTO RE-EXEC ON SERVER RESTART / REJOIN:
       queue_on_teleport + getgenv one-shot flag + on-disk marker, so a manual
       unload (which clears the flag) stays unloaded. Place-aware so it never
       fires in a different game.

     Everything is pcall-wrapped so missing executor functions degrade
     gracefully instead of crashing.

     Optional config via getgenv().AntiAfk_Config (set BEFORE executing):
       NUDGE_INTERVAL     (seconds, default 120)  - how often to nudge
       RECONNECT          (bool, default true)    - re-exec on teleport/rejoin
       CONFIG_URL         (string, optional)      - raw URL to re-run on rejoin.
       SOURCE             (string, optional)      - explicit source to re-run.

     A draggable status panel shows Time / FPS / AFK timer / Next nudge.
     Click the header to unload.
     ========================================================================== ]]

-- Unmissable startup marker: if you see this, the script IS running.
print("[AntiAFK] >>> SCRIPT STARTED <<<")
warn("[AntiAFK] >>> SCRIPT STARTED <<<")

-- ============================================================================
-- CONFIG / ENVIRONMENT
-- ============================================================================
local genv = (type(getgenv) == "function" and getgenv()) or _G
local USER_CFG = (type(genv.AntiAfk_Config) == "table" and genv.AntiAfk_Config) or {}

local NUDGE_INTERVAL = tonumber(USER_CFG.NUDGE_INTERVAL) or 120
local RECONNECT      = (USER_CFG.RECONNECT ~= false) -- default true
local CONFIG_URL     = USER_CFG.CONFIG_URL -- optional raw URL for re-exec

-- Keys used for persistence across re-exec / rejoins.
local FLAG_KEY       = "__StandaloneAntiAfkReexec"
local PLACE_KEY      = "__StandaloneAntiAfkPlaceId"
local SRC_KEY        = "__StandaloneAntiAfkSource"
local RUN_KEY        = "__StandaloneAntiAfkRunning"
local FOLDER         = "StandaloneAntiAfk"
local MARKER_FILE    = FOLDER .. "/_reexec_" .. tostring(game.PlaceId)

-- ============================================================================
-- DUPLICATE-RUN GUARD
-- ============================================================================
do
	if genv[RUN_KEY] and type(genv.__StandaloneAntiAfkDestroy) == "function" then
		warn("[AntiAFK] Already running -- skipping duplicate execution.")
		return
	end
	if genv[RUN_KEY] then
		warn("[AntiAFK] Stale run flag found (previous copy crashed) -- continuing.")
		genv[RUN_KEY] = nil
	end
	genv[RUN_KEY] = true
end

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local VirtualUser        = game:GetService("VirtualUser")
local RunService         = game:GetService("RunService")
local lp                 = Players.LocalPlayer

-- Track whether we're being unloaded on purpose (so re-exec stays cancelled).
local destroyed = false

-- Stats shown by the status panel.
local lastActivity = os.clock()  -- timestamp of the last input we sent (AFK timer)
local fpsAccum, fpsTime, lastFps = 0, 0, 0

-- ============================================================================
-- SMALL HELPERS
-- ============================================================================
local function log(msg, err)
	if err then
		warn("[AntiAFK] " .. tostring(msg))
	else
		print("[AntiAFK] " .. tostring(msg))
	end
end

local function hasFS()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function getHRP(char)
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

-- ============================================================================
-- AUTO RE-EXEC PERSISTENCE (server restart / rejoin)
-- ============================================================================
local SELF_SOURCE = nil
do
	-- Best-effort capture of our own source.
	pcall(function()
		if type(debug) == "function" and type(debug.getinfo) == "function" then
			local info = debug.getinfo(1, "S")
			if info and info.source and info.source:sub(1, 1) == "@" then
				local path = info.source:sub(2)
				if type(readfile) == "function" then
					local ok, content = pcall(readfile, path)
					if ok and type(content) == "string" and #content > 0 then
						SELF_SOURCE = content
					end
				end
			end
		end
	end)
	if not SELF_SOURCE and type(USER_CFG.SOURCE) == "string" then
		SELF_SOURCE = USER_CFG.SOURCE
	end
	if SELF_SOURCE then
		pcall(function() genv[SRC_KEY] = SELF_SOURCE end)
		if hasFS() then
			pcall(function()
				if type(isfolder) == "function" and type(makefolder) == "function" then
					if not isfolder(FOLDER) then makefolder(FOLDER) end
				end
				writefile(FOLDER .. "/source.lua", SELF_SOURCE)
			end)
		end
	else
		pcall(function() SELF_SOURCE = genv[SRC_KEY] end)
		if not SELF_SOURCE and hasFS() and isfile(FOLDER .. "/source.lua") then
			pcall(function() SELF_SOURCE = readfile(FOLDER .. "/source.lua") end)
		end
	end
end

-- Arm/disarm the one-shot re-exec flag for the next boot.
local function setReexec(on)
	on = on and true or false
	pcall(function()
		genv[FLAG_KEY] = on
		if on then
			genv[PLACE_KEY] = game.PlaceId
		else
			genv[PLACE_KEY] = nil
		end
	end)
	if hasFS() then
		pcall(function()
			if on then
				if type(isfolder) == "function" and type(makefolder) == "function" then
					if not isfolder(FOLDER) then makefolder(FOLDER) end
				end
				writefile(MARKER_FILE, tostring(game.PlaceId))
			elseif isfile(MARKER_FILE) and type(delfile) == "function" then
				delfile(MARKER_FILE)
			end
		end)
	end
end

-- Consume (one-shot) the re-exec flag; returns true if a rejoin was pending.
local function consumeReexec()
	local flag = false
	pcall(function()
		if genv[FLAG_KEY] == true
			and (genv[PLACE_KEY] == nil or genv[PLACE_KEY] == game.PlaceId) then
			flag = true
		end
	end)
	if not flag and hasFS() and isfile(MARKER_FILE) then
		flag = true
	end
	if flag then
		pcall(function()
			genv[FLAG_KEY] = false
			genv[PLACE_KEY] = nil
		end)
		if hasFS() and isfile(MARKER_FILE) and type(delfile) == "function" then
			pcall(delfile, MARKER_FILE)
		end
	end
	return flag
end

local function armAutoReexec()
	if not RECONNECT then return end

	setReexec(true)

	if type(queue_on_teleport) == "function" then
		local payload = ([[
local ok, err = pcall(function()
	local flag = false
	pcall(function()
		local g = (type(getgenv) == "function") and getgenv() or nil
		if g and g.%s == true
			and (g.%s == nil or g.%s == game.PlaceId) then
			flag = true
		end
	end)
	if not flag then
		pcall(function()
			if type(isfile) == "function" and isfile(%q) then flag = true end
		end)
	end
	if not flag then return end
	if _G.%s and type(_G.__StandaloneAntiAfkDestroy) == "function" then return end

	local src
]]):format(FLAG_KEY, PLACE_KEY, PLACE_KEY, MARKER_FILE, RUN_KEY)

		if CONFIG_URL then
			payload = payload .. ([[
	local httpOk, body = pcall(function() return game:HttpGet(%q) end)
	if httpOk and type(body) == "string" and body ~= "" and body ~= "404: Not Found" then
		src = body
	end
]]):format(CONFIG_URL)
		end

		payload = payload .. ([[
	if not src then
		pcall(function()
			local g = (type(getgenv) == "function") and getgenv() or nil
			if g and type(g.%s) == "string" and #g.%s > 0 then src = g.%s end
		end)
	end
	if not src then
		pcall(function()
			if type(isfile) == "function" and isfile(%q) and type(readfile) == "function" then
				src = readfile(%q)
			end
		end)
	end
	if not src or #src == 0 then
		warn("[AntiAFK] Auto re-exec: no source available on rejoin.")
		return
	end
	local fn, cerr = loadstring(src)
	if fn then fn() else warn("[AntiAFK] Auto re-exec failed: " .. tostring(cerr)) end
end)
if not ok then warn("[AntiAFK] Auto re-exec failed: " .. tostring(err)) end
]]):format(SRC_KEY, SRC_KEY, SRC_KEY, FOLDER .. "/source.lua", FOLDER .. "/source.lua")

		pcall(function() queue_on_teleport(payload) end)
	end

	-- Safety net: re-arm the marker the moment a teleport STARTS.
	pcall(function()
		lp.OnTeleport:Connect(function(state)
			if destroyed then return end
			if state == Enum.TeleportState.Started then
				pcall(function() setReexec(true) end)
			end
		end)
	end)
end

-- ============================================================================
-- CONNECTION TRACKING
-- ============================================================================
local connections = {}
local function track(conn)
	if conn then table.insert(connections, conn) end
	return conn
end

-- ============================================================================
-- LAYER 2: REMOTE HANDLERS
-- ============================================================================
local function looksLikeAfkDecision(name)
	local n = string.lower(name)
	return string.find(n, "afk", 1, true) ~= nil
		and (string.find(n, "decision", 1, true) ~= nil or string.find(n, "return", 1, true) ~= nil)
end

local function answerRemote(re, ...)
	local args = { ... }
	pcall(function() re:FireServer(table.unpack(args)) end)
end

local function hookAfkRemotes()
	local containers = {
		ReplicatedStorage,
		ReplicatedStorage:FindFirstChild("GameRemoteEvents"),
		ReplicatedStorage:FindFirstChild("Remotes"),
		ReplicatedStorage:FindFirstChild("RemoteEvents"),
	}

	local checkEvent, decisionEvent, returnEvent

	for _, container in ipairs(containers) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("RemoteEvent") then
					local n = string.lower(child.Name)
					if string.find(n, "afk", 1, true) then
						if string.find(n, "return", 1, true) then
							returnEvent = returnEvent or child
						elseif string.find(n, "decision", 1, true) then
							decisionEvent = decisionEvent or child
						elseif string.find(n, "check", 1, true) then
							checkEvent = checkEvent or child
						end
					end
				end
			end
		end
	end

	if checkEvent then
		log("Hooked AFK check remote: " .. checkEvent:GetFullName())
		track(checkEvent.OnClientEvent:Connect(function(...)
			if destroyed then return end
			log("AFK check received -- answering")
			if decisionEvent then
				answerRemote(decisionEvent)
				task.wait(0.15)
				answerRemote(decisionEvent, true)
			end
			task.wait(0.3)
			scanForPrompt()
		end))
	end

	if returnEvent then
		log("Hooked AFK return remote: " .. returnEvent:GetFullName())
		track(returnEvent.OnClientEvent:Connect(function(...)
			if destroyed then return end
			log("AFK return prompt received -- requesting return")
			answerRemote(returnEvent, true)
		end))
	end
end

-- ============================================================================
-- LAYER 3: GUI FALLBACK
-- ============================================================================
local scanForPrompt

local AFK_TEXTS = {
	"still there",
	"are you still",
	"afk",
	"idle",
	"you have been inactive",
	"inactive",
}

local AFFIRMATIVE = { "i'm here", "im here", "still here", "yes", "continue", "stay" }
local DISMISS     = { "dismiss", "no", "close", "ok" }

local PROMPT_NAMES = { "Confirmation", "AFK", "AFKCheck", "AntiAFK", "IdleCheck", "StillThere" }

local function matchesAny(text, patterns)
	local lower = string.lower(tostring(text or ""))
	for _, p in ipairs(patterns) do
		if string.find(lower, p, 1, true) then return true end
	end
	return false
end

local function containerHasAfk(container)
	for _, desc in ipairs(container:GetDescendants()) do
		if desc:IsA("TextLabel") or desc:IsA("TextButton") then
			if matchesAny(desc.Text, AFK_TEXTS) then return true end
		end
	end
	return false
end

local function clickButton(button)
	local ok = pcall(function()
		local pos, size = button.AbsolutePosition, button.AbsoluteSize
		VirtualUser:CaptureController()
		VirtualUser:SendMouseButtonEvent(pos.X + size.X / 2, pos.Y + size.Y / 2, 0, true, game, 0)
		task.wait(0.05)
		VirtualUser:SendMouseButtonEvent(pos.X + size.X / 2, pos.Y + size.Y / 2, 0, false, game, 0)
	end)
	if not ok and type(firesignal) == "function" then
		pcall(function() firesignal(button.MouseButton1Click) end)
	end
end

local function findButton(container)
	local buttons = {}
	for _, desc in ipairs(container:GetDescendants()) do
		if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
			table.insert(buttons, desc)
		end
	end
	for _, group in ipairs({ AFFIRMATIVE, DISMISS }) do
		for _, b in ipairs(buttons) do
			if b:IsA("TextButton") and matchesAny(b.Text, group) then return b end
		end
	end
	return buttons[1]
end

scanForPrompt = function()
	local playerGui = lp:FindFirstChild("PlayerGui")
	if not playerGui then return end

	for _, name in ipairs(PROMPT_NAMES) do
		local gui = playerGui:FindFirstChild(name)
		if gui and (gui:IsA("ScreenGui") or gui:IsA("GuiObject")) then
			local enabled = (not gui:IsA("ScreenGui")) or gui.Enabled
			if enabled and containerHasAfk(gui) then
				log("AFK prompt UI detected (" .. name .. ") -- clicking")
				if genv.__StandaloneAntiAfkAnswer then
					pcall(genv.__StandaloneAntiAfkAnswer)
				end
				local btn = findButton(gui)
				if btn then clickButton(btn) end
				return
			end
		end
	end
end

local function watchPrompts()
	local playerGui = lp:FindFirstChild("PlayerGui")
	if not playerGui then return end

	for _, name in ipairs(PROMPT_NAMES) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			track(gui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if destroyed or not gui.Enabled then return end
				task.wait(0.2)
				scanForPrompt()
			end))
		end
	end

	track(playerGui.ChildAdded:Connect(function(child)
		if destroyed then return end
		for _, name in ipairs(PROMPT_NAMES) do
			if child.Name == name then
				task.wait(0.3)
				scanForPrompt()
				return
			end
		end
	end))
end

-- ============================================================================
-- LAYER 1: PREVENTION (idle-timer reset)
-- ============================================================================
local function generateActivity()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)

	pcall(function()
		local char = lp.Character
		local hrp = getHRP(char)
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid then
			local pos = hrp.Position
			humanoid:MoveTo(pos + Vector3.new(0, 0, 0.5))
			task.wait(0.15)
			humanoid:MoveTo(pos)
		end
	end)

	lastActivity = os.clock()
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================
local loopRunning = false
local function startLoop()
	if loopRunning then return end
	loopRunning = true
	task.spawn(function()
		while not destroyed do
			generateActivity()
			scanForPrompt()
			task.wait(NUDGE_INTERVAL)
		end
		loopRunning = false
	end)
end

track(lp.CharacterAdded:Connect(function()
	if destroyed then return end
	task.wait(1)
	scanForPrompt()
end))

-- Expose a "answer all AFK remotes" helper for the GUI layer + externals.
genv.__StandaloneAntiAfkAnswer = function()
	local containers = {
		ReplicatedStorage,
		ReplicatedStorage:FindFirstChild("GameRemoteEvents"),
	}
	for _, c in ipairs(containers) do
		if c then
			for _, child in ipairs(c:GetChildren()) do
				if child:IsA("RemoteEvent") and looksLikeAfkDecision(child.Name) then
					answerRemote(child)
					answerRemote(child, true)
				end
			end
		end
	end
end

-- ============================================================================
-- UNLOAD HOOK
-- ============================================================================
local function destroyAll()
	if destroyed then return end
	destroyed = true
	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	connections = {}
	genv.__StandaloneAntiAfkAnswer = nil
	setReexec(false)
	genv[RUN_KEY] = nil
	genv.__StandaloneAntiAfkDestroy = nil
	-- Destroy the GUI via the stored reference (works whether it was parented
	-- to CoreGui or PlayerGui), then fall back to name lookups.
	pcall(function()
		local gui = genv.__StandaloneAntiAfkGui
		if gui then gui:Destroy() end
	end)
	pcall(function()
		local gui = lp.PlayerGui and lp.PlayerGui:FindFirstChild("StandaloneAntiAfk")
		if gui then gui:Destroy() end
	end)
	pcall(function()
		local cg = game:GetService("CoreGui")
		local gui = cg and cg:FindFirstChild("StandaloneAntiAfk")
		if gui then gui:Destroy() end
	end)
	genv.__StandaloneAntiAfkGui = nil
	genv.__StandaloneAntiAfkPanel = nil
	log("Unloaded.")
end

genv.__StandaloneAntiAfkDestroy = destroyAll

-- ============================================================================
-- BOOT
-- ============================================================================
if consumeReexec() then
	log("Rejoin detected -- auto-executing.")
end

-- ============================================================================
-- STATUS PANEL  (Time / FPS / AFK timer / next-nudge countdown)
-- ============================================================================
-- Draggable, clickable-to-unload panel. Stored in genv so destroyAll() can
-- always tear it down no matter which container it was parented to.
do
	pcall(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "StandaloneAntiAfk"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 9999
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local parentOk = pcall(function() gui.Parent = game:GetService("CoreGui") end)
		if not parentOk or not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end
		genv.__StandaloneAntiAfkGui = gui

		local frame = Instance.new("Frame")
		frame.Name = "Panel"
		frame.Size = UDim2.new(0, 190, 0, 118)
		frame.Position = UDim2.new(1, -200, 0, 10)
		frame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
		frame.BorderSizePixel = 0
		frame.Active = true
		frame.Draggable = true
		frame.Parent = gui
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke", frame)
		stroke.Color = Color3.fromRGB(60, 66, 80)
		stroke.Thickness = 1

		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, 0, 0, 26)
		header.BackgroundColor3 = Color3.fromRGB(46, 110, 168)
		header.BorderSizePixel = 0
		header.Font = Enum.Font.GothamBold
		header.TextSize = 13
		header.TextColor3 = Color3.fromRGB(255, 255, 255)
		header.Text = "Anti-AFK: ON"
		header.Parent = frame
		Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

		local headerFix = Instance.new("Frame")
		headerFix.Size = UDim2.new(1, 0, 0, 8)
		headerFix.Position = UDim2.new(0, 0, 1, -8)
		headerFix.BackgroundColor3 = Color3.fromRGB(46, 110, 168)
		headerFix.BorderSizePixel = 0
		headerFix.ZIndex = header.ZIndex
		headerFix.Parent = header

		local function makeRow(yOffset, labelText)
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(0.55, 0, 0, 18)
			label.Position = UDim2.new(0, 12, 0, yOffset)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Gotham
			label.TextSize = 12
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = Color3.fromRGB(150, 156, 168)
			label.Text = labelText
			label.Parent = frame

			local value = Instance.new("TextLabel")
			value.Size = UDim2.new(0.40, 0, 0, 18)
			value.Position = UDim2.new(0.58, 0, 0, yOffset)
			value.BackgroundTransparency = 1
			value.Font = Enum.Font.GothamBold
			value.TextSize = 12
			value.TextXAlignment = Enum.TextXAlignment.Right
			value.TextColor3 = Color3.fromRGB(235, 238, 245)
			value.Text = "--"
			value.Parent = frame
			return value
		end

		local timeValue  = makeRow(34, "Time")
		local fpsValue   = makeRow(54, "FPS")
		local afkValue   = makeRow(74, "AFK timer")
		local nudgeValue = makeRow(94, "Next nudge")

		local clickBtn = Instance.new("TextButton")
		clickBtn.Size = UDim2.new(1, 0, 0, 26)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.ZIndex = 5
		clickBtn.Parent = header
		clickBtn.MouseButton1Click:Connect(function()
			destroyAll()
		end)

		track(RunService.RenderStepped:Connect(function(dt)
			if destroyed then return end
			if dt > 0 then
				fpsAccum = fpsAccum + 1
				fpsTime = fpsTime + dt
				if fpsTime >= 0.5 then
					lastFps = math.floor(fpsAccum / fpsTime + 0.5)
					fpsAccum = 0
					fpsTime = 0
				end
			end
		end))

		track(task.spawn(function()
			while not destroyed do
				pcall(function()
					local idleFor = os.clock() - lastActivity
					timeValue.Text = os.date("%H:%M:%S")
					fpsValue.Text = tostring(lastFps)
					afkValue.Text = string.format("%.0fs", idleFor)
					nudgeValue.Text = string.format("%.0fs", math.max(0, NUDGE_INTERVAL - idleFor))
				end)
				task.wait(0.25)
			end
		end))

		genv.__StandaloneAntiAfkPanel = frame
	end)
end

-- Start everything.
hookAfkRemotes()
watchPrompts()
startLoop()
armAutoReexec()

log(string.format("Running (nudge=%ds, reconnect=%s). Click the header to unload.",
	NUDGE_INTERVAL, tostring(RECONNECT)))
