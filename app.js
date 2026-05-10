// ============================================================
// app.js - Logika Utama Aplikasi (v2 - Fitur Lengkap)
// ============================================================

import { supabaseClient } from './supabase.js';

const ROLES = {
  ADMIN: 'admin',
  PENGURUS_KAS: 'pengurus_kas',
  PENGURUS_ABSENSI: 'pengurus_absensi',
  PENGUNJUNG: 'pengunjung',
};

const PAGE_ACCESS = {
  admin:             ['index.html','kas.html','absensi.html','laporan.html','jadwal.html','tugas.html','materi.html','confession.html','memories.html','quotes.html','polling.html','pengumuman.html','leaderboard.html','profil.html'],
  pengurus_kas:      ['kas.html','laporan.html','jadwal.html','tugas.html','materi.html','confession.html','memories.html','quotes.html','polling.html','pengumuman.html','leaderboard.html','profil.html'],
  pengurus_absensi:  ['absensi.html','laporan.html','jadwal.html','tugas.html','materi.html','confession.html','memories.html','quotes.html','polling.html','pengumuman.html','leaderboard.html','profil.html'],
  pengunjung:        ['laporan.html','jadwal.html','tugas.html','materi.html','confession.html','memories.html','quotes.html','polling.html','pengumuman.html','leaderboard.html','profil.html'],
};

const XP_REWARDS = {
  hadir: 5,
  bayar_kas: 10,
  upload_materi: 15,
  ikut_voting: 3,
  kontribusi_sosial: 5,
  login_harian: 2,
  upload_memory: 5,
  kirim_shoutbox: 1,
};

const LEVEL_THRESHOLDS = [0, 50, 120, 220, 350, 520, 730, 1000, 1350, 1800, 2500];

