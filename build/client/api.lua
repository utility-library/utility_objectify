if not leap then leap={}end;if not leap.deserialize then leap.deserialize=function(a,b)b=b or{}if b[a]then return b[a]end;local c=_type(a)if c~="table"or not a.__type then if c=="table"then if type(a.x)=="number"and type(a.y)=="number"then if type(a.z)=="number"then if type(a.w)=="number"then return vector4(a.x,a.y,a.z,a.w)else return vector3(a.x,a.y,a.z)end else return vector2(a.x,a.y)end else local d={}b[a]=d;for e,f in pairs(a)do d[e]=leap.deserialize(f,b)end;return d end else return a end end;local g=_G[a.__type]if not g then error("Class '"..a.__type.."' not found",2)end;g.__skipNextConstructor=true;local h=g()b[a]=h;if h.deserialize then h:deserialize(a)else for e,f in pairs(a)do if e~="__type"then h[e]=leap.deserialize(f,b)end end end;return h end end;if not leap.serialize then leap.serialize=function(a,b)b=b or{}local c=_type(a)if c~="table"then return a end;if b[a]then return b[a]end;if a.serialize then local i=a:serialize()if not i then return nil end;if type(i)~="table"then error("leap.serialize: custom serialize method must return a table",2)end;b[a]=i;for e,f in pairs(i)do i[e]=leap.serialize(f,b)end;i.__type=a.__type;return i end;local j={__stack=true,__parent=true,super=true}if a.__ignoreList then for e,f in pairs(a.__ignoreList)do j[f]=true end end;local d=_leap_internal_deepcopy(a,b,j,true)b[a]=d;return d end end;if not skipSerialize then skipSerialize=function(k,l)if _type(k)~="table"then error("skipSerialize: #1 passed argument must be a class, but got "..type(k),2)end;if not k.__prototype.__ignoreList then k.__prototype.__ignoreList={}end;if _type(l)=="table"then for e,f in pairs(l)do k.__prototype.__ignoreList[f]=true end elseif _type(l)=="string"then k.__prototype.__ignoreList[l]=true else error("skipSerialize: #2 passed argument must be a table or a string, but got "..type(l),2)end end end;if not leap.fsignature then leap.fsignature=function(m)if _type(m)~="function"then error("leap.fsignature: passed argument must be a function, but got ".._type(m),2)end;if not __leap__introspection then return nil end;return __leap__introspection[m]end end;if not leap.registerfunc then leap.registerfunc=function(m,n)if not __leap__introspection then __leap__introspection=setmetatable({},{__mode="k"})end;__leap__introspection[m]=n;return m end end;if not leap.minimal then leap.minimal=false end;if not table.clone then table.clone=function(o)local d={}for e,f in pairs(o)do d[e]=f end;return d end end;if not _leap_internal_deepcopy then _leap_internal_deepcopy=function(o,p,q,r)if _type(o)~="table"then return o end;p=p or{}if p[o]then return p[o]end;local s=table.clone(o)p[o]=s;for e,f in next,o do if q and q[e]then s[e]=nil else local t=_type(f)if t=="function"and r then s[e]=nil else if t=="table"then if f.__type~=nil then s[e]=leap.serialize(f,p)else s[e]=_leap_internal_deepcopy(f,p,q,r)end else s[e]=f end end end end;return s end end;if not _type then _type=type;type=function(u)local v=_type(u)if v=="table"and u.__type then return u.__type else return v end end end;if not _leap_internal_classBuilder then _leap_internal_classBuilder=function(a,b,c)b._leap_internal_decorators={}if not c then error("ExtendingNotDefined: "..a.." tried to extend a class that is not defined",2)end;if c.__prototype then b.__parent=c end;local d={__cache={},__newindex=function(e,f,g)rawset(e,f,g)getmetatable(e).__cache[f]=nil end}setmetatable(b,d)local h=b;local i={}while h do for f,g in next,h do if not i[f]then if _type(g)=="table"and f:sub(1,5)~="_leap"and f:sub(1,2)~="__"then i[f]=h end end end;if not h.__parent then break end;h=h.__parent.__prototype end;local j={__index=function(self,k)if not k then return nil end;if k:sub(1,2)=="__"then return rawget(b,k)end;local l=getmetatable(b).__cache;local h=b;if not l[k]then while h do if rawget(h,k)~=nil then l[k]=h;break end;if not h.__parent then return nil end;h=h.__parent.__prototype end else end;local h=l[k]return h[k]end,__gc=function(self)if self.destructor then self:destructor()end end,__tostring=function(self)if self.toString then return self:toString()else local m=""if not leap.minimal then for f,g in pairs(self)do if f~="super"and f:sub(1,5)~="_leap"and f:sub(1,2)~="__"then local n=_type(g)if n~="function"then local o=g;if n=="table"then if g.__type then o="<"..g.__type..":"..("%p"):format(g)..">"else o=tostring(g)end end;if n=="string"then o='"'..g..'"'end;m=m..f..": "..tostring(o)..", "end end end;m=m:sub(1,-3)end;return"<"..self.__type..":"..("%p"):format(self).."> "..m end end}_G[a]=setmetatable({__type=a,__prototype=b},{__index=function(self,f)local p=j.__index(self,f)if type(p)=="function"then return function(q,...)if _type(q)=="table"and q.__type==self.__type then return p(nil,...)else return p(q,...)end end else return p end end,__newindex=function(self,f,g)if f:sub(1,2)=="__"then rawset(self,f,g)else error("attempt to assign class property '"..f.."' directly, please instantiate the class before assigning any properties",2)end end,__call=function(self,...)local r={__type=self.__type}for k,s in pairs(i)do r[k]=_leap_internal_deepcopy(s[k])end;setmetatable(r,j)for t,u in pairs(r._leap_internal_decorators)do local v=r[u.name]local w=function(...)return v(r,...)end;leap.registerfunc(w,leap.fsignature(v))if not _G[u.decoratorName]then error("Decorator "..u.decoratorName.." does not exist",2)end;r[u.name]=_G[u.decoratorName](r,w,table.unpack(u.args))or v end;if not self.__skipNextConstructor then local x=r.constructor;if x then local y,z=pcall(x,r,...)if not y then error(z,2)end end end;self.__skipNextConstructor=nil;return r end})end;_leap_internal_classBuilder("Error",{constructor=function(self,A)self.message=A end,toString=function(self)return type(self)..": "..self.message end},{})end;if not _leap_internal_is_operator then _leap_internal_is_operator=function(r,B)if not r or not B then return false end;if _type(r)~="table"then return _type(r)==type(B)end;if _type(B)~="table"then error("leap.is_operator: #2 passed argument must be a class, but got ".._type(B),2)end;if r.__prototype then error("leap.is_operator: #1 passed argument must be a class instance, but got class",2)end;local C=r;while C and C.__type~=B.__type do if C.__parent or C.__prototype.__parent then C=C.__parent or C.__prototype.__parent else return false end end;return true end end; 
model = leap.registerfunc(function(_class, model, abstract)
    if type(model) == "table" then
        for k,v in pairs(model) do
            if IsClient then
                RegisterObjectScript(v, "main", _class)
            elseif IsServer then
                _class.__prototype[v] = leap.registerfunc(function(...)
                    _class.__prototype.model = v
                    local obj = _class(...)
                    obj.model = v
                    _class.__prototype.model = nil

                    return obj
                end, {args={{name = "_class"},{name = "model"},{name = "abstract"},},name=v,has_return=true,})
            end
        end

        _class.__models = model
    elseif type(model) == "string" then
        _class.__prototype.model = model

        if IsClient then
            RegisterObjectScript(model, "main", _class)
        elseif IsServer then
            _class.__prototype.abstract = abstract
        end
    end
end, {args={},name="model",})

