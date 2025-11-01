Config = {}

-- ========================================
-- GENERAL SETTINGS
-- ========================================
Config.MinPlayers = 1 -- 게임 시작을 위한 최소 플레이어 수
Config.MaxPlayers = 32 -- 최대 플레이어 수
Config.RequiredReadyPercentage = 0.5 -- 과반수 (50%)

-- ========================================
-- ROUND SETTINGS
-- ========================================
Config.Round = {
    WaitingTime = 60, -- 대기 시간 (초)
    PrepareTime = 30, -- 준비 시간 (초)
    EndTime = 30, -- 종료 시간 (초)
    ForceStartTime = 120 -- 강제 시작 시간 (일정 인원 모였을 때)
}

-- ========================================
-- SPAWN SETTINGS
-- ========================================
Config.SpawnLocation = vector4(-75.0, -818.0, 326.0, 0.0) -- 로비 스폰 위치

-- ========================================
-- RANK SYSTEM
-- ========================================
Config.Ranks = {
    [1] = {
        name = "Newbie",
        image = "img/ranks/newbie.png"
    },
    [2] = {
        name = "Bronze",
        image = "img/ranks/bronze.png"
    },
    [3] = {
        name = "Silver",
        image = "img/ranks/silver.png"
    },
    [4] = {
        name = "Gold",
        image = "img/ranks/gold.png"
    },
    [5] = {
        name = "Platinum",
        image = "img/ranks/platinum.png"
    },
    [6] = {
        name = "Diamond",
        image = "img/ranks/diamond.png"
    },
    [7] = {
        name = "Master",
        image = "img/ranks/master.png"
    },
    [8] = {
        name = "Admin",
        image = "img/ranks/admin.png"
    }
}

-- ========================================
-- GAMEMODE DEFINITIONS
-- ========================================
Config.Gamemodes = {
    {
        id = "bumpercar",
        name = "범퍼카",
        description = "차량으로 서로 충돌하여 마지막까지 살아남는 플레이어가 승리합니다.",
        image = "img/gamemodes/bumpercar.png",
        minPlayers = 2,
        maxPlayers = 16,
        roundTime = 300, -- 5분
        suddenDeathTime = 240 -- 4분 후 서든데스
    },
    {
        id = "bomb",
        name = "폭탄",
        description = "폭탄을 다른 플레이어에게 전달하여 생존하세요.",
        image = "img/gamemodes/bomb.png",
        minPlayers = 2,
        maxPlayers = 16,
        roundTime = 180, -- 3분
        bombTimer = 15 -- 폭탄 폭발 시간
    },
    {
        id = "avalanche",
        name = "아발란체",
        description = "경사로를 올라가며 떨어지는 차량들을 피하세요.",
        image = "img/gamemodes/avalanche.png",
        minPlayers = 1,
        maxPlayers = 16,
        roundTime = 120, -- 2분
        spawnInterval = 2 -- 차량 스폰 간격 (초)
    },
    {
        id = "boss",
        name = "보스",
        description = "보스 차량을 피해 살아남거나, 보스가 되어 모두를 제거하세요.",
        image = "img/gamemodes/boss.png",
        minPlayers = 3,
        maxPlayers = 16,
        roundTime = 180 -- 3분
    },
    {
        id = "weapon",
        name = "무기",
        description = "차량 무기로 다른 플레이어를 모두 제거하세요.",
        image = "img/gamemodes/weapon.png",
        minPlayers = 2,
        maxPlayers = 16,
        roundTime = 300, -- 5분
        suddenDeathTime = 240 -- 4분 후 서든데스
    }
}

