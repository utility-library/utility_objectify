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

    get = function(entity: BaseEntity)
        local _, entity = table.find(self.list, entity)

        return entity
    end,

    getBy = function(key: string, value)
        local _, entity = table.find(self.list, function(entity)
            return entity[key] == value
        end)
        
        return entity
    end
}

class BaseEntity {
    id = nil,
    state = nil,

    constructor = function(coords: vector3 | nil, rotation: vector3 | nil, options = {})
        Entities:add(self)

        if coords != nil then
            self:create(coords, rotation, options)
        end
    end,

    deconstructor = function()
        Entities:remove(self)

        if self.OnDestroy then
            self:OnDestroy()
        end

        UnregisterEntity(self)
        UtilityNet.DeleteEntity(self.id)
    end,

    create = function(coords: vector3, rotation: vector3 | nil, options = {})
        if not self.model then
            error("${type(self)}: trying to create entity without model, please use the model decorator to set the model")
        end

        options.rotation = options.rotation or rotation
        options.abstract = options.abstract or self.abstract

        self.id = UtilityNet.CreateEntity(self.model, coords, options)
        self.state = UtilityNet.State(self.id)

        RegisterEntity(self)
        
        if self.OnAwake then
            self:OnAwake()
        end
        if self.OnSpawn then
            self:OnSpawn()
        end
        if self.AfterSpawn then
            self:AfterSpawn()
        end
    end
}

Entities = new EntitiesSingleton()

------------------------------------

--@utility_objectify/server/framework.lua
-- v1.1
IsServer = true
IsClient = false

local namespace = (Config?.Namespace or GetCurrentResourceName()) .. ":"
local callbacks = {}

local rpcEntities = {} -- Used to store all class exposed rpcs

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
        local _class = Entities:getBy("id", id)
        
        if not _class then
            error("${ogname}(${source}): Entity with id ${tostring(id)} does not exist")
            return
        end

        local className2 = type(_class)
        if className2 != className then
            error("${ogname}(${source}): Entity with id ${tostring(id)} is not a ${className}")
            return
        end

        if not _class[ogname] then
            error("${ogname}(${source}): Class ${className} doesnt define ${ogname}")
            return
        end

        if not rpcEntities[className] then
            error("${ogname}(${className}): Class ${className} doesnt expose any rpcs")
            return
        end

        if not rpcEntities[className][ogname] then
            error("${ogname}(${source}): Class ${className} doesnt expose ${ogname}")
            return
        end

        if rpcEntities[className][ogname] then
            return _class[ogname](_class, ...)
        end
    end, sig)

    rpc_function(_fn, _return)

    if rpc_hasreturn(fn, _return) then
        TriggerClientEvent(namespace.."RegisterCallback", -1, sig.name) -- Register the callback on runtime for connected clients!
    end
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
        local className = type(class)

        if not rpcEntities[className] then
            rpcEntities[className] = {}
        end

        if not rpcEntities[className][sig.name] then
            rpcEntities[className][sig.name] = true -- Set the rpc as exposed

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

------------------------------------

