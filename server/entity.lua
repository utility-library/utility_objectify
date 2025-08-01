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