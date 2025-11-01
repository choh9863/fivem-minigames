-- ========================================
-- BUMPER CAR GAMEMODE - CLIENT
-- ========================================

local BumperCar = {
    collisionCheckThread = nil,
    targetingThread = nil,
    currentTarget = nil,
    lastCollisionTime = 0,
    nearbyItems = {}
}

-- 게임모드 초기화
RegisterNetEvent('minigames:client:gamemode:initialize', function(gamemodeId, map)
    if gamemodeId ~= "bumpercar" then return end

    Utils.Info('Bumper Car: Initializing')

    -- 충돌 감지 시작
    StartCollisionDetection()

    -- 타겟팅 시스템 시작 (유도 미사일용)
    StartTargeting()
end)

-- 충돌 감지 시작
function StartCollisionDetection()
    if BumperCar.collisionCheckThread then return end

    BumperCar.collisionCheckThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "bumpercar" do
            Wait(100)

            local vehicle = LocalPlayer.vehicle
            if vehicle and DoesEntityExist(vehicle) then
                -- 차량 충돌 체크
                if HasEntityCollidedWithAnything(vehicle) then
                    local currentTime = GetGameTimer()

                    -- 쿨다운 체크 (0.5초)
                    if currentTime - BumperCar.lastCollisionTime > 500 then
                        BumperCar.lastCollisionTime = currentTime

                        -- 충돌 속도 계산
                        local speed = GetEntitySpeed(vehicle) * 3.6 -- m/s to km/h

                        if speed > 10.0 then
                            -- 충돌한 엔티티 찾기
                            local collisionEntity = GetLastEntityHitByVehicle(vehicle)

                            if collisionEntity and IsEntityAVehicle(collisionEntity) then
                                -- 다른 플레이어 차량과 충돌
                                local otherPed = GetPedInVehicleSeat(collisionEntity, -1)

                                if otherPed and IsPedAPlayer(otherPed) then
                                    local otherPlayer = NetworkGetPlayerIndexFromPed(otherPed)
                                    local otherPlayerId = GetPlayerServerId(otherPlayer)

                                    -- 데미지 계산
                                    local vehicleData = GetVehicleData()
                                    local baseDamage = vehicleData.vehicleStats and vehicleData.vehicleStats.damage or 50

                                    local damage = baseDamage * (speed / 100)

                                    -- 데미지 버프 적용
                                    if vehicleData.effects.damageBoost then
                                        damage = damage * vehicleData.effects.damageBoost.multiplier
                                    end

                                    -- 서버에 충돌 데미지 전송
                                    TriggerServerEvent('minigames:server:collisionDamage', otherPlayerId, damage)

                                    Utils.Debug('Collision damage: ' .. damage .. ' to player ' .. otherPlayerId)
                                end
                            end
                        end
                    end
                end
            end
        end

        BumperCar.collisionCheckThread = nil
    end)
end

-- 타겟팅 시스템 시작
function StartTargeting()
    if BumperCar.targetingThread then return end

    BumperCar.targetingThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "bumpercar" do
            Wait(0)

            local vehicle = LocalPlayer.vehicle

            if vehicle and DoesEntityExist(vehicle) then
                -- 유도 미사일 아이템이 있는지 체크
                local hasHomingMissile = false
                local vehicleData = GetVehicleData()

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
                        BumperCar.currentTarget = entityHit

                        -- 조준점 그리기
                        DrawTargetMarker(entityHit)
                    else
                        BumperCar.currentTarget = nil
                    end
                else
                    BumperCar.currentTarget = nil
                end
            else
                Wait(500)
            end
        end

        BumperCar.targetingThread = nil
        BumperCar.currentTarget = nil
    end)
end

-- 타겟 마커 그리기
function DrawTargetMarker(entity)
    local coords = GetEntityCoords(entity)

    -- 3D 마커
    DrawMarker(
        0, -- 마커 타입 (원형)
        coords.x, coords.y, coords.z + 2.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        2.0, 2.0, 2.0,
        255, 0, 0, 150,
        false, true, 2, false, nil, nil, false
    )

    -- 2D 조준점
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z + 1.0)

    if onScreen then
        -- 십자 조준선
        DrawRect(_x, _y, 0.002, 0.03, 255, 0, 0, 255)
        DrawRect(_x, _y, 0.03, 0.002, 255, 0, 0, 255)
    end
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