const SIDEBAR_MENU = [
  { section: 'Menu Utama' },
  { href: 'index.html',       icon: '📊', label: 'Dashboard',     roles: ['admin'] },
  { href: 'kas.html',         icon: '💰', label: 'Kas Kelas',     roles: ['admin','pengurus_kas'] },
  { href: 'absensi.html',     icon: '📋', label: 'Absensi',       roles: ['admin','pengurus_absensi'] },
  { href: 'laporan.html',     icon: '📈', label: 'Laporan',       roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { section: 'Akademik' },
  { href: 'jadwal.html',      icon: '📅', label: 'Jadwal',        roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { href: 'tugas.html',       icon: '📝', label: 'Tugas',         roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { href: 'materi.html',      icon: '📚', label: 'Bank Materi',   roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { section: 'Sosial' },
  { href: 'pengumuman.html',  icon: '📢', label: 'Pengumuman',    roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { href: 'confession.html',  icon: '💌', label: 'Confession',    roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { href: 'memories.html',    icon: '📸', label: 'Memories',      roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { href: 'quotes.html',      icon: '💬', label: 'Quotes',        roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { href: 'polling.html',     icon: '🗳️', label: 'Polling',       roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { section: 'Gamifikasi' },
  { href: 'leaderboard.html', icon: '🏆', label: 'Leaderboard',   roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { href: 'profil.html',      icon: '👤', label: 'Profil Saya',   roles: ['admin','pengurus_kas','pengurus_absensi','pengunjung'] },
  { section: 'Admin' },
  { href: '#manage-users',    icon: '👥', label: 'Kelola Akun',   roles: ['admin'], id: 'manage-users-link' },
];

window.App = {

  async getSession() {
    const { data: { session } } = await supabaseClient.auth.getSession();
    return session;
  },

  async getProfile(userId) {
    const { data } = await supabaseClient.from('profiles').select('*').eq('id', userId).single();
    return data;
  },

  async getCurrentUser() {
    const session = await this.getSession();
    if (!session) return null;
    const profile = await this.getProfile(session.user.id);
    return { ...session.user, profile };
  },

  async logout() {
    await supabaseClient.auth.signOut();
    window.location.href = 'login.html';
  },

  async requireAuth(allowedRoles = null) {
    const user = await this.getCurrentUser();
    if (!user) { window.location.href = 'login.html'; return null; }
    const role = user.profile?.role;
    if (allowedRoles && !allowedRoles.includes(role)) { window.location.href = 'akses-ditolak.html'; return null; }
    return user;
  },

  async checkPageAccess() {
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const user = await this.getCurrentUser();
    if (!user) { if (currentPage !== 'login.html') window.location.href = 'login.html'; return null; }
    const role = user.profile?.role;
    const allowed = PAGE_ACCESS[role] || [];
    if (!allowed.includes(currentPage) && currentPage !== 'akses-ditolak.html') { window.location.href = 'akses-ditolak.html'; return null; }
    return user;
  },

  // ── DARK MODE ──────────────────────────────────────────────
  initDarkMode() {
    const saved = localStorage.getItem('darkMode');
    if (saved === 'true' || (!saved && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      document.documentElement.setAttribute('data-theme', 'dark');
    }
  },

  toggleDarkMode() {
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    document.documentElement.setAttribute('data-theme', isDark ? 'light' : 'dark');
    localStorage.setItem('darkMode', !isDark);
    const btn = document.getElementById('dark-mode-toggle');
    if (btn) btn.textContent = isDark ? '🌙' : '☀️';
  },

  // ── THEME ──────────────────────────────────────────────────
  async loadTheme() {
    try {
      const { data } = await supabaseClient.from('class_settings').select('value').eq('key', 'theme_color').single();
      if (data?.value) {
        document.documentElement.style.setProperty('--accent', data.value);
        document.documentElement.style.setProperty('--accent-hover', this.adjustColor(data.value, -20));
        document.documentElement.style.setProperty('--accent-light', this.adjustColor(data.value, 180));
      }
    } catch (e) { /* use default theme */ }
  },

  adjustColor(hex, amount) {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = Math.min(255, Math.max(0, (num >> 16) + amount));
    const g = Math.min(255, Math.max(0, ((num >> 8) & 0x00FF) + amount));
    const b = Math.min(255, Math.max(0, (num & 0x0000FF) + amount));
    return `#${(1 << 24 | r << 16 | g << 8 | b).toString(16).slice(1)}`;
  },

  // ── UI HELPERS ─────────────────────────────────────────────
  showToast(message, type = 'success') {
    let container = document.getElementById('toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'toast-container';
      document.body.appendChild(container);
    }
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `<span class="toast-icon">${type === 'success' ? '✓' : type === 'error' ? '✕' : 'ℹ'}</span><span>${message}</span>`;
    container.appendChild(toast);
    requestAnimationFrame(() => toast.classList.add('show'));
    setTimeout(() => { toast.classList.remove('show'); setTimeout(() => toast.remove(), 300); }, 3500);
  },

  showLoading(containerId) {
    const el = document.getElementById(containerId);
    if (el) el.innerHTML = '<div class="loading-state"><div class="spinner"></div><p>Memuat data...</p></div>';
  },

  showEmpty(containerId, message = 'Tidak ada data ditemukan') {
    const el = document.getElementById(containerId);
    if (el) el.innerHTML = `<div class="empty-state"><div class="empty-icon">📭</div><p>${message}</p></div>`;
  },

  showSkeleton(containerId, count = 3) {
    const el = document.getElementById(containerId);
    if (el) el.innerHTML = Array(count).fill('<div class="skeleton-card"><div class="skeleton-line w-60"></div><div class="skeleton-line w-40"></div><div class="skeleton-line w-80"></div></div>').join('');
  },

  async confirmDelete(message = 'Yakin ingin menghapus data ini?') {
    return new Promise((resolve) => {
      const overlay = document.createElement('div');
      overlay.className = 'confirm-overlay';
      overlay.innerHTML = `<div class="confirm-dialog"><div class="confirm-icon">⚠️</div><h3>Konfirmasi Hapus</h3><p>${message}</p><div class="confirm-actions"><button class="btn btn-secondary" id="confirm-cancel">Batal</button><button class="btn btn-danger" id="confirm-ok">Ya, Hapus</button></div></div>`;
      document.body.appendChild(overlay);
      requestAnimationFrame(() => overlay.classList.add('show'));
      document.getElementById('confirm-ok').onclick = () => { overlay.remove(); resolve(true); };
      document.getElementById('confirm-cancel').onclick = () => { overlay.remove(); resolve(false); };
    });
  },

  formatCurrency(amount) {
    return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(amount);
  },

  formatDate(dateStr) {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' });
  },

  formatDateShort(dateStr) {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
  },

  formatDateTime(dateStr) {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  },

  formatDateInput(dateStr) {
    if (!dateStr) return '';
    return new Date(dateStr).toISOString().split('T')[0];
  },

  formatTime(timeStr) {
    if (!timeStr) return '-';
    return timeStr.substring(0, 5);
  },

  timeAgo(dateStr) {
    const now = new Date();
    const d = new Date(dateStr);
    const diff = Math.floor((now - d) / 1000);
    if (diff < 60) return 'baru saja';
    if (diff < 3600) return `${Math.floor(diff / 60)} menit lalu`;
    if (diff < 86400) return `${Math.floor(diff / 3600)} jam lalu`;
    if (diff < 2592000) return `${Math.floor(diff / 86400)} hari lalu`;
    return this.formatDateShort(dateStr);
  },

  getRoleBadge(role) {
    const map = {
      admin:             { label: 'Admin',             class: 'badge-admin' },
      pengurus_kas:      { label: 'Pengurus Kas',      class: 'badge-kas' },
      pengurus_absensi:  { label: 'Pengurus Absensi',  class: 'badge-absensi' },
      pengunjung:        { label: 'Pengunjung',        class: 'badge-pengunjung' },
    };
    const r = map[role] || { label: role, class: '' };
    return `<span class="badge ${r.class}">${r.label}</span>`;
  },

  getStatusBadge(status) {
    const map = { Hadir: 'badge-hadir', Izin: 'badge-izin', Sakit: 'badge-sakit', Alpha: 'badge-alpha' };
    return `<span class="badge ${map[status] || ''}">${status}</span>`;
  },

  // ── XP SYSTEM ──────────────────────────────────────────────
  async addXP(userId, amount, reason) {
    await supabaseClient.from('xp_logs').insert({ user_id: userId, amount, reason });
    const { data: profile } = await supabaseClient.from('profiles').select('xp, level').eq('id', userId).single();
    if (profile) {
      const newXP = (profile.xp || 0) + amount;
      const newLevel = this.calculateLevel(newXP);
      await supabaseClient.from('profiles').update({ xp: newXP, level: newLevel }).eq('id', userId);
      if (newLevel > (profile.level || 1)) {
        this.showToast(`Level Up! Kamu sekarang Level ${newLevel} 🎉`, 'success');
      }
    }
  },

  calculateLevel(xp) {
    for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
      if (xp >= LEVEL_THRESHOLDS[i]) return i + 1;
    }
    return 1;
  },

  getLevelProgress(xp) {
    const level = this.calculateLevel(xp);
    const current = LEVEL_THRESHOLDS[level - 1] || 0;
    const next = LEVEL_THRESHOLDS[level] || LEVEL_THRESHOLDS[LEVEL_THRESHOLDS.length - 1] + 500;
    const progress = ((xp - current) / (next - current)) * 100;
    return { level, progress: Math.min(100, Math.max(0, progress)), current, next, xp };
  },

  getLevelBadge(level) {
    const badges = ['🌱','🌿','🌲','⭐','🌟','💫','🔥','💎','👑','🏆','🎖️'];
    return badges[Math.min(level - 1, badges.length - 1)] || '🌱';
  },

  // ── COUNTDOWN ──────────────────────────────────────────────
  getCountdown(targetDate) {
    const now = new Date();
    const target = new Date(targetDate);
    const diff = target - now;
    if (diff <= 0) return { expired: true, text: 'Sudah lewat' };
    const days = Math.floor(diff / 86400000);
    const hours = Math.floor((diff % 86400000) / 3600000);
    const minutes = Math.floor((diff % 3600000) / 60000);
    const seconds = Math.floor((diff % 60000) / 1000);
    return { expired: false, days, hours, minutes, seconds, text: `${days}h ${hours}j ${minutes}m` };
  },

  // ── SIDEBAR GENERATION ────────────────────────────────────
  generateSidebar(user) {
    const role = user?.profile?.role;
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';

    let menuHTML = '';
    SIDEBAR_MENU.forEach(item => {
      if (item.section) {
        menuHTML += `<div class="nav-section-label">${item.section}</div>`;
      } else if (item.roles.includes(role)) {
        const isActive = item.href === currentPage ? 'active' : '';
        const idAttr = item.id ? `id="${item.id}"` : '';
        menuHTML += `<a class="nav-link ${isActive}" href="${item.href}" ${idAttr}><span class="nav-icon">${item.icon}</span> ${item.label}</a>`;
      }
    });

    return `
    <aside id="sidebar">
      <div class="sidebar-header">
        <div class="sidebar-brand">
          <div class="brand-icon">🎓</div>
          <div><div class="brand-name">ManajemenKelas</div><div class="brand-sub">Sistem Informasi</div></div>
        </div>
        <div class="sidebar-user">
          <div class="user-avatar" id="sidebar-avatar">${(user?.profile?.full_name || 'U')[0].toUpperCase()}</div>
          <div class="user-info">
            <div id="sidebar-name">${user?.profile?.full_name || user?.email || 'Pengguna'}</div>
            <div id="sidebar-role">${this.getRoleBadge(role)}</div>
          </div>
        </div>
      </div>
      <nav class="sidebar-nav">${menuHTML}</nav>
      <div class="sidebar-footer">
        <div class="sidebar-actions">
          <button class="btn-icon-sidebar" id="dark-mode-toggle" title="Toggle Dark Mode">${isDark ? '☀️' : '🌙'}</button>
          <button class="btn-icon-sidebar" id="music-toggle" title="Toggle Musik">🎵</button>
        </div>
        <button id="logout-btn">🚪 Logout</button>
      </div>
    </aside>
    <div id="sidebar-overlay"></div>`;
  },

  async initSidebar(user) {
    const appLayout = document.querySelector('.app-layout');
    if (!appLayout) return;

    const existingSidebar = document.getElementById('sidebar');
    const existingOverlay = document.getElementById('sidebar-overlay');
    if (existingSidebar) existingSidebar.remove();
    if (existingOverlay) existingOverlay.remove();

    appLayout.insertAdjacentHTML('afterbegin', this.generateSidebar(user));

    const toggleBtn = document.getElementById('sidebar-toggle');
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebar-overlay');

    if (toggleBtn) {
      toggleBtn.addEventListener('click', () => {
        sidebar?.classList.toggle('open');
        overlay?.classList.toggle('show');
      });
    }
    if (overlay) {
      overlay.addEventListener('click', () => {
        sidebar?.classList.remove('open');
        overlay?.classList.remove('show');
      });
    }

    document.getElementById('logout-btn')?.addEventListener('click', () => this.logout());
    document.getElementById('dark-mode-toggle')?.addEventListener('click', () => this.toggleDarkMode());

    this.initBackgroundMusic();
    await this.trackLogin(user);
  },

  // ── BACKGROUND MUSIC ──────────────────────────────────────
  initBackgroundMusic() {
    const btn = document.getElementById('music-toggle');
    if (!btn) return;
    let audio = document.getElementById('bg-music');
    if (!audio) {
      audio = document.createElement('audio');
      audio.id = 'bg-music';
      audio.loop = true;
      audio.volume = 0.15;
      audio.src = 'https://cdn.pixabay.com/download/audio/2022/02/22/audio_d1718ab41b.mp3?filename=please-calm-my-mind-125566.mp3';
      document.body.appendChild(audio);
    }
    const musicOn = localStorage.getItem('musicOn') === 'true';
    btn.textContent = musicOn ? '🔊' : '🎵';
    if (musicOn) audio.play().catch(() => {});

    btn.addEventListener('click', () => {
      if (audio.paused) {
        audio.play().catch(() => {});
        localStorage.setItem('musicOn', 'true');
        btn.textContent = '🔊';
      } else {
        audio.pause();
        localStorage.setItem('musicOn', 'false');
        btn.textContent = '🎵';
      }
    });
  },

  // ── LOGIN TRACKING ────────────────────────────────────────
  async trackLogin(user) {
    if (!user?.id) return;
    const today = new Date().toISOString().split('T')[0];
    const lastLogin = user.profile?.last_login;
    if (lastLogin === today) return;

    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
    const newStreak = lastLogin === yesterday ? (user.profile?.streak_login || 0) + 1 : 1;

    await supabaseClient.from('profiles').update({
      last_login: today,
      streak_login: newStreak
    }).eq('id', user.id);

    await this.addXP(user.id, XP_REWARDS.login_harian, 'Login harian');
  },

  // ── WEATHER WIDGET ────────────────────────────────────────
  async getWeather() {
    try {
      const res = await fetch('https://api.open-meteo.com/v1/forecast?latitude=-6.2&longitude=106.8&current_weather=true&timezone=Asia/Jakarta');
      const data = await res.json();
      const w = data.current_weather;
      const weatherIcons = { 0: '☀️', 1: '🌤️', 2: '⛅', 3: '☁️', 45: '🌫️', 48: '🌫️', 51: '🌦️', 53: '🌦️', 55: '🌧️', 61: '🌧️', 63: '🌧️', 65: '🌧️', 71: '❄️', 73: '❄️', 75: '❄️', 80: '🌧️', 81: '🌧️', 82: '🌧️', 95: '⛈️' };
      return { temp: Math.round(w.temperature), icon: weatherIcons[w.weathercode] || '🌤️', code: w.weathercode };
    } catch (e) { return { temp: '--', icon: '🌤️', code: 0 }; }
  },

  // ── BAD WORD FILTER ───────────────────────────────────────
  filterBadWords(text) {
    const badWords = ['anjing','babi','bangsat','bajingan','brengsek','goblok','idiot','kampret','kontol','memek','ngentot','setan','tai','tolol'];
    let filtered = text;
    badWords.forEach(w => {
      const regex = new RegExp(w, 'gi');
      filtered = filtered.replace(regex, '*'.repeat(w.length));
    });
    return filtered;
  },

  // ── HARI LIBUR NASIONAL ───────────────────────────────────
  isHoliday(dateStr) {
    const holidays2025 = [
      '2025-01-01','2025-01-27','2025-01-29','2025-02-12','2025-03-28','2025-03-29',
      '2025-03-30','2025-03-31','2025-04-01','2025-04-18','2025-05-01','2025-05-12',
      '2025-05-29','2025-06-01','2025-06-07','2025-06-08','2025-07-27','2025-08-17',
      '2025-09-05','2025-09-06','2025-10-02','2025-12-25',
    ];
    const holidays2026 = [
      '2026-01-01','2026-01-16','2026-02-01','2026-03-18','2026-03-19','2026-03-20',
      '2026-03-21','2026-03-22','2026-04-03','2026-05-01','2026-05-14','2026-05-16',
      '2026-05-18','2026-05-28','2026-06-27','2026-07-17','2026-08-17','2026-08-26',
      '2026-09-25','2026-12-25',
    ];
    return holidays2025.includes(dateStr) || holidays2026.includes(dateStr);
  },

  getHolidayName(dateStr) {
    const names = {
      '2025-01-01': 'Tahun Baru', '2025-08-17': 'HUT RI',
      '2025-12-25': 'Natal', '2026-01-01': 'Tahun Baru',
      '2026-08-17': 'HUT RI', '2026-12-25': 'Natal',
    };
    return names[dateStr] || 'Hari Libur Nasional';
  },

  // ── WELCOME ANIMATION ────────────────────────────────────
  showWelcomeAnimation() {
    if (sessionStorage.getItem('welcomeShown')) return;
    sessionStorage.setItem('welcomeShown', 'true');
    const overlay = document.createElement('div');
    overlay.className = 'welcome-overlay';
    overlay.innerHTML = `
      <div class="welcome-animation">
        <div class="welcome-emoji">🎓</div>
        <h1 class="welcome-title">Selamat Datang!</h1>
        <p class="welcome-sub">Manajemen Kelas</p>
      </div>`;
    document.body.appendChild(overlay);
    setTimeout(() => { overlay.classList.add('fade-out'); setTimeout(() => overlay.remove(), 600); }, 2000);
  },
};

// ── AUTO-INIT ────────────────────────────────────────────────
App.initDarkMode();

document.addEventListener('DOMContentLoaded', async () => {
  const currentPage = window.location.pathname.split('/').pop() || 'index.html';
  if (currentPage === 'login.html' || currentPage === 'akses-ditolak.html') return;

  const user = await App.checkPageAccess();
  if (user) {
    await App.initSidebar(user);
    await App.loadTheme();
  }
});
