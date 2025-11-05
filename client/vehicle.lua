-- ========================================
-- VEHICLE SYSTEM
-- ========================================

local VehicleData = {
    currentVehicle = nil,
    vehicleStats = nil,
    effects = {} -- 차량에 적용된 효과들
}

-- 차량 생성 (서버에서 호출)
RegisterNetEvent('minigames:client:spawnVehicle', function(model, coords, heading, stats)
    SpawnVehicle(model, coords, heading, stats)
end)

-- 차량 생성 함수
function SpawnVehicle(model, coords, heading, stats)
    -- 기존 차량 제거
    if VehicleData.currentVehicle then
        DeleteVehicle(VehicleData.currentVehicle)
    end

    -- 모델 로드
    local modelHash = type(model) == "string" and GetHashKey(model) or model

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(100)
        timeout = timeout + 100
    end

    if not HasModelLoaded(modelHash) then
        Utils.Error('Failed to load vehicle model: ' .. model)
        return nil
    end

    -- 차량 생성
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)

    -- 플레이어를 차량에 태우기
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)

    -- 차량 설정
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleOnGroundProperly(vehicle)

    -- 차량 스탯 적용
    if stats then
        ApplyVehicleStats(vehicle, stats)
    end

    -- 모델 해제
    SetModelAsNoLongerNeeded(modelHash)

    VehicleData.currentVehicle = vehicle
    VehicleData.vehicleStats = stats
    LocalPlayer.vehicle = vehicle

    Utils.Info('Spawned vehicle: ' .. model)

    return vehicle
end

-- 차량 스탯 적용
function ApplyVehicleStats(vehicle, stats)
    if not DoesEntityExist(vehicle) then return end

    -- 체력 설정
    if stats.health then
        SetVehicleEngineHealth(vehicle, stats.health)
        SetVehicleBodyHealth(vehicle, stats.health)
    end

    -- 속도 설정 (엔진 파워 수정)
    if stats.speed then
        SetVehicleEnginePowerMultiplier(vehicle, stats.speed)
    end

    -- 무적 해제 (데미지 처리를 위해)
    SetEntityInvincible(vehicle, false)

    Utils.Debug('Applied vehicle stats')
end

-- 차량 제거
RegisterNetEvent('minigames:client:deleteVehicle', function()
    DeletePlayerVehicle()
end)

function DeletePlayerVehicle()
    if VehicleData.currentVehicle and DoesEntityExist(VehicleData.currentVehicle) then
        DeleteVehicle(VehicleData.currentVehicle)
        VehicleData.currentVehicle = nil
        VehicleData.vehicleStats = nil
        VehicleData.effects = {}
        LocalPlayer.vehicle = nil

        Utils.Info('Deleted vehicle')
    end
end

-- 차량 수리
function RepairVehicle(amount)
    if not VehicleData.currentVehicle then return end

    local currentHealth = GetVehicleEngineHealth(VehicleData.currentVehicle)
    local newHealth = math.min(currentHealth + amount, 1000.0)

    SetVehicleEngineHealth(VehicleData.currentVehicle, newHealth)
    SetVehicleBodyHealth(VehicleData.currentVehicle, newHealth)
    SetVehicleFixed(VehicleData.currentVehicle)

    Utils.Debug('Repaired vehicle: +' .. amount)
end

-- 차량 크기 변경
function SetVehicleScale(scale, duration)
    if not VehicleData.currentVehicle then return end

    -- FiveM에는 네이티브 스케일 함수가 없으므로 대체 방법 사용
    -- 시각적 효과로만 구현 (실제 충돌 박스는 변경 안됨)

    VehicleData.effects.scale = {
        scale = scale,
        endTime = GetGameTimer() + (duration * 1000)
    }

    Utils.Debug('Vehicle scale set to: ' .. scale)
end

-- 차량 부스트
function ApplyVehicleBoost(multiplier, duration)
    if not VehicleData.currentVehicle then return end

    VehicleData.effects.boost = {
        multiplier = multiplier,
        endTime = GetGameTimer() + (duration * 1000)
    }

    Utils.Debug('Vehicle boost applied: ' .. multiplier .. 'x for ' .. duration .. 's')
end

