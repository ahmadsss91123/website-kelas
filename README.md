# 🎓 Manajemen Kelas – Dokumentasi Lengkap

Website manajemen kelas berbasis HTML + Supabase, siap deploy ke GitHub Pages tanpa backend server.

---

## 📁 Struktur Folder

```
manajemen-kelas/
├── index.html          # Dashboard (admin only)
├── kas.html            # Manajemen kas kelas
├── absensi.html        # Manajemen absensi
├── laporan.html        # Laporan (semua role)
├── login.html          # Halaman login
├── akses-ditolak.html  # Halaman akses ditolak
├── style.css           # Semua styling
├── app.js              # Logika utama & helpers
├── supabase.js         # Konfigurasi Supabase client
├── supabase-setup.sql  # SQL untuk setup database
└── README.md           # Dokumentasi ini
```

---

## ⚡ Cara Setup (Langkah Demi Langkah)

### Langkah 1 – Buat Project Supabase

1. Buka [https://supabase.com](https://supabase.com) dan klik **Start your project**
2. Login dengan GitHub atau email
3. Klik **New project**
4. Isi:
   - **Name**: `manajemen-kelas` (atau nama lain)
   - **Database Password**: buat password kuat, **simpan baik-baik**
   - **Region**: pilih `Southeast Asia (Singapore)`
5. Tunggu project selesai dibuat (~2 menit)

---

### Langkah 2 – Setup Database

1. Di dashboard Supabase, klik **SQL Editor** di sidebar kiri
2. Klik **New query**
3. Buka file `supabase-setup.sql` dari project ini
4. Copy semua isinya, paste ke SQL Editor
5. Klik **Run** (Ctrl+Enter)
6. Pastikan tidak ada error merah

---

### Langkah 3 – Ambil Credentials Supabase

1. Di dashboard Supabase, klik **Settings** (ikon gear) → **API**
2. Catat:
   - **Project URL**: `https://xxxxxxxx.supabase.co`
   - **anon/public key**: `eyJhbGciOiJ...` (kunci panjang)

---

### Langkah 4 – Konfigurasi supabase.js

Buka file `supabase.js` dan ganti dua baris ini:

```javascript
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
// Ganti dengan URL project Anda, contoh:
const SUPABASE_URL = 'https://abcdefghijkl.supabase.co';

const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
// Ganti dengan anon key Anda, contoh:
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

> ⚠️ **Penting**: `anon key` aman untuk digunakan di frontend karena sudah dilindungi oleh Row Level Security (RLS). **Jangan pernah gunakan `service_role key` di frontend!**

---

### Langkah 5 – Upload ke GitHub

1. Buat akun di [https://github.com](https://github.com) jika belum punya
2. Klik **+** → **New repository**
3. Isi:
   - **Repository name**: `manajemen-kelas`
   - Centang **Public**
   - Klik **Create repository**
4. Upload semua file project:

**Cara A – Drag & Drop (mudah):**
- Di halaman repository, klik **uploading an existing file**
- Drag semua file project ke area upload
- Klik **Commit changes**

**Cara B – Git CLI:**
```bash
git init
git add .
git commit -m "Initial commit: Manajemen Kelas"
git branch -M main
git remote add origin https://github.com/USERNAME/manajemen-kelas.git
git push -u origin main
```

---

### Langkah 6 – Aktifkan GitHub Pages

1. Di repository GitHub, klik **Settings**
2. Scroll ke bagian **Pages** (sidebar kiri)
3. Di **Source**, pilih:
   - Branch: **main**
   - Folder: **/ (root)**
4. Klik **Save**
5. Tunggu ~1 menit, akan muncul URL seperti:
   `https://username.github.io/manajemen-kelas/`
6. Buka URL tersebut – website sudah online!

> 🌐 **Catatan**: Setiap kali Anda push ke branch `main`, GitHub Pages otomatis memperbarui website dalam ~1 menit.

---

## 👤 Cara Membuat Akun Admin Pertama

Karena fitur signup publik membuat akun dengan role `pengunjung` secara default, akun admin harus dibuat manual:

### Metode A – Via Supabase Dashboard (Direkomendasikan)

1. Di Supabase, klik **Authentication** → **Users**
2. Klik **Invite user** atau **Add user**
3. Masukkan email dan password admin
4. Klik **Create user**
5. Catat UUID user yang baru dibuat
6. Klik **SQL Editor** → buat query baru:

```sql
-- Ganti 'email-admin@contoh.com' dan UUID sesuai akun yang baru dibuat
UPDATE public.profiles
SET role = 'admin', full_name = 'Administrator'
WHERE email = 'email-admin@contoh.com';

-- Atau gunakan UUID langsung:
UPDATE public.profiles
SET role = 'admin', full_name = 'Administrator'
WHERE id = 'UUID-DARI-USER-ANDA';
```

7. Run query → akun sudah jadi admin

### Metode B – Daftar lalu Upgrade

1. Buka website dan daftar akun baru (via fitur signup jika diaktifkan)
2. Login ke Supabase → SQL Editor
3. Jalankan:

```sql
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'email-anda@contoh.com';
```

---

## 👥 Cara Membuat Akun Pengunjung / Role Lain

### Via SQL (paling cepat)

Setelah user signup sendiri, ubah role-nya:

```sql
-- Jadikan pengurus kas
UPDATE public.profiles SET role = 'pengurus_kas'
WHERE email = 'kas@contoh.com';

-- Jadikan pengurus absensi
UPDATE public.profiles SET role = 'pengurus_absensi'
WHERE email = 'absensi@contoh.com';

-- Jadikan pengunjung (sudah default)
UPDATE public.profiles SET role = 'pengunjung'
WHERE email = 'guest@contoh.com';
```

### Via Dashboard Admin

Admin yang sudah login dapat mengelola akun langsung dari halaman Dashboard (`index.html`):
- Klik **Kelola Akun**
- Gunakan tombol **Edit** untuk mengubah role user

---

## 🔐 Alur Authentication & Role System

```
User buka halaman
       ↓
app.js: checkPageAccess()
       ↓
supabaseClient.auth.getSession()
       ↓
 Tidak ada sesi? ──────────────→ Redirect ke login.html
       ↓
Ada sesi → ambil profiles dari DB
       ↓
Cek role vs PAGE_ACCESS map:
  admin             → ['index','kas','absensi','laporan']
  pengurus_kas      → ['kas','laporan']
  pengurus_absensi  → ['absensi','laporan']
  pengunjung        → ['laporan']
       ↓
Role tidak sesuai halaman? ────→ Redirect ke akses-ditolak.html
       ↓
Akses diberikan → render halaman
       ↓
Sidebar: sembunyikan menu yang tidak sesuai role
       ↓
Di tiap query: role dicek ulang sebelum INSERT/UPDATE/DELETE
```

**Session Storage**: Supabase menyimpan session di `localStorage` browser secara otomatis. Session tetap aktif bahkan setelah tab ditutup, hingga expired (default 1 minggu) atau logout manual.

---

## 🛡️ Cara Kerja Row Level Security (RLS) Supabase

RLS adalah lapisan keamanan di level database PostgreSQL. Meski seseorang mencuri `anon key`, mereka **tidak bisa** mengakses data yang tidak diizinkan.

### Alur RLS:

```
Request dari browser
       ↓
Supabase menerima request + JWT token user
       ↓
PostgreSQL memanggil auth.uid() → dapat UUID user
       ↓
Fungsi get_my_role() → SELECT role FROM profiles WHERE id = auth.uid()
       ↓
Policy dievaluasi untuk setiap baris:
  - SELECT: apakah role user termasuk yang diizinkan membaca?
  - INSERT: apakah role user termasuk yang diizinkan menambah?
  - UPDATE: apakah role user termasuk yang diizinkan mengubah?
  - DELETE: apakah role user termasuk yang diizinkan menghapus?
       ↓
Hanya data yang lolos policy yang dikembalikan/dimodifikasi
```

### Contoh Policy:

```sql
-- Pengunjung hanya bisa SELECT dari cash_payments, tidak bisa INSERT/UPDATE/DELETE
CREATE POLICY "cash_select"
  ON public.cash_payments FOR SELECT
  USING (get_my_role() IN ('admin','pengurus_kas','pengunjung'));

-- Hanya admin & pengurus_kas yang bisa INSERT
CREATE POLICY "cash_insert"
  ON public.cash_payments FOR INSERT
  WITH CHECK (get_my_role() IN ('admin','pengurus_kas'));
```

**Ini berarti**: bahkan jika seseorang menggunakan `curl` dengan anon key dan mencoba `INSERT` sebagai pengunjung, Supabase akan menolak dengan error `new row violates row-level security policy`.

---

## 🔄 Cara Update Website Setelah Online

### Cara 1 – Drag & Drop di GitHub

1. Buka repository di GitHub
2. Klik file yang ingin diubah
3. Klik ikon pensil (Edit)
4. Lakukan perubahan
5. Klik **Commit changes**
6. Website otomatis diperbarui dalam ~1 menit

### Cara 2 – Git CLI

```bash
# Edit file lokal, lalu:
git add .
git commit -m "Update: deskripsi perubahan"
git push origin main
```

### Cara 3 – GitHub Desktop (GUI)

1. Download [GitHub Desktop](https://desktop.github.com/)
2. Clone repository
3. Edit file secara lokal
4. Commit dan Push dari aplikasi

---

## 🚨 Troubleshooting

| Masalah | Solusi |
|---|---|
| "Failed to fetch" saat login | Cek SUPABASE_URL dan SUPABASE_ANON_KEY di supabase.js |
| Login berhasil tapi redirect ke akses-ditolak | Cek apakah row di tabel `profiles` sudah ada dan role-nya benar |
| Data tidak muncul | Cek RLS policies di Supabase → Authentication → Policies |
| GitHub Pages tidak update | Tunggu 2-3 menit, atau cek tab Actions di repository |
| CORS error | Tambahkan URL GitHub Pages ke Supabase: Settings → API → CORS origins |
| `supabase is not defined` | Pastikan CDN script dimuat sebelum `supabase.js` |

---

## ➕ Cara Menambahkan Siswa Baru

Saat ini siswa dikelola via SQL. Untuk menambah siswa:

```sql
INSERT INTO public.students (nama, nis, kelas)
VALUES ('Nama Siswa Baru', '2024011', 'XII IPA 1');
```

Atau tambahkan fitur manajemen siswa di halaman admin (extension opsional).

---

## 📧 Konfigurasi Email di Supabase

Untuk disable konfirmasi email saat signup (lebih mudah untuk testing):

1. Supabase → **Authentication** → **Providers** → **Email**
2. Matikan **Confirm email**
3. Save

Untuk production, sebaiknya konfirmasi email tetap aktif.

---

*Website ini menggunakan: HTML5 · CSS3 · Vanilla JavaScript · Supabase (Auth + PostgreSQL) · GitHub Pages*
