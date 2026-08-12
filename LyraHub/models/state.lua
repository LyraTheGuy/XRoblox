-- LyraHub/models/state.lua
-- Model layer: minimal observable state store.
--
-- Views never write state directly. Controllers publish via model.set() and
-- subscribe via model.onChange() so the view re-renders when data changes.

return function()
    local values = {}
    local watchers = {}

    local model = {}

    function model.set(key, value)
        local old = values[key]
        if old == value then
            return
        end
        values[key] = value
        local list = watchers[key]
        if list then
            for _, fn in ipairs(list) do
                pcall(fn, value, old)
            end
        end
    end

    function model.get(key)
        return values[key]
    end

    -- Registers a listener; returns an unsubscribe function.
    function model.onChange(key, fn)
        watchers[key] = watchers[key] or {}
        table.insert(watchers[key], fn)
        return function()
            local list = watchers[key]
            if not list then
                return
            end
            for i, f in ipairs(list) do
                if f == fn then
                    table.remove(list, i)
                    break
                end
            end
        end
    end

    function model.destroy()
        table.clear(watchers)
        table.clear(values)
    end

    return model
end
