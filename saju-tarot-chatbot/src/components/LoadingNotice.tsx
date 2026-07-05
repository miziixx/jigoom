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

const OMOK_SIZE = 5;
const HUMAN_STONE: Exclude<Stone, null> = "black";
const COMPUTER_STONE: Exclude<Stone, null> = "white";
const OMOK_DIRS = [
  [1, 0],
  [0, 1],
  [1, 1],
  [1, -1],
];

const YUT_RESULTS = [
  { name: "도", move: 1, note: "작게 한 칸." },
  { name: "개", move: 2, note: "두 칸 전진." },
  { name: "걸", move: 3, note: "세 칸 전진." },
  { name: "윷", move: 4, note: "크게 전진. 한 번 더!" },
  { name: "모", move: 5, note: "제일 큰 전진!" },
];
const YUT_FINISH = 20;

function longestLineAt(board: Stone[], index: number, stone: Stone) {
  if (!stone) return 0;
  const x = index % OMOK_SIZE;
  const y = Math.floor(index / OMOK_SIZE);
  let best = 1;
  for (const [dx, dy] of OMOK_DIRS) {
    let count = 1;
    for (const sign of [-1, 1]) {
      let nx = x + dx * sign;
      let ny = y + dy * sign;
      while (nx >= 0 && nx < OMOK_SIZE && ny >= 0 && ny < OMOK_SIZE && board[ny * OMOK_SIZE + nx] === stone) {
        count += 1;
        nx += dx * sign;
        ny += dy * sign;
      }
    }
    if (count > best) best = count;
  }
  return best;
}

/** 즉시 승리 > 상대 승리 저지 > 중앙 선호 + 자기/상대 연결 가능성 순으로 고르는 간단한 오목 AI. */
function pickComputerMove(board: Stone[]): number {
  const empties: number[] = [];
  board.forEach((cell, idx) => {
    if (!cell) empties.push(idx);
  });

  for (const idx of empties) {
    const next = [...board];
    next[idx] = COMPUTER_STONE;
    if (longestLineAt(next, idx, COMPUTER_STONE) >= 4) return idx;
  }
  for (const idx of empties) {
    const next = [...board];
    next[idx] = HUMAN_STONE;
    if (longestLineAt(next, idx, HUMAN_STONE) >= 4) return idx;
  }

  const center = (OMOK_SIZE - 1) / 2;
  let bestIdx = empties[0];
  let bestScore = -Infinity;
  for (const idx of empties) {
    const asComputer = [...board];
    asComputer[idx] = COMPUTER_STONE;
    const asHuman = [...board];
    asHuman[idx] = HUMAN_STONE;
    const x = idx % OMOK_SIZE;
    const y = Math.floor(idx / OMOK_SIZE);
    const centerDistance = Math.abs(x - center) + Math.abs(y - center);
    const score = longestLineAt(asComputer, idx, COMPUTER_STONE) * 2 + longestLineAt(asHuman, idx, HUMAN_STONE) - centerDistance * 0.1;
    if (score > bestScore) {
      bestScore = score;
      bestIdx = idx;
    }
  }
  return bestIdx;
}

function OmokMiniGame() {
  const [board, setBoard] = useState<Stone[]>(Array.from({ length: 25 }, () => null));
  const [turn, setTurn] = useState<Exclude<Stone, null>>(HUMAN_STONE);
  const [winner, setWinner] = useState<Exclude<Stone, null> | "draw" | null>(null);

  const place = (index: number) => {
    if (turn !== HUMAN_STONE || board[index] || winner) return;
    const next = [...board];
    next[index] = HUMAN_STONE;
    const nextWinner = longestLineAt(next, index, HUMAN_STONE) >= 4 ? HUMAN_STONE : next.every(Boolean) ? "draw" : null;
    setBoard(next);
    setWinner(nextWinner);
    if (!nextWinner) setTurn(COMPUTER_STONE);
  };

  const reset = () => {
    setBoard(Array.from({ length: 25 }, () => null));
    setTurn(HUMAN_STONE);
    setWinner(null);
  };

  useEffect(() => {
    if (turn !== COMPUTER_STONE || winner) return;
    const id = window.setTimeout(() => {
      setBoard((current) => {
        const index = pickComputerMove(current);
        const next = [...current];
        next[index] = COMPUTER_STONE;
        const nextWinner = longestLineAt(next, index, COMPUTER_STONE) >= 4 ? COMPUTER_STONE : next.every(Boolean) ? "draw" : null;
        setWinner(nextWinner);
        setTurn(nextWinner ? COMPUTER_STONE : HUMAN_STONE);
        return next;
      });
    }, 500);
    return () => window.clearTimeout(id);
  }, [turn, winner]);

  return (
    <div className="loading-game loading-game--omok">
      <div className="loading-game__head">
        <b>기다리는 동안 미니 오목 · 나 vs 프로그램</b>
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
            disabled={turn !== HUMAN_STONE || Boolean(winner)}
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
          : winner === HUMAN_STONE
            ? "내가 이겼어요! 리딩도 거의 다 익어가는 중이에요."
            : winner === COMPUTER_STONE
              ? "프로그램이 이겼어요. 한 판 더 가볼까요?"
              : turn === HUMAN_STONE
                ? "내 차례(흑) · 4개를 먼저 이어보세요."
                : "프로그램이 두는 중..."}
      </p>
    </div>
  );
}

