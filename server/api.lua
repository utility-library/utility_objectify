--@utility_objectify/server/entity.lua
if not UtilityNet then
    error("Please load the utility_lib before utility_objectify!")
end

class EntitiesSingleton {
    list = {},

    constructor = function()
        self.list = {}
    end,

    add = function(entity: BaseEntity)
        table.insert(self.list, entity)
    end,

    createByName = function(name: string)
        return _G[name]()
    end,

    remove = function(entity: BaseEntity)
        local key = table.find(self.list, entity)
        table.remove(self.list, key)
    end,

    get = function(id: number)
        local _, entity = table.find(self.list, function(entity) 
            return entity.id == id
        end)

        return entity
    end,

    getBy = function(key: string, value)
        local _, entity = table.find(self.list, function(entity)
            if type(value) == "function" then
                return value(entity[key])
            else
                return entity[key] == value
            end
        end)
        
        return entity
    end,

    getAllBy = function(key: string, value)
        return table.filter(self.list, function(entity)
            if type(value) == "function" then
                return value(entity[key])
            else
                return entity[key] == value
            end
        end)
    end
}

@skipSerialize({"plugins", "_plugins", "id", "state", "main", "isPlugin"})
class BaseEntity {
    id = nil,
    state = nil,
    main = nil,

    constructor = function(coords: vector3 | nil, rotation: vector3 | nil, options = {})
        if self.isPlugin then
            return
        end

        Entities:add(self)

        if self._plugins then
            self.plugins = {}
            for k,v in pairs(self._plugins) do
                local _plugin = _G[v]

                -- Dont call the constructor (reduce useless calls,it will be skipped anyway)
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
        
        if self.id and UtilityNet.DoesUNetIdExist(self.id) then
            if self.OnDestroy then
                self:OnDestroy()
            end

            UtilityNet.DeleteEntity(self.id)
        end
    end,

    init = function(id, state)
        self.id = id
        self.state = state

        if self.OnAwake then
            self:OnAwake()
        end
        if self.OnSpawn then
            self:OnSpawn()
        end
        if self.AfterSpawn then
            self:AfterSpawn()
        end
    end,

    create = function(coords: vector3, rotation: vector3 | nil, options = {})
        if not self.model then
            error("${type(self)}: trying to create entity without model, please use the model decorator to set the model")
        end

        options.rotation = options.rotation or rotation
        options.abstract = options.abstract or self.abstract

        local id = UtilityNet.CreateEntity(self.model, coords, options)
        local state = UtilityNet.State(self.id)

        self:init(id, state)

        if self.plugins then
            for k,v in pairs(self.plugins) do
                v:init(self.id, self.state)
            end
        end
    end,
}

Entities = new EntitiesSingleton()

------------------------------------

--@utility_objectify/server/framework.lua
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
    if not _class.__prototype._plugins then
        _class.__prototype._plugins = {}
    end

    table.insert(_class.__prototype._plugins, plugin)
end

------------------------------------

