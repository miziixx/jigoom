import { useEffect, useState } from "react";
import type { ReadingContext, ReadingType } from "../types";
import { buildReadingProgress } from "../lib/readingProgress";

const DEPTH_ETA: Record<NonNullable<ReadingContext["depth"]>, string> = {
  advanced: "근거와 행동 조언을 함께 엮는 중이에요. 30~60초 정도 걸릴 수 있어요.",
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

type LoadingGame = "omok" | "tetris";
type Stone = "black" | "white" | null;
type TetrisCell = string | null;

const OMOK_SIZE = 5;
const HUMAN_STONE: Exclude<Stone, null> = "black";
const COMPUTER_STONE: Exclude<Stone, null> = "white";
const OMOK_DIRS = [
  [1, 0],
  [0, 1],
  [1, 1],
  [1, -1],
];

const TETRIS_WIDTH = 8;
const TETRIS_HEIGHT = 12;
const TETRIS_SHAPES = [
  {
    name: "I",
    color: "cyan",
    cells: [
      [0, 1],
      [1, 1],
      [2, 1],
      [3, 1],
    ],
  },
  {
    name: "O",
    color: "gold",
    cells: [
      [0, 0],
      [1, 0],
      [0, 1],
      [1, 1],
    ],
  },
  {
    name: "T",
    color: "violet",
    cells: [
      [1, 0],
      [0, 1],
      [1, 1],
      [2, 1],
    ],
  },
  {
    name: "L",
    color: "orange",
    cells: [
      [0, 0],
      [0, 1],
      [1, 1],
      [2, 1],
    ],
  },
  {
    name: "S",
    color: "green",
    cells: [
      [1, 0],
      [2, 0],
      [0, 1],
      [1, 1],
    ],
  },
];

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

function rotatePiece(piece: (typeof TETRIS_SHAPES)[number]) {
  if (piece.name === "O") return piece.cells;
  return piece.cells.map(([x, y]) => [1 - y, x] as [number, number]);
}

function TetrisMiniGame() {
  const makePiece = () => {
    const shape = TETRIS_SHAPES[Math.floor(Math.random() * TETRIS_SHAPES.length)];
    return { ...shape, x: Math.floor(TETRIS_WIDTH / 2) - 2, y: 0 };
  };
  const emptyBoard = () => Array.from({ length: TETRIS_WIDTH * TETRIS_HEIGHT }, () => null as TetrisCell);
  const [board, setBoard] = useState<TetrisCell[]>(emptyBoard);
  const [piece, setPiece] = useState(makePiece);
  const [cleared, setCleared] = useState(0);
  const [gameOver, setGameOver] = useState(false);

  const cellsOf = (p = piece) => p.cells.map(([x, y]) => [p.x + x, p.y + y] as [number, number]);
  const canPlace = (p: typeof piece, current = board) =>
    cellsOf(p).every(([x, y]) => x >= 0 && x < TETRIS_WIDTH && y >= 0 && y < TETRIS_HEIGHT && !current[y * TETRIS_WIDTH + x]);

  const lockPiece = (p: typeof piece) => {
    const next = [...board];
    for (const [x, y] of cellsOf(p)) next[y * TETRIS_WIDTH + x] = p.color;
    const rows: TetrisCell[][] = [];
    let removed = 0;
    for (let y = 0; y < TETRIS_HEIGHT; y += 1) {
      const row = next.slice(y * TETRIS_WIDTH, (y + 1) * TETRIS_WIDTH);
      if (row.every(Boolean)) removed += 1;
      else rows.push(row);
    }
    while (rows.length < TETRIS_HEIGHT) rows.unshift(Array.from({ length: TETRIS_WIDTH }, () => null));
    const clearedBoard = rows.flat();
    const nextPiece = makePiece();
    setBoard(clearedBoard);
    setCleared((n) => n + removed);
    setPiece(nextPiece);
    if (!canPlace(nextPiece, clearedBoard)) setGameOver(true);
  };

  const move = (dx: number, dy: number) => {
    if (gameOver) return;
    const next = { ...piece, x: piece.x + dx, y: piece.y + dy };
    if (canPlace(next)) setPiece(next);
    else if (dy > 0) lockPiece(piece);
  };

  const rotate = () => {
    if (gameOver) return;
    const next = { ...piece, cells: rotatePiece(piece) };
    if (canPlace(next)) setPiece(next);
  };

  const reset = () => {
    setBoard(emptyBoard());
    setPiece(makePiece());
    setCleared(0);
    setGameOver(false);
  };

  useEffect(() => {
    if (gameOver) return;
    const id = window.setInterval(() => move(0, 1), 800);
    return () => window.clearInterval(id);
  });

  const active = new Set(cellsOf().map(([x, y]) => `${x}:${y}`));

  return (
    <div className="loading-game loading-game--tetris">
      <div className="loading-game__head">
        <b>기다리는 동안 미니 테트리스</b>
        <button type="button" onClick={reset}>
          새 판
        </button>
      </div>
      <div className="tetris-wrap">
        <div className="tetris-board" aria-label="미니 테트리스">
          {board.map((cell, index) => {
            const x = index % TETRIS_WIDTH;
            const y = Math.floor(index / TETRIS_WIDTH);
            const activeCell = active.has(`${x}:${y}`);
            const color = activeCell ? piece.color : cell;
            return <span className={`tetris-cell${color ? ` tetris-cell--${color}` : ""}`} key={index} />;
          })}
        </div>
        <div className="tetris-controls">
          <button type="button" onClick={() => move(-1, 0)} disabled={gameOver}>
            왼쪽
          </button>
          <button type="button" onClick={rotate} disabled={gameOver}>
            돌리기
          </button>
          <button type="button" onClick={() => move(1, 0)} disabled={gameOver}>
            오른쪽
          </button>
          <button type="button" onClick={() => move(0, 1)} disabled={gameOver}>
            내리기
          </button>
        </div>
      </div>
      <p className="loading-game__note">
        {gameOver ? "블록이 가득 찼어요. 새 판으로 다시 시작해도 좋아요." : `지운 줄 ${cleared}개 · 리딩이 완성되는 동안 가볍게 움직여보세요.`}
      </p>
    </div>
  );
}

function LoadingMiniGame() {
  const [game] = useState<LoadingGame>(() => (Math.random() > 0.5 ? "omok" : "tetris"));
  return game === "omok" ? <OmokMiniGame /> : <TetrisMiniGame />;
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

  const progress = isInitial && type && replyText !== undefined ? buildReadingProgress(type, hasQuestion, replyText, depth) : null;

  return (
    <div className="loading-notice">
      <div className="loading-notice__head">
        <span className="loading-notice__spinner" aria-hidden="true" />
        <span>
          <strong>리딩 생성 중이에요.</strong> 계산은 끝났고, 풀이를 쓰고 있어요. <span className="loading-notice__elapsed">({elapsed}초 경과)</span>
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
