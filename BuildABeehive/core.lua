-- BuildABeehive/core.lua
-- Shared services, state, helper functions, and cleanup for honey automation modules

return function(gui, config)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local StatsService = game:GetService("Stats")
	local UserInputService = game:GetService("UserInputService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local localPlayer = Players.LocalPlayer
	local ctx = {
		gui = gui,
		config = config,
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		LocalPlayer = localPlayer,
		PlayerGui = localPlayer:WaitForChild("PlayerGui"),
		Destroyed = false,
		minimized = false,
		AutoCollect = false,
		AutoExtract = false,
		AutoSell = false,
		AutoDepositAurora = false,
		AutoBuySeed = false,
		collectInterval = 2,
		sellInterval = 5,
		auroraInterval = 5,
		buySeedInterval = 120,
		buySeedId = "Bamboo",
		FLOWER_LIST = {
			"Lavender",
			"Daisy",
			"Clover",
			"Sunflower",
			"Dahlia",
			"Bamboo",
			"Tulip",
			"AloeFlower",
			"VenusFlyTrap",
			"MorningGlory",
			"Gourd",
			"FireBlossom",
			"Bluebell",
			"Lily",
			"Rose",
			"Cactus",
			"KniphofiaUvaria",
			"AquilegiaCoerulea",
			"MartagonLily",
		},
		selectedFlowers = { Bamboo = true },
		fps = 0,
		ping = 0,
		playerCount = #Players:GetPlayers(),
		totalHive = 0,
		connections = {},
	}

	ctx.RunService = RunService

	-- Remotes live deep inside the game's framework hierarchy. Resolve them
	-- defensively so a missing/renamed folder can never crash the whole hub
	-- ("Framework is not a valid member of ReplicatedStorage"). A nil remote
	-- simply leaves that automation inert — the modules wrap every FireServer
	-- in pcall — and a delayed re-resolve picks the remotes up if the
	-- framework loads after this script starts.
	local REMOTE_PATHS = {
		ExtractRemote = { "Framework", "Features", "HoneySystem", "HiveUtil", "RemoteEvent" },
		SellRemote = { "Framework", "Features", "HoneySystem", "HoneyUtil", "RemoteEvent" },
		GameRemote = { "Framework", "Features", "GameEvent", "GameEventUtil", "RemoteEvent" },
		FlowerRemote = { "Framework", "Features", "HoneySystem", "FlowerUtil", "RemoteEvent" },
	}

	local function resolveRemotes()
		local allFound = true
		for name, path in pairs(REMOTE_PATHS) do
			local current = ReplicatedStorage
			for _, part in ipairs(path) do
				current = current:FindFirstChild(part)
				if not current then
					break
				end
			end
			ctx[name] = current
			if not current then
				allFound = false
			end
		end
		return allFound
	end

	-- Resolve now; if the framework isn't present yet, retry once a second for
	-- up to 30s (game structure often populates after the client connects).
	if not resolveRemotes() then
		task.spawn(function()
			for _ = 1, 30 do
				task.wait(1)
				if ctx.Destroyed or resolveRemotes() then
					break
				end
			end
		end)
	end

	local function bind(signal, fn)
		local connection = signal:Connect(fn)
		table.insert(ctx.connections, connection)
		return connection
	end
	ctx.bind = bind

	local function getPlayerCount()
		return #Players:GetPlayers()
	end
	ctx.getPlayerCount = getPlayerCount

	local function setButtonState(button, enabled, label)
		if not button then
			return
		end

		button.Text = label .. ": " .. (enabled and "ON" or "OFF")
		button.BackgroundColor3 = enabled and (config.Theme and config.Theme.success or Color3.fromRGB(60, 180, 60))
			or (config.Theme and config.Theme.danger or Color3.fromRGB(180, 60, 60))
	end
	ctx.setButtonState = setButtonState

	local function readInterval(input, fallback)
		if not input then
			return fallback
		end

		-- LyraHub textinput views: read via GetText, write via SetText with
		-- notifyChange=false so programmatic writes can't echo into OnChanged.
		-- Skip the write while the field is focused so committing one field can't
		-- clobber text the user is actively typing in another.
		local value = tonumber(input.GetText())
		if not value then
			if not input.Box:IsFocused() then
				input.SetText(tostring(fallback), false)
			end
			return fallback
		end

		value = math.clamp(value, 1, 3600)
		if not input.Box:IsFocused() then
			input.SetText(tostring(value), false)
		end
		return value
	end
	ctx.readInterval = readInterval

	local function syncIntervals()
		ctx.collectInterval = readInterval(gui.CollectIntervalInput, 2)
		ctx.sellInterval = readInterval(gui.SellIntervalInput, 5)
		ctx.auroraInterval = readInterval(gui.AuroraIntervalInput, 5)
		ctx.buySeedInterval = readInterval(gui.BuySeedIntervalInput, 120)

		if gui.BuySeedInput then
			local seedId = tostring(gui.BuySeedInput.GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if seedId == "" then
				seedId = "Bamboo"
			end
			ctx.buySeedId = seedId
			if not gui.BuySeedInput.Box:IsFocused() then
				gui.BuySeedInput.SetText(ctx.buySeedId, false)
			end
		end
	end
	ctx.syncIntervals = syncIntervals

	-- Per-category action counters (incremented by the feature modules).
	ctx.counts = {}

	-- Persist counters to a settings file so they survive script reloads.
	-- Uses the executor file API (writefile/readfile/isfile) guarded with pcall,
	-- same pattern as IndoVoice's LyraHub_Settings.json.
	local COUNTERS_FILE = "BuildABeehive_Counters.json"
	local COUNTERS_SAVE_INTERVAL = 1 -- throttle: at most one write per second
	local lastCountersSave = tick()

	local function saveCounters()
		pcall(function()
			local HttpService = game:GetService("HttpService")
			writefile(COUNTERS_FILE, HttpService:JSONEncode(ctx.counts))
		end)
	end
	ctx.saveCounters = saveCounters

	local function loadCounters()
		pcall(function()
			if isfile and isfile(COUNTERS_FILE) then
				local HttpService = game:GetService("HttpService")
				local loaded = HttpService:JSONDecode(readfile(COUNTERS_FILE))
				if type(loaded) == "table" then
					for key, value in pairs(loaded) do
						if type(value) == "number" then
							ctx.counts[key] = value
						end
					end
				end
			end
		end)
	end
	loadCounters()

	ctx.addCount = function(category, amount)
		local key = tostring(category or "unknown")
		ctx.counts[key] = (ctx.counts[key] or 0) + (amount or 1)

		-- Persist with a 1s throttle: bursts of actions (e.g. per-hive collect
		-- ticks) don't spam the disk, and a hard kill loses at most ~1s.
		local now = tick()
		if now - lastCountersSave >= COUNTERS_SAVE_INTERVAL then
			lastCountersSave = now
			saveCounters()
		end
	end

	local function setMinimized(minimized)
		ctx.minimized = minimized
		if gui.Main then
			gui.Main.Visible = not minimized
		end
		if gui.MinimizedPanel then
			gui.MinimizedPanel.Visible = minimized
		end
		if gui.Shadow then
			gui.Shadow.Visible = not minimized
		end
	end
	ctx.setMinimized = setMinimized

	-- Compact number formatting for large action counters (1.2k / 3.4M / 1.1B)
	local function formatCount(n)
		n = tonumber(n) or 0
		if n >= 1e9 then
			return string.format("%.1fB", n / 1e9)
		elseif n >= 1e6 then
			return string.format("%.1fM", n / 1e6)
		elseif n >= 1e3 then
			return string.format("%.1fK", n / 1e3)
		end
		return tostring(math.floor(n))
	end
	ctx.formatCount = formatCount

	local function updateStats()
		local hives = ctx.getMyHives()
		local hiveCount = hives and #hives:GetChildren() or 0
		local active = ctx.AutoCollect or ctx.AutoSell or ctx.AutoDepositAurora or ctx.AutoBuySeed
		local theme = config.Theme or {}

		ctx.playerCount = getPlayerCount()
		ctx.totalHive = hiveCount

		if gui.StatusLbl then
			gui.StatusLbl.Text = "Status: " .. (active and "ON" or "OFF")
			gui.StatusLbl.TextColor3 = active and (theme.success or Color3.fromRGB(80, 220, 140))
				or (theme.danger or Color3.fromRGB(255, 80, 100))
		end

		if gui.Stats then
			gui.Stats.FPSVal.Text = tostring(ctx.fps)
			gui.Stats.PingVal.Text = tostring(ctx.ping) .. " ms"
			gui.Stats.PlayerCountVal.Text = tostring(ctx.playerCount)
			gui.Stats.TotalHiveVal.Text = tostring(ctx.totalHive)
		end

		if gui.MiniStats then
			gui.MiniStats.FPSVal.Text = tostring(ctx.fps)
			gui.MiniStats.PingVal.Text = tostring(ctx.ping)
			gui.MiniStats.PlayerCountVal.Text = tostring(ctx.playerCount)
			gui.MiniStats.TotalHiveVal.Text = tostring(ctx.totalHive)
		end

		if gui.ActionStats then
			gui.ActionStats.CollectVal.Text = formatCount(ctx.counts.collect)
			gui.ActionStats.SellVal.Text = formatCount(ctx.counts.sell)
			gui.ActionStats.AuroraVal.Text = formatCount(ctx.counts.aurora)
			gui.ActionStats.BuySeedVal.Text = formatCount(ctx.counts["buy_seed"])
		end
		if gui.MiniActionStats then
			gui.MiniActionStats.CollectVal.Text = formatCount(ctx.counts.collect)
			gui.MiniActionStats.SellVal.Text = formatCount(ctx.counts.sell)
			gui.MiniActionStats.AuroraVal.Text = formatCount(ctx.counts.aurora)
			gui.MiniActionStats.BuySeedVal.Text = formatCount(ctx.counts["buy_seed"])
		end

		if gui.CollectButton then
			setButtonState(gui.CollectButton, ctx.AutoCollect, "Collect")
		end
		if gui.SellButton then
			setButtonState(gui.SellButton, ctx.AutoSell, "Sell")
		end
		if gui.DepositAuroraButton then
			setButtonState(gui.DepositAuroraButton, ctx.AutoDepositAurora, "Aurora")
		end
		if gui.BuySeedButton then
			setButtonState(gui.BuySeedButton, ctx.AutoBuySeed, "Buy Seed")
		end

		if gui.CollectIntervalInput and not gui.CollectIntervalInput.Box:IsFocused() then
			gui.CollectIntervalInput.SetText(tostring(ctx.collectInterval), false)
		end
		if gui.SellIntervalInput and not gui.SellIntervalInput.Box:IsFocused() then
			gui.SellIntervalInput.SetText(tostring(ctx.sellInterval), false)
		end
		if gui.AuroraIntervalInput and not gui.AuroraIntervalInput.Box:IsFocused() then
			gui.AuroraIntervalInput.SetText(tostring(ctx.auroraInterval), false)
		end
		if gui.BuySeedIntervalInput and not gui.BuySeedIntervalInput.Box:IsFocused() then
			gui.BuySeedIntervalInput.SetText(tostring(ctx.buySeedInterval), false)
		end
		if gui.BuySeedInput and not gui.BuySeedInput.Box:IsFocused() then
			gui.BuySeedInput.SetText(ctx.buySeedId, false)
		end
	end
	ctx.updateStats = updateStats

	ctx.updateStatus = updateStats

	local frameCount = 0
	local fpsAccum = 0
	local lastUpdate = tick()

	bind(RunService.Heartbeat, function(dt)
		if ctx.Destroyed then
			return
		end

		frameCount = frameCount + 1
		fpsAccum = fpsAccum + dt

		local now = tick()
		if now - lastUpdate < 0.5 then
			return
		end

		lastUpdate = now

		if fpsAccum > 0 then
			ctx.fps = math.floor(frameCount / fpsAccum + 0.5)
		end
		frameCount = 0
		fpsAccum = 0

		local ok, pingMs = pcall(function()
			return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if ok then
			ctx.ping = math.floor(pingMs + 0.5)
		end

		updateStats()
	end)

	local function getMyPlot()
		local plots = workspace:FindFirstChild("Plots")
		if not plots then
			return nil
		end

		for _, plot in ipairs(plots:GetChildren()) do
			local owner = plot:FindFirstChild("Owner")
			if owner and owner.Value == localPlayer then
				return plot
			end
		end

		return nil
	end
	ctx.getMyPlot = getMyPlot

	local function getMyHives()
		local plot = getMyPlot()
		if plot then
			return plot:FindFirstChild("Hives")
		end
		return nil
	end
	ctx.getMyHives = getMyHives

	local function beginDrag(target, input)
		ctx.draggingUI = true
		ctx.dragTarget = target
		ctx.dragStart = input.Position
		ctx.startPos = target.Position
		ctx.shadowStart = gui.Shadow and gui.Shadow.Position
		ctx.dragInput = input
	end
	ctx.beginDrag = beginDrag

	local function endDrag(input)
		if ctx.dragInput == input then
			ctx.draggingUI = false
			ctx.dragTarget = nil
			ctx.dragInput = nil
		end
	end
	ctx.endDrag = endDrag

	-- NOTE: the top bar is covered by a full-width transparent DragHit button,
	-- so InputBegan on the TopBar frame itself almost never fires. Bind the
	-- DragHit button (returned by gui.lua) instead, or dragging breaks.
	bind(gui.DragHit.InputBegan, function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			beginDrag(gui.Frame, input)
		end
	end)

	bind(gui.MiniDragHit.InputBegan, function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			beginDrag(gui.MinimizedPanel, input)
		end
	end)

	bind(UserInputService.InputChanged, function(input)
		if not ctx.draggingUI or input ~= ctx.dragInput then
			return
		end

		local delta = input.Position - ctx.dragStart
		local position = ctx.startPos
		ctx.dragTarget.Position =
			UDim2.new(position.X.Scale, position.X.Offset + delta.X, position.Y.Scale, position.Y.Offset + delta.Y)

		-- Keep the soft drop shadow glued to the main window while dragging
		-- (shared.shadow only positions it once at creation).
		if gui.Shadow and ctx.dragTarget == gui.Main and ctx.shadowStart then
			local sp = ctx.shadowStart
			gui.Shadow.Position =
				UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
		end
	end)

	bind(UserInputService.InputEnded, function(input)
		endDrag(input)
	end)

	bind(gui.MinBtn.MouseButton1Click, function()
		setMinimized(true)
	end)

	bind(gui.MiniExpand.MouseButton1Click, function()
		setMinimized(false)
	end)

	if gui.TabButtons then
		bind(gui.TabButtons.Overview.MouseButton1Click, function()
			if gui.SetTab then
				gui.SetTab("Overview")
			end
		end)

		bind(gui.TabButtons.Actions.MouseButton1Click, function()
			if gui.SetTab then
				gui.SetTab("Actions")
			end
		end)

		if gui.TabButtons.Buy then
			bind(gui.TabButtons.Buy.MouseButton1Click, function()
				if gui.SetTab then
					gui.SetTab("Buy")
				end
			end)
		end
	end

	-- Commit-on-focus-lost: the LyraHub textinput fires OnChanged on blur, so
	-- subscribing here syncs the ctx intervals/seed id whenever any of the five
	-- fields is committed (component-internal value update, then our read-back).
	for _, input in ipairs({
		gui.CollectIntervalInput,
		gui.SellIntervalInput,
		gui.AuroraIntervalInput,
		gui.BuySeedIntervalInput,
		gui.BuySeedInput,
	}) do
		if input then
			input.OnChanged(function()
				ctx.syncIntervals()
			end)
		end
	end

	-- Reset action counters (fresh session stats without reloading)
	if gui.ResetCountersBtn then
		bind(gui.ResetCountersBtn.MouseButton1Click, function()
			table.clear(ctx.counts)
			saveCounters() -- zero the persisted file too, so a reload starts fresh
			updateStats()
		end)
	end

	local function destroyAll()
		ctx.Destroyed = true
		saveCounters()
		for _, connection in ipairs(ctx.connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(ctx.connections)
		pcall(function()
			gui.ScreenGui:Destroy()
		end)
	end
	ctx.destroyAll = destroyAll
	_G.__BuildABeehive_Destroy = destroyAll

	bind(gui.CloseBtn.MouseButton1Click, function()
		ctx.destroyAll()
	end)

	setMinimized(false)
	updateStats()

	return ctx
end
