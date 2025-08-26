game "gta5"
fx_version "cerulean"

server_scripts {
    "build.lua",
}

leap_ignore {
    "build.lua"
}

files {
    "build/server/api.lua",
    "build/client/api.lua",
    "build/shared/api.lua"
}

dependency "leap3"
lua54 "yes"