fx_version 'cerulean'
lua54 'yes'
game 'gta5'

client_scripts {
    "@utility_lib/client/native.lua",
    "build/client/objectify.lua",
    "build/client/functions/*.lua",
    "build/client/objects/**.lua",
    "build/client/main.lua",
}

server_scripts {
    "@utility_lib/server/native.lua",
    "build/server/objectify.lua",
    "build/server/functions/*.lua",
    "build/server/objects/*.lua",
    "build/server/main.lua",
}

dependency "leap3"