-- 경계 체크
RegisterNetEvent('minigames:client:checkBoundary', function(center, radius)
    local vehicle = LocalPlayer.vehicle

    if not vehicle or not DoesEntityExist(vehicle) then return end

    local vehicleCoords = GetEntityCoords(vehicle)
    local distance = Utils.GetDistance2D(vehicleCoords, center)

    if distance > radius then
        -- 경계 밖으로 나감 - 차량 폭파
        ExplodeVehicle(vehicle, true, false)
        TriggerServerEvent('minigames:server:playerDied')

        TriggerEvent('minigames:client:notify', '경계를 벗어났습니다!', 'error')

        Utils.Debug('Player went out of bounds')
    end
end)

-- 차량 변경
RegisterNetEvent('minigames:client:changeVehicle', function(vehicleData)
    local currentVehicle = LocalPlayer.vehicle

    if not currentVehicle or not DoesEntityExist(currentVehicle) then return end

    -- 현재 위치와 방향 저장
    local coords = GetEntityCoords(currentVehicle)
    local heading = GetEntityHeading(currentVehicle)
    local velocity = GetEntityVelocity(currentVehicle)

    -- 기존 차량 제거
    DeleteVehicle(currentVehicle)

    -- 새 차량 생성
    Wait(100)
    SpawnVehicle(vehicleData.model, coords, heading, vehicleData)

    -- 속도 복원
    Wait(100)
    if LocalPlayer.vehicle and DoesEntityExist(LocalPlayer.vehicle) then
        SetEntityVelocity(LocalPlayer.vehicle, velocity.x, velocity.y, velocity.z)
    end
end)

-- 아이템 스폰
RegisterNetEvent('minigames:client:spawnItem', function(itemId, coords, item)
    BumperCar.nearbyItems[itemId] = {
        id = itemId,
        coords = coords,
        name = item.name,
        item = item
    }
end)

-- 아이템 제거
RegisterNetEvent('minigames:client:removeItem', function(itemId)
    BumperCar.nearbyItems[itemId] = nil
end)

-- 아이템 전체 제거
RegisterNetEvent('minigames:client:clearItems', function()
    BumperCar.nearbyItems = {}
end)

-- 아이템 렌더링
CreateThread(function()
    while true do
        Wait(0)

        if CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode and CurrentRound.gamemode.id == "bumpercar" then
            local playerCoords = GetEntityCoords(PlayerPedId())

            for itemId, itemData in pairs(BumperCar.nearbyItems) do
                local distance = #(playerCoords - itemData.coords)

                if distance < 100.0 then
                    -- 마커 그리기
                    DrawMarker(
                        1, -- 원통형
                        itemData.coords.x, itemData.coords.y, itemData.coords.z - 0.5,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        1.5, 1.5, 1.0,
                        0, 217, 255, 200,
                        true, true, 2, false, nil, nil, false
                    )

                    -- 3D 텍스트
                    if distance < 30.0 then
                        DrawText3D(itemData.coords.x, itemData.coords.y, itemData.coords.z + 1.0, itemData.name)
                    end

                    -- 근처에 있으면 습득
                    if distance < 3.0 and LocalPlayer.vehicle and DoesEntityExist(LocalPlayer.vehicle) then
                        TriggerServerEvent('minigames:server:pickupItem', itemId)
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

-- 3D 텍스트 그리기
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)

    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)

        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- 플레이어 위치 표시 (서든 데스)
RegisterNetEvent('minigames:client:showPlayerPositions', function(playerIds)
    -- HUD 업데이트 또는 미니맵 블립 표시
    -- 간단한 구현으로 생략 (실제로는 블립 생성)
end)

-- HUD 업데이트 루프
CreateThread(function()
    while true do
        Wait(100)

        if CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode and CurrentRound.gamemode.id == "bumpercar" then
            local vehicle = LocalPlayer.vehicle

            if vehicle and DoesEntityExist(vehicle) then
                local health = GetVehicleEngineHealth(vehicle)
                local speed = GetEntitySpeed(vehicle) * 3.6 -- km/h

                -- HUD 업데이트 (NUI로 전송)
                SendNUIMessage({
                    action = "updateVehicleHUD",
                    health = health,
                    maxHealth = 1000,
                    speed = math.floor(speed)
                })
            end
        else
            Wait(500)
        end
    end
end)

Utils.Info('Bumper Car gamemode (client) loaded')
