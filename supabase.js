// ============================================================
// supabase.js - Konfigurasi Supabase Client
// GANTI nilai di bawah ini dengan credentials Supabase Anda
// ============================================================

const SUPABASE_URL = 'https://giqynajbhchsqevbxhsi.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdpcXluYWpiaGNoc3FldmJ4aHNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzNzU4MjcsImV4cCI6MjA5Mzk1MTgyN30.-IxewgNlk-ya7XjkPeVk2yiiA1KZ7U_LrmrRJjGcVIs';

// Inisialisasi Supabase client menggunakan CDN
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export { supabaseClient };
