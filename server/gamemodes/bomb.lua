-- ========================================
-- BOMB GAMEMODE - SERVER
-- ========================================

local Bomb = {
    currentBombHolder = nil,
    bombTimer = 0,
    bombTimerThread = nil,
    collisionCheckInterval = 100,
    lastTransferTime = 0,
    explosionCount = 0
}

-- 라운드 준비
AddEventHandler('minigames:server:gamemode:prepare:bomb', function()
    Utils.Info('Bomb: Preparing round')

    Bomb.currentBombHolder = nil
    Bomb.bombTimer = 0
    Bomb.explosionCount = 0

    -- 플레이어들을 스폰 위치로 텔레포트 및 차량 생성
    local map = CurrentRound.map
    local spawns = Utils.ShuffleTable(map.spawns)
    local spawnIndex = 1

    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            local spawn = spawns[spawnIndex]
            if spawn then
                -- 모든 플레이어 동일한 차량 (밸런스)
                local vehicleModel = "blista"

                -- 플레이어에게 차량 생성 요청
                TriggerClientEvent('minigames:client:spawnVehicle', playerId,
                    vehicleModel,
                    Utils.Vec4ToVec3(spawn),
                    spawn.w,
                    {health = 1000, speed = 1.0}
                )

                -- 플레이어 차량 데이터 저장
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

    Utils.Info('Bomb: Round prepared')
end)

