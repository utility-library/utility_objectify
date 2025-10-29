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