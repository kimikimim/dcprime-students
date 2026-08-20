-- ============================================================
-- dcprime-students (교직원 전용 재원생 관리) Supabase 셋업 SQL
-- 기존 대치프라임 DB(smnakhjdtbqgwocwlluz)에 그대로 추가 실행
-- Supabase SQL Editor에 전체 붙여넣고 한 번에 실행 (재실행해도 안전)
-- 테이블명은 기존 테이블과 겹치지 않도록 staff_ 접두사 사용
-- ============================================================

-- ────────────────────────────────────────────
-- 1. 교직원 로그인 설정 테이블 + 역할별 비밀번호 검증 함수
--    일반교직원 비밀번호: 2869 (조회만 가능)
--    관리자 비밀번호: 1250 (추가/수정/삭제 가능)
-- ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS staff_config (
  key text PRIMARY KEY,
  value text NOT NULL
);
ALTER TABLE staff_config ENABLE ROW LEVEL SECURITY;
-- 정책 없음 = anon 직접 조회 불가

INSERT INTO staff_config (key, value) VALUES
  ('staff_password', '2869'),
  ('admin_password', '1250')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

DROP FUNCTION IF EXISTS verify_staff_password(text);

-- 비밀번호가 맞으면 역할('admin' | 'staff')을, 틀리면 NULL을 반환
CREATE OR REPLACE FUNCTION verify_staff_login(pw text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  matched_key text;
BEGIN
  SELECT key INTO matched_key FROM staff_config
    WHERE key IN ('staff_password', 'admin_password') AND value = pw
    LIMIT 1;

  IF matched_key = 'admin_password' THEN
    RETURN 'admin';
  ELSIF matched_key = 'staff_password' THEN
    RETURN 'staff';
  ELSE
    RETURN NULL;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION verify_staff_login(text) TO anon;

-- ────────────────────────────────────────────
-- 2. 재원생 목록 테이블
--    RLS는 anon 전체 허용 (역할 구분은 앱 화면 단에서만 처리 — adminssh와 동일한 신뢰 모델)
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

-- ────────────────────────────────────────────
-- 3. 매년 1/1 자동 학년 진급 / 졸업 처리
--    - 고3 재원생: 삭제 (졸업)
--    - 초6, 중3 재원생: 학년 진급 + 학교 배정이 바뀌므로 school을 NULL로 초기화
--      (관리자 페이지에서 새 학교로 다시 입력)
--    - 그 외: 학년만 한 단계 진급
-- ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION staff_promote_grades()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM staff_students WHERE grade = '고3';

  UPDATE staff_students SET school = NULL WHERE grade IN ('초6', '중3');

  UPDATE staff_students SET grade = CASE grade
    WHEN '초4' THEN '초5'
    WHEN '초5' THEN '초6'
    WHEN '초6' THEN '중1'
    WHEN '중1' THEN '중2'
    WHEN '중2' THEN '중3'
    WHEN '중3' THEN '고1'
    WHEN '고1' THEN '고2'
    WHEN '고2' THEN '고3'
    ELSE grade
  END
  WHERE grade IN ('초4', '초5', '초6', '중1', '중2', '중3', '고1', '고2');
END;
$$;

-- pg_cron 확장 활성화 (이미 켜져 있으면 무시됨)
-- 이 줄에서 권한 오류가 나면 Supabase 대시보드 → Database → Extensions에서
-- pg_cron을 직접 켠 뒤, 아래 cron.schedule 부분부터 다시 실행하세요.
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 재실행 시 중복 스케줄 방지
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'staff-yearly-grade-promotion';

-- 매년 1월 1일 00:00(UTC, 한국시간 오전 9시)에 실행
SELECT cron.schedule(
  'staff-yearly-grade-promotion',
  '0 0 1 1 *',
  $$SELECT staff_promote_grades();$$
);
