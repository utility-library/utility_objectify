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

--MERGE @utility_objectify/client/api.lua
if not IsDuplicityVersion() then
--BUILD @utility_objectify/client/framework.lua
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

------------------------------------

--BUILD @utility_objectify/client/objectManagement.lua
-- v1.5
local tag = "^3ObjectManagement^0"
local modelScripts = {}
local objectScripts = {}
local registeredObjects = {}
local tempObjectsProperties = {} -- Used to store temporary object properties for later instantiation
local customHooks = {}

local function GetScriptsForModel(model)
    return modelScripts[model]
end

local function _IsObjectScriptRegistered(model, name)
    local scripts = GetScriptsForModel(model)
    if scripts then
        for k,v in ipairs(scripts) do
            if v.name == name then
                return true
            end
        end
    end
end

-- Temp objects instances can interact only with tempObjectsProperties, not real instance runtime changed properties
-- Real objects instances can interact also with tempObjectsProperties
local function CreateTempObjectAndCallMethod(uNetId, model, method, ...)
    local _model = type(model) == "string" and GetHashKey(model) or model
    local scripts = GetScriptsForModel(_model)
    
    local _self = nil
    local _oldNewIndex = nil

    if not scripts then
        return
    end
    
    for k,v in pairs(scripts) do
        if v.script.__prototype[method] then
            if not _self then
                _self = new v.script()
                _self.state = UtilityNet.State(uNetId)
                _self.id = uNetId

                -- Set all temp object properties to new temp instance 
                -- (so that things done in OnRegister can be reused also in OnUnregister)
                -- This is done voluntarily like this to dont allow to access real instance properties and prevent strange bugs 
                -- (when unregistering a rendered object or unrendered the OnUnregister will be called with different objects creating strange situational bugs)
                if tempObjectsProperties[uNetId] then
                    for k,v in pairs(tempObjectsProperties[uNetId]) do
                        _self[k] = v
                    end
                end

                local metatable = getmetatable(_self)
                _oldNewIndex = metatable.__newindex

                metatable.__newindex = function(self, key, value)
                    -- We store all object properties in a temp table to set them later on object instantiation/OnUnregister
                    if not tempObjectsProperties[uNetId] then
                        tempObjectsProperties[uNetId] = {}
                    end

                    tempObjectsProperties[uNetId][key] = value
                    rawset(self, key, value)
                end
            end

            _self[method](_self, ...)
        end
    end

    if _self then -- Reset metatable to default!
        local metatable = getmetatable(_self)
        metatable.__newindex = _oldNewIndex
    end
end

local function CallOnRegister(uNetId, model, coords, rotation)
    registeredObjects[uNetId] = promise.new()
    CreateTempObjectAndCallMethod(uNetId, model, "OnRegister", coords, rotation)
    registeredObjects[uNetId]:resolve(true)
end

local function CreateObjectScriptInstance(obj, scriptIndex, source)
    local model = GetEntityModel(obj)
    local uNetId = UtilityNet.GetUNetIdFromEntity(obj)
    local scripts = GetScriptsForModel(model)

    if not scripts then
        developer(tag, "Model ^4"..model.."^0 has no scripts, skipping script index "..scriptIndex)
        return
    end

    local script = scripts[scriptIndex]

    -- Script already registered, skipping
    if objectScripts[obj][script.name] then
        developer("^1ObjectManagement^0", "Skipping ^1"..GetEntityArchetypeName(obj).."^0 since is already registered > ^5"..script.name.."^0 for "..obj)
        return
    end

    if source == "Registered" and Config?.ObjectManagementDebug?.Registered then
        developer(tag .. " ^2Registered^0", "Creating instance ^4"..GetEntityArchetypeName(obj).."^0 > ^5"..script.name.."^0 for "..obj)
    elseif source == "GetInstance" and Config?.ObjectManagementDebug?.GetInstance then
        developer(tag .. " ^3GetInstance^0", "Creating instance ^4"..GetEntityArchetypeName(obj).."^0 > ^5"..script.name.."^0 for "..obj)
    elseif source == "CreateInstances" and Config?.ObjectManagementDebug?.CreateInstances then
        developer(tag .. " ^6CreateInstances^0", "Creating instance ^4"..GetEntityArchetypeName(obj).."^0 > ^5"..script.name.."^0 for "..obj)
    end

    -- This "mechanism" is similar to the server side, where is a little cleaner

    if script.name ~= "main" then
        -- We need to set it in the prototype since the rpc decorator is called before full object initialization
        script.script.__prototype.isPlugin = true
        script.script.__prototype.main = objectScripts[obj]["main"]
    end

    local instance = new script.script()

    instance.state = UtilityNet.State(uNetId)
    instance.id = uNetId
    instance.obj = obj
    instance.model = GetEntityArchetypeName(obj)

    if script.name ~= "main" then
        local main = objectScripts[obj]["main"]

        -- Reset prototype for future object instantiations
        script.script.__prototype.isPlugin = nil
        script.script.__prototype.main = nil

        -- Reset the values on this object instance
        instance.isPlugin = true
        instance.main = main

        main.plugins[script.name] = instance -- Register plugin in main instance
    end

    -- On object instantiation set all temp object properties to real instance (saves a lot of memory)
    if tempObjectsProperties[uNetId] then
        for k,v in pairs(tempObjectsProperties[uNetId]) do
            instance[k] = v
        end
    end

    -- Call all hooks .exec method
    for hookMethod, hook in pairs(customHooks) do
        if instance[hookMethod] and hook.exec then
            hook.exec(instance, name)
        end
    end

    -- Register script instance on object
    objectScripts[obj][script.name] = instance

    return instance
