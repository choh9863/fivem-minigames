-- ========================================
-- BOSS GAMEMODE - CLIENT
-- ========================================

local Boss = {
    bossPlayerId = nil,
    bossName = "",
    isBoss = false,
    bossBlip = nil,
    collisionCheckThread = nil,
    lastCollisionTime = 0,
    renderThread = nil
}

-- 게임모드 초기화
RegisterNetEvent('minigames:client:gamemode:initialize', function(gamemodeId, map)
    if gamemodeId ~= "boss" then return end

    Utils.Info('Boss: Initializing')

    -- 충돌 감지 시작
    StartCollisionDetection()

    -- 렌더링 시작
    StartRendering()
end)

-- 보스 선택 알림
RegisterNetEvent('minigames:client:bossSelected', function(bossPlayerId, bossName)
    Boss.bossPlayerId = bossPlayerId
    Boss.bossName = bossName
    Boss.isBoss = (bossPlayerId == GetPlayerServerId(PlayerId()))

    if Boss.isBoss then
        TriggerEvent('minigames:client:notify', '당신이 보스입니다! 모든 플레이어를 제거하세요!', 'warning')
        Utils.Info('You are the BOSS!')
    else
        TriggerEvent('minigames:client:notify', bossName .. ' 님이 보스입니다! 생존하세요!', 'info')

        -- 보스 블립 생성
        CreateBossBlip(bossPlayerId)
    end

    -- HUD 업데이트
    UpdateBossHUD()
end)

-- 보스 블립 생성
function CreateBossBlip(playerId)
    -- 기존 블립 제거
    if Boss.bossBlip then
        RemoveBlip(Boss.bossBlip)
    end

    local playerPed = GetPlayerPed(GetPlayerFromServerId(playerId))
    if not playerPed or not DoesEntityExist(playerPed) then return end

    -- 블립 생성
    Boss.bossBlip = AddBlipForEntity(playerPed)
    SetBlipSprite(Boss.bossBlip, 303) -- 해골 아이콘
    SetBlipColour(Boss.bossBlip, 1) -- 빨간색
    SetBlipScale(Boss.bossBlip, 1.5)
    SetBlipAsShortRange(Boss.bossBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("보스")
    EndTextCommandSetBlipName(Boss.bossBlip)

    Utils.Debug('Boss blip created for player ' .. playerId)
end

-- 충돌 감지 시작
function StartCollisionDetection()
    if Boss.collisionCheckThread then return end

    Boss.collisionCheckThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "boss" do
            Wait(100)

            local vehicle = LocalPlayer.vehicle

            if vehicle and DoesEntityExist(vehicle) and Boss.isBoss then
                -- 보스가 다른 플레이어와 충돌했는지 체크
                if HasEntityCollidedWithAnything(vehicle) then
                    local currentTime = GetGameTimer()

                    -- 쿨다운 체크 (0.5초)
                    if currentTime - Boss.lastCollisionTime > 500 then
                        -- 충돌한 엔티티 찾기
                        local collisionEntity = GetLastEntityHitByVehicle(vehicle)

                        if collisionEntity and IsEntityAVehicle(collisionEntity) then
                            -- 다른 플레이어 차량과 충돌
                            local otherPed = GetPedInVehicleSeat(collisionEntity, -1)

                            if otherPed and IsPedAPlayer(otherPed) and otherPed ~= PlayerPedId() then
                                local otherPlayer = NetworkGetPlayerIndexFromPed(otherPed)
                                local otherPlayerId = GetPlayerServerId(otherPlayer)

                                -- 서버에 보스 충돌 알림
                                TriggerServerEvent('minigames:server:bossCollision', otherPlayerId)

                                Boss.lastCollisionTime = currentTime

                                Utils.Debug('Boss collision with player ' .. otherPlayerId)
                            end
                        end
                    end
                end
            end
        end

        Boss.collisionCheckThread = nil
    end)
end

-- 차량 폭파
RegisterNetEvent('minigames:client:explodeVehicle', function()
    local vehicle = LocalPlayer.vehicle

    if vehicle and DoesEntityExist(vehicle) then
        ExplodeVehicle(vehicle, true, false)
    end
end)

-- 렌더링 시작
function StartRendering()
    if Boss.renderThread then return end

    Boss.renderThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "boss" do
            Wait(0)

            -- 보스 플레이어 위에 표시
            if Boss.bossPlayerId then
                local bossPlayer = GetPlayerFromServerId(Boss.bossPlayerId)

                if bossPlayer and bossPlayer ~= -1 then
                    local bossPed = GetPlayerPed(bossPlayer)

                    if bossPed and DoesEntityExist(bossPed) then
                        local bossCoords = GetEntityCoords(bossPed)

                        -- 보스 마커
                        DrawMarker(
                            0, -- 원형
                            bossCoords.x, bossCoords.y, bossCoords.z + 3.0,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            2.0, 2.0, 2.0,
                            255, 0, 0, 200,
                            false, true, 2, false, nil, nil, false
                        )

                        -- 3D 텍스트 (NUI 사용)
                        local playerCoords = GetEntityCoords(PlayerPedId())
                        local distance = #(playerCoords - bossCoords)

                        if distance < 50.0 and not Boss.isBoss then
                            ShowText3D(
                                vector3(bossCoords.x, bossCoords.y, bossCoords.z + 2.5),
                                "[ 보스 ]",
                                { id = 'boss-marker', style = 'boss-marker' }
                            )
                        end
                    end
                end
            end

            -- 보스 차량 특수 이펙트 (파티클 등)
            if Boss.isBoss then
                local vehicle = LocalPlayer.vehicle

                if vehicle and DoesEntityExist(vehicle) then
                    -- 보스 차량에 빨간 불빛 효과 (간단한 구현)
                    -- 실제로는 파티클 이펙트를 사용할 수 있음
                end
            end
        end

        Boss.renderThread = nil
    end)
end

-- 보스 HUD 업데이트
function UpdateBossHUD()
    SendNUIMessage({
        action = "updateBossHUD",
        isBoss = Boss.isBoss,
        bossName = Boss.bossName
    })
end

-- 보스 HUD 업데이트 루프
CreateThread(function()
    while true do
        Wait(100)

        if CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode and
           CurrentRound.gamemode.id == "boss" then

            local vehicle = LocalPlayer.vehicle

            SendNUIMessage({
                action = 'updateBossHUD',
                isBoss = Boss.isBoss,
                bossName = Boss.bossName,
                vehicleHealth = vehicle and DoesEntityExist(vehicle) and (GetVehicleEngineHealth(vehicle) / 10) or 0,
                vehicleSpeed = vehicle and DoesEntityExist(vehicle) and math.floor(GetEntitySpeed(vehicle) * 3.6) or 0
            })
        else
            Wait(500)
        end
    end
end)

-- 블립 업데이트 루프
CreateThread(function()
    while true do
        Wait(1000)

        if CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode and
           CurrentRound.gamemode.id == "boss" and Boss.bossPlayerId and not Boss.isBoss then

            -- 보스 블립 업데이트
            CreateBossBlip(Boss.bossPlayerId)
        else
            Wait(2000)
        end
    end
end)

-- 정리
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- 블립 제거
    if Boss.bossBlip then
        RemoveBlip(Boss.bossBlip)
    end
end)

Utils.Info('Boss gamemode (client) loaded')
