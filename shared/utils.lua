Utils = {}

-- 테이블 복사
function Utils.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils.DeepCopy(orig_key)] = Utils.DeepCopy(orig_value)
        end
        setmetatable(copy, Utils.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- 거리 계산
function Utils.GetDistance(pos1, pos2)
    if type(pos1) == "vector3" and type(pos2) == "vector3" then
        return #(pos1 - pos2)
    elseif type(pos1) == "vector4" and type(pos2) == "vector4" then
        return #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
    end
    return 0.0
end

-- 2D 거리 계산 (높이 무시)
function Utils.GetDistance2D(pos1, pos2)
    local p1 = type(pos1) == "vector4" and vector2(pos1.x, pos1.y) or vector2(pos1.x, pos1.y)
    local p2 = type(pos2) == "vector4" and vector2(pos2.x, pos2.y) or vector2(pos2.x, pos2.y)
    return #(p1 - p2)
end

-- 랜덤 테이블 요소 가져오기
function Utils.GetRandomElement(tbl)
    if #tbl == 0 then return nil end
    return tbl[math.random(#tbl)]
end

-- 테이블 셔플
function Utils.ShuffleTable(tbl)
    local shuffled = Utils.DeepCopy(tbl)
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end

-- 테이블에서 값 찾기
function Utils.TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- 테이블 크기
function Utils.TableSize(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- 시간 포맷 (초 -> MM:SS)
function Utils.FormatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", minutes, secs)
end

-- 퍼센트 계산
function Utils.Percentage(value, max)
    if max == 0 then return 0 end
    return (value / max) * 100
end

-- 게임모드 ID로 게임모드 찾기
function Utils.GetGamemodeById(id)
    for _, gamemode in ipairs(Config.Gamemodes) do
        if gamemode.id == id then
            return gamemode
        end
    end
    return nil
end

-- 맵 ID로 맵 찾기
function Utils.GetMapById(gamemodeId, mapId)
    if not Config.Maps[gamemodeId] then return nil end

    for _, map in ipairs(Config.Maps[gamemodeId]) do
        if map.id == mapId then
            return map
        end
    end
    return nil
end

-- 랭크 정보 가져오기
function Utils.GetRankInfo(rankId)
    return Config.Ranks[rankId] or Config.Ranks[1]
end

-- Vector4를 Vector3로 변환
function Utils.Vec4ToVec3(vec4)
    return vector3(vec4.x, vec4.y, vec4.z)
end

-- 각도 정규화 (0-360)
function Utils.NormalizeAngle(angle)
    while angle < 0 do
        angle = angle + 360
    end
    while angle >= 360 do
        angle = angle - 360
    end
    return angle
end

-- 벡터 회전
function Utils.RotateVector(vec, angle)
    local rad = math.rad(angle)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    return vector3(
        vec.x * cos - vec.y * sin,
        vec.x * sin + vec.y * cos,
        vec.z
    )
end

-- 디버그 출력
function Utils.Debug(...)
    if GetConvar('minigames_debug', 'false') == 'true' then
        print('^3[Minigames Debug]^7', ...)
    end
end

-- 에러 출력
function Utils.Error(...)
    print('^1[Minigames Error]^7', ...)
end

-- 정보 출력
function Utils.Info(...)
    print('^2[Minigames Info]^7', ...)
end

return Utils
