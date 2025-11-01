-- ========================================
-- BOSS GAMEMODE - SERVER
-- ========================================

local Boss = {
    bossPlayerId = nil,
    collisionCheckThread = nil
}

-- 라운드 준비
AddEventHandler('minigames:server:gamemode:prepare:boss', function()
    Utils.Info('Boss: Preparing round')

    Boss.bossPlayerId = nil

    -- 플레이어 목록 가져오기
    local playingPlayers = {}
    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            table.insert(playingPlayers, playerId)
        end
    end

    if #playingPlayers < 3 then
        Utils.Error('Boss: Not enough players (minimum 3)')
        return
    end

    -- 랜덤으로 보스 선택
    Boss.bossPlayerId = playingPlayers[math.random(#playingPlayers)]

    -- 맵 데이터
    local map = CurrentRound.map

    -- 보스 플레이어 차량 생성
    local bossPlayer = Players[Boss.bossPlayerId]
    if bossPlayer then
        local bossSpawn = map.bossSpawn or map.spawns[1]
        local bossVehicle = Config.Boss.BossVehicle

        -- 보스 차량 생성
        TriggerClientEvent('minigames:client:spawnVehicle', Boss.bossPlayerId,
            bossVehicle.model,
            Utils.Vec4ToVec3(bossSpawn),
            bossSpawn.w,
            bossVehicle
        )

        -- 보스 데이터 저장
        bossPlayer.vehicle = {
            model = bossVehicle.model,
            health = bossVehicle.health,
            maxHealth = bossVehicle.health,
            stats = bossVehicle,
            isBoss = true
        }

        Utils.Info('Boss player: ' .. bossPlayer.name)
    end

    -- 일반 플레이어들 차량 생성
    local spawns = Utils.ShuffleTable(map.spawns)
    local spawnIndex = 1

    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING and playerId ~= Boss.bossPlayerId then
            local spawn = spawns[spawnIndex]
            if spawn then
                -- 랜덤 일반 차량 선택
                local vehicleModel = Utils.GetRandomElement(Config.Boss.PlayerVehicles)

                -- 차량 생성
                TriggerClientEvent('minigames:client:spawnVehicle', playerId,
                    vehicleModel,
                    Utils.Vec4ToVec3(spawn),
                    spawn.w,
                    {health = 1000, speed = 1.0}
                )

                -- 차량 데이터 저장
                player.vehicle = {
                    model = vehicleModel,
                    health = 1000,
                    maxHealth = 1000
                }

                spawnIndex = spawnIndex + 1
                if spawnIndex > #spawns then
                    spawnIndex = 1
                end
            end
        end
    end

    -- 모든 플레이어에게 보스 알림
    TriggerClientEvent('minigames:client:bossSelected', -1, Boss.bossPlayerId,
        bossPlayer and bossPlayer.name or "Unknown")

    Utils.Info('Boss: Round prepared')
end)

-- 라운드 시작
AddEventHandler('minigames:server:gamemode:start:boss', function()
    Utils.Info('Boss: Starting round')

    -- 충돌 체크 시작
    StartCollisionCheck()

    Utils.Info('Boss: Round started')
end)

-- 라운드 종료
AddEventHandler('minigames:server:gamemode:end:boss', function(winners)
    Utils.Info('Boss: Ending round')

    -- 모든 차량 제거
    for playerId, _ in pairs(Players) do
        TriggerClientEvent('minigames:client:deleteVehicle', playerId)
    end

    Utils.Info('Boss: Round ended')
end)

-- 충돌 체크 시작
function StartCollisionCheck()
    if Boss.collisionCheckThread then return end

    Boss.collisionCheckThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING do
            Wait(100)

            -- 클라이언트에서 충돌 처리
        end

        Boss.collisionCheckThread = nil
    end)
end

-- 보스와 충돌 처리
RegisterNetEvent('minigames:server:bossCollision', function(targetId)
    local src = source

    -- 보스가 아니면 무시
    if src ~= Boss.bossPlayerId then return end

    local target = Players[targetId]
    if not target or target.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 일반 플레이어 즉사
    target.state = GameModes.PlayerStates.DEAD
    target.stats.deaths = target.stats.deaths + 1

    -- 보스 킬 카운트
    local boss = Players[Boss.bossPlayerId]
    if boss then
        boss.stats.kills = boss.stats.kills + 1
    end

    -- 차량 폭파
    TriggerClientEvent('minigames:client:explodeVehicle', targetId)
    TriggerClientEvent('minigames:client:deleteVehicle', targetId)

    -- 모든 플레이어에게 사망 알림
    TriggerClientEvent('minigames:client:playerDied', -1, targetId, target.name)

    Utils.Info('Boss killed player: ' .. target.name)

    -- 승리 조건 체크
    CheckWinCondition()
end)

-- 플레이어 사망 처리
RegisterNetEvent('minigames:server:playerDied', function(playerId)
    playerId = playerId or source
    local player = Players[playerId]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 플레이어 상태 변경
    player.state = GameModes.PlayerStates.DEAD
    player.stats.deaths = player.stats.deaths + 1

    -- 차량 제거
    TriggerClientEvent('minigames:client:deleteVehicle', playerId)

    -- 모든 플레이어에게 사망 알림
    TriggerClientEvent('minigames:client:playerDied', -1, playerId, player.name)

    Utils.Info('Player ' .. player.name .. ' died')

    -- 승리 조건 체크
    CheckWinCondition()
end)

-- 승리 조건 체크
function CheckWinCondition()
    local alivePlayers = {}
    local bossAlive = false

    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            table.insert(alivePlayers, {
                source = playerId,
                name = player.name,
                stats = player.stats,
                isBoss = playerId == Boss.bossPlayerId
            })

            if playerId == Boss.bossPlayerId then
                bossAlive = true
            end
        end
    end

    -- 보스만 남으면 보스 승리
    if #alivePlayers == 1 and bossAlive then
        local boss = alivePlayers[1]

        -- 라운드 종료
        OnRoundEnding({boss})

        Utils.Info('Boss: Boss wins - ' .. boss.name)
    -- 보스가 죽으면 일반 플레이어들 승리
    elseif not bossAlive then
        local survivors = {}
        for _, player in ipairs(alivePlayers) do
            table.insert(survivors, player)
        end

        -- 라운드 종료
        OnRoundEnding(survivors)

        Utils.Info('Boss: Players win - Boss defeated')
    -- 시간 초과로 일반 플레이어 생존하면 승리
    elseif CurrentRound.timer <= 0 then
        local survivors = {}
        for _, player in ipairs(alivePlayers) do
            if not player.isBoss then
                table.insert(survivors, player)
            end
        end

        -- 라운드 종료
        OnRoundEnding(survivors)

        Utils.Info('Boss: Players win - Time survived')
    end
end

Utils.Info('Boss gamemode (server) loaded')
