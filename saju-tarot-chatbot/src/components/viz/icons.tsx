import type { ReactNode } from "react";

/**
 * 앱 전역에서 쓰는 손그림 스타일 스트로크 아이콘 모음.
 * - 외부 라이브러리 없이 인라인 SVG만 사용한다 (번들 부담 최소화).
 * - 아이콘은 장식이다: 항상 옆의 텍스트가 의미를 말하므로 aria-hidden으로 렌더한다.
 * - 건강 아이콘은 의료 연상(십자가 등)을 피하고 잎사귀를 쓴다.
 */

const PATHS: Record<string, ReactNode> = {
  // ── 섹션/분야 ──
  person: (
    <>
      <circle cx="10" cy="6.4" r="3" />
      <path d="M4.6 16.5c0-3 2.4-5 5.4-5s5.4 2 5.4 5" />
    </>
  ),
  briefcase: (
    <>
      <rect x="3.4" y="6.8" width="13.2" height="9" rx="1.6" />
      <path d="M7.6 6.8V5.4A1.4 1.4 0 0 1 9 4h2a1.4 1.4 0 0 1 1.4 1.4v1.4M3.4 10.8h13.2" />
    </>
  ),
  coin: (
    <>
      <circle cx="10" cy="10" r="6.6" />
      <rect x="7.9" y="7.9" width="4.2" height="4.2" />
    </>
  ),
  heart: (
    <path d="M10 16.4S3.6 12.4 3.6 8.2c0-2.2 1.7-3.7 3.6-3.7 1.2 0 2.2.6 2.8 1.6.6-1 1.6-1.6 2.8-1.6 1.9 0 3.6 1.5 3.6 3.7 0 4.2-6.4 8.2-6.4 8.2z" />
  ),
  leaf: (
    <>
      <path d="M15.6 4.4C9.2 4.4 4.6 8 4.6 15.4c7.4 0 11-4.6 11-11z" />
      <path d="M4.9 15.1c2.6-4 5.8-7.2 9.4-9.5" />
    </>
  ),
  wave: (
    <path d="M3 7.6c2-2.4 4-2.4 6 0s4 2.4 6 0M3 12.8c2-2.4 4-2.4 6 0s4 2.4 6 0" />
  ),
  calendar: (
    <>
      <rect x="3.4" y="5" width="13.2" height="11.4" rx="1.6" />
      <path d="M3.4 9h13.2M7 3.4v3M13 3.4v3" />
    </>
  ),
  magnifier: (
    <>
      <circle cx="8.8" cy="8.8" r="4.9" />
      <path d="M12.4 12.4l4.1 4.1" />
    </>
  ),
  scale: (
    <>
      <path d="M10 3.6v12.8M6.6 16.4h6.8M4 6.2h12" />
      <path d="M4 6.2l-1.9 4.5a2.3 2.3 0 0 0 3.8 0L4 6.2zM16 6.2l-1.9 4.5a2.3 2.3 0 0 0 3.8 0L16 6.2z" />
    </>
  ),
  flag: (
    <>
      <path d="M5.2 17V3.6" />
      <path d="M5.2 4.4h9.4l-2.2 3 2.2 3H5.2" />
    </>
  ),
  checkCircle: (
    <>
      <circle cx="10" cy="10" r="6.6" />
      <path d="M7.1 10.3l2.1 2.1 3.7-4.4" />
    </>
  ),
  moonStar: (
    <>
      <path d="M11.8 3.6a6.6 6.6 0 1 0 4.6 10.6A7.4 7.4 0 0 1 11.8 3.6z" />
      <path d="M15 4.2l.5 1.3 1.3.5-1.3.5-.5 1.3-.5-1.3-1.3-.5 1.3-.5z" />
    </>
  ),
  quote: (
    <path d="M7.2 8.4a2.3 2.3 0 1 1-2.3 2.3c0-2.9 1.2-4.8 3.3-5.9M15 8.4a2.3 2.3 0 1 1-2.3 2.3c0-2.9 1.2-4.8 3.3-5.9" />
  ),
  dots: (
    <>
      <circle cx="4.8" cy="10" r="1.1" fill="currentColor" stroke="none" />
      <circle cx="10" cy="10" r="1.1" fill="currentColor" stroke="none" />
      <circle cx="15.2" cy="10" r="1.1" fill="currentColor" stroke="none" />
    </>
  ),
  // ── 파트(소제목) ──
  book: (
    <>
      <path d="M10 5.4C8.5 4.2 6.6 3.7 3.6 3.7v11.6c3 0 4.9.5 6.4 1.7 1.5-1.2 3.4-1.7 6.4-1.7V3.7c-3 0-4.9.5-6.4 1.7z" />
      <path d="M10 5.4V17" />
    </>
  ),
  home: (
    <>
      <path d="M3.8 9.6L10 4l6.2 5.6" />
      <path d="M5.4 8.6v7.6h9.2V8.6" />
    </>
  ),
  alertTriangle: (
    <>
      <path d="M10 3.8L17.4 16H2.6z" />
      <path d="M10 8.6v3.4" />
      <circle cx="10" cy="13.9" r="0.5" fill="currentColor" stroke="none" />
    </>
  ),
  sprout: (
    <>
      <path d="M10 16.6v-6.2" />
      <path d="M10 10.4C10 7 7.8 5 4.4 5c0 3.6 2.1 5.4 5.6 5.4zM10 10.4c0-3 2-4.7 5.6-4.7 0 3-2.1 4.7-5.6 4.7z" />
    </>
  ),
  checkSquare: (
    <>
      <rect x="3.8" y="3.8" width="12.4" height="12.4" rx="2" />
      <path d="M7.2 10.2l2 2 3.7-4.2" />
    </>
  ),
  // ── UI 공용 ──
  compass: (
    <>
      <circle cx="10" cy="10" r="6.6" />
      <path d="M12.9 7.1l-1.7 4.1-4.1 1.7 1.7-4.1z" />
    </>
  ),
  clock: (
    <>
      <circle cx="10" cy="10" r="6.6" />
      <path d="M10 6.4V10l2.5 1.8" />
    </>
  ),
  pin: (
    <>
      <path d="M10 17s-5.1-4.4-5.1-8.1a5.1 5.1 0 0 1 10.2 0C15.1 12.6 10 17 10 17z" />
      <circle cx="10" cy="8.9" r="1.8" />
    </>
  ),
  palette: (
    <>
      <path d="M10 3.5a6.5 6.5 0 1 0 0 13c1 0 1.5-.6 1.5-1.3 0-.9-.9-1.3-.9-2.2 0-.8.7-1.5 1.7-1.5h1.3c1.6 0 2.9-1.2 2.9-2.7C16.5 6 13.6 3.5 10 3.5z" />
      <circle cx="7" cy="8" r="0.6" fill="currentColor" stroke="none" />
      <circle cx="10.6" cy="6.4" r="0.6" fill="currentColor" stroke="none" />
      <circle cx="6.8" cy="11.5" r="0.6" fill="currentColor" stroke="none" />
    </>
  ),
  hash: (
    <path d="M7.6 3.8l-1.5 12.4M13.9 3.8l-1.5 12.4M4.4 7.8h12M3.6 12.4h12" />
  ),
  check: <path d="M4.4 10.6l3.6 3.6 7.6-8.6" />,
  sparkle: (
    <path d="M10 3.4l1.6 5 5 1.6-5 1.6-1.6 5-1.6-5-5-1.6 5-1.6z" />
  ),
  people: (
    <>
      <circle cx="7" cy="6.9" r="2.5" />
      <path d="M2.9 15.6c0-2.4 1.8-4 4.1-4s4.1 1.6 4.1 4" />
      <circle cx="13.7" cy="7.5" r="2" />
      <path d="M13.2 11.7c2.2.2 3.9 1.6 3.9 3.9" />
    </>
  ),
  link: (
    <>
      <path d="M8.2 11.8l3.6-3.6" />
      <path d="M6.8 9.4L5.2 11a3 3 0 0 0 4.2 4.2l1.6-1.6M13.2 10.6l1.6-1.6A3 3 0 0 0 10.6 4.8L9 6.4" />
    </>
  ),
  // ── 타로 수트 ──
  wand: (
    <>
      <path d="M10 17V4.4" />
      <path d="M10 5.2l-2.4 2M10 5.2l2.4 2M10 9l-2 1.7M10 9l2 1.7" />
    </>
  ),
  cup: (
    <>
      <path d="M5.6 4.6h8.8v3.2a4.4 4.4 0 0 1-8.8 0z" />
      <path d="M10 12.4v2.8M7.2 15.4h5.6" />
    </>
  ),
  sword: (
    <>
      <path d="M10 3.6v9.6" />
      <path d="M7.4 6.2L10 3.6l2.6 2.6" />
      <path d="M6.6 13.2h6.8M10 13.2v3.2" />
    </>
  ),
  pentacle: (
    <>
      <circle cx="10" cy="10" r="6.6" />
      <path d="M10 5.4l1.4 3 3.2.3-2.4 2.1.7 3.2-2.9-1.7-2.9 1.7.7-3.2-2.4-2.1 3.2-.3z" />
    </>
  ),
  star: (
    <path d="M10 3.8l1.9 3.9 4.3.6-3.1 3 .7 4.2-3.8-2-3.8 2 .7-4.2-3.1-3 4.3-.6z" />
  ),
};

