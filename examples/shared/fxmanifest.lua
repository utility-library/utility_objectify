fx_version 'cerulean'
lua54 'yes'
game 'gta5'

client_scripts {
    "@utility_lib/client/native.lua",
    "@utility_objectify/shared/api.lua",
    "shared/functions/*.lua",
    "shared/objects/**.lua",
    "shared/main.lua",
}

server_scripts {
    "@utility_lib/server/native.lua",
    "@utility_objectify/shared/api.lua",
    "shared/functions/*.lua",
    "shared/objects/**.lua",
    "shared/main.lua",
}

dependency "leap"