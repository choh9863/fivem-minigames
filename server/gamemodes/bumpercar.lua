-- ========================================
-- BUMPER CAR GAMEMODE - SERVER
-- ========================================

local BumperCar = {
    spawnedItems = {},
    itemSpawnThread = nil,
    boundaryCheckThread = nil,
    suddenDeathActive = false,
    suddenDeathThread = nil
}

-- 라운드 준비
AddEventHandler('minigames:server:gamemode:prepare:bumpercar', function()
    Utils.Info('Bumper Car: Preparing round')

    BumperCar.spawnedItems = {}
    BumperCar.suddenDeathActive = false

    -- 플레이어들을 스폰 위치로 텔레포트 및 차량 생성
    local map = CurrentRound.map
    local spawns = Utils.ShuffleTable(map.spawns)
    local spawnIndex = 1

    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            local spawn = spawns[spawnIndex]
            if spawn then
                -- 랜덤 차량 선택
                local vehicleData = Utils.GetRandomElement(Config.BumperCar.Vehicles)

                -- 플레이어에게 차량 생성 요청
                TriggerClientEvent('minigames:client:spawnVehicle', playerId,
                    vehicleData.model,
                    Utils.Vec4ToVec3(spawn),
                    spawn.w,
                    vehicleData
                )

                -- 플레이어 차량 데이터 저장
                player.vehicle = {
                    model = vehicleData.model,
                    health = vehicleData.health,
                    maxHealth = vehicleData.health,
                    stats = vehicleData
                }

                spawnIndex = spawnIndex + 1
                if spawnIndex > #spawns then
                    spawnIndex = 1
                end
            end
        end
    end

    Utils.Info('Bumper Car: Round prepared')
end)

-- 라운드 시작
AddEventHandler('minigames:server:gamemode:start:bumpercar', function()
    Utils.Info('Bumper Car: Starting round')

    -- 아이템 스폰 시작
    StartItemSpawning()

    -- 경계 체크 시작
    StartBoundaryCheck()

    -- 서든 데스 타이머 시작
    local suddenDeathTime = CurrentRound.gamemode.suddenDeathTime or 240
    SetTimeout(suddenDeathTime * 1000, function()
        if CurrentRound.state == GameModes.States.PLAYING then
            TriggerEvent('minigames:server:gamemode:suddendeath:bumpercar')
        end
    end)

    Utils.Info('Bumper Car: Round started')
end)

-- 라운드 종료
AddEventHandler('minigames:server:gamemode:end:bumpercar', function(winners)
    Utils.Info('Bumper Car: Ending round')

    -- 아이템 스폰 중지
    StopItemSpawning()

    -- 경계 체크 중지
    StopBoundaryCheck()

    -- 서든 데스 중지
    StopSuddenDeath()

    -- 모든 차량 제거
    for playerId, _ in pairs(Players) do
        TriggerClientEvent('minigames:client:deleteVehicle', playerId)
    end

    Utils.Info('Bumper Car: Round ended')
end)

-- 서든 데스 활성화
AddEventHandler('minigames:server:gamemode:suddendeath:bumpercar', function()
    Utils.Info('Bumper Car: Sudden death activated')

    BumperCar.suddenDeathActive = true

    -- 모든 플레이어에게 알림
    TriggerClientEvent('minigames:client:notify', -1, '서든 데스! 모든 차량의 체력이 감소합니다!', 'warning')

    -- 체력 감소 및 위치 표시 시작
    StartSuddenDeath()
end)

-- 아이템 스폰 시작
function StartItemSpawning()
    if BumperCar.itemSpawnThread then return end

    local map = CurrentRound.map
    if not map.itemSpawns then return end

    BumperCar.itemSpawnThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and not BumperCar.suddenDeathActive do
            Wait(5000) -- 5초마다 아이템 스폰 시도

            -- 랜덤 스폰 위치 선택
            local spawnPos = Utils.GetRandomElement(map.itemSpawns)
            if spawnPos then
                -- 랜덤 아이템 선택
                local item = Utils.GetRandomElement(Config.BumperCar.Items)

                -- 아이템 ID 생성
                local itemId = 'item_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)

                -- 아이템 스폰
                BumperCar.spawnedItems[itemId] = {
                    id = itemId,
                    coords = spawnPos,
                    item = item
                }

                -- 모든 클라이언트에 아이템 스폰 알림
                TriggerClientEvent('minigames:client:spawnItem', -1, itemId, spawnPos, item)

                Utils.Debug('Spawned item: ' .. item.name .. ' at ' .. tostring(spawnPos))
            end
        end

        BumperCar.itemSpawnThread = nil
    end)
end

-- 아이템 스폰 중지
function StopItemSpawning()
    BumperCar.spawnedItems = {}
    -- 모든 클라이언트에 아이템 제거 알림
    TriggerClientEvent('minigames:client:clearItems', -1)
end

