-- ========================================
-- ITEM SYSTEM
-- ========================================

local ItemData = {
    slots = {nil, nil, nil}, -- 3개 슬롯
    nearbyItems = {}, -- 근처의 아이템들
    activeEffects = {} -- 활성 효과들
}

-- 아이템 사용
RegisterNetEvent('minigames:server:useItem', function(slot)
    UseItem(slot)
end)

function UseItem(slot)
    local item = ItemData.slots[slot]

    if not item then
        TriggerEvent('minigames:client:notify', '아이템이 없습니다.', 'warning')
        return
    end

    -- 아이템 효과 적용
    ApplyItemEffect(item)

    -- 슬롯 비우기 (액티브 아이템의 경우)
    if item.type == GameModes.ItemTypes.ACTIVE then
        ItemData.slots[slot] = nil
        UpdateItemSlotsHud(ItemData.slots)
    end

    Utils.Debug('Used item: ' .. item.id .. ' in slot ' .. slot)
end

-- 아이템 효과 적용
function ApplyItemEffect(item)
    local effect = item.effect

    if effect == "repair" then
        -- 차량 수리
        RepairVehicle(item.value)
        TriggerEvent('minigames:client:notify', '차량이 수리되었습니다!', 'success')

    elseif effect == "random_vehicle" then
        -- 무작위 차량으로 변경
        TriggerServerEvent('minigames:server:requestRandomVehicle')
        TriggerEvent('minigames:client:notify', '차량이 변경되었습니다!', 'info')

    elseif effect == "boost" then
        -- 부스트
        ApplyVehicleBoost(item.speedMultiplier, item.duration)
        TriggerEvent('minigames:client:notify', '부스트 활성화!', 'success')

    elseif effect == "jump" then
        -- 점프
        VehicleJump(item.force)
        TriggerEvent('minigames:client:notify', '점프!', 'info')

    elseif effect == "shrink" then
        -- 차량 축소
        SetVehicleScale(item.scale, item.duration)
        TriggerEvent('minigames:client:notify', '차량 크기 축소!', 'info')

    elseif effect == "missile" then
        -- 일반 미사일 발사
        FireMissile(false)
        TriggerEvent('minigames:client:notify', '미사일 발사!', 'info')

    elseif effect == "homing_missile" then
        -- 유도 미사일 발사
        FireMissile(true)
        TriggerEvent('minigames:client:notify', '유도 미사일 발사!', 'info')

    elseif effect == "knockback" then
        -- 넉백
        ApplyKnockback(item.radius, item.force)
        TriggerEvent('minigames:client:notify', '넉백!', 'info')

    elseif effect == "defense" then
        -- 방어력 증가
        local vehicleData = GetVehicleData()
        vehicleData.effects.defenseBoost = {
            bonus = item.defenseBonus,
            endTime = GetGameTimer() + (item.duration * 1000)
        }
        TriggerEvent('minigames:client:notify', '방어력 증가!', 'success')

    elseif effect == "damage" then
        -- 데미지 증가
        local vehicleData = GetVehicleData()
        vehicleData.effects.damageBoost = {
            multiplier = item.damageMultiplier,
            endTime = GetGameTimer() + (item.duration * 1000)
        }
        TriggerEvent('minigames:client:notify', '데미지 증가!', 'success')

    elseif effect == "shield" then
        -- 쉴드
        local vehicleData = GetVehicleData()
        vehicleData.effects.shield = {
            health = item.shieldHealth
        }
        TriggerEvent('minigames:client:notify', '쉴드 활성화!', 'success')
    end
end

-- 미사일 발사
function FireMissile(homing)
    local ped = PlayerPedId()
    local vehicle = VehicleData.currentVehicle

    if not vehicle then return end

    -- 차량 정면 방향 계산
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleForward = GetEntityForwardVector(vehicle)
    local spawnOffset = vector3(vehicleCoords.x + vehicleForward.x * 3.0,
                                 vehicleCoords.y + vehicleForward.y * 3.0,
                                 vehicleCoords.z)

    -- 미사일 생성 (서버에 요청)
    TriggerServerEvent('minigames:server:createMissile', spawnOffset, vehicleForward, homing)
end

-- 넉백 적용
function ApplyKnockback(radius, force)
    local vehicle = VehicleData.currentVehicle
    if not vehicle then return end

    local vehicleCoords = GetEntityCoords(vehicle)

    -- 서버에 넉백 요청
    TriggerServerEvent('minigames:server:applyKnockback', vehicleCoords, radius, force)
end

-- 아이템 습득
RegisterNetEvent('minigames:client:pickupItem', function(item)
    PickupItem(item)
end)

function PickupItem(item)
    -- 빈 슬롯 찾기
    local emptySlot = nil
    for i = 1, 3 do
        if not ItemData.slots[i] then
            emptySlot = i
            break
        end
    end

    -- 즉발형 아이템은 바로 사용
    if item.type == GameModes.ItemTypes.INSTANT then
        ApplyItemEffect(item)
        TriggerEvent('minigames:client:notify', item.name .. ' 획득!', 'success')
        return
    end

    -- 액티브형 아이템은 슬롯에 저장
    if emptySlot then
        ItemData.slots[emptySlot] = item
        UpdateItemSlotsHud(ItemData.slots)
        TriggerEvent('minigames:client:notify', item.name .. ' 획득! (슬롯 ' .. emptySlot .. ')', 'success')
    else
        -- 슬롯이 가득 찬 경우 마지막 슬롯 교체
        ItemData.slots[3] = item
        UpdateItemSlotsHud(ItemData.slots)
        TriggerEvent('minigames:client:notify', item.name .. ' 획득! (슬롯 3 교체)', 'info')
    end
end

-- 아이템 스폰 렌더링
CreateThread(function()
    while true do
        Wait(0)

        if CurrentRound.state == GameModes.States.PLAYING and
           (CurrentRound.gamemode.id == "bumpercar" or CurrentRound.gamemode.id == "weapon") then

            local playerCoords = GetEntityCoords(PlayerPedId())

            for itemId, itemData in pairs(ItemData.nearbyItems) do
                local distance = #(playerCoords - itemData.coords)

                -- 아이템 렌더링
                if distance < 100.0 then
                    -- 3D 텍스트 그리기
                    DrawText3D(itemData.coords.x, itemData.coords.y, itemData.coords.z + 1.0, itemData.name)

                    -- 마커 그리기
                    DrawMarker(
                        1, -- 타입
                        itemData.coords.x, itemData.coords.y, itemData.coords.z - 0.5,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        1.0, 1.0, 0.5,
                        0, 217, 255, 200,
                        false, true, 2, false, nil, nil, false
                    )

                    -- 근처에 있으면 습득
                    if distance < 3.0 then
                        TriggerServerEvent('minigames:server:pickupItem', itemId)
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

-- 3D 텍스트 그리기
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)

    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)

        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- 아이템 목록 업데이트
RegisterNetEvent('minigames:client:updateNearbyItems', function(items)
    ItemData.nearbyItems = items
end)

-- 아이템 슬롯 초기화
function ResetItemSlots()
    ItemData.slots = {nil, nil, nil}
    UpdateItemSlotsHud(ItemData.slots)
end

Utils.Info('Item system loaded')
