-- ========================================
-- BOMB GAMEMODE - CLIENT
-- ========================================

local Bomb = {
    bombHolder = nil,
    bombTimer = 0,
    hasBomb = false,
    bombObject = nil,
    collisionCheckThread = nil,
    lastCollisionTime = 0,
    bombBlip = nil
}

-- 게임모드 초기화
RegisterNetEvent('minigames:client:gamemode:initialize', function(gamemodeId, map)
    if gamemodeId ~= "bomb" then return end

    Utils.Info('Bomb: Initializing')

    -- 충돌 감지 시작 (폭탄 전달용)
    StartCollisionDetection()
end)

-- 충돌 감지 시작
function StartCollisionDetection()
    if Bomb.collisionCheckThread then return end

    Bomb.collisionCheckThread = CreateThread(function()
        while CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode.id == "bomb" do
            Wait(100)

            local vehicle = LocalPlayer.vehicle
            if vehicle and DoesEntityExist(vehicle) and Bomb.hasBomb then
                -- 차량 충돌 체크
                if HasEntityCollidedWithAnything(vehicle) then
                    local currentTime = GetGameTimer()

                    -- 쿨다운 체크 (1초)
                    if currentTime - Bomb.lastCollisionTime > 1000 then
                        -- 충돌한 엔티티 찾기
                        local collisionEntity = GetLastEntityHitByVehicle(vehicle)

                        if collisionEntity and IsEntityAVehicle(collisionEntity) then
                            -- 다른 플레이어 차량과 충돌
                            local otherPed = GetPedInVehicleSeat(collisionEntity, -1)

                            if otherPed and IsPedAPlayer(otherPed) and otherPed ~= PlayerPedId() then
                                local otherPlayer = NetworkGetPlayerIndexFromPed(otherPed)
                                local otherPlayerId = GetPlayerServerId(otherPlayer)

                                -- 서버에 폭탄 전달 요청
                                TriggerServerEvent('minigames:server:transferBomb', otherPlayerId)

                                Bomb.lastCollisionTime = currentTime

                                Utils.Debug('Attempting to transfer bomb to player ' .. otherPlayerId)
                            end
                        end
                    end
                end
            end
        end

        Bomb.collisionCheckThread = nil
    end)
end

-- 폭탄 부착 알림
RegisterNetEvent('minigames:client:bombAttached', function(playerId, timer)
    Bomb.bombHolder = playerId
    Bomb.bombTimer = timer
    Bomb.hasBomb = (playerId == GetPlayerServerId(PlayerId()))

    if Bomb.hasBomb then
        -- 폭탄 오브젝트 생성
        CreateBombObject()

        Utils.Info('Bomb attached to you!')
    else
        -- 폭탄 소유자 블립 생성
        CreateBombHolderBlip(playerId)

        Utils.Debug('Bomb attached to player ' .. playerId)
    end

    -- HUD 업데이트
    UpdateBombHUD()
end)

-- 폭탄 전달 알림
RegisterNetEvent('minigames:client:bombTransferred', function(fromId, toId, timer)
    local myId = GetPlayerServerId(PlayerId())

    -- 이전 소유자의 폭탄 제거
    if fromId == myId then
        RemoveBombObject()
        Bomb.hasBomb = false
    end

    -- 새 소유자에게 폭탄 부착
    Bomb.bombHolder = toId
    Bomb.bombTimer = timer

    if toId == myId then
        Bomb.hasBomb = true
        CreateBombObject()
    else
        -- 블립 업데이트
        CreateBombHolderBlip(toId)
    end

    -- HUD 업데이트
    UpdateBombHUD()

    Utils.Debug('Bomb transferred from ' .. fromId .. ' to ' .. toId)
end)

-- 폭탄 타이머 업데이트
RegisterNetEvent('minigames:client:bombTimerUpdate', function(timer)
    Bomb.bombTimer = timer

    -- HUD 업데이트
    UpdateBombHUD()

    -- 경고음 (타이머가 적을 때)
    if Bomb.hasBomb and timer <= 5 then
        PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)
    end
end)