-- 차량 점프
function VehicleJump(force)
    if not VehicleData.currentVehicle then return end

    SetVehicleForwardSpeed(VehicleData.currentVehicle, GetEntitySpeed(VehicleData.currentVehicle))

    local velocity = GetEntityVelocity(VehicleData.currentVehicle)
    SetEntityVelocity(VehicleData.currentVehicle, velocity.x, velocity.y, force)

    Utils.Debug('Vehicle jump applied: ' .. force)
end

-- 차량 데미지 처리
RegisterNetEvent('minigames:client:vehicleDamage', function(damage)
    ApplyVehicleDamage(damage)
end)

function ApplyVehicleDamage(damage)
    if not VehicleData.currentVehicle then return end

    -- 방어력 적용
    local defense = VehicleData.vehicleStats and VehicleData.vehicleStats.defense or 0
    local actualDamage = damage - defense

    -- 방어력 버프 적용
    if VehicleData.effects.defenseBoost then
        actualDamage = actualDamage - VehicleData.effects.defenseBoost.bonus
    end

    -- 쉴드 적용
    if VehicleData.effects.shield then
        local shieldRemaining = VehicleData.effects.shield.health - actualDamage
        if shieldRemaining > 0 then
            VehicleData.effects.shield.health = shieldRemaining
            actualDamage = 0
        else
            actualDamage = math.abs(shieldRemaining)
            VehicleData.effects.shield = nil
        end
    end

    actualDamage = math.max(0, actualDamage)

    local currentHealth = GetVehicleEngineHealth(VehicleData.currentVehicle)
    local newHealth = currentHealth - actualDamage

    SetVehicleEngineHealth(VehicleData.currentVehicle, newHealth)

    -- 차량 파괴
    if newHealth <= 0 then
        ExplodeVehicle(VehicleData.currentVehicle, true, false)
        TriggerServerEvent('minigames:server:playerDied')
    end

    Utils.Debug('Vehicle damaged: -' .. actualDamage .. ' (Health: ' .. newHealth .. ')')
end

-- 차량 충돌 데미지 계산
function CalculateCollisionDamage(vehicle1, vehicle2, speed1, speed2)
    local stats1 = VehicleData.vehicleStats
    local stats2 = nil -- TODO: 다른 차량의 스탯 가져오기

    local baseDamage1 = stats1 and stats1.damage or 50
    local baseDamage2 = stats2 and stats2.damage or 50

    -- 속도에 따른 데미지 계산
    local damage1 = baseDamage2 * (speed2 / 100) * 0.5
    local damage2 = baseDamage1 * (speed1 / 100) * 0.5

    -- 데미지 버프 적용
    if VehicleData.effects.damageBoost then
        damage2 = damage2 * VehicleData.effects.damageBoost.multiplier
    end

    return damage1, damage2
end

-- 차량 효과 업데이트 루프
CreateThread(function()
    while true do
        Wait(100)

        if VehicleData.currentVehicle and DoesEntityExist(VehicleData.currentVehicle) then
            local currentTime = GetGameTimer()

            -- 부스트 효과
            if VehicleData.effects.boost then
                if currentTime >= VehicleData.effects.boost.endTime then
                    VehicleData.effects.boost = nil
                    SetVehicleEnginePowerMultiplier(VehicleData.currentVehicle, VehicleData.vehicleStats.speed or 1.0)
                else
                    SetVehicleEnginePowerMultiplier(VehicleData.currentVehicle,
                        (VehicleData.vehicleStats.speed or 1.0) * VehicleData.effects.boost.multiplier)
                end
            end

            -- 크기 효과
            if VehicleData.effects.scale then
                if currentTime >= VehicleData.effects.scale.endTime then
                    VehicleData.effects.scale = nil
                    -- 원래 크기로 복구
                end
            end

            -- 방어력 버프
            if VehicleData.effects.defenseBoost and currentTime >= VehicleData.effects.defenseBoost.endTime then
                VehicleData.effects.defenseBoost = nil
            end

            -- 데미지 버프
            if VehicleData.effects.damageBoost and currentTime >= VehicleData.effects.damageBoost.endTime then
                VehicleData.effects.damageBoost = nil
            end
        end
    end
end)

-- 차량 정보 가져오기
function GetVehicleData()
    return VehicleData
end

Utils.Info('Vehicle system loaded')
