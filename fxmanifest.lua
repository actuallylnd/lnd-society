fx_version 'adamant'

game 'gta5'

description 'ESX Society converted by lnd'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    '@es_extended/locale.lua',
    'locales/en.lua',
    'locales/pl.lua',
    'config.lua',
    'server/main.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/en.lua',
    'locales/pl.lua',
    'config.lua',
    'client/main.lua'
}

dependencies {
    'es_extended',
    'cron',
    'esx_addonaccount'
}