-- ========================================
-- MAP DEFINITIONS
-- ========================================
Config.Maps = {
    -- 범퍼카 맵
    bumpercar = {
        {
            id = "bumpercar_arena",
            name = "아레나",
            gamemode = "bumpercar",
            image = "img/maps/bumpercar_arena.png",
            spawns = {
                vector4(0.0, 0.0, 75.0, 0.0),
                vector4(10.0, 10.0, 75.0, 90.0),
                vector4(-10.0, 10.0, 75.0, 180.0),
                vector4(-10.0, -10.0, 75.0, 270.0)
            },
            boundary = {
                enabled = true,
                center = vector3(0.0, 0.0, 75.0),
                radius = 100.0
            },
            itemSpawns = {
                vector3(20.0, 20.0, 75.0),
                vector3(-20.0, 20.0, 75.0),
                vector3(20.0, -20.0, 75.0),
                vector3(-20.0, -20.0, 75.0)
            }
        }
    },

    -- 폭탄 맵
    bomb = {
        {
            id = "bomb_city",
            name = "도시",
            gamemode = "bomb",
            image = "img/maps/bomb_city.png",
            spawns = {
                vector4(100.0, 100.0, 75.0, 0.0),
                vector4(110.0, 110.0, 75.0, 90.0)
            },
            boundary = {
                enabled = true,
                center = vector3(100.0, 100.0, 75.0),
                radius = 150.0
            }
        }
    },

    -- 아발란체 맵
    avalanche = {
        {
            id = "avalanche_mountain",
            name = "산",
            gamemode = "avalanche",
            image = "img/maps/avalanche_mountain.png",
            spawns = {
                vector4(200.0, 200.0, 50.0, 0.0)
            },
            finishLine = vector3(200.0, 200.0, 150.0),
            vehicleSpawnPoint = vector3(200.0, 200.0, 160.0)
        }
    },

    -- 보스 맵
    boss = {
        {
            id = "boss_stadium",
            name = "스타디움",
            gamemode = "boss",
            image = "img/maps/boss_stadium.png",
            spawns = {
                vector4(300.0, 300.0, 75.0, 0.0)
            },
            bossSpawn = vector4(300.0, 300.0, 75.0, 180.0)
        }
    },

    -- 무기 맵
    weapon = {
        {
            id = "weapon_warzone",
            name = "워존",
            gamemode = "weapon",
            image = "img/maps/weapon_warzone.png",
            spawns = {
                vector4(400.0, 400.0, 75.0, 0.0)
            },
            weaponSpawns = {
                vector3(420.0, 420.0, 75.0),
                vector3(380.0, 420.0, 75.0)
            }
        }
    }
}

-- ========================================
-- BUMPERCAR MODE SETTINGS
-- ========================================
Config.BumperCar = {
    Vehicles = {
        {
            model = "bison",
            health = 1000,
            defense = 10,
            speed = 1.0,
            damage = 50
        },
        {
            model = "tornado",
            health = 800,
            defense = 5,
            speed = 1.2,
            damage = 40
        },
        {
            model = "rhapsody",
            health = 1200,
            defense = 15,
            speed = 0.8,
            damage = 60
        }
    },

    Items = {
        {
            id = "repair",
            name = "차량 수리",
            type = "instant", -- instant or active
            effect = "repair",
            value = 200,
            icon = "img/items/repair.png"
        },
        {
            id = "random_vehicle",
            name = "무작위 차량",
            type = "instant",
            effect = "random_vehicle",
            icon = "img/items/random_vehicle.png"
        },
        {
            id = "boost",
            name = "부스트",
            type = "active",
            effect = "boost",
            duration = 5,
            speedMultiplier = 2.0,
            icon = "img/items/boost.png",
            slot = true
        },
        {
            id = "jump",
            name = "점프",
            type = "active",
            effect = "jump",
            force = 20.0,
            icon = "img/items/jump.png",
            slot = true
        },
        {
            id = "shrink",
            name = "차량 축소",
            type = "instant",
            effect = "shrink",
            duration = 10,
            scale = 0.7,
            icon = "img/items/shrink.png"
        },
        {
            id = "missile",
            name = "일반 미사일",
            type = "active",
            effect = "missile",
            damage = 150,
            icon = "img/items/missile.png",
            slot = true,
            targeting = false
        },
        {
            id = "homing_missile",
            name = "유도 미사일",
            type = "active",
            effect = "homing_missile",
            damage = 200,
            icon = "img/items/homing_missile.png",
            slot = true,
            targeting = true
        },
        {
            id = "knockback",
            name = "넉백",
            type = "active",
            effect = "knockback",
            radius = 20.0,
            force = 50.0,
            icon = "img/items/knockback.png",
            slot = true
        },
        {
            id = "defense_boost",
            name = "방어력 증가",
            type = "instant",
            effect = "defense",
            duration = 15,
            defenseBonus = 20,
            icon = "img/items/defense.png"
        },
        {
            id = "damage_boost",
            name = "데미지 증가",
            type = "instant",
            effect = "damage",
            duration = 15,
            damageMultiplier = 1.5,
            icon = "img/items/damage.png"
        },
        {
            id = "shield",
            name = "쉴드",
            type = "instant",
            effect = "shield",
            shieldHealth = 300,
            icon = "img/items/shield.png"
        }
    }
}

