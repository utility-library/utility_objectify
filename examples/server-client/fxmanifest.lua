fx_version 'cerulean'
lua54 'yes'
game 'gta5'

client_scripts {
    "@utility_lib/client/native.lua",
    "@utility_objectify/build/client/api.lua",
    "build/client/objects/**.lua",
    "build/client/main.lua",
}

server_scripts {
    "@utility_lib/server/native.lua",
    "@utility_objectify/build/server/api.lua",
    "build/server/objects/**.lua",
    "build/server/main.lua",
}

dependency "leap"