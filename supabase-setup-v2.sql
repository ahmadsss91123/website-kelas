-- ============================================================
-- SUPABASE SQL SETUP V2 – Fitur Lengkap Manajemen Kelas
-- Jalankan SETELAH supabase-setup.sql
-- Project → SQL Editor → New Query → Paste → Run
-- ============================================================

-- ── 1. UPDATE PROFILES – Tambah field gamifikasi ────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS xp INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS level INTEGER DEFAULT 1;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS streak_login INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_login DATE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS streak_hadir INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS streak_kas INTEGER DEFAULT 0;

-- ── 2. JADWAL PELAJARAN ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.schedules (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tanggal     DATE NOT NULL,
  hari        TEXT NOT NULL,
  mata_pelajaran TEXT,
  guru        TEXT,
  jam_mulai   TIME,
  jam_selesai TIME,
  ruang_kelas TEXT,
  status      TEXT NOT NULL DEFAULT 'normal'
                CHECK (status IN ('normal','libur','kegiatan_sekolah','ujian','class_meeting','pengganti','study_tour','agenda_khusus')),
  catatan     TEXT,
  created_by  UUID REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_schedules_tanggal ON public.schedules(tanggal);
CREATE INDEX IF NOT EXISTS idx_schedules_status ON public.schedules(status);

-- ── 3. TUGAS / ASSIGNMENTS ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.assignments (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  judul       TEXT NOT NULL,
  mata_pelajaran TEXT NOT NULL,
  deskripsi   TEXT,
  deadline    TIMESTAMPTZ NOT NULL,
  lampiran_url TEXT,
  lampiran_name TEXT,
  guru        TEXT,
  created_by  UUID REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assignments_deadline ON public.assignments(deadline);
CREATE INDEX IF NOT EXISTS idx_assignments_mapel ON public.assignments(mata_pelajaran);

-- ── 4. BANK MATERI ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.materials (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  judul       TEXT NOT NULL,
  mata_pelajaran TEXT NOT NULL,
  deskripsi   TEXT,
  file_url    TEXT NOT NULL,
  file_name   TEXT NOT NULL,
  file_type   TEXT,
  file_size   BIGINT DEFAULT 0,
  uploaded_by UUID REFERENCES auth.users(id),
  uploader_name TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_materials_mapel ON public.materials(mata_pelajaran);

-- ── 5. CONFESSION / PESAN ANONIM ────────────────────────────
CREATE TABLE IF NOT EXISTS public.confessions (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pesan       TEXT NOT NULL,
  kategori    TEXT DEFAULT 'confession'
                CHECK (kategori IN ('confession','kritik','saran')),
  status      TEXT DEFAULT 'pending'
                CHECK (status IN ('pending','approved','rejected')),
  likes       INTEGER DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.confession_likes (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  confession_id UUID NOT NULL REFERENCES public.confessions(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(confession_id, user_id)
);

-- ── 6. WALL OF MEMORIES ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.memories (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  image_url   TEXT NOT NULL,
  caption     TEXT,
  uploaded_by UUID REFERENCES auth.users(id),
  uploader_name TEXT,
  likes       INTEGER DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.memory_likes (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  memory_id  UUID NOT NULL REFERENCES public.memories(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(memory_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.memory_comments (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  memory_id  UUID NOT NULL REFERENCES public.memories(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES auth.users(id),
  user_name  TEXT,
  komentar   TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 7. QUOTES ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.quotes (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teks       TEXT NOT NULL,
  penulis    TEXT,
  kategori   TEXT DEFAULT 'motivasi'
               CHECK (kategori IN ('motivasi','lucu','inside_joke')),
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 8. POLLING / VOTING ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.polls (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  judul       TEXT NOT NULL,
  deskripsi   TEXT,
  is_active   BOOLEAN DEFAULT true,
  created_by  UUID REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  ends_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.poll_options (
  id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  poll_id  UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  teks     TEXT NOT NULL,
  votes    INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.poll_votes (
  id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  poll_id   UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(poll_id, user_id)
);

-- ── 9. PENGUMUMAN ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.announcements (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  judul      TEXT NOT NULL,
  isi        TEXT NOT NULL,
  is_pinned  BOOLEAN DEFAULT false,
  created_by UUID REFERENCES auth.users(id),
  author_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 10. XP LOGS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.xp_logs (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount     INTEGER NOT NULL,
  reason     TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_xp_user ON public.xp_logs(user_id);

-- ── 11. ACHIEVEMENTS / BADGES ───────────────────────────────
CREATE TABLE IF NOT EXISTS public.achievements (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nama        TEXT NOT NULL UNIQUE,
  deskripsi   TEXT,
  icon        TEXT DEFAULT '🏆',
  syarat      TEXT,
  xp_reward   INTEGER DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_achievements (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id UUID NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
  earned_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);

-- ── 12. EVENTS (Countdown) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.events (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  judul      TEXT NOT NULL,
  tanggal    TIMESTAMPTZ NOT NULL,
  deskripsi  TEXT,
  kategori   TEXT DEFAULT 'umum'
               CHECK (kategori IN ('ujian','class_meeting','kelulusan','study_tour','umum')),
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 13. SHOUTBOX ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.shoutbox (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID REFERENCES auth.users(id),
  user_name  TEXT,
  pesan      TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 14. THEME SETTINGS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.class_settings (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key        TEXT NOT NULL UNIQUE,
  value      TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── TRIGGERS updated_at ─────────────────────────────────────
CREATE TRIGGER trg_schedules_updated BEFORE UPDATE ON public.schedules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_assignments_updated BEFORE UPDATE ON public.assignments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_announcements_updated BEFORE UPDATE ON public.announcements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── ENABLE RLS ──────────────────────────────────────────────
ALTER TABLE public.schedules       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.confessions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.confession_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_likes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polls           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_logs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shoutbox        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_settings  ENABLE ROW LEVEL SECURITY;

-- ── POLICIES: Semua user login bisa baca ────────────────────

-- Schedules
CREATE POLICY "schedules_select" ON public.schedules FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "schedules_insert" ON public.schedules FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "schedules_update" ON public.schedules FOR UPDATE USING (get_my_role() = 'admin');
CREATE POLICY "schedules_delete" ON public.schedules FOR DELETE USING (get_my_role() = 'admin');

-- Assignments
CREATE POLICY "assignments_select" ON public.assignments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "assignments_insert" ON public.assignments FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "assignments_update" ON public.assignments FOR UPDATE USING (get_my_role() = 'admin');
CREATE POLICY "assignments_delete" ON public.assignments FOR DELETE USING (get_my_role() = 'admin');

-- Materials
CREATE POLICY "materials_select" ON public.materials FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "materials_insert" ON public.materials FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "materials_delete" ON public.materials FOR DELETE USING (get_my_role() = 'admin' OR uploaded_by = auth.uid());

-- Confessions
CREATE POLICY "confessions_select" ON public.confessions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "confessions_insert" ON public.confessions FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "confessions_update" ON public.confessions FOR UPDATE USING (get_my_role() = 'admin');
CREATE POLICY "confessions_delete" ON public.confessions FOR DELETE USING (get_my_role() = 'admin');

-- Confession Likes
CREATE POLICY "confession_likes_select" ON public.confession_likes FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "confession_likes_insert" ON public.confession_likes FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "confession_likes_delete" ON public.confession_likes FOR DELETE USING (user_id = auth.uid());

-- Memories
CREATE POLICY "memories_select" ON public.memories FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "memories_insert" ON public.memories FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "memories_delete" ON public.memories FOR DELETE USING (get_my_role() = 'admin' OR uploaded_by = auth.uid());

-- Memory Likes
CREATE POLICY "memory_likes_select" ON public.memory_likes FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "memory_likes_insert" ON public.memory_likes FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "memory_likes_delete" ON public.memory_likes FOR DELETE USING (user_id = auth.uid());

-- Memory Comments
CREATE POLICY "memory_comments_select" ON public.memory_comments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "memory_comments_insert" ON public.memory_comments FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "memory_comments_delete" ON public.memory_comments FOR DELETE USING (get_my_role() = 'admin' OR user_id = auth.uid());

-- Quotes
CREATE POLICY "quotes_select" ON public.quotes FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "quotes_insert" ON public.quotes FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "quotes_delete" ON public.quotes FOR DELETE USING (get_my_role() = 'admin');

-- Polls
CREATE POLICY "polls_select" ON public.polls FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "polls_insert" ON public.polls FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "polls_update" ON public.polls FOR UPDATE USING (get_my_role() = 'admin');
CREATE POLICY "polls_delete" ON public.polls FOR DELETE USING (get_my_role() = 'admin');

-- Poll Options
CREATE POLICY "poll_options_select" ON public.poll_options FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "poll_options_insert" ON public.poll_options FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "poll_options_delete" ON public.poll_options FOR DELETE USING (get_my_role() = 'admin');

-- Poll Votes
CREATE POLICY "poll_votes_select" ON public.poll_votes FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "poll_votes_insert" ON public.poll_votes FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Announcements
CREATE POLICY "announcements_select" ON public.announcements FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "announcements_insert" ON public.announcements FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "announcements_update" ON public.announcements FOR UPDATE USING (get_my_role() = 'admin');
CREATE POLICY "announcements_delete" ON public.announcements FOR DELETE USING (get_my_role() = 'admin');

-- XP Logs
CREATE POLICY "xp_logs_select" ON public.xp_logs FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "xp_logs_insert" ON public.xp_logs FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Achievements
CREATE POLICY "achievements_select" ON public.achievements FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "achievements_insert" ON public.achievements FOR INSERT WITH CHECK (get_my_role() = 'admin');

-- User Achievements
CREATE POLICY "user_achievements_select" ON public.user_achievements FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "user_achievements_insert" ON public.user_achievements FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Events
CREATE POLICY "events_select" ON public.events FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "events_insert" ON public.events FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "events_update" ON public.events FOR UPDATE USING (get_my_role() = 'admin');
CREATE POLICY "events_delete" ON public.events FOR DELETE USING (get_my_role() = 'admin');

-- Shoutbox
CREATE POLICY "shoutbox_select" ON public.shoutbox FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "shoutbox_insert" ON public.shoutbox FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "shoutbox_delete" ON public.shoutbox FOR DELETE USING (get_my_role() = 'admin' OR user_id = auth.uid());

-- Class Settings
CREATE POLICY "settings_select" ON public.class_settings FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "settings_insert" ON public.class_settings FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "settings_update" ON public.class_settings FOR UPDATE USING (get_my_role() = 'admin');

-- ── INSERT DEFAULT ACHIEVEMENTS ─────────────────────────────
INSERT INTO public.achievements (nama, deskripsi, icon, syarat, xp_reward) VALUES
  ('Tidak Pernah Alpha', 'Tidak pernah alpha selama sebulan', '🌟', 'zero_alpha_month', 50),
  ('Rajin Bayar Kas', 'Bayar kas tepat waktu 4 minggu berturut-turut', '💎', 'kas_streak_4', 40),
  ('Aktif di Website', 'Login 7 hari berturut-turut', '🔥', 'login_streak_7', 30),
  ('Raja Voting', 'Ikut voting 5 kali', '👑', 'vote_count_5', 25),
  ('Kontributor Materi', 'Upload 3 materi', '📚', 'upload_material_3', 35),
  ('Hadir Full Sebulan', 'Hadir penuh selama 1 bulan', '🏅', 'full_attendance_month', 60),
  ('Sosialita Kelas', 'Kirim 10 pesan di shoutbox', '💬', 'shoutbox_10', 20),
  ('Memory Maker', 'Upload 5 foto kenangan', '📸', 'upload_memory_5', 30),
  ('First Login', 'Login pertama kali', '🎉', 'first_login', 10),
  ('Streak Master', 'Login streak 30 hari', '⚡', 'login_streak_30', 100)
ON CONFLICT (nama) DO NOTHING;

-- ── INSERT DEFAULT QUOTES ───────────────────────────────────
INSERT INTO public.quotes (teks, penulis, kategori) VALUES
  ('Pendidikan adalah senjata paling ampuh untuk mengubah dunia.', 'Nelson Mandela', 'motivasi'),
  ('Belajar tanpa berpikir itu tidak berguna, tapi berpikir tanpa belajar itu berbahaya.', 'Konfusius', 'motivasi'),
  ('Masa depan milik mereka yang percaya pada keindahan mimpi-mimpi mereka.', 'Eleanor Roosevelt', 'motivasi'),
  ('Guru terbaik adalah pengalaman, tapi biaya sekolahnya mahal.', 'Anonim', 'lucu'),
  ('PR itu seperti cinta, kadang bikin galau tapi harus dikerjakan.', 'Anonim', 'inside_joke'),
  ('Jangan pernah menyerah, kecuali kamu sedang mengangkat tangan untuk bertanya.', 'Anonim', 'lucu'),
  ('Sukses bukan tentang menjadi yang terbaik, tapi menjadi lebih baik dari kemarin.', 'Anonim', 'motivasi'),
  ('Kelas ini bukan sekadar ruangan, tapi keluarga kedua.', 'Anonim', 'inside_joke')
ON CONFLICT DO NOTHING;

-- ── SUPABASE STORAGE BUCKETS ────────────────────────────────
-- Jalankan ini di SQL Editor atau buat manual di Storage UI:
-- 1. Buat bucket 'materials' (public)
-- 2. Buat bucket 'memories' (public)
-- 3. Buat bucket 'assignments' (public)

INSERT INTO storage.buckets (id, name, public) VALUES ('materials', 'materials', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('memories', 'memories', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('assignments', 'assignments', true) ON CONFLICT DO NOTHING;

-- Storage policies
CREATE POLICY "materials_storage_select" ON storage.objects FOR SELECT USING (bucket_id = 'materials');
CREATE POLICY "materials_storage_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'materials' AND auth.uid() IS NOT NULL);
CREATE POLICY "materials_storage_delete" ON storage.objects FOR DELETE USING (bucket_id = 'materials' AND auth.uid() IS NOT NULL);

CREATE POLICY "memories_storage_select" ON storage.objects FOR SELECT USING (bucket_id = 'memories');
CREATE POLICY "memories_storage_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'memories' AND auth.uid() IS NOT NULL);
CREATE POLICY "memories_storage_delete" ON storage.objects FOR DELETE USING (bucket_id = 'memories' AND auth.uid() IS NOT NULL);

CREATE POLICY "assignments_storage_select" ON storage.objects FOR SELECT USING (bucket_id = 'assignments');
CREATE POLICY "assignments_storage_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'assignments' AND auth.uid() IS NOT NULL);
CREATE POLICY "assignments_storage_delete" ON storage.objects FOR DELETE USING (bucket_id = 'assignments' AND auth.uid() IS NOT NULL);

-- ============================================================
-- SELESAI! Lanjut deploy website dengan fitur baru
-- ============================================================
