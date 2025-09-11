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