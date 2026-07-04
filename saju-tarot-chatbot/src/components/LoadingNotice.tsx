import { useEffect, useState } from "react";
import type { ReadingContext, ReadingType } from "../types";
import { buildReadingProgress } from "../lib/readingProgress";

const DEPTH_ETA: Record<NonNullable<ReadingContext["depth"]>, string> = {
  light: "핵심만 먼저 정리하는 모드예요. 보통 금방 첫 문장이 떠요.",
  basic: "전체 흐름을 압축해서 쓰는 중이에요. 보통 10~20초 정도 걸려요.",
  advanced: "근거와 행동 조언을 함께 엮는 중이에요. 30~60초 정도 걸릴 수 있어요.",
  expert: "가장 자세한 리딩이라 1~2분 정도 걸릴 수 있어요. 먼저 뜨는 내용부터 읽어도 괜찮아요.",
};

interface LoadingNoticeProps {
  depth?: ReadingContext["depth"];
  /** 최초 리딩 생성일 때만 넘긴다. 후속 질문 응답은 `#` 섹션 형식을 안 쓰므로 진행률 계산에서 제외한다. */
  type?: ReadingType;
  hasQuestion?: boolean;
  /** 지금까지 스트리밍된 답변 텍스트. 세션이 아직 없으면 undefined. */
  replyText?: string;
  isInitial?: boolean;
}

/**
 * 계산은 이미 끝났고 AI가 문장을 만드는 동안 보여주는 안내.
 * 실제 스트리밍 텍스트에 등장한 `# 섹션명` 개수로 진짜 진행률을 계산해서 보여준다(가짜 고정 스텝 아님).
 * 세션이 아직 없거나(계산 대기 중) 후속 질문 응답일 때는 진행률 없이 경과 시간만 보여준다.
 */
export default function LoadingNotice({ depth, type, hasQuestion = false, replyText, isInitial = true }: LoadingNoticeProps) {
  const [elapsed, setElapsed] = useState(0);

  useEffect(() => {
    const start = Date.now();
    const id = window.setInterval(() => setElapsed(Math.floor((Date.now() - start) / 1000)), 1000);
    return () => window.clearInterval(id);
  }, []);

  const progress = isInitial && type && replyText !== undefined ? buildReadingProgress(type, hasQuestion, replyText) : null;

  return (
    <div className="loading-notice">
      <div className="loading-notice__head">
        <span className="loading-notice__spinner" aria-hidden="true" />
        <span>
          계산은 끝났고, 풀이를 쓰고 있어요. <span className="loading-notice__elapsed">({elapsed}초 경과)</span>
        </span>
      </div>
      <p className="loading-notice__note">{depth ? DEPTH_ETA[depth] : "곧 첫 점괘부터 뜨기 시작해요."}</p>
      {progress && (
        <div className="loading-progress" aria-label="리딩 생성 진행률">
          <div className="loading-progress__track">
            <div className="loading-progress__fill" style={{ width: `${progress.percent}%` }} />
          </div>
          <p className="loading-progress__label">
            {progress.completed}/{progress.total}
            {progress.currentTitle ? ` · 지금 쓰는 중: ${progress.currentTitle}` : " · 마무리 중"}
          </p>
        </div>
      )}
    </div>
  );
}