-- 경계 체크 시작
function StartBoundaryCheck()
    if BumperCar.boundaryCheckThread then return end

    local map = CurrentRound.map
    if not map.boundary or not map.boundary.enabled then return end

    local center = map.boundary.center
    local radius = map.boundary.radius

    BumperCar.boundaryCheckThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING do
            Wait(1000) -- 1초마다 체크

            for playerId, player in pairs(Players) do
                if player.state == GameModes.PlayerStates.PLAYING then
                    -- 플레이어 위치 가져오기 (클라이언트에서)
                    TriggerClientEvent('minigames:client:checkBoundary', playerId, center, radius)
                end
            end
        end

        BumperCar.boundaryCheckThread = nil
    end)
end

-- 경계 체크 중지
function StopBoundaryCheck()
    -- 쓰레드는 자동으로 종료됨 (CurrentRound.state 체크)
end

-- 서든 데스 시작
function StartSuddenDeath()
    if BumperCar.suddenDeathThread then return end

    BumperCar.suddenDeathThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and BumperCar.suddenDeathActive do
            Wait(2000) -- 2초마다 체력 감소

            for playerId, player in pairs(Players) do
                if player.state == GameModes.PlayerStates.PLAYING and player.vehicle then
                    -- 차량 체력 감소
                    player.vehicle.health = player.vehicle.health - 10

                    -- 클라이언트에 데미지 전송
                    TriggerClientEvent('minigames:client:vehicleDamage', playerId, 10)

                    -- 체력이 0 이하면 사망 처리
                    if player.vehicle.health <= 0 then
                        TriggerEvent('minigames:server:playerDied', playerId)
                    end
                end
            end

            -- 모든 플레이어 위치 표시
            local playerPositions = {}
            for playerId, player in pairs(Players) do
                if player.state == GameModes.PlayerStates.PLAYING then
                    table.insert(playerPositions, playerId)
                end
            end

            TriggerClientEvent('minigames:client:showPlayerPositions', -1, playerPositions)
        end

        BumperCar.suddenDeathThread = nil
    end)
end

-- 서든 데스 중지
function StopSuddenDeath()
    BumperCar.suddenDeathActive = false
end

-- 아이템 습득 처리
RegisterNetEvent('minigames:server:pickupItem', function(itemId)
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 아이템 확인
    local spawnedItem = BumperCar.spawnedItems[itemId]
    if not spawnedItem then return end

    -- 아이템 제거
    BumperCar.spawnedItems[itemId] = nil

    -- 모든 클라이언트에 아이템 제거 알림
    TriggerClientEvent('minigames:client:removeItem', -1, itemId)

    -- 플레이어에게 아이템 전달
    TriggerClientEvent('minigames:client:pickupItem', src, spawnedItem.item)

    Utils.Debug('Player ' .. player.name .. ' picked up item: ' .. spawnedItem.item.name)
end)

-- 무작위 차량 요청 처리
RegisterNetEvent('minigames:server:requestRandomVehicle', function()
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end
    if not CurrentRound.map then return end

    -- 랜덤 차량 선택
    local vehicleData = Utils.GetRandomElement(Config.BumperCar.Vehicles)

    -- 현재 위치와 방향 유지
    TriggerClientEvent('minigames:client:changeVehicle', src, vehicleData)

    -- 플레이어 차량 데이터 업데이트
    player.vehicle = {
        model = vehicleData.model,
        health = vehicleData.health,
        maxHealth = vehicleData.health,
        stats = vehicleData
    }

    Utils.Debug('Player ' .. player.name .. ' changed vehicle to: ' .. vehicleData.model)
end)

-- 충돌 데미지 처리
RegisterNetEvent('minigames:server:collisionDamage', function(targetId, damage)
    local src = source
    local player = Players[src]
    local target = Players[targetId]

    if not player or not target then return end
    if player.state ~= GameModes.PlayerStates.PLAYING or target.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 대상에게 데미지 적용
    if target.vehicle then
        target.vehicle.health = target.vehicle.health - damage
        TriggerClientEvent('minigames:client:vehicleDamage', targetId, damage)

        -- 체력이 0 이하면 사망 처리
        if target.vehicle.health <= 0 then
            TriggerEvent('minigames:server:playerDied', targetId)
        end
    end

    Utils.Debug('Player ' .. player.name .. ' dealt ' .. damage .. ' damage to ' .. target.name)
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

    -- 승리 조건 체크 (마지막 1명)
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

    -- 1명 남으면 승리
    if #alivePlayers == 1 then
        -- 승리 처리
        local winner = alivePlayers[1]

        -- 라운드 종료
        OnRoundEnding({winner})

        Utils.Info('Bumper Car: Winner - ' .. winner.name)
    elseif #alivePlayers == 0 then
        -- 모두 죽으면 무승부
        OnRoundEnding({})

        Utils.Info('Bumper Car: Draw - No survivors')
    end
end

Utils.Info('Bumper Car gamemode (server) loaded')
