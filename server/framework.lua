-- v1.1
IsServer = true
IsClient = false
local disableTimeoutNext = false

@rpc(true)
function GetCallbacks()
    return callbacks
end

function GenerateCallbackId()
    return "cb"..GetHashKey(tostring(math.random()) .. GetGameTimer())
end

function AwaitCallback(name, cid, id)
    local p = promise.new() 

    if not disableTimeoutNext then
        Citizen.SetTimeout(5000, function()
            if p.state == 0 then
                warn("Client callback ${name}(${tostring(id)}) sended to ${tostring(cid)} timed out")
                p:reject({})
            end
        end)
    else
        disableTimeoutNext = false
    end

    local eventHandler = nil

    -- Register a new event to handle the callback from the client
    RegisterNetEvent(name)
    eventHandler = AddEventHandler(name, function(_id, data)
        if _id ~= id then return end

        Citizen.SetTimeout(1, function()
            RemoveEventHandler(eventHandler)
        end)
        p:resolve(data)
    end)

    return p
end

local await = setmetatable({}, {
    __index = function(self, key)
        local name = namespace.."Client:"..key

        return function(cid: number | table, ...)
            
            if type(cid) == "table" then
                local promises = {}

                for k,v in ipairs(cid) do
                    local id = GenerateCallbackId()
                    local p = AwaitCallback(name, cid, id)
                    TriggerClientEvent(name, cid, id, ...)

                    table.insert(promises, p)
                end

                local returns = Citizen.Await(promise.all(promises))
                local retByCid = {}

                for k,v in ipairs(returns) do
                    retByCid[cid[k]] = v
                end

                return retByCid
            else
                local id = GenerateCallbackId()
                local p = AwaitCallback(name, cid, id)
                TriggerClientEvent(name, cid, id, ...)

                return table.unpack(Citizen.Await(p))
            end
        end
    end
})

Client = setmetatable({
    DisableTimeoutForNext = function()
        disableTimeoutNext = true
    end
}, {
    __index = function(self, key)
        local name = namespace.."Client:"..key

        if key == "await" then
            return await
        else
            return function(cid: number | table, ...)
                if type(cid) == "table" then
                    for k,v in ipairs(cid) do
                        TriggerClientEvent(name, v, ...)
                    end
                else
                    TriggerClientEvent(name, cid, ...)
                end
            end
        end
    end,
})