# FiveM Minigames Server

TheIvaneh의 미니게임 서버에서 영감을 받은 GTA 5 FiveM용 멀티플레이어 미니게임 모드입니다.

## 📋 개요

다양한 미니게임 모드를 플레이할 수 있는 FiveM 리소스로, 로비 시스템, 투표 시스템, 5가지 게임 모드를 포함합니다.

## 🎮 게임 모드

### 1. 범퍼카 (Bumper Car)
- 차량으로 서로 충돌하여 마지막까지 살아남는 배틀로얄 게임
- 다양한 아이템 시스템 (미사일, 부스트, 쉴드 등)
- 서든 데스 시스템
- 맵 경계 시스템

### 2. 폭탄 (Bomb)
- 폭탄을 다른 플레이어에게 전달하여 생존하는 게임
- 시간이 지날수록 폭탄 타이머 감소
- 폭발 시 새로운 플레이어에게 폭탄 부착

### 3. 아발란체 (Avalanche)
- 경사로를 올라가며 떨어지는 차량을 피하는 게임
- 제한 시간 내 골인 지점 도달 시 승리
- 점점 빨라지는 차량 스폰

### 4. 보스 (Boss)
- 1명의 보스 vs 나머지 플레이어
- 보스: 강력한 차량으로 모든 플레이어 제거
- 플레이어: 제한 시간 동안 생존

### 5. 무기 (Weapon)
- 차량에 장착된 무기로 전투하는 게임
- 다양한 무기 (대구경포, 미사일, 미니건 등)
- 무기 교체 시스템
- 서든 데스 시스템

## 🚀 설치 방법

1. 이 리포지토리를 FiveM 서버의 `resources` 폴더에 클론:
```bash
cd resources
git clone https://github.com/yourusername/fivem-minigames.git
```

2. `server.cfg`에 리소스 추가:
```
ensure fivem-minigames
```

3. 서버 재시작

## 📁 프로젝트 구조

```
fivem-minigames/
├── fxmanifest.lua          # FiveM 리소스 매니페스트
├── shared/                 # 공유 스크립트
│   ├── config.lua          # 게임 설정
│   ├── utils.lua           # 유틸리티 함수
│   └── gamemodes.lua       # 게임모드 정의
├── server/                 # 서버 스크립트
│   ├── main.lua            # 서버 메인
│   ├── player.lua          # 플레이어 관리
│   ├── lobby.lua           # 로비 시스템
│   ├── round.lua           # 라운드 관리
│   ├── voting.lua          # 투표 시스템
│   └── gamemodes/          # 게임모드별 서버 로직
│       ├── bumpercar.lua
│       ├── bomb.lua
│       ├── avalanche.lua
│       ├── boss.lua
│       └── weapon.lua
├── client/                 # 클라이언트 스크립트
│   ├── main.lua            # 클라이언트 메인
│   ├── lobby.lua           # 로비 클라이언트
│   ├── round.lua           # 라운드 클라이언트
│   ├── hud.lua             # HUD 시스템
│   ├── camera.lua          # 카메라/관전 시스템
│   ├── vehicle.lua         # 차량 시스템
│   ├── items.lua           # 아이템 시스템
│   └── gamemodes/          # 게임모드별 클라이언트 로직
│       ├── bumpercar.lua
│       ├── bomb.lua
│       ├── avalanche.lua
│       ├── boss.lua
│       └── weapon.lua
└── html/                   # NUI (웹 인터페이스)
    ├── index.html          # 메인 HTML
    ├── css/
    │   └── lobby.css       # 로비 스타일
    ├── js/
    │   └── lobby.js        # 로비 JavaScript
    └── img/                # 이미지 에셋
        ├── gamemodes/      # 게임모드 이미지
        ├── maps/           # 맵 이미지
        └── ranks/          # 랭크 아이콘
```

## ⚙️ 설정

### 기본 설정 (`shared/config.lua`)

```lua
Config.MinPlayers = 2           -- 최소 플레이어 수
Config.MaxPlayers = 32          -- 최대 플레이어 수
Config.RequiredReadyPercentage = 0.5  -- 게임 시작 최소 준비 비율

Config.Round = {
    WaitingTime = 60,   -- 대기 시간 (초)
    PrepareTime = 30,   -- 준비 시간 (초)
    EndTime = 30        -- 종료 시간 (초)
}
```

### 게임모드별 설정

각 게임모드는 `Config.BumperCar`, `Config.Bomb` 등에서 설정 가능:
- 차량 스탯 (체력, 방어력, 속도, 데미지)
- 아이템 효과 및 밸런스
- 라운드 시간
- 특수 규칙

