-- ========================================
-- WEAPON GAMEMODE - CLIENT (차량 무기 시스템)
-- ========================================

local Weapon = {
    -- 무기 상태
    currentWeapon = nil,
    currentAmmo = 0,
    isReloading = false,
    weaponProp = nil,
    vehicleData = nil,

    -- 무기 픽업
    weaponPickups = {},
    pickupObjects = {},

    -- 발사체
    projectiles = {},

    -- 타겟팅
    currentTarget = nil,

    -- 쓰레드
    shootingThread = nil,
    targetingThread = nil,
    renderThread = nil,
    pickupThread = nil,

    -- 발사 제어
    lastShotTime = 0,

    -- 재장전 진행
    reloadStartTime = 0,
    reloadDuration = 0
}

-- ========================================
-- 게임모드 초기화
-- ========================================
RegisterNetEvent('minigames:client:gamemode:initialize', function(gamemodeId, map)
    if gamemodeId ~= "weapon" then return end

    Utils.Info('Weapon: Initializing')

    -- 모든 상태 초기화
    Weapon.currentWeapon = nil
    Weapon.currentAmmo = 0
    Weapon.isReloading = false
    Weapon.weaponProp = nil
    Weapon.weaponPickups = {}
    Weapon.pickupObjects = {}
    Weapon.projectiles = {}
    Weapon.currentTarget = nil
    Weapon.lastShotTime = 0

    -- 쓰레드 시작
    StartShooting()
    StartTargeting()
    StartRendering()
    StartPickupCheck()
end)

-- ========================================
-- 게임모드 종료
-- ========================================
RegisterNetEvent('minigames:client:gamemode:cleanup', function(gamemodeId)
    if gamemodeId ~= "weapon" then return end

    Utils.Info('Weapon: Cleaning up')

    -- 무기 제거
    RemoveWeaponProp()

    -- 픽업 오브젝트 제거
    ClearPickupObjects()

    -- 모든 발사체 제거
    ClearAllProjectiles()

    -- 상태 초기화
    Weapon.currentWeapon = nil
    Weapon.currentAmmo = 0
    Weapon.isReloading = false
    Weapon.weaponPickups = {}
    Weapon.projectiles = {}
end)

-- ========================================
-- 무기 장착
-- ========================================
RegisterNetEvent('minigames:client:weapon:equip', function(weapon)
    Weapon.currentWeapon = weapon
    Weapon.currentAmmo = weapon.maxAmmo
    Weapon.isReloading = false

    -- 무기 프롭 생성
    CreateWeaponProp(weapon)

    Utils.Info('Equipped weapon: ' .. weapon.name)
end)

-- ========================================
-- 무기 제거
-- ========================================
RegisterNetEvent('minigames:client:weapon:remove', function()
    RemoveWeaponProp()

    Weapon.currentWeapon = nil
    Weapon.currentAmmo = 0
    Weapon.isReloading = false
end)

