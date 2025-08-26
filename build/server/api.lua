if not leap then leap={}end;if not leap.deserialize then leap.deserialize=function(a,b)b=b or{}if b[a]then return b[a]end;local c=_type(a)if c~="table"or not a.__type then if c=="table"then if type(a.x)=="number"and type(a.y)=="number"then if type(a.z)=="number"then if type(a.w)=="number"then return vector4(a.x,a.y,a.z,a.w)else return vector3(a.x,a.y,a.z)end else return vector2(a.x,a.y)end else local d={}b[a]=d;for e,f in pairs(a)do d[e]=leap.deserialize(f,b)end;return d end else return a end end;local g=_G[a.__type]if not g then error("Class '"..a.__type.."' not found",2)end;g.__skipNextConstructor=true;local h=g()b[a]=h;if h.deserialize then h:deserialize(a)else for e,f in pairs(a)do if e~="__type"then h[e]=leap.deserialize(f,b)end end end;return h end end;if not leap.serialize then leap.serialize=function(a,b)b=b or{}local c=_type(a)if c~="table"then return a end;if b[a]then return b[a]end;if a.serialize then local i=a:serialize()if not i then return nil end;if type(i)~="table"then error("leap.serialize: custom serialize method must return a table",2)end;b[a]=i;for e,f in pairs(i)do i[e]=leap.serialize(f,b)end;i.__type=a.__type;return i end;local j={__stack=true,__parent=true,super=true}if a.__ignoreList then for e,f in pairs(a.__ignoreList)do j[f]=true end end;local d=_leap_internal_deepcopy(a,b,j,true)b[a]=d;return d end end;if not skipSerialize then skipSerialize=function(k,l)if _type(k)~="table"then error("skipSerialize: #1 passed argument must be a class, but got "..type(k),2)end;if not k.__prototype.__ignoreList then k.__prototype.__ignoreList={}end;if _type(l)=="table"then for e,f in pairs(l)do k.__prototype.__ignoreList[f]=true end elseif _type(l)=="string"then k.__prototype.__ignoreList[l]=true else error("skipSerialize: #2 passed argument must be a table or a string, but got "..type(l),2)end end end;if not leap.fsignature then leap.fsignature=function(m)if _type(m)~="function"then error("leap.fsignature: passed argument must be a function, but got ".._type(m),2)end;if not __leap__introspection then return nil end;return __leap__introspection[m]end end;if not leap.registerfunc then leap.registerfunc=function(m,n)if not __leap__introspection then __leap__introspection=setmetatable({},{__mode="k"})end;__leap__introspection[m]=n;return m end end;if not leap.minimal then leap.minimal=false end;if not table.clone then table.clone=function(o)local d={}for e,f in pairs(o)do d[e]=f end;return d end end;if not _leap_internal_deepcopy then _leap_internal_deepcopy=function(o,p,q,r)if _type(o)~="table"then return o end;p=p or{}if p[o]then return p[o]end;local s=table.clone(o)p[o]=s;for e,f in next,o do if q and q[e]then s[e]=nil else local t=_type(f)if t=="function"and r then s[e]=nil else if t=="table"then if f.__type~=nil then s[e]=leap.serialize(f,p)else s[e]=_leap_internal_deepcopy(f,p,q,r)end else s[e]=f end end end end;return s end end;if not _type then _type=type;type=function(u)local v=_type(u)if v=="table"and u.__type then return u.__type else return v end end end;if not _leap_internal_classBuilder then _leap_internal_classBuilder=function(a,b,c)b._leap_internal_decorators={}if not c then error("ExtendingNotDefined: "..a.." tried to extend a class that is not defined",2)end;if c.__prototype then b.__parent=c end;local d={__cache={},__newindex=function(e,f,g)rawset(e,f,g)getmetatable(e).__cache[f]=nil end}setmetatable(b,d)local h=b;local i={}while h do for f,g in next,h do if not i[f]then if _type(g)=="table"and f:sub(1,5)~="_leap"and f:sub(1,2)~="__"then i[f]=h end end end;if not h.__parent then break end;h=h.__parent.__prototype end;local j={__index=function(self,k)if not k then return nil end;if k:sub(1,2)=="__"then return rawget(b,k)end;local l=getmetatable(b).__cache;local h=b;if not l[k]then while h do if rawget(h,k)~=nil then l[k]=h;break end;if not h.__parent then return nil end;h=h.__parent.__prototype end else end;local h=l[k]return h[k]end,__gc=function(self)if self.destructor then self:destructor()end end,__tostring=function(self)if self.toString then return self:toString()else local m=""if not leap.minimal then for f,g in pairs(self)do if f~="super"and f:sub(1,5)~="_leap"and f:sub(1,2)~="__"then local n=_type(g)if n~="function"then local o=g;if n=="table"then if g.__type then o="<"..g.__type..":"..("%p"):format(g)..">"else o=tostring(g)end end;if n=="string"then o='"'..g..'"'end;m=m..f..": "..tostring(o)..", "end end end;m=m:sub(1,-3)end;return"<"..self.__type..":"..("%p"):format(self).."> "..m end end}_G[a]=setmetatable({__type=a,__prototype=b},{__newindex=function(self,f,g)if f:sub(1,2)=="__"then rawset(self,f,g)else error("attempt to assign class property '"..f.."' directly, please instantiate the class before assigning any properties",2)end end,__call=function(self,...)local p={__type=self.__type}for k,q in pairs(i)do p[k]=_leap_internal_deepcopy(q[k])end;setmetatable(p,j)for r,s in pairs(p._leap_internal_decorators)do local t=p[s.name]local u=function(...)return t(p,...)end;leap.registerfunc(u,leap.fsignature(t))if not _G[s.decoratorName]then error("Decorator "..s.decoratorName.." does not exist",2)end;p[s.name]=_G[s.decoratorName](p,u,table.unpack(s.args))or t end;if not self.__skipNextConstructor then local v=p.constructor;if v then local w,x=pcall(v,p,...)if not w then error(x,2)end end end;self.__skipNextConstructor=nil;return p end})end;_leap_internal_classBuilder("Error",{constructor=function(self,y)self.message=y end,toString=function(self)return type(self)..": "..self.message end},{})end;if not _leap_internal_is_operator then _leap_internal_is_operator=function(p,z)if not p or not z then return false end;if _type(p)~="table"then return _type(p)==type(z)end;if _type(z)~="table"then error("leap.is_operator: #2 passed argument must be a class, but got ".._type(z),2)end;if p.__prototype then error("leap.is_operator: #1 passed argument must be a class instance, but got class",2)end;local A=p;while A and A.__type~=z.__type do if A.__parent or A.__prototype.__parent then A=A.__parent or A.__prototype.__parent else return false end end;return true end end; 
model = leap.registerfunc(function(_class, model, abstract)
    if type(model) == "table" then
        local models = {}

        for k,v in pairs(model) do
            local c_class = deepcopy(_class)
            models[v] = c_class

            c_class.__prototype.model = v
            
            if IsClient then
                RegisterObjectScript(v, "main", c_class)
            elseif IsServer then
                c_class.__prototype.abstract = true
            end
        end

        _class.__models = models
    elseif type(model) == "string" then
        _class.__prototype.model = model

        if IsClient then
            RegisterObjectScript(model, "main", _class)
        elseif IsServer then
            _class.__prototype.abstract = abstract
        end
    end
end, {args={{name = "_class"},{name = "model"},{name = "abstract"},},name="model",})

