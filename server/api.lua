--BUILD @utility_objectify/shared/decorators.lua
function model(_class, model, abstract)
    if type(model) == "table" then
        for k,v in pairs(model) do
            if IsClient then
                RegisterObjectScript(v, "main", _class)
            elseif IsServer then
                _class.__prototype[v] = function(...)
                    _class.__prototype.model = v
                    local obj = new _class(...)
                    obj.model = v
                    _class.__prototype.model = nil

                    return obj
                end
            end
        end

        _class.__models = model
    elseif type(model) == "string" then
        _class.__prototype.model = model

        if IsClient then
            RegisterObjectScript(model, "main", _class)
        elseif IsServer then
            _class.__prototype.abstract = abstract
        end
    end
end

function plugin(_class, plugin)
    if IsClient then
        Citizen.CreateThread(function()
            if _G[plugin].__prototype.OnPluginApply then
                _G[plugin].__prototype.OnPluginApply({}, _class.__prototype)
            end

            if _class.__models then
                for _,model in pairs(_class.__models) do
                    RegisterObjectScript(model, plugin, _G[plugin])
                end
            else
                local model = _class.__prototype.model
                RegisterObjectScript(model, plugin, _G[plugin])
            end
        end)
    elseif IsServer then
        if not _class.__prototype.__plugins then
            _class.__prototype.__plugins = {}
        end

        table.insert(_class.__prototype.__plugins, plugin)
    end
end

function vehicle(_class, _model)
    model(_class, "UtilityNet:Veh:".._model, true)
end

function ped(_class, _model)
    model(_class, "UtilityNet:Ped:".._model, true)
end

function object(_class, _model)
    model(_class, "UtilityNet:Obj:".._model, true)
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
        if IsClient then
            if ignoreRendering then
                fn(...)
            else
                if AreObjectScriptsFullyLoaded(self.obj) then -- Only run if object is loaded
                    fn(...)
                end
            end
        elseif IsServer then
            fn(...)
        end
    end)
end

------------------------------------

--BUILD @utility_objectify/shared/entitiesSingleton.lua
class EntitiesSingleton {
    list = {},

    constructor = function()
        self.list = {}
    end,

    add = function(entity: BaseEntity)
        self.list[entity.id] = entity
    end,

    createByName = function(name: string)
        return _G[name]()
    end,

    remove = function(entity: BaseEntity)
        self.list[entity.id] = nil
    end,

    get = function(id: number)
        return self.list[id]
    end,

    waitFor = function(id: number, timeout: number = 5000)
        local start = GetGameTimer()

        while not self.list[id] do
            if GetGameTimer() - start > timeout then
                throw new Error("${type(self)}: Child ${childId} not found after ${timeout}ms, skipping")
                return nil
            end

            Wait(0)
        end

        return self.list[id]
    end,

    getBy = function(key: string, value)
        for _, entity in pairs(self.list) do
            if type(value) == "function" then
                if value(entity[key]) then
                    return entity
                end
            else
                if entity[key] == value then
                    return entity
                end
            end
        end
    end,

    getAllBy = function(key: string, value)
        local ret = {}

        for k,v in pairs(self.list) do
            if type(value) == "function" then
                if value(v[key]) then
                    table.insert(ret, v)
                end
            else
                if v[key] == value then
                    table.insert(ret, v)
                end
            end
        end

        return ret
    end
}

Entities = new EntitiesSingleton()

------------------------------------

--BUILD @utility_objectify/shared/rpc.lua
local exposedEntitiesRpcs = {} -- Used to store all class exposed rpcs
local callbacks = {}
local namespace = (Config?.Namespace or GetCurrentResourceName()) .. ":"

function SetRPCNamespace(_namespace)
    namespace = _namespace
end

if not IsDuplicityVersion() then
    callbacks["GetCallbacks"] = true
end

local function rpc_hasreturn(fn, _return)
    local sig = leap.fsignature(fn)
    return _return != nil ? _return : sig.has_return
end