-- ========================================
-- 무기 프롭 생성
-- ========================================
function CreateWeaponProp(weapon)
    -- 기존 프롭 제거
    RemoveWeaponProp()

    local vehicle = LocalPlayer.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end

    -- 차량 모델 가져오기
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleModelName = GetDisplayNameFromVehicleModel(vehicleModel)

    -- 차량별 무기 부착 설정 가져오기
    local vehicleConfig = nil
    for _, vConfig in ipairs(Config.Weapon.Vehicles) do
        if GetHashKey(vConfig.model) == vehicleModel then
            vehicleConfig = vConfig
            break
        end
    end

    if not vehicleConfig then
        vehicleConfig = Config.Weapon.Vehicles[1] -- 기본 설정 사용
    end

    Weapon.vehicleData = vehicleConfig

    -- 무기 모델 로드
    local weaponModel = GetHashKey(weapon.model)
    RequestModel(weaponModel)

    local timeout = 0
    while not HasModelLoaded(weaponModel) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    if not HasModelLoaded(weaponModel) then
        Utils.Error('Failed to load weapon model: ' .. weapon.model)
        return
    end

    -- 무기 프롭 생성
    local vehicleCoords = GetEntityCoords(vehicle)
    Weapon.weaponProp = CreateObject(weaponModel, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z,
        false, false, false)

    SetEntityCollision(Weapon.weaponProp, false, false)
    SetEntityCompletelyDisableCollision(Weapon.weaponProp, false, false)

    -- 차량별 부착 위치 가져오기
    local attachmentConfig = vehicleConfig.weapons[weapon.id]
    local offset = attachmentConfig and attachmentConfig.offset or vector3(0.0, 2.0, 0.5)
    local rotation = attachmentConfig and attachmentConfig.rotation or vector3(0.0, 0.0, 0.0)

    -- 차량에 부착
    AttachEntityToEntity(
        Weapon.weaponProp,
        vehicle,
        GetEntityBoneIndexByName(vehicle, "chassis"), -- 차량 본
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, false, false, false, 2, true
    )

    SetModelAsNoLongerNeeded(weaponModel)

    Utils.Debug('Weapon prop created and attached')
end)

-- ========================================
-- 무기 프롭 제거
-- ========================================
function RemoveWeaponProp()
    if Weapon.weaponProp and DoesEntityExist(Weapon.weaponProp) then
        DeleteObject(Weapon.weaponProp)
        Weapon.weaponProp = nil
        Utils.Debug('Weapon prop removed')
    end
end

-- ========================================
-- 무기 픽업 스폰
-- ========================================
RegisterNetEvent('minigames:client:weapon:spawnPickup', function(weaponId, coords, weapon)
    Weapon.weaponPickups[weaponId] = {
        id = weaponId,
        coords = coords,
        weapon = weapon
    }

    -- 픽업 오브젝트 생성 (선택사항)
    CreatePickupObject(weaponId, coords, weapon)
end)

-- ========================================
-- 무기 픽업 제거
-- ========================================
RegisterNetEvent('minigames:client:weapon:removePickup', function(weaponId)
    Weapon.weaponPickups[weaponId] = nil

    -- 픽업 오브젝트 제거
    if Weapon.pickupObjects[weaponId] then
        if DoesEntityExist(Weapon.pickupObjects[weaponId]) then
            DeleteObject(Weapon.pickupObjects[weaponId])
        end
        Weapon.pickupObjects[weaponId] = nil
    end
end)

-- ========================================
-- 무기 픽업 전체 제거
-- ========================================
RegisterNetEvent('minigames:client:weapon:clearPickups', function()
    Weapon.weaponPickups = {}
    ClearPickupObjects()
end)

-- ========================================
-- 픽업 오브젝트 생성
-- ========================================
function CreatePickupObject(weaponId, coords, weapon)
    local model = GetHashKey(weapon.model)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) and timeout < 3000 do
        Wait(10)
        timeout = timeout + 10
    end

    if HasModelLoaded(model) then
        local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
        SetEntityCollision(obj, false, false)
        PlaceObjectOnGroundProperly(obj)
        Weapon.pickupObjects[weaponId] = obj
        SetModelAsNoLongerNeeded(model)
    end
end

-- ========================================
-- 픽업 오브젝트 전체 제거
-- ========================================
function ClearPickupObjects()
    for weaponId, obj in pairs(Weapon.pickupObjects) do
        if DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
    Weapon.pickupObjects = {}
end

-- ========================================
-- 탄약 업데이트
-- ========================================
RegisterNetEvent('minigames:client:weapon:updateAmmo', function(ammo)
    Weapon.currentAmmo = ammo
end)

-- ========================================
-- 재장전 시작
-- ========================================
RegisterNetEvent('minigames:client:weapon:startReload', function(reloadTime)
    Weapon.isReloading = true
    Weapon.reloadStartTime = GetGameTimer()
    Weapon.reloadDuration = reloadTime

    -- 재장전 사운드
    PlaySoundFrontend(-1, "WEAPON_PURCHASE", "HUD_AMMO_SHOP_SOUNDSET", true)
end)

