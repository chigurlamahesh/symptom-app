// ============================================
// AuraHealth AI — Medicine Reminder Engine
// Uses: localStorage, Web Audio API, Notifications
// ============================================

const STORAGE_KEY = 'aurahealth_reminders';
const DAY_NAMES   = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
const MED_ICONS   = ['fa-pills','fa-capsules','fa-syringe','fa-tablets','fa-prescription-bottle-medical'];

let reminders = [];
let selectedColor  = '#6366f1';
let selectedDays   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
let alarmAudioCtx  = null;
let alarmInterval  = null;
let firingAudioStop = null;  // function to stop the current alarm sound
let snoozedAlarms  = {};     // { id: snoozedUntilMinuteStr }

// ── INIT ────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    loadReminders();
    renderAll();
    setupForm();
    requestNotificationPermission();
    startAlarmChecker();
});

// ── STORAGE ─────────────────────────────────
function loadReminders() {
    try {
        reminders = JSON.parse(localStorage.getItem(STORAGE_KEY)) || [];
    } catch { reminders = []; }
}

function saveReminders() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(reminders));
}

function generateId() {
    return 'rem_' + Date.now().toString(36) + Math.random().toString(36).slice(2,6);
}

// ── FORM SETUP ──────────────────────────────
function setupForm() {
    // Day picker
    document.querySelectorAll('.day-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            btn.classList.toggle('active');
            updateSelectedDays();
        });
    });

    // Quick day presets
    document.getElementById('quick-everyday').addEventListener('click', () => {
        setDayButtons(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']);
    });
    document.getElementById('quick-weekday').addEventListener('click', () => {
        setDayButtons(['Mon','Tue','Wed','Thu','Fri']);
    });
    document.getElementById('quick-weekend').addEventListener('click', () => {
        setDayButtons(['Sat','Sun']);
    });

    // Color picker
    document.querySelectorAll('.color-swatch').forEach(sw => {
        sw.addEventListener('click', () => {
            document.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('active'));
            sw.classList.add('active');
            selectedColor = sw.dataset.color;
        });
    });

    // Add reminder button
    document.getElementById('add-reminder-btn').addEventListener('click', addReminder);

    // Allow Enter key to submit
    ['med-name','med-time','med-dosage','med-note'].forEach(id => {
        document.getElementById(id)?.addEventListener('keydown', e => {
            if (e.key === 'Enter') addReminder();
        });
    });

    // Notification permission banner button
    document.getElementById('notif-allow-btn')?.addEventListener('click', () => {
        Notification.requestPermission().then(perm => {
            if (perm === 'granted') {
                document.getElementById('notif-banner').style.display = 'none';
            }
        });
    });

    // Alarm overlay buttons
    document.getElementById('alarm-dismiss-btn').addEventListener('click', dismissAlarm);
    document.getElementById('alarm-snooze-btn').addEventListener('click', snoozeAlarm);
}

function setDayButtons(days) {
    document.querySelectorAll('.day-btn').forEach(btn => {
        if (days.includes(btn.dataset.day)) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });
    updateSelectedDays();
}

function updateSelectedDays() {
    selectedDays = [];
    document.querySelectorAll('.day-btn.active').forEach(btn => {
        selectedDays.push(btn.dataset.day);
    });
}

// ── ADD REMINDER ─────────────────────────────
function addReminder() {
    const name   = document.getElementById('med-name').value.trim();
    const time   = document.getElementById('med-time').value;
    const dosage = document.getElementById('med-dosage').value.trim();
    const note   = document.getElementById('med-note').value.trim();

    if (!name) { flashInput('med-name', 'Medicine name is required'); return; }
    if (!time) { flashInput('med-time', 'Please set a time'); return; }
    if (selectedDays.length === 0) {
        showToastRem('Please select at least one day.', 'warning');
        return;
    }

    const reminder = {
        id:      generateId(),
        name,
        time,
        dosage,
        days:    [...selectedDays],
        note,
        color:   selectedColor,
        active:  true,
        icon:    MED_ICONS[Math.floor(Math.random() * MED_ICONS.length)],
        created: Date.now()
    };

    reminders.push(reminder);
    saveReminders();
    renderAll();

    // Reset form
    document.getElementById('med-name').value  = '';
    document.getElementById('med-dosage').value = '';
    document.getElementById('med-note').value  = '';

    showToastRem(`✓ Reminder set for ${formatTime12(time)}`, 'success');
}

