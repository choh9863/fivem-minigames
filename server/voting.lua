-- ========================================
-- VOTING SYSTEM
-- ========================================

-- 게임모드 투표
RegisterNetEvent('minigames:server:voteGamemode', function(gamemodeId)
    local src = source
    local player = GetPlayer(src)

    if not player then return end

    -- 관전 중이면 투표 불가
    if player.spectating then
        TriggerClientEvent('minigames:client:notify', src, '관전 중에는 투표할 수 없습니다.')
        return
    end

    -- 게임 진행 중이면 투표 불가
    if CurrentRound.state ~= GameModes.States.WAITING then
        TriggerClientEvent('minigames:client:notify', src, '게임 진행 중에는 투표할 수 없습니다.')
        return
    end

    -- 게임모드 유효성 검사
    local gamemode = Utils.GetGamemodeById(gamemodeId)
    if not gamemode then
        TriggerClientEvent('minigames:client:notify', src, '잘못된 게임모드입니다.')
        return
    end

    -- 기존 투표 제거
    for gmId, voters in pairs(CurrentRound.votes.gamemode) do
        for i, voter in ipairs(voters) do
            if voter == src then
                table.remove(CurrentRound.votes.gamemode[gmId], i)
                break
            end
        end
    end

    -- 새 투표 추가
    if not CurrentRound.votes.gamemode[gamemodeId] then
        CurrentRound.votes.gamemode[gamemodeId] = {}
    end
    table.insert(CurrentRound.votes.gamemode[gamemodeId], src)

    -- 모든 플레이어에게 투표 업데이트
    TriggerClientEvent('minigames:client:updateVotes', -1, CurrentRound.votes)

    Utils.Debug('Player ' .. player.name .. ' voted for gamemode: ' .. gamemodeId)
end)

-- 맵 투표
RegisterNetEvent('minigames:server:voteMap', function(mapId)
    local src = source
    local player = GetPlayer(src)

    if not player then return end

    -- 관전 중이면 투표 불가
    if player.spectating then
        TriggerClientEvent('minigames:client:notify', src, '관전 중에는 투표할 수 없습니다.')
        return
    end

    -- 게임 진행 중이면 투표 불가
    if CurrentRound.state ~= GameModes.States.WAITING then
        TriggerClientEvent('minigames:client:notify', src, '게임 진행 중에는 투표할 수 없습니다.')
        return
    end

    -- 맵 유효성 검사 (모든 게임모드에서 검색)
    local mapExists = false
    for _, maps in pairs(Config.Maps) do
        for _, map in ipairs(maps) do
            if map.id == mapId then
                mapExists = true
                break
            end
        end
        if mapExists then break end
    end

    if not mapExists then
        TriggerClientEvent('minigames:client:notify', src, '잘못된 맵입니다.')
        return
    end

    -- 기존 투표 제거
    for mId, voters in pairs(CurrentRound.votes.map) do
        for i, voter in ipairs(voters) do
            if voter == src then
                table.remove(CurrentRound.votes.map[mId], i)
                break
            end
        end
    end

    -- 새 투표 추가
    if not CurrentRound.votes.map[mapId] then
        CurrentRound.votes.map[mapId] = {}
    end
    table.insert(CurrentRound.votes.map[mapId], src)

    -- 모든 플레이어에게 투표 업데이트
    TriggerClientEvent('minigames:client:updateVotes', -1, CurrentRound.votes)

    Utils.Debug('Player ' .. player.name .. ' voted for map: ' .. mapId)
end)

-- 투표 초기화
function ResetVotes()
    CurrentRound.votes.gamemode = {}
    CurrentRound.votes.map = {}

    TriggerClientEvent('minigames:client:updateVotes', -1, CurrentRound.votes)

    Utils.Debug('Votes reset')
end

-- 투표 결과 가져오기
function GetVoteResults()
    local results = {
        gamemode = {},
        map = {}
    }

    -- 게임모드 투표 집계
    for gamemodeId, voters in pairs(CurrentRound.votes.gamemode) do
        results.gamemode[gamemodeId] = #voters
    end

    -- 맵 투표 집계
    for mapId, voters in pairs(CurrentRound.votes.map) do
        results.map[mapId] = #voters
    end

    return results
end

Utils.Info('Voting system loaded')