local function rpc_function(fn, _return)
    local sig = leap.fsignature(fn)
    _return = rpc_hasreturn(fn, _return)
    local tag = IsServer and "Server" or "Client"

    local name = namespace.."${tag}:"..sig.name

    if not _return then
        RegisterNetEvent(name)

        if IsServer then
            AddEventHandler(name, fn)
        else
            AddEventHandler(name, function(...)
                local first = ...
                if type(first) == "string" and first:sub(1, 2) == "cb" then
                    error("${sig.name}: You cannot call a standard rpc as a callback, please dont use `await`")
                end
                
                fn(...)
            end)
        end
    else
        callbacks[sig.name] = true

        RegisterNetEvent(name)
        AddEventHandler(name, function(id, ...)
            if IsClient then
                if type(id) != "string" or id:sub(1, 2) != "cb" then
                    error("${sig.name}: You cannot call a callback as a standard rpc, please use `await`")
                end
            end

            local source = source
            
            -- For make the return of lua works
            local _cb = table.pack(fn(...))
            
            if _cb ~= nil then -- If the callback is not nil
                if IsServer then
                    TriggerClientEvent(name, source, id, _cb) -- Trigger the client event
                else
                    TriggerServerEvent(name, id, _cb) -- Trigger the server event
                end
            end
        end)
    end
end

local function checkRPCExposure(ogname, source, classLabel, methodName)
    if not exposedEntitiesRpcs[classLabel] or not exposedEntitiesRpcs[classLabel][methodName] then
        error("${ogname}(${source}): Class ${classLabel} doesn't expose ${methodName}")
        return false
    end

    return true
end

local function callRPC(target, method, ...)
    return target[method](target, ...)
end

local function rpc_entity(className, fn, _return)
    local sig = leap.fsignature(fn)
    local ogname = sig.name
    sig.name =  className.."."..sig.name
    
    --[[
    -- This function is used as a "global" function to expose a rpc to the other side for a specific class
    -- The other side will pass as first argument the id of the entity and it will call the function in the object class
    -- Example:
    --   class Test extends BaseEntity {
    --       @rpc()
    --       test = function(a)
    --           print("from client/server:", a)
    --       end
    --   }
    --
    --   When the other side calls the rpc this is the call stack:
    --    other side: send call to Test.test (className:fn) passing as first argument the uNetId of the entity
    --    this side: call a global function that will resolve the entity from the uNetId and call the appropriate function
    --]]
    local _fn = leap.registerfunc(function(id, ...)
        local source = source or "SERVER"
        local entity = Entities:getBy("id", id)
        local tag = "${ogname}(${source})"

        if not entity then
            error("${tag}: Entity with id ${tostring(id)} does not exist")
            return
        end

        local isPlugin = className:find("%.")
        if isPlugin then -- RPC from a plugin
            local _className, pluginName = className:match("(.*)%.(.*)")

            if not entity.plugins or not entity.plugins[pluginName] then
                error("${tag}: Entity with id ${tostring(id)} has no plugin ${pluginName}")
                return
            end

            if type(entity) ~= _className then
                error("${tag}: Entity with id ${tostring(id)} is not a ${className}")
                return
            end

            local plugin = entity.plugins[pluginName]
            if not plugin[ogname] then
                error("${tag}: Class ${className} doesnt define ${ogname}")
                return
            end

            if checkRPCExposure(ogname, source, className, ogname) then
                return callRPC(plugin, ogname, ...)
            end
        else
            if type(entity) ~= className then
                error("${tag}: Entity with id ${tostring(id)} is not a ${className}")
                return
            end

            if not entity[ogname] then
                error("${tag}: Class ${className} doesnt define ${ogname}")
                return
            end

            if checkRPCExposure(ogname, source, className, ogname) then
                return callRPC(entity, ogname, ...)
            end
        end
    end, sig)

    rpc_function(_fn, _return)

    if IsServer then
        if rpc_hasreturn(fn, _return) then
            TriggerClientEvent(namespace.."RegisterCallback", -1, sig.name) -- Register the callback on runtime for connected clients!
        end
    end

    sig.name = ogname
end

function rpc(fn, _return, c)
    if _type(fn) == "function" then
        rpc_function(fn, _return)
    else
        local class = fn
        local fn = _return
        local _return = c
        
        if not class is BaseEntity then
            error("The rpc decorator on classes is only allowed to be used on classes that inherit from BaseEntity")
        end

        local sig = leap.fsignature(fn)

        local className = nil

        if class.isPlugin then
            className = type(class.main) .. "." .. type(class)
        else
            className = type(class)
        end
        
        if not exposedEntitiesRpcs[className] then
            exposedEntitiesRpcs[className] = {}
        end

        if not exposedEntitiesRpcs[className][sig.name] then
            exposedEntitiesRpcs[className][sig.name] = true -- Set the rpc as exposed

            -- Register global function that will handle "entity branching"
            rpc_entity(className, fn, _return)
        end
    end
