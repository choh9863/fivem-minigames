-- ========================================
-- LOBBY MANAGEMENT
-- ========================================

-- 플레이어 리스트 브로드캐스트
function BroadcastPlayerList()
    -- 플레이어 리스트
    local playerList = {}
    for playerId, player in pairs(Players) do
        if not player.spectating then
            table.insert(playerList, {
                source = playerId,
                name = player.name,
                level = player.level,
                rank = player.rank,
                ready = player.ready
            })
        end
    end

    -- 관전자 리스트
    local spectatorList = {}
    for playerId, player in pairs(Players) do
        if player.spectating then
            table.insert(spectatorList, {
                source = playerId,
                name = player.name,
                level = player.level,
                rank = player.rank
            })
        end
    end

    -- 모든 클라이언트에 전송
    TriggerClientEvent('minigames:client:updatePlayerList', -1, playerList, spectatorList)
end

-- 로비 데이터 요청
RegisterNetEvent('minigames:server:requestLobbyData', function()
    local src = source

    -- 플레이어 리스트
    local playerList = {}
    for playerId, player in pairs(Players) do
        if not player.spectating then
            table.insert(playerList, {
                source = playerId,
                name = player.name,
                level = player.level,
                rank = player.rank,
                ready = player.ready
            })
        end
    end

    -- 관전자 리스트
    local spectatorList = {}
    for playerId, player in pairs(Players) do
        if player.spectating then
            table.insert(spectatorList, {
                source = playerId,
                name = player.name,
                level = player.level,
                rank = player.rank
            })
        end
    end

    -- 로비 데이터 전송
    TriggerClientEvent('minigames:client:receiveLobbyData', src, {
        players = playerList,
        spectators = spectatorList,
        gamemodes = Config.Gamemodes,
        maps = Config.Maps,
        votes = CurrentRound.votes,
        timer = CurrentRound.timer,
        state = CurrentRound.state
    })
end)

-- 플레이어 참가 시 모든 클라이언트에 업데이트
RegisterNetEvent('minigames:client:playerJoined', function(playerId, playerData)
    -- NUI 업데이트 이벤트는 클라이언트에서 처리
end)

-- 플레이어 나감 시 모든 클라이언트에 업데이트
RegisterNetEvent('minigames:client:playerLeft', function(playerId)
    -- NUI 업데이트 이벤트는 클라이언트에서 처리
end)

-- 채팅 메시지 전송
RegisterNetEvent('minigames:server:chatMessage', function(message)
    local src = source
    local player = GetPlayer(src)

    if not player then return end

    -- 메시지 길이 제한
    if #message > 200 then
        TriggerClientEvent('minigames:client:notify', src, '메시지가 너무 깁니다.')
        return
    end

    -- 메시지 필터링 (욕설 등)
    -- TODO: 욕설 필터 구현

    -- 모든 플레이어에게 채팅 메시지 전송
    TriggerClientEvent('minigames:client:receiveChatMessage', -1, player.name, message)

    Utils.Debug('Chat message from ' .. player.name .. ': ' .. message)
end)

-- 게임 종료 (로비로 복귀)
RegisterNetEvent('minigames:server:quitGame', function()
    local src = source
    local player = GetPlayer(src)

    if not player then return end

    -- 이미 로비에 있으면 무시
    if player.state == GameModes.PlayerStates.LOBBY then
        return
    end

    -- 게임 중이면 사망 처리
    if player.state == GameModes.PlayerStates.PLAYING then
        TriggerEvent('minigames:server:playerDied', src)
    end

    -- 로비로 복귀
    player.state = GameModes.PlayerStates.LOBBY
    player.ready = false

    TriggerClientEvent('minigames:client:returnToLobby', src)

    Utils.Debug('Player ' .. player.name .. ' quit to lobby')
end)

Utils.Info('Lobby management loaded')
