-- ========================================
-- ROUND MANAGEMENT
-- ========================================

-- 투표 상태 관리
VotingState = {
    IDLE = 0,           -- 대기 중
    GAMEMODE = 1,       -- 게임모드 투표 중
    MAP = 2,            -- 맵 투표 중
    WAITING_START = 3   -- 게임 시작 대기
}

CurrentVoting = {
    state = VotingState.IDLE,
    timer = 0,
    selectedGamemode = nil,
    gamemodeVotes = {},
    mapVotes = {}
}

-- 라운드 상태 변경 시 호출되는 함수들

-- 라운드 준비 단계 시작
function OnRoundPrepare()
    Utils.Info('Round prepare phase started')

    -- 플레이어들을 게임 상태로 변경
    for playerId, player in pairs(Players) do
        if not player.spectating and player.ready then
            player.state = GameModes.PlayerStates.PLAYING
        end
    end

    -- 게임모드별 준비 함수 호출
    if CurrentRound.gamemode then
        local gamemodeId = CurrentRound.gamemode.id
        TriggerEvent('minigames:server:gamemode:prepare:' .. gamemodeId)
    end
end

-- 라운드 진행 단계 시작
function OnRoundPlaying()
    Utils.Info('Round playing phase started')

    -- 게임모드별 시작 함수 호출
    if CurrentRound.gamemode then
        local gamemodeId = CurrentRound.gamemode.id
        TriggerEvent('minigames:server:gamemode:start:' .. gamemodeId)
    end
end

-- 라운드 종료 단계 시작
function OnRoundEnding(winners)
    Utils.Info('Round ending phase started')

    -- 게임모드별 종료 함수 호출
    if CurrentRound.gamemode then
        local gamemodeId = CurrentRound.gamemode.id
        TriggerEvent('minigames:server:gamemode:end:' .. gamemodeId, winners)
    end

    -- 통계 업데이트
    UpdatePlayerStats(winners)

    -- 투표 초기화
    ResetVoting()
end

-- 플레이어 통계 업데이트
function UpdatePlayerStats(winners)
    for playerId, player in pairs(Players) do
        -- 게임 플레이 횟수 증가
        if player.state == GameModes.PlayerStates.PLAYING or player.state == GameModes.PlayerStates.DEAD then
            player.stats.gamesPlayed = player.stats.gamesPlayed + 1
        end

        -- 승리 횟수 증가
        for _, winner in ipairs(winners) do
            if winner.source == playerId then
                player.stats.wins = player.stats.wins + 1
                break
            end
        end
    end
end

-- 서든 데스 활성화
function ActivateSuddenDeath()
    Utils.Info('Sudden death activated')

    -- 모든 플레이어에게 서든 데스 알림
    TriggerClientEvent('minigames:client:suddenDeath', -1)

    -- 게임모드별 서든 데스 함수 호출
    if CurrentRound.gamemode then
        local gamemodeId = CurrentRound.gamemode.id
        TriggerEvent('minigames:server:gamemode:suddendeath:' .. gamemodeId)
    end
end

-- 강제 라운드 종료
RegisterNetEvent('minigames:server:forceEndRound', function()
    local src = source

    -- TODO: 관리자 권한 체크

    EndRound()

    Utils.Info('Round force ended by ' .. GetPlayerName(src))
end)

-- 강제 라운드 시작
RegisterNetEvent('minigames:server:forceStartRound', function()
    local src = source

    -- TODO: 관리자 권한 체크

    if CurrentRound.state == GameModes.States.WAITING then
        StartRound()
        Utils.Info('Round force started by ' .. GetPlayerName(src))
    end
end)

-- ========================================
-- 투표 시스템
-- ========================================

-- 최소 인원 충족 시 게임모드 투표 시작
function StartGamemodeVoting()
    CurrentVoting.state = VotingState.GAMEMODE
    CurrentVoting.timer = 30 -- 30초
    CurrentVoting.gamemodeVotes = {}

    Utils.Info('Gamemode voting started (30s)')
    TriggerClientEvent('minigames:client:startGamemodeVoting', -1, Config.Gamemodes, 30)
    TriggerClientEvent('minigames:client:updateRoundState', -1, 'voting_gamemode', 30)
end

