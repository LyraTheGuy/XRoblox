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

local configChunk = compile(fetch(BASE_URL .. "config.lua", "config.lua"), "config.lua")
local config = configChunk()
assert(type(config) == "table", "config.lua must return a table")

-- LyraHub UI kit (shared primitives + component factories)
-- shared.lua returns function(theme): call the chunk to get the factory,
-- then call the factory with config to get the shared helper table.
local components = {}
local kitOk, kitErr = pcall(function()
    local shared = compile(fetch(LYRAHUB_URL .. "views/components/shared.lua", "shared.lua"), "shared.lua")()(config)
    components.shared = shared
    for _, name in ipairs({ "button", "textinput", "toast", "updatecheck" }) do
        local factory = compile(fetch(LYRAHUB_URL .. "views/components/" .. name .. ".lua", name), name)()
        components[name] = factory(config, shared)
    end
end)
if not kitOk then
    warn("[LyraHub] Kit load failed: " .. tostring(kitErr))
    showKitToast("LyraHub UI kit failed to load from the raw GitHub link.\nPush the latest LyraHub/ folder to GitHub, then re-run.")
    return
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

-- Update check: compare the running build against the live raw config
if components.updatecheck and components.updatecheck.Check and config.Build then
    components.updatecheck.Check({ LocalBuild = config.Build, ConfigURL = BASE_URL .. "config.lua" })
end