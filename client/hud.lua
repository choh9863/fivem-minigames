-- ========================================
-- HUD SYSTEM
-- ========================================

local HudData = {
    visible = false,
    type = nil, -- bumpercar, bomb, avalanche, boss, weapon
    elements = {}
}

-- HUD 표시
function ShowHud(hudType)
    HudData.visible = true
    HudData.type = hudType
    HudData.elements = {}

    -- NUI로 HUD 표시 이벤트 전송
    SendNUIMessage({
        action = 'showHud',
        hudType = hudType
    })

    Utils.Debug('HUD shown: ' .. hudType)
end

-- HUD 숨기기
function HideHud()
    HudData.visible = false
    HudData.type = nil
    HudData.elements = {}

    SendNUIMessage({
        action = 'hideHud'
    })

    Utils.Debug('HUD hidden')
end

-- HUD 업데이트
function UpdateHud(elements)
    if not HudData.visible then return end

    HudData.elements = elements

    SendNUIMessage({
        action = 'updateHud',
        elements = elements
    })
end

-- 차량 HUD 업데이트 (범퍼카, 아발란체, 보스, 무기 모드)
function UpdateVehicleHud(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local health = GetVehicleEngineHealth(vehicle)
    local maxHealth = 1000.0
    local healthPercent = (health / maxHealth) * 100

    local speed = GetEntitySpeed(vehicle) * 3.6 -- m/s to km/h

    UpdateHud({
        vehicleHealth = math.max(0, healthPercent),
        vehicleSpeed = math.floor(speed)
    })
end

-- 아이템 슬롯 HUD 업데이트 (범퍼카 모드)
function UpdateItemSlotsHud(items)
    UpdateHud({
        items = items
    })
end

-- 폭탄 타이머 HUD 업데이트 (폭탄 모드)
function UpdateBombTimerHud(timer)
    UpdateHud({
        bombTimer = timer
    })
end

-- 무기 HUD 업데이트 (무기 모드)
function UpdateWeaponHud(weaponData)
    UpdateHud({
        weapon = weaponData
    })
end

-- 라운드 정보 HUD 업데이트
function UpdateRoundInfoHud(info)
    UpdateHud({
        roundInfo = info
    })
end

-- 알림 표시
RegisterNetEvent('minigames:client:notify', function(message, type)
    SendNUIMessage({
        action = 'notify',
        message = message,
        type = type or 'info' -- info, success, error, warning
    })
end)

-- 레벨업 알림
RegisterNetEvent('minigames:client:levelUp', function(level)
    SendNUIMessage({
        action = 'levelUp',
        level = level
    })
end)

-- 서든 데스 알림
RegisterNetEvent('minigames:client:suddenDeath', function()
    SendNUIMessage({
        action = 'suddenDeath'
    })
end)

-- 결과 화면 표시
RegisterNetEvent('minigames:client:showResults', function(winners)
    SendNUIMessage({
        action = 'showResults',
        winners = winners
    })
end)

-- 스코어보드 업데이트
function UpdateScoreboard(players)
    SendNUIMessage({
        action = 'updateScoreboard',
        players = players
    })
end

-- 킬피드 표시
RegisterNetEvent('minigames:client:playerKill', function(killerId, killerName, victimId, victimName)
    SendNUIMessage({
        action = 'killfeed',
        killer = killerName,
        victim = victimName
    })
end)

-- 사망 알림
RegisterNetEvent('minigames:client:playerDied', function(playerId, playerName)
    SendNUIMessage({
        action = 'playerDied',
        player = playerName
    })
end)

-- HUD 렌더링 쓰레드
CreateThread(function()
    while true do
        Wait(100)

        if HudData.visible and CurrentRound.state == GameModes.States.PLAYING then
            -- 게임모드별 HUD 업데이트
            if HudData.type == "bumpercar" or HudData.type == "avalanche" or
               HudData.type == "boss" or HudData.type == "weapon" then
                if LocalPlayer.vehicle and DoesEntityExist(LocalPlayer.vehicle) then
                    UpdateVehicleHud(LocalPlayer.vehicle)
                end
            end
        end
    end
end)

-- 3D 텍스트 시스템
local Text3DData = {
    texts = {},
    counter = 0,
    updateInterval = 100 -- 100ms마다 업데이트
}

-- 3D 텍스트 표시 (NUI 사용)
function ShowText3D(coords, text, options)
    options = options or {}

    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)

    if onScreen then
        -- NUI에 텍스트 표시 요청
        SendNUIMessage({
            action = 'show3DText',
            x = _x,
            y = _y,
            text = text,
            id = options.id,
            style = options.style or '',
            color = options.color
        })

        return true
    end

    return false
end

-- 3D 텍스트 숨기기
function HideText3D(id)
    SendNUIMessage({
        action = 'hide3DText',
        id = id
    })
end

-- 모든 3D 텍스트 제거
function ClearAllText3D()
    SendNUIMessage({
        action = 'clear3DTexts'
    })
end

-- 조준점 표시
function ShowCrosshair(targeting)
    SendNUIMessage({
        action = 'showCrosshair',
        targeting = targeting or false
    })
end

-- 조준점 숨기기
function HideCrosshair()
    SendNUIMessage({
        action = 'hideCrosshair'
    })
end

-- 네이티브 HUD 비활성화
CreateThread(function()
    while true do
        Wait(0)

        if CurrentRound.state == GameModes.States.PLAYING then
            -- 레이더 숨기기
            DisplayRadar(false)

            -- 일부 HUD 요소 숨기기
            HideHudComponentThisFrame(1)  -- Wanted Stars
            HideHudComponentThisFrame(2)  -- Weapon Icon
            HideHudComponentThisFrame(3)  -- Cash
            HideHudComponentThisFrame(4)  -- MP Cash
            HideHudComponentThisFrame(6)  -- Vehicle Name
            HideHudComponentThisFrame(7)  -- Area Name
            HideHudComponentThisFrame(8)  -- Vehicle Class
            HideHudComponentThisFrame(9)  -- Street Name
            HideHudComponentThisFrame(13) -- Cash Change
            HideHudComponentThisFrame(19) -- Weapon Wheel
        else
            DisplayRadar(false)
        end
    end
end)

Utils.Info('HUD system loaded')
