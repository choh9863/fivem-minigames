-- ========================================
-- WEAPON GAMEMODE - SERVER
-- ========================================

local Weapon = {
    spawnedWeapons = {},
    weaponSpawnThread = nil,
    projectiles = {},
    suddenDeathActive = false,
    suddenDeathThread = nil
}

-- 라운드 준비
AddEventHandler('minigames:server:gamemode:prepare:weapon', function()
    Utils.Info('Weapon: Preparing round')

    Weapon.spawnedWeapons = {}
    Weapon.projectiles = {}
    Weapon.suddenDeathActive = false

    -- 플레이어들을 스폰 위치로 텔레포트 및 차량 생성
    local map = CurrentRound.map
    local spawns = Utils.ShuffleTable(map.spawns)
    local spawnIndex = 1

    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            local spawn = spawns[spawnIndex]
            if spawn then
                -- 랜덤 차량 선택
                local vehicleData = Utils.GetRandomElement(Config.Weapon.Vehicles)

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

                -- 기본 무기 부여
                player.weapon = Config.Weapon.Weapons[1] -- 첫 번째 무기 (pistol 등)
                player.ammo = player.weapon.ammo
                player.isReloading = false

                -- 클라이언트에 무기 부여 알림
                TriggerClientEvent('minigames:client:equipWeapon', playerId, player.weapon)

                spawnIndex = spawnIndex + 1
                if spawnIndex > #spawns then
                    spawnIndex = 1
                end
            end
        end
    end

    Utils.Info('Weapon: Round prepared')
end)

-- 라운드 시작
AddEventHandler('minigames:server:gamemode:start:weapon', function()
    Utils.Info('Weapon: Starting round')

    -- 무기 아이템 스폰 시작
    StartWeaponSpawning()

    -- 서든 데스 타이머 시작
    local suddenDeathTime = CurrentRound.gamemode.suddenDeathTime or 240
    SetTimeout(suddenDeathTime * 1000, function()
        if CurrentRound.state == GameModes.States.PLAYING then
            TriggerEvent('minigames:server:gamemode:suddendeath:weapon')
        end
    end)

    Utils.Info('Weapon: Round started')
end)

-- 라운드 종료
AddEventHandler('minigames:server:gamemode:end:weapon', function(winners)
    Utils.Info('Weapon: Ending round')

    -- 무기 스폰 중지
    StopWeaponSpawning()

    -- 서든 데스 중지
    StopSuddenDeath()

    -- 모든 차량 제거
    for playerId, _ in pairs(Players) do
        TriggerClientEvent('minigames:client:deleteVehicle', playerId)
        TriggerClientEvent('minigames:client:removeWeapon', playerId)
    end

    Utils.Info('Weapon: Round ended')
end)

-- 서든 데스 활성화
AddEventHandler('minigames:server:gamemode:suddendeath:weapon', function()
    Utils.Info('Weapon: Sudden death activated')

    Weapon.suddenDeathActive = true

    -- 모든 플레이어에게 알림
    TriggerClientEvent('minigames:client:notify', -1, '서든 데스! 모든 차량의 체력이 감소합니다!', 'warning')

    -- 체력 감소 및 위치 표시 시작
    StartSuddenDeath()
end)

-- 무기 스폰 시작
function StartWeaponSpawning()
    if Weapon.weaponSpawnThread then return end

    local map = CurrentRound.map
    if not map.weaponSpawns then return end

    Weapon.weaponSpawnThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and not Weapon.suddenDeathActive do
            Wait(10000) -- 10초마다 무기 스폰

            -- 랜덤 스폰 위치 선택
            local spawnPos = Utils.GetRandomElement(map.weaponSpawns)
            if spawnPos then
                -- 랜덤 무기 선택
                local weapon = Utils.GetRandomElement(Config.Weapon.Weapons)

                -- 무기 ID 생성
                local weaponId = 'weapon_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)

                -- 무기 스폰
                Weapon.spawnedWeapons[weaponId] = {
                    id = weaponId,
                    coords = spawnPos,
                    weapon = weapon
                }

                -- 모든 클라이언트에 무기 스폰 알림
                TriggerClientEvent('minigames:client:spawnWeaponPickup', -1, weaponId, spawnPos, weapon)

                Utils.Debug('Spawned weapon: ' .. weapon.name .. ' at ' .. tostring(spawnPos))
            end
        end

        Weapon.weaponSpawnThread = nil
    end)
end

-- 무기 스폰 중지
function StopWeaponSpawning()
    Weapon.spawnedWeapons = {}
    -- 모든 클라이언트에 무기 제거 알림
    TriggerClientEvent('minigames:client:clearWeaponPickups', -1)
end

-- 서든 데스 시작
function StartSuddenDeath()
    if Weapon.suddenDeathThread then return end

    Weapon.suddenDeathThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and Weapon.suddenDeathActive do
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

        Weapon.suddenDeathThread = nil
    end)
end

-- 서든 데스 중지
function StopSuddenDeath()
    Weapon.suddenDeathActive = false
end

