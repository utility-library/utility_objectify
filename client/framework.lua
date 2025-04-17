-- v1.1
local AppendMethod = function(self, toAppendFuncName, funcName)
    local _original = self[funcName]

    self[funcName] = function(...)
        if _original then _original(...) end
        self[toAppendFuncName](...)
    end
end

class BaseEntity {
    constructor = function()
        AppendMethod(self, "_OnSpawn", "OnSpawn")
        AppendMethod(self, "_OnDestroy", "OnDestroy")
    end,

    _OnSpawn = function()
        if self.listenedStates and next(self.listenedStates) then
            for key, listeners in pairs(self.listenedStates) do
                for _, data in pairs(listeners) do
                    if data.value ~= nil then
                        if self.state[key] ~= data.value then
                            continue
                        end
                    end
    
                    data.fn(self.state[key], true)
                end
            end

            self.__stateChangeHandler = UtilityNet.AddStateBagChangeHandler(self.id, function(key, value)
                local listeners = self.listenedStates[key]

                if not listeners then
                    return
                end

                for _, data in pairs(listeners) do
                    if data.value ~= nil then
                        if value ~= data.value then
                            continue
                        end
                    end
    
                    data.fn(value, false)
                end
            end)
        end
    end,

    _OnDestroy = function()
        if self.__stateChangeHandler then
            UtilityNet.RemoveStateBagChangeHandler(self.__stateChangeHandler)
        end
    end
}

deepcopy = function(orig, copies)
    copies = copies or {}

    if _type(orig) ~= 'table' then
        return orig
    elseif copies[orig] then
        return copies[orig]
    end

    local copy = {}
    copies[orig] = copy

    for k, v in next, orig, nil do -- Dont use __pairs metatable
        copy[deepcopy(k, copies)] = deepcopy(v, copies)
    end

    setmetatable(copy, deepcopy(getmetatable(orig), copies))
    return copy
end

-- Decorators
function model(_class, model)
    if type(model) == "table" then
        local models = {}

        for k,v in pairs(model) do
            local c_class = deepcopy(_class)
            models[v] = c_class

            RegisterObjectScript(v, "main", c_class)
            c_class.__prototype.model = v
        end

        _class.__models = models
    elseif type(model) == "string" then
        RegisterObjectScript(model, "main", _class)
        _class.__prototype.model = model
    end
end

function plugin(_class, plugin)
    Citizen.CreateThread(function()
        if _class.__models then
            for model,_class in pairs(_class.__models) do
                if _G[plugin].__prototype.OnPluginApply then
                    _G[plugin].__prototype.OnPluginApply({}, _class.__prototype)
                end
            
                RegisterObjectScript(model, plugin, _G[plugin])
            end
        else
            local model = _class.__prototype.model
        
            if _G[plugin].__prototype.OnPluginApply then
                _G[plugin].__prototype.OnPluginApply({}, _class.__prototype)
            end
        
            RegisterObjectScript(model, plugin, _G[plugin])
        end
    end)
end


function state(self, fn, key, value)
    if not self.listenedStates then
        self.listenedStates = {}
    end

    if not self.listenedStates[key] then
        self.listenedStates[key] = {}
    end

    table.insert(self.listenedStates[key], {
        fn = fn,
        value = value
    })
end

function event(self, fn, key, ignoreRendering)
    RegisterNetEvent(key)
    AddEventHandler(key, function(...)
        if ignoreRendering then
            fn(...)
        else
            if AreObjectScriptsFullyLoaded(self.obj) then -- Only run if object is loaded
                fn(...)
            end
        end
    end)

    return fn
end

-- RPC
local callbacksLoaded = false
local callbacks = {["GetCallbacks"] = true}

function SetRPCNamespace(namespace)
    Server.namespace = namespace..":"
end

Server = setmetatable({
    namespace = (Config?.Namespace or GetCurrentResourceName()) .. ":",
}, {
    __index = function(self, key)
        local name = self.namespace..key

        return function(...)
            -- Wait that callbacks are loaded
            while not callbacksLoaded and key ~= "GetCallbacks" do
                Wait(0)
            end

            if callbacks[key] then
                local p = promise.new()        
                local id = GetHashKey(GetPlayerName(-1) .. GetGameTimer()) -- Generate a random id (we use player name + game timer and hash it to make it unique)

                local eventHandler = nil
            
                -- Register a new event to handle the callback from the server
                RegisterNetEvent(name)
                eventHandler = AddEventHandler(name, function(_id, data)
                    if _id ~= id then
                        return
                    end

                    Citizen.SetTimeout(1, function()
                        RemoveEventHandler(eventHandler)
                    end)
                    p:resolve(data)
                end)
                
                TriggerServerEvent(name, id, ...)
                return table.unpack(Citizen.Await(p))
            else
                TriggerServerEvent(name, ...)
            end
        end
    end,
})

-- Request callbacks from server (with a callback)
Citizen.CreateThreadNow(function()
    callbacks = Server.GetCallbacks()
    callbacksLoaded = true
end)