end

local function CreateObjectScriptsInstances(obj)
    local model = GetEntityModel(obj)
    local scripts = GetScriptsForModel(model)

    if not scripts then
        developer(tag, "Model ^4"..model.."^0 has no scripts, skipping scripts instances creation")
        return false
    end
    
    objectScripts[obj] = {}

    -- Find main script (since someone can register the main script after the plugins)
    local mainIndex = nil

    for k,v in ipairs(scripts) do
        if v.name == "main" then
            mainIndex = k
            break
        end
    end

    -- Create main script before possible plugins
    local main = CreateObjectScriptInstance(obj, mainIndex, "GetInstance")
    main.plugins = {} -- Allow plugins to register themself

    objectScripts[obj]["main"] = main

    -- Create script instances in registration order (only plugins)
    for k,v in ipairs(scripts) do
        if v.name ~= "main" then
            objectScripts[obj][v.name] = CreateObjectScriptInstance(obj, k, "CreateInstances")
        end
    end

    return true
end

function CallMethodForAllObjectScripts(obj, method, ...)
    local model = Entity(obj).state.model
    local scripts = GetScriptsForModel(model)

    if not scripts then
        developer(tag, "Model ^4"..tostring(model).."^0 has no scripts, ignoring call method "..method)
        return
    end

    for k,v in ipairs(scripts) do
        if not DoesEntityExist(obj) then -- Object was deleted in the meantime
            break
        end

        local instance = GetObjectScriptInstance(obj, v.name, true)
        
        if not instance then -- Instance was deleted in the meantime
            break
        end

        if instance[method] then
            instance[method](instance, ...)
        end

        -- Propagate events also for custom hooks
        for hookMethod, hook in pairs(customHooks) do
            -- If this script instance and the hook implements the method
            if instance[hookMethod] and hook[method] then
                -- Temporarily create the call function to call the original method
                local call = function(...) 
                    CallMethodForAllObjectScripts(instance.obj, hookMethod, ...)
                end

                hook[method](instance, call, ...)
            end
        end
    end
end

--#region External API
function RegisterObjectScript(model, name, script)
    local hashmodel = type(model) == "string" and GetHashKey(model) or model

    if not modelScripts[hashmodel] then
        modelScripts[hashmodel] = {}
    end

    if not script then
        error("RegisterObjectScript: tried to register "..model.." > "..name.." but script is empty")
    end

    if IsObjectScriptRegistered(hashmodel, name) then
        developer(tag, "Model ^4"..model.."^0 > ^5"..name.."^0 is already registered, skipping")
        return
    end
        
    table.insert(modelScripts[hashmodel], {
        script = script,
        name = name
    })

    -- Register script for already spawned objects
    local scriptIndex = #modelScripts[hashmodel]

    if not table.empty(objectScripts) then
        for obj, scripts in pairs(objectScripts) do
            local model = GetEntityModel(obj)

            -- Same model and script is not already registered
            if model == hashmodel and not objectScripts[obj][name] then
                objectScripts[obj][name] = CreateObjectScriptInstance(obj, scriptIndex, "Registered")
            end
        end
    end
end

function RegisterObjectsScript(models, name, script)
    for k,v in pairs(models) do
        RegisterObjectScript(v, name, script)
    end
