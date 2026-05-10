// ============================================================
// app.js - Logika Utama Aplikasi
// ============================================================

import { supabaseClient } from './supabase.js';

// ── KONSTANTA ROLE ────────────────────────────────────────────
const ROLES = {
  ADMIN: 'admin',
  PENGURUS_KAS: 'pengurus_kas',
  PENGURUS_ABSENSI: 'pengurus_absensi',
  PENGUNJUNG: 'pengunjung',
};

// Halaman yang diizinkan per role
const PAGE_ACCESS = {
  admin:             ['index.html', 'kas.html', 'absensi.html', 'laporan.html'],
  pengurus_kas:      ['kas.html', 'laporan.html'],
  pengurus_absensi:  ['absensi.html', 'laporan.html'],
  pengunjung:        ['laporan.html'],
};

// ── HELPERS GLOBAL ────────────────────────────────────────────
window.App = {

  // ── AUTH ────────────────────────────────────────────────────
  async getSession() {
    const { data: { session } } = await supabaseClient.auth.getSession();
    return session;
  },

  async getProfile(userId) {
    const { data, error } = await supabaseClient
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single();
    if (error) return null;
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

  // ── ROUTE GUARD ─────────────────────────────────────────────
  async requireAuth(allowedRoles = null) {
    const user = await this.getCurrentUser();
    if (!user) {
      window.location.href = 'login.html';
      return null;
    }

    const role = user.profile?.role;

    if (allowedRoles && !allowedRoles.includes(role)) {
      window.location.href = 'akses-ditolak.html';
      return null;
    }

    return user;
  },

  async checkPageAccess() {
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const user = await this.getCurrentUser();

    if (!user) {
      if (currentPage !== 'login.html') window.location.href = 'login.html';
      return null;
    }

    const role = user.profile?.role;
    const allowed = PAGE_ACCESS[role] || [];

    if (!allowed.includes(currentPage) && currentPage !== 'akses-ditolak.html') {
      window.location.href = 'akses-ditolak.html';
      return null;
    }

    return user;
  },

  // ── UI HELPERS ───────────────────────────────────────────────
  showToast(message, type = 'success') {
    const existing = document.getElementById('toast-container');
    if (!existing) {
      const container = document.createElement('div');
      container.id = 'toast-container';
      document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
      <span class="toast-icon">${type === 'success' ? '✓' : type === 'error' ? '✕' : 'ℹ'}</span>
      <span>${message}</span>
    `;

    document.getElementById('toast-container').appendChild(toast);

    requestAnimationFrame(() => toast.classList.add('show'));

    setTimeout(() => {
      toast.classList.remove('show');
      setTimeout(() => toast.remove(), 300);
    }, 3500);
  },

  showLoading(containerId) {
    const el = document.getElementById(containerId);
    if (el) el.innerHTML = `
      <div class="loading-state">
        <div class="spinner"></div>
        <p>Memuat data...</p>
      </div>`;
  },

  showEmpty(containerId, message = 'Tidak ada data ditemukan') {
    const el = document.getElementById(containerId);
    if (el) el.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">📭</div>
        <p>${message}</p>
      </div>`;
  },

  async confirmDelete(message = 'Yakin ingin menghapus data ini?') {
    return new Promise((resolve) => {
      const overlay = document.createElement('div');
      overlay.className = 'confirm-overlay';
      overlay.innerHTML = `
        <div class="confirm-dialog">
          <div class="confirm-icon">⚠️</div>
          <h3>Konfirmasi Hapus</h3>
          <p>${message}</p>
          <div class="confirm-actions">
            <button class="btn btn-secondary" id="confirm-cancel">Batal</button>
            <button class="btn btn-danger" id="confirm-ok">Ya, Hapus</button>
          </div>
        </div>`;
      document.body.appendChild(overlay);
      requestAnimationFrame(() => overlay.classList.add('show'));

      document.getElementById('confirm-ok').onclick = () => {
        overlay.remove(); resolve(true);
      };
      document.getElementById('confirm-cancel').onclick = () => {
        overlay.remove(); resolve(false);
      };
    });
  },

  formatCurrency(amount) {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency', currency: 'IDR', minimumFractionDigits: 0
    }).format(amount);
  },

  formatDate(dateStr) {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('id-ID', {
      day: '2-digit', month: 'long', year: 'numeric'
    });
  },

  formatDateInput(dateStr) {
    if (!dateStr) return '';
    return new Date(dateStr).toISOString().split('T')[0];
  },

  getRoleBadge(role) {
    const map = {
      admin:             { label: 'Admin',             class: 'badge-admin' },
      pengurus_kas:      { label: 'Pengurus Kas',      class: 'badge-kas' },
      pengurus_absensi:  { label: 'Pengurus Absensi',  class: 'badge-absensi' },
      pengunjung:        { label: 'Pengunjung',         class: 'badge-pengunjung' },
    };
    const r = map[role] || { label: role, class: '' };
    return `<span class="badge ${r.class}">${r.label}</span>`;
  },

  getStatusBadge(status) {
    const map = {
      Hadir:  'badge-hadir',
      Izin:   'badge-izin',
      Sakit:  'badge-sakit',
      Alpha:  'badge-alpha',
    };
    return `<span class="badge ${map[status] || ''}">${status}</span>`;
  },

  // ── SIDEBAR ──────────────────────────────────────────────────
  async initSidebar(user) {
    const role = user?.profile?.role;
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';

    // Tampilkan nama & role
    const nameEl = document.getElementById('sidebar-name');
    const roleEl = document.getElementById('sidebar-role');
    const avatarEl = document.getElementById('sidebar-avatar');
    if (nameEl) nameEl.textContent = user?.profile?.full_name || user?.email || 'Pengguna';
    if (roleEl) roleEl.innerHTML = this.getRoleBadge(role);
    if (avatarEl) avatarEl.textContent = (user?.profile?.full_name || user?.email || 'U')[0].toUpperCase();

    // Tampilkan/sembunyikan menu berdasarkan role
    const menuItems = document.querySelectorAll('[data-role-access]');
    menuItems.forEach(item => {
      const allowed = item.dataset.roleAccess?.split(',') || [];
      item.style.display = allowed.includes(role) ? 'flex' : 'none';
    });

    // Tandai halaman aktif
    document.querySelectorAll('.nav-link').forEach(link => {
      link.classList.toggle('active', link.dataset.page === currentPage);
    });

    // Mobile sidebar toggle
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

    // Logout
    document.getElementById('logout-btn')?.addEventListener('click', () => this.logout());
  },
};

// ── AUTO-INIT SAAT DOM SIAP ──────────────────────────────────
document.addEventListener('DOMContentLoaded', async () => {
  const currentPage = window.location.pathname.split('/').pop() || 'index.html';
  if (currentPage === 'login.html' || currentPage === 'akses-ditolak.html') return;

  const user = await App.checkPageAccess();
  if (user) await App.initSidebar(user);
});