plugin = leap.registerfunc(function(_class, plugin)
    if IsClient then
        Citizen.CreateThread(function()
            if _class.__models then
                for model,_class in pairs(_class.__models) do
                    if _G[plugin].__prototype.OnPluginApply then
                        _G[plugin].__prototype.OnPluginApply({}, _class.__prototype)
                    end
                
                    RegisterObjectScript(model, plugin, _G[plugin])
                end
            else
                local model = _class.__prototype.model
            
                if _G[plugin].__prototype.OnPluginApply then
                    _G[plugin].__prototype.OnPluginApply({}, _class.__prototype)
                end
            
                RegisterObjectScript(model, plugin, _G[plugin])
            end
        end)
    elseif IsServer then
        if not _class.__prototype.__plugins then
            _class.__prototype.__plugins = {}
        end

        if _class.__models then
            for model,_class in pairs(_class.__models) do
                table.insert(_class.__prototype.__plugins, plugin)
            end
        else
            local model = _class.__prototype.model
        
            table.insert(_class.__prototype.__plugins, plugin)
        end
    end
end, {args={{name = "_class"},{name = "plugin"},},name="plugin",})

state = leap.registerfunc(function(self, fn, key, value)
    if not self.listenedStates then
        self.listenedStates = {}
    end

    if not self.listenedStates[key] then
        self.listenedStates[key] = {}
    end

    table.insert(self.listenedStates[key], {
        fn = fn,
        value = value
    })
end, {args={{name = "self"},{name = "fn"},{name = "key"},{name = "value"},},name="state",})

