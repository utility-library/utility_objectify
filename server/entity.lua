if not UtilityNet then
    error("Please load the utility_lib before utility_objectify!")
end

class BaseEntity {
    id = nil,
    state = nil,

    constructor = function(coords: vector3 | nil, rotation: vector3 | nil, options = {})
        if coords != nil then
            self:create(coords, rotation, options)
        end
    end,

    deconstructor = function()
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