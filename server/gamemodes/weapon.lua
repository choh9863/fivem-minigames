-- ========================================
-- WEAPON GAMEMODE - SERVER (차량 무기 시스템)
-- ========================================

local Weapon = {
    spawnedWeapons = {},
    weaponSpawnThread = nil,
    projectiles = {},
    suddenDeathActive = false,
    suddenDeathThread = nil
}

-- ========================================
-- 라운드 준비
-- ========================================
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

                -- 기본 무기 부여 (권총)
                local defaultWeapon = nil
                for _, weapon in ipairs(Config.Weapon.Weapons) do
                    if weapon.id == "pistol" then
                        defaultWeapon = weapon
                        break
                    end
                end

                if defaultWeapon then
                    player.weapon = defaultWeapon
                    player.ammo = defaultWeapon.maxAmmo
                    player.isReloading = false

                    -- 클라이언트에 무기 부여 알림
                    TriggerClientEvent('minigames:client:weapon:equip', playerId, defaultWeapon)
                end

                spawnIndex = spawnIndex + 1
                if spawnIndex > #spawns then
                    spawnIndex = 1
                end
            end
        end
    end

    Utils.Info('Weapon: Round prepared')
end)

-- ========================================
-- 라운드 시작
-- ========================================
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

-- ========================================
-- 라운드 종료
-- ========================================
AddEventHandler('minigames:server:gamemode:end:weapon', function(winners)
    Utils.Info('Weapon: Ending round')

    -- 무기 스폰 중지
    StopWeaponSpawning()

    -- 서든 데스 중지
    StopSuddenDeath()

    -- 모든 차량 및 무기 제거
    for playerId, _ in pairs(Players) do
        TriggerClientEvent('minigames:client:deleteVehicle', playerId)
        TriggerClientEvent('minigames:client:weapon:remove', playerId)
    end

    -- 모든 발사체 제거
    Weapon.projectiles = {}
    TriggerClientEvent('minigames:client:weapon:clearAllProjectiles', -1)

    Utils.Info('Weapon: Round ended')
end)

-- ========================================
-- 서든 데스 활성화
-- ========================================
AddEventHandler('minigames:server:gamemode:suddendeath:weapon', function()
    Utils.Info('Weapon: Sudden death activated')

    Weapon.suddenDeathActive = true

    -- 모든 플레이어에게 알림
    TriggerClientEvent('minigames:client:notify', -1, '서든 데스! 모든 차량의 체력이 감소합니다!', 'warning')

    -- 체력 감소 시작
    StartSuddenDeath()
end)

-- ========================================
-- 무기 스폰 시작
-- ========================================
function StartWeaponSpawning()
    if Weapon.weaponSpawnThread then return end

    local map = CurrentRound.map
    if not map.weaponSpawns or #map.weaponSpawns == 0 then
        Utils.Warn('Weapon: No weapon spawn points found')
        return
    end

    Weapon.weaponSpawnThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and not Weapon.suddenDeathActive do
            Wait(10000) -- 10초마다 무기 스폰

            -- 랜덤 스폰 위치 선택
            local spawnPos = Utils.GetRandomElement(map.weaponSpawns)
            if spawnPos then
                -- 랜덤 무기 선택 (권총 제외)
                local availableWeapons = {}
                for _, weapon in ipairs(Config.Weapon.Weapons) do
                    if weapon.id ~= "pistol" then
                        table.insert(availableWeapons, weapon)
                    end
                end

                local weapon = Utils.GetRandomElement(availableWeapons)
                if weapon then
                    -- 무기 ID 생성
                    local weaponId = 'weapon_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)

                    -- 무기 스폰
                    Weapon.spawnedWeapons[weaponId] = {
                        id = weaponId,
                        coords = spawnPos,
                        weapon = weapon
                    }

                    -- 모든 클라이언트에 무기 스폰 알림
                    TriggerClientEvent('minigames:client:weapon:spawnPickup', -1, weaponId, spawnPos, weapon)

                    Utils.Debug('Spawned weapon: ' .. weapon.name .. ' at ' .. tostring(spawnPos))
                end
            end
        end

        Weapon.weaponSpawnThread = nil
    end)