### 맵 설정

`Config.Maps`에서 각 게임모드별 맵 추가 가능:
```lua
Config.Maps.bumpercar = {
    {
        id = "bumpercar_arena",
        name = "아레나",
        spawns = { ... },    -- 스폰 위치
        boundary = { ... },  -- 맵 경계
        itemSpawns = { ... } -- 아이템 스폰 위치
    }
}
```

## 🎨 이미지 에셋

다음 이미지들을 `/html/img/` 폴더에 추가해야 합니다:

### 게임모드 이미지 (`/img/gamemodes/`)
- `bumpercar.png` - 범퍼카
- `bomb.png` - 폭탄
- `avalanche.png` - 아발란체
- `boss.png` - 보스
- `weapon.png` - 무기

권장 크기: 480x270px (16:9 비율)

### 맵 이미지 (`/img/maps/`)
- `bumpercar_arena.png`
- `bomb_city.png`
- `avalanche_mountain.png`
- `boss_stadium.png`
- `weapon_warzone.png`

권장 크기: 480x270px

### 랭크 아이콘 (`/img/ranks/`)
- `newbie.png`
- `bronze.png`
- `silver.png`
- `gold.png`
- `platinum.png`
- `diamond.png`
- `master.png`
- `admin.png`

권장 크기: 64x64px

## 🎯 주요 기능

### 로비 시스템
- GTA 5 바닐라 스타일 UI
- 플레이어 리스트 (이름, 랭크, 레벨)
- 준비/관전 시스템
- 게임모드 및 맵 투표
- 실시간 채팅
- 자동 게임 시작

### 라운드 시스템
- 4단계 라운드 (대기 → 준비 → 진행 → 종료)
- 자동 타이머 관리
- 승자 결정 및 통계

### 차량 시스템
- 차량별 다른 스탯 (체력, 속도, 데미지)
- 충돌 데미지 계산
- 차량 효과 (부스트, 크기 변경 등)

### 아이템 시스템 (범퍼카/무기 모드)
- 3개 아이템 슬롯
- 즉발형/액티브형 아이템
- 다양한 아이템 효과

### 관전 시스템
- 자유 관전 모드
- 플레이어 간 전환 (좌/우 화살표)
- 자동 타겟 업데이트

## 🔧 테스트 명령어

```
/testlobby   -- 로비 UI 테스트 (클라이언트)
/closelobby  -- 로비 닫기 (클라이언트)
/setrank <playerId> <rank>  -- 플레이어 랭크 설정 (서버 콘솔)
```

## 📝 개발자 정보

### 이벤트 목록

**서버 → 클라이언트:**
- `minigames:client:initialize` - 플레이어 초기화
- `minigames:client:roundPrepare` - 라운드 준비
- `minigames:client:roundPlaying` - 라운드 진행
- `minigames:client:roundEnding` - 라운드 종료
- `minigames:client:updateTimer` - 타이머 업데이트
- `minigames:client:spawnVehicle` - 차량 생성

**클라이언트 → 서버:**
- `minigames:server:toggleReady` - 준비 상태 토글
- `minigames:server:toggleSpectate` - 관전 상태 토글
- `minigames:server:voteGamemode` - 게임모드 투표
- `minigames:server:voteMap` - 맵 투표
- `minigames:server:sendChatMessage` - 채팅 메시지
- `minigames:server:useItem` - 아이템 사용

### 전역 변수

**서버:**
```lua
Players          -- 플레이어 데이터 테이블
CurrentRound     -- 현재 라운드 정보
```

**클라이언트:**
```lua
LocalPlayer      -- 로컬 플레이어 정보
CurrentRound     -- 현재 라운드 정보
```

**공유:**
```lua
Config           -- 게임 설정
Utils            -- 유틸리티 함수
GameModes        -- 게임모드 정의
```

## 🐛 알려진 문제

1. 차량 스케일 변경 (크기 조절) 기능은 FiveM 제한으로 시각적 효과만 제공
2. 대량의 발사체 생성 시 성능 저하 가능
3. 일부 맵에서 경계 설정 필요

## 🚧 향후 계획

- [ ] 더 많은 게임모드 추가
- [ ] 레벨/경험치 시스템
- [ ] 데이터베이스 연동 (통계 저장)
- [ ] 커스텀 차량 스킨
- [ ] 시즌/랭크 시스템
- [ ] 업적 시스템

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 🙏 크레딧

- TheIvaneh - 오리지널 미니게임 서버 컨셉
- FiveM Community - 개발 도구 및 문서
