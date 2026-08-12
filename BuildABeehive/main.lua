-- BuildABeehive/main.lua
-- Shared loader for config, gui, core, then feature modules

local BASE_URL = ...

-- Derive the LyraHub folder URL from the same repo/branch (this folder's URL
-- is "<...>/staging/BuildABeehive/", the kit lives in "<...>/staging/LyraHub/").
local LYRAHUB_URL = BASE_URL:gsub("/BuildABeehive/", "/LyraHub/")

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

local function loadModule(name)
    return compile(fetch(BASE_URL .. "modules/" .. name .. ".lua", name), name)
end

local function showErrorGui(msg)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local errGui = Instance.new("ScreenGui")
    errGui.Name = "BuildABeehive_Error"
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
    lbl.Text = "BuildABeehive Error:\n" .. tostring(msg)
    lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Parent = frame

    task.delay(15, function()
        pcall(function()
            errGui:Destroy()
        end)
    end)
end

local configChunk = compile(fetch(BASE_URL .. "config.lua", "config.lua"), "config.lua")
local config = configChunk()
assert(type(config) == "table", "config.lua must return a table")

-- LyraHub UI kit (shared primitives + component factories)
local shared = compile(fetch(LYRAHUB_URL .. "views/components/shared.lua", "shared.lua"), "shared.lua")(config)
local components = { shared = shared }
for _, name in ipairs({ "button", "textinput" }) do
    local factory = compile(fetch(LYRAHUB_URL .. "views/components/" .. name .. ".lua", name), name)()
    components[name] = factory(config, shared)
end

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

local modules = {"auto_collect", "auto_sell", "auto_deposit_aurora", "auto_buy_seed"}
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