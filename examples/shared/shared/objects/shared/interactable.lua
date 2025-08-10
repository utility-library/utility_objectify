class interactable extends BaseEntity {
    OnSpawn = function()
        -- All plugin scripts have:

        -- self.id       = uNetId (UtilityNet id)
        -- self.obj      = The game object handle
        -- self.state    = A state bag that can be used to store custom synced data
        -- self.server   = Used to call server-side entity RPC functions 
        -- self.main     = The main script instance
        -- self.isPlugin = on true since this is a plugin

        if not self.main or not self.main.OnInteract then
            error("The object does not have an OnInteract function in its main script.")
        end

        if IsClient then
            self:InteractionLoop()
        end
    end,

    InteractionLoop = function()
        Citizen.CreateThread(function()
            while DoesEntityExist(self.obj) do
                local coords = GetEntityCoords(self.obj)
                local playerCoords = GetEntityCoords(PlayerPedId())

                if #(coords - playerCoords) < 2.0 then
                    DrawText3Ds(coords + vector3(0.0, 0.0, 1.0), "Press [E] to interact")

                    if IsControlJustReleased(0, 38) then -- E key
                        self.main:OnInteract()
                    end
                end

                Citizen.Wait(0)
            end
        end)
    end
}