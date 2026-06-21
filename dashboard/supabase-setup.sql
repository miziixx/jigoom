-- ════════════════════════════════════════════════
-- 내 운영 대시보드 — Supabase 초기 설정 SQL
-- Supabase 대시보드 > SQL Editor 에서 실행해줘.
-- ════════════════════════════════════════════════

-- 1. 데이터 테이블 생성 (유저 1명당 행 1개)
CREATE TABLE IF NOT EXISTS public.user_data (
  user_id    UUID        PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  tasks      JSONB       NOT NULL DEFAULT '[]',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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