function flashInput(id, msg) {
    const el = document.getElementById(id);
    el.style.borderColor = 'var(--danger)';
    el.style.boxShadow   = '0 0 0 3px rgba(239,68,68,0.2)';
    el.focus();
    showToastRem(msg, 'error');
    setTimeout(() => {
        el.style.borderColor = '';
        el.style.boxShadow   = '';
    }, 2000);
}

// ── RENDER ──────────────────────────────────
function renderAll() {
    renderReminderList();
    renderTodaySchedule();
    updateCountBadge();
}

function renderReminderList() {
    const list  = document.getElementById('reminders-list');
    const empty = document.getElementById('reminders-empty');
    if (!list) return;

    list.innerHTML = '';

    if (reminders.length === 0) {
        empty?.classList.remove('hidden');
        return;
    }
    empty?.classList.add('hidden');

    // Sort by time
    const sorted = [...reminders].sort((a,b) => a.time.localeCompare(b.time));

    sorted.forEach((rem, idx) => {
        const card = document.createElement('div');
        card.className = 'reminder-card' + (rem.active ? '' : ' inactive');
        card.style.setProperty('--rem-color', rem.color);
        card.setAttribute('data-id', rem.id);
        card.style.animationDelay = `${idx * 0.05}s`;

        const daysLabel = rem.days.length === 7
            ? 'Every Day'
            : (rem.days.join(', ') || 'No days');

        card.innerHTML = `
            <div class="rem-icon-wrap" style="color:${rem.color}">
                <i class="fa-solid ${rem.icon}"></i>
            </div>
            <div class="rem-body">
                <div class="rem-name">${escHtml(rem.name)}</div>
                <div class="rem-meta">
                    <span class="rem-time-pill" style="color:${rem.color};background:${rem.color}18;border-color:${rem.color}33">
                        <i class="fa-regular fa-clock"></i> ${formatTime12(rem.time)}
                    </span>
                    ${rem.dosage ? `<span class="rem-dosage-pill">${escHtml(rem.dosage)}</span>` : ''}
                </div>
                <div class="rem-days"><i class="fa-regular fa-calendar"></i> ${daysLabel}</div>
                ${rem.note ? `<div class="rem-note">${escHtml(rem.note)}</div>` : ''}
            </div>
            <div class="rem-actions">
                <label class="rem-toggle">
                    <input type="checkbox" ${rem.active ? 'checked' : ''} data-id="${rem.id}" class="toggle-chk">
                    <span class="rem-toggle-track"></span>
                    <span class="rem-toggle-thumb"></span>
                </label>
                <button class="rem-delete-btn" data-id="${rem.id}" title="Delete reminder">
                    <i class="fa-solid fa-trash-can"></i>
                </button>
            </div>
        `;

        list.appendChild(card);
    });

    // Event delegation for toggles and deletes
    list.querySelectorAll('.toggle-chk').forEach(chk => {
        chk.addEventListener('change', e => {
            toggleReminder(e.target.dataset.id, e.target.checked);
        });
    });

    list.querySelectorAll('.rem-delete-btn').forEach(btn => {
        btn.addEventListener('click', e => {
            deleteReminder(e.currentTarget.dataset.id);
        });
    });
}