-- ========================================
-- 재장전 완료
-- ========================================
RegisterNetEvent('minigames:client:weapon:finishReload', function()
    Weapon.isReloading = false
    Weapon.reloadStartTime = 0

    -- 재장전 완료 사운드
    PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", true)
end)

-- ========================================
-- 타겟팅 시스템 시작
-- ========================================
function StartTargeting()
    if Weapon.targetingThread then return end

    Weapon.targetingThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "weapon" do
            Wait(0)

            local vehicle = LocalPlayer.vehicle

            if vehicle and DoesEntityExist(vehicle) and Weapon.currentWeapon then
                -- 카메라 방향 가져오기
                local camRot = GetGameplayCamRot(0)
                local camCoords = GetGameplayCamCoord()
                local direction = RotationToDirection(camRot)
                local destination = vector3(
                    camCoords.x + direction.x * 1000.0,
                    camCoords.y + direction.y * 1000.0,
                    camCoords.z + direction.z * 1000.0
                )

                -- 레이캐스트
                local rayHandle = StartShapeTestRay(
                    camCoords.x, camCoords.y, camCoords.z,
                    destination.x, destination.y, destination.z,
                    10, -- 차량만
                    vehicle, 0
                )

                local _, hit, hitCoords, _, entityHit = GetShapeTestResult(rayHandle)

                if hit and entityHit and IsEntityAVehicle(entityHit) and entityHit ~= vehicle then
                    local targetPed = GetPedInVehicleSeat(entityHit, -1)

                    if targetPed and IsPedAPlayer(targetPed) and targetPed ~= PlayerPedId() then
                        Weapon.currentTarget = {
                            entity = entityHit,
                            playerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(targetPed)),
                            coords = hitCoords
                        }

                        -- 조준점 그리기
                        DrawTargetMarker(entityHit)
                    else
                        Weapon.currentTarget = nil
                    end
                else
                    Weapon.currentTarget = nil
                end

                -- 조준선 그리기
                DrawCrosshair()
            else
                Wait(500)
            end
        end

        Weapon.targetingThread = nil
        Weapon.currentTarget = nil
    end)
end

-- ========================================
-- 타겟 마커 그리기
-- ========================================
function DrawTargetMarker(entity)
    local coords = GetEntityCoords(entity)

    -- 3D 마커 (빨간색)
    DrawMarker(
        0, -- 원통형
        coords.x, coords.y, coords.z + 2.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        1.5, 1.5, 1.5,
        255, 0, 0, 150,
        true, true, 2, false, nil, nil, false
    )
end

-- ========================================
-- 조준선 그리기
-- ========================================
function DrawCrosshair()
    local screenX, screenY = 0.5, 0.5

    -- 십자 조준선
    local color = Weapon.currentTarget and {255, 0, 0, 255} or {255, 255, 255, 255}
    DrawRect(screenX, screenY, 0.002, 0.02, color[1], color[2], color[3], color[4])
    DrawRect(screenX, screenY, 0.02, 0.002, color[1], color[2], color[3], color[4])
end

-- ========================================
-- 회전을 방향 벡터로 변환
-- ========================================
function RotationToDirection(rotation)
    local adjustedRotation = vector3(
        (math.pi / 180) * rotation.x,
        (math.pi / 180) * rotation.y,
        (math.pi / 180) * rotation.z
    )

    return vector3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
end

