-- IndoHangout/main.lua
-- Central loader: config → gui → core → feature modules.
-- Handles duplicate-run guard, cleanup wrapping, and module orchestration.

local BASE_URL = ...

-- ----------------------------------------------------------------------------
-- DUPLICATE-RUN GUARD
-- ----------------------------------------------------------------------------
-- We use _G.INDOHANGOUT_RUNNING to detect whether another copy is already
-- running. If a previous copy is alive, _G.__IndoHangout_Destroy exists.
-- If the flag is set but destroyAll is gone, the previous copy crashed and we
-- clear the stale flag and continue.
do
    if _G.INDOHANGOUT_RUNNING then
        if type(_G.__IndoHangout_Destroy) == "function" then
            warn("[IndoHangout] Script is already running — skipping duplicate execution.")
            return
        end
        warn("[IndoHangout] Stale run flag found (previous copy crashed) — continuing.")
        _G.INDOHANGOUT_RUNNING = nil
    end
    _G.INDOHANGOUT_RUNNING = true
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

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local function loadModule(name)
    return compile(fetch(BASE_URL .. "modules/" .. name .. ".lua", name), name)
end

-- Forward declaration so showErrorGui can reference the theme safely.
local config = nil

-- Error GUI fallback (same pattern as IndoVoice's showErrorGui)
local function showErrorGui(msg)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local THEME = (config and config.Theme) or {}
    local errGui = Instance.new("ScreenGui")
    errGui.Name = "IndoHangout_Error"
    errGui.ResetOnSpawn = false
    errGui.DisplayOrder = 9999
    pcall(function() errGui.Parent = game:GetService("CoreGui") end)
    if not errGui.Parent then errGui.Parent = lp:WaitForChild("PlayerGui") end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 120)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = THEME.panel or Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Parent = errGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = THEME.danger or Color3.fromRGB(222, 92, 92)
    stroke.Thickness = 1.5

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 1, -20)
    lbl.Position = UDim2.new(0, 10, 0, 10)
    lbl.BackgroundTransparency = 1
    lbl.Text = "IndoHangout Error:\n" .. tostring(msg)
    lbl.TextColor3 = THEME.danger or Color3.fromRGB(222, 92, 92)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Parent = frame

    task.delay(15, function() pcall(function() errGui:Destroy() end) end)
end

-- ----------------------------------------------------------------------------
-- LOAD CONFIG
-- ----------------------------------------------------------------------------
local configChunk = compile(fetch(BASE_URL .. "config.lua", "config.lua"), "config.lua")
config = deepCopy(configChunk())
assert(type(config) == "table", "config.lua must return a table")

-- ----------------------------------------------------------------------------
-- SESSION (lightweight persistence)
-- ----------------------------------------------------------------------------
local Session = nil
pcall(function()
    local sessionChunk = compile(fetch(BASE_URL .. "session.lua", "session.lua"), "session.lua")
    local sessionFactory = sessionChunk()
    if type(sessionFactory) == "function" then
        Session = sessionFactory(config)
    end
end)

-- ----------------------------------------------------------------------------
-- AUTH GATE
-- ----------------------------------------------------------------------------
-- Blocks until the correct password is entered (or attempts run out).
-- The expected password is reconstructed at runtime: XOR-decode -> base64-decode.
local function base64Decode(s)
    local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, #b64chars do
        lookup[b64chars:sub(i, i)] = i - 1
    end
    s = s:gsub("[^" .. b64chars .. "=]", "")
    local out = {}
    local i = 1
    while i <= #s do
        local a = lookup[s:sub(i, i)] or 0
        local b = lookup[s:sub(i + 1, i + 1)]
        local c = lookup[s:sub(i + 2, i + 2)]
        local d = lookup[s:sub(i + 3, i + 3)]
        local n = a * 262144 + (b or 0) * 4096 + (c or 0) * 64 + (d or 0)
        local b1 = math.floor(n / 65536) % 256
        local b2 = math.floor(n / 256) % 256
        local b3 = n % 256
        table.insert(out, string.char(b1))
        if s:sub(i + 2, i + 2) ~= "=" and s:sub(i + 2, i + 2) ~= "" then
            table.insert(out, string.char(b2))
        end
        if s:sub(i + 3, i + 3) ~= "=" and s:sub(i + 3, i + 3) ~= "" then
            table.insert(out, string.char(b3))
        end
        i += 4
    end
    return table.concat(out)
end

local function expectedPassword()
    local auth = config.Auth
    if not auth or not auth.Enabled then return nil end
    local key = auth.XorKey or 0
    local chars = {}
    for _, byte in ipairs(auth.TokenBytes or {}) do
        table.insert(chars, string.char(bit32 and bit32.bxor(byte, key) or (byte ~ key)))
    end
    local b64 = table.concat(chars)
    return base64Decode(b64)
end

