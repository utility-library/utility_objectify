function model(_class, model, abstract)
    if type(model) == "table" then
        for k,v in pairs(model) do
            if IsClient then
                RegisterObjectScript(v, "main", _class)
            elseif IsServer then
                _class.__prototype[v] = function(...)
                    _class.__prototype.model = v
                    _class.__prototype.abstract = abstract

                    local obj = new _class(...)
                    obj.model = v
                    _class.__prototype.model = nil

                    return obj
                end
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
end

function plugin(_class, plugin)
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
end

local function registerOneSyncEntity(_class, _type, _model)
    if type(_model) == "table" then
        for k,v in pairs(_model) do
            _model[k] = "UtilityNet:".._type..":"..v
        end

        model(_class, _model, true)
    else
        model(_class, "UtilityNet:".._type..":".._model, true)
    end
end

function vehicle(_class, _model)
    registerOneSyncEntity(_class, "Veh", _model)
end

function ped(_class, _model)
    registerOneSyncEntity(_class, "Ped", _model)
end

function object(_class, _model)
    registerOneSyncEntity(_class, "Obj", _model)
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