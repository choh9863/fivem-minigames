// ========================================
// 전역 변수
// ========================================
let lobbyData = {
    mySource: null,
    players: [],
    spectators: [],
    gamemodes: [],
    maps: [],
    selectedGamemode: null,
    selectedMap: null,
    myVotedGamemode: null,
    myVotedMap: null,
    isReady: false,
    isSpectating: false,
    maxPlayers: 32,
    timer: 0
};

// ========================================
// DOM 요소
// ========================================
const elements = {
    container: document.getElementById('lobby-container'),

    // 버튼
    btnReady: document.getElementById('btn-ready'),
    btnSpectate: document.getElementById('btn-spectate'),
    btnQuit: document.getElementById('btn-quit'),
    btnSend: document.getElementById('btn-send'),

    // 리스트
    playerList: document.getElementById('player-list'),
    spectatorList: document.getElementById('spectator-list'),
    gamemodeVoteList: document.getElementById('gamemode-vote-list'),
    mapVoteList: document.getElementById('map-vote-list'),

    // 채팅
    chatMessages: document.getElementById('chat-messages'),
    chatInput: document.getElementById('chat-input'),

    // 카운터
    playerCount: document.getElementById('player-count'),
    spectatorCount: document.getElementById('spectator-count'),
    timerValue: document.getElementById('timer-value'),
    timerSection: document.getElementById('timer-section'),
    timerLabel: document.querySelector('.timer-label')
};

// ========================================
// NUI 이벤트 리스너
// ========================================
window.addEventListener('message', (event) => {
    const data = event.data;

    // 디버그 로그
    console.log('[Lobby] NUI Message:', data);

    if (!data.action) {
        console.warn('[Lobby] No action in message:', data);
        return;
    }

    switch (data.action) {
        case 'openLobby':
            openLobby(data.data);
            break;

        case 'closeLobby':
            closeLobby();
            break;

        case 'updateLobbyData':
            updateLobbyData(data.data);
            break;

        case 'updateTimer':
            updateTimer(data.time);
            break;

        case 'updateRoundState':
            updateRoundState(data.state, data.data);
            break;

        case 'chatMessage':
            addChatMessage(data.sender, data.message);
            break;

        default:
            console.warn('[Lobby] Unknown action:', data.action);
    }
});

// ESC 키로 로비 닫기
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !elements.container.classList.contains('hidden')) {
        sendNUIMessage('closeLobby');
    }
});

// ========================================
// 버튼 이벤트
// ========================================
elements.btnReady.addEventListener('click', () => {
    // 관전 중이면 준비 버튼 무시
    if (lobbyData.isSpectating) {
        return;
    }

    lobbyData.isReady = !lobbyData.isReady;
    updateReadyButton();
    sendNUIMessage('toggleReady');
});

elements.btnSpectate.addEventListener('click', () => {
    lobbyData.isSpectating = !lobbyData.isSpectating;
    updateSpectateButton();
    sendNUIMessage('toggleSpectate');
});

elements.btnQuit.addEventListener('click', () => {
    sendNUIMessage('quitGame');
});

elements.btnSend.addEventListener('click', () => {
    sendChatMessage();
});

elements.chatInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        sendChatMessage();
    }
});

// ========================================
// 로비 관리
// ========================================
function openLobby(data) {
    lobbyData = { ...lobbyData, ...data };

    // maxPlayers 기본값 설정
    if (!lobbyData.maxPlayers) {
        lobbyData.maxPlayers = 32;
    }

    elements.container.classList.remove('hidden');

    // 초기 데이터 렌더링
    updatePlayerList();
    updateSpectatorList();
    updateGamemodeVotes();
    updateMapVotes();
    updateCounters();
    updateReadyButton();
    updateSpectateButton();

    console.log('로비 열림', lobbyData);
}

function closeLobby() {
    elements.container.classList.add('hidden');

    // 채팅 초기화
    elements.chatMessages.innerHTML = '';
    elements.chatInput.value = '';

    console.log('로비 닫힘');
}

function updateLobbyData(data) {
    lobbyData = { ...lobbyData, ...data };

    // 내 플레이어 상태 동기화
    if (lobbyData.mySource && (data.players || data.spectators)) {
        // 플레이어 리스트에서 내 상태 찾기
        if (data.players) {
            const myPlayer = data.players.find(p => p.source === lobbyData.mySource);
            if (myPlayer) {
                lobbyData.isReady = myPlayer.ready;
                lobbyData.isSpectating = false;
                updateReadyButton();
                updateSpectateButton();
            }
        }

        // 관전자 리스트에서 내 상태 찾기
        if (data.spectators) {
            const mySpectator = data.spectators.find(s => s.source === lobbyData.mySource);
            if (mySpectator) {
                lobbyData.isReady = false;
                lobbyData.isSpectating = true;
                updateReadyButton();
                updateSpectateButton();
            }
        }
    }

    // UI 업데이트
    updatePlayerList();
    updateSpectatorList();
    updateGamemodeVotes();
    updateMapVotes();
    updateCounters();

    console.log('로비 데이터 업데이트', lobbyData);
}

