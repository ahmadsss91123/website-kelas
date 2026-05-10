// ============================================================
// supabase.js - Konfigurasi Supabase Client
// GANTI nilai di bawah ini dengan credentials Supabase Anda
// ============================================================

const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';

// Inisialisasi Supabase client menggunakan CDN
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export { supabaseClient };
