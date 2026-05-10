-- ============================================================
-- SUPABASE SQL SETUP TAMBAHAN – Fitur Profil Siswa, XP & Chat
-- Jalankan di Supabase SQL Editor SETELAH supabase-setup.sql
-- ============================================================

-- ── 1. KOLOM TAMBAHAN DI TABEL STUDENTS ──────────────────────
-- Tambah kolom untuk foto, bio, dan akun (link ke auth.users)
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS bio         TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url  TEXT,
  ADD COLUMN IF NOT EXISTS user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS nomor_hp    TEXT;

-- Index untuk cari berdasarkan user_id
CREATE INDEX IF NOT EXISTS idx_students_user_id ON public.students(user_id);

-- ── 2. TABEL STUDENT_XP ───────────────────────────────────────
-- Menyimpan total XP dan level per siswa (dihitung ulang tiap perubahan)
CREATE TABLE IF NOT EXISTS public.student_xp (
  student_id  UUID PRIMARY KEY REFERENCES public.students(id) ON DELETE CASCADE,
  total_xp    INTEGER NOT NULL DEFAULT 0,
  level       INTEGER NOT NULL DEFAULT 1,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── 3. TABEL STUDENT_ACHIEVEMENTS ────────────────────────────
-- Badge/achievement yang diraih siswa
CREATE TABLE IF NOT EXISTS public.student_achievements (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id  UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  badge_key   TEXT NOT NULL,   -- e.g. 'perfect_attendance', 'no_alpha', dll.
  earned_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (student_id, badge_key)
);

CREATE INDEX IF NOT EXISTS idx_achievements_student ON public.student_achievements(student_id);

-- ── 4. TABEL ANONYMOUS_MESSAGES ──────────────────────────────
-- Pesan anonim di halaman profil siswa
CREATE TABLE IF NOT EXISTS public.anonymous_messages (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id    UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  message       TEXT NOT NULL CHECK (char_length(message) BETWEEN 1 AND 500),
  sender_token  TEXT,          -- random token untuk rate-limit (disimpan di localStorage)
  is_hidden     BOOLEAN DEFAULT FALSE,  -- admin bisa sembunyikan pesan
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_anon_msg_student  ON public.anonymous_messages(student_id);
CREATE INDEX IF NOT EXISTS idx_anon_msg_created  ON public.anonymous_messages(created_at DESC);

-- ── 5. RLS: STUDENT_XP ───────────────────────────────────────
ALTER TABLE public.student_xp ENABLE ROW LEVEL SECURITY;

-- Semua user login bisa baca
CREATE POLICY "xp_select_all"
  ON public.student_xp FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Hanya system/admin yang bisa insert/update (via service role atau trigger)
-- Frontend tidak perlu insert langsung; ada fungsi recalc_xp di bawah

-- ── 6. RLS: STUDENT_ACHIEVEMENTS ─────────────────────────────
ALTER TABLE public.student_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ach_select_all"
  ON public.student_achievements FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ── 7. RLS: ANONYMOUS_MESSAGES ───────────────────────────────
ALTER TABLE public.anonymous_messages ENABLE ROW LEVEL SECURITY;

-- Siapa saja (termasuk yang tidak login) bisa baca pesan yang tidak disembunyikan
CREATE POLICY "anon_msg_select"
  ON public.anonymous_messages FOR SELECT
  USING (is_hidden = FALSE);

-- Siapa saja (termasuk yang tidak login) bisa kirim pesan
-- Rate-limit ditangani di level aplikasi via sender_token
CREATE POLICY "anon_msg_insert"
  ON public.anonymous_messages FOR INSERT
  WITH CHECK (char_length(message) BETWEEN 1 AND 500);

-- Admin bisa sembunyikan pesan (update is_hidden)
CREATE POLICY "anon_msg_hide_admin"
  ON public.anonymous_messages FOR UPDATE
  USING (get_my_role() = 'admin');

-- Admin bisa hapus pesan
CREATE POLICY "anon_msg_delete_admin"
  ON public.anonymous_messages FOR DELETE
  USING (get_my_role() = 'admin');

-- ── 8. FUNGSI HITUNG XP & LEVEL ──────────────────────────────
-- Dipanggil setelah data absensi / kas berubah untuk recalculate

CREATE OR REPLACE FUNCTION recalc_student_xp(p_student_id UUID)
RETURNS VOID AS $$
DECLARE
  v_hadir   INTEGER;
  v_izin    INTEGER;
  v_sakit   INTEGER;
  v_kas     INTEGER;
  v_xp      INTEGER;
  v_level   INTEGER;
BEGIN
  -- Hitung kehadiran
  SELECT
    COUNT(*) FILTER (WHERE status = 'Hadir'),
    COUNT(*) FILTER (WHERE status = 'Izin'),
    COUNT(*) FILTER (WHERE status = 'Sakit')
  INTO v_hadir, v_izin, v_sakit
  FROM public.attendances
  WHERE student_id = p_student_id;

  -- Hitung pembayaran kas
  SELECT COUNT(*)
  INTO v_kas
  FROM public.cash_payments
  WHERE student_id = p_student_id;

  -- Rumus XP:
  -- Hadir  = +5 XP
  -- Izin   = +2 XP (tetap masuk kategori)
  -- Sakit  = +2 XP
  -- Bayar kas = +10 XP per pembayaran
  v_xp := (v_hadir * 5) + (v_izin * 2) + (v_sakit * 2) + (v_kas * 10);

  -- Level: setiap 50 XP naik 1 level, mulai dari level 1
  v_level := GREATEST(1, FLOOR(v_xp / 50) + 1);

  -- Upsert ke student_xp
  INSERT INTO public.student_xp (student_id, total_xp, level, updated_at)
  VALUES (p_student_id, v_xp, v_level, NOW())
  ON CONFLICT (student_id)
  DO UPDATE SET total_xp = v_xp, level = v_level, updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 9. FUNGSI CEK & BERI ACHIEVEMENT ─────────────────────────
CREATE OR REPLACE FUNCTION recalc_student_achievements(p_student_id UUID)
RETURNS VOID AS $$
DECLARE
  v_total     INTEGER;
  v_hadir     INTEGER;
  v_alpha     INTEGER;
  v_izin      INTEGER;
  v_kas_count INTEGER;
  v_kas_total NUMERIC;
BEGIN
  SELECT COUNT(*) INTO v_total   FROM public.attendances WHERE student_id = p_student_id;
  SELECT COUNT(*) INTO v_hadir   FROM public.attendances WHERE student_id = p_student_id AND status = 'Hadir';
  SELECT COUNT(*) INTO v_alpha   FROM public.attendances WHERE student_id = p_student_id AND status = 'Alpha';
  SELECT COUNT(*) INTO v_izin    FROM public.attendances WHERE student_id = p_student_id AND status = 'Izin';
  SELECT COUNT(*), COALESCE(SUM(nominal),0)
    INTO v_kas_count, v_kas_total
    FROM public.cash_payments WHERE student_id = p_student_id;

  -- 🏆 Perfect Attendance: minimal 20 hadir, tidak ada alpha
  IF v_hadir >= 20 AND v_alpha = 0 THEN
    INSERT INTO public.student_achievements (student_id, badge_key)
    VALUES (p_student_id, 'perfect_attendance') ON CONFLICT DO NOTHING;
  END IF;

  -- ⭐ Paling Rajin: 30+ hadir
  IF v_hadir >= 30 THEN
    INSERT INTO public.student_achievements (student_id, badge_key)
    VALUES (p_student_id, 'super_rajin') ON CONFLICT DO NOTHING;
  END IF;

  -- 🚫 Tidak Pernah Alpha: total absensi > 10 dan alpha = 0
  IF v_total >= 10 AND v_alpha = 0 THEN
    INSERT INTO public.student_achievements (student_id, badge_key)
    VALUES (p_student_id, 'no_alpha') ON CONFLICT DO NOTHING;
  END IF;

  -- 👑 Raja Izin: 10+ izin
  IF v_izin >= 10 THEN
    INSERT INTO public.student_achievements (student_id, badge_key)
    VALUES (p_student_id, 'raja_izin') ON CONFLICT DO NOTHING;
  END IF;

  -- 💰 Pembayar Setia: 5+ kali bayar kas
  IF v_kas_count >= 5 THEN
    INSERT INTO public.student_achievements (student_id, badge_key)
    VALUES (p_student_id, 'pembayar_setia') ON CONFLICT DO NOTHING;
  END IF;

  -- 💎 Sultan Kas: total bayar >= 500000
  IF v_kas_total >= 500000 THEN
    INSERT INTO public.student_achievements (student_id, badge_key)
    VALUES (p_student_id, 'sultan_kas') ON CONFLICT DO NOTHING;
  END IF;

  -- 🌟 Bintang Kelas: hadir >= 25 DAN kas >= 3
  IF v_hadir >= 25 AND v_kas_count >= 3 THEN
    INSERT INTO public.student_achievements (student_id, badge_key)
    VALUES (p_student_id, 'bintang_kelas') ON CONFLICT DO NOTHING;
  END IF;

  -- 🎯 Konsisten: total absensi >= 15 dengan alpha <= 2
  IF v_total >= 15 AND v_alpha <= 2 THEN
    INSERT INTO public.student_achievements (student_id, badge_key)
    VALUES (p_student_id, 'konsisten') ON CONFLICT DO NOTHING;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 10. TRIGGER OTOMATIS RECALC XP ───────────────────────────
-- Setiap kali absensi berubah
CREATE OR REPLACE FUNCTION trigger_recalc_from_attendance()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM recalc_student_xp(OLD.student_id);
    PERFORM recalc_student_achievements(OLD.student_id);
    RETURN OLD;
  ELSE
    PERFORM recalc_student_xp(NEW.student_id);
    PERFORM recalc_student_achievements(NEW.student_id);
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_xp_from_attendance ON public.attendances;
CREATE TRIGGER trg_xp_from_attendance
  AFTER INSERT OR UPDATE OR DELETE ON public.attendances
  FOR EACH ROW EXECUTE FUNCTION trigger_recalc_from_attendance();

-- Setiap kali kas berubah
CREATE OR REPLACE FUNCTION trigger_recalc_from_kas()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM recalc_student_xp(OLD.student_id);
    PERFORM recalc_student_achievements(OLD.student_id);
    RETURN OLD;
  ELSE
    PERFORM recalc_student_xp(NEW.student_id);
    PERFORM recalc_student_achievements(NEW.student_id);
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_xp_from_kas ON public.cash_payments;
CREATE TRIGGER trg_xp_from_kas
  AFTER INSERT OR UPDATE OR DELETE ON public.cash_payments
  FOR EACH ROW EXECUTE FUNCTION trigger_recalc_from_kas();

-- ── 11. INISIALISASI XP UNTUK SISWA EXISTING ─────────────────
-- Jalankan sekali untuk siswa yang sudah ada datanya
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.students LOOP
    PERFORM recalc_student_xp(r.id);
    PERFORM recalc_student_achievements(r.id);
  END LOOP;
END;
$$;

-- ── 12. VIEW: LEADERBOARD ─────────────────────────────────────
CREATE OR REPLACE VIEW public.leaderboard_view AS
SELECT
  s.id,
  s.nama,
  s.kelas,
  s.avatar_url,
  COALESCE(x.total_xp, 0)    AS total_xp,
  COALESCE(x.level, 1)       AS level,
  COALESCE(a_hadir.cnt, 0)   AS total_hadir,
  COALESCE(a_alpha.cnt, 0)   AS total_alpha,
  COALESCE(a_izin.cnt, 0)    AS total_izin,
  COALESCE(a_sakit.cnt, 0)   AS total_sakit,
  COALESCE(k.kas_total, 0)   AS total_kas,
  COALESCE(k.kas_count, 0)   AS kas_count,
  -- Rank hadir
  RANK() OVER (ORDER BY COALESCE(a_hadir.cnt, 0) DESC) AS rank_hadir,
  -- Rank kas (jumlah pembayaran)
  RANK() OVER (ORDER BY COALESCE(k.kas_count, 0) DESC) AS rank_kas,
  -- Rank XP keseluruhan
  RANK() OVER (ORDER BY COALESCE(x.total_xp, 0) DESC) AS rank_xp
FROM public.students s
LEFT JOIN public.student_xp x ON x.student_id = s.id
LEFT JOIN (
  SELECT student_id, COUNT(*) AS cnt FROM public.attendances WHERE status = 'Hadir' GROUP BY student_id
) a_hadir ON a_hadir.student_id = s.id
LEFT JOIN (
  SELECT student_id, COUNT(*) AS cnt FROM public.attendances WHERE status = 'Alpha' GROUP BY student_id
) a_alpha ON a_alpha.student_id = s.id
LEFT JOIN (
  SELECT student_id, COUNT(*) AS cnt FROM public.attendances WHERE status = 'Izin' GROUP BY student_id
) a_izin ON a_izin.student_id = s.id
LEFT JOIN (
  SELECT student_id, COUNT(*) AS cnt FROM public.attendances WHERE status = 'Sakit' GROUP BY student_id
) a_sakit ON a_sakit.student_id = s.id
LEFT JOIN (
  SELECT student_id, SUM(nominal) AS kas_total, COUNT(*) AS kas_count
  FROM public.cash_payments GROUP BY student_id
) k ON k.student_id = s.id;

-- RLS tidak berlaku untuk view, akses dikontrol via tabel dasarnya
-- Tapi kita beri grant
GRANT SELECT ON public.leaderboard_view TO authenticated, anon;

-- ── 13. HUBUNGKAN SISWA KE AKUN USER (opsional) ──────────────
-- Admin bisa link siswa ke akun user via SQL:
-- UPDATE public.students SET user_id = 'UUID-USER' WHERE nama = 'Nama Siswa';

-- ============================================================
-- SELESAI! Tambahkan profil-siswa.html dan leaderboard.html ke project
-- ============================================================