plugin = leap.registerfunc(function(_class, plugin)
    if IsClient then
        Citizen.CreateThread(function()
            if _G[plugin].__prototype.OnPluginApply then
                _G[plugin].__prototype.OnPluginApply({}, _class.__prototype)
            end

            if _class.__models then
                for _,model in pairs(_class.__models) do
                    RegisterObjectScript(model, plugin, _G[plugin])
                end
            else
                local model = _class.__prototype.model
                RegisterObjectScript(model, plugin, _G[plugin])
            end
        end)
    elseif IsServer then
        if not _class.__prototype.__plugins then
            _class.__prototype.__plugins = {}
        end

        table.insert(_class.__prototype.__plugins, plugin)
    end
end, {args={{name = "_class"},{name = "plugin"},},name="plugin",})

vehicle = leap.registerfunc(function(_class, _model)
    model(_class, "UtilityNet:Veh:".._model, true)
end, {args={{name = "_class"},{name = "_model"},},name="vehicle",})

ped = leap.registerfunc(function(_class, _model)
    model(_class, "UtilityNet:Ped:".._model, true)
end, {args={{name = "_class"},{name = "_model"},},name="ped",})

object = leap.registerfunc(function(_class, _model)
    model(_class, "UtilityNet:Obj:".._model, true)
end, {args={{name = "_class"},{name = "_model"},},name="object",})

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

    waitFor = leap.registerfunc(function(self, id, timeout)if type(id) ~= "number" then error('id: must be (number) but got '..type(id)..'', 2) end;if timeout == nil then timeout = 5000 end;if type(timeout) ~= "number" then error('timeout: must be (number) but got '..type(timeout)..'', 2) end;
        local start = GetGameTimer()

        while not self.list[id] do
            if GetGameTimer() - start > timeout then
                error(tostring(Error(""..(type(self))..": Child "..(childId).." not found after "..(timeout).."ms, skipping")))
                return nil
            end

            Wait(0)
        end

        return self.list[id]
    end, {args={{name = "id"},{name = "timeout"},},name="waitFor",has_return=true,}),

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
    end, {args={{name = "key"},{name = "value"},},name="getAllBy",has_return=true,})
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



 
 