-- ========================================
-- BOMB MODE SETTINGS
-- ========================================
Config.Bomb = {
    InitialTimer = 15,
    MinTimer = 5,
    TimerDecrease = 1, -- 라운드마다 감소
    TransferCooldown = 1 -- 폭탄 전달 후 쿨다운
}

-- ========================================
-- AVALANCHE MODE SETTINGS
-- ========================================
Config.Avalanche = {
    Vehicles = {
        "bison",
        "tornado",
        "blista",
        "dilettante",
        "emperor"
    },
    SpawnInterval = 2, -- 차량 스폰 간격 (초)
    VehicleSpeed = 50.0 -- 떨어지는 차량 속도
}

-- ========================================
-- BOSS MODE SETTINGS
-- ========================================
Config.Boss = {
    BossVehicle = {
        model = "monster",
        health = 5000,
        speed = 1.5,
        damage = 999 -- 원킬
    },
    PlayerVehicles = {
        "blista",
        "dilettante",
        "emperor"
    }
}

-- ========================================
-- WEAPON MODE SETTINGS
-- ========================================
Config.Weapon = {
    Vehicles = {
        {
            model = "bison",
            health = 1000,
            weapons = {
                -- 무기별 부착 위치 (차량 본 기준 오프셋)
                cannon = {offset = vector3(0.0, 2.5, 0.5), rotation = vector3(0.0, 0.0, 0.0)},
                minigun = {offset = vector3(0.0, 2.0, 0.3), rotation = vector3(0.0, 0.0, 0.0)},
                machinegun = {offset = vector3(0.0, 2.2, 0.4), rotation = vector3(0.0, 0.0, 0.0)},
                homing_missile = {offset = vector3(0.0, 2.0, 0.6), rotation = vector3(0.0, 0.0, 0.0)},
                pistol = {offset = vector3(0.0, 1.8, 0.3), rotation = vector3(0.0, 0.0, 0.0)},
                shotgun = {offset = vector3(0.0, 2.0, 0.4), rotation = vector3(0.0, 0.0, 0.0)},
                sniper = {offset = vector3(0.0, 2.3, 0.5), rotation = vector3(0.0, 0.0, 0.0)},
                smg = {offset = vector3(0.0, 1.9, 0.3), rotation = vector3(0.0, 0.0, 0.0)},
                missile = {offset = vector3(0.0, 2.1, 0.5), rotation = vector3(0.0, 0.0, 0.0)}
            }
        },
        {
            model = "tornado",
            health = 800,
            weapons = {
                cannon = {offset = vector3(0.0, 2.3, 0.4), rotation = vector3(0.0, 0.0, 0.0)},
                minigun = {offset = vector3(0.0, 1.8, 0.2), rotation = vector3(0.0, 0.0, 0.0)},
                machinegun = {offset = vector3(0.0, 2.0, 0.3), rotation = vector3(0.0, 0.0, 0.0)},
                homing_missile = {offset = vector3(0.0, 1.9, 0.5), rotation = vector3(0.0, 0.0, 0.0)},
                pistol = {offset = vector3(0.0, 1.7, 0.2), rotation = vector3(0.0, 0.0, 0.0)},
                shotgun = {offset = vector3(0.0, 1.9, 0.3), rotation = vector3(0.0, 0.0, 0.0)},
                sniper = {offset = vector3(0.0, 2.1, 0.4), rotation = vector3(0.0, 0.0, 0.0)},
                smg = {offset = vector3(0.0, 1.8, 0.2), rotation = vector3(0.0, 0.0, 0.0)},
                missile = {offset = vector3(0.0, 2.0, 0.4), rotation = vector3(0.0, 0.0, 0.0)}
            }
        }
    },

    Weapons = {
        {
            id = "cannon",
            name = "대구경포",
            model = "prop_minigun_01", -- 무기 프롭 모델
            projectileModel = "w_ex_grenade", -- 발사체 모델
            damage = 100,
            fireRate = 1.0, -- 초당 발사 횟수
            projectileSpeed = 100.0,
            ammo = 50,
            maxAmmo = 50,
            reloadTime = 3000, -- 밀리초
            hasGravity = true,
            explosionType = 2, -- GTA 폭발 타입
            projectileScale = 0.3
        },
        {
            id = "minigun",
            name = "미니건",
            model = "prop_minigun_01",
            projectileModel = "prop_ld_ammo_pack_01", -- 작은 탄환
            damage = 30,
            fireRate = 10.0,
            projectileSpeed = 150.0,
            ammo = 500,
            maxAmmo = 500,
            reloadTime = 5000,
            hasGravity = false,
            explosionType = 0, -- 폭발 없음
            projectileScale = 0.1
        },
        {
            id = "homing_missile",
            name = "유도미사일",
            model = "w_lr_rpg",
            projectileModel = "w_lr_rpg_rocket",
            damage = 250,
            fireRate = 0.3,
            projectileSpeed = 80.0,
            ammo = 10,
            maxAmmo = 10,
            reloadTime = 7000,
            hasGravity = false,
            homing = true, -- 유도 기능
            homingSpeed = 5.0,
            explosionType = 5, -- 큰 폭발
            projectileScale = 0.5
        },
        {
            id = "pistol",
            name = "권총",
            model = "w_pi_pistol",
            projectileModel = "prop_ld_ammo_pack_01",
            damage = 20,
            fireRate = 3.0,
            projectileSpeed = 120.0,
            ammo = 100,
            maxAmmo = 100,
            reloadTime = 1500,
            hasGravity = false,
            explosionType = 0,
            projectileScale = 0.08
        },
        {
            id = "machinegun",
            name = "기관총",
            model = "w_ar_assaultrifle",
            projectileModel = "prop_ld_ammo_pack_01",
            damage = 40,
            fireRate = 5.0,
            projectileSpeed = 140.0,
            ammo = 200,
            maxAmmo = 200,
            reloadTime = 3000,
            hasGravity = false,
            explosionType = 0,
            projectileScale = 0.12
        },
        {
            id = "smg",
            name = "기관단총",
            model = "w_smg_smg",
            projectileModel = "prop_ld_ammo_pack_01",
            damage = 25,
            fireRate = 7.0,
            projectileSpeed = 130.0,
            ammo = 150,
            maxAmmo = 150,
            reloadTime = 2000,
            hasGravity = false,
            explosionType = 0,
            projectileScale = 0.1
        },
        {
            id = "shotgun",
            name = "샷건",
            model = "w_sg_pumpshotgun",
            projectileModel = "prop_ld_ammo_pack_01",
            damage = 80,
            fireRate = 1.5,
            projectileSpeed = 110.0,
            ammo = 30,
            maxAmmo = 30,
            reloadTime = 2500,
            hasGravity = false,
            explosionType = 0,
            spread = true, -- 산탄 효과
            spreadCount = 5,
            spreadAngle = 5.0,
            projectileScale = 0.15
        },
        {
            id = "sniper",
            name = "저격총",
            model = "w_sr_sniperrifle",
            projectileModel = "prop_ld_ammo_pack_01",
            damage = 150,
            fireRate = 0.5,
            projectileSpeed = 200.0,
            ammo = 20,
            maxAmmo = 20,
            reloadTime = 2000,
            hasGravity = false,
            explosionType = 0,
            projectileScale = 0.2
        },
        {
            id = "missile",
            name = "미사일",
            model = "w_lr_rpg",
            projectileModel = "w_lr_rpg_rocket",
            damage = 200,
            fireRate = 0.3,
            projectileSpeed = 90.0,
            ammo = 10,
            maxAmmo = 10,
            reloadTime = 5000,
            hasGravity = true,
            explosionType = 4, -- 중형 폭발
            projectileScale = 0.4
        }
    }
}
