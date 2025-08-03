-- v1.1
IsServer = true
IsClient = false

local namespace = (Config?.Namespace or GetCurrentResourceName()) .. ":"
local callbacks = {}

local exposedEntitiesRpcs = {} -- Used to store all class exposed rpcs

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
        AddEventHandler(name, fn)
    else
        callbacks[sig.name] = true

        RegisterNetEvent(name)
        AddEventHandler(name, function(id, ...)
            local source = source
            
            -- For make the return of lua works
            local _cb = table.pack(fn(...))
            
            if _cb ~= nil then -- If the callback is not nil
                TriggerClientEvent(name, source, id, _cb) -- Trigger the client event
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

function rpc_entity(className, fn, _return)
    local sig = leap.fsignature(fn)
    local ogname = sig.name
    sig.name =  className.."."..sig.name
    
    --[[
    -- This function is used as a "global" function to expose a rpc to the client for a specific class
    -- Clients will pass as first argument the id of the entity and it will call the function in the object class
    -- Example:
    --   class Test extends BaseEntity {
    --       @rpc()
    --       test = function(a)
    --           print("from client:", a)
    --       end
    --   }
    --
    --   When the client calls the rpc this is the call stack:
    --    client: send call to Test.test (className:fn) passing as first argument the uNetId of the entity
    --    server: call a global function that will resolve the entity from the uNetId and call the appropriate function
    --]]
    local _fn = leap.registerfunc(function(id, ...)
        local source = source
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

    if rpc_hasreturn(fn, _return) then
        TriggerClientEvent(namespace.."RegisterCallback", -1, sig.name) -- Register the callback on runtime for connected clients!
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

@rpc(true)
function GetCallbacks()
    return callbacks
end


function GenerateCallbackId()
    return "cb"..GetHashKey(tostring(math.random()) .. GetGameTimer())
end

function AwaitCallback(name, cid, id)
    local p = promise.new()        
    Citizen.SetTimeout(5000, function()
        if p.state == 0 then
            warn("Client callback ${name}(${tostring(id)}) sended to ${tostring(cid)} timed out")
            p:reject({})
        end
    end)

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
        local name = namespace..key

        return function(cid: number, ...)
            local id = GenerateCallbackId()
            local p = AwaitCallback(name, cid, id)
            
            TriggerClientEvent(name, cid, id, ...)
            return table.unpack(Citizen.Await(p))
        end
    end
})

Client = setmetatable({}, {
    __index = function(self, key)
        local name = namespace..key

        if key == "await" then
            return await
        else
            return function(cid: number, ...)
                TriggerClientEvent(name, cid, ...)
            end
        end
    end,
})

------

function model(_class, model, abstract)
    if type(model) == "table" then
        local models = {}

        for k,v in pairs(model) do
            local c_class = table.deepcopy(_class)
            models[v] = c_class

            c_class.__prototype.model = v
            c_class.__prototype.abstract = true
        end

        _class.__models = models
    elseif type(model) == "string" then
        _class.__prototype.model = model
        _class.__prototype.abstract = abstract
    end
end

function plugin(_class, plugin)
    if not _class.__prototype.__plugins then
        _class.__prototype.__plugins = {}
    end

    table.insert(_class.__prototype.__plugins, plugin)
end

function state(self, fn, key, value)
        if not self.__listenedStates then
        self.__listenedStates = {}
    end

    if not self.__listenedStates[key] then
        self.__listenedStates[key] = {}
    end

    table.insert(self.__listenedStates[key], {
        fn = fn,
        value = value
    })
end

function event(_class, fn, key)
    RegisterNetEvent(key)
    AddEventHandler(key, function(...)
        fn(...)
    end)
end