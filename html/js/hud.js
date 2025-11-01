// ========================================
// HUD 시스템
// ========================================

// 현재 HUD 상태
let currentHudType = null;
let text3DElements = {};
let text3DCounter = 0;

// ========================================
// NUI 메시지 리스너
// ========================================
window.addEventListener('message', function(event) {
    const data = event.data;

    switch(data.action) {
        case 'showHud':
            showHud(data.hudType);
            break;
        case 'hideHud':
            hideHud();
            break;
        case 'updateHud':
            updateHud(data.hudType, data.data);
            break;
        case 'updateVehicleHUD':
            updateVehicleHud(data);
            break;
        case 'updateBombHUD':
            updateBombHud(data);
            break;
        case 'updateAvalancheHUD':
            updateAvalancheHud(data);
            break;
        case 'updateBossHUD':
            updateBossHud(data);
            break;
        case 'updateWeaponHud':
            updateWeaponHud(data);
            break;
        case 'show3DText':
            show3DText(data);
            break;
        case 'hide3DText':
            hide3DText(data.id);
            break;
        case 'clear3DTexts':
            clearAll3DTexts();
            break;
        case 'showCrosshair':
            showCrosshair(data.targeting);
            break;
        case 'hideCrosshair':
            hideCrosshair();
            break;
        case 'notify':
            showNotification(data.message, data.type);
            break;
        case 'killfeed':
            showKillfeed(data.killer, data.victim);
            break;
        case 'showWarning':
            showWarning(data.message);
            break;
        case 'hideWarning':
            hideWarning();
            break;
    }
});

// ========================================
// HUD 표시/숨김
// ========================================
function showHud(hudType) {
    // 모든 HUD 숨기기
    hideHud();

    currentHudType = hudType;

    // 해당 HUD 표시
    const hudElement = document.getElementById(`${hudType}-hud`);
    if (hudElement) {
        hudElement.classList.remove('hidden');
    }
}

function hideHud() {
    const hudContainers = document.querySelectorAll('.hud-container');
    hudContainers.forEach(container => {
        container.classList.add('hidden');
    });

    hideCrosshair();
    clearAll3DTexts();
    currentHudType = null;
}

// ========================================
// 통합 HUD 업데이트
// ========================================
function updateHud(hudType, data) {
    if (!data) return;

    // 차량 정보 업데이트
    if (data.vehicleHealth !== undefined || data.vehicleSpeed !== undefined) {
        updateVehicleInfo(hudType, data);
    }

    // 아이템 슬롯 업데이트 (범퍼카)
    if (data.items) {
        updateItemSlots(data.items);
    }

    // 무기 정보 업데이트
    if (data.weapon) {
        updateWeaponInfo(data.weapon);
    }

    // 폭탄 타이머 업데이트
    if (data.bombTimer !== undefined) {
        updateBombTimer(data.bombTimer);
    }

    // 폭탄 소유자 업데이트
    if (data.bombHolder !== undefined) {
        updateBombHolder(data.bombHolder, data.hasBomb);
    }

    // 거리 정보 업데이트 (아발란체)
    if (data.distanceToFinish !== undefined) {
        updateDistance(data.distanceToFinish);
    }

    // 보스 정보 업데이트
    if (data.bossName !== undefined) {
        updateBossInfo(data.bossName, data.isBoss);
    }
}

// ========================================
// 차량 정보 업데이트
// ========================================
function updateVehicleInfo(hudType, data) {
    const healthBar = document.getElementById(`${hudType}-health-bar`);
    const healthText = document.getElementById(`${hudType}-health-text`);
    const speedElement = document.getElementById(`${hudType}-speed`);

    if (data.vehicleHealth !== undefined) {
        const healthPercent = Math.max(0, Math.min(100, data.vehicleHealth));

        if (healthBar) {
            healthBar.style.width = healthPercent + '%';

            // 색상 변경
            healthBar.classList.remove('medium', 'low');
            if (healthPercent < 30) {
                healthBar.classList.add('low');
            } else if (healthPercent < 60) {
                healthBar.classList.add('medium');
            }
        }

        if (healthText) {
            healthText.textContent = Math.floor(healthPercent) + '%';
        }
    }

    if (data.vehicleSpeed !== undefined && speedElement) {
        speedElement.textContent = data.vehicleSpeed + ' km/h';
    }
}

function updateVehicleHud(data) {
    if (!currentHudType) return;

    const healthPercent = (data.health / data.maxHealth) * 100;
    updateVehicleInfo(currentHudType, {
        vehicleHealth: healthPercent,
        vehicleSpeed: data.speed
    });
}

