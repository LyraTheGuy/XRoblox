-- IndoHangout/modules/utils.lua
-- Small generic helpers. No feature logic tied to specific game paths.

local Utils = {}

-- Safely resolve a descendant path, returning nil on any missing component.
-- Example: Utils.resolve(container, {"Events", "RemoteEvent", "Rod"})
function Utils.resolve(container, path)
    local obj = container
    for _, childName in ipairs(path or {}) do
        if type(obj) ~= "Instance" then
            return nil, "expected Instance, found " .. type(obj)
        end
        obj = obj:FindFirstChild(childName)
        if not obj then
            return nil, "missing: " .. tostring(childName)
        end
    end
    return obj
end

-- Wait for a path with a timeout, using WaitForChild with per-level timeouts.
function Utils.waitForPath(container, path, timeout)
    local deadline = tick() + (timeout or 15)
    local obj = container
    for _, childName in ipairs(path or {}) do
        if type(obj) ~= "Instance" then return nil end
        local found = nil
        local ok = pcall(function()
            found = obj:WaitForChild(childName, math.max(1, deadline - tick()))
        end)
        if ok and found and tick() <= deadline then
            obj = found
        else
            return nil, "timeout waiting for " .. tostring(childName)
        end
    end
    return obj
end

-- Case-insensitive containment.
function Utils.looseContains(haystack, needle)
    if type(haystack) ~= "string" or type(needle) ~= "string" then return false end
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

-- Round-robin small delay (no sleepspike). Delay can be fractional seconds.
function Utils.wait(seconds)
    if seconds <= 0 then return end
    local endTime = tick() + seconds
    while tick() < endTime do
        task.wait(math.min(0.05, seconds))
    end
end

-- Clamp helper.
function Utils.clamp(v, min, max)
    return math.max(min or v, math.min(max or v, v))
end

-- Safe interaction: only fire when close enough (within tolerance studs).
function Utils.isCloseTo(targetPos, tolerance)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or type(targetPos) ~= "Vector3" then
        -- Vector3 type in Luau: use typeof is safer
        return false
    end
    return (hrp.Position - targetPos).Magnitude <= (tolerance or 1)
end

-- List tools in Backpack and Character that match an exclusion filter.
-- Excludes tools whose names contain 'rod' or 'pickaxe' by default when
-- excludeCommonTools is truthy.
function Utils.listUsableTools()
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local out = {}
    local seen = {}
    local function addTool(tool)
        if type(tool) ~= "Instance" or not tool:IsA("Tool") then return end
        local name = tool.Name or ""
        local lower = name:lower()
        if lower:find("rod", 1, true) or lower:find("pickaxe", 1, true) then
            return -- common held/equip tools are excluded
        end
        if not seen[name] then
            seen[name] = true
            table.insert(out, tool)
        end
    end
    local backpack = lp:FindFirstChild("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            addTool(child)
        end
    end
    local char = lp.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            addTool(child)
        end
    end
    return out
end

-- Find a tool in Backpack or Character by loose name match (default: rods).
function Utils.findTool(looseName)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local pattern = (looseName or "rod"):lower()

    local function scan(container)
        if not container then return nil end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") and child.Name and child.Name:lower():find(pattern, 1, true) then
                return child
            end
        end
        return nil
    end
    return scan(lp:FindFirstChild("Backpack")) or scan(lp.Character)
end

-- Equip a tool into the character (via Humanoid:EquipTool).
function Utils.equipTool(tool)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or not tool or not tool:IsA("Tool") then return false end
    if tool.Parent ~= char then
        if tool.Parent ~= lp:FindFirstChild("Backpack") then
            tool.Parent = lp:FindFirstChild("Backpack")
        end
    end
    if tool.Parent == char then
        return true -- already equipped
    end
    local ok = pcall(function()
        hum:EquipTool(tool)
    end)
    return ok
end

-- Disable/enable jumping on the local character's humanoid.
function Utils.setJumpEnabled(enabled)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local ok = pcall(function()
        if enabled then
            hum.Jump = true
        else
            hum.Jump = false
        end
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, enabled)
    end)
    return ok
end

-- Serialize CFrame to a JSON-friendly table.
function Utils.cframeToTable(cf)
    if cf == nil or (type(cf) == "userdata" and typeof(cf) ~= "CFrame") then return nil end
    local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:GetComponents()
    return {
        __type = "CFrame",
        X = x, Y = y, Z = z,
        R00 = R00, R01 = R01, R02 = R02,
        R10 = R10, R11 = R11, R12 = R12,
        R20 = R20, R21 = R21, R22 = R22,
    }
end

-- Reconstruct a CFrame from the table produced by cframeToTable.
function Utils.tableToCframe(tbl)
    if type(tbl) ~= "table" or tbl.__type ~= "CFrame" then return nil end
    local ok, cf = pcall(function()
        return CFrame.new(
            tbl.X or 0, tbl.Y or 0, tbl.Z or 0,
            tbl.R00 or 1, tbl.R01 or 0, tbl.R02 or 0,
            tbl.R10 or 0, tbl.R11 or 1, tbl.R12 or 0,
            tbl.R20 or 0, tbl.R21 or 0, tbl.R22 or 1
        )
    end)
    if ok then return cf end
    return nil
end

return Utils