IsServer = false
IsClient = true

local callbacksLoaded = false

local  CombineHooks = leap.registerfunc(function(self, methodName, beforeName, afterName)
    local main = self[methodName]

    self[methodName] = leap.registerfunc(function(...)
        local before = self[beforeName]
        local after = self[afterName]
        
        if before then before(self, ...) end
        if main then main(self, ...) end
        if after then return after(self, ...) end
    end, {args={{name = "self"},{name = "methodName"},{name = "beforeName"},{name = "afterName"},},name=methodName,has_return=true,})
end, {args={},name="CombineHooks",})

local server_rpc_mt, server_plugin_rpc_mt, children_mt = nil  
server_rpc_mt = {
    __index = leap.registerfunc(function(self, key)
                
        if key == "plugins" then
            local id = rawget(self, "id")
            local __type = rawget(self, "__type")

            local plugins = setmetatable({id = id, __type = __type}, server_plugin_rpc_mt)
            rawset(self, "plugins", plugins)  
            return plugins
        end

        local method = self.__type .. "." .. key

        local fn = leap.registerfunc(function(...)
            local first = ...        
            local selfCall = first and type(first) == self.__type and first.id == self.id

            if selfCall then
                return Server[method](self.id, select(2, ...))
            else
                return Server[method](self.id, ...)
            end
        end, {args={{name = "self"},{name = "key"},},name="fn",has_return=true,})

        rawset(self, key, fn)  
        return fn
    end, {args={},name="__index",has_return=true,}),
    __newindex = leap.registerfunc(function(self, key, value)
        error("You can't register server methods from the client, please register them from the server using the rpc decorator!")
    end, {args={{name = "self"},{name = "key"},{name = "value"},},name="__newindex",})
}

server_plugin_rpc_mt = {
    __index = leap.registerfunc(function(self, key)
                    
        local proxy = setmetatable({
            id = self.id,
            __type = self.__type .. "." .. key
        }, server_rpc_mt)

        rawset(self, key, proxy)  
        return proxy
    end, {args={{name = "self"},{name = "key"},},name="__index",has_return=true,}),

    __newindex = leap.registerfunc(function()
        error("You can't register server methods from the client, please register them from the server using the rpc decorator!")
    end, {args={},name="__newindex",})
}

