-- ========================================
-- SERVER MAIN
-- ========================================

-- 전역 변수
Players = {} -- 플레이어 데이터 저장
CurrentRound = {
    state = GameModes.States.WAITING,
    gamemode = nil,
    map = nil,
    timer = 0,
    votes = {
        gamemode = {},
        map = {}
    }
}

-- 리소스 시작
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Utils.Info('========================================')
    Utils.Info('FiveM Minigames Server Starting...')
    Utils.Info('Version: 1.0.0')
    Utils.Info('========================================')

    -- 플레이어 초기화
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        InitializePlayer(src)
    end

    -- 라운드 타이머 시작
    StartRoundTimer()
end)

-- 리소스 중지
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Utils.Info('FiveM Minigames Server Stopping...')

    -- 모든 플레이어 정리
    for playerId, _ in pairs(Players) do
        CleanupPlayer(playerId)
    end
end)

-- 플레이어 접속
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source

    deferrals.defer()
    Wait(100)

    -- 최대 플레이어 수 체크
    if Utils.TableSize(Players) >= Config.MaxPlayers then
        deferrals.done('서버가 가득 찼습니다.')
        return
    end

    deferrals.done()
end)

-- 플레이어 참가
AddEventHandler('playerJoining', function()
    local src = source
    InitializePlayer(src)
end)

-- 플레이어 나감
AddEventHandler('playerDropped', function(reason)
    local src = source
    CleanupPlayer(src)
end)

-- 플레이어 초기화
function InitializePlayer(src)
    if not src then return end

    local playerData = {
        source = src,
        name = GetPlayerName(src),
        state = GameModes.PlayerStates.LOBBY,
        ready = false,
        spectating = false,
        level = 1,
        rank = 1,
        stats = {
            kills = 0,
            deaths = 0,
            wins = 0,
            gamesPlayed = 0
        },
        vehicle = nil,
        items = {nil, nil, nil}, -- 3개 슬롯
        effects = {}
    }

    Players[src] = playerData

    -- 클라이언트에 초기화 알림
    TriggerClientEvent('minigames:client:initialize', src, playerData)

    -- 모든 플레이어에게 새 플레이어 알림
    TriggerClientEvent('minigames:client:playerJoined', -1, src, playerData)

    -- 플레이어 리스트 브로드캐스트
    BroadcastPlayerList()

    Utils.Info('Player ' .. playerData.name .. ' (' .. src .. ') joined the server')
end

-- 플레이어 정리
function CleanupPlayer(src)
    if not Players[src] then return end

    local playerName = Players[src].name

    -- 투표 제거
    RemovePlayerVotes(src)

    -- 플레이어 데이터 제거
    Players[src] = nil

    -- 모든 플레이어에게 플레이어 나감 알림
    TriggerClientEvent('minigames:client:playerLeft', -1, src)

    -- 플레이어 리스트 브로드캐스트
    BroadcastPlayerList()

    Utils.Info('Player ' .. playerName .. ' (' .. src .. ') left the server')
end

-- 플레이어 투표 제거
function RemovePlayerVotes(src)
    -- 게임모드 투표 제거
    for gamemode, voters in pairs(CurrentRound.votes.gamemode) do
        for i, voter in ipairs(voters) do
            if voter == src then
                table.remove(CurrentRound.votes.gamemode[gamemode], i)
                break
            end
        end
    end

    -- 맵 투표 제거
    for map, voters in pairs(CurrentRound.votes.map) do
        for i, voter in ipairs(voters) do
            if voter == src then
                table.remove(CurrentRound.votes.map[map], i)
                break
            end
        end
    end

    -- 투표 업데이트
    TriggerClientEvent('minigames:client:updateVotes', -1, CurrentRound.votes)
end

-- 준비된 플레이어 수 가져오기
function GetReadyPlayersCount()
    local count = 0
    for _, player in pairs(Players) do
        if player.ready and not player.spectating then
            count = count + 1
        end
    end
    return count
end

-- 활성 플레이어 수 가져오기 (관전자 제외)
function GetActivePlayersCount()
    local count = 0
    for _, player in pairs(Players) do
        if not player.spectating then
            count = count + 1
        end
    end
    return count
end

-- 게임 중인 플레이어 수 가져오기
function GetPlayingPlayersCount()
    local count = 0
    for _, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            count = count + 1
        end
    end
    return count
end

-- 라운드 타이머 시작
function StartRoundTimer()
    CreateThread(function()
        while true do
            Wait(1000)

            if CurrentRound.state == GameModes.States.WAITING then
                HandleWaitingState()
            elseif CurrentRound.state == GameModes.States.PREPARE then
                HandlePrepareState()
            elseif CurrentRound.state == GameModes.States.PLAYING then
                HandlePlayingState()
            elseif CurrentRound.state == GameModes.States.ENDING then
                HandleEndingState()
            end

            -- 타이머 업데이트
            if CurrentRound.timer > 0 then
                CurrentRound.timer = CurrentRound.timer - 1
                TriggerClientEvent('minigames:client:updateTimer', -1, CurrentRound.timer)
            end
        end
    end)
end