// ========================================
// 플레이어 리스트
// ========================================
function updatePlayerList() {
    elements.playerList.innerHTML = '';

    if (!lobbyData.players || lobbyData.players.length === 0) {
        elements.playerList.innerHTML = '<div class="no-data">플레이어가 없습니다</div>';
        return;
    }

    lobbyData.players.forEach(player => {
        const card = createPlayerCard(player);
        elements.playerList.appendChild(card);
    });
}

function createPlayerCard(player) {
    const card = document.createElement('div');
    card.className = 'player-card';
    if (player.ready) {
        card.classList.add('ready');
    }

    // 랭크 정보 가져오기
    const rankInfo = getRankInfo(player.rank || 1);

    card.innerHTML = `
        <div class="player-info">
            <div class="player-name">
                <span>${escapeHtml(player.name)}</span>
                <img src="${rankInfo.image}" alt="${rankInfo.name}" class="player-rank-img"
                     onerror="this.style.display='none'">
            </div>
            <div class="player-level">레벨 ${player.level || 1}</div>
        </div>
        <div class="player-status">${player.ready ? '✓' : ''}</div>
    `;

    return card;
}

// ========================================
// 관전자 리스트
// ========================================
function updateSpectatorList() {
    elements.spectatorList.innerHTML = '';

    if (!lobbyData.spectators || lobbyData.spectators.length === 0) {
        elements.spectatorList.innerHTML = '<div class="no-data">관전자가 없습니다</div>';
        return;
    }

    lobbyData.spectators.forEach(spectator => {
        const item = createSpectatorItem(spectator);
        elements.spectatorList.appendChild(item);
    });
}

function createSpectatorItem(spectator) {
    const item = document.createElement('div');
    item.className = 'spectator-item';

    const rankInfo = getRankInfo(spectator.rank || 1);

    item.innerHTML = `
        <div class="spectator-name">
            <img src="${rankInfo.image}" alt="${rankInfo.name}" class="spectator-rank-img"
                 onerror="this.style.display='none'">
            <span>${escapeHtml(spectator.name)}</span>
        </div>
        <div class="spectator-level">LV ${spectator.level || 1}</div>
    `;

    return item;
}

// ========================================
// 게임모드 투표
// ========================================
function updateGamemodeVotes() {
    elements.gamemodeVoteList.innerHTML = '';

    if (!lobbyData.gamemodes || lobbyData.gamemodes.length === 0) {
        elements.gamemodeVoteList.innerHTML = '<div class="no-data">게임모드 없음</div>';
        return;
    }

    lobbyData.gamemodes.forEach(gamemode => {
        const item = createVoteItem(gamemode, 'gamemode');
        elements.gamemodeVoteList.appendChild(item);
    });
}

function updateMapVotes() {
    elements.mapVoteList.innerHTML = '';

    if (!lobbyData.maps || lobbyData.maps.length === 0) {
        elements.mapVoteList.innerHTML = '<div class="no-data">맵을 선택하려면 게임모드를 먼저 투표하세요</div>';
        return;
    }

    lobbyData.maps.forEach(map => {
        const item = createVoteItem(map, 'map');
        elements.mapVoteList.appendChild(item);
    });
}

function createVoteItem(item, type) {
    const voteItem = document.createElement('div');
    voteItem.className = 'vote-item';

    // 배경 이미지 설정
    if (item.image) {
        voteItem.style.backgroundImage = `linear-gradient(rgba(0, 0, 0, 0.3), rgba(0, 0, 0, 0.6)), url('${item.image}')`;
    }

    // 선택 상태 확인
    const isSelected = type === 'gamemode'
        ? item.id === lobbyData.myVotedGamemode
        : item.id === lobbyData.myVotedMap;

    if (isSelected) {
        voteItem.classList.add('selected');
    }

    // 게임모드가 선택되지 않았을 때 맵 비활성화
    if (type === 'map' && !lobbyData.selectedGamemode) {
        voteItem.classList.add('disabled');
    }

    voteItem.innerHTML = `
        <div class="vote-item-info">
            <div class="vote-item-name">${escapeHtml(item.name)}</div>
            ${item.description ? `<div class="vote-item-description">${escapeHtml(item.description)}</div>` : ''}
            <div class="vote-item-votes">투표 수: ${item.votes || 0}</div>
        </div>
    `;

    // 클릭 이벤트
    voteItem.addEventListener('click', () => {
        if (voteItem.classList.contains('disabled')) return;

        if (type === 'gamemode') {
            voteGamemode(item.id);
        } else {
            voteMap(item.id);
        }
    });

    return voteItem;
}

