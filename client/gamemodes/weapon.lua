-- ========================================
-- WEAPON GAMEMODE - CLIENT
-- ========================================

local Weapon = {
    currentWeapon = nil,
    currentAmmo = 0,
    isReloading = false,
    weaponObject = nil,
    weaponPickups = {},
    projectiles = {},
    targetingThread = nil,
    currentTarget = nil,
    renderThread = nil,
    shootingThread = nil,
    lastShotTime = 0
}

-- 게임모드 초기화
RegisterNetEvent('minigames:client:gamemode:initialize', function(gamemodeId, map)
    if gamemodeId ~= "weapon" then return end

    Utils.Info('Weapon: Initializing')

    -- 타겟팅 시스템 시작
    StartTargeting()

    -- 렌더링 시작
    StartRendering()

    -- 발사 시스템 시작
    StartShooting()
end)

-- 무기 장착
RegisterNetEvent('minigames:client:equipWeapon', function(weapon)
    Weapon.currentWeapon = weapon
    Weapon.currentAmmo = weapon.ammo
    Weapon.isReloading = false

    -- 무기 오브젝트 생성
    CreateWeaponObject(weapon)

    -- HUD 업데이트
    UpdateWeaponHUD()

    Utils.Info('Equipped weapon: ' .. weapon.name)
end)

-- 무기 제거
RegisterNetEvent('minigames:client:removeWeapon', function()
    RemoveWeaponObject()

    Weapon.currentWeapon = nil
    Weapon.currentAmmo = 0
    Weapon.isReloading = false

    UpdateWeaponHUD()
end)

-- 무기 오브젝트 생성
function CreateWeaponObject(weapon)
    -- 기존 오브젝트 제거
    RemoveWeaponObject()

    local vehicle = LocalPlayer.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end

    -- 무기 모델 로드
    local weaponModel = GetHashKey(weapon.model)

    RequestModel(weaponModel)
    local timeout = 0
    while not HasModelLoaded(weaponModel) and timeout < 3000 do
        Wait(100)
        timeout = timeout + 100
    end

    if not HasModelLoaded(weaponModel) then
        Utils.Error('Failed to load weapon model: ' .. weapon.model)
        return
    end

    -- 차량 위에 무기 생성
    local vehicleCoords = GetEntityCoords(vehicle)
    Weapon.weaponObject = CreateObject(weaponModel, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0,
        false, false, false)

    -- 차량에 부착 (offset 적용)
    local offset = weapon.offset or vector3(0.0, 2.0, 0.5)
    AttachEntityToEntity(Weapon.weaponObject, vehicle, 0,
        offset.x, offset.y, offset.z,
        0.0, 0.0, 0.0,
        false, false, false, false, 0, true)

    SetModelAsNoLongerNeeded(weaponModel)

    Utils.Debug('Weapon object created')
end

-- 무기 오브젝트 제거
function RemoveWeaponObject()
    if Weapon.weaponObject and DoesEntityExist(Weapon.weaponObject) then
        DeleteObject(Weapon.weaponObject)
        Weapon.weaponObject = nil

        Utils.Debug('Weapon object removed')
    end
end

-- 무기 픽업 스폰
RegisterNetEvent('minigames:client:spawnWeaponPickup', function(weaponId, coords, weapon)
    Weapon.weaponPickups[weaponId] = {
        id = weaponId,
        coords = coords,
        name = weapon.name,
        weapon = weapon
    }
end)

-- 무기 픽업 제거
RegisterNetEvent('minigames:client:removeWeaponPickup', function(weaponId)
    Weapon.weaponPickups[weaponId] = nil
end)

-- 무기 픽업 전체 제거
RegisterNetEvent('minigames:client:clearWeaponPickups', function()
    Weapon.weaponPickups = {}
end)

-- 탄약 업데이트
RegisterNetEvent('minigames:client:updateAmmo', function(ammo)
    Weapon.currentAmmo = ammo
    UpdateWeaponHUD()
end)

-- 재장전 시작
RegisterNetEvent('minigames:client:startReload', function(reloadTime)
    Weapon.isReloading = true

    -- 재장전 애니메이션/사운드
    PlaySoundFrontend(-1, "WEAPON_PURCHASE", "HUD_AMMO_SHOP_SOUNDSET", true)

    -- 재장전 완료 후 상태 업데이트
    SetTimeout(reloadTime * 1000, function()
        Weapon.isReloading = false
        UpdateWeaponHUD()
    end)

    UpdateWeaponHUD()
end)

