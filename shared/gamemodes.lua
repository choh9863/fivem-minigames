-- 게임모드 공유 데이터 및 함수

GameModes = {}

-- 게임모드 상태
GameModes.States = {
    WAITING = 0,    -- 대기 중
    PREPARE = 1,    -- 준비 중
    PLAYING = 2,    -- 게임 진행 중
    ENDING = 3      -- 종료 중
}

-- 플레이어 상태
GameModes.PlayerStates = {
    LOBBY = 0,      -- 로비
    SPECTATING = 1, -- 관전
    READY = 2,      -- 준비 완료
    PLAYING = 3,    -- 게임 중
    DEAD = 4        -- 사망
}

-- 아이템 타입
GameModes.ItemTypes = {
    INSTANT = "instant",  -- 즉발형
    ACTIVE = "active"     -- 액티브형
}

-- 게임모드별 초기화 함수 (오버라이드 가능)
GameModes.Initialize = {
    bumpercar = function()
        -- 범퍼카 모드 초기화
    end,

    bomb = function()
        -- 폭탄 모드 초기화
    end,

    avalanche = function()
        -- 아발란체 모드 초기화
    end,

    boss = function()
        -- 보스 모드 초기화
    end,

    weapon = function()
        -- 무기 모드 초기화
    end
}

return GameModes
