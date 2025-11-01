-- ========================================
-- AVALANCHE GAMEMODE - SERVER
-- ========================================

local Avalanche = {
    spawnedVehicles = {},
    vehicleSpawnThread = nil,
    collisionCheckThread = nil,
    finishCheckThread = nil
}

-- 라운드 준비
AddEventHandler('minigames:server:gamemode:prepare:avalanche', function()
    Utils.Info('Avalanche: Preparing round')

    Avalanche.spawnedVehicles = {}

    -- 플레이어들을 시작 위치로 텔레포트 및 차량 생성
    local map = CurrentRound.map
    local spawns = Utils.ShuffleTable(map.spawns)
    local spawnIndex = 1

    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            local spawn = spawns[spawnIndex]
            if spawn then
                -- 모든 플레이어 동일한 빠른 차량
                local vehicleModel = "blista"

                -- 플레이어에게 차량 생성 요청
                TriggerClientEvent('minigames:client:spawnVehicle', playerId,
                    vehicleModel,
                    Utils.Vec4ToVec3(spawn),
                    spawn.w,
                    {health = 1000, speed = 1.2}
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

    Utils.Info('Avalanche: Round prepared')
end)

-- 라운드 시작
AddEventHandler('minigames:server:gamemode:start:avalanche', function()
    Utils.Info('Avalanche: Starting round')

    -- 차량 스폰 시작
    StartVehicleSpawning()

    -- 충돌 체크 시작
    StartCollisionCheck()

    -- 골인 체크 시작
    StartFinishCheck()

    Utils.Info('Avalanche: Round started')
end)

-- 라운드 종료
AddEventHandler('minigames:server:gamemode:end:avalanche', function(winners)
    Utils.Info('Avalanche: Ending round')

    -- 차량 스폰 중지
    StopVehicleSpawning()

    -- 스폰된 차량 모두 제거
    for _, vehicle in pairs(Avalanche.spawnedVehicles) do
        TriggerClientEvent('minigames:client:deleteAvalancheVehicle', -1, vehicle.netId)
    end
    Avalanche.spawnedVehicles = {}

    -- 모든 플레이어 차량 제거
    for playerId, _ in pairs(Players) do
        TriggerClientEvent('minigames:client:deleteVehicle', playerId)
    end

    Utils.Info('Avalanche: Round ended')
end)

-- 차량 스폰 시작
function StartVehicleSpawning()
    if Avalanche.vehicleSpawnThread then return end

    local map = CurrentRound.map
    if not map.vehicleSpawnPoint then
        Utils.Error('Avalanche: No vehicle spawn point defined in map')
        return
    end

    local spawnPoint = map.vehicleSpawnPoint
    local spawnInterval = (Config.Avalanche.SpawnInterval or 2) * 1000

    Avalanche.vehicleSpawnThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING do
            Wait(spawnInterval)

            -- 랜덤 차량 선택
            local vehicleModel = Utils.GetRandomElement(Config.Avalanche.Vehicles)

            -- 랜덤 스폰 오프셋 (좌우로 약간 변화)
            local offsetX = math.random(-10, 10)
            local offsetY = math.random(-10, 10)

            local spawnCoords = vector3(
                spawnPoint.x + offsetX,
                spawnPoint.y + offsetY,
                spawnPoint.z
            )

            -- 차량 ID 생성
            local vehicleId = 'avalanche_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)

            -- 모든 클라이언트에 차량 스폰 요청
            TriggerClientEvent('minigames:client:spawnAvalancheVehicle', -1,
                vehicleId, vehicleModel, spawnCoords)

            -- 차량 데이터 저장
            Avalanche.spawnedVehicles[vehicleId] = {
                id = vehicleId,
                model = vehicleModel,
                coords = spawnCoords,
                spawnTime = GetGameTimer()
            }

            Utils.Debug('Spawned avalanche vehicle: ' .. vehicleModel .. ' at ' .. tostring(spawnCoords))

            -- 10초 후 차량 자동 제거 (성능 최적화)
            SetTimeout(10000, function()
                if Avalanche.spawnedVehicles[vehicleId] then
                    TriggerClientEvent('minigames:client:deleteAvalancheVehicle', -1, vehicleId)
                    Avalanche.spawnedVehicles[vehicleId] = nil
                end
            end)
        end

        Avalanche.vehicleSpawnThread = nil
    end)
end

-- 차량 스폰 중지
function StopVehicleSpawning()
    -- 쓰레드는 자동으로 종료됨 (CurrentRound.state 체크)
end

-- 충돌 체크 시작
function StartCollisionCheck()
    if Avalanche.collisionCheckThread then return end

    Avalanche.collisionCheckThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING do
            Wait(100)

            -- 클라이언트에서 충돌 감지 처리
        end

        Avalanche.collisionCheckThread = nil
    end)
end

-- 골인 체크 시작
function StartFinishCheck()
    if Avalanche.finishCheckThread then return end

    local map = CurrentRound.map
    if not map.finishLine then
        Utils.Error('Avalanche: No finish line defined in map')
        return
    end

    local finishLine = map.finishLine
    local finishRadius = 10.0 -- 골인 지점 반경

    Avalanche.finishCheckThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING do
            Wait(500)

            for playerId, player in pairs(Players) do
                if player.state == GameModes.PlayerStates.PLAYING then
                    -- 플레이어에게 골인 체크 요청
                    TriggerClientEvent('minigames:client:checkFinishLine', playerId, finishLine, finishRadius)
                end
            end
        end

        Avalanche.finishCheckThread = nil
    end)
end

-- 플레이어 골인 처리
RegisterNetEvent('minigames:server:playerFinished', function()
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 플레이어 상태 변경 (완주)
    player.state = GameModes.PlayerStates.SPECTATING
    player.stats.wins = player.stats.wins + 1

    -- 모든 플레이어에게 알림
    TriggerClientEvent('minigames:client:notify', -1, player.name .. ' 님이 골인했습니다!', 'success')

    Utils.Info('Player ' .. player.name .. ' finished!')

    -- 승리 처리
    local winner = {
        source = src,
        name = player.name,
        stats = player.stats
    }

    -- 라운드 종료
    OnRoundEnding({winner})
end)

-- 플레이어 사망 처리 (충돌로 죽었을 때)
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

    -- 승리 조건 체크 (모두 죽었는지)
    CheckWinCondition()
end)

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

    -- 모두 죽으면 무승부
    if #alivePlayers == 0 then
        OnRoundEnding({})

        Utils.Info('Avalanche: Draw - No survivors')
    end
end

Utils.Info('Avalanche gamemode (server) loaded')
