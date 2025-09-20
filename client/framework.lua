-- v1.2
IsServer = false
IsClient = true

local callbacksLoaded = false

local function CombineHooks(self, methodName, beforeName, afterName)
    local main = self[methodName]

    self[methodName] = function(...)
        local before = self[beforeName]
        local after = self[afterName]
        
        if before then before(self, ...) end
        if main then main(self, ...) end
        if after then return after(self, ...) end
    end
end

local server_rpc_mt, server_plugin_rpc_mt, children_mt = nil -- hoisting
server_rpc_mt = {
    __index = function(self, key)
        -- Create "plugins" at runtime, this reduce memory footprint
        if key == "plugins" then
            local id = rawget(self, "id")
            local __type = rawget(self, "__type")

            local plugins = setmetatable({id = id, __type = __type}, server_plugin_rpc_mt)
            rawset(self, "plugins", plugins) -- Caching
            return plugins
        end

        local method = self.__type .. "." .. key

        local fn = function(...)
            local first = ... -- This will just assign the first argument
            local selfCall = first and type(first) == self.__type and first.id == self.id

            if selfCall then
                return Server[method](self.id, select(2, ...))
            else
                return Server[method](self.id, ...)
            end
        end

        rawset(self, key, fn) -- Caching
        return fn
    end,
    __newindex = function(self, key, value)
        error("You can't register server methods from the client, please register them from the server using the rpc decorator!")
    end
}

server_plugin_rpc_mt = {
    __index = function(self, key)
        -- Create a client_rpc_mt with the plugin name and add the plugin type
        local proxy = setmetatable({
            id = self.id,
            __type = self.__type .. "." .. key
        }, server_rpc_mt)

        rawset(self, key, proxy) -- Caching
        return proxy
    end,

    __newindex = function()
        error("You can't register server methods from the client, please register them from the server using the rpc decorator!")
    end
}

children_mt = {
    __mode = "v",

    getEntity = function(self, name)
        if not self._state.children then
            return nil
        end

        if not self._state.children[name] then
            return nil
        end

        local entity = Entities:waitFor(self._state.children[name])
        entity.parent = self._parent

        return entity
    end,

    __pairs = function(self)
        if not self._state.children then
            return function() end
        end

        local meta = getmetatable(self)

        return function(t, k)
            local k,v = next(self._state.children, k)
            if not v or not k then return nil end

            local entity = meta.getEntity(self, k)

            if entity then
                return k, entity
            end
        end
    end,

    __tostring = function(self)
        if not self._state.children then
            return "[]"
        end

        return json.encode(self._state.children)
    end,

    __ipairs = function(self)
        local meta = getmetatable(self)
        return meta.__pairs(self)
    end,

    __len = function(self)
        if not self._state.children then
            return 0
        end

        return #self._state.children
    end,

    __index = function(self, key)
        local meta = getmetatable(self)
        return meta.getEntity(self, key)
    end
}

@skipSerialize({"main", "isPlugin", "plugins", "server", "listenedStates"})
class BaseEntity {
    server = nil,
    children = nil,
    __stateChangeHandler = nil,

    constructor = function()
        CombineHooks(self, "OnSpawn", "_BeforeOnSpawn", "_AfterOnSpawn")
        CombineHooks(self, "OnDestroy", nil, "_AfterOnDestroy")
    end,

    @state("parent")
    _OnParentChange = function(parent, load)
        if load then return end

        if parent then
            self.parent = Entities:waitFor(parent)
        else
            self.parent = nil
        end
    end,

    @state("root")
    _OnRootChange = function(root, load)
        if load then return end

        if root then
            self.root = Entities:waitFor(root)
        else
            self.root = nil
        end
    end,

    _BeforeOnSpawn = function()
        self.server = setmetatable({id = self.id, __type = type(self)}, server_rpc_mt)
        self.children = setmetatable({_state = self.state, _parent = self}, children_mt)

        if self.state.parent then
            self.parent = Entities:waitFor(self.state.parent)
        end

        if self.state.root then
            self.root = Entities:waitFor(self.state.root)
        end

        if not self.isPlugin then
            Entities:add(self)
        end
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
                Citizen.CreateThread(function()
                    onStateChange(listeners, self.state[key], true)
                end)
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

        if not self.isPlugin then
            Entities:remove(self)
        end
    end,

    getChild = function(path: string)
        if path:find("/") then
            local child = self

            for str in path:gmatch("([^/]+)") do
                if not child or not child.children then
                    return nil
                end

                child = child.children[str]
            end

            return child
        end

        return self.children[path]
    end,

    getChildBy = function(key: string, value)
        for name, child in pairs(self.children) do
            if type(value) == "function" then
                if value(child[key]) then
                    return child
                end
            else
                if child[key] == value then
                    return child
                end
            end
        end

        return nil
    end,

    getChildrenBy = function(key: string, value)
        local children = {}

        for name, child in pairs(self.children) do
            if type(value) == "function" then
                if value(child[key]) then
                    children[name] = child
                end
            else
                if child[key] == value then
                    children[name] = child
                end
            end
        end

        return children
    end
}

class BaseEntityOneSync extends BaseEntity {
    _CreateOneSyncEntity = function(enttype)
        local _obj = nil

        if enttype == "Veh" then
            _obj = CreateVehicle(self.model, GetEntityCoords(self.obj), GetEntityHeading(self.obj), true, true)
        elseif enttype == "Ped" then
            _obj = CreatePed(self.model, GetEntityCoords(self.obj), GetEntityHeading(self.obj), true, true)
        elseif enttype == "Obj" then
            _obj = CreateObject(self.model, GetEntityCoords(self.obj), GetEntityHeading(self.obj), true, true)
        end

        if not _obj then
            error("OneSyncEntity: Failed to create entity for "..tostring(self.id)..", "..tostring(enttype).." is not an allowed type!")
            return
        end
        
        while not DoesEntityExist(_obj) do
            Wait(0)
        end

        local netid = NetworkGetNetworkIdFromEntity(_obj)
        self.server:_created(netid)
    end,

    _BeforeOnSpawn = function()
        self.super:_BeforeOnSpawn()

        local type, model = self.model:match("^[^:]+:([^:]+):([^:]+)$")
        self.model = model 

        if not self.state.netId or not NetworkDoesNetworkIdExist(self.state.netId) then
            local allowed = self.server:_askPermission()

            if allowed then
                self:_CreateOneSyncEntity(type)
            end
        end

        while not self.state.netId do
            Wait(0)
        end

        self._obj = self.obj
        self.obj = NetworkGetEntityFromNetworkId(self.state.netId)
        self.netId = self.state.netId
    end
}

-- RPC
local disableTimeoutNext = false

function SetRPCNamespace(_namespace)
    namespace = _namespace
end

local GenerateCallbackId = function()
    return "cb"..GetHashKey(GetPlayerName(-1) .. GetGameTimer())
end

local AwaitCallback = function(name, id)
    local p = promise.new()    
   
    if not disableTimeoutNext then
        Citizen.SetTimeout(5000, function()
            if p.state == 0 then
                warn("Server callback ${name} (${tostring(id)}) timed out")
                p:reject({})
            end
        end)
    else
        disableTimeoutNext = false
    end

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
    DisableTimeoutForNext = function()
        disableTimeoutNext = true
    end
}, {
    __index = function(self, key)
        local name = namespace.."Server:"..key

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

    RegisterNetEvent(namespace.."RegisterCallback")
    AddEventHandler(namespace.."RegisterCallback", function(key)
        callbacks[key] = true
    end)
end)