end

function IsObjectScriptRegistered(model, name)
    local hashmodel = type(model) == "string" and GetHashKey(model) or model

    return _IsObjectScriptRegistered(hashmodel, name)
end

---@class Hook
---@field exec function Called when any script object is created
---@field OnSpawn fun(self, call:function) Called when a script instance is created
---@field AfterSpawn fun(self, call:function) Called after a script instance is created
---@field OnDespawn fun(self, call:function) Called when a script instance is despawned

---Register a custom hook (works like a custom method)
---@param hookMethod string The name of the method for using the hook
---@param hookData Hook The table includes the following default methods: `exec`, `OnSpawn`, `AfterSpawn`, `OnDespawn`. Additionally, a function parameter `call` is added to call the original method in all script instances.
function RegisterCustomHook(hookMethod, hookData)
    customHooks[hookMethod] = hookData
end

---Pass a script as "static", no instance is created, the script will be returned as it is (table)  
---Not safe to edit the "static" script or calling functions without providing a custom "instance" mockup
---@param model string
---@param name string The script name
function GetExternalObjectScriptStatic(model, name)
    if type(model) == "string" then
        model = GetHashKey(model)
    end
    
    if not modelScripts[model] then return end

    for k,v in pairs(modelScripts[model]) do
        if v.name == name then
            return v.script
        end
    end
end

function GetObjectScriptInstance(obj, name, nocheck)
    if not obj then error("GetObjectScriptInstance: passed obj is nil, name: "..name) end
    if not UtilityNet.GetUNetIdFromEntity(obj) then return end -- Object is not networked

    if not nocheck then
        -- Wait that the object is rendered
        local start = GetGameTimer()
        while not UtilityNet.IsEntityRendered(obj) do
            if GetGameTimer() - start > 5000 then
                error("GetObjectScriptInstance: UtilityNet.IsEntityRendered timed out for "..GetEntityArchetypeName(obj).." > "..name, 2)
            end
            Citizen.Wait(0)
        end
    end

    local model = GetEntityModel(obj)

    if not objectScripts[obj] then
        -- Check if script should be loaded
        if _IsObjectScriptRegistered(model, name) then
            -- Wait for script to be loaded
            local start = GetGameTimer()
            while not objectScripts[obj] or not objectScripts[obj][name] do
                if GetGameTimer() - start > 5000 then
                    error("GetObjectScriptInstance: timed out for "..GetEntityArchetypeName(obj).." > "..name, 2)
                end
                Citizen.Wait(0)
            end
        else -- Script is not registered and will not be loaded in the future (dont exist)
            return nil 
        end
    end

    if not objectScripts[obj][name] then
        local model = GetEntityModel(obj)
        local scripts = GetScriptsForModel(model)
        local scriptIndex = nil

        for k,v in ipairs(scripts) do
            if v.name == name then
                scriptIndex = k
                break
            end
        end

        if not scriptIndex then
            return
        end

        CreateObjectScriptInstance(obj, scriptIndex, "GetInstance")
    end

    return objectScripts[obj][name]
end

function GetNetScriptInstance(netid, name)
    if not netid then error("GetNetScriptInstance: passed netid is nil", 2) return end

    local start = GetGameTimer()
    while not UtilityNet.IsReady(netid) do
        if GetGameTimer() - start > 5000 then
            error("GetNetScriptInstance: timed out IsReady for netid "..tostring(netid), 2)
        end
        Citizen.Wait(0)
    end

    local obj = UtilityNet.GetEntityFromUNetId(netid)

    local start = GetGameTimer()
    while not UtilityNet.IsEntityRendered(obj) do
        if GetGameTimer() - start > 5000 then
            error("GetNetScriptInstance: timed out IsEntityRendered for netid "..tostring(netid)..", obj "..tostring(obj), 2)
        end
        Citizen.Wait(0)
    end

    local model = GetEntityModel(obj)
    if not IsObjectScriptRegistered(model, name) then
        return nil
    end

    local start = GetGameTimer()
    while not Entity(obj).state.om_scripts_created do
        if GetGameTimer() - start > 5000 then
            error("GetNetScriptInstance: timed out, not all scripts created after 5s for netid "..tostring(netid)..", obj "..tostring(obj), 2)
        end

        warn(obj..' waiting for all scripts to be created')
        Citizen.Wait(0)
    end

    return GetObjectScriptInstance(obj, name)
end