children_mt = {
    __mode = "v",

    getEntity = leap.registerfunc(function(self, name)
        if not self._state.children then
            return nil
        end

        if not self._state.children[name] then
            return nil
        end

        local entity = Entities:waitFor(self._state.children[name])
        entity.parent = self._parent

        return entity
    end, {args={{name = "self"},{name = "name"},},name="getEntity",has_return=true,}),

    __pairs = leap.registerfunc(function(self)
        if not self._state.children then
            return leap.registerfunc(function() end, {args={{name = "self"},},name="__pairs",has_return=true,})
        end

        local meta = getmetatable(self)

        return function(t, k)
            local k,v = next(self._state.children, k)
            if not v or not k then return nil end

            local entity = meta.getEntity(self, k)

            if entity then
                return k, entity
            end
        end
    end, {args={{name = "t"},{name = "k"},},name="__pairs",has_return=true,}),

    __tostring = leap.registerfunc(function(self)
        if not self._state.children then
            return "[]"
        end

        return json.encode(self._state.children)
    end, {args={{name = "self"},},name="__tostring",has_return=true,}),

    __ipairs = leap.registerfunc(function(self)
        local meta = getmetatable(self)
        return meta.__pairs(self)
    end, {args={{name = "self"},},name="__ipairs",has_return=true,}),

    __len = leap.registerfunc(function(self)
        if not self._state.children then
            return 0
        end

        return #self._state.children
    end, {args={{name = "self"},},name="__len",has_return=true,}),

    __index = leap.registerfunc(function(self, key)
        local meta = getmetatable(self)
        return meta.getEntity(self, key)
    end, {args={{name = "self"},{name = "key"},},name="__index",has_return=true,})
}

 _leap_internal_classBuilder("BaseEntity",
  {
    server = nil,
    children = nil,
    __stateChangeHandler = nil,

    constructor = leap.registerfunc(function(self)
        CombineHooks(self, "OnSpawn", "_BeforeOnSpawn", "_AfterOnSpawn")
        CombineHooks(self, "OnDestroy", nil, "_AfterOnDestroy")
    end, {args={},name="constructor",}),

    
      _OnParentChange = leap.registerfunc(function(self, parent, load)
        if load then return end

        if parent then
            self.parent = Entities:waitFor(parent)
        else
            self.parent = nil
        end
    end, {args={{name = "parent"},{name = "load"},},name="_OnParentChange",}),

    
      _OnRootChange = leap.registerfunc(function(self, root, load)
        if load then return end

        if root then
            self.root = Entities:waitFor(root)
        else
            self.root = nil
        end
    end, {args={{name = "root"},{name = "load"},},name="_OnRootChange",}),

    _BeforeOnSpawn = leap.registerfunc(function(self)
        self.server = setmetatable({id = self.id, __type = type(self)}, server_rpc_mt)
        self.children = setmetatable({_state = self.state, _parent = self}, children_mt)

        if self.state.parent then
            self.parent = Entities:waitFor(self.state.parent)
        end

        if self.state.root then
            self.root = Entities:waitFor(self.state.root)
        end

        if not self.isPlugin then
            Entities:add(self)
        end
    end, {args={},name="_BeforeOnSpawn",}),

    _AfterOnSpawn = leap.registerfunc(function(self)
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

        if self.listenedStates and next(self.listenedStates) then
            for key, listeners in pairs(self.listenedStates) do
                Citizen.CreateThread(leap.registerfunc(function()
                    onStateChange(listeners, self.state[key], true)
                end, {args={},name="Citizen.CreateThread",}))
            end

            self.__stateChangeHandler = UtilityNet.AddStateBagChangeHandler(self.id, leap.registerfunc(function(key, value)
                local listeners = self.listenedStates[key]

                if listeners then
                    onStateChange(listeners, value, false)
                end
            end, {args={{name = "key"},{name = "value"},},name="UtilityNet.AddStateBagChangeHandler",}))
        end
    end, {args={},name="_AfterOnSpawn",}),

    _AfterOnDestroy = leap.registerfunc(function(self)
        if self.__stateChangeHandler then
            UtilityNet.RemoveStateBagChangeHandler(self.__stateChangeHandler)
        end

        if not self.isPlugin then
            Entities:remove(self)
        end
    end, {args={},name="_AfterOnDestroy",}),

    getChild = leap.registerfunc(function(self, path)if type(path) ~= "string" then error('path: must be (string) but got '..type(path)..'', 2) end;
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
    end, {args={{name = "path"},},name="getChild",has_return=true,}),

    getChildBy = leap.registerfunc(function(self, key, value)if type(key) ~= "string" then error('key: must be (string) but got '..type(key)..'', 2) end;
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
    end, {args={{name = "key"},{name = "value"},},name="getChildBy",has_return=true,}),

    getChildrenBy = leap.registerfunc(function(self, key, value)if type(key) ~= "string" then error('key: must be (string) but got '..type(key)..'', 2) end;
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
    end, {args={{name = "key"},{name = "value"},},name="getChildrenBy",has_return=true,})
}, {});BaseEntity = skipSerialize(BaseEntity, {"main", "isPlugin", "plugins", "server", "listenedStates"}) or BaseEntity;table.insert(BaseEntity.__prototype._leap_internal_decorators, {name = "_OnParentChange", decoratorName = "state", args = {"parent"}});table.insert(BaseEntity.__prototype._leap_internal_decorators, {name = "_OnRootChange", decoratorName = "state", args = {"root"}});

_leap_internal_classBuilder("BaseEntityOneSync",{
    _CreateOneSyncEntity = leap.registerfunc(function(self, enttype)
        local _obj = nil

        if enttype == "Veh" then
            _obj = CreateVehicle(self.model, GetEntityCoords(self.obj), GetEntityHeading(self.obj), true, true)
        elseif enttype == "Ped" then
            _obj = CreatePed(self.model, GetEntityCoords(self.obj), GetEntityHeading(self.obj), true, true)
        elseif enttype == "Obj" then
            _obj = CreateObject(self.model, GetEntityCoords(self.obj), GetEntityHeading(self.obj), true, true)
        end

        if not _obj then
            error("OneSyncEntity: Failed to create entity for "..tostring(self.id)..", "..tostring(enttype).." is not an allowed type!")
            return
        end
        
        while not DoesEntityExist(_obj) do
            Wait(0)
        end

        local netid = NetworkGetNetworkIdFromEntity(_obj)
        self.server:_created(netid)
    end, {args={{name = "enttype"},},name="_CreateOneSyncEntity",}),

    _BeforeOnSpawn = leap.registerfunc(function(self)
        BaseEntity.__prototype._BeforeOnSpawn(self)

        local type, model = self.model:match("^[^:]+:([^:]+):([^:]+)$")
        self.model = model 

        if not self.state.netId or not NetworkDoesNetworkIdExist(self.state.netId) then
            local allowed = self.server:_askPermission()

            if allowed then
                self:_CreateOneSyncEntity(type)
            end
        end

        while not self.state.netId do
            Wait(0)
        end

        self._obj = self.obj
        self.obj = NetworkGetEntityFromNetworkId(self.state.netId)
        self.netId = self.state.netId
    end, {args={},name="_BeforeOnSpawn",})
}, BaseEntity)

 
local disableTimeoutNext = false

