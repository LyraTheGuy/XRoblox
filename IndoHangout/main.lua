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
