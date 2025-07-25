--@utility_objectify/client/framework.lua
-- v1.1
IsServer = false
IsClient = true

local callbacksLoaded = false
local callbacks = {["GetCallbacks"] = true}
local namespace = (Config?.Namespace or GetCurrentResourceName()) .. ":"

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
            local args = {...}

            if type(args[1]) == self.__type and args[1].id == self.id then -- Is self
                table.remove(args, 1)
            end

            return Server["${type(self)}.${key}"](self.id, table.unpack(args))
        end
    end,
    __newindex = function(self, key, value)
        error("You can't register server methods from the client, please register them from the server using the rpc decorator!")
    end
}

class BaseEntity {
    server = nil,
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

function rpc_hasreturn(fn, _return)
    local sig = leap.fsignature(fn)
    return _return != nil ? _return : sig.has_return
end

function rpc_function(fn, _return)
    local sig = leap.fsignature(fn)
    _return = rpc_hasreturn(fn, _return)
    
    local name = namespace..sig.name

    if not _return then
        RegisterNetEvent(name)
        AddEventHandler(name, function(...)
            local a = {...}
            if type(a[1]) == "string" and a[1]:sub(1, 2) == "cb" then
                error("${sig.name}: You cannot call a standard rpc as a callback, please dont use `await`")
            end
            
            fn(...)
        end)
    else
        RegisterNetEvent(name)
        AddEventHandler(name, function(id, ...)
            if type(id) != "string" or id:sub(1, 2) != "cb" then
                error("${sig.name}: You cannot call a callback as a standard rpc, please use `await`")
            end

            -- For make the return of lua works
            local _cb = table.pack(fn(...))
            
            if _cb ~= nil then -- If the callback is not nil
                TriggerServerEvent(name, id, _cb) -- Trigger the server event
            end
        end)
    end
end

function rpc(fn, _return, c)
    if _type(fn) == "function" then
        rpc_function(fn, _return)
    else
        --[[ local class = fn
        local fn = _return
        local _return = c
        
        if not class is BaseEntity then
            error("The rpc decorator on classes is only allowed to be used on classes that inherit from BaseEntity")
        end

        local sig = leap.fsignature(fn)
        local className = type(class)

        if not rpcEntities[className] then
            rpcEntities[className] = {}
        end

        if not rpcEntities[className][sig.name] then
            rpcEntities[className][sig.name] = true -- Set the rpc as exposed

            -- Register global function that will handle "entity branching"
            rpc_entity(className, fn, _return)
        end ]]
    end
end

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
        local name = namespace..key

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

--@utility_objectify/client/objectManagement.lua
-- v1.4
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

    local instance = new script.script()

    instance.state = UtilityNet.State(uNetId)
    instance.id = uNetId
    instance.obj = obj

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
    
    -- Create script instances in registration order
    for k,v in ipairs(scripts) do
        objectScripts[obj][v.name] = CreateObjectScriptInstance(obj, k, "CreateInstances")
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
        return
    end

    while not registeredObjects[id] do -- Wait that OnRegister is properly called before OnAwake and etc (order of calls is important)
        Citizen.Wait(0)
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

RegisterNetEvent("Utility:Net:EntityCreated", function(_, object)
    CreateTempObjectAndCallMethod(object.id, object.model, "OnRegister")
    registeredObjects[object.id] = true
end)

RegisterNetEvent("Utility:Net:RequestDeletion", function(uNetId)
    registeredObjects[uNetId] = nil

    local model = GetEntityModel(UtilityNet.GetEntityFromUNetId(uNetId))
    if model then
        CreateTempObjectAndCallMethod(uNetId, model, "OnUnregister")
    else
        warn("OnUnregister: model not found for uNetId "..tostring(uNetId))
    end

    tempObjectsProperties[uNetId] = nil -- Clear all temp properties on deletion (always)
end)

Citizen.CreateThread(function()
    local sliced = UtilityNet.GetEntities()

    for slice, entities in pairs(sliced) do
        for uNetId,v in pairs(entities) do
            CreateTempObjectAndCallMethod(uNetId, v.model, "OnRegister")
            registeredObjects[uNetId] = true
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