-- 라운드 시작
AddEventHandler('minigames:server:gamemode:start:bomb', function()
    Utils.Info('Bomb: Starting round')

    -- 무작위 플레이어에게 폭탄 부여
    local playingPlayers = {}
    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            table.insert(playingPlayers, playerId)
        end
    end

    if #playingPlayers > 0 then
        local randomPlayer = playingPlayers[math.random(#playingPlayers)]
        AttachBomb(randomPlayer)
    end

    Utils.Info('Bomb: Round started')
end)

-- 라운드 종료
AddEventHandler('minigames:server:gamemode:end:bomb', function(winners)
    Utils.Info('Bomb: Ending round')

    -- 폭탄 타이머 중지
    StopBombTimer()

    -- 모든 차량 제거
    for playerId, _ in pairs(Players) do
        TriggerClientEvent('minigames:client:deleteVehicle', playerId)
        TriggerClientEvent('minigames:client:removeBomb', playerId)
    end

    Utils.Info('Bomb: Round ended')
end)

-- 폭탄 부착
function AttachBomb(playerId)
    local player = Players[playerId]
    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end

    Bomb.currentBombHolder = playerId

    -- 폭탄 타이머 설정 (점점 짧아짐)
    local baseTimer = Config.Bomb.InitialTimer or 15
    local decrease = (Config.Bomb.TimerDecrease or 1) * Bomb.explosionCount
    Bomb.bombTimer = math.max(Config.Bomb.MinTimer or 5, baseTimer - decrease)

    -- 모든 플레이어에게 폭탄 소유자 알림
    TriggerClientEvent('minigames:client:bombAttached', -1, playerId, Bomb.bombTimer)

    -- 폭탄 소유자에게 알림
    TriggerClientEvent('minigames:client:notify', playerId, '폭탄이 부착되었습니다! 다른 플레이어에게 전달하세요!', 'warning')

    -- 폭탄 타이머 시작
    StartBombTimer()

    Utils.Info('Bomb attached to player: ' .. player.name .. ' (Timer: ' .. Bomb.bombTimer .. 's)')
end

-- 폭탄 타이머 시작
function StartBombTimer()
    -- 기존 타이머 중지
    StopBombTimer()

    Bomb.bombTimerThread = CreateThread(function()
        while Bomb.bombTimer > 0 and CurrentRound.state == GameModes.States.PLAYING do
            Wait(1000)

            Bomb.bombTimer = Bomb.bombTimer - 1

            -- 모든 플레이어에게 타이머 업데이트
            TriggerClientEvent('minigames:client:bombTimerUpdate', -1, Bomb.bombTimer)

            -- 타이머가 3초 이하일 때 경고
            if Bomb.bombTimer <= 3 and Bomb.bombTimer > 0 then
                if Bomb.currentBombHolder then
                    TriggerClientEvent('minigames:client:notify', Bomb.currentBombHolder,
                        '폭발까지 ' .. Bomb.bombTimer .. '초!', 'error')
                end
            end
        end

        -- 폭발
        if Bomb.bombTimer <= 0 and Bomb.currentBombHolder then
            ExplodeBomb()
        end

        Bomb.bombTimerThread = nil
    end)
end

-- 폭탄 타이머 중지
function StopBombTimer()
    Bomb.bombTimer = 0
    -- 쓰레드는 자동으로 종료됨
end

-- 폭탄 폭발
function ExplodeBomb()
    if not Bomb.currentBombHolder then return end

    local player = Players[Bomb.currentBombHolder]
    if not player then return end

    Utils.Info('Bomb exploded on player: ' .. player.name)

    -- 폭발 이펙트
    TriggerClientEvent('minigames:client:bombExplode', -1, Bomb.currentBombHolder)

    -- 폭탄 소유자 사망 처리
    player.state = GameModes.PlayerStates.DEAD
    player.stats.deaths = player.stats.deaths + 1

    -- 차량 제거
    TriggerClientEvent('minigames:client:deleteVehicle', Bomb.currentBombHolder)

    -- 모든 플레이어에게 사망 알림
    TriggerClientEvent('minigames:client:playerDied', -1, Bomb.currentBombHolder, player.name)

    Bomb.explosionCount = Bomb.explosionCount + 1
    Bomb.currentBombHolder = nil

    -- 승리 조건 체크
    Wait(1000)
    CheckWinCondition()

    -- 생존자가 2명 이상이면 새 폭탄 생성
    local alivePlayers = GetAlivePlayers()
    if #alivePlayers >= 2 then
        Wait(2000)
        local randomPlayer = alivePlayers[math.random(#alivePlayers)]
        AttachBomb(randomPlayer)
    end
end

-- 폭탄 전달 (충돌)
RegisterNetEvent('minigames:server:transferBomb', function(targetId)
    local src = source

    -- 폭탄 소유자 확인
    if Bomb.currentBombHolder ~= src then return end

    -- 쿨다운 체크
    local currentTime = GetGameTimer()
    if currentTime - Bomb.lastTransferTime < (Config.Bomb.TransferCooldown or 1) * 1000 then
        return
    end

    local target = Players[targetId]
    if not target or target.state ~= GameModes.PlayerStates.PLAYING then return end

    Bomb.lastTransferTime = currentTime

    -- 폭탄 전달
    local previousHolder = Players[Bomb.currentBombHolder]
    Bomb.currentBombHolder = targetId

    -- 타이머 약간 증가 (보너스)
    Bomb.bombTimer = math.min(Bomb.bombTimer + 2, Config.Bomb.InitialTimer or 15)

    -- 모든 플레이어에게 알림
    TriggerClientEvent('minigames:client:bombTransferred', -1, src, targetId, Bomb.bombTimer)

    -- 이전 소유자와 새 소유자에게 알림
    if previousHolder then
        TriggerClientEvent('minigames:client:notify', src, '폭탄을 전달했습니다!', 'success')
    end
    TriggerClientEvent('minigames:client:notify', targetId, '폭탄이 전달되었습니다!', 'warning')

    Utils.Info('Bomb transferred from ' .. (previousHolder and previousHolder.name or 'unknown') ..
               ' to ' .. target.name)
end)

-- 생존 플레이어 가져오기
function GetAlivePlayers()
    local alive = {}
    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            table.insert(alive, playerId)
        end
    end
    return alive
end

-- 승리 조건 체크
function CheckWinCondition()
    local alivePlayers = {}

    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            table.insert(alivePlayers, {
                source = playerId,
                name = player.name,
                stats = player.stats
            })
        end
    end

    -- 1명 남으면 승리
    if #alivePlayers == 1 then
        local winner = alivePlayers[1]

        -- 라운드 종료
        OnRoundEnding({winner})

        Utils.Info('Bomb: Winner - ' .. winner.name)
    elseif #alivePlayers == 0 then
        -- 모두 죽으면 무승부
        OnRoundEnding({})

        Utils.Info('Bomb: Draw - No survivors')
    end
end

-- 플레이어 사망 처리 (다른 이유로 죽었을 때)
RegisterNetEvent('minigames:server:playerDied', function(playerId)
    playerId = playerId or source
    local player = Players[playerId]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 플레이어 상태 변경
    player.state = GameModes.PlayerStates.DEAD
    player.stats.deaths = player.stats.deaths + 1

    -- 폭탄 소유자였으면 폭탄 제거하고 새로 생성
    if Bomb.currentBombHolder == playerId then
        Bomb.currentBombHolder = nil
        StopBombTimer()

        -- 모든 플레이어에게 알림
        TriggerClientEvent('minigames:client:removeBomb', -1)

        -- 새 폭탄 생성
        Wait(2000)
        local alivePlayers = GetAlivePlayers()
        if #alivePlayers >= 2 then
            local randomPlayer = alivePlayers[math.random(#alivePlayers)]
            AttachBomb(randomPlayer)
        end
    end

    -- 차량 제거
    TriggerClientEvent('minigames:client:deleteVehicle', playerId)

    -- 모든 플레이어에게 사망 알림
    TriggerClientEvent('minigames:client:playerDied', -1, playerId, player.name)

    Utils.Info('Player ' .. player.name .. ' died')

    -- 승리 조건 체크
    CheckWinCondition()
end)

Utils.Info('Bomb gamemode (server) loaded')
