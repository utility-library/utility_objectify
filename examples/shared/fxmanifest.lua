fx_version 'cerulean'
lua54 'yes'
game 'gta5'

client_scripts {
    "@utility_lib/client/native.lua",
    "@utility_objectify/shared/api.lua",
    "build/shared/functions/*.lua",
    "build/shared/objects/**.lua",
    "build/shared/main.lua",
}

server_scripts {
    "@utility_lib/server/native.lua",
    "@utility_objectify/shared/api.lua",
    "build/shared/functions/*.lua",
    "build/shared/objects/**.lua",
    "build/shared/main.lua",
}

dependency "leap3"