-- LyraHub/main.lua
-- Composition root. Fetches + compiles every module in MVC order and builds
-- the dependency graph:
--
--     config -> models/state -> views/components/shared -> components
--            -> views/main -> controllers/main -> controllers/demo
--
-- Controllers run after the view exists and receive (view, model, config).

local BASE_URL = ...

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

    task.delay(15, function()
        pcall(function() errGui:Destroy() end)
    end)
end

-- 1. Config (theme + defaults)
local config = compile(fetch(BASE_URL .. "config.lua", "config.lua"), "config.lua")()
assert(type(config) == "table", "config.lua must return a table")

-- 2. Model (observable store)
-- state.lua returns a factory function; call the chunk to get the factory,
-- then call the factory (no args) to get the model table.
local model = compile(fetch(BASE_URL .. "models/state.lua", "state.lua"), "state.lua")()()

-- 3. View primitives
-- shared.lua returns function(theme); call the chunk to get the factory,
-- then call the factory with config to get the shared helper table.
local shared = compile(fetch(BASE_URL .. "views/components/shared.lua", "shared.lua"), "shared.lua")()(config)

local components = { shared = shared }
for _, name in ipairs({ "button", "toggle", "dropdown", "slider", "keybind", "textinput", "colorpicker", "toast", "updatecheck" }) do
    local factory = compile(fetch(BASE_URL .. "views/components/" .. name .. ".lua", name), name)()
    components[name] = factory(config, shared)
end

-- 4. View (window chrome + pages)
local viewFactory = compile(fetch(BASE_URL .. "views/main.lua", "views/main.lua"), "views/main.lua")()
local viewOk, view = pcall(viewFactory, config, components)
if not viewOk then
    showErrorGui("views/main.lua execution failed:\n" .. tostring(view))
    return
end

-- 5. Controllers — main first (owns window lifecycle), demo second (binds
--    the components to the store). One failing controller never blocks the rest.
for _, name in ipairs({ "main", "demo" }) do
    local ok, err = pcall(function()
        local factory = compile(fetch(BASE_URL .. "controllers/" .. name .. ".lua", name), name)()
        if type(factory) == "function" then
            factory(view, model, config)
        else
            error("controller '" .. name .. "' did not return a function")
        end
    end)
    if not ok then
        showErrorGui("Controller '" .. name .. "' failed:\n" .. tostring(err))
    end
end

-- Update check: compare the running build against the live raw config
if components.updatecheck and components.updatecheck.Check and config.Build then
    components.updatecheck.Check({ LocalBuild = config.Build, ConfigURL = BASE_URL .. "config.lua" })
end
