-- ========================================
-- CAMERA SYSTEM
-- ========================================

local CurrentCamera = nil
local CameraData = {
    spectating = false,
    spectateTarget = nil,
    spectateList = {}
}

-- 관전 모드 설정
RegisterNetEvent('minigames:client:setSpectateMode', function(enabled)
    if enabled then
        StartSpectating()
    else
        StopSpectating()
    end
end)

-- 관전 시작
function StartSpectating()
    CameraData.spectating = true

    -- 관전 가능한 플레이어 목록 생성
    UpdateSpectateList()

    -- 첫 번째 플레이어 관전
    if #CameraData.spectateList > 0 then
        SpectatePlayer(CameraData.spectateList[1])
    end

    Utils.Info('Started spectating')
end

-- 관전 중지
function StopSpectating()
    CameraData.spectating = false

    if CameraData.spectateTarget then
        -- 카메라 해제
        NetworkSetInSpectatorMode(false, CameraData.spectateTarget)
        CameraData.spectateTarget = nil
    end

    CameraData.spectateList = {}

    Utils.Info('Stopped spectating')
end

-- 플레이어 관전
function SpectatePlayer(playerId)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(playerId))

    if DoesEntityExist(targetPed) then
        CameraData.spectateTarget = targetPed
        NetworkSetInSpectatorMode(true, targetPed)

        Utils.Debug('Spectating player: ' .. playerId)
    end
end

-- 관전 대상 목록 업데이트
function UpdateSpectateList()
    CameraData.spectateList = {}

    for _, player in pairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(player)
        if serverId ~= LocalPlayer.source then
            table.insert(CameraData.spectateList, serverId)
        end
    end
end

-- 다음 플레이어 관전
function SpectateNext()
    if not CameraData.spectating or #CameraData.spectateList == 0 then return end

    local currentIndex = 1
    for i, playerId in ipairs(CameraData.spectateList) do
        if playerId == GetPlayerServerId(NetworkGetPlayerIndexFromPed(CameraData.spectateTarget)) then
            currentIndex = i
            break
        end
    end

    local nextIndex = currentIndex + 1
    if nextIndex > #CameraData.spectateList then
        nextIndex = 1
    end

    SpectatePlayer(CameraData.spectateList[nextIndex])
end

-- 이전 플레이어 관전
function SpectatePrevious()
    if not CameraData.spectating or #CameraData.spectateList == 0 then return end

    local currentIndex = 1
    for i, playerId in ipairs(CameraData.spectateList) do
        if playerId == GetPlayerServerId(NetworkGetPlayerIndexFromPed(CameraData.spectateTarget)) then
            currentIndex = i
            break
        end
    end

    local prevIndex = currentIndex - 1
    if prevIndex < 1 then
        prevIndex = #CameraData.spectateList
    end

    SpectatePlayer(CameraData.spectateList[prevIndex])
end

-- 관전 키 입력
CreateThread(function()
    while true do
        Wait(0)

        if CameraData.spectating then
            -- 좌/우 화살표로 관전 대상 변경
            if IsControlJustPressed(0, 174) then -- 좌 화살표
                SpectatePrevious()
            elseif IsControlJustPressed(0, 175) then -- 우 화살표
                SpectateNext()
            end
        end
    end
end)

-- 관전 대상 자동 업데이트
CreateThread(function()
    while true do
        Wait(5000) -- 5초마다

        if CameraData.spectating then
            UpdateSpectateList()

            -- 현재 관전 대상이 유효하지 않으면 다음 플레이어로
            if CameraData.spectateTarget and not DoesEntityExist(CameraData.spectateTarget) then
                if #CameraData.spectateList > 0 then
                    SpectateNext()
                else
                    StopSpectating()
                end
            end
        end
    end
end)

Utils.Info('Camera system loaded')