function AreObjectScriptsFullyLoaded(obj)
    if not DoesEntityExist(obj) then
        warn("AreObjectScriptsFullyLoaded: object "..tostring(obj).." doesn't exist, skipping")
        return false
    end

    local entity = Entity(obj)
    if entity and entity.state and entity.state.om_loaded then
        return true
    end

    return false
end
--#endregion

RegisterCustomHook("OnStateChange", {
    OnSpawn = function(env, call)
        env.changeHandler = UtilityNet.AddStateBagChangeHandler(env.id, function(key, value)
            call(key, value)
        end)
    end,
    OnDestroy = function(env)
        UtilityNet.RemoveStateBagChangeHandler(env.changeHandler)
    end
})

if not UtilityNet then
    error("Please load the utility_lib before utility_objectify!")
end

local resource = GetCurrentResourceName()
UtilityNet.OnRender(function(id, obj, model)
    if UtilityNet.GetuNetIdCreator(id) ~= resource then
        return
    end

    if objectScripts[obj] then
        warn("Skipping render of "..id.." since it already has some registered scripts")
        return
    end

    if not registeredObjects[id] then
        CallOnRegister(id, model, GetEntityCoords(obj), GetEntityRotation(obj))
    else
        Citizen.Await(registeredObjects[id])
    end

    local created = CreateObjectScriptsInstances(obj)

    if not created then
        return
    end
    Entity(obj).state:set("om_scripts_created", true, false)

    local model = GetEntityModel(obj)
    Entity(obj).state:set("model", model, false) -- Preserve original model to fetch scripts (since can be replace with CreateModelSwap)

    CallMethodForAllObjectScripts(obj, "OnAwake")
    CallMethodForAllObjectScripts(obj, "OnSpawn")
    CallMethodForAllObjectScripts(obj, "AfterSpawn")

    -- Used for tracking object loading state
    Entity(obj).state:set("om_loaded", true, false)
    UtilityNet.PreserveEntity(id)
end)

UtilityNet.OnUnrender(function(id, obj, model)
    if not objectScripts[obj] then
        return
    end

    CallMethodForAllObjectScripts(obj, "OnDestroy")
    objectScripts[obj] = nil

    if Config?.ObjectManagementDebug?.Deleting then
        developer(tag, "Deleting ^4"..GetEntityArchetypeName(obj).."^0 instances")
    end

    DeleteEntity(obj)
end)

RegisterNetEvent("Utility:Net:EntityCreated", function(_, uNetId, model, coords, rotation)
    if registeredObjects[uNetId] then
        return
    end

    rotation = rotation or vec3(0, 0, 0)
    CallOnRegister(uNetId, model, coords, rotation)
end)

RegisterNetEvent("Utility:Net:RequestDeletion", function(uNetId, model, coords, rotation)
    rotation = rotation or vec3(0, 0, 0)

    registeredObjects[uNetId] = nil
    CreateTempObjectAndCallMethod(uNetId, model, "OnUnregister", coords, rotation)
    tempObjectsProperties[uNetId] = nil -- Clear all temp properties on deletion (always)
end)

Citizen.CreateThread(function()
    local entities = UtilityNet.GetServerEntities({
        where = {createdBy = resource},
        select = {"id", "model", "coords", "options"}
    })

    for _, entity in pairs(entities) do
        if not registeredObjects[entity.id] then
            CallOnRegister(entity.id, entity.model, entity.coords, entity.options.rotation)
        end
    end
end)

--#region Debug
Citizen.CreateThread(function()
    if DevModeStatus then
        while true do
            local found, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())

            if found and objectScripts[entity] then
                local coords = GetEntityCoords(entity)
                local text = "INSTANCES:"

                for name, instance in pairs(objectScripts[entity]) do
                    text = text .. "\n"..name.." : "..tostring(instance)
                end

                DrawText3Ds(coords, text)
            end
            
            Citizen.Wait(1)
        end
    end
end)
--#endregion

------------------------------------

end


--MERGE @utility_objectify/server/api.lua
if IsDuplicityVersion() then
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
        
        -- Give time to the children to be added
        Citizen.SetTimeout(1, function()
            self:callOnAll("OnAwake")
            self:callOnAll("OnSpawn")
            self:callOnAll("AfterSpawn")
        end)
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

            -- Give time to the children to be added
            Citizen.SetTimeout(1, function()
                self:callOnAll("OnAwake")
                self:callOnAll("OnSpawn")
                self:callOnAll("AfterSpawn")
            end)
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

end