-- 타겟팅 시스템 시작
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
                local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z,
                    destination.x, destination.y, destination.z,
                    10, -- 차량만
                    PlayerPedId(), 0)

                local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

                if hit and entityHit and IsEntityAVehicle(entityHit) then
                    local targetPed = GetPedInVehicleSeat(entityHit, -1)

                    if targetPed and IsPedAPlayer(targetPed) and targetPed ~= PlayerPedId() then
                        Weapon.currentTarget = {
                            entity = entityHit,
                            playerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(targetPed))
                        }

                        -- 조준점 그리기
                        DrawTargetMarker(entityHit)
                    else
                        Weapon.currentTarget = nil
                    end
                else
                    Weapon.currentTarget = nil
                end

                -- 일반 조준점 그리기
                DrawCrosshair()
            else
                Wait(500)
            end
        end

        Weapon.targetingThread = nil
        Weapon.currentTarget = nil
    end)
end

-- 타겟 마커 그리기
function DrawTargetMarker(entity)
    local coords = GetEntityCoords(entity)

    -- 3D 마커
    DrawMarker(
        0, -- 마커 타입
        coords.x, coords.y, coords.z + 2.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        2.0, 2.0, 2.0,
        255, 0, 0, 150,
        false, true, 2, false, nil, nil, false
    )
end

-- 조준점 그리기
function DrawCrosshair()
    local screenX, screenY = 0.5, 0.5

    -- 십자 조준선
    DrawRect(screenX, screenY, 0.002, 0.025, 255, 255, 255, 255)
    DrawRect(screenX, screenY, 0.025, 0.002, 255, 255, 255, 255)

    -- 원형 조준선
    -- DrawSprite 등을 사용할 수도 있음
end

-- 회전을 방향 벡터로 변환
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

-- 발사 시스템 시작
function StartShooting()
    if Weapon.shootingThread then return end

    Weapon.shootingThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "weapon" do
            Wait(0)

            if Weapon.currentWeapon and not Weapon.isReloading then
                -- 좌클릭으로 발사
                if IsControlPressed(0, 24) then -- Left Mouse Button
                    local currentTime = GetGameTimer()
                    local fireInterval = 1000 / (Weapon.currentWeapon.fireRate or 1.0)

                    if currentTime - Weapon.lastShotTime >= fireInterval then
                        FireWeapon()
                        Weapon.lastShotTime = currentTime
                    end
                end

                -- R키로 재장전
                if IsControlJustPressed(0, 45) then -- R
                    TriggerServerEvent('minigames:server:reloadWeapon')
                end
            else
                Wait(100)
            end
        end

        Weapon.shootingThread = nil
    end)
end

-- 무기 발사
function FireWeapon()
    if Weapon.currentAmmo <= 0 then
        TriggerEvent('minigames:client:notify', '탄약이 부족합니다! [R]키로 재장전하세요.', 'warning')
        return
    end

    local vehicle = LocalPlayer.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end

    -- 발사 위치 (무기 오브젝트 위치)
    local origin = Weapon.weaponObject and DoesEntityExist(Weapon.weaponObject) and
        GetEntityCoords(Weapon.weaponObject) or GetEntityCoords(vehicle)

    -- 발사 방향 (카메라 방향)
    local camRot = GetGameplayCamRot(0)
    local direction = RotationToDirection(camRot)

    -- 유도 미사일 체크
    local homing = Weapon.currentWeapon.homing or false
    local targetId = Weapon.currentTarget and Weapon.currentTarget.playerId or nil

    -- 서버에 발사 요청
    TriggerServerEvent('minigames:server:fireWeapon', origin, direction, Weapon.currentWeapon, homing, targetId)

    -- 발사 이펙트
    PlayFireEffect(origin, direction)

    -- 사운드
    PlaySoundFrontend(-1, "WEAPON_FIRE", "HUD_AMMO_SHOP_SOUNDSET", true)

    Utils.Debug('Fired weapon')
end

-- 발사 이펙트
function PlayFireEffect(origin, direction)
    -- 총구 화염
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do
        Wait(1)
    end

    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("muz_railgun", origin.x, origin.y, origin.z,
        0.0, 0.0, 0.0, 0.5, false, false, false)
end

-- 발사체 생성
RegisterNetEvent('minigames:client:createProjectile', function(projectileId, projectileData)
    Weapon.projectiles[projectileId] = projectileData

    -- 발사체 업데이트 시작
    UpdateProjectileClient(projectileId)
end)

-- 발사체 제거
RegisterNetEvent('minigames:client:removeProjectile', function(projectileId)
    Weapon.projectiles[projectileId] = nil
end)

