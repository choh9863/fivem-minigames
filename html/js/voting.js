// ========================================
// 투표 시스템 클라이언트 스크립트
// ========================================

let votingState = {
    phase: null, // 'gamemode' or 'map'
    timer: 0,
    myVote: null,
    options: []
};

// ========================================
// NUI 메시지 수신
// ========================================
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'startGamemodeVoting') {
        showVoting('gamemode', data.gamemodes, data.timer);
    } else if (data.action === 'startMapVoting') {
        showVoting('map', data.maps, data.timer);
    } else if (data.action === 'updateVotingTimer') {
        updateTimer(data.timer);
    } else if (data.action === 'updateVoteCounts') {
        updateVoteCounts(data.votes);
    } else if (data.action === 'votingComplete') {
        hideVoting();
    }
});

// ========================================
// 투표 UI 표시
// ========================================
function showVoting(phase, options, timer) {
    votingState.phase = phase;
    votingState.timer = timer;
    votingState.options = options;
    votingState.myVote = null;

    const overlay = document.getElementById('voting-overlay');
    const title = document.getElementById('voting-title');
    const grid = document.getElementById('voting-grid');

    overlay.classList.remove('hidden');
    title.textContent = phase === 'gamemode' ? '게임모드 투표' : '맵 투표';

    // 투표 카드 생성
    grid.innerHTML = '';
    options.forEach((option, index) => {
        const card = createVoteCard(option, index);
        grid.appendChild(card);
    });

    // 타이머 업데이트
    document.getElementById('voting-time').textContent = timer;

    console.log(`[Voting] ${phase} voting started with ${options.length} options`);
}

// ========================================
// 투표 카드 생성
// ========================================
function createVoteCard(option, index) {
    const card = document.createElement('div');
    card.className = 'vote-card';
    card.dataset.id = option.id;

    // 배경 이미지 설정 (이미지가 있는 경우)
    if (option.image) {
        card.style.backgroundImage = `url('${option.image}')`;
    }

    // 카드 내용
    card.innerHTML = `
        <div class="vote-count">0</div>
        <div class="vote-info">
            <div class="vote-name">${option.name || option.id}</div>
            ${option.description ? `<div class="vote-desc">${option.description}</div>` : ''}
        </div>
    `;

    // 클릭 이벤트
    card.addEventListener('click', () => {
        vote(option.id);
    });

    return card;
}

// ========================================
// 투표하기
// ========================================
function vote(optionId) {
    // 이미 투표한 것과 같으면 무시
    if (votingState.myVote === optionId) {
        return;
    }

    votingState.myVote = optionId;

    // 선택 표시 업데이트
    document.querySelectorAll('.vote-card').forEach(card => {
        card.classList.remove('selected');
    });

    const selectedCard = document.querySelector(`[data-id="${optionId}"]`);
    if (selectedCard) {
        selectedCard.classList.add('selected');
    }

    // 서버에 투표 전송
    const eventName = votingState.phase === 'gamemode'
        ? 'voteGamemode'
        : 'voteMap';

    fetch(`https://minigames/${eventName}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ id: optionId })
    });

    console.log(`[Voting] Voted for ${optionId}`);
}

// ========================================
// 타이머 업데이트
// ========================================
function updateTimer(time) {
    votingState.timer = time;
    const timerElement = document.getElementById('voting-time');

    if (timerElement) {
        timerElement.textContent = time;

        // 시간이 10초 이하면 빨간색으로 변경
        const timerContainer = timerElement.parentElement;
        if (time <= 10) {
            timerContainer.style.borderColor = '#ff0000';
            timerContainer.style.color = '#ff0000';
            timerContainer.style.background = 'linear-gradient(135deg, rgba(255, 0, 0, 0.2), rgba(204, 0, 0, 0.2))';
        } else {
            timerContainer.style.borderColor = '#00d9ff';
            timerContainer.style.color = '#00d9ff';
            timerContainer.style.background = 'linear-gradient(135deg, rgba(0, 217, 255, 0.2), rgba(0, 170, 204, 0.2))';
        }
    }

    // 시간이 0이 되면 숨기기
    if (time <= 0) {
        setTimeout(() => {
            hideVoting();
        }, 1000);
    }
}

// ========================================
// 투표 수 업데이트
// ========================================
function updateVoteCounts(votes) {
    Object.entries(votes).forEach(([id, count]) => {
        const card = document.querySelector(`[data-id="${id}"]`);
        if (card) {
            const countElement = card.querySelector('.vote-count');
            if (countElement) {
                // 애니메이션 효과를 위해 클래스 추가
                countElement.style.animation = 'none';
                setTimeout(() => {
                    countElement.style.animation = '';
                }, 10);

                countElement.textContent = count;
            }
        }
    });
}

// ========================================
// 투표 UI 숨기기
// ========================================
function hideVoting() {
    const overlay = document.getElementById('voting-overlay');
    overlay.classList.add('hidden');

    // 상태 초기화
    votingState.phase = null;
    votingState.timer = 0;
    votingState.myVote = null;
    votingState.options = [];

    console.log('[Voting] Voting closed');
}

// ========================================
// ESC 키 처리 (투표 중에는 ESC 비활성화)
// ========================================
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !document.getElementById('voting-overlay').classList.contains('hidden')) {
        // 투표 중에는 ESC 키 무시
        e.preventDefault();
        e.stopPropagation();
    }
});

console.log('[Voting] Voting system loaded');
