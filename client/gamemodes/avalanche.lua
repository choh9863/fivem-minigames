-- ========================================
-- AVALANCHE GAMEMODE - CLIENT
-- ========================================

local Avalanche = {
    avalancheVehicles = {},
    collisionCheckThread = nil,
    finishLineBlip = nil,
    renderThread = nil
}

-- 게임모드 초기화
RegisterNetEvent('minigames:client:gamemode:initialize', function(gamemodeId, map)
    if gamemodeId ~= "avalanche" then return end

    Utils.Info('Avalanche: Initializing')

    -- 골인 지점 블립 생성
    if map.finishLine then
        CreateFinishLineBlip(map.finishLine)
    end

    -- 충돌 감지 시작
    StartCollisionDetection()

    -- 렌더링 시작
    StartRendering()
end)

-- 골인 지점 블립 생성
function CreateFinishLineBlip(coords)
    -- 기존 블립 제거
    if Avalanche.finishLineBlip then
        RemoveBlip(Avalanche.finishLineBlip)
    end

    -- 블립 생성
    Avalanche.finishLineBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(Avalanche.finishLineBlip, 38) -- 깃발 아이콘
    SetBlipColour(Avalanche.finishLineBlip, 2) -- 초록색
    SetBlipScale(Avalanche.finishLineBlip, 1.5)
    SetBlipAsShortRange(Avalanche.finishLineBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("골인 지점")
    EndTextCommandSetBlipName(Avalanche.finishLineBlip)

    Utils.Debug('Finish line blip created')
end

-- 아발란체 차량 스폰
RegisterNetEvent('minigames:client:spawnAvalancheVehicle', function(vehicleId, model, coords)
    -- 모델 로드
    local modelHash = type(model) == "string" and GetHashKey(model) or model

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 3000 do
        Wait(100)
        timeout = timeout + 100
    end

    if not HasModelLoaded(modelHash) then
        Utils.Error('Failed to load avalanche vehicle model: ' .. model)
        return
    end

    -- 차량 생성
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, 0.0, true, false)

    -- 차량 설정
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleOnGroundProperly(vehicle)

    -- 낙하 속도 적용 (중력 + 초기 속도)
    local speed = Config.Avalanche.VehicleSpeed or 50.0
    SetVehicleForwardSpeed(vehicle, speed)

    -- 차량 데이터 저장
    Avalanche.avalancheVehicles[vehicleId] = {
        id = vehicleId,
        vehicle = vehicle,
        model = model,
        spawnTime = GetGameTimer()
    }

    -- 모델 해제
    SetModelAsNoLongerNeeded(modelHash)

    Utils.Debug('Spawned avalanche vehicle: ' .. vehicleId)
end)

-- 아발란체 차량 제거
RegisterNetEvent('minigames:client:deleteAvalancheVehicle', function(vehicleId)
    local vehicleData = Avalanche.avalancheVehicles[vehicleId]

    if vehicleData and DoesEntityExist(vehicleData.vehicle) then
        DeleteVehicle(vehicleData.vehicle)
        Avalanche.avalancheVehicles[vehicleId] = nil

        Utils.Debug('Deleted avalanche vehicle: ' .. vehicleId)
    end
end)

-- 충돌 감지 시작
function StartCollisionDetection()
    if Avalanche.collisionCheckThread then return end

    Avalanche.collisionCheckThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "avalanche" do
            Wait(100)

            local vehicle = LocalPlayer.vehicle

            if vehicle and DoesEntityExist(vehicle) then
                -- 아발란체 차량과의 충돌 체크
                for vehicleId, vehicleData in pairs(Avalanche.avalancheVehicles) do
                    if DoesEntityExist(vehicleData.vehicle) then
                        -- 거리 체크
                        local playerCoords = GetEntityCoords(vehicle)
                        local avalancheCoords = GetEntityCoords(vehicleData.vehicle)
                        local distance = #(playerCoords - avalancheCoords)

                        -- 충돌 감지 (2m 이내)
                        if distance < 2.0 then
                            -- 플레이어 사망 처리
                            ExplodeVehicle(vehicle, true, false)
                            TriggerServerEvent('minigames:server:playerDied')

                            TriggerEvent('minigames:client:notify', '아발란체 차량에 충돌했습니다!', 'error')

                            Utils.Debug('Collision with avalanche vehicle!')

                            break
                        end
                    end
                end
            end
        end

        Avalanche.collisionCheckThread = nil
    end)
