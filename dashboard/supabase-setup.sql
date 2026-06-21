-- ════════════════════════════════════════════════
-- 내 운영 대시보드 — Supabase 초기 설정 SQL
-- Supabase 대시보드 > SQL Editor 에서 실행해줘.
-- ════════════════════════════════════════════════

-- 1. 데이터 테이블 생성 (유저 1명당 행 1개)
CREATE TABLE IF NOT EXISTS public.user_data (
  user_id    UUID        PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  tasks      JSONB       NOT NULL DEFAULT '[]',
  cats       JSONB       NOT NULL DEFAULT '[]',
  projects   JSONB       NOT NULL DEFAULT '[]',
  routines   JSONB       NOT NULL DEFAULT '[]',
  memos      JSONB       NOT NULL DEFAULT '[]',
  diary      JSONB       NOT NULL DEFAULT '[]',
  theme      TEXT        NOT NULL DEFAULT 'mint',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 이미 테이블을 만들어 둔 경우 추가 컬럼만 보강
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS cats     JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS projects JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS routines JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS memos    JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS diary    JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS theme    TEXT  NOT NULL DEFAULT 'mint';

-- 2. Row Level Security 활성화
--    → 로그인 없이는 데이터에 전혀 접근 불가
ALTER TABLE public.user_data ENABLE ROW LEVEL SECURITY;

-- 3. "내 데이터만" 정책
--    SELECT / INSERT / UPDATE / DELETE 모두 본인 row만 허용
CREATE POLICY "본인 데이터만 접근"
  ON public.user_data
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 4. 실시간 동기화 활성화
--    (Supabase 대시보드 > Database > Replication 에서
--     user_data 테이블 토글도 켜줘야 해)
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_data;

-- ════════════════════════════════════════════════
-- 5. (점검용) RLS가 실제로 켜져 있는지 확인
--    아래 두 쿼리를 SQL Editor에서 실행해봐.
-- ════════════════════════════════════════════════

-- (a) rowsecurity 가 true 여야 안전 (false면 anon 키로 전체 노출!)
SELECT relname, relrowsecurity AS rls_enabled
FROM pg_class
WHERE relname = 'user_data';

-- (b) "본인 데이터만 접근" 정책이 보여야 함
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'user_data';