-- 발사체 클라이언트 업데이트
function UpdateProjectileClient(projectileId)
    CreateThread(function()
        local updateInterval = 50
        local currentPos = Weapon.projectiles[projectileId].origin

        while Weapon.projectiles[projectileId] do
            Wait(updateInterval)

            local projectile = Weapon.projectiles[projectileId]
            if not projectile then break end

            -- 위치 업데이트
            local moveDistance = projectile.speed * (updateInterval / 1000)
            currentPos = vector3(
                currentPos.x + projectile.direction.x * moveDistance,
                currentPos.y + projectile.direction.y * moveDistance,
                currentPos.z + projectile.direction.z * moveDistance
            )

            -- 유도 미사일 처리
            if projectile.homing and projectile.targetId then
                local targetPed = GetPlayerPed(GetPlayerFromServerId(projectile.targetId))
                if targetPed and DoesEntityExist(targetPed) then
                    local targetCoords = GetEntityCoords(targetPed)
                    local directionToTarget = vector3(
                        targetCoords.x - currentPos.x,
                        targetCoords.y - currentPos.y,
                        targetCoords.z - currentPos.z
                    )

                    local length = #directionToTarget
                    if length > 0 then
                        projectile.direction = vector3(
                            directionToTarget.x / length,
                            directionToTarget.y / length,
                            directionToTarget.z / length
                        )
                    end
                end
            end

            -- 충돌 체크
            local vehicle = LocalPlayer.vehicle
            if vehicle and DoesEntityExist(vehicle) then
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(currentPos - vehicleCoords)

                if distance < 2.0 and projectile.owner ~= GetPlayerServerId(PlayerId()) then
                    -- 충돌!
                    TriggerServerEvent('minigames:server:projectileHit', projectileId,
                        GetPlayerServerId(PlayerId()))

                    -- 폭발 이펙트
                    AddExplosion(currentPos.x, currentPos.y, currentPos.z, 2, 0.0, true, false, 0.5)

                    break
                end
            end

            -- 발사체 렌더링
            DrawMarker(
                28, -- 폭발 마커
                currentPos.x, currentPos.y, currentPos.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                0.5, 0.5, 0.5,
                255, 100, 0, 200,
                false, true, 2, false, nil, nil, false
            )
        end
    end)
end

-- 렌더링 시작
function StartRendering()
    if Weapon.renderThread then return end

    Weapon.renderThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "weapon" do
            Wait(0)

            -- 무기 픽업 렌더링
            local playerCoords = GetEntityCoords(PlayerPedId())

            for weaponId, weaponData in pairs(Weapon.weaponPickups) do
                local distance = #(playerCoords - weaponData.coords)

                if distance < 100.0 then
                    -- 마커 그리기
                    DrawMarker(
                        2, -- 화살표
                        weaponData.coords.x, weaponData.coords.y, weaponData.coords.z + 1.0,
                        0.0, 0.0, 0.0,
                        0.0, 180.0, 0.0,
                        0.5, 0.5, 0.5,
                        255, 200, 0, 200,
                        true, true, 2, false, nil, nil, false
                    )

                    -- 3D 텍스트
                    if distance < 30.0 then
                        DrawText3D(weaponData.coords.x, weaponData.coords.y, weaponData.coords.z + 1.5,
                            weaponData.name)
                    end

                    -- 근처에 있으면 습득
                    if distance < 3.0 and LocalPlayer.vehicle and DoesEntityExist(LocalPlayer.vehicle) then
                        TriggerServerEvent('minigames:server:pickupWeapon', weaponId)
                    end
                end
            end
        end

        Weapon.renderThread = nil
    end)
end

-- 3D 텍스트 그리기
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)

    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 200, 0, 255)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)

        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- 무기 HUD 업데이트
function UpdateWeaponHUD()
    SendNUIMessage({
        action = "updateWeaponHUD",
        weapon = Weapon.currentWeapon,
        ammo = Weapon.currentAmmo,
        isReloading = Weapon.isReloading
    })
end

-- HUD 표시
CreateThread(function()
    while true do
        Wait(0)

        if CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode and
           CurrentRound.gamemode.id == "weapon" and Weapon.currentWeapon then

            -- 무기 정보 표시
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.4, 0.4)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")

            local weaponText = Weapon.currentWeapon.name
            local ammoText = Weapon.isReloading and "재장전 중..." or
                ("탄약: " .. Weapon.currentAmmo .. " / " .. Weapon.currentWeapon.ammo)

            AddTextComponentString(weaponText)
            DrawText(0.85, 0.92)

            SetTextEntry("STRING")
            AddTextComponentString(ammoText)
            DrawText(0.85, 0.95)
        else
            Wait(500)
        end
    end
end)

-- 정리
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- 무기 오브젝트 제거
    RemoveWeaponObject()
end)

Utils.Info('Weapon gamemode (client) loaded')
