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

type LoadingGame = "omok" | "yut";
type Stone = "black" | "white" | null;

const YUT_RESULTS = [
  { name: "도", move: 1, note: "작게 한 칸. 오늘은 무리보다 시작이 좋아요." },
  { name: "개", move: 2, note: "두 칸 전진. 흐름이 조금씩 붙고 있어요." },
  { name: "걸", move: 3, note: "세 칸 전진. 생각보다 빠르게 풀릴 수 있어요." },
  { name: "윷", move: 4, note: "크게 전진. 한 번 더 던질 기세예요." },
  { name: "모", move: 5, note: "제일 큰 전진. 지금은 운이 시원하게 붙는 판이에요." },
];

function hasLine(board: Stone[], index: number, stone: Stone) {
  if (!stone) return false;
  const size = 5;
  const x = index % size;
  const y = Math.floor(index / size);
  const dirs = [
    [1, 0],
    [0, 1],
    [1, 1],
    [1, -1],
  ];

  return dirs.some(([dx, dy]) => {
    let count = 1;
    for (const sign of [-1, 1]) {
      let nx = x + dx * sign;
      let ny = y + dy * sign;
      while (nx >= 0 && nx < size && ny >= 0 && ny < size && board[ny * size + nx] === stone) {
        count += 1;
        nx += dx * sign;
        ny += dy * sign;
      }
    }
    return count >= 4;
  });
}

function OmokMiniGame() {
  const [board, setBoard] = useState<Stone[]>(Array.from({ length: 25 }, () => null));
  const [turn, setTurn] = useState<Exclude<Stone, null>>("black");
  const [winner, setWinner] = useState<Exclude<Stone, null> | "draw" | null>(null);

  const place = (index: number) => {
    if (board[index] || winner) return;
    const next = [...board];
    next[index] = turn;
    const nextWinner = hasLine(next, index, turn) ? turn : next.every(Boolean) ? "draw" : null;
    setBoard(next);
    setWinner(nextWinner);
    if (!nextWinner) setTurn(turn === "black" ? "white" : "black");
  };

  const reset = () => {
    setBoard(Array.from({ length: 25 }, () => null));
    setTurn("black");
    setWinner(null);
  };

  return (
    <div className="loading-game loading-game--omok">
      <div className="loading-game__head">
        <b>기다리는 동안 미니 오목</b>
        <button type="button" onClick={reset}>
          새 판
        </button>
      </div>
      <div className="omok-board" aria-label="미니 오목판">
        {board.map((stone, index) => (
          <button
            type="button"
            className={`omok-cell${stone ? ` omok-cell--${stone}` : ""}`}
            onClick={() => place(index)}
            aria-label={`${index + 1}번째 칸`}
            key={index}
          >
            {stone && <span />}
          </button>
        ))}
      </div>
      <p className="loading-game__note">
        {winner === "draw"
          ? "무승부예요. 리딩이 아직이면 한 판 더 가도 좋아요."
          : winner
            ? `${winner === "black" ? "흑" : "백"} 승! 리딩도 거의 다 익어가는 중이에요.`
            : `${turn === "black" ? "흑" : "백"} 차례 · 4개를 먼저 이어보세요.`}
      </p>
    </div>
  );
}

function YutMiniGame() {
  const [result, setResult] = useState(YUT_RESULTS[0]);
  const [throws, setThrows] = useState(0);

  const roll = () => {
    const next = YUT_RESULTS[Math.floor(Math.random() * YUT_RESULTS.length)];
    setResult(next);
    setThrows((value) => value + 1);
  };

  return (
    <div className="loading-game loading-game--yut">
      <div className="loading-game__head">
        <b>기다리는 동안 윷 던지기</b>
        <button type="button" onClick={roll}>
          던지기
        </button>
      </div>
      <div className="yut-result" aria-live="polite">
        <span>{result.name}</span>
        <strong>{result.move}칸</strong>
      </div>
      <p className="loading-game__note">
        {throws === 0 ? "한 번 던져볼까요? 리딩이 나오는 동안 가볍게 운을 봐요." : result.note}
      </p>
    </div>
  );
}

function LoadingMiniGame() {
  const [game] = useState<LoadingGame>(() => (Math.random() > 0.5 ? "omok" : "yut"));
  return game === "omok" ? <OmokMiniGame /> : <YutMiniGame />;
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
      <LoadingMiniGame />
    </div>
  );
}
