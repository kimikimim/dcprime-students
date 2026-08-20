import { createClient } from '@supabase/supabase-js';

// Cloudflare 빌드 환경변수 인식 문제로 anon key는 직접 박아둠 (anon key는 RLS로 보호되는 공개용 키)
const supabaseUrl = 'https://smnakhjdtbqgwocwlluz.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtbmFraGpkdGJxZ3dvY3dsbHV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4NDc2MDQsImV4cCI6MjA5MjQyMzYwNH0._jfUSWEVlMr8oapYLul33LRrhEnRJBSgppGNR1jshnA';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});
