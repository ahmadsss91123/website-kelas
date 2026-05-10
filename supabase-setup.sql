-- ============================================================
-- SUPABASE SQL SETUP – Manajemen Kelas
-- Jalankan seluruh skrip ini di Supabase SQL Editor
-- Project → SQL Editor → New Query → Paste → Run
-- ============================================================

-- ── 1. ENABLE UUID EXTENSION ─────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 2. TABEL PROFILES ────────────────────────────────────────
-- Menyimpan informasi profil user (role, nama, dll.)
CREATE TABLE IF NOT EXISTS public.profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT,
  full_name  TEXT,
  role       TEXT NOT NULL DEFAULT 'pengunjung'
               CHECK (role IN ('admin','pengurus_kas','pengurus_absensi','pengunjung')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 3. TABEL STUDENTS ────────────────────────────────────────
-- Daftar siswa di kelas
CREATE TABLE IF NOT EXISTS public.students (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nama       TEXT NOT NULL,
  nis        TEXT UNIQUE,
  kelas      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 4. TABEL CASH_PAYMENTS ───────────────────────────────────
-- Riwayat pembayaran kas
CREATE TABLE IF NOT EXISTS public.cash_payments (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id   UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  tanggal_bayar DATE NOT NULL,
  nominal      NUMERIC(12,0) NOT NULL CHECK (nominal > 0),
  keterangan   TEXT,
  created_by   UUID REFERENCES auth.users(id),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── 5. TABEL ATTENDANCES ─────────────────────────────────────
-- Catatan absensi harian
CREATE TABLE IF NOT EXISTS public.attendances (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id  UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  tanggal     DATE NOT NULL,
  status      TEXT NOT NULL CHECK (status IN ('Hadir','Izin','Sakit','Alpha')),
  keterangan  TEXT,
  created_by  UUID REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  -- Mencegah absensi ganda (1 siswa, 1 tanggal)
  UNIQUE (student_id, tanggal)
);

-- ── 6. INDEXES ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_cash_student    ON public.cash_payments(student_id);
CREATE INDEX IF NOT EXISTS idx_cash_tanggal    ON public.cash_payments(tanggal_bayar);
CREATE INDEX IF NOT EXISTS idx_att_student     ON public.attendances(student_id);
CREATE INDEX IF NOT EXISTS idx_att_tanggal     ON public.attendances(tanggal);
CREATE INDEX IF NOT EXISTS idx_att_status      ON public.attendances(status);
CREATE INDEX IF NOT EXISTS idx_profiles_role   ON public.profiles(role);

-- ── 7. TRIGGER AUTO-UPDATE updated_at ────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_cash_updated
  BEFORE UPDATE ON public.cash_payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_att_updated
  BEFORE UPDATE ON public.attendances
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── 8. TRIGGER AUTO-CREATE PROFILE SAAT SIGNUP ───────────────
-- Otomatis membuat row di profiles ketika user mendaftar
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'pengunjung')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ── 9. ENABLE ROW LEVEL SECURITY (RLS) ───────────────────────
ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendances  ENABLE ROW LEVEL SECURITY;

-- ── 10. HELPER FUNCTION: ambil role user saat ini ─────────────
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── 11. POLICIES: PROFILES ────────────────────────────────────
-- Semua user yang login bisa baca profil sendiri
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

-- Admin bisa baca semua profil
CREATE POLICY "profiles_select_admin"
  ON public.profiles FOR SELECT
  USING (get_my_role() = 'admin');

-- Admin bisa update semua profil
CREATE POLICY "profiles_update_admin"
  ON public.profiles FOR UPDATE
  USING (get_my_role() = 'admin');

-- Admin bisa insert profil baru
CREATE POLICY "profiles_insert_admin"
  ON public.profiles FOR INSERT
  WITH CHECK (get_my_role() = 'admin');

-- Admin bisa hapus profil
CREATE POLICY "profiles_delete_admin"
  ON public.profiles FOR DELETE
  USING (get_my_role() = 'admin');

-- User update profil sendiri (nama saja, bukan role)
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid());

-- ── 12. POLICIES: STUDENTS ───────────────────────────────────
-- Semua user yang login bisa baca data siswa
CREATE POLICY "students_select_all"
  ON public.students FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Admin bisa CRUD siswa
CREATE POLICY "students_insert_admin"
  ON public.students FOR INSERT
  WITH CHECK (get_my_role() = 'admin');

CREATE POLICY "students_update_admin"
  ON public.students FOR UPDATE
  USING (get_my_role() = 'admin');

CREATE POLICY "students_delete_admin"
  ON public.students FOR DELETE
  USING (get_my_role() = 'admin');

-- ── 13. POLICIES: CASH_PAYMENTS ──────────────────────────────
-- Admin & Pengurus Kas & Pengunjung bisa baca
CREATE POLICY "cash_select"
  ON public.cash_payments FOR SELECT
  USING (get_my_role() IN ('admin','pengurus_kas','pengunjung'));

-- Admin & Pengurus Kas bisa tambah
CREATE POLICY "cash_insert"
  ON public.cash_payments FOR INSERT
  WITH CHECK (get_my_role() IN ('admin','pengurus_kas'));

-- Admin & Pengurus Kas bisa edit
CREATE POLICY "cash_update"
  ON public.cash_payments FOR UPDATE
  USING (get_my_role() IN ('admin','pengurus_kas'));

-- Admin & Pengurus Kas bisa hapus
CREATE POLICY "cash_delete"
  ON public.cash_payments FOR DELETE
  USING (get_my_role() IN ('admin','pengurus_kas'));

-- ── 14. POLICIES: ATTENDANCES ────────────────────────────────
-- Admin & Pengurus Absensi & Pengunjung bisa baca
CREATE POLICY "att_select"
  ON public.attendances FOR SELECT
  USING (get_my_role() IN ('admin','pengurus_absensi','pengunjung'));

-- Admin & Pengurus Absensi bisa tambah
CREATE POLICY "att_insert"
  ON public.attendances FOR INSERT
  WITH CHECK (get_my_role() IN ('admin','pengurus_absensi'));

-- Admin & Pengurus Absensi bisa edit
CREATE POLICY "att_update"
  ON public.attendances FOR UPDATE
  USING (get_my_role() IN ('admin','pengurus_absensi'));

-- Admin & Pengurus Absensi bisa hapus
CREATE POLICY "att_delete"
  ON public.attendances FOR DELETE
  USING (get_my_role() IN ('admin','pengurus_absensi'));

-- ── 15. SAMPLE DATA SISWA ─────────────────────────────────────
-- (Opsional) Jalankan setelah tabel students dibuat
INSERT INTO public.students (nama, nis, kelas) VALUES
  ('Ahmad Fauzi',         '2024001', 'XII IPA 1'),
  ('Budi Santoso',        '2024002', 'XII IPA 1'),
  ('Citra Dewi',          '2024003', 'XII IPA 1'),
  ('Dian Pratama',        '2024004', 'XII IPA 1'),
  ('Eka Rahayu',          '2024005', 'XII IPA 1'),
  ('Fajar Nugroho',       '2024006', 'XII IPA 1'),
  ('Gita Permatasari',    '2024007', 'XII IPA 1'),
  ('Hendra Wijaya',       '2024008', 'XII IPA 1'),
  ('Indah Lestari',       '2024009', 'XII IPA 1'),
  ('Joko Susilo',         '2024010', 'XII IPA 1')
ON CONFLICT DO NOTHING;

-- ============================================================
-- SELESAI! Lanjut ke langkah membuat akun admin di README
-- ============================================================