function renderTodaySchedule() {
    const container = document.getElementById('today-schedule');
    const section   = document.getElementById('upcoming-section');
    if (!container) return;

    const todayName = DAY_NAMES[new Date().getDay()];
    const nowMins   = getNowMinutes();

    const todayRems = reminders
        .filter(r => r.active && r.days.includes(todayName))
        .sort((a,b) => a.time.localeCompare(b.time));

    if (todayRems.length === 0) {
        section.style.display = 'none';
        return;
    }
    section.style.display = '';
    container.innerHTML = '';

    todayRems.forEach(rem => {
        const [h, m]  = rem.time.split(':').map(Number);
        const remMins = h * 60 + m;
        const isPast  = remMins < nowMins;

        const item = document.createElement('div');
        item.className = 'schedule-item' + (isPast ? ' past' : '');
        item.style.setProperty('--sc-color', rem.color);
        item.innerHTML = `
            <div class="schedule-dot"></div>
            <div>
                <div class="schedule-time">${formatTime12(rem.time)}</div>
                <div class="schedule-name">${escHtml(rem.name)}</div>
            </div>
            <div class="schedule-status">${isPast ? 'Done' : 'Upcoming'}</div>
        `;
        container.appendChild(item);
    });
}

function updateCountBadge() {
    const badge = document.getElementById('reminder-count-badge');
    if (badge) badge.textContent = reminders.filter(r => r.active).length;
}

// ── TOGGLE / DELETE ──────────────────────────
function toggleReminder(id, active) {
    const rem = reminders.find(r => r.id === id);
    if (rem) {
        rem.active = active;
        saveReminders();
        renderAll();
    }
}

function deleteReminder(id) {
    const card = document.querySelector(`.reminder-card[data-id="${id}"]`);
    if (card) {
        card.style.opacity = '0';
        card.style.transform = 'translateX(-20px)';
        card.style.transition = 'all 0.3s ease';
        setTimeout(() => {
            reminders = reminders.filter(r => r.id !== id);
            saveReminders();
            renderAll();
        }, 280);
    }
}

// ── ALARM CHECKER ────────────────────────────
function startAlarmChecker() {
    checkAlarms(); // check immediately
    // Check every 30 seconds
    alarmInterval = setInterval(checkAlarms, 30000);
}

function getNowMinutes() {
    const now = new Date();
    return now.getHours() * 60 + now.getMinutes();
}

function checkAlarms() {
    const now       = new Date();
    const todayName = DAY_NAMES[now.getDay()];
    const timeStr   = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;

    reminders
        .filter(r => r.active && r.days.includes(todayName) && r.time === timeStr)
        .forEach(rem => {
            // Check if snoozed
            if (snoozedAlarms[rem.id] === timeStr) return;
            fireAlarm(rem);
        });

    // Refresh schedule colors (past/upcoming)
    renderTodaySchedule();
}

// ── FIRE ALARM ───────────────────────────────
function fireAlarm(rem) {
    // Show overlay
    const overlay = document.getElementById('alarm-overlay');
    document.getElementById('alarm-fire-name').textContent = rem.name;
    document.getElementById('alarm-fire-time').textContent = formatTime12(rem.time) + (rem.dosage ? ' — ' + rem.dosage : '');
    document.getElementById('alarm-fire-note').textContent = rem.note || '';
    overlay.classList.remove('hidden');
    overlay.dataset.remId = rem.id;

    // Play audio alarm
    firingAudioStop = playAlarmSound();

    // Browser notification (works in background)
    sendNotification(rem);
}

function dismissAlarm() {
    const overlay = document.getElementById('alarm-overlay');
    overlay.classList.add('hidden');
    if (firingAudioStop) { firingAudioStop(); firingAudioStop = null; }
}

function snoozeAlarm() {
    const overlay = document.getElementById('alarm-overlay');
    const id = overlay.dataset.remId;

    if (firingAudioStop) { firingAudioStop(); firingAudioStop = null; }
    overlay.classList.add('hidden');

    // Snooze for 10 minutes
    const snoozeTime = new Date(Date.now() + 10 * 60 * 1000);
    const snoozeStr  = `${String(snoozeTime.getHours()).padStart(2,'0')}:${String(snoozeTime.getMinutes()).padStart(2,'0')}`;

    // Create a one-off snooze reminder copy
    const original = reminders.find(r => r.id === id);
    if (original) {
        const snoozeRem = {
            ...original,
            id:   generateId(),
            time: snoozeStr,
            days: [DAY_NAMES[new Date().getDay()]],
            name: original.name + ' (Snoozed)',
            active: true
        };
        reminders.push(snoozeRem);
        saveReminders();
        renderAll();
        showToastRem(`Snoozed until ${formatTime12(snoozeStr)}`, 'info');
    }
}

// ── WEB AUDIO ALARM SOUND ────────────────────
function playAlarmSound() {
    try {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return () => {};

        const ctx = new AudioContext();
        let stopped = false;

        function playPattern() {
            if (stopped) return;

            // Three escalating beeps
            const freqs   = [880, 1046, 1318];
            const beepGap = 0.18;

            freqs.forEach((freq, i) => {
                const t   = ctx.currentTime + i * beepGap;
                const osc = ctx.createOscillator();
                const gain = ctx.createGain();
                osc.connect(gain);
                gain.connect(ctx.destination);

                osc.type = 'sine';
                osc.frequency.value = freq;

                gain.gain.setValueAtTime(0, t);
                gain.gain.linearRampToValueAtTime(0.35, t + 0.02);
                gain.gain.exponentialRampToValueAtTime(0.001, t + beepGap - 0.02);

                osc.start(t);
                osc.stop(t + beepGap);
            });

            // Repeat the pattern every 2 seconds
            if (!stopped) {
                setTimeout(playPattern, 2000);
            }
        }

        playPattern();

        return function stopAlarm() {
            stopped = true;
            try { ctx.close(); } catch(e) {}
        };
    } catch (e) {
        console.warn('Audio alarm error:', e);
        return () => {};
    }
}

// ── BROWSER NOTIFICATION ─────────────────────
function requestNotificationPermission() {
    if (!('Notification' in window)) return;
    if (Notification.permission === 'default') {
        const banner = document.getElementById('notif-banner');
        if (banner) banner.style.display = 'flex';
    }
}

function sendNotification(rem) {
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    new Notification('💊 Medicine Reminder — AuraHealth AI', {
        body: `Time to take: ${rem.name}${rem.dosage ? ' (' + rem.dosage + ')' : ''}${rem.note ? '\n' + rem.note : ''}`,
        icon: '/static/favicon.png',
        tag:  rem.id,
        requireInteraction: true
    });
}

// ── HELPERS ──────────────────────────────────
function formatTime12(timeStr) {
    if (!timeStr) return '';
    const [h, m] = timeStr.split(':').map(Number);
    const ampm   = h >= 12 ? 'PM' : 'AM';
    const h12    = h % 12 || 12;
    return `${h12}:${String(m).padStart(2,'0')} ${ampm}`;
}

function escHtml(str) {
    return String(str)
        .replace(/&/g,'&amp;')
        .replace(/</g,'&lt;')
        .replace(/>/g,'&gt;')
        .replace(/"/g,'&quot;')
        .replace(/'/g,'&#039;');
}

function showToastRem(message, type = 'info') {
    const existing = document.getElementById('rem-toast');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.id = 'rem-toast';

    const colors = {
        success: { bg: 'rgba(34,197,94,0.15)',  border: 'rgba(34,197,94,0.4)',  color: '#22c55e' },
        warning: { bg: 'rgba(245,158,11,0.15)', border: 'rgba(245,158,11,0.4)', color: '#f59e0b' },
        error:   { bg: 'rgba(239,68,68,0.15)',  border: 'rgba(239,68,68,0.4)',  color: '#ef4444' },
        info:    { bg: 'rgba(99,102,241,0.15)', border: 'rgba(99,102,241,0.4)', color: '#6366f1' },
    };
    const c = colors[type] || colors.info;

    Object.assign(toast.style, {
        position: 'fixed', bottom: '2rem', right: '2rem',
        padding: '0.9rem 1.4rem',
        background: c.bg, border: `1px solid ${c.border}`,
        color: c.color, borderRadius: '12px',
        fontFamily: 'Inter, sans-serif', fontWeight: '600',
        fontSize: '0.9rem', zIndex: '9999',
        backdropFilter: 'blur(12px)',
        boxShadow: '0 8px 24px rgba(0,0,0,0.3)',
        animation: 'fadeIn 0.3s ease',
        maxWidth: '320px',
        transition: 'opacity 0.3s'
    });

    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
    }, 3500);
}