end

-- ========================================
-- 무기 스폰 중지
-- ========================================
function StopWeaponSpawning()
    Weapon.spawnedWeapons = {}
    -- 모든 클라이언트에 무기 제거 알림
    TriggerClientEvent('minigames:client:weapon:clearPickups', -1)
end

-- ========================================
-- 서든 데스 시작
-- ========================================
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
                        TriggerEvent('minigames:server:weapon:playerDied', playerId)
                    end
                end
            end
        end

        Weapon.suddenDeathThread = nil
    end)
end

-- ========================================
-- 서든 데스 중지
-- ========================================
function StopSuddenDeath()
    Weapon.suddenDeathActive = false
end

-- ========================================
-- 무기 습득 처리
-- ========================================
RegisterNetEvent('minigames:server:weapon:pickupWeapon', function(weaponId)
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 무기 확인
    local spawnedWeapon = Weapon.spawnedWeapons[weaponId]
    if not spawnedWeapon then return end

    -- 무기 제거
    Weapon.spawnedWeapons[weaponId] = nil

    -- 모든 클라이언트에 무기 제거 알림
    TriggerClientEvent('minigames:client:weapon:removePickup', -1, weaponId)

    -- 플레이어에게 무기 장착
    player.weapon = spawnedWeapon.weapon
    player.ammo = spawnedWeapon.weapon.maxAmmo
    player.isReloading = false

    TriggerClientEvent('minigames:client:weapon:equip', src, spawnedWeapon.weapon)
    TriggerClientEvent('minigames:client:notify', src, spawnedWeapon.weapon.name .. ' 획득!', 'success')

    Utils.Debug('Player ' .. player.name .. ' picked up weapon: ' .. spawnedWeapon.weapon.name)
end)

-- ========================================
-- 무기 발사 처리
-- ========================================
RegisterNetEvent('minigames:server:weapon:fire', function(projectilesData)
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end
    if not player.weapon or player.isReloading then return end

    -- 탄약 체크
    local shotsToFire = #projectilesData
    if player.ammo < shotsToFire then
        return
    end

    -- 탄약 소모
    player.ammo = player.ammo - shotsToFire

    -- 클라이언트에 탄약 업데이트
    TriggerClientEvent('minigames:client:weapon:updateAmmo', src, player.ammo)

    -- 발사체 생성
    for _, projData in ipairs(projectilesData) do
        local projectileId = 'projectile_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)

        local projectile = {
            id = projectileId,
            owner = src,
            ownerName = player.name,
            origin = projData.origin,
            direction = projData.direction,
            weaponData = player.weapon,
            spawnTime = GetGameTimer(),
            active = true
        }

        Weapon.projectiles[projectileId] = projectile

        -- 모든 클라이언트에 발사체 생성 알림
        TriggerClientEvent('minigames:client:weapon:createProjectile', -1, projectileId, projectile)
    end

    Utils.Debug('Player ' .. player.name .. ' fired weapon: ' .. shotsToFire .. ' shots')
end)

-- ========================================
-- 발사체 충돌 처리
-- ========================================
RegisterNetEvent('minigames:server:weapon:projectileHit', function(projectileId, targetVehicle, hitCoords)
    local src = source
    local projectile = Weapon.projectiles[projectileId]

    if not projectile or not projectile.active then return end

    -- 발사체 비활성화
    projectile.active = false

    -- 타겟 플레이어 찾기
    local targetId = nil
    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING and player.vehicle then
            -- 클라이언트에서 네트워크 ID를 전달받음
            local netId = NetworkGetNetworkIdFromEntity(targetVehicle)
            TriggerClientEvent('minigames:client:weapon:checkVehicleOwnership', playerId, netId, projectileId, projectile.weaponData.damage)
        end
    end

    -- 발사체 제거
    SetTimeout(100, function()
        Weapon.projectiles[projectileId] = nil
        TriggerClientEvent('minigames:client:weapon:removeProjectile', -1, projectileId)
    end)

    Utils.Debug('Projectile ' .. projectileId .. ' hit vehicle')
end)

