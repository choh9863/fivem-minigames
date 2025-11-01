fx_version 'cerulean'
game 'gta5'

author 'FiveM Minigames Team'
description 'Advanced Minigame Server with Multiple Game Modes'
version '1.0.0'

-- Shared Scripts
shared_scripts {
    'shared/config.lua',
    'shared/utils.lua',
    'shared/gamemodes.lua'
}

-- Server Scripts
server_scripts {
    'server/main.lua',
    'server/player.lua',
    'server/lobby.lua',
    'server/round.lua',
    'server/voting.lua',
    'server/gamemodes/bumpercar.lua',
    'server/gamemodes/bomb.lua',
    'server/gamemodes/avalanche.lua',
    'server/gamemodes/boss.lua',
    'server/gamemodes/weapon.lua'
}

-- Client Scripts
client_scripts {
    'client/main.lua',
    'client/lobby.lua',
    'client/round.lua',
    'client/hud.lua',
    'client/camera.lua',
    'client/vehicle.lua',
    'client/items.lua',
    'client/gamemodes/bumpercar.lua',
    'client/gamemodes/bomb.lua',
    'client/gamemodes/avalanche.lua',
    'client/gamemodes/boss.lua',
    'client/gamemodes/weapon.lua'
}

-- UI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/**/*.*'
}

dependencies {
    '/server:5104',
    '/gameBuild:2545'
}
