fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qb-delivery'
description 'Simple package delivery job for QBCore'
author 'qb-delivery contributors'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'qb-core',
}
