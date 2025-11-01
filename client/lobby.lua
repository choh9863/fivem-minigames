-- ========================================
-- 로비 클라이언트 스크립트 (NUI 통신 예제)
-- ========================================

local isLobbyOpen = false
local lobbyData = {
    players = {},
    spectators = {},
    gamemodes = {},
    maps = {},
    timer = 0
}

-- ========================================
-- 로비 열기
-- ========================================
function OpenLobby(data)
    if isLobbyOpen then return end

    isLobbyOpen = true
    SetNuiFocus(true, true)

    -- data가 nil이면 빈 테이블로 초기화
    data = data or {}

    -- 게임모드 데이터 준비
    local gamemodes = {}
    for _, mode in ipairs(Config.Gamemodes) do
        table.insert(gamemodes, {
            id = mode.id,
            name = mode.name,
            description = mode.description,
            image = mode.image,
            votes = 0
        })
    end

    -- 로비 데이터 전송
    SendNUIMessage({
        action = 'openLobby',
        data = {
            players = data.players or {},
            spectators = data.spectators or {},
            gamemodes = gamemodes,
            maps = data.maps or {},
            maxPlayers = Config.MaxPlayers,
            isReady = false,
            isSpectating = false
        }
    })

    -- 서버에 로비 데이터 요청
    TriggerServerEvent('minigames:server:requestLobbyData')
end

-- ========================================
-- 로비 닫기
-- ========================================
function CloseLobby()
    if not isLobbyOpen then return end

    isLobbyOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'closeLobby'
    })
end

-- ========================================
-- 로비 데이터 업데이트
-- ========================================
function UpdateLobbyData(data)
    if not isLobbyOpen then return end

    lobbyData = data

    SendNUIMessage({
        action = 'updateLobbyData',
        data = data
    })
end

-- ========================================
-- 타이머 업데이트
-- ========================================
function UpdateLobbyTimer(time)
    if not isLobbyOpen then return end

    SendNUIMessage({
        action = 'updateTimer',
        time = time
    })
end

-- ========================================
-- 채팅 메시지 수신
-- ========================================
function ReceiveChatMessage(sender, message)
    if not isLobbyOpen then return end

    SendNUIMessage({
        action = 'chatMessage',
        sender = sender,
        message = message
    })
end

-- ========================================
-- NUI 콜백 (UI -> 클라이언트)
-- ========================================

-- 로비 닫기
RegisterNUICallback('closeLobby', function(data, cb)
    CloseLobby()
    cb('ok')
end)

-- 준비 상태 토글
RegisterNUICallback('toggleReady', function(data, cb)
    TriggerServerEvent('minigames:server:toggleReady')
    cb('ok')
end)

-- 관전 상태 토글
RegisterNUICallback('toggleSpectate', function(data, cb)
    TriggerServerEvent('minigames:server:toggleSpectate')
    cb('ok')
end)

-- 게임 종료
RegisterNUICallback('quitGame', function(data, cb)
    TriggerServerEvent('minigames:server:quitGame')
    CloseLobby()
    cb('ok')
end)

-- 게임모드 투표
RegisterNUICallback('voteGamemode', function(data, cb)
    TriggerServerEvent('minigames:server:voteGamemode', data.gamemodeId)
    cb('ok')
end)

-- 맵 투표
RegisterNUICallback('voteMap', function(data, cb)
    TriggerServerEvent('minigames:server:voteMap', data.mapId)
    cb('ok')
end)

-- 채팅 메시지 전송
RegisterNUICallback('sendChatMessage', function(data, cb)
    TriggerServerEvent('minigames:server:chatMessage', data.message)
    cb('ok')
end)

-- ========================================
-- 서버 이벤트 (서버 -> 클라이언트)
-- ========================================

-- 로비 데이터 수신 및 열기
RegisterNetEvent('minigames:client:receiveLobbyData', function(data)
    OpenLobby(data)
end)

-- 로비 열기
RegisterNetEvent('minigames:client:openLobby', function(data)
    OpenLobby(data)
end)

-- 로비 닫기
RegisterNetEvent('minigames:client:closeLobby', function()
    CloseLobby()
end)

-- 로비 데이터 업데이트
RegisterNetEvent('minigames:client:updateLobby', function(data)
    UpdateLobbyData(data)
end)

-- 타이머 업데이트
RegisterNetEvent('minigames:client:updateTimer', function(time)
    UpdateLobbyTimer(time)
end)

-- 채팅 메시지
RegisterNetEvent('minigames:client:chatMessage', function(sender, message)
    ReceiveChatMessage(sender, message)
end)

-- 채팅 메시지 수신
RegisterNetEvent('minigames:client:receiveChatMessage', function(sender, message)
    ReceiveChatMessage(sender, message)
end)

-- 플레이어 리스트 업데이트
RegisterNetEvent('minigames:client:updatePlayerList', function(playerList, spectatorList)
    if not isLobbyOpen then return end

    SendNUIMessage({
        action = 'updateLobbyData',
        data = {
            players = playerList,
            spectators = spectatorList
        }
    })
end)

-- 투표 업데이트
RegisterNetEvent('minigames:client:updateVotes', function(votes)
    if not isLobbyOpen then return end

    -- 투표 수를 게임모드와 맵에 반영
    local gamemodes = {}
    for _, mode in ipairs(Config.Gamemodes) do
        local voteCount = 0
        if votes.gamemode[mode.id] then
            voteCount = #votes.gamemode[mode.id]
        end

        table.insert(gamemodes, {
            id = mode.id,
            name = mode.name,
            description = mode.description,
            image = mode.image,
            votes = voteCount
        })
    end

    -- 현재 선택된 게임모드의 맵 가져오기
    local maps = {}
    -- TODO: 선택된 게임모드에 따른 맵 필터링

    SendNUIMessage({
        action = 'updateLobbyData',
        data = {
            gamemodes = gamemodes,
            maps = maps,
            votes = votes
        }
    })
end)

-- ========================================
-- 테스트 명령어 (개발용)
-- ========================================
if IsDuplicityVersion() == false then
    RegisterCommand('testlobby', function()
        OpenLobby({
            players = {
                { name = '테스트플레이어1', level = 15, rank = 3, ready = true },
                { name = '테스트플레이어2', level = 24, rank = 5, ready = false }
            },
            spectators = {
                { name = '관전자1', level = 5, rank = 1 }
            },
            maps = {
                { id = 'bumpercar_arena', name = '아레나', image = 'img/maps/bumpercar_arena.png', votes = 0 }
            }
        })

        -- 타이머 테스트
        local timer = 60
        CreateThread(function()
            while timer > 0 and isLobbyOpen do
                UpdateLobbyTimer(timer)
                Wait(1000)
                timer = timer - 1
            end
        end)
    end, false)

    RegisterCommand('closelobby', function()
        CloseLobby()
    end, false)
end

-- ========================================
-- ESC 키 핸들링
-- ========================================
CreateThread(function()
    while true do
        if isLobbyOpen then
            DisableControlAction(0, 322, true) -- ESC
            DisableControlAction(0, 106, true) -- VEH_MOUSE_CONTROL_OVERRIDE
        end
        Wait(0)
    end
end)

print('^2[Minigames]^7 로비 클라이언트 스크립트 로드됨')
