function Build(_type)
    local files = io.readdir("@"..GetCurrentResourceName().."/".._type)
    local content = ""

    for file in files:lines() do
        if file ~= "api.lua" then
            content = content .. "--@utility_objectify/".._type.."/"..file.."\n"
            content = content .. LoadResourceFile(GetCurrentResourceName(), _type.."/"..file)

            content = content .. "\n\n"
            content = content .. "------------------------------------"
            content = content .. "\n\n"
        end
    end

    SaveResourceFile(GetCurrentResourceName(), _type.."/api.lua", content)
end

Build("client")
Build("server")