event = leap.registerfunc(function(self, fn, key, ignoreRendering)
    RegisterNetEvent(key)
    AddEventHandler(key, function(...)
        if IsClient then
            if ignoreRendering then
                fn(...)
            else
                if AreObjectScriptsFullyLoaded(self.obj) then       
                    fn(...)
                end
            end
        elseif IsServer then
            fn(...)
        end
    end)
end, {args={{name = "self"},{name = "fn"},{name = "key"},{name = "ignoreRendering"},},name="event",})



 
_leap_internal_classBuilder("EntitiesSingleton",{
    list = {},

    constructor = leap.registerfunc(function(self)
        self.list = {}
    end, {args={},name="constructor",}),

    add = leap.registerfunc(function(self, entity)if _type(entity) ~= "table" and not _leap_internal_is_operator(entity, BaseEntity) then error('entity: must be (BaseEntity) or a derived class but got '..type(entity)..'', 2) end;
        self.list[entity.id] = entity
    end, {args={{name = "entity"},},name="add",}),

    createByName = leap.registerfunc(function(self, name)if type(name) ~= "string" then error('name: must be (string) but got '..type(name)..'', 2) end;
        return _G[name]()
    end, {args={{name = "name"},},name="createByName",has_return=true,}),

    remove = leap.registerfunc(function(self, entity)if _type(entity) ~= "table" and not _leap_internal_is_operator(entity, BaseEntity) then error('entity: must be (BaseEntity) or a derived class but got '..type(entity)..'', 2) end;
        self.list[entity.id] = nil
    end, {args={{name = "entity"},},name="remove",}),

    get = leap.registerfunc(function(self, id)if type(id) ~= "number" then error('id: must be (number) but got '..type(id)..'', 2) end;
        return self.list[id]
    end, {args={{name = "id"},},name="get",has_return=true,}),

    getBy = leap.registerfunc(function(self, key, value)if type(key) ~= "string" then error('key: must be (string) but got '..type(key)..'', 2) end;
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
    end, {args={{name = "key"},{name = "value"},},name="getBy",has_return=true,}),

    getAllBy = leap.registerfunc(function(self, key, value)if type(key) ~= "string" then error('key: must be (string) but got '..type(key)..'', 2) end;
        return table.filter(self.list, leap.registerfunc(function(_, entity)
            if type(value) == "function" then
                return value(entity[key])
            else
                return entity[key] == value
            end
        end, {args={{name = "_"},{name = "entity"},},name="table.filter",has_return=true,}))
    end, {args={},name="getAllBy",})
}, {})

Entities = EntitiesSingleton()



 
local exposedEntitiesRpcs = {}        
local callbacks = {}
local namespace = (Config?.Namespace or GetCurrentResourceName()) .. ":"

if not IsDuplicityVersion() then
    callbacks["GetCallbacks"] = true
end

local  rpc_hasreturn = leap.registerfunc(function(fn, _return)
    local sig = leap.fsignature(fn)
    return (function()if _return ~= nil then return  _return else return  sig.has_return end;end)()
end, {args={{name = "fn"},{name = "_return"},},name="rpc_hasreturn",has_return=true,})

local  rpc_function = leap.registerfunc(function(fn, _return)
    local sig = leap.fsignature(fn)
    _return = rpc_hasreturn(fn, _return)
    local tag = IsServer and "Server" or "Client"

    local name = namespace..""..(tag)..":"..sig.name

    if not _return then
        RegisterNetEvent(name)

        if IsServer then
            AddEventHandler(name, fn)
        else
            AddEventHandler(name, function(...)
                local first = ...
                if type(first) == "string" and first:sub(1, 2) == "cb" then
                    error(""..(sig.name)..": You cannot call a standard rpc as a callback, please dont use `await`")
                end
                
                fn(...)
            end)
        end
    else
        callbacks[sig.name] = true

        RegisterNetEvent(name)
        AddEventHandler(name, function(id, ...)
            if IsClient then
                if type(id) ~= "string" or id:sub(1, 2) ~= "cb" then
                    error(""..(sig.name)..": You cannot call a callback as a standard rpc, please use `await`")
                end
            end

            local source = source
            
                   
            local _cb = table.pack(fn(...))
            
            if _cb ~= nil then       
                if IsServer then
                    TriggerClientEvent(name, source, id, _cb)     
                else
                    TriggerServerEvent(name, id, _cb)     
                end
            end
        end)
    end
end, {args={{name = "id"},},name="rpc_function",})

