-- ========================================
-- PLAYER MANAGEMENT
-- ========================================

-- 준비 상태 토글
RegisterNetEvent('minigames:server:toggleReady', function()
    local src = source
    local player = GetPlayer(src)

    if not player then return end

    -- 관전 중이면 불가
    if player.spectating then
        TriggerClientEvent('minigames:client:notify', src, '관전 중에는 준비할 수 없습니다.')
        return
    end

    -- 게임 진행 중이면 불가
    if CurrentRound.state ~= GameModes.States.WAITING then
        TriggerClientEvent('minigames:client:notify', src, '게임 진행 중에는 준비 상태를 변경할 수 없습니다.')
        return
    end

    -- 준비 상태 토글
    player.ready = not player.ready

    -- 모든 플레이어에게 업데이트
    TriggerClientEvent('minigames:client:playerReadyUpdate', -1, src, player.ready)

    Utils.Debug('Player ' .. player.name .. ' ready status: ' .. tostring(player.ready))
end)

-- 관전 상태 토글
RegisterNetEvent('minigames:server:toggleSpectate', function()
    local src = source
    local player = GetPlayer(src)

    if not player then return end

    -- 게임 진행 중이면 불가
    if CurrentRound.state == GameModes.States.PLAYING then
        TriggerClientEvent('minigames:client:notify', src, '게임 진행 중에는 관전 상태를 변경할 수 없습니다.')
        return
    end

    -- 관전 상태 토글
    player.spectating = not player.spectating

    -- 관전 시작 시 준비 해제
    if player.spectating then
        player.ready = false
    end

    -- 모든 플레이어에게 업데이트
    TriggerClientEvent('minigames:client:playerSpectateUpdate', -1, src, player.spectating)

    -- 클라이언트에 관전 모드 토글
    TriggerClientEvent('minigames:client:setSpectateMode', src, player.spectating)

    Utils.Debug('Player ' .. player.name .. ' spectate status: ' .. tostring(player.spectating))
end)

-- 플레이어 사망 처리
RegisterNetEvent('minigames:server:playerDied', function()
    local src = source
    local player = GetPlayer(src)

    if not player then return end

    player.state = GameModes.PlayerStates.DEAD
    player.stats.deaths = player.stats.deaths + 1

    -- 모든 플레이어에게 사망 알림
    TriggerClientEvent('minigames:client:playerDied', -1, src, player.name)

    -- 게임 종료 조건 체크
    CheckGameEndCondition()

    Utils.Debug('Player ' .. player.name .. ' died')
end)

-- 플레이어 킬 처리
RegisterNetEvent('minigames:server:playerKill', function(victimId)
    local src = source
    local killer = GetPlayer(src)
    local victim = GetPlayer(victimId)

    if not killer or not victim then return end

    killer.stats.kills = killer.stats.kills + 1

    -- 모든 플레이어에게 킬 알림
    TriggerClientEvent('minigames:client:playerKill', -1, src, killer.name, victimId, victim.name)

    Utils.Debug('Player ' .. killer.name .. ' killed ' .. victim.name)
end)

-- 게임 종료 조건 체크
function CheckGameEndCondition()
    if CurrentRound.state ~= GameModes.States.PLAYING then return end

    local alivePlayers = GetPlayingPlayersCount()

    -- 게임모드별 종료 조건
    if CurrentRound.gamemode then
        local gamemodeId = CurrentRound.gamemode.id

        -- 범퍼카, 무기 모드: 1명 이하 남으면 종료
        if gamemodeId == "bumpercar" or gamemodeId == "weapon" then
            if alivePlayers <= 1 then
                EndRound()
            end
        end

        -- 폭탄, 보스 모드: 특수 처리는 게임모드 파일에서
    end
end

-- 플레이어 레벨업
function LevelUpPlayer(src, level)
    local player = GetPlayer(src)
    if not player then return end

    player.level = level

    TriggerClientEvent('minigames:client:levelUp', src, level)
    TriggerClientEvent('minigames:client:notify', src, '레벨업! 현재 레벨: ' .. level)

    Utils.Debug('Player ' .. player.name .. ' leveled up to ' .. level)
end

-- 플레이어 랭크 설정
function SetPlayerRank(src, rank)
    local player = GetPlayer(src)
    if not player then return end

    player.rank = rank

    TriggerClientEvent('minigames:client:rankUpdate', src, rank)
    TriggerClientEvent('minigames:client:notify', src, '랭크 변경: ' .. Config.Ranks[rank].name)

    Utils.Debug('Player ' .. player.name .. ' rank set to ' .. rank)
end

-- 관리자 명령: 플레이어 랭크 설정
RegisterCommand('setrank', function(source, args)
    if source == 0 then -- 콘솔
        local targetId = tonumber(args[1])
        local rank = tonumber(args[2])

        if not targetId or not rank then
            print('Usage: setrank <playerId> <rank>')
            return
        end

        if not Config.Ranks[rank] then
            print('Invalid rank')
            return
        end

        SetPlayerRank(targetId, rank)
        print('Set player ' .. targetId .. ' rank to ' .. rank)
    else
        -- TODO: 권한 체크
        TriggerClientEvent('minigames:client:notify', source, '권한이 없습니다.')
    end
end, false)

Utils.Info('Player management loaded')