end

function srpc(fn, _return, c)
    if IsServer then
        rpc(fn, _return, c)
    end
end

function crpc(fn, _return, c)
    if IsClient then
        rpc(fn, _return, c)
    end
end

------------------------------------

--BUILD @utility_objectify/server/entity.lua
if not UtilityNet then
    error("Please load the utility_lib before utility_objectify!")
end

local client_rpc_mt, client_plugin_rpc_mt = nil -- hoisting
client_rpc_mt = {
    __index = function(self, key)
        -- Create "plugins" and "await" at runtime, this reduce memory footprint
        if key == "plugins" then
            local id = rawget(self, "id")
            local __type = rawget(self, "__type")
            local _await = rawget(self, "_await")

            local plugins = setmetatable({id = id, __type = __type, _await = _await}, client_plugin_rpc_mt)
            rawset(self, "plugins", plugins) -- Caching
            return plugins
        end

        if key == "await" then
            local id = rawget(self, "id")
            local __type = rawget(self, "__type")

            local await = setmetatable({id = id, __type = __type, _await = true}, client_rpc_mt)
            rawset(self, "await", await) -- Caching
            return await
        end


        local method = self.__type .. "." .. key
    
        local fn = function(...)
            local n = select("#", ...)

            if n == 0 then -- No args, so also no client id
                error("${method} requires the client id as the first argument!", 2)
            end

            if n > 0 then
                local first, second = ...
                local selfCall = first and type(first) == self.__type and first.id == self.id
                
                local cid = selfCall and second or first
                if type(cid) != "number" then
                    error("${method} requires the client id as the first argument!", 2)
                end

                local hasAwait = rawget(self, "_await")

                local call = function(_cid, ...)
                    -- 3 and 2 because the first argument is the client id and should always be ignored
                    if hasAwait then
                        -- Cant do selfCall and or since the first argument can be nil
                        if selfCall then
                            return Client.await[method](_cid, self.id, select(3, ...))
                        else
                            return Client.await[method](_cid, self.id, select(2, ...))
                        end
                    else
                        if selfCall then
                            return Client[method](_cid, self.id, select(3, ...))
                        else
                            return Client[method](_cid, self.id, select(2, ...))
                        end
                    end
                end

                if cid == -1 then
                    local ids = exports["utility_lib"]:GetEntityListeners(self.id)

                    return call(ids, ...)
                else
                    return call(cid, ...)
                end
            end
        end

        rawset(self, key, fn) -- Caching
        return fn
    end,
    __newindex = function(self, key, value)
        error("You can't register ${IsServer and 'server' or 'client'} methods from the ${IsServer and 'client' or 'server'}, please register them from the ${IsServer and 'server' or 'client'} using the rpc decorator!")
    end
}

client_plugin_rpc_mt = {
    __index = function(self, key)
        -- Create a client_rpc_mt with the plugin name and add the plugin type
        local proxy = setmetatable({
            id = self.id,
            __type = type(self) .. "." .. key,
            plugins = self,
            _await = rawget(self, "_await")
        }, client_rpc_mt)

        rawset(self, key, proxy) -- Caching
        return proxy
    end,
    __newindex = function(self, key, value)
        error("You can't register ${IsServer and 'server' or 'client'} methods from the ${IsServer and 'client' or 'server'}, please register them from the ${IsServer and 'server' or 'client'} using the rpc decorator!")
    end
}

-- Use always the same reference and create a new table only if needed, this reduce memory footprint
local EMPTY_PLUGINS = {}
local EMPTY_CHILDREN = {}

@skipSerialize({"plugins", "children", "parent", "id", "state", "main", "isPlugin"})
class BaseEntity {
    id = nil,
    state = nil,
    main = nil,
    parent = nil,

    constructor = function(coords: vector3 | nil, rotation: vector3 | nil, options = {})
        if self.isPlugin then
            return
        end

        self.children = EMPTY_CHILDREN
        self.plugins = EMPTY_PLUGINS

        if self.__plugins then
            self.plugins = {}

            for k,v in pairs(self.__plugins) do
                local _plugin = _G[v]

                -- Dont call the constructor (reduce useless calls, it will be skipped anyway)
                _plugin.__skipNextConstructor = true
                
