function Clear(_type)
    for k,v in pairs(_type) do
        SaveResourceFile(GetCurrentResourceName(), v.."/api.lua", "")
    end
end

function Build(_type, dest, prepend)
    local files = io.readdir("@"..GetCurrentResourceName().."/".._type)
    local content = ""

    for file in files:lines() do
        if file ~= "api.lua" then
            content = content .. "--BUILD @utility_objectify/".._type.."/"..file.."\n"
            content = content .. LoadResourceFile(GetCurrentResourceName(), _type.."/"..file)

            content = content .. "\n\n"
            content = content .. "------------------------------------"
            content = content .. "\n\n"
        end
    end

    local get = LoadResourceFile(GetCurrentResourceName(), (dest or _type).."/api.lua")

    if prepend then
        content = content..get
    else
        content = get..content
    end
    SaveResourceFile(GetCurrentResourceName(), (dest or _type).."/api.lua", content)
end

function Merge(from, _type)
    local content = ""

    for k,v in pairs(from) do
        content = content .. "--MERGE @utility_objectify/"..v.."/api.lua\n"

        if v == "server" then
            content = content .. "if IsDuplicityVersion() then\n"
        elseif v == "client" then
            content = content .. "if not IsDuplicityVersion() then\n"
        end

        content = content .. LoadResourceFile(GetCurrentResourceName(), v.."/api.lua")

        if v == "server" or v == "client" then
            content = content .. "end\n"
        end

        content = content .. "\n\n"
    end

    local get = LoadResourceFile(GetCurrentResourceName(), _type.."/api.lua")
    content = get..content
    SaveResourceFile(GetCurrentResourceName(), _type.."/api.lua", content)
end

-- Lets clear all
Clear({"client", "server", "shared"})

-- Build client, server and shared in their api.lua
Build("client")
Build("server")
Build("shared")

-- Lets merge client and server api in shared api.lua
Merge({"client", "server"}, "shared")

-- Now lets build all shared files inside client and server
-- After merge, so that the shared api.lua doesnt have double code (from this build and the merge done before)
Build("shared", "client", true)
Build("shared", "server", true)