local  checkRPCExposure = leap.registerfunc(function(ogname, source, classLabel, methodName)
    if not exposedEntitiesRpcs[classLabel] or not exposedEntitiesRpcs[classLabel][methodName] then
        error(""..(ogname).."("..(source).."): Class "..(classLabel).." doesn't expose "..(methodName).."")
        return false
    end

    return true
end, {args={{name = "ogname"},{name = "source"},{name = "classLabel"},{name = "methodName"},},name="checkRPCExposure",has_return=true,})

local  callRPC = leap.registerfunc(function(target, method, ...)
    return target[method](target, ...)
end, {args={{name = "target"},{name = "method"},},name="callRPC",has_return=true,})

local  rpc_entity = leap.registerfunc(function(className, fn, _return)
    local sig = leap.fsignature(fn)
    local ogname = sig.name
    sig.name = className.."."..sig.name
    
    
                        
                           
     
           
           
             
                 
           
       
    
                  
                       
                          
    
    local _fn = leap.registerfunc(leap.registerfunc(function(id, ...)
        local source = source or "SERVER"
        local entity = Entities:getBy("id", id)
        local tag = ""..(ogname).."("..(source)..")"

        if not entity then
            error(""..(tag)..": Entity with id "..(tostring(id)).." does not exist")
            return
        end

        local isPlugin = className:find("%.")
        if isPlugin then     
            local _className, pluginName = className:match("(.*)%.(.*)")

            if not entity.plugins or not entity.plugins[pluginName] then
                error(""..(tag)..": Entity with id "..(tostring(id)).." has no plugin "..(pluginName).."")
                return
            end

            if type(entity) ~= _className then
                error(""..(tag)..": Entity with id "..(tostring(id)).." is not a "..(className).."")
                return
            end

            local plugin = entity.plugins[pluginName]
            if not plugin[ogname] then
                error(""..(tag)..": Class "..(className).." doesnt define "..(ogname).."")
                return
            end

            if checkRPCExposure(ogname, source, className, ogname) then
                return callRPC(plugin, ogname, ...)
            end
        else
            if type(entity) ~= className then
                error(""..(tag)..": Entity with id "..(tostring(id)).." is not a "..(className).."")
                return
            end

            if not entity[ogname] then
                error(""..(tag)..": Class "..(className).." doesnt define "..(ogname).."")
                return
            end

            if checkRPCExposure(ogname, source, className, ogname) then
                return callRPC(entity, ogname, ...)
            end
        end
    end, {args={{name = "id"},},name="leap.registerfunc",has_return=true,}), sig)

    rpc_function(_fn, _return)

    if IsServer then
        if rpc_hasreturn(fn, _return) then
            TriggerClientEvent(namespace.."RegisterCallback", -1, sig.name)         
        end
    end

    sig.name = ogname
end, {args={},name="rpc_entity",})

rpc = leap.registerfunc(function(fn, _return, c)
    if _type(fn) == "function" then
        rpc_function(fn, _return)
    else
        local class = fn
        local fn = _return
        local _return = c
        
        if not _leap_internal_is_operator(class,  BaseEntity) then
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
            exposedEntitiesRpcs[className][sig.name] = true      

                    
            rpc_entity(className, fn, _return)
        end
    end
end, {args={{name = "fn"},{name = "_return"},{name = "c"},},name="rpc",})

srpc = leap.registerfunc(function(fn, _return, c)
    if IsServer then
        rpc(fn, _return, c)
    end
end, {args={{name = "fn"},{name = "_return"},{name = "c"},},name="srpc",})

crpc = leap.registerfunc(function(fn, _return, c)
    if IsClient then
        rpc(fn, _return, c)
    end
end, {args={{name = "fn"},{name = "_return"},{name = "c"},},name="crpc",})



 
if not UtilityNet then
    error("Please load the utility_lib before utility_objectify!")
end

