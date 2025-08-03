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

@skipSerialize({"plugins", "id", "state", "main", "isPlugin"})
class BaseEntity {
    id = nil,
    state = nil,
    main = nil,

    constructor = function(coords: vector3 | nil, rotation: vector3 | nil, options = {})
        if self.isPlugin then
            return
        end

        Entities:add(self)

        if self.__plugins then
            self.plugins = {}
            for k,v in pairs(self.__plugins) do
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

        if self.__stateChangeHandler then
            UtilityNet.RemoveStateBagChangeHandler(self.__stateChangeHandler)
        end
    end,

    init = function(id, state)
        self.id = id
        self.state = state

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
        if not self.model then
            error("${type(self)}: trying to create entity without model, please use the model decorator to set the model")
        end

        options.rotation = options.rotation or rotation
        options.abstract = options.abstract or self.abstract

        local id = UtilityNet.CreateEntity(self.model, coords, options)
        local state = UtilityNet.State(id)

        self:init(id, state)
        
        self:callOnAll("OnAwake")
        self:callOnAll("OnSpawn")
        self:callOnAll("AfterSpawn")
    end,
}

Entities = new EntitiesSingleton()