function YutMiniGame() {
  const [playerPos, setPlayerPos] = useState(0);
  const [computerPos, setComputerPos] = useState(0);
  const [turn, setTurn] = useState<"player" | "computer">("player");
  const [winner, setWinner] = useState<"player" | "computer" | null>(null);
  const [lastRoll, setLastRoll] = useState<{ who: "player" | "computer"; result: (typeof YUT_RESULTS)[number] } | null>(null);

  const roll = () => {
    if (turn !== "player" || winner) return;
    const result = YUT_RESULTS[Math.floor(Math.random() * YUT_RESULTS.length)];
    setLastRoll({ who: "player", result });
    setPlayerPos((pos) => {
      const nextPos = Math.min(YUT_FINISH, pos + result.move);
      if (nextPos >= YUT_FINISH) setWinner("player");
      else setTurn("computer");
      return nextPos;
    });
  };

  const reset = () => {
    setPlayerPos(0);
    setComputerPos(0);
    setTurn("player");
    setWinner(null);
    setLastRoll(null);
  };

  useEffect(() => {
    if (turn !== "computer" || winner) return;
    const id = window.setTimeout(() => {
      const result = YUT_RESULTS[Math.floor(Math.random() * YUT_RESULTS.length)];
      setLastRoll({ who: "computer", result });
      setComputerPos((pos) => {
        const nextPos = Math.min(YUT_FINISH, pos + result.move);
        if (nextPos >= YUT_FINISH) setWinner("computer");
        else setTurn("player");
        return nextPos;
      });
    }, 600);
    return () => window.clearTimeout(id);
  }, [turn, winner]);

  return (
    <div className="loading-game loading-game--yut">
      <div className="loading-game__head">
        <b>기다리는 동안 윷놀이 대결 · 나 vs 프로그램</b>
        <button type="button" onClick={reset}>
          새 판
        </button>
      </div>
      <div className="yut-race">
        <div className="yut-race__row">
          <span className="yut-race__label">나</span>
          <div className="yut-race__track">
            <div className="yut-race__fill yut-race__fill--player" style={{ width: `${(playerPos / YUT_FINISH) * 100}%` }} />
          </div>
          <span className="yut-race__pos">{playerPos}/{YUT_FINISH}</span>
        </div>
        <div className="yut-race__row">
          <span className="yut-race__label">프로그램</span>
          <div className="yut-race__track">
            <div className="yut-race__fill yut-race__fill--computer" style={{ width: `${(computerPos / YUT_FINISH) * 100}%` }} />
          </div>
          <span className="yut-race__pos">{computerPos}/{YUT_FINISH}</span>
        </div>
      </div>
      <div className="yut-result" aria-live="polite">
        <span>{lastRoll ? lastRoll.result.name : "-"}</span>
        <strong>{lastRoll ? `${lastRoll.result.move}칸 (${lastRoll.who === "player" ? "나" : "프로그램"})` : "던지기 대기"}</strong>
      </div>
      <button type="button" className="loading-game__action" onClick={roll} disabled={turn !== "player" || Boolean(winner)}>
        던지기
      </button>
      <p className="loading-game__note">
        {winner === "player"
          ? "내가 먼저 도착했어요! 리딩도 거의 다 익어가는 중이에요."
          : winner === "computer"
            ? "프로그램이 먼저 도착했어요. 한 판 더 가볼까요?"
            : turn === "player"
              ? "내 차례예요 · 던지기를 눌러보세요."
              : "프로그램이 던지는 중..."}
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