                -- We need to set it in the prototype since the rpc decorator is called before full object initialization
                _plugin.__prototype.isPlugin = true
                _plugin.__prototype.main = self

                local instance = new _plugin(nil)

                -- Reset prototype for future object instantiations
                _plugin.__prototype.isPlugin = nil
                _plugin.__prototype.main = nil

                -- Reset the values on this object instance
                instance.isPlugin = true
                instance.main = self
                
                self.plugins[v] = instance
            end
        end

        if coords != nil then
            self:create(coords, rotation, options)
        end
    end,

    deconstructor = function()
        self:destroy()
    end,
    
    destroy = function()
        Entities:remove(self)
        
        self:callOnAll("OnDestroy")

        if self.id and UtilityNet.DoesUNetIdExist(self.id) then
            UtilityNet.DeleteEntity(self.id)
        end

        if self.__stateChangeHandler then
            UtilityNet.RemoveStateBagChangeHandler(self.__stateChangeHandler)
        end
    end,

    init = function(id, state, client)
        self.id = id
        self.state = state
        self.client = client

        if self.__listenedStates and next(self.__listenedStates) then
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

            for key, listeners in pairs(self.__listenedStates) do
                Citizen.CreateThread(function()
                    onStateChange(listeners, self.state[key], true)
                end)
            end

            self.__stateChangeHandler = UtilityNet.AddStateBagChangeHandler(self.id, function(key, value)
                local listeners = self.__listenedStates[key]

                if listeners then
                    onStateChange(listeners, value, false)
                end
            end)
        end

        if self.plugins then
            for k,v in pairs(self.plugins) do
                v:init(id, state)
            end
        end
    end,

    callOnAll = function(method, ...)
        if self[method] then
            self[method](self, ...)
        end

        if self.plugins then
            for k,v in pairs(self.plugins) do
                if v[method] then
                    v[method](v, ...)
                end
            end
        end
    end,

    create = function(coords: vector3, rotation: vector3 | nil, options = {})
        local _type = type(self)

        if not self.model then
            error("${_type}: trying to create entity without model, please use the model decorator to set the model")
        end

        if self.abstract and self.model:find("UtilityNet") and not self is BaseEntityOneSync then
            error("${type(self)}: trying to create a BasicEntity but using a BaseEntityOneSync decorator, please extend BasicEntityOneSync (vehicle, ped, object)")
        end

        options.rotation = options.rotation or rotation
        options.abstract = options.abstract or self.abstract

        local id = UtilityNet.CreateEntity(self.model, coords, options)
        local state = UtilityNet.State(id)
        local client = setmetatable({id = id, __type = _type}, client_rpc_mt)

        self:init(id, state, client)
        Entities:add(self)
        
        self:callOnAll("OnAwake")

        -- Give time to the children to be added
        Citizen.SetTimeout(1, function()
            self:callOnAll("OnSpawn")
        end)

        self:callOnAll("AfterSpawn")
    end,

    addChild = function(name: string, child: BaseEntity)
        if not child.id then
            error("${type(self)}: trying to add a child that hasnt been created yet")
        end

        local exist = table.find(self.children, child)
        if exist then
            return
        end
        
        local _root = self        
        while _root.parent do
            _root = _root.parent
        end
        
        child.parent = self
        child.root = _root

        child.state.parent = self.id
        child.state.root = _root.id

        if self.children == EMPTY_CHILDREN then
            self.children = {}
        end

        self.children[name] = child

        if not self.state.children then
            self.state.children = {[name] = child.id}
        else
            self.state.children[name] = child.id
        end
    end,

    removeChild = function(childOrName: BaseEntity | string)
        if type(childOrName) == "string" then
            self.children[childOrName] = nil
            self.state.children[childOrName] = nil
        else
            for name, child in pairs(self.children) do
                if child == childOrName then
                    self.children[name] = nil
                    break
                end
            end
            
            for name, id in pairs(self.state.children) do
                if id == childOrName.id then
                    self.state.children[name] = nil
                    break
                end
            end
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
    netId = nil,
    spawned = false,
    
    constructor = function(coords, rotation, options)
        if not self.abstract and not (self.model or ""):find("UtilityNet") then
            error("${type(self)}: trying to create a BasicEntityOneSync without an allowed decorator (vehicle, ped, object)")
        end

        self:super(coords, rotation, options)

