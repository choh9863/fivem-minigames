-- ========================================
-- ROUND MANAGEMENT
-- ========================================

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
    ResetVotes()
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

Utils.Info('Round management loaded')