-- 게임모드 투표 종료 후 맵 투표 시작
function EndGamemodeVoting()
    local selectedGamemode = GetMostVotedGamemode()

    if not selectedGamemode then
        Utils.Warn('No gamemode votes, selecting random')
        selectedGamemode = Config.Gamemodes[math.random(#Config.Gamemodes)]
    end

    CurrentVoting.selectedGamemode = selectedGamemode
    CurrentVoting.state = VotingState.MAP
    CurrentVoting.timer = 20 -- 20초
    CurrentVoting.mapVotes = {}

    local maps = Config.Maps[selectedGamemode.id] or {}

    Utils.Info('Map voting started for ' .. selectedGamemode.name .. ' (20s)')
    TriggerClientEvent('minigames:client:startMapVoting', -1, maps, 20)
    TriggerClientEvent('minigames:client:updateRoundState', -1, 'voting_map', 20)
end

-- 맵 투표 종료 후 게임 시작 대기
function EndMapVoting()
    local selectedMap = GetMostVotedMap()

    if not selectedMap and CurrentVoting.selectedGamemode then
        local maps = Config.Maps[CurrentVoting.selectedGamemode.id] or {}
        if #maps > 0 then
            Utils.Warn('No map votes, selecting random')
            selectedMap = maps[math.random(#maps)]
        end
    end

    CurrentVoting.state = VotingState.WAITING_START

    -- 라운드 시작 로직으로 전달
    CurrentRound.gamemode = CurrentVoting.selectedGamemode
    CurrentRound.map = selectedMap

    Utils.Info('Voting complete: ' .. (CurrentRound.gamemode and CurrentRound.gamemode.name or 'none') .. ' - ' .. (CurrentRound.map and CurrentRound.map.name or 'none'))
    TriggerClientEvent('minigames:client:votingComplete', -1, CurrentVoting.selectedGamemode, selectedMap)

    -- 투표 완료 후 라운드 시작
    Wait(3000) -- 3초 대기 (결과 확인 시간)
    StartRound()
end

-- 가장 많은 표를 받은 게임모드 반환
function GetMostVotedGamemode()
    local voteCounts = {}

    -- 투표 수 집계
    for playerId, gamemodeId in pairs(CurrentVoting.gamemodeVotes) do
        voteCounts[gamemodeId] = (voteCounts[gamemodeId] or 0) + 1
    end

    -- 최다 득표 찾기
    local maxVotes = 0
    local winner = nil

    for gamemodeId, count in pairs(voteCounts) do
        if count > maxVotes then
            maxVotes = count
            winner = gamemodeId
        end
    end

    -- 게임모드 객체 반환
    if winner then
        for _, gamemode in ipairs(Config.Gamemodes) do
            if gamemode.id == winner then
                return gamemode
            end
        end
    end

    return nil
end

-- 가장 많은 표를 받은 맵 반환
function GetMostVotedMap()
    local voteCounts = {}

    -- 투표 수 집계
    for playerId, mapId in pairs(CurrentVoting.mapVotes) do
        voteCounts[mapId] = (voteCounts[mapId] or 0) + 1
    end

    -- 최다 득표 찾기
    local maxVotes = 0
    local winner = nil

    for mapId, count in pairs(voteCounts) do
        if count > maxVotes then
            maxVotes = count
            winner = mapId
        end
    end

    -- 맵 객체 반환
    if winner and CurrentVoting.selectedGamemode then
        local maps = Config.Maps[CurrentVoting.selectedGamemode.id] or {}
        for _, map in ipairs(maps) do
            if map.id == winner then
                return map
            end
        end
    end

    return nil
end

-- 투표 초기화
function ResetVoting()
    CurrentVoting.state = VotingState.IDLE
    CurrentVoting.timer = 0
    CurrentVoting.selectedGamemode = nil
    CurrentVoting.gamemodeVotes = {}
    CurrentVoting.mapVotes = {}

    Utils.Debug('Voting reset')
end

-- 게임모드 투표
RegisterNetEvent('minigames:server:voteGamemode', function(gamemodeId)
    local src = source

    if CurrentVoting.state ~= VotingState.GAMEMODE then
        Utils.Warn('Player ' .. src .. ' tried to vote gamemode when not in voting state')
        return
    end

    CurrentVoting.gamemodeVotes[src] = gamemodeId

    -- 투표 수 브로드캐스트
    BroadcastVoteCounts()

    Utils.Debug('Player ' .. src .. ' voted for gamemode: ' .. gamemodeId)
end)

-- 맵 투표
RegisterNetEvent('minigames:server:voteMap', function(mapId)
    local src = source

    if CurrentVoting.state ~= VotingState.MAP then
        Utils.Warn('Player ' .. src .. ' tried to vote map when not in voting state')
        return
    end

    CurrentVoting.mapVotes[src] = mapId

    -- 투표 수 브로드캐스트
    BroadcastVoteCounts()

    Utils.Debug('Player ' .. src .. ' voted for map: ' .. mapId)
end)

-- 투표 수 브로드캐스트
function BroadcastVoteCounts()
    local votes = {}

    if CurrentVoting.state == VotingState.GAMEMODE then
        -- 게임모드별 투표 수 집계
        for playerId, gamemodeId in pairs(CurrentVoting.gamemodeVotes) do
            votes[gamemodeId] = (votes[gamemodeId] or 0) + 1
        end
    elseif CurrentVoting.state == VotingState.MAP then
        -- 맵별 투표 수 집계
        for playerId, mapId in pairs(CurrentVoting.mapVotes) do
            votes[mapId] = (votes[mapId] or 0) + 1
        end
    end

    TriggerClientEvent('minigames:client:updateVoteCounts', -1, votes)
end

-- 투표 타이머 (1초마다 호출)
CreateThread(function()
    while true do
        Wait(1000)

        if CurrentVoting.state == VotingState.GAMEMODE or CurrentVoting.state == VotingState.MAP then
            CurrentVoting.timer = CurrentVoting.timer - 1

            -- 타이머 브로드캐스트
            TriggerClientEvent('minigames:client:updateVotingTimer', -1, CurrentVoting.timer)

            -- 시간 종료
            if CurrentVoting.timer <= 0 then
                if CurrentVoting.state == VotingState.GAMEMODE then
                    EndGamemodeVoting()
                elseif CurrentVoting.state == VotingState.MAP then
                    EndMapVoting()
                end
            end
        end
    end
end)

Utils.Info('Round management loaded')