SetRPCNamespace = leap.registerfunc(function(_namespace)
    namespace = _namespace
end, {args={{name = "_namespace"},},name="SetRPCNamespace",})

local GenerateCallbackId = leap.registerfunc(function()
    return "cb"..GetHashKey(GetPlayerName(-1) .. GetGameTimer())
end, {args={},name="GenerateCallbackId",has_return=true,})

local AwaitCallback = leap.registerfunc(function(name, id)
    local p = promise.new()    
   
    if not disableTimeoutNext then
        Citizen.SetTimeout(5000, function()
            if p.state == 0 then
                warn("Server callback "..(name).." ("..(tostring(id))..") timed out")
                p:reject({})
            end
        end)
    else
        disableTimeoutNext = false
    end

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

Server = setmetatable({ 
    DisableTimeoutForNext = leap.registerfunc(function()
        disableTimeoutNext = true
    end, {args={},name="DisableTimeoutForNext",})
}, {
    __index = leap.registerfunc(function(self, key)
        local name = namespace.."Server:"..key

        return function(...)
                 
            while not callbacksLoaded and key ~= "GetCallbacks" do
                Wait(0)
            end

            if callbacks[key] then
                local id = GenerateCallbackId()
                local p = AwaitCallback(name, id)
                
                TriggerServerEvent(name, id, ...)
                return table.unpack(Citizen.Await(p))
            else
                TriggerServerEvent(name, ...)
            end
        end
    end, {args={{name = "self"},{name = "key"},},name="__index",has_return=true,}),
})

       
Citizen.CreateThreadNow(function()
    callbacks = Server.GetCallbacks()
    callbacksLoaded = true

    RegisterNetEvent(namespace.."RegisterCallback")
    AddEventHandler(namespace.."RegisterCallback", function(key)
        callbacks[key] = true
    end)
end)



 
 
local tag = "^3ObjectManagement^0"
local modelScripts = {}
local objectScripts = {}
local registeredObjects = {}
local tempObjectsProperties = {}          
local customHooks = {}

local  GetScriptsForModel = leap.registerfunc(function(model)
    return modelScripts[model]
end, {args={{name = "model"},},name="GetScriptsForModel",has_return=true,})

local  _IsObjectScriptRegistered = leap.registerfunc(function(model, name)
    local scripts = GetScriptsForModel(model)
    if scripts then
        for k,v in ipairs(scripts) do
            if v.name == name then
                return true
            end
        end
    end
end, {args={{name = "model"},{name = "name"},},name="_IsObjectScriptRegistered",has_return=true,})

              
        
local  CreateTempObjectAndCallMethod = leap.registerfunc(function(uNetId, model, method, ...)
    local _model = type(model) == "string" and GetHashKey(model) or model
    local scripts = GetScriptsForModel(_model)
    
    local _self = nil
    local _oldNewIndex = nil

    if not scripts then
        return
    end
    
    for k,v in pairs(scripts) do
        if v.script.__prototype[method] then
            if not _self then
                _self = v.script()
                _self.state = UtilityNet.State(uNetId)
                _self.id = uNetId

                          
                            
                                   
                                   
                if tempObjectsProperties[uNetId] then
                    for k,v in pairs(tempObjectsProperties[uNetId]) do
                        _self[k] = v
                    end
                end

                local metatable = getmetatable(_self)
                _oldNewIndex = metatable.__newindex

                metatable.__newindex = leap.registerfunc(function(self, key, value)
                                    
                    if not tempObjectsProperties[uNetId] then
                        tempObjectsProperties[uNetId] = {}
                    end

                    tempObjectsProperties[uNetId][key] = value
                    rawset(self, key, value)
                end, {args={{name = "self"},{name = "key"},{name = "value"},},name="__newindex",})
            end

            _self[method](_self, ...)
        end
    end

    if _self then     
        local metatable = getmetatable(_self)
        metatable.__newindex = _oldNewIndex
    end
end, {args={},name="CreateTempObjectAndCallMethod",})

local  CallOnRegister = leap.registerfunc(function(uNetId, model, coords, rotation)
    registeredObjects[uNetId] = promise.new()
    CreateTempObjectAndCallMethod(uNetId, model, "OnRegister", coords, rotation)
    registeredObjects[uNetId]:resolve(true)
end, {args={{name = "uNetId"},{name = "model"},{name = "coords"},{name = "rotation"},},name="CallOnRegister",})

local  CreateObjectScriptInstance = leap.registerfunc(function(obj, scriptIndex, source)
    local model = GetEntityModel(obj)
    local uNetId = UtilityNet.GetUNetIdFromEntity(obj)
    local scripts = GetScriptsForModel(model)

    if not scripts then
        developer(tag, "Model ^4"..model.."^0 has no scripts, skipping script index "..scriptIndex)
        return
    end

    local script = scripts[scriptIndex]

        
    if objectScripts[obj][script.name] then
        developer("^1ObjectManagement^0", "Skipping ^1"..GetEntityArchetypeName(obj).."^0 since is already registered > ^5"..script.name.."^0 for "..obj)
        return
    end

    if source == "Registered" and Config?.ObjectManagementDebug?.Registered then
        developer(tag .. " ^2Registered^0", "Creating instance ^4"..GetEntityArchetypeName(obj).."^0 > ^5"..script.name.."^0 for "..obj)
    elseif source == "GetInstance" and Config?.ObjectManagementDebug?.GetInstance then
        developer(tag .. " ^3GetInstance^0", "Creating instance ^4"..GetEntityArchetypeName(obj).."^0 > ^5"..script.name.."^0 for "..obj)
    elseif source == "CreateInstances" and Config?.ObjectManagementDebug?.CreateInstances then
        developer(tag .. " ^6CreateInstances^0", "Creating instance ^4"..GetEntityArchetypeName(obj).."^0 > ^5"..script.name.."^0 for "..obj)
    end

                 

    if script.name ~= "main" then
                          
        script.script.__prototype.isPlugin = true
        script.script.__prototype.main = objectScripts[obj]["main"]
    end

    local instance = script.script()

    instance.state = UtilityNet.State(uNetId)
    instance.id = uNetId
    instance.obj = obj
    instance.model = GetEntityArchetypeName(obj)

    if script.name ~= "main" then
        local main = objectScripts[obj]["main"]

              
        script.script.__prototype.isPlugin = nil
        script.script.__prototype.main = nil

               
        instance.isPlugin = true
        instance.main = main

        main.plugins[script.name] = instance      
    end

                    
    if tempObjectsProperties[uNetId] then
        for k,v in pairs(tempObjectsProperties[uNetId]) do
            instance[k] = v
        end
    end

         
    for hookMethod, hook in pairs(customHooks) do
        if instance[hookMethod] and hook.exec then
            hook.exec(instance, name)
        end
    end

         
    objectScripts[obj][script.name] = instance

    return instance
end, {args={{name = "obj"},{name = "scriptIndex"},{name = "source"},},name="CreateObjectScriptInstance",has_return=true,})

local  CreateObjectScriptsInstances = leap.registerfunc(function(obj)
    local model = GetEntityModel(obj)
    local scripts = GetScriptsForModel(model)

    if not scripts then
        developer(tag, "Model ^4"..model.."^0 has no scripts, skipping scripts instances creation")
        return false
    end
    
    objectScripts[obj] = {}

                 
    local mainIndex = nil

    for k,v in ipairs(scripts) do
        if v.name == "main" then
            mainIndex = k
            break
        end
    end

          
    local main = CreateObjectScriptInstance(obj, mainIndex, "GetInstance")
    main.plugins = {}      

    objectScripts[obj]["main"] = main

            
    for k,v in ipairs(scripts) do
        if v.name ~= "main" then
            objectScripts[obj][v.name] = CreateObjectScriptInstance(obj, k, "CreateInstances")
        end
    end

    return true
end, {args={{name = "obj"},},name="CreateObjectScriptsInstances",has_return=true,})

CallMethodForAllObjectScripts = leap.registerfunc(function(obj, method, ...)
    local model = Entity(obj).state.model
    local scripts = GetScriptsForModel(model)

    if not scripts then
        developer(tag, "Model ^4"..tostring(model).."^0 has no scripts, ignoring call method "..method)
        return
    end

    for k,v in ipairs(scripts) do
        if not DoesEntityExist(obj) then       
            break
        end

        local instance = GetObjectScriptInstance(obj, v.name, true)
        
        if not instance then       
            break
        end

        if instance[method] then
            instance[method](instance, ...)
        end

              
        for hookMethod, hook in pairs(customHooks) do
                      
            if instance[hookMethod] and hook[method] then
                          
                local call = leap.registerfunc(function(...) 
                    CallMethodForAllObjectScripts(instance.obj, hookMethod, ...)
                end, {args={{name = "obj"},{name = "method"},},name="call",})

                hook[method](instance, call, ...)
            end
        end
    end
end, {args={},name="CallMethodForAllObjectScripts",})

  
RegisterObjectScript = leap.registerfunc(function(model, name, script)
    local hashmodel = type(model) == "string" and GetHashKey(model) or model

    if not modelScripts[hashmodel] then
        modelScripts[hashmodel] = {}
    end

    if not script then
        error("RegisterObjectScript: tried to register "..model.." > "..name.." but script is empty")
    end

    if IsObjectScriptRegistered(hashmodel, name) then
        developer(tag, "Model ^4"..model.."^0 > ^5"..name.."^0 is already registered, skipping")
        return
    end
        
    table.insert(modelScripts[hashmodel], {
        script = script,
        name = name
    })

          
    local scriptIndex = #modelScripts[hashmodel]

    if not table.empty(objectScripts) then
        for obj, scripts in pairs(objectScripts) do
            local model = GetEntityModel(obj)

                    
            if model == hashmodel and not objectScripts[obj][name] then
                objectScripts[obj][name] = CreateObjectScriptInstance(obj, scriptIndex, "Registered")
            end
        end
    end
end, {args={{name = "model"},{name = "name"},{name = "script"},},name="RegisterObjectScript",})

RegisterObjectsScript = leap.registerfunc(function(models, name, script)
    for k,v in pairs(models) do
        RegisterObjectScript(v, name, script)
    end
end, {args={{name = "models"},{name = "name"},{name = "script"},},name="RegisterObjectsScript",})

IsObjectScriptRegistered = leap.registerfunc(function(model, name)
    local hashmodel = type(model) == "string" and GetHashKey(model) or model

    return _IsObjectScriptRegistered(hashmodel, name)
end, {args={{name = "model"},{name = "name"},},name="IsObjectScriptRegistered",has_return=true,})

 
         
          
          
          

        
           
                             
RegisterCustomHook = leap.registerfunc(function(hookMethod, hookData)
    customHooks[hookMethod] = hookData
end, {args={{name = "hookMethod"},{name = "hookData"},},name="RegisterCustomHook",})

                   
               
  
     
GetExternalObjectScriptStatic = leap.registerfunc(function(model, name)
    if type(model) == "string" then
        model = GetHashKey(model)
    end
    
    if not modelScripts[model] then return end

    for k,v in pairs(modelScripts[model]) do
        if v.name == name then
            return v.script
        end
    end
end, {args={{name = "model"},{name = "name"},},name="GetExternalObjectScriptStatic",has_return=true,})

GetObjectScriptInstance = leap.registerfunc(function(obj, name, nocheck)
    if not obj then error("GetObjectScriptInstance: passed obj is nil, name: "..name) end
    if not UtilityNet.GetUNetIdFromEntity(obj) then return end     

    if not nocheck then
              
        local start = GetGameTimer()
        while not UtilityNet.IsEntityRendered(obj) do
            if GetGameTimer() - start > 5000 then
                error("GetObjectScriptInstance: UtilityNet.IsEntityRendered timed out for "..GetEntityArchetypeName(obj).." > "..name, 2)
            end
            Citizen.Wait(0)
        end
    end

    local model = GetEntityModel(obj)

    if not objectScripts[obj] then
              
        if _IsObjectScriptRegistered(model, name) then
                  
            local start = GetGameTimer()
            while not objectScripts[obj] or not objectScripts[obj][name] do
                if GetGameTimer() - start > 5000 then
                    error("GetObjectScriptInstance: timed out for "..GetEntityArchetypeName(obj).." > "..name, 2)
                end
                Citizen.Wait(0)
            end
        else               
            return nil 
        end
    end

    if not objectScripts[obj][name] then
        local model = GetEntityModel(obj)
        local scripts = GetScriptsForModel(model)
        local scriptIndex = nil

        for k,v in ipairs(scripts) do
            if v.name == name then
                scriptIndex = k
                break
            end
        end

        if not scriptIndex then
            return
        end

        CreateObjectScriptInstance(obj, scriptIndex, "GetInstance")
    end

    return objectScripts[obj][name]
end, {args={{name = "obj"},{name = "name"},{name = "nocheck"},},name="GetObjectScriptInstance",has_return=true,})

GetNetScriptInstance = leap.registerfunc(function(netid, name)
    if not netid then error("GetNetScriptInstance: passed netid is nil", 2) return end

    local start = GetGameTimer()
    while not UtilityNet.IsReady(netid) do
        if GetGameTimer() - start > 5000 then
            error("GetNetScriptInstance: timed out IsReady for netid "..tostring(netid), 2)
        end
        Citizen.Wait(0)
    end

    local obj = UtilityNet.GetEntityFromUNetId(netid)

    local start = GetGameTimer()
    while not UtilityNet.IsEntityRendered(obj) do
        if GetGameTimer() - start > 5000 then
            error("GetNetScriptInstance: timed out IsEntityRendered for netid "..tostring(netid)..", obj "..tostring(obj), 2)
        end
        Citizen.Wait(0)
    end

    local model = GetEntityModel(obj)
    if not IsObjectScriptRegistered(model, name) then
        return nil
    end

    local start = GetGameTimer()
    while not Entity(obj).state.om_scripts_created do
        if GetGameTimer() - start > 5000 then
            error("GetNetScriptInstance: timed out, not all scripts created after 5s for netid "..tostring(netid)..", obj "..tostring(obj), 2)
        end

        warn(obj..' waiting for all scripts to be created')
        Citizen.Wait(0)
    end

    return GetObjectScriptInstance(obj, name)
end, {args={{name = "netid"},{name = "name"},},name="GetNetScriptInstance",has_return=true,})

AreObjectScriptsFullyLoaded = leap.registerfunc(function(obj)
    if not DoesEntityExist(obj) then
        warn("AreObjectScriptsFullyLoaded: object "..tostring(obj).." doesn't exist, skipping")
        return false
    end

    local entity = Entity(obj)
    if entity and entity.state and entity.state.om_loaded then
        return true
    end

    return false
end, {args={{name = "obj"},},name="AreObjectScriptsFullyLoaded",has_return=true,})


RegisterCustomHook("OnStateChange", {
    OnSpawn = leap.registerfunc(function(env, call)
        env.changeHandler = UtilityNet.AddStateBagChangeHandler(env.id, leap.registerfunc(function(key, value)
            call(key, value)
        end, {args={{name = "key"},{name = "value"},},name="UtilityNet.AddStateBagChangeHandler",}))
    end, {args={},name="OnSpawn",}),
    OnDestroy = leap.registerfunc(function(env)
        UtilityNet.RemoveStateBagChangeHandler(env.changeHandler)
    end, {args={{name = "env"},},name="OnDestroy",})
})

if not UtilityNet then
    error("Please load the utility_lib before utility_objectify!")
end

local resource = GetCurrentResourceName()
UtilityNet.OnRender(function(id, obj, model)
    if UtilityNet.GetuNetIdCreator(id) ~= resource then
        return
    end

    if objectScripts[obj] then
        warn("Skipping render of "..id.." since it already has some registered scripts")
        return
    end

    if not registeredObjects[id] then
        CallOnRegister(id, model, GetEntityCoords(obj), GetEntityRotation(obj))
    else
        Citizen.Await(registeredObjects[id])
    end

    local created = CreateObjectScriptsInstances(obj)

    if not created then
        return
    end
    Entity(obj).state:set("om_scripts_created", true, false)

    local model = GetEntityModel(obj)
    Entity(obj).state:set("model", model, false)             

    CallMethodForAllObjectScripts(obj, "OnAwake")
    CallMethodForAllObjectScripts(obj, "OnSpawn")
    CallMethodForAllObjectScripts(obj, "AfterSpawn")

          
    Entity(obj).state:set("om_loaded", true, false)
    UtilityNet.PreserveEntity(id)
end)

UtilityNet.OnUnrender(function(id, obj, model)
    if not objectScripts[obj] then
        return
    end

    CallMethodForAllObjectScripts(obj, "OnDestroy")
    objectScripts[obj] = nil

    if Config?.ObjectManagementDebug?.Deleting then
        developer(tag, "Deleting ^4"..GetEntityArchetypeName(obj).."^0 instances")
    end

    DeleteEntity(obj)
end)

RegisterNetEvent("Utility:Net:EntityCreated", function(_, uNetId, model, coords, rotation)
    if registeredObjects[uNetId] then
        return
    end

    rotation = rotation or vec3(0, 0, 0)
    CallOnRegister(uNetId, model, coords, rotation)
end)

RegisterNetEvent("Utility:Net:RequestDeletion", function(uNetId, model, coords, rotation)
    rotation = rotation or vec3(0, 0, 0)

    registeredObjects[uNetId] = nil
    CreateTempObjectAndCallMethod(uNetId, model, "OnUnregister", coords, rotation)
    tempObjectsProperties[uNetId] = nil        
end)

Citizen.CreateThread(function()
    local entities = UtilityNet.GetServerEntities({
        where = {createdBy = resource},
        select = {"id", "model", "coords", "options"}
    })

    for _, entity in pairs(entities) do
        if not registeredObjects[entity.id] then
            CallOnRegister(entity.id, entity.model, entity.coords, entity.options.rotation)
        end
    end
end)

 
Citizen.CreateThread(function()
    if DevModeStatus then
        while true do
            local found, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())

            if found and objectScripts[entity] then
                local coords = GetEntityCoords(entity)
                local text = "INSTANCES:"

                for name, instance in pairs(objectScripts[entity]) do
                    text = text .. "\n"..name.." : "..tostring(instance)
                end

                DrawText3Ds(coords, text)
            end
            
            Citizen.Wait(1)
        end
    end
end)