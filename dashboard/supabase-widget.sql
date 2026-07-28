-- ════════════════════════════════════════════════
-- 받은함 빠른메모 위젯용 큐 테이블
-- Supabase 대시보드 > SQL Editor 에서 실행해줘.
-- ════════════════════════════════════════════════

-- 위젯이 INSERT만 하면 되도록 user_id 는 자동(auth.uid())으로 채워짐
CREATE TABLE IF NOT EXISTS public.inbox_queue (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL DEFAULT auth.uid() REFERENCES auth.users ON DELETE CASCADE,
  text       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 본인 데이터만 (위젯도 로그인한 본인으로만 넣을 수 있음)
ALTER TABLE public.inbox_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "본인 큐만 접근" ON public.inbox_queue;
CREATE POLICY "본인 큐만 접근"
  ON public.inbox_queue
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 실시간으로 대시보드가 바로 받아가도록
ALTER PUBLICATION supabase_realtime ADD TABLE public.inbox_queue;

-- ── 점검 ──
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname='inbox_queue';