-- ========================================
-- 발사 시스템 시작
-- ========================================
function StartShooting()
    if Weapon.shootingThread then return end

    Weapon.shootingThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "weapon" do
            Wait(0)

            local vehicle = LocalPlayer.vehicle

            if vehicle and DoesEntityExist(vehicle) and Weapon.currentWeapon and not Weapon.isReloading then
                -- 좌클릭으로 발사
                if IsControlPressed(0, 24) then -- Left Mouse Button
                    local currentTime = GetGameTimer()
                    local fireInterval = 1000 / (Weapon.currentWeapon.fireRate or 1.0)

                    if currentTime - Weapon.lastShotTime >= fireInterval and Weapon.currentAmmo > 0 then
                        FireWeapon()
                        Weapon.lastShotTime = currentTime
                    end
                end

                -- R키로 재장전
                if IsControlJustPressed(0, 45) then -- R
                    TriggerServerEvent('minigames:server:weapon:reload')
                end
            else
                Wait(100)
            end
        end

        Weapon.shootingThread = nil
    end)
end

-- ========================================
-- 무기 발사
-- ========================================
function FireWeapon()
    if Weapon.currentAmmo <= 0 then
        TriggerEvent('minigames:client:notify', '탄약이 부족합니다! [R]키로 재장전하세요.', 'warning')
        return
    end

    local vehicle = LocalPlayer.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end

    -- 차량의 정면 방향
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleForward = GetEntityForwardVector(vehicle)

    -- 발사 위치 (무기 프롭 위치 또는 차량 앞)
    local fireOffset = 3.0
    local fireHeight = 0.5
    local origin = vehicleCoords + (vehicleForward * fireOffset) + vector3(0, 0, fireHeight)

    -- 카메라 방향으로 발사
    local camRot = GetGameplayCamRot(0)
    local direction = RotationToDirection(camRot)

    -- 발사체 데이터 준비
    local projectilesData = {}

    -- 산탄총 처리
    if Weapon.currentWeapon.spread then
        local spreadCount = Weapon.currentWeapon.spreadCount or 5
        local spreadAngle = Weapon.currentWeapon.spreadAngle or 5.0

        for i = 1, spreadCount do
            -- 랜덤 각도 생성
            local angleOffset = math.random() * spreadAngle - (spreadAngle / 2)
            local pitchOffset = math.random() * spreadAngle - (spreadAngle / 2)

            -- 방향 벡터 회전
            local spreadDirection = RotateVector(direction, angleOffset, pitchOffset)

            table.insert(projectilesData, {
                origin = origin,
                direction = spreadDirection
            })
        end
    else
        table.insert(projectilesData, {
            origin = origin,
            direction = direction
        })
    end

    -- 서버에 발사 요청
    TriggerServerEvent('minigames:server:weapon:fire', projectilesData)

    -- 발사 이펙트
    PlayFireEffect(origin)

    -- 사운드
    PlaySoundFrontend(-1, "WEAPON_FIRE", "HUD_AMMO_SHOP_SOUNDSET", false)

    Utils.Debug('Fired weapon')
end

-- ========================================
-- 벡터 회전
-- ========================================
function RotateVector(vec, yawDeg, pitchDeg)
    local yaw = math.rad(yawDeg)
    local pitch = math.rad(pitchDeg)

    -- Yaw 회전
    local cosYaw = math.cos(yaw)
    local sinYaw = math.sin(yaw)
    local rotatedX = vec.x * cosYaw - vec.y * sinYaw
    local rotatedY = vec.x * sinYaw + vec.y * cosYaw

    -- Pitch 회전
    local cosPitch = math.cos(pitch)
    local sinPitch = math.sin(pitch)
    local rotatedZ = vec.z * cosPitch - rotatedY * sinPitch
    local finalY = vec.z * sinPitch + rotatedY * cosPitch

    return vector3(rotatedX, finalY, rotatedZ)
end

-- ========================================
-- 발사 이펙트
-- ========================================
function PlayFireEffect(origin)
    -- 총구 화염
    RequestNamedPtfxAsset("core")
    local timeout = 0
    while not HasNamedPtfxAssetLoaded("core") and timeout < 1000 do
        Wait(10)
        timeout = timeout + 10
    end

    if HasNamedPtfxAssetLoaded("core") then
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("muz_pistol", origin.x, origin.y, origin.z,
            0.0, 0.0, 0.0, 0.5, false, false, false)
    end
end

