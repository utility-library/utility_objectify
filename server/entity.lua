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

    create = function(coords: vector3, rotation: vector3 | nil, options = {})
        if not self.model then
            error("${type(self)}: trying to create entity without model, please use the model decorator to set the model")
        end

        options.rotation = options.rotation or rotation
        options.abstract = options.abstract or self.abstract

        self.id = UtilityNet.CreateEntity(self.model, coords, options)
        self.state = UtilityNet.State(self.id)

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