fx_version 'cerulean'
game 'gta5'

name        'gang_aggression'
description 'Immersive gang NPC aggression system. Standalone — works with QBCore, QBox, ESX, and vanilla FiveM.'
author      'Zix'
version     '2.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

-- No server scripts needed. Zero network overhead.
