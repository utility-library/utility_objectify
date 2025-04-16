-- v1.1
local namespace = (Config?.Namespace or GetCurrentResourceName()) .. ":"
local callbacks = {}

function rpc(fn, _return)
    local sig = leap.fsignature(fn)
    _return = _return != nil ? _return : sig.has_return
    
    local name = namespace..sig.name

    if not _return then
        RegisterNetEvent(name)
        AddEventHandler(name, fn)
    else
        callbacks[sig.name] = true

        RegisterServerEvent(name)
        AddEventHandler(name, function(id, ...)
            local source = source
            
            -- For make the return of lua works
            local _cb = table.pack(fn(...))
                
            if _cb ~= nil then -- If the callback is not nil
                TriggerClientEvent(name, source, id, _cb) -- Trigger the client event
            end
        end)
    end
end

@rpc(true)
function GetCallbacks()
    return callbacks
end