/** ReadingResult SECTION_META의 tone → 아이콘 이름 */
const SECTION_ICON: Record<string, string> = {
  self: "person",
  work: "briefcase",
  money: "coin",
  love: "heart",
  health: "leaf",
  flow: "wave",
  year: "calendar",
  pattern: "magnifier",
  decision: "scale",
  strategy: "flag",
  action: "checkCircle",
  tarot: "moonStar",
  conclusion: "quote",
  default: "dots",
};

/** ReadingResult PART_META의 tone → 아이콘 이름 */
const PART_ICON: Record<string, string> = {
  conclusion: "quote",
  plain: "book",
  why: "magnifier",
  life: "home",
  caution: "alertTriangle",
  use: "sprout",
  todo: "checkSquare",
  default: "dots",
};

export function VizIcon({ name, size = 16, className }: { name: string; size?: number; className?: string }) {
  const body = PATHS[name] ?? PATHS.dots;
  return (
    <svg
      className={className ? `viz-icon ${className}` : "viz-icon"}
      viewBox="0 0 20 20"
      width={size}
      height={size}
      fill="none"
      stroke="currentColor"
      strokeWidth={1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {body}
    </svg>
  );
}

export function SectionIcon({ tone, size = 18, className }: { tone?: string; size?: number; className?: string }) {
  return <VizIcon name={SECTION_ICON[tone ?? "default"] ?? "dots"} size={size} className={className} />;
}

export function PartIcon({ tone, size = 14, className }: { tone?: string; size?: number; className?: string }) {
  return <VizIcon name={PART_ICON[tone ?? "default"] ?? "dots"} size={size} className={className} />;
}
