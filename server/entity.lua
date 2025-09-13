if not UtilityNet then
    error("Please load the utility_lib before utility_objectify!")
end

local client_rpc_mt, client_plugin_rpc_mt = nil -- hoisting
client_rpc_mt = {
    __index = function(self, key)
        -- Create "plugins" and "await" at runtime, this reduce memory footprint
        if key == "plugins" then
            local id = rawget(self, "id")
            local __type = rawget(self, "__type")
            local _await = rawget(self, "_await")

            local plugins = setmetatable({id = id, __type = __type, _await = _await}, client_plugin_rpc_mt)
            rawset(self, "plugins", plugins) -- Caching
            return plugins
        end

        if key == "await" then
            local id = rawget(self, "id")
            local __type = rawget(self, "__type")

            local await = setmetatable({id = id, __type = __type, _await = true}, client_rpc_mt)
            rawset(self, "await", await) -- Caching
            return await
        end


        local method = self.__type .. "." .. key
    
        local fn = function(...)
            local n = select("#", ...)

            if n == 0 then -- No args, so also no client id
                error("${method} requires the client id as the first argument!", 2)
            end

            if n > 0 then
                local first, second = ...
                local selfCall = first and type(first) == self.__type and first.id == self.id
                
                local cid = selfCall and second or first
                if type(cid) != "number" then
                    error("${method} requires the client id as the first argument!", 2)
                end
                
                local hasAwait = rawget(self, "_await")

                -- 3 and 2 because the first argument is the client id and should always be ignored
                if hasAwait then
                    -- Cant do selfCall and or since the first argument can be nil
                    if selfCall then
                        return Client.await[method](cid, self.id, select(3, ...))
                    else
                        return Client.await[method](cid, self.id, select(2, ...))
                    end
                else
                    if selfCall then
                        return Client[method](cid, self.id, select(3, ...))
                    else
                        return Client[method](cid, self.id, select(2, ...))
                    end
                end
            end
        end

        rawset(self, key, fn) -- Caching
        return fn
    end,
    __newindex = function(self, key, value)
        error("You can't register ${IsServer and 'server' or 'client'} methods from the ${IsServer and 'client' or 'server'}, please register them from the ${IsServer and 'server' or 'client'} using the rpc decorator!")
    end
}

client_plugin_rpc_mt = {
    __index = function(self, key)
        -- Create a client_rpc_mt with the plugin name and add the plugin type
        local proxy = setmetatable({
            id = self.id,
            __type = type(self) .. "." .. key,
            plugins = self,
            _await = rawget(self, "_await")
        }, client_rpc_mt)

        rawset(self, key, proxy) -- Caching
        return proxy
    end,
    __newindex = function(self, key, value)
        error("You can't register ${IsServer and 'server' or 'client'} methods from the ${IsServer and 'client' or 'server'}, please register them from the ${IsServer and 'server' or 'client'} using the rpc decorator!")
    end
}

-- Use always the same reference and create a new table only if needed, this reduce memory footprint
local EMPTY_PLUGINS = {}
local EMPTY_CHILDREN = {}

@skipSerialize({"plugins", "children", "parent", "id", "state", "main", "isPlugin"})
class BaseEntity {
    id = nil,
    state = nil,
    main = nil,
    parent = nil,

    constructor = function(coords: vector3 | nil, rotation: vector3 | nil, options = {})
        if self.isPlugin then
            return
        end

        self.children = EMPTY_CHILDREN
        self.plugins = EMPTY_PLUGINS

        if self.__plugins then
            self.plugins = {}

            for k,v in pairs(self.__plugins) do
                local _plugin = _G[v]

                -- Dont call the constructor (reduce useless calls, it will be skipped anyway)
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

    init = function(id, state, client)
        self.id = id
        self.state = state
        self.client = client

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
        local _type = type(self)

        if not self.model then
            error("${_type}: trying to create entity without model, please use the model decorator to set the model")
        end

        options.rotation = options.rotation or rotation
        options.abstract = options.abstract or self.abstract

        local id = UtilityNet.CreateEntity(self.model, coords, options)
        local state = UtilityNet.State(id)
        local client = setmetatable({id = id, __type = _type}, client_rpc_mt)

        self:init(id, state, client)
        Entities:add(self)
        
        self:callOnAll("OnAwake")

        -- Give time to the children to be added
        Citizen.SetTimeout(1, function()
            self:callOnAll("OnSpawn")
        end)

        self:callOnAll("AfterSpawn")
    end,

    addChild = function(name: string, child: BaseEntity)
        if not child.id then
            error("${type(self)}: trying to add a child that hasnt been created yet")
        end

        local exist = table.find(self.children, child)
        if exist then
            return
        end
        
        local _root = self        
        while _root.parent do
            _root = _root.parent
        end
        
        child.parent = self
        child.root = _root

        child.state.parent = self.id
        child.state.root = _root.id

        if self.children == EMPTY_CHILDREN then
            self.children = {}
        end

        self.children[name] = child

        if not self.state.children then
            self.state.children = {[name] = child.id}
        else
            self.state.children[name] = child.id
        end
    end,

    removeChild = function(childOrName: BaseEntity | string)
        if type(childOrName) == "string" then
            self.children[childOrName] = nil
            self.state.children[childOrName] = nil
        else
            for name, child in pairs(self.children) do
                if child == childOrName then
                    self.children[name] = nil
                    break
                end
            end
            
            for name, id in pairs(self.state.children) do
                if id == childOrName.id then
                    self.state.children[name] = nil
                    break
                end
            end
        end
    end,

    getChild = function(path: string)
        if path:find("/") then
            local child = self

            for str in path:gmatch("([^/]+)") do
                if not child or not child.children then
                    return nil
                end

                child = child.children[str]
            end

            return child
        end

        return self.children[path]
    end,

    getChildBy = function(key: string, value)
        for name, child in pairs(self.children) do
            if type(value) == "function" then
                if value(child[key]) then
                    return child
                end
            else
                if child[key] == value then
                    return child
                end
            end
        end

        return nil
    end,

    getChildrenBy = function(key: string, value)
        local children = {}

        for name, child in pairs(self.children) do
            if type(value) == "function" then
                if value(child[key]) then
                    children[name] = child
                end
            else
                if child[key] == value then
                    children[name] = child
                end
            end
        end

        return children
    end
}