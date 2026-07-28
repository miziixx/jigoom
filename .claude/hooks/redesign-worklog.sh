#!/bin/bash
# SessionStart hook: 인사이트 오라클 재기획 작업 레코드를 매 세션 강제로 노출한다.
# 계정이 달라도 이 훅이 리포에 커밋돼 있으므로 모든 세션에서 동일하게 실행된다.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
WORKLOG="$ROOT/saju-tarot-chatbot/docs/redesign-worklog.md"

# 재기획 워크로그가 없는 리포/브랜치에서는 조용히 통과 (다른 앱 작업 방해 금지)
if [ ! -f "$WORKLOG" ]; then
  exit 0
fi

echo "================ 인사이트 오라클 재기획 — 필수 작업 프로토콜 ================"
echo ""
echo "이 리포에는 '강제 확인/기록' 규칙이 있습니다. 재기획(saju-tarot-chatbot)"
echo "관련 작업이라면 아래를 반드시 지키세요. (무관한 작업이면 이 안내는 무시)"
echo ""
echo "  1) 먼저 아래 '현재 상태'를 읽고 무엇을 이어서 할지 파악한다."
echo "  2) 기준 문서를 확인한다:"
echo "       - saju-tarot-chatbot/docs/redesign-2026-07.md (기획안)"
echo "       - saju-tarot-chatbot/docs/mockups/redesign-mockup.html (시안)"
echo "  3) 작업을 마치면 반드시:"
echo "       - redesign-worklog.md 의 '현재 상태' 5줄을 최신으로 덮어쓰고"
echo "       - '세션 로그' 표에 이력 한 줄 append 하고"
echo "       - 변경을 커밋/푸시한다. (기록 없이 세션을 끝내지 않는다)"
echo ""
echo "------------------------ 현재 redesign-worklog.md ------------------------"
echo ""
cat "$WORKLOG"
echo ""
echo "======================================================================="