local client_rpc_mt, client_plugin_rpc_mt = nil  
client_rpc_mt = {
    __index = leap.registerfunc(function(self, key)
                  
        if key == "plugins" then
            local id = rawget(self, "id")
            local __type = rawget(self, "__type")
            local _await = rawget(self, "_await")

            local plugins = setmetatable({id = id, __type = __type, _await = _await}, client_plugin_rpc_mt)
            rawset(self, "plugins", plugins)  
            return plugins
        end

        if key == "await" then
            local id = rawget(self, "id")
            local __type = rawget(self, "__type")

            local await = setmetatable({id = id, __type = __type, _await = true}, client_rpc_mt)
            rawset(self, "await", await)  
            return await
        end


        local method = self.__type .. "." .. key
    
        local fn = leap.registerfunc(function(...)
            local n = select("#", ...)

            if n == 0 then        
                error(""..(method).." requires the client id as the first argument!", 2)
            end

            if n > 0 then
                local first, second = ...
                local selfCall = first and type(first) == self.__type and first.id == self.id
                
                local cid = selfCall and second or first
                if type(cid) ~= "number" then
                    error(""..(method).." requires the client id as the first argument!", 2)
                end
                
                local hasAwait = rawget(self, "_await")

                                
                if hasAwait then
                                
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
        end, {args={{name = "self"},{name = "key"},},name="fn",has_return=true,})

        rawset(self, key, fn)  
        return fn
    end, {args={},name="__index",has_return=true,}),
    __newindex = leap.registerfunc(function(self, key, value)
        error("You can't register "..(IsServer and 'server' or 'client').." methods from the "..(IsServer and 'client' or 'server')..", please register them from the "..(IsServer and 'server' or 'client').." using the rpc decorator!")
    end, {args={{name = "self"},{name = "key"},{name = "value"},},name="__newindex",})
}

client_plugin_rpc_mt = {
    __index = leap.registerfunc(function(self, key)
                    
        local proxy = setmetatable({
            id = self.id,
            __type = type(self) .. "." .. key,
            plugins = self,
            _await = rawget(self, "_await")
        }, client_rpc_mt)

        rawset(self, key, proxy)  
        return proxy
    end, {args={{name = "self"},{name = "key"},},name="__index",has_return=true,}),
    __newindex = leap.registerfunc(function(self, key, value)
        error("You can't register "..(IsServer and 'server' or 'client').." methods from the "..(IsServer and 'client' or 'server')..", please register them from the "..(IsServer and 'server' or 'client').." using the rpc decorator!")
    end, {args={{name = "self"},{name = "key"},{name = "value"},},name="__newindex",})
}

 _leap_internal_classBuilder("BaseEntity",
  {
    id = nil,
    state = nil,
    main = nil,

    constructor = leap.registerfunc(function(self, coords, rotation, options)if type(coords) ~= "vector3" and type(coords) ~= "nil" then error('coords: must be (vector3 | nil) but got '..type(coords)..'', 2) end;if type(rotation) ~= "vector3" and type(rotation) ~= "nil" then error('rotation: must be (vector3 | nil) but got '..type(rotation)..'', 2) end;if options == nil then options = {} end;
        if self.isPlugin then
            return
        end

        if self.__plugins then
            self.plugins = {}
            for k,v in pairs(self.__plugins) do
                local _plugin = _G[v]

                            
                _plugin.__skipNextConstructor = true
                
                                  
                _plugin.__prototype.isPlugin = true
                _plugin.__prototype.main = self

                local instance = _plugin(nil)

                      
                _plugin.__prototype.isPlugin = nil
                _plugin.__prototype.main = nil

                       
                instance.isPlugin = true
                instance.main = self
                
                self.plugins[v] = instance
            end
        end

        if coords ~= nil then
            self:create(coords, rotation, options)
        end
    end, {args={{name = "coords"},{name = "rotation"},{name = "options"},},name="constructor",}),

    deconstructor = leap.registerfunc(function(self)
        self:destroy()
    end, {args={},name="deconstructor",}),
    
    destroy = leap.registerfunc(function(self)
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
    end, {args={},name="destroy",}),

    init = leap.registerfunc(function(self, id, state, client)
        self.id = id
        self.state = state
        self.client = client

        if self.__listenedStates and next(self.__listenedStates) then
            local  onStateChange = leap.registerfunc(function(listeners, value, initial)
                for _, data in pairs(listeners) do
                    if data.value ~= nil then
                        if value ~= data.value then
                            goto continue_1
                        end
                    end

                    data.fn(value, initial) ::continue_1::
                end
            end, {args={{name = "listeners"},{name = "value"},{name = "initial"},},name="onStateChange",})

            for key, listeners in pairs(self.__listenedStates) do
                Citizen.CreateThread(function()
                    onStateChange(listeners, self.state[key], true)
                end)
            end

            self.__stateChangeHandler = UtilityNet.AddStateBagChangeHandler(self.id, leap.registerfunc(function(key, value)
                local listeners = self.__listenedStates[key]

                if listeners then
                    onStateChange(listeners, value, false)
                end
            end, {args={{name = "key"},{name = "value"},},name="UtilityNet.AddStateBagChangeHandler",}))
        end

        if self.plugins then
            for k,v in pairs(self.plugins) do
                v:init(id, state)
            end
        end
    end, {args={},name="init",}),

    callOnAll = leap.registerfunc(function(self, method, ...)
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
    end, {args={{name = "method"},},name="callOnAll",}),

    create = leap.registerfunc(function(self, coords, rotation, options)if type(coords) ~= "vector3" then error('coords: must be (vector3) but got '..type(coords)..'', 2) end;if type(rotation) ~= "vector3" and type(rotation) ~= "nil" then error('rotation: must be (vector3 | nil) but got '..type(rotation)..'', 2) end;if options == nil then options = {} end;
        local _type = type(self)

        if not self.model then
            error(""..(_type)..": trying to create entity without model, please use the model decorator to set the model")
        end

        options.rotation = options.rotation or rotation
        options.abstract = options.abstract or self.abstract

        local id = UtilityNet.CreateEntity(self.model, coords, options)
        local state = UtilityNet.State(id)
        local client = setmetatable({id = id, __type = _type}, client_rpc_mt)

        self:init(id, state, client)
        Entities:add(self)
        
        self:callOnAll("OnAwake")
        self:callOnAll("OnSpawn")
        self:callOnAll("AfterSpawn")
    end, {args={{name = "coords"},{name = "rotation"},{name = "options"},},name="create",}),
}, {});BaseEntity = skipSerialize(BaseEntity, {"plugins", "id", "state", "main", "isPlugin"}) or BaseEntity;



 
 