// ========================================
// 아이템 슬롯 업데이트
// ========================================
function updateItemSlots(items) {
    for (let i = 0; i < 3; i++) {
        const slotContent = document.getElementById(`item-slot-${i + 1}`);
        if (!slotContent) continue;

        const item = items[i];

        if (item) {
            slotContent.innerHTML = `
                ${item.icon ? `<img src="img/items/${item.icon}" class="slot-item-icon" alt="${item.name}">` : ''}
                <div class="slot-item-name">${item.name}</div>
            `;
        } else {
            slotContent.innerHTML = '<div class="slot-empty">비어있음</div>';
        }
    }
}

// ========================================
// 무기 정보 업데이트
// ========================================
function updateWeaponInfo(weapon) {
    const weaponName = document.getElementById('weapon-name');
    const weaponIcon = document.getElementById('weapon-icon');
    const ammoCurrent = document.getElementById('weapon-ammo-current');
    const ammoMax = document.getElementById('weapon-ammo-max');
    const weaponAmmo = document.querySelector('.weapon-ammo');
    const reloadContainer = document.getElementById('reload-bar-container');
    const reloadBar = document.getElementById('reload-bar');

    if (weaponName) {
        weaponName.textContent = weapon.name || '무기 없음';
    }

    if (weaponIcon && weapon.icon) {
        weaponIcon.innerHTML = `<img src="img/weapons/${weapon.icon}" alt="${weapon.name}">`;
    }

    if (ammoCurrent && ammoMax) {
        ammoCurrent.textContent = weapon.ammo || 0;
        ammoMax.textContent = weapon.maxAmmo || 0;

        // 탄약 상태에 따른 색상 변경
        if (weaponAmmo) {
            weaponAmmo.classList.remove('low-ammo', 'no-ammo');

            if (weapon.ammo === 0) {
                weaponAmmo.classList.add('no-ammo');
            } else if (weapon.ammo < weapon.maxAmmo * 0.3) {
                weaponAmmo.classList.add('low-ammo');
            }
        }
    }

    // 재장전 진행바
    if (weapon.reloadProgress !== undefined) {
        if (reloadContainer) {
            if (weapon.reloadProgress > 0 && weapon.reloadProgress < 1) {
                reloadContainer.classList.remove('hidden');
                if (reloadBar) {
                    reloadBar.style.width = (weapon.reloadProgress * 100) + '%';
                }
            } else {
                reloadContainer.classList.add('hidden');
            }
        }
    }
}

function updateWeaponHud(data) {
    if (data.weapon) {
        updateWeaponInfo(data.weapon);
    }

    if (data.vehicleHealth !== undefined || data.vehicleSpeed !== undefined) {
        updateVehicleInfo('weapon', {
            vehicleHealth: data.vehicleHealth,
            vehicleSpeed: data.vehicleSpeed
        });
    }
}