function voteGamemode(gamemodeId) {
    lobbyData.myVotedGamemode = gamemodeId;
    lobbyData.myVotedMap = null; // 게임모드 변경시 맵 투표 초기화
    updateGamemodeVotes();
    updateMapVotes();
    sendNUIMessage('voteGamemode', { gamemodeId });
}

function voteMap(mapId) {
    lobbyData.myVotedMap = mapId;
    updateMapVotes();
    sendNUIMessage('voteMap', { mapId });
}

// ========================================
// 채팅
// ========================================
function sendChatMessage() {
    const message = elements.chatInput.value.trim();

    if (!message) return;

    sendNUIMessage('sendChatMessage', { message });
    elements.chatInput.value = '';
}

function addChatMessage(sender, message) {
    const messageDiv = document.createElement('div');
    messageDiv.className = 'chat-message';

    messageDiv.innerHTML = `
        <span class="sender">${escapeHtml(sender)}:</span>
        <span class="text">${escapeHtml(message)}</span>
    `;

    elements.chatMessages.appendChild(messageDiv);

    // 스크롤을 최하단으로
    elements.chatMessages.scrollTop = elements.chatMessages.scrollHeight;

    // 메시지가 너무 많으면 오래된 메시지 삭제
    const messages = elements.chatMessages.children;
    if (messages.length > 50) {
        elements.chatMessages.removeChild(messages[0]);
    }
}

// ========================================
// 타이머
// ========================================
function updateTimer(time) {
    // 타이머가 없거나 0 이하면 "플레이어를 기다리는 중" 표시
    if (!time || time <= 0) {
        elements.timerSection.style.display = 'block';
        if (elements.timerLabel) {
            elements.timerLabel.textContent = '상태';
        }
        elements.timerValue.textContent = '대기 중';
        return;
    }

    elements.timerSection.style.display = 'block';
    lobbyData.timer = time;

    if (elements.timerLabel) {
        elements.timerLabel.textContent = '게임 시작까지';
    }

    const minutes = Math.floor(time / 60);
    const seconds = time % 60;

    elements.timerValue.textContent =
        `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

// ========================================
// 라운드 상태 업데이트
// ========================================
function updateRoundState(state, data) {
    elements.timerSection.style.display = 'block';

    switch (state) {
        case 'waiting_players':
            // 플레이어를 기다리는 중 (X명 더 필요)
            if (elements.timerLabel) {
                elements.timerLabel.textContent = '상태';
            }
            elements.timerValue.textContent = `${data}명 더 필요`;
            break;

        case 'waiting_ready':
            // 준비된 플레이어를 기다리는 중 (X/Y 준비됨)
            if (elements.timerLabel) {
                elements.timerLabel.textContent = '상태';
            }
            elements.timerValue.textContent = `준비: ${data.ready}/${data.required}`;
            break;

        case 'starting':
            // 게임 시작까지 남은 시간
            if (elements.timerLabel) {
                elements.timerLabel.textContent = '게임 시작까지';
            }
            if (data > 0) {
                elements.timerValue.textContent = `${data}초`;
            } else {
                elements.timerValue.textContent = '곧 시작...';
            }
            break;

        case 'voting_gamemode':
            // 게임모드 투표 중
            if (elements.timerLabel) {
                elements.timerLabel.textContent = '상태';
            }
            elements.timerValue.textContent = '게임모드 투표 중';
            break;

        case 'voting_map':
            // 맵 투표 중
            if (elements.timerLabel) {
                elements.timerLabel.textContent = '상태';
            }
            elements.timerValue.textContent = '맵 투표 중';
            break;

        case 'preparing':
            // 라운드 준비 중
            if (elements.timerLabel) {
                elements.timerLabel.textContent = '상태';
            }
            if (data > 0) {
                elements.timerValue.textContent = `준비 중... ${data}초`;
            } else {
                elements.timerValue.textContent = '곧 시작...';
            }
            break;

        default:
            if (elements.timerLabel) {
                elements.timerLabel.textContent = '상태';
            }
            elements.timerValue.textContent = '대기 중';
    }

    console.log('[Lobby] Round state updated:', state, data);
}

// ========================================
// 버튼 상태 업데이트
// ========================================
function updateReadyButton() {
    if (lobbyData.isReady) {
        elements.btnReady.classList.add('active');
    } else {
        elements.btnReady.classList.remove('active');
    }

    // 관전 중일 때 준비 버튼 비활성화
    if (lobbyData.isSpectating) {
        elements.btnReady.disabled = true;
        elements.btnReady.style.opacity = '0.5';
        elements.btnReady.style.cursor = 'not-allowed';
    } else {
        elements.btnReady.disabled = false;
        elements.btnReady.style.opacity = '1';
        elements.btnReady.style.cursor = 'pointer';
    }
}

function updateSpectateButton() {
    if (lobbyData.isSpectating) {
        elements.btnSpectate.classList.add('active');
        elements.btnSpectate.querySelector('.btn-text').textContent = '관전 중';
    } else {
        elements.btnSpectate.classList.remove('active');
        elements.btnSpectate.querySelector('.btn-text').textContent = '관전 참여';
    }
}

// ========================================
// 카운터 업데이트
// ========================================
function updateCounters() {
    const playerCount = lobbyData.players ? lobbyData.players.length : 0;
    const spectatorCount = lobbyData.spectators ? lobbyData.spectators.length : 0;
    const maxPlayers = lobbyData.maxPlayers || 32;

    elements.playerCount.textContent = `${playerCount}/${maxPlayers}`;
    elements.spectatorCount.textContent = spectatorCount;
}

// ========================================
// NUI 메시지 전송
// ========================================
function sendNUIMessage(action, data = {}) {
    fetch(`https://minigames/${action}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    }).catch(err => {
        console.error('NUI 메시지 전송 실패:', action, err);
    });
}