-- 폭탄 폭발
RegisterNetEvent('minigames:client:bombExplode', function(playerId)
    -- 폭발 이펙트
    local playerPed = GetPlayerPed(GetPlayerFromServerId(playerId))

    if playerPed and DoesEntityExist(playerPed) then
        local coords = GetEntityCoords(playerPed)

        -- 폭발 생성
        AddExplosion(coords.x, coords.y, coords.z, 2, 100.0, true, false, 1.0)

        -- 파티클 이펙트
        RequestNamedPtfxAsset("core")
        while not HasNamedPtfxAssetLoaded("core") do
            Wait(1)
        end

        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_bzgas_smoke", coords.x, coords.y, coords.z,
            0.0, 0.0, 0.0, 3.0, false, false, false)
    end

    -- 폭탄 오브젝트 제거
    if playerId == GetPlayerServerId(PlayerId()) then
        RemoveBombObject()
        Bomb.hasBomb = false
    end

    Bomb.bombHolder = nil

    -- 블립 제거
    RemoveBombBlip()

    Utils.Debug('Bomb exploded on player ' .. playerId)
end)

-- 폭탄 제거
RegisterNetEvent('minigames:client:removeBomb', function()
    RemoveBombObject()
    RemoveBombBlip()

    Bomb.bombHolder = nil
    Bomb.hasBomb = false
    Bomb.bombTimer = 0

    UpdateBombHUD()
end)

-- 폭탄 오브젝트 생성
function CreateBombObject()
    -- 기존 오브젝트 제거
    RemoveBombObject()

    local vehicle = LocalPlayer.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end

    -- 폭탄 모델 로드 (prop_bomb_01 같은 것)
    local bombModel = GetHashKey("prop_ld_bomb_01")

    RequestModel(bombModel)
    while not HasModelLoaded(bombModel) do
        Wait(1)
    end

    -- 차량 위에 폭탄 생성
    local vehicleCoords = GetEntityCoords(vehicle)
    Bomb.bombObject = CreateObject(bombModel, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 2.0,
        false, false, false)

    -- 차량에 부착
    AttachEntityToEntity(Bomb.bombObject, vehicle, 0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
        false, false, false, false, 0, true)

    SetModelAsNoLongerNeeded(bombModel)

    Utils.Debug('Bomb object created')
end

-- 폭탄 오브젝트 제거
function RemoveBombObject()
    if Bomb.bombObject and DoesEntityExist(Bomb.bombObject) then
        DeleteObject(Bomb.bombObject)
        Bomb.bombObject = nil

        Utils.Debug('Bomb object removed')
    end
end

-- 폭탄 소유자 블립 생성
function CreateBombHolderBlip(playerId)
    -- 기존 블립 제거
    RemoveBombBlip()

    local playerPed = GetPlayerPed(GetPlayerFromServerId(playerId))
    if not playerPed or not DoesEntityExist(playerPed) then return end

    -- 블립 생성
    Bomb.bombBlip = AddBlipForEntity(playerPed)
    SetBlipSprite(Bomb.bombBlip, 161) -- 폭탄 아이콘
    SetBlipColour(Bomb.bombBlip, 1) -- 빨간색
    SetBlipScale(Bomb.bombBlip, 1.2)
    SetBlipAsShortRange(Bomb.bombBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("폭탄 소유자")
    EndTextCommandSetBlipName(Bomb.bombBlip)

    Utils.Debug('Bomb holder blip created for player ' .. playerId)
end

-- 폭탄 블립 제거
function RemoveBombBlip()
    if Bomb.bombBlip then
        RemoveBlip(Bomb.bombBlip)
        Bomb.bombBlip = nil

        Utils.Debug('Bomb blip removed')
    end
end

-- 폭탄 HUD 업데이트
function UpdateBombHUD()
    SendNUIMessage({
        action = "updateBombHUD",
        hasBomb = Bomb.hasBomb,
        bombHolder = Bomb.bombHolder,
        timer = Bomb.bombTimer
    })
end

-- 폭탄 타이머 HUD 업데이트 루프
CreateThread(function()
    while true do
        Wait(100)

        if CurrentRound.state == GameModes.States.PLAYING and CurrentRound.gamemode and
           CurrentRound.gamemode.id == "bomb" then

            local vehicle = LocalPlayer.vehicle

            SendNUIMessage({
                action = 'updateBombHUD',
                timer = Bomb.bombTimer,
                bombHolder = Bomb.bombHolder,
                hasBomb = Bomb.hasBomb,
                health = vehicle and DoesEntityExist(vehicle) and GetVehicleEngineHealth(vehicle) or 0,
                maxHealth = 1000,
                speed = vehicle and DoesEntityExist(vehicle) and math.floor(GetEntitySpeed(vehicle) * 3.6) or 0
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
           CurrentRound.gamemode.id == "bomb" and Bomb.bombHolder then

            -- 폭탄 소유자가 자신이 아니면 블립 업데이트
            if not Bomb.hasBomb then
                CreateBombHolderBlip(Bomb.bombHolder)
            end
        else
            Wait(2000)
        end
    end
end)

Utils.Info('Bomb gamemode (client) loaded')