-- ========================================
-- 발사체 생성
-- ========================================
RegisterNetEvent('minigames:client:weapon:createProjectile', function(projectileId, projectileData)
    -- 발사체 모델 로드
    local model = GetHashKey(projectileData.weaponData.projectileModel)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) and timeout < 3000 do
        Wait(10)
        timeout = timeout + 10
    end

    if not HasModelLoaded(model) then
        Utils.Error('Failed to load projectile model: ' .. projectileData.weaponData.projectileModel)
        return
    end

    -- 발사체 오브젝트 생성
    local origin = projectileData.origin
    local projectileObj = CreateObject(model, origin.x, origin.y, origin.z, true, true, false)

    -- 충돌 비활성화
    SetEntityCollision(projectileObj, false, false)

    -- 스케일 적용
    if projectileData.weaponData.projectileScale then
        SetObjectScale(projectileObj, projectileData.weaponData.projectileScale)
    end

    SetModelAsNoLongerNeeded(model)

    -- 발사체 데이터 저장
    Weapon.projectiles[projectileId] = {
        id = projectileId,
        object = projectileObj,
        data = projectileData,
        position = origin,
        velocity = vector3(
            projectileData.direction.x * projectileData.weaponData.projectileSpeed,
            projectileData.direction.y * projectileData.weaponData.projectileSpeed,
            projectileData.direction.z * projectileData.weaponData.projectileSpeed
        ),
        active = true
    }

    -- 발사체 업데이트 시작
    UpdateProjectile(projectileId)
end)

-- ========================================
-- 발사체 제거
-- ========================================
RegisterNetEvent('minigames:client:weapon:removeProjectile', function(projectileId)
    local projectile = Weapon.projectiles[projectileId]
    if projectile then
        if projectile.object and DoesEntityExist(projectile.object) then
            DeleteObject(projectile.object)
        end
        Weapon.projectiles[projectileId] = nil
    end
end)

-- ========================================
-- 모든 발사체 제거
-- ========================================
RegisterNetEvent('minigames:client:weapon:clearAllProjectiles', function()
    ClearAllProjectiles()
end)

function ClearAllProjectiles()
    for projectileId, projectile in pairs(Weapon.projectiles) do
        if projectile.object and DoesEntityExist(projectile.object) then
            DeleteObject(projectile.object)
        end
    end
    Weapon.projectiles = {}
end

