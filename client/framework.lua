-- v1.1
IsServer = false
IsClient = true

local callbacksLoaded = false
local callbacks = {["GetCallbacks"] = true}

local function CombineHooks(self, methodName, beforeName, afterName)
    local before = self[beforeName]
    local main = self[methodName]
    local after = self[afterName]

    self[methodName] = function(...)
        if before then before(self, ...) end
        if main then main(self, ...) end
        if after then return after(self, ...) end
    end
end

local server_rpc_mt = {
    __index = function(self, key)
        return function(...)
            return Server["${type(self)}.${key}"](self.id, ...)
        end
    end,
    __newindex = function(self, key, value)
        error("You can't register server methods from the client, please register them from the server using the rpc decorator!")
    end
}

class BaseEntity {
    server = nil,
    listenedStates = {},
    __stateChangeHandler = nil,

    constructor = function()
        CombineHooks(self, "OnSpawn", "_BeforeOnSpawn", "_AfterOnSpawn")
        CombineHooks(self, "OnDestroy", nil, "_AfterOnDestroy")
    end,

    _BeforeOnSpawn = function() 
        self.server = setmetatable({id = self.id, __type = type(self)}, server_rpc_mt)
    end,

    _AfterOnSpawn = function()
        local function onStateChange(listeners, value, initial)
            for _, data in pairs(listeners) do
                if data.value ~= nil then
                    if value ~= data.value then
                        continue
                    end
                end

                data.fn(value, initial)
            end
        end

        if self.listenedStates and next(self.listenedStates) then
            for key, listeners in pairs(self.listenedStates) do
                onStateChange(listeners, self.state[key], true)
            end

            self.__stateChangeHandler = UtilityNet.AddStateBagChangeHandler(self.id, function(key, value)
                local listeners = self.listenedStates[key]

                if listeners then
                    onStateChange(listeners, value, false)
                end
            end)
        end
    end,

    _AfterOnDestroy = function()
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

    for k, v in next, orig, nil do
        local key_copy = deepcopy(k, copies)
        if type(k) == 'string' and k:sub(1, 5) == "_leap" then
            copy[key_copy] = v -- copy by reference
        else
            copy[key_copy] = deepcopy(v, copies)
        end
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
function SetRPCNamespace(namespace)
    Server.namespace = namespace..":"
end

function GenerateCallbackId()
    return GetHashKey(GetPlayerName(-1) .. GetGameTimer())
end

function AwaitCallback(name, id)
    local p = promise.new()        
    Citizen.SetTimeout(5000, function()
        if p.state == 0 then
            warn("Server callback ${name} (${tostring(id)}) timed out")
            p:reject({})
        end
    end)

    local eventHandler = nil

    -- Register a new event to handle the callback from the server
    RegisterNetEvent(name)
    eventHandler = AddEventHandler(name, function(_id, data)
        if _id ~= id then return end

        Citizen.SetTimeout(1, function()
            RemoveEventHandler(eventHandler)
        end)
        p:resolve(data)
    end)

    return p
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
                local id = GenerateCallbackId()
                local p = AwaitCallback(name, id)
                
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

    RegisterNetEvent(Server.namespace.."RegisterCallback")
    AddEventHandler(Server.namespace.."RegisterCallback", function(key)
        callbacks[key] = true
    end)
end)