// ========================================
// 유틸리티 함수
// ========================================
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function getRankInfo(rank) {
    // Config.Ranks에 정의된 랭크 정보
    const ranks = {
        1: { name: 'Newbie', image: 'img/ranks/newbie.png' },
        2: { name: 'Bronze', image: 'img/ranks/bronze.png' },
        3: { name: 'Silver', image: 'img/ranks/silver.png' },
        4: { name: 'Gold', image: 'img/ranks/gold.png' },
        5: { name: 'Platinum', image: 'img/ranks/platinum.png' },
        6: { name: 'Diamond', image: 'img/ranks/diamond.png' },
        7: { name: 'Master', image: 'img/ranks/master.png' },
        8: { name: 'Admin', image: 'img/ranks/admin.png' }
    };

    return ranks[rank] || ranks[1];
}

// ========================================
// 디버그 (개발 중에만 사용)
// ========================================
if (window.location.protocol === 'file:') {
    console.log('개발 모드: 테스트 데이터 로드');

    // 테스트 데이터
    setTimeout(() => {
        openLobby({
            players: [
                { name: '플레이어1', level: 15, rank: 3, ready: true },
                { name: '플레이어2', level: 24, rank: 5, ready: false },
                { name: '플레이어3', level: 8, rank: 2, ready: true },
                { name: '플레이어4', level: 42, rank: 7, ready: false }
            ],
            spectators: [
                { name: '관전자1', level: 5, rank: 1 },
                { name: '관전자2', level: 12, rank: 3 }
            ],
            gamemodes: [
                {
                    id: 'bumpercar',
                    name: '범퍼카',
                    description: '차량으로 서로 충돌하여 마지막까지 살아남는 플레이어가 승리합니다.',
                    image: 'img/gamemodes/bumpercar.png',
                    votes: 3
                },
                {
                    id: 'bomb',
                    name: '폭탄',
                    description: '폭탄을 다른 플레이어에게 전달하여 생존하세요.',
                    image: 'img/gamemodes/bomb.png',
                    votes: 1
                },
                {
                    id: 'avalanche',
                    name: '아발란체',
                    description: '경사로를 올라가며 떨어지는 차량들을 피하세요.',
                    image: 'img/gamemodes/avalanche.png',
                    votes: 0
                }
            ],
            maps: [
                {
                    id: 'bumpercar_arena',
                    name: '아레나',
                    image: 'img/maps/bumpercar_arena.png',
                    votes: 2
                }
            ],
            maxPlayers: 32
        });

        updateTimer(65);

        addChatMessage('시스템', '로비에 오신 것을 환영합니다!');
        addChatMessage('플레이어1', '안녕하세요!');
        addChatMessage('플레이어2', '같이 게임하실 분?');
    }, 500);
}

console.log('Lobby UI 초기화 완료');