-- 무기 습득 처리
RegisterNetEvent('minigames:server:pickupWeapon', function(weaponId)
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 무기 확인
    local spawnedWeapon = Weapon.spawnedWeapons[weaponId]
    if not spawnedWeapon then return end

    -- 무기 제거
    Weapon.spawnedWeapons[weaponId] = nil

    -- 모든 클라이언트에 무기 제거 알림
    TriggerClientEvent('minigames:client:removeWeaponPickup', -1, weaponId)

    -- 플레이어에게 무기 장착
    player.weapon = spawnedWeapon.weapon
    player.ammo = spawnedWeapon.weapon.ammo
    player.isReloading = false

    TriggerClientEvent('minigames:client:equipWeapon', src, spawnedWeapon.weapon)

    Utils.Debug('Player ' .. player.name .. ' picked up weapon: ' .. spawnedWeapon.weapon.name)
end)

-- 무기 발사 처리
RegisterNetEvent('minigames:server:fireWeapon', function(origin, direction, weaponData, homing, targetId)
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end
    if not player.weapon or player.isReloading then return end

    -- 탄약 체크
    if player.ammo <= 0 then
        TriggerClientEvent('minigames:client:notify', src, '탄약이 부족합니다!', 'warning')
        return
    end

    -- 탄약 소모
    player.ammo = player.ammo - 1

    -- 클라이언트에 탄약 업데이트
    TriggerClientEvent('minigames:client:updateAmmo', src, player.ammo)

    -- 발사체 생성
    local projectileId = 'projectile_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)

    local projectile = {
        id = projectileId,
        owner = src,
        origin = origin,
        direction = direction,
        speed = 100.0,
        damage = weaponData.damage or 100,
        homing = homing,
        targetId = targetId,
        spawnTime = GetGameTimer()
    }

    Weapon.projectiles[projectileId] = projectile

    -- 모든 클라이언트에 발사체 생성 알림
    TriggerClientEvent('minigames:client:createProjectile', -1, projectileId, projectile)

    Utils.Debug('Player ' .. player.name .. ' fired weapon')

    -- 발사체 업데이트 시작
    UpdateProjectile(projectileId)
end)

-- 발사체 업데이트
function UpdateProjectile(projectileId)
    CreateThread(function()
        local maxLifetime = 5000 -- 5초
        local updateInterval = 50 -- 50ms

        while Weapon.projectiles[projectileId] do
            Wait(updateInterval)

            local projectile = Weapon.projectiles[projectileId]
            if not projectile then break end

            -- 수명 체크
            if GetGameTimer() - projectile.spawnTime > maxLifetime then
                -- 발사체 제거
                TriggerClientEvent('minigames:client:removeProjectile', -1, projectileId)
                Weapon.projectiles[projectileId] = nil
                break
            end

            -- 충돌 체크는 클라이언트에서 처리
        end
    end)
end

-- 발사체 충돌 처리
RegisterNetEvent('minigames:server:projectileHit', function(projectileId, targetId)
    local src = source
    local projectile = Weapon.projectiles[projectileId]

    if not projectile then return end

    local target = Players[targetId]
    if not target or target.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 데미지 적용
    if target.vehicle then
        target.vehicle.health = target.vehicle.health - projectile.damage
        TriggerClientEvent('minigames:client:vehicleDamage', targetId, projectile.damage)

        -- 체력이 0 이하면 사망 처리
        if target.vehicle.health <= 0 then
            -- 킬 카운트
            local attacker = Players[projectile.owner]
            if attacker then
                attacker.stats.kills = attacker.stats.kills + 1
            end

            TriggerEvent('minigames:server:playerDied', targetId)
        end
    end

    -- 발사체 제거
    TriggerClientEvent('minigames:client:removeProjectile', -1, projectileId)
    Weapon.projectiles[projectileId] = nil

    Utils.Debug('Projectile hit player ' .. targetId)
end)

-- 재장전 처리
RegisterNetEvent('minigames:server:reloadWeapon', function()
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end
    if not player.weapon or player.isReloading then return end

    -- 재장전 시작
    player.isReloading = true

    -- 클라이언트에 재장전 알림
    TriggerClientEvent('minigames:client:startReload', src, player.weapon.reloadTime)

    -- 재장전 시간 후 완료
    SetTimeout(player.weapon.reloadTime * 1000, function()
        if player and player.weapon then
            player.ammo = player.weapon.ammo
            player.isReloading = false

            TriggerClientEvent('minigames:client:updateAmmo', src, player.ammo)
            TriggerClientEvent('minigames:client:notify', src, '재장전 완료!', 'success')

            Utils.Debug('Player ' .. player.name .. ' reloaded weapon')
        end
    end)
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
        local winner = alivePlayers[1]

        -- 라운드 종료
        OnRoundEnding({winner})

        Utils.Info('Weapon: Winner - ' .. winner.name)
    elseif #alivePlayers == 0 then
        -- 모두 죽으면 무승부
        OnRoundEnding({})

        Utils.Info('Weapon: Draw - No survivors')
    end
end

Utils.Info('Weapon gamemode (server) loaded')
