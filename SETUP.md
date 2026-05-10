# Setup Guide – Website Manajemen Kelas

## Struktur Folder

```
website-kelas/
├── index.html            # Dashboard Admin
├── login.html            # Halaman Login
├── kas.html              # Kas Kelas
├── absensi.html          # Absensi
├── laporan.html          # Laporan
├── jadwal.html           # Jadwal Pelajaran Interaktif
├── tugas.html            # Deadline & Tugas
├── materi.html           # Bank Materi
├── confession.html       # Confession / Pesan Anonim
├── memories.html         # Wall of Memories
├── quotes.html           # Quote Harian
├── polling.html          # Polling / Voting
├── pengumuman.html       # Pengumuman Realtime
├── leaderboard.html      # Leaderboard Keaktifan
├── profil.html           # Profil & Statistik Personal
├── app.js                # Logika aplikasi utama
├── supabase.js           # Konfigurasi Supabase
├── style.css             # Stylesheet (dark/light mode)
├── supabase-setup.sql    # SQL setup awal (profiles, students, kas, absensi)
├── supabase-setup-v2.sql # SQL setup fitur tambahan (semua tabel baru)
├── SETUP.md              # Dokumentasi setup (file ini)
└── README.md             # Deskripsi proyek
```

## 1. Setup Supabase

### 1.1. Buat Project Supabase
1. Buka https://supabase.com
2. Buat project baru (atau gunakan project yang sudah ada)
3. Catat **Project URL** dan **Anon Key** dari `Settings > API`

### 1.2. Jalankan SQL Schema
1. Buka **SQL Editor** di Supabase Dashboard
2. Jalankan file `supabase-setup.sql` terlebih dahulu (schema dasar)
3. Jalankan file `supabase-setup-v2.sql` (fitur-fitur baru)

> **PENTING**: Jalankan `supabase-setup.sql` dulu, baru `supabase-setup-v2.sql`

### 1.3. Setup Supabase Storage
1. Buka **Storage** di Supabase Dashboard
2. Buat 3 bucket (atau jalankan SQL yang sudah membuat otomatis):
   - `materials` – untuk file materi (PDF, dokumen)
   - `memories` – untuk foto kenangan
   - `assignments` – untuk lampiran tugas
3. Semua bucket di-set **Public** agar file bisa diakses
4. Pastikan RLS policy sudah benar (sudah diatur via SQL)

### 1.4. Setup Authentication
1. Buka **Authentication > Settings** di Supabase
2. Pastikan **Email** provider sudah enabled
3. Di **Authentication > URL Configuration**:
   - Tambahkan URL GitHub Pages ke **Redirect URLs**: `https://USERNAME.github.io/website-kelas/**`

## 2. Konfigurasi Website

### 2.1. Update Credentials Supabase
Edit file `supabase.js`:
```javascript
const SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
```

## 3. Deploy ke GitHub Pages

### 3.1. Push ke GitHub
```bash
git add .
git commit -m "Initial commit"
git push origin main
```

### 3.2. Aktifkan GitHub Pages
1. Buka **Settings > Pages** di repositori GitHub
2. Source: **Deploy from a branch**
3. Branch: **main** / **(root)**
4. Klik **Save**
5. Website akan tersedia di: `https://USERNAME.github.io/website-kelas/`

## 4. Membuat Admin Pertama

### Opsi A: Via Supabase Dashboard
1. Buka **Authentication > Users** di Supabase
2. Klik **Add User > Create New User**
3. Masukkan email dan password
4. Setelah user dibuat, buka **Table Editor > profiles**
5. Edit row user tersebut, set `role` menjadi `admin`

### Opsi B: Via SQL
```sql
-- Setelah user mendaftar, update role-nya:
UPDATE profiles SET role = 'admin' WHERE email = 'admin@email.com';
```

### Opsi C: Via Dashboard Website
1. Login dengan akun pertama (otomatis terdaftar sebagai `pengunjung`)
2. Ubah role via SQL ke `admin`
3. Setelah jadi admin, bisa membuat akun baru dari Dashboard

## 5. Cara Update Website

### 5.1. Update Konten
1. Edit file HTML/CSS/JS yang diperlukan
2. Push ke GitHub:
```bash
git add .
git commit -m "Update: deskripsi perubahan"
git push origin main
```
3. GitHub Pages akan otomatis deploy dalam 1-2 menit

### 5.2. Update Database Schema
1. Buat SQL migration baru
2. Jalankan di Supabase SQL Editor
3. Pastikan tidak menghapus data yang sudah ada

## 6. Fitur-Fitur

### Fitur Akademik
- **Jadwal Pelajaran**: Kalender & list harian, indikator pelajaran berlangsung, countdown jam
- **Deadline & Tugas**: Card tugas dengan countdown, filter mapel, upload lampiran
- **Bank Materi**: Upload/download materi, filter & pencarian, Supabase Storage

### Fitur Sosial
- **Confession**: Pesan anonim, moderasi admin, like reaction
- **Wall of Memories**: Galeri foto, upload multiple, like & komentar
- **Quote Harian**: Auto random, kategori motivasi/lucu/inside joke
- **Polling**: Voting realtime, satu akun satu vote, progress bar
- **Pengumuman**: Post & pin pengumuman, edit/hapus

### Fitur Gamifikasi
- **Leaderboard**: Peringkat XP, streak, kehadiran
- **XP System**: Hadir +5, Bayar Kas +10, Upload Materi +15, Voting +3, dll
- **Achievement/Badge**: 10+ badge otomatis
- **Streak System**: Login, hadir, bayar kas
- **Statistik Personal**: XP, level, badge, streak, riwayat

### Fitur Premium
- **Dark Mode**: Toggle di sidebar
- **Tema Kelas**: Admin ubah warna aksen
- **Event Countdown**: Countdown ujian, class meeting, kelulusan
- **Widget Cuaca**: Cuaca realtime Jakarta
- **Mini Shoutbox**: Chat ringan
- **Welcome Animation**: Animasi sambutan
- **Musik Background**: Opsional, bisa dimatikan

### Role System
| Role | Akses |
|------|-------|
| `admin` | Semua halaman + kelola akun/data |
| `pengurus_kas` | Kas + semua fitur siswa |
| `pengurus_absensi` | Absensi + semua fitur siswa |
| `pengunjung` | Fitur siswa (tanpa kas/absensi/dashboard) |

### XP Rewards
| Aktivitas | XP |
|-----------|-----|
| Hadir | +5 |
| Bayar Kas Tepat Waktu | +10 |
| Upload Materi | +15 |
| Ikut Voting | +3 |
| Kontribusi Sosial | +5 |
| Login Harian | +2 |
| Upload Memory | +5 |
| Kirim Shoutbox | +1 |

### Level System
| Level | XP Minimum |
|-------|-----------|
| 1 | 0 |
| 2 | 50 |
| 3 | 120 |
| 4 | 220 |
| 5 | 350 |
| 6 | 520 |
| 7 | 730 |
| 8 | 1,000 |
| 9 | 1,350 |
| 10 | 1,800 |
| 11 | 2,500 |