-- ========================================
-- 차량 데미지 확인
-- ========================================
RegisterNetEvent('minigames:server:weapon:confirmVehicleHit', function(projectileId, damage)
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end
    if not player.vehicle then return end

    local projectile = Weapon.projectiles[projectileId]
    if not projectile then return end

    -- 자신의 발사체는 무시
    if projectile.owner == src then return end

    -- 데미지 적용
    player.vehicle.health = player.vehicle.health - damage
    TriggerClientEvent('minigames:client:vehicleDamage', src, damage)

    Utils.Debug('Player ' .. player.name .. ' took ' .. damage .. ' damage (health: ' .. player.vehicle.health .. ')')

    -- 체력이 0 이하면 사망 처리
    if player.vehicle.health <= 0 then
        -- 킬 카운트
        local attacker = Players[projectile.owner]
        if attacker then
            attacker.stats.kills = attacker.stats.kills + 1
            TriggerClientEvent('minigames:client:notify', projectile.owner,
                player.name .. ' 처치!', 'success')
        end

        TriggerEvent('minigames:server:weapon:playerDied', src)
    end
end)

-- ========================================
-- 재장전 처리
-- ========================================
RegisterNetEvent('minigames:server:weapon:reload', function()
    local src = source
    local player = Players[src]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end
    if not player.weapon or player.isReloading then return end

    -- 이미 최대 탄약이면 재장전 불필요
    if player.ammo >= player.weapon.maxAmmo then
        TriggerClientEvent('minigames:client:notify', src, '탄약이 가득 찼습니다!', 'info')
        return
    end

    -- 재장전 시작
    player.isReloading = true

    -- 클라이언트에 재장전 알림
    TriggerClientEvent('minigames:client:weapon:startReload', src, player.weapon.reloadTime)

    Utils.Debug('Player ' .. player.name .. ' started reloading')

    -- 재장전 시간 후 완료
    SetTimeout(player.weapon.reloadTime, function()
        if player and player.weapon then
            player.ammo = player.weapon.maxAmmo
            player.isReloading = false

            TriggerClientEvent('minigames:client:weapon:updateAmmo', src, player.ammo)
            TriggerClientEvent('minigames:client:weapon:finishReload', src)
            TriggerClientEvent('minigames:client:notify', src, '재장전 완료!', 'success')

            Utils.Debug('Player ' .. player.name .. ' finished reloading')
        end
    end)
end)

-- ========================================
-- 플레이어 사망 처리
-- ========================================
RegisterNetEvent('minigames:server:weapon:playerDied', function(playerId)
    playerId = playerId or source
    local player = Players[playerId]

    if not player or player.state ~= GameModes.PlayerStates.PLAYING then return end

    -- 플레이어 상태 변경
    player.state = GameModes.PlayerStates.DEAD
    player.stats.deaths = player.stats.deaths + 1

    -- 차량 제거
    TriggerClientEvent('minigames:client:deleteVehicle', playerId)
    TriggerClientEvent('minigames:client:weapon:remove', playerId)

    -- 모든 플레이어에게 사망 알림
    TriggerClientEvent('minigames:client:playerDied', -1, playerId, player.name)
    TriggerClientEvent('minigames:client:notify', -1, player.name .. '님이 사망했습니다!', 'error')

    Utils.Info('Player ' .. player.name .. ' died')

    -- 승리 조건 체크 (마지막 1명)
    CheckWinCondition()
end)

-- ========================================
-- 승리 조건 체크
-- ========================================
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