local function runAuthGate()
    local auth = config.Auth
    if not auth or not auth.Enabled then return true end
    local expected = expectedPassword()
    if not expected then return true end

    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local THEME = config.Theme or {}

    local gateGui = Instance.new("ScreenGui")
    gateGui.Name = "IndoHangout_Auth"
    gateGui.ResetOnSpawn = false
    gateGui.IgnoreGuiInset = true
    gateGui.DisplayOrder = 10000
    local parented = pcall(function() gateGui.Parent = game:GetService("CoreGui") end)
    if not parented or not gateGui.Parent then
        gateGui.Parent = lp:WaitForChild("PlayerGui")
    end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 150)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = THEME.bg or Color3.fromRGB(16, 16, 19)
    frame.BorderSizePixel = 0
    frame.Parent = gateGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = THEME.border or Color3.fromRGB(46, 48, 58)
    stroke.Thickness = 1

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "IndoHangout"
    title.TextColor3 = THEME.accentGlow or Color3.fromRGB(160, 190, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -20, 0, 16)
    hint.Position = UDim2.new(0, 10, 0, 34)
    hint.BackgroundTransparency = 1
    hint.Text = auth.Hint or "Enter access password"
    hint.TextColor3 = THEME.dim or Color3.fromRGB(168, 172, 184)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -20, 0, 30)
    box.Position = UDim2.new(0, 10, 0, 54)
    box.BackgroundColor3 = THEME.surface or Color3.fromRGB(34, 34, 42)
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = "Password"
    box.TextColor3 = THEME.text or Color3.fromRGB(238, 238, 242)
    box.PlaceholderColor3 = THEME.faint or Color3.fromRGB(112, 116, 128)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 30)
    btn.Position = UDim2.new(0, 10, 0, 94)
    btn.BackgroundColor3 = THEME.accentDark or Color3.fromRGB(42, 72, 145)
    btn.BorderSizePixel = 0
    btn.Text = "Unlock"
    btn.TextColor3 = THEME.text or Color3.fromRGB(238, 238, 242)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local attempts = 0
    local maxAttempts = auth.MaxAttempts or 5
    local success = false

    local function trySubmit()
        if box.Text == expected then
            success = true
        else
            attempts += 1
            hint.Text = ("Incorrect password (%d/%d)"):format(attempts, maxAttempts)
            hint.TextColor3 = THEME.danger or Color3.fromRGB(222, 92, 92)
        end
    end

    btn.MouseButton1Click:Connect(trySubmit)
    box.FocusLost:Connect(function(enterPressed)
        if enterPressed then trySubmit() end
    end)

    while not success and attempts < maxAttempts do
        task.wait(0.1)
    end

    pcall(function() gateGui:Destroy() end)
    return success
end

if not runAuthGate() then
    _G.INDOHANGOUT_RUNNING = nil
    showErrorGui("Access denied: invalid password or too many attempts.")
    return
end

-- ----------------------------------------------------------------------------
-- LOAD GUI
-- ----------------------------------------------------------------------------
local guiChunk = compile(fetch(BASE_URL .. "gui.lua", "gui.lua"), "gui.lua")
local guiFactory = guiChunk()
if type(guiFactory) ~= "function" then
    showErrorGui("gui.lua returned: " .. type(guiFactory) .. " (expected function)")
    return
end

local guiOk, gui = pcall(guiFactory, config)
if not guiOk then
    showErrorGui("gui.lua execution failed:\n" .. tostring(gui))
    return
end

-- ----------------------------------------------------------------------------
-- LOAD CORE
-- ----------------------------------------------------------------------------
local coreChunk = compile(fetch(BASE_URL .. "core.lua", "core.lua"), "core.lua")
local coreFactory = coreChunk()
if type(coreFactory) ~= "function" then
    showErrorGui("core.lua returned: " .. type(coreFactory) .. " (expected function)")
    return
end

local coreOk, ctx = pcall(coreFactory, gui, config)
if not coreOk then
    showErrorGui("core.lua execution failed:\n" .. tostring(ctx))
    return
end

-- ----------------------------------------------------------------------------
-- WRAP DESTROY TO RELEASE RUN FLAG
-- ----------------------------------------------------------------------------
-- When the user clicks Close or the script unloads, we want to clear the
-- run flag so re-executing immediately starts a fresh copy.
if ctx and type(ctx.destroyAll) == "function" then
    local origDestroyAll = ctx.destroyAll
    ctx.destroyAll = function()
        _G.INDOHANGOUT_RUNNING = nil
        origDestroyAll()
    end
    -- Also wrap the global handle so external unload paths clear the run flag.
    local origGlobalDestroy = _G.__IndoHangout_Destroy
    _G.__IndoHangout_Destroy = function()
        _G.INDOHANGOUT_RUNNING = nil
        if type(origGlobalDestroy) == "function" then
            origGlobalDestroy()
        else
            origDestroyAll()
        end
    end
end

-- ----------------------------------------------------------------------------
-- LOAD UTILITIES MODULE
-- ----------------------------------------------------------------------------
local Utils = nil
pcall(function()
    local utilsChunk = loadModule("utils")
    local utilsFactory = utilsChunk()
    if type(utilsFactory) == "table" then
        Utils = utilsFactory
    end
end)
ctx.Utils = Utils

-- ----------------------------------------------------------------------------
-- LOAD FEATURE MODULES
-- ----------------------------------------------------------------------------
-- Order matters: settings last so its autoload can use the already-loaded
-- fishing/mining/misc modules.
local modules = { "fishing", "mining", "misc", "settings" }
for _, name in ipairs(modules) do
    local ok, err = pcall(function()
        local modChunk = loadModule(name)
        local modFactory = modChunk()
        if type(modFactory) == "function" then
            local instance = modFactory(ctx)
            if type(instance) == "table" then
                ctx[name] = instance
                if type(instance.Init) == "function" then
                    instance.Init()
                end
            end
        else
            showErrorGui("Module '" .. name .. "' did not return a function")
        end
    end)
    if not ok then
        showErrorGui("Module '" .. name .. "' failed:\n" .. tostring(err))
    end
end