IsServer = true
IsClient = false

 
 GetCallbacks = leap.registerfunc(function()
    return callbacks
end, {args={},name="GetCallbacks",has_return=true,});GetCallbacks = rpc(GetCallbacks, true) or GetCallbacks;

GenerateCallbackId = leap.registerfunc(function()
    return "cb"..GetHashKey(tostring(math.random()) .. GetGameTimer())
end, {args={},name="GenerateCallbackId",has_return=true,})

AwaitCallback = leap.registerfunc(function(name, cid, id)
    local p = promise.new()        
    Citizen.SetTimeout(5000, function()
        if p.state == 0 then
            warn("Client callback "..(name).."("..(tostring(id))..") sended to "..(tostring(cid)).." timed out")
            p:reject({})
        end
    end)

    local eventHandler = nil

               
    RegisterNetEvent(name)
    eventHandler = AddEventHandler(name, leap.registerfunc(function(_id, data)
        if _id ~= id then return end

        Citizen.SetTimeout(1, leap.registerfunc(function()
            RemoveEventHandler(eventHandler)
        end, {args={{name = "_id"},{name = "data"},},name="Citizen.SetTimeout",}))
        p:resolve(data)
    end, {args={},name="AddEventHandler",}))

    return p
end, {args={},name="AwaitCallback",has_return=true,})

local await = setmetatable({}, {
    __index = leap.registerfunc(function(self, key)
        local name = namespace.."Client:"..key

        return function(cid, ...)if type(cid) ~= "number" then error('cid: must be (number) but got '..type(cid)..'', 2) end;
            local id = GenerateCallbackId()
            local p = AwaitCallback(name, cid, id)
            
            TriggerClientEvent(name, cid, id, ...)
            return table.unpack(Citizen.Await(p))
        end
    end, {args={{name = "cid"},},name="__index",has_return=true,})
})

Client = setmetatable({}, {
    __index = leap.registerfunc(function(self, key)
        local name = namespace.."Client:"..key

        if key == "await" then
            return await
        else
            return function(cid, ...)if type(cid) ~= "number" then error('cid: must be (number) but got '..type(cid)..'', 2) end;
                TriggerClientEvent(name, cid, ...)
            end
        end
    end, {args={{name = "cid"},},name="__index",has_return=true,}),
})