-- ========================================
-- 발사체 업데이트
-- ========================================
function UpdateProjectile(projectileId)
    CreateThread(function()
        local maxLifetime = 10000 -- 10초
        local updateInterval = 16 -- ~60 FPS
        local gravityAccel = 9.8 -- m/s^2

        while Weapon.projectiles[projectileId] and Weapon.projectiles[projectileId].active do
            Wait(updateInterval)

            local projectile = Weapon.projectiles[projectileId]
            if not projectile or not projectile.active then break end

            local deltaTime = updateInterval / 1000.0 -- 초 단위

            -- 수명 체크
            local lifetime = GetGameTimer() - projectile.data.spawnTime
            if lifetime > maxLifetime then
                -- 발사체 제거
                if projectile.object and DoesEntityExist(projectile.object) then
                    DeleteObject(projectile.object)
                end
                Weapon.projectiles[projectileId] = nil
                break
            end

            -- 유도 미사일 처리
            if projectile.data.weaponData.homing and Weapon.currentTarget then
                local targetCoords = GetEntityCoords(Weapon.currentTarget.entity)
                local directionToTarget = targetCoords - projectile.position
                local distance = #directionToTarget

                if distance > 0 then
                    local normalizedDir = directionToTarget / distance
                    local homingSpeed = projectile.data.weaponData.homingSpeed or 5.0

                    -- 속도 방향을 타겟 방향으로 점진적으로 변경
                    local currentDir = projectile.velocity / #projectile.velocity
                    local newDir = currentDir + (normalizedDir * homingSpeed * deltaTime)
                    newDir = newDir / #newDir

                    projectile.velocity = newDir * projectile.data.weaponData.projectileSpeed
                end
            end

            -- 중력 적용
            if projectile.data.weaponData.hasGravity then
                projectile.velocity = projectile.velocity - vector3(0, 0, gravityAccel * deltaTime)
            end

            -- 위치 업데이트
            projectile.position = projectile.position + (projectile.velocity * deltaTime)

            -- 오브젝트 위치 업데이트
            if projectile.object and DoesEntityExist(projectile.object) then
                SetEntityCoords(projectile.object, projectile.position.x, projectile.position.y, projectile.position.z, false, false, false, false)

                -- 회전 설정 (속도 방향)
                local heading = GetHeadingFromVector_2d(projectile.velocity.x, projectile.velocity.y)
                local pitch = math.deg(math.atan2(projectile.velocity.z, math.sqrt(projectile.velocity.x^2 + projectile.velocity.y^2)))
                SetEntityRotation(projectile.object, pitch, 0.0, heading, 2, false)
            end

            -- 충돌 체크 (레이캐스트)
            local rayHandle = StartShapeTestRay(
                projectile.position.x, projectile.position.y, projectile.position.z,
                projectile.position.x + projectile.velocity.x * deltaTime,
                projectile.position.y + projectile.velocity.y * deltaTime,
                projectile.position.z + projectile.velocity.z * deltaTime,
                -1, -- 모든 것과 충돌
                0, 7
            )

            local _, hit, hitCoords, _, entityHit = GetShapeTestResult(rayHandle)

            if hit then
                -- 차량과 충돌 체크
                if IsEntityAVehicle(entityHit) then
                    -- 서버에 충돌 알림
                    TriggerServerEvent('minigames:server:weapon:projectileHit', projectileId, entityHit, hitCoords)

                    -- 폭발 이펙트
                    local explosionType = projectile.data.weaponData.explosionType or 0
                    if explosionType > 0 then
                        AddExplosion(hitCoords.x, hitCoords.y, hitCoords.z, explosionType,
                            projectile.data.weaponData.damage / 100.0, true, false, 0.5)
                    end
                else
                    -- 지형/오브젝트 충돌
                    local explosionType = projectile.data.weaponData.explosionType or 0
                    if explosionType > 0 then
                        AddExplosion(hitCoords.x, hitCoords.y, hitCoords.z, explosionType,
                            projectile.data.weaponData.damage / 200.0, true, false, 0.3)
                    end
                end

                -- 발사체 제거
                projectile.active = false
                if projectile.object and DoesEntityExist(projectile.object) then
                    DeleteObject(projectile.object)
                end
                Weapon.projectiles[projectileId] = nil
                break
            end
        end
    end)
end

-- ========================================
-- 차량 소유 확인
-- ========================================
RegisterNetEvent('minigames:client:weapon:checkVehicleOwnership', function(networkId, projectileId, damage)
    local vehicle = LocalPlayer.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if netId == networkId then
        -- 자신의 차량이 맞으면 서버에 확인
        TriggerServerEvent('minigames:server:weapon:confirmVehicleHit', projectileId, damage)
    end
end)

-- ========================================
-- 무기 픽업 체크
-- ========================================
function StartPickupCheck()
    if Weapon.pickupThread then return end

    Weapon.pickupThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "weapon" do
            Wait(100)

            local vehicle = LocalPlayer.vehicle
            if not vehicle or not DoesEntityExist(vehicle) then
                Wait(500)
                goto continue
            end

            local vehicleCoords = GetEntityCoords(vehicle)

            for weaponId, weaponData in pairs(Weapon.weaponPickups) do
                local distance = #(vehicleCoords - weaponData.coords)

                -- 근처에 있으면 습득
                if distance < 5.0 then
                    TriggerServerEvent('minigames:server:weapon:pickupWeapon', weaponId)
                end
            end

            ::continue::
        end

        Weapon.pickupThread = nil
    end)
end

