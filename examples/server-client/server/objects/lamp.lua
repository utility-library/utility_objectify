@model("prop_cd_lamp")
class Lamp extends BaseEntity {
    @rpc -- RPC suppports return values!
    SetLampState = function(state)
        print("Server: Lamp ${self.id} state changed to ${tostring(state)} by ${source}")
      
        self.state.isOn = state

        -- Lest change the color just for fun
        self.state.color = {255, 0, 0}
        Citizen.Wait(500)
        self.state.color = {0, 255, 0}
        Citizen.Wait(500)
        self.state.color = {0, 0, 255}
    end,
}