end

-- 골인 체크
RegisterNetEvent('minigames:client:checkFinishLine', function(finishLine, radius)
    local vehicle = LocalPlayer.vehicle

    if not vehicle or not DoesEntityExist(vehicle) then return end

    local vehicleCoords = GetEntityCoords(vehicle)
    local distance = #(vehicleCoords - finishLine)

    if distance < radius then
        -- 골인!
        TriggerServerEvent('minigames:server:playerFinished')

        TriggerEvent('minigames:client:notify', '골인! 축하합니다!', 'success')

        Utils.Info('Finished the race!')
    end
end)

-- 렌더링 시작
function StartRendering()
    if Avalanche.renderThread then return end

    Avalanche.renderThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "avalanche" do
            Wait(0)

            -- 골인 지점 마커 그리기
            if CurrentRound.map and CurrentRound.map.finishLine then
                local finishLine = CurrentRound.map.finishLine

                DrawMarker(
                    1, -- 원통형
                    finishLine.x, finishLine.y, finishLine.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    20.0, 20.0, 2.0,
                    0, 255, 0, 150,
                    false, true, 2, false, nil, nil, false
                )

                -- 3D 텍스트
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - finishLine)

                if distance < 100.0 then
                    DrawText3D(finishLine.x, finishLine.y, finishLine.z + 2.0, "골인 지점")
                end
            end

            -- 아발란체 차량 경고 표시
            local playerCoords = GetEntityCoords(PlayerPedId())

            for vehicleId, vehicleData in pairs(Avalanche.avalancheVehicles) do
                if DoesEntityExist(vehicleData.vehicle) then
                    local avalancheCoords = GetEntityCoords(vehicleData.vehicle)
                    local distance = #(playerCoords - avalancheCoords)

                    -- 가까이 있으면 경고 마커
                    if distance < 30.0 then
                        DrawMarker(
                            28, -- 위험 표시
                            avalancheCoords.x, avalancheCoords.y, avalancheCoords.z + 2.0,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            2.0, 2.0, 2.0,
                            255, 0, 0, 150,
                            false, true, 2, false, nil, nil, false
                        )
                    end
                end
            end
        end

        Avalanche.renderThread = nil
    end)
end

-- 3D 텍스트 그리기
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)

    if onScreen then
        SetTextScale(0.5, 0.5)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(0, 255, 0, 255)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)

        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- HUD 업데이트 루프
CreateThread(function()
    while true do
        Wait(100)

        if CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode and
           CurrentRound.gamemode.id == "avalanche" then

            local vehicle = LocalPlayer.vehicle

            if vehicle and DoesEntityExist(vehicle) then
                local speed = GetEntitySpeed(vehicle) * 3.6 -- km/h

                -- 골인 지점까지 거리
                local distance = 0
                if CurrentRound.map and CurrentRound.map.finishLine then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    distance = #(vehicleCoords - CurrentRound.map.finishLine)
                end

                -- HUD 업데이트
                SendNUIMessage({
                    action = "updateAvalancheHUD",
                    speed = math.floor(speed),
                    distanceToFinish = math.floor(distance)
                })
            end
        else
            Wait(500)
        end
    end
end)

-- 정리
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- 블립 제거
    if Avalanche.finishLineBlip then
        RemoveBlip(Avalanche.finishLineBlip)
    end

    -- 아발란체 차량 모두 제거
    for vehicleId, vehicleData in pairs(Avalanche.avalancheVehicles) do
        if DoesEntityExist(vehicleData.vehicle) then
            DeleteVehicle(vehicleData.vehicle)
        end
    end
end)

Utils.Info('Avalanche gamemode (client) loaded')