-- ========================================
-- 렌더링 시작
-- ========================================
function StartRendering()
    if Weapon.renderThread then return end

    Weapon.renderThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "weapon" do
            Wait(0)

            local vehicle = LocalPlayer.vehicle
            if not vehicle or not DoesEntityExist(vehicle) then
                Wait(500)
                goto continue
            end

            local vehicleCoords = GetEntityCoords(vehicle)

            -- 무기 픽업 렌더링
            for weaponId, weaponData in pairs(Weapon.weaponPickups) do
                local distance = #(vehicleCoords - weaponData.coords)

                if distance < 200.0 then
                    -- 마커 그리기
                    DrawMarker(
                        2, -- 화살표
                        weaponData.coords.x, weaponData.coords.y, weaponData.coords.z + 1.5,
                        0.0, 0.0, 0.0,
                        0.0, 180.0, 0.0,
                        0.7, 0.7, 0.7,
                        255, 200, 0, 200,
                        true, true, 2, true, nil, nil, false
                    )

                    -- 3D 텍스트
                    if distance < 50.0 then
                        DrawText3D(weaponData.coords.x, weaponData.coords.y, weaponData.coords.z + 2.0,
                            weaponData.weapon.name)
                    end
                end
            end

            ::continue::
        end

        Weapon.renderThread = nil
    end)
end

-- ========================================
-- 3D 텍스트 그리기
-- ========================================
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)

    if onScreen then
        SetTextScale(0.4, 0.4)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 200, 0, 255)
        SetTextEntry("STRING")
        SetTextCentre(1)
        SetTextOutline()
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- ========================================
-- HUD 표시
-- ========================================
CreateThread(function()
    while true do
        Wait(0)

        if CurrentRound.state == GameModes.States.PLAYING and
           CurrentRound.gamemode and CurrentRound.gamemode.id == "weapon" and
           Weapon.currentWeapon then

            -- 무기 정보 표시
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.45, 0.45)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")

            -- 무기 이름
            local weaponText = "무기: " .. Weapon.currentWeapon.name
            AddTextComponentString(weaponText)
            DrawText(0.82, 0.90)

            -- 탄약
            SetTextEntry("STRING")
            local ammoText
            if Weapon.isReloading then
                -- 재장전 진행률 계산
                local elapsed = GetGameTimer() - Weapon.reloadStartTime
                local progress = math.min(elapsed / Weapon.reloadDuration, 1.0)
                local percentage = math.floor(progress * 100)
                ammoText = "재장전 중... " .. percentage .. "%"
                SetTextColour(255, 200, 0, 255)
            else
                ammoText = "탄약: " .. Weapon.currentAmmo .. " / " .. Weapon.currentWeapon.maxAmmo

                -- 탄약 부족 시 빨간색
                if Weapon.currentAmmo == 0 then
                    SetTextColour(255, 0, 0, 255)
                elseif Weapon.currentAmmo < Weapon.currentWeapon.maxAmmo * 0.3 then
                    SetTextColour(255, 150, 0, 255)
                else
                    SetTextColour(255, 255, 255, 255)
                end
            end

            AddTextComponentString(ammoText)
            DrawText(0.82, 0.93)

            -- 재장전 진행 바
            if Weapon.isReloading then
                local elapsed = GetGameTimer() - Weapon.reloadStartTime
                local progress = math.min(elapsed / Weapon.reloadDuration, 1.0)

                -- 배경
                DrawRect(0.88, 0.96, 0.12, 0.02, 0, 0, 0, 150)
                -- 진행 바
                DrawRect(0.82 + (0.06 * progress), 0.96, 0.12 * progress, 0.02, 255, 200, 0, 255)
            end
        else
            Wait(500)
        end
    end
end)

-- ========================================
-- 정리
-- ========================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- 무기 프롭 제거
    RemoveWeaponProp()

    -- 픽업 오브젝트 제거
    ClearPickupObjects()

    -- 발사체 제거
    ClearAllProjectiles()
end)

Utils.Info('Weapon gamemode (client) loaded')