        -- TODO: fix leap not running decorators of parent when extending class
        rpc(self, self._askPermission, true)
        rpc(self, self._created, true)

        RegisterNetEvent("Utility:Net:RemoveStateListener", function(uNetId, __source)
            if not source then
                source = __source
            end

            if UtilityNet.DoesUNetIdExist(uNetId) then
                Citizen.Wait(100)
                local listeners = exports["utility_lib"]:GetEntityListeners(uNetId)
    
                if not listeners or #listeners == 0 then
                    self:destroyNetId()
                end
            end
        end)

        AddEventHandler("Utility:Net:EntityDeleted", function(uNetId)
            if uNetId == self.id then
                self:destroy()
            end
        end)
    end,

    callOnAll = function(...)
        if not self.netId then
            return
        end

        self.super:callOnAll(...)
    end,

    _created = function(netId)
        try
            self.obj = NetworkGetEntityFromNetworkId(netId)
            self.netId = netId
            self.state.netId = netId

            UtilityNet.AttachToNetId(self.id, netId, 0, vec3(0,0,0), vec3(0,0,0), false, false, 1, true)

            self:callOnAll("OnAwake")

            -- Give time to the children to be added
            Citizen.SetTimeout(1, function()
                self:callOnAll("OnSpawn")
            end)

            self:callOnAll("AfterSpawn")
        catch e
            self.spawned = false
            error("Created: Client "..source.." passed an invalid netId "..netId)
        end
    end,

    destroy = function()
        self.super:destroy()
        self:destroyNetId()
    end,

    destroyNetId = function()
        if not self.spawned then
            return
        end

        self:callOnAll("OnDestroy")

        local entity = NetworkGetEntityFromNetworkId(self.netId)
        local rotation = GetEntityRotation(entity)

        if UtilityNet.DoesUNetIdExist(self.id) then
            UtilityNet.SetEntityRotation(self.id, rotation)
            UtilityNet.DetachEntity(self.id)

            self.state.netId = nil
            self.spawned = false
        end

        self.netId = nil
        self.obj = nil
        DeleteEntity(entity)
    end,

    _askPermission = function()
        if not self.spawned then
            self.spawned = true
            return true
        end
        
        return false
    end
}

------------------------------------

--BUILD @utility_objectify/server/framework.lua
-- v1.1
IsServer = true
IsClient = false
local disableTimeoutNext = false

@rpc(true)
function GetCallbacks()
    return callbacks
end

function GenerateCallbackId()
    return "cb"..GetHashKey(tostring(math.random()) .. GetGameTimer())
end

function AwaitCallback(name, cid, id)
    local p = promise.new() 

    if not disableTimeoutNext then
        Citizen.SetTimeout(5000, function()
            if p.state == 0 then
                warn("Client callback ${name}(${tostring(id)}) sended to ${tostring(cid)} timed out")
                p:reject({})
            end
        end)
    else
        disableTimeoutNext = false
    end

    local eventHandler = nil

    -- Register a new event to handle the callback from the client
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

local await = setmetatable({}, {
    __index = function(self, key)
        local name = namespace.."Client:"..key

        return function(cid: number | table, ...)
            
            if type(cid) == "table" then
                local promises = {}

                for k,v in ipairs(cid) do
                    local id = GenerateCallbackId()
                    local p = AwaitCallback(name, cid, id)
                    TriggerClientEvent(name, cid, id, ...)

                    table.insert(promises, p)
                end

                local returns = Citizen.Await(promise.all(promises))
                local retByCid = {}

                for k,v in ipairs(returns) do
                    retByCid[cid[k]] = v
                end

                return retByCid
            else
                local id = GenerateCallbackId()
                local p = AwaitCallback(name, cid, id)
                TriggerClientEvent(name, cid, id, ...)

                return table.unpack(Citizen.Await(p))
            end
        end
    end
})

Client = setmetatable({
    DisableTimeoutForNext = function()
        disableTimeoutNext = true
    end
}, {
    __index = function(self, key)
        local name = namespace.."Client:"..key

        if key == "await" then
            return await
        else
            return function(cid: number | table, ...)
                if type(cid) == "table" then
                    for k,v in ipairs(cid) do
                        TriggerClientEvent(name, v, ...)
                    end
                else
                    TriggerClientEvent(name, cid, ...)
                end
            end
        end
    end,
})

------------------------------------