// ========================================
// 폭탄 타이머 업데이트
// ========================================
function updateBombTimer(seconds) {
    const timerDisplay = document.getElementById('bomb-timer-display');
    const bombTimer = document.querySelector('.bomb-timer');

    if (timerDisplay) {
        const minutes = Math.floor(seconds / 60);
        const secs = seconds % 60;
        timerDisplay.textContent = `${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }

    // 5초 이하일 때 깜빡임 효과
    if (bombTimer) {
        if (seconds <= 5) {
            bombTimer.classList.add('critical');
        } else {
            bombTimer.classList.remove('critical');
        }
    }
}

function updateBombHolder(holderName, hasBomb) {
    const holderNameElement = document.getElementById('bomb-holder-name');

    if (holderNameElement) {
        holderNameElement.textContent = holderName || '-';
    }
}

function updateBombHud(data) {
    if (data.timer !== undefined) {
        updateBombTimer(data.timer);
    }

    if (data.bombHolder !== undefined) {
        updateBombHolder(data.bombHolder, data.hasBomb);
    }

    if (data.health !== undefined || data.speed !== undefined) {
        updateVehicleInfo('bomb', {
            vehicleHealth: (data.health / data.maxHealth) * 100,
            vehicleSpeed: data.speed
        });
    }
}

// ========================================
// 아발란체 거리 업데이트
// ========================================
function updateDistance(distance) {
    const distanceValue = document.getElementById('avalanche-distance');

    if (distanceValue) {
        distanceValue.textContent = Math.floor(distance) + ' m';
    }
}

function updateAvalancheHud(data) {
    if (data.distanceToFinish !== undefined) {
        updateDistance(data.distanceToFinish);
    }

    if (data.speed !== undefined) {
        updateVehicleInfo('avalanche', {
            vehicleSpeed: data.speed
        });
    }
}

// ========================================
// 보스 정보 업데이트
// ========================================
function updateBossInfo(bossName, isBoss) {
    const bossNameElement = document.getElementById('boss-name');
    const roleText = document.getElementById('boss-role-text');
    const roleDisplay = document.querySelector('.role-display');
    const bossLabel = document.getElementById('boss-role-label');

    if (bossNameElement) {
        bossNameElement.textContent = bossName || '-';
    }

    if (roleText) {
        roleText.textContent = isBoss ? '보스' : '생존자';
    }

    if (roleDisplay) {
        if (isBoss) {
            roleDisplay.classList.add('boss-role');
        } else {
            roleDisplay.classList.remove('boss-role');
        }
    }

    if (bossLabel) {
        bossLabel.textContent = isBoss ? '당신의 역할' : '보스';
    }
}

function updateBossHud(data) {
    if (data.bossName !== undefined) {
        updateBossInfo(data.bossName, data.isBoss);
    }
}

// ========================================
// 3D 텍스트 표시
// ========================================
function show3DText(data) {
    const container = document.getElementById('text-3d-container');
    if (!container) return;

    // 고유 ID가 없으면 생성
    const textId = data.id || `text3d-${text3DCounter++}`;

    // 기존 요소가 있으면 재사용
    let textElement = text3DElements[textId];

    if (!textElement) {
        textElement = document.createElement('div');
        textElement.className = 'text-3d';
        textElement.id = textId;
        container.appendChild(textElement);
        text3DElements[textId] = textElement;
    }

    // 스타일 클래스 적용
    if (data.style) {
        textElement.className = `text-3d ${data.style}`;
    }

    // 위치 설정 (0~1 범위를 % 단위로)
    textElement.style.left = (data.x * 100) + '%';
    textElement.style.top = (data.y * 100) + '%';
    textElement.textContent = data.text;

    // 색상 커스터마이징
    if (data.color) {
        textElement.style.color = data.color;
    }

    return textId;
}

function hide3DText(id) {
    const textElement = text3DElements[id];
    if (textElement && textElement.parentNode) {
        textElement.parentNode.removeChild(textElement);
        delete text3DElements[id];
    }
}

function clearAll3DTexts() {
    const container = document.getElementById('text-3d-container');
    if (container) {
        container.innerHTML = '';
    }
    text3DElements = {};
}

// ========================================
// 조준점 표시/숨김
// ========================================
function showCrosshair(targeting = false) {
    const crosshair = document.getElementById('crosshair');
    if (crosshair) {
        crosshair.classList.remove('hidden');

        if (targeting) {
            crosshair.classList.add('targeting');
        } else {
            crosshair.classList.remove('targeting');
        }
    }
}

function hideCrosshair() {
    const crosshair = document.getElementById('crosshair');
    if (crosshair) {
        crosshair.classList.add('hidden');
        crosshair.classList.remove('targeting');
    }
}

// ========================================
// 알림 표시
// ========================================
function showNotification(message, type = 'info') {
    const container = document.getElementById('notification-container');
    if (!container) return;

    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.innerHTML = `<div class="notification-text">${message}</div>`;

    container.appendChild(notification);

    // 3초 후 제거
    setTimeout(() => {
        notification.style.animation = 'fadeOut 0.3s ease-out';
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }, 3000);
}

// ========================================
// 킬피드 표시
// ========================================
function showKillfeed(killer, victim) {
    const container = document.getElementById('killfeed-container');
    if (!container) return;

    const killfeed = document.createElement('div');
    killfeed.className = 'killfeed-item';
    killfeed.innerHTML = `
        <span class="killfeed-killer">${killer}</span>
        <span class="killfeed-icon">💀</span>
        <span class="killfeed-victim">${victim}</span>
    `;

    container.appendChild(killfeed);

    // 5초 후 제거
    setTimeout(() => {
        if (killfeed.parentNode) {
            killfeed.parentNode.removeChild(killfeed);
        }
    }, 5000);

    // 킬피드 항목이 너무 많으면 오래된 것 제거
    const items = container.querySelectorAll('.killfeed-item');
    if (items.length > 5) {
        items[0].parentNode.removeChild(items[0]);
    }
}

// ========================================
// 경고 메시지
// ========================================
function showWarning(message) {
    const warning = document.getElementById('avalanche-warning');
    if (warning) {
        warning.classList.remove('hidden');
        const warningText = warning.querySelector('.warning-text');
        if (warningText && message) {
            warningText.textContent = message;
        }
    }
}

function hideWarning() {
    const warning = document.getElementById('avalanche-warning');
    if (warning) {
        warning.classList.add('hidden');
    }
}

// ========================================
// fadeOut 애니메이션 추가
// ========================================
const style = document.createElement('style');
style.textContent = `
@keyframes fadeOut {
    from {
        opacity: 1;
    }
    to {
        opacity: 0;
    }
}
`;
document.head.appendChild(style);

// ========================================
// 초기화
// ========================================
console.log('HUD system initialized');