-- 대기 상태 처리
function HandleWaitingState()
    local activeCount = GetActivePlayersCount()
    local readyCount = GetReadyPlayersCount()

    -- 투표가 진행 중이면 대기 상태 타이머 무시
    if CurrentVoting and CurrentVoting.state ~= VotingState.IDLE then
        return
    end

    -- 최소 플레이어 수 체크
    if activeCount < Config.MinPlayers then
        CurrentRound.timer = 0
        -- 상태 브로드캐스트 (플레이어 기다리는 중)
        TriggerClientEvent('minigames:client:updateRoundState', -1, 'waiting_players', Config.MinPlayers - activeCount)
        return
    end

    -- 과반수 준비 체크
    if readyCount >= math.ceil(activeCount * Config.RequiredReadyPercentage) then
        if CurrentRound.timer <= 0 then
            CurrentRound.timer = 10 -- 10초 카운트다운
        end
        -- 상태 브로드캐스트 (게임 시작까지 남은 시간)
        TriggerClientEvent('minigames:client:updateRoundState', -1, 'starting', CurrentRound.timer)

        if CurrentRound.timer <= 0 then
            -- 투표 시작
            StartGamemodeVoting()
        end
    else
        CurrentRound.timer = 0
        -- 상태 브로드캐스트 (준비된 플레이어 기다리는 중)
        TriggerClientEvent('minigames:client:updateRoundState', -1, 'waiting_ready', {ready = readyCount, required = math.ceil(activeCount * Config.RequiredReadyPercentage)})
    end
end

-- 준비 상태 처리
function HandlePrepareState()
    if CurrentRound.timer <= 0 then
        CurrentRound.state = GameModes.States.PLAYING
        CurrentRound.timer = CurrentRound.gamemode.roundTime
        TriggerClientEvent('minigames:client:roundPlaying', -1)
    end
end

-- 게임 진행 상태 처리
function HandlePlayingState()
    if CurrentRound.timer <= 0 then
        EndRound()
    end
end

-- 종료 상태 처리
function HandleEndingState()
    if CurrentRound.timer <= 0 then
        CurrentRound.state = GameModes.States.WAITING
        CurrentRound.timer = Config.Round.WaitingTime
        CurrentRound.gamemode = nil
        CurrentRound.map = nil

        -- 모든 플레이어 로비로 복귀
        for playerId, player in pairs(Players) do
            player.state = GameModes.PlayerStates.LOBBY
            player.ready = false
            TriggerClientEvent('minigames:client:returnToLobby', playerId)
        end
    end
end

-- 라운드 시작 (투표 완료 후 호출됨)
function StartRound()
    -- 투표 시스템이 이미 게임모드와 맵을 선택함
    if not CurrentRound.gamemode or not CurrentRound.map then
        Utils.Error('Failed to start round: Invalid gamemode or map')
        return
    end

    CurrentRound.state = GameModes.States.PREPARE
    CurrentRound.timer = Config.Round.PrepareTime

    -- 모든 플레이어에게 라운드 시작 알림
    TriggerClientEvent('minigames:client:roundPrepare', -1, CurrentRound.gamemode, CurrentRound.map)
    TriggerClientEvent('minigames:client:updateRoundState', -1, 'preparing', CurrentRound.timer)

    -- 라운드 준비 함수 호출
    OnRoundPrepare()

    Utils.Info('Round starting: ' .. CurrentRound.gamemode.name .. ' - ' .. CurrentRound.map.name)
end

-- 라운드 종료
function EndRound()
    CurrentRound.state = GameModes.States.ENDING
    CurrentRound.timer = Config.Round.EndTime

    -- 승자 계산
    local winners = CalculateWinners()

    -- 모든 플레이어에게 라운드 종료 알림
    TriggerClientEvent('minigames:client:roundEnding', -1, winners)

    Utils.Info('Round ended')
end

-- 가장 많은 투표를 받은 게임모드 가져오기
function GetMostVotedGamemode()
    local maxVotes = 0
    local selected = nil

    for gamemodeId, voters in pairs(CurrentRound.votes.gamemode) do
        local voteCount = #voters
        if voteCount > maxVotes then
            maxVotes = voteCount
            selected = Utils.GetGamemodeById(gamemodeId)
        end
    end

    -- 투표가 없으면 랜덤
    if not selected then
        selected = Utils.GetRandomElement(Config.Gamemodes)
    end

    return selected
end

-- 가장 많은 투표를 받은 맵 가져오기
function GetMostVotedMap(gamemode)
    if not gamemode then return nil end

    local maxVotes = 0
    local selected = nil

    for mapId, voters in pairs(CurrentRound.votes.map) do
        local voteCount = #voters
        if voteCount > maxVotes then
            maxVotes = voteCount
            selected = Utils.GetMapById(gamemode.id, mapId)
        end
    end

    -- 투표가 없으면 랜덤
    if not selected and Config.Maps[gamemode.id] then
        selected = Utils.GetRandomElement(Config.Maps[gamemode.id])
    end

    return selected
end

-- 승자 계산
function CalculateWinners()
    local winners = {}

    for playerId, player in pairs(Players) do
        if player.state == GameModes.PlayerStates.PLAYING then
            table.insert(winners, {
                source = playerId,
                name = player.name,
                stats = player.stats
            })
        end
    end

    return winners
end

-- 유틸리티: 모든 플레이어 데이터 가져오기
function GetAllPlayers()
    return Players
end

-- 유틸리티: 플레이어 데이터 가져오기
function GetPlayer(src)
    return Players[src]
end

Utils.Info('Server main loaded')
