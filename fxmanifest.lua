fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'

game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'ox_inventory'
author 'Overextended; RedM/VORP fork'
version '0.1.0-redm'
description 'RedM-only slot inventory for VORP Core'

dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
    'vorp_core',
}

shared_script '@ox_lib/init.lua'

ox_libs {
    'locale',
    'table',
    'math',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'init.lua',
}

client_script 'init.lua'

ui_page 'web/build/index.html'

files {
    'client.lua',
    'server.lua',

    'locales/*.json',

    'data/*.lua',

    'modules/**/shared.lua',
    'modules/**/client.lua',

    'web/build/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/images/*.png',
}
