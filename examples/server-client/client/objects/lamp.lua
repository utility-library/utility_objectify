@model("prop_cd_lamp")
@plugin("interactable")
class Lamp extends BaseEntity {
    OnSpawn = function()
        -- All main scripts have:

        -- self.id      = uNetId (UtilityNet id)
        -- self.obj     = The game object handle
        -- self.state   = A state bag that can be used to store custom synced data
        -- self.plugins = A list of plugins attached to this object 
        -- self.server  = Used to call server-side entity RPC functions 

        self:DrawLightLoop()
    end,

    DrawLightLoop = function()
        Citizen.CreateThread(function()
            while DoesEntityExist(self.obj) do -- Loop until the object is deleted
                if self.state.isOn then
                    local coords = GetEntityCoords(self.obj)
                    local color = self.state.color or {255, 255, 255} -- Default color is white
                    DrawLightWithRange(coords, color[1], color[2], color[3], 4.0, 5.0)
                end

                Citizen.Wait(0)
            end
        end)
    end,

    @state("isOn")
    OnLightStateChanged = function(value, load)
        print("Client: Lamp ${self.id} state changed to ${tostring(value)}, load: ${tostring(load)}")
    end,

    -- This will be called from the "interactable" plugin
    OnInteract = function()
        self.server:SetLampState(not self.state.isOn)
    end
}