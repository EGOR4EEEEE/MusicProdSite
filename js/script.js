// ── Навигация ──────────────────────────────────────────────────────
const PAGES = ['home','tariffs','about','contacts','reviews'];

function nav(id) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.getElementById(id).classList.add('active');
  document.querySelectorAll('.nav-link').forEach(l => {
    l.classList.toggle('active', l.dataset.page === id);
  });
  closeMob();
  window.scrollTo(0, 0);
  if (id === 'contacts') initMap();
  if (id === 'reviews')  loadReviews();
}

// ── API ────────────────────────────────────────────────────────────
const API = 'http://localhost:3001/api';

// ── Карта (Leaflet + CartoDB dark) ────────────────────────────────
let _map = null;

function initMap() {
  const el = document.getElementById('map');
  if (!el || _map) {
    if (_map) _map.invalidateSize();
    return;
  }

  // ул. Рубинштейна, 15 — Санкт-Петербург
  _map = L.map('map', { zoomControl: true, scrollWheelZoom: false })
           .setView([59.9284, 30.3488], 16);

  L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions" target="_blank">CARTO</a>',
    subdomains: 'abcd',
    maxZoom: 19
  }).addTo(_map);

  const icon = L.divIcon({
    html: `<div style="
      width:16px;height:16px;border-radius:50%;
      background:#9333ea;border:3px solid #c084fc;
      box-shadow:0 0 0 6px rgba(147,51,234,.25),0 0 14px rgba(147,51,234,.6);
    "></div>`,
    className: '',
    iconSize: [16, 16],
    iconAnchor: [8, 8],
    popupAnchor: [0, -12]
  });

  L.marker([59.9284, 30.3488], { icon })
    .addTo(_map)
    .bindPopup('<b>Music Prod</b><br>ул. Рубинштейна, 15<br><small>5 мин от м. Достоевская</small>')
    .openPopup();
}

// ── Бургер ─────────────────────────────────────────────────────────
function toggleMob() {
  document.getElementById('burger').classList.toggle('open');
  document.getElementById('mobMenu').classList.toggle('open');
}
function closeMob() {
  document.getElementById('burger').classList.remove('open');
  document.getElementById('mobMenu').classList.remove('open');
}

// ── Модальное окно ─────────────────────────────────────────────────
function openModal(tariff) {
  const overlay = document.getElementById('modalOverlay');
  overlay.classList.add('open');
  if (tariff) {
    const sel = document.getElementById('fTariff');
    for (let i = 0; i < sel.options.length; i++) {
      if (sel.options[i].value === tariff) { sel.selectedIndex = i; break; }
    }
  }
}
function closeModal() {
  document.getElementById('modalOverlay').classList.remove('open');
}

document.getElementById('modalOverlay').addEventListener('click', function(e) {
  if (e.target === this) closeModal();
});

// ── Форма → POST /api/bookings ─────────────────────────────────────
document.getElementById('bookingForm').addEventListener('submit', async function(e) {
  e.preventDefault();
  const btn  = this.querySelector('.form-submit');
  const orig = btn.innerHTML;
  btn.disabled = true;
  btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Отправка...';

  const data = {
    name:     document.getElementById('fName').value,
    phone:    document.getElementById('fPhone').value,
    email:    document.getElementById('fEmail').value,
    tariff:   document.getElementById('fTariff').value,
    engineer: document.getElementById('fEngineer').value,
    date:     document.getElementById('fDate').value,
    comment:  document.getElementById('fComment').value,
  };

  try {
    const res = await fetch(`${API}/bookings`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(data),
    });
    if (!res.ok) throw new Error();
  } catch {
    // API недоступен — тост всё равно показываем
  }

  btn.disabled = false;
  btn.innerHTML = orig;
  closeModal();
  this.reset();
  showToast();
});

// ── Тост ───────────────────────────────────────────────────────────
function showToast() {
  const t = document.getElementById('toast');
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 3500);
}

// ── Отзывы из БД ───────────────────────────────────────────────────
const RU_MONTHS = ['января','февраля','марта','апреля','мая','июня',
                   'июля','августа','сентября','октября','ноября','декабря'];

function fmtDate(iso) {
  const [y, m, d] = iso.split('-');
  return `${parseInt(d)} ${RU_MONTHS[parseInt(m) - 1]} ${y}`;
}

async function loadReviews() {
  const grid = document.getElementById('reviews-list');
  if (!grid || grid.dataset.loaded) return;
  try {
    const res = await fetch(`${API}/reviews`);
    if (!res.ok) throw new Error();
    const list = await res.json();
    grid.innerHTML = list.map(r => `
      <div class="rv-card">
        <div class="rv-top">
          <div class="rv-stars">${'★'.repeat(r.rating)}${'☆'.repeat(5 - r.rating)}</div>
          <div class="rv-date">${fmtDate(r.review_date)}</div>
        </div>
        <p class="rv-text">${r.review_text}</p>
        <div class="rv-author">
          <div class="rv-avatar"><i class="fa-solid fa-user"></i></div>
          <div>
            <div class="rv-name">${r.author_name}</div>
            <div class="rv-city">${r.city ?? ''}</div>
          </div>
        </div>
      </div>`).join('');
    grid.dataset.loaded = '1';
  } catch {
    // API недоступен — остаётся статический HTML
  }
}

// ── Аудиоплеер ─────────────────────────────────────────────────────
const GENRE_ICONS = {
  'Pop':        'fa-music',
  'Rock':       'fa-guitar',
  'Electronic': 'fa-waveform-lines',
  'Hip-Hop':    'fa-microphone',
  'Jazz':       'fa-saxophone',
  'R&B':        'fa-record-vinyl',
};

let currentAudio = null;

function fmtTime(sec) {
  if (!sec || isNaN(sec)) return '0:00';
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function togglePlay(btn) {
  const card  = btn.closest('.work-card');
  const audio = card.querySelector('.work-audio');

  // Останавливаем предыдущий трек
  if (currentAudio && currentAudio !== audio) {
    currentAudio.pause();
    const prevCard = currentAudio.closest('.work-card');
    prevCard.querySelector('.play-btn i').className = 'fa-solid fa-play';
    prevCard.classList.remove('playing');
  }

  if (audio.paused) {
    audio.play();
    btn.querySelector('i').className = 'fa-solid fa-pause';
    card.classList.add('playing');
    currentAudio = audio;
  } else {
    audio.pause();
    btn.querySelector('i').className = 'fa-solid fa-play';
    card.classList.remove('playing');
    currentAudio = null;
  }
}

function seekAudio(e, wrap) {
  const card  = wrap.closest('.work-card');
  const audio = card.querySelector('.work-audio');
  if (!audio.duration) return;
  const rect  = wrap.getBoundingClientRect();
  audio.currentTime = ((e.clientX - rect.left) / rect.width) * audio.duration;
}

function buildWorkCard(w) {
  const icon = GENRE_ICONS[w.genre] || 'fa-music';
  return `
    <div class="swiper-slide">
      <div class="work-card">
        <audio class="work-audio" src="${w.audio_url}" preload="none"></audio>
        <div class="work-cover">
          <div class="work-cover-placeholder"><i class="fa-solid ${icon}"></i></div>
          <span class="work-genre">${w.genre ?? ''}</span>
        </div>
        <div class="work-info">
          <div class="work-title">${w.title}</div>
          <div class="work-artist">${w.artist}</div>
          <div class="work-player">
            <button class="play-btn" onclick="togglePlay(this)">
              <i class="fa-solid fa-play"></i>
            </button>
            <div class="work-progress-wrap" onclick="seekAudio(event, this)">
              <div class="work-progress-bar"></div>
            </div>
            <span class="work-time">0:00</span>
          </div>
        </div>
      </div>
    </div>`;
}

function bindAudioEvents(card) {
  const audio   = card.querySelector('.work-audio');
  const bar     = card.querySelector('.work-progress-bar');
  const timeEl  = card.querySelector('.work-time');
  const playBtn = card.querySelector('.play-btn');

  audio.addEventListener('timeupdate', () => {
    const pct = audio.duration ? (audio.currentTime / audio.duration) * 100 : 0;
    bar.style.width = pct + '%';
    timeEl.textContent = `${fmtTime(audio.currentTime)} / ${fmtTime(audio.duration)}`;
  });

  audio.addEventListener('ended', () => {
    playBtn.querySelector('i').className = 'fa-solid fa-play';
    card.classList.remove('playing');
    bar.style.width = '0%';
    timeEl.textContent = '0:00';
    currentAudio = null;
  });

  audio.addEventListener('loadedmetadata', () => {
    timeEl.textContent = `0:00 / ${fmtTime(audio.duration)}`;
  });
}

// ── Статические треки (запасной вариант) ──────────────────────────
const FALLBACK_WORKS = [
  { title: 'Первый снег',     artist: 'Анастасия Лукина', genre: 'Pop',        audio_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3' },
  { title: 'Огонь внутри',   artist: 'Группа «Восток»',  genre: 'Rock',       audio_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3' },
  { title: 'Night Drive',     artist: 'DJ Phantom',       genre: 'Electronic', audio_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3' },
  { title: 'Мой город',      artist: 'MC Север',         genre: 'Hip-Hop',    audio_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3' },
  { title: 'Blue Morning',    artist: 'Trio Latitude',    genre: 'Jazz',       audio_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3' },
  { title: 'Далеко от тебя', artist: 'Виктория Соль',    genre: 'R&B',        audio_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3' },
];

// ── Загрузка работ из БД ───────────────────────────────────────────
async function loadWorks() {
  const wrapper = document.getElementById('works-swiper-wrapper');
  if (!wrapper) return;
  let works = FALLBACK_WORKS;
  try {
    const res = await fetch(`${API}/works`);
    if (res.ok) works = await res.json();
  } catch { /* API недоступен — используем статику */ }
  wrapper.innerHTML = works.map(buildWorkCard).join('');
  wrapper.querySelectorAll('.work-card').forEach(bindAudioEvents);
}

// ── Swiper ─────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', async function() {
  await loadWorks();

  new Swiper('.swiper', {
    slidesPerView: 'auto',
    spaceBetween: 18,
    loop: true,
    pagination: { el: '.swiper-pagination', clickable: true },
    breakpoints: {
      640:  { spaceBetween: 18 },
      1024: { spaceBetween: 22 },
    }
  });

  nav('home');
});
