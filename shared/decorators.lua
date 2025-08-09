function model(_class, model, abstract)
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
end

function plugin(_class, plugin)
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
end

function state(self, fn, key, value)
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
end

function event(self, fn, key, ignoreRendering)
    RegisterNetEvent(key)
    AddEventHandler(key, function(...)
        if IsClient then
            if ignoreRendering then
                fn(...)
            else
                if AreObjectScriptsFullyLoaded(self.obj) then -- Only run if object is loaded
                    fn(...)
                end
            end
        elseif IsServer then
            fn(...)
        end
    end)
end