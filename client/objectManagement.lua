-- v1.2
local tag = "^3ObjectManagement^0"
local modelScripts = {}
local objectScripts = {}
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
        local instance = GetObjectScriptInstance(obj, v.name)

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

function GetObjectScriptInstance(obj, name)
    if not UtilityNet.GetUNetIdFromEntity(obj) then return end -- Object is not networked

    -- Wait that the object is rendered
    while not UtilityNet.IsEntityRendered(obj) do
        Citizen.Wait(0)
    end

    if not obj then
        error("GetObjectScriptInstance: obj is nil, name: "..name)
    end

    local model = GetEntityModel(obj)

    if not objectScripts[obj] then
        -- Check if script should be loaded
        if _IsObjectScriptRegistered(model, name) then
            -- Wait for script to be loaded
            while not objectScripts[obj] or not objectScripts[obj][name] do
                Citizen.Wait(0)
            end
        else
            error("GetObjectScriptInstance: requested script instance "..name.." for "..GetEntityArchetypeName(obj).." but it doesnt have any scripts loaded")
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
    if not netid then error("GetNetScriptInstance: passed netid is nil") return end

    local start = GetGameTimer()
    while not UtilityNet.IsReady(netid) do
        if GetGameTimer() - start > 5000 then
            error("GetNetScriptInstance: timed out IsReady for netid "..tostring(netid))
        end
        Citizen.Wait(0)
    end

    local obj = UtilityNet.GetEntityFromUNetId(netid)

    local start = GetGameTimer()
    while not UtilityNet.IsEntityRendered(obj) do
        if GetGameTimer() - start > 5000 then
            error("GetNetScriptInstance: timed out IsEntityRendered for netid "..tostring(netid)..", obj "..tostring(obj))
        end
        Citizen.Wait(0)
    end

    return GetObjectScriptInstance(obj, name)
end

function AreObjectScriptsFullyLoaded(obj)
    if not DoesEntityExist(obj) then
        print("AreObjectScriptsFullyLoaded: object "..tostring(obj).." doesn't exist, skipping")
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

UtilityNet.OnRender(function(id, obj, model)
    if not objectScripts[obj] then
        local created = CreateObjectScriptsInstances(obj)

        if not created then
            return
        end

        local model = GetEntityModel(obj)
        Entity(obj).state:set("model", model, false) -- Preserve original model to fetch scripts (since can be replace with CreateModelSwap)

        CallMethodForAllObjectScripts(obj, "OnAwake")
        CallMethodForAllObjectScripts(obj, "OnSpawn")
        CallMethodForAllObjectScripts(obj, "AfterSpawn")

        -- Used for tracking object loading state
        Entity(obj).state:set("om_loaded", true, false)
    end
end)
UtilityNet.OnUnrender(function(id, obj, model)
    if objectScripts[obj] then
        UtilityNet.PreserveEntity(id)
        CallMethodForAllObjectScripts(obj, "OnDestroy")
        objectScripts[obj] = nil

        if Config?.ObjectManagementDebug?.Deleting then
            developer(tag, "Deleting ^4"..GetEntityArchetypeName(obj).."^0 instances")
        end

        DeleteEntity(obj)
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