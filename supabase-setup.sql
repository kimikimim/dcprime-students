-- ============================================================
-- dcprime-students (교직원 전용 재원생 관리) Supabase 셋업 SQL
-- 기존 대치프라임 DB(smnakhjdtbqgwocwlluz)에 그대로 추가 실행
-- Supabase SQL Editor에 전체 붙여넣고 한 번에 실행
-- 테이블명은 기존 테이블과 겹치지 않도록 staff_ 접두사 사용
-- ============================================================

-- ────────────────────────────────────────────
-- 1. 교직원 로그인 설정 테이블 + 비밀번호 검증 함수
-- ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS staff_config (
  key text PRIMARY KEY,
  value text NOT NULL
);
ALTER TABLE staff_config ENABLE ROW LEVEL SECURITY;
-- 정책 없음 = anon 직접 조회 불가

-- 최초 비밀번호. 배포 후 SQL Editor에서 직접 바꿔서 운영하세요.
INSERT INTO staff_config (key, value) VALUES ('staff_password', 'Prime0979!')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION verify_staff_password(pw text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  stored_pw text;
BEGIN
  SELECT value INTO stored_pw FROM staff_config WHERE key = 'staff_password';
  RETURN stored_pw = pw;
END;
$$;

GRANT EXECUTE ON FUNCTION verify_staff_password(text) TO anon;

-- ────────────────────────────────────────────
-- 2. 재원생 목록 테이블
-- ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS staff_students (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  name       text        NOT NULL,
  school     text,
  grade      text,
  subjects   text[]      DEFAULT '{}',
  teacher    text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE staff_students ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon select staff_students" ON staff_students;
DROP POLICY IF EXISTS "anon insert staff_students" ON staff_students;
DROP POLICY IF EXISTS "anon update staff_students" ON staff_students;
DROP POLICY IF EXISTS "anon delete staff_students" ON staff_students;

CREATE POLICY "anon select staff_students" ON staff_students
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon insert staff_students" ON staff_students
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon update staff_students" ON staff_students
  FOR UPDATE TO anon USING (true);

CREATE POLICY "anon delete staff_students" ON staff_students
  FOR DELETE TO anon USING (true);

CREATE OR REPLACE FUNCTION staff_students_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_staff_students_updated_at ON staff_students;
CREATE TRIGGER trg_staff_students_updated_at
  BEFORE UPDATE ON staff_students
  FOR EACH ROW EXECUTE FUNCTION staff_students_set_updated_at();

CREATE INDEX IF NOT EXISTS idx_staff_students_name ON staff_students (name);
