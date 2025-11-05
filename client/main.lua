-- ========================================
-- CLIENT MAIN
-- ========================================

-- 전역 변수
LocalPlayer = {
    source = nil,
    data = nil,
    vehicle = nil,
    frozen = false
}

CurrentRound = {
    state = GameModes.States.WAITING,
    gamemode = nil,
    map = nil,
    timer = 0
}

-- 리소스 시작
CreateThread(function()
    Utils.Info('========================================')
    Utils.Info('FiveM Minigames Client Starting...')
    Utils.Info('Version: 1.0.0')
    Utils.Info('========================================')

    -- 초기 설정
    DisplayRadar(false)
    SetPlayerControl(PlayerId(), false, 0)

    -- 서버로부터 초기화 대기
    while not LocalPlayer.data do
        Wait(100)
    end

    -- 로비 스폰
    SpawnInLobby()
end)

-- 플레이어 초기화
RegisterNetEvent('minigames:client:initialize', function(playerData)
    LocalPlayer.source = GetPlayerServerId(PlayerId())
    LocalPlayer.data = playerData

    Utils.Info('Client initialized for player: ' .. playerData.name)
end)

-- 로비 스폰
function SpawnInLobby()
    local ped = PlayerPedId()
    local spawnPos = Config.SpawnLocation

    -- 플레이어 텔레포트
    SetEntityCoords(ped, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
    SetEntityHeading(ped, spawnPos.w)

    -- 플레이어 프리즈
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityAlpha(ped, 0, false)
    LocalPlayer.frozen = true

    -- 무기 제거
    RemoveAllPedWeapons(ped, true)

    -- 로비 UI 열기
    Wait(500)
    -- 서버에 로비 데이터 요청
    TriggerServerEvent('minigames:server:requestLobbyData')

    Utils.Info('Spawned in lobby')
end

-- 로비에서 나가기 (게임 시작)
function LeaveLobby()
    local ped = PlayerPedId()

    -- 플레이어 언프리즈
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    LocalPlayer.frozen = false

    -- 로비 UI 닫기
    TriggerEvent('minigames:client:closeLobby')

    Utils.Info('Left lobby')
end

-- 로비로 복귀
RegisterNetEvent('minigames:client:returnToLobby', function()
    -- 차량에서 내리기
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        TaskLeaveVehicle(PlayerPedId(), GetVehiclePedIsIn(PlayerPedId(), false), 0)
        Wait(1000)
    end

    -- 차량 제거
    if LocalPlayer.vehicle and DoesEntityExist(LocalPlayer.vehicle) then
        DeleteEntity(LocalPlayer.vehicle)
        LocalPlayer.vehicle = nil
    end

    -- 로비 스폰
    SpawnInLobby()

    -- 상태 초기화
    LocalPlayer.data.state = GameModes.PlayerStates.LOBBY
    LocalPlayer.data.ready = false

    Utils.Info('Returned to lobby')
end)

-- 라운드 준비
RegisterNetEvent('minigames:client:roundPrepare', function(gamemode, map)
    CurrentRound.gamemode = gamemode
    CurrentRound.map = map
    CurrentRound.state = GameModes.States.PREPARE
    CurrentRound.timer = Config.Round.PrepareTime

    Utils.Info('Round preparing: ' .. gamemode.name .. ' - ' .. map.name)

    -- 로비 나가기
    LeaveLobby()

    -- 맵으로 텔레포트
    Wait(500)
    TeleportToMap(map)
end)

-- 라운드 진행
RegisterNetEvent('minigames:client:roundPlaying', function()
    CurrentRound.state = GameModes.States.PLAYING

    -- 플레이어 컨트롤 활성화
    SetPlayerControl(PlayerId(), true, 0)

    Utils.Info('Round playing')
end)

-- 라운드 종료
RegisterNetEvent('minigames:client:roundEnding', function(winners)
    CurrentRound.state = GameModes.States.ENDING

    Utils.Info('Round ending')

    -- 결과 화면 표시
    TriggerEvent('minigames:client:showResults', winners)
end)

-- 타이머 업데이트
RegisterNetEvent('minigames:client:updateTimer', function(timer)
    CurrentRound.timer = timer
end)

-- 맵으로 텔레포트
function TeleportToMap(map)
    local ped = PlayerPedId()

    -- 랜덤 스폰 위치 선택
    local spawn = Utils.GetRandomElement(map.spawns)
    if not spawn then
        Utils.Error('No spawn points found for map: ' .. map.id)
        return
    end

    -- 텔레포트
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    SetEntityHeading(ped, spawn.w)

    Utils.Info('Teleported to map: ' .. map.id)

    -- 게임모드별 초기화
    TriggerEvent('minigames:client:gamemode:initialize', CurrentRound.gamemode.id, map)
end

-- 차량 생성
function CreatePlayerVehicle(model, coords, heading)
    -- 모델 로드
    local modelHash = type(model) == "string" and GetHashKey(model) or model

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(100)
    end

    -- 차량 생성
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)

    -- 플레이어를 차량에 태우기
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)

    -- 모델 해제
    SetModelAsNoLongerNeeded(modelHash)

    LocalPlayer.vehicle = vehicle

    Utils.Info('Created vehicle: ' .. model)

    return vehicle
end

-- 차량 제거
function DeletePlayerVehicle()
    if LocalPlayer.vehicle and DoesEntityExist(LocalPlayer.vehicle) then
        DeleteEntity(LocalPlayer.vehicle)
        LocalPlayer.vehicle = nil
        Utils.Info('Deleted vehicle')
    end
end

-- 키 바인딩
CreateThread(function()
    while true do
        Wait(0)

        -- ESC: 메뉴 토글 (로비에서만)
        if IsControlJustPressed(0, 322) and CurrentRound.state == GameModes.States.WAITING then
            TriggerEvent('minigames:client:toggleLobby')
        end

        -- 아이템 사용 (1, 2, 3)
        if CurrentRound.state == GameModes.States.PLAYING then
            if IsControlJustPressed(0, 157) then -- 1번 키
                TriggerServerEvent('minigames:server:useItem', 1)
            elseif IsControlJustPressed(0, 158) then -- 2번 키
                TriggerServerEvent('minigames:server:useItem', 2)
            elseif IsControlJustPressed(0, 160) then -- 3번 키
                TriggerServerEvent('minigames:server:useItem', 3)
            end
        end
    end
end)

-- 충돌 데미지 처리
CreateThread(function()
    while true do
        Wait(0)

        if CurrentRound.state == GameModes.States.PLAYING and LocalPlayer.vehicle then
            -- 차량 무적 해제 (게임모드에서 데미지 처리)
            SetEntityInvincible(LocalPlayer.vehicle, false)
        end
    end
end)

Utils.Info('Client main loaded')
