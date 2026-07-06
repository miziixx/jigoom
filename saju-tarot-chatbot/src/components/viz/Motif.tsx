/**
 * 한지/수묵 느낌의 장식 SVG 모티프. 전부 순수 장식이라 aria-hidden으로 렌더하고
 * 데이터는 절대 담지 않는다 ("시각 요소 하나 = 메시지 하나" — 장식은 메시지 0개).
 */

export function SectionDivider() {
  return (
    <div className="motif-divider" aria-hidden="true">
      <svg viewBox="0 0 260 16" focusable="false">
        <path d="M6 8h98" className="motif-divider__line" />
        <path d="M130 2.6l5.4 5.4-5.4 5.4-5.4-5.4z" className="motif-divider__knot" />
        <circle cx="114" cy="8" r="1.4" className="motif-divider__bead" />
        <circle cx="146" cy="8" r="1.4" className="motif-divider__bead" />
        <path d="M156 8h98" className="motif-divider__line" />
      </svg>
    </div>
  );
}

const CORNER_POS = ["tl", "tr", "bl", "br"] as const;

/** 카드 네 모서리 장식. 부모에 position:relative가 필요하다. */
export function CornerOrnaments() {
  return (
    <span className="motif-corners" aria-hidden="true">
      {CORNER_POS.map((pos) => (
        <svg key={pos} className={`motif-corner motif-corner--${pos}`} viewBox="0 0 24 24" focusable="false">
          <path d="M2.5 21.5V10c0-4.1 3.4-7.5 7.5-7.5h11.5" fill="none" />
          <circle cx="6.5" cy="6.5" r="1.1" fill="currentColor" stroke="none" />
        </svg>
      ))}
    </span>
  );
}

/** 큰 장식 따옴표 (점괘 카드용). */
export function QuoteMark() {
  return (
    <svg className="motif-quote" viewBox="0 0 48 36" aria-hidden="true" focusable="false">
      <path
        d="M19.5 3.5C10.9 5.8 6 12 6 21.2V32h14.6V16.9h-8.2c.6-5.4 3.4-8.8 8.4-10.5l-1.3-2.9zM42 3.5C33.4 5.8 28.5 12 28.5 21.2V32h14.6V16.9h-8.2c.6-5.4 3.4-8.8 8.4-10.5L42 3.5z"
        fill="currentColor"
      />
    </svg>
  );
}

/** 은은한 구름 문양 배경. 같은 화면에 여럿 쓰면 id가 겹치지 않게 고유 id를 넘긴다. */
export function CloudPattern({ id }: { id: string }) {
  return (
    <svg className="motif-cloud" aria-hidden="true" focusable="false">
      <defs>
        <pattern id={id} width="72" height="48" patternUnits="userSpaceOnUse">
          <path
            d="M8 30c0-5 4-9 9-9 1.6 0 3.1.4 4.4 1.2C23 18 27 15.5 31.5 15.5c6 0 11 4.4 11.8 10.2 3.4.5 6.7 2.5 6.7 6.3H8.7C8.2 31.4 8 30.7 8 30z"
            fill="none"
            stroke="currentColor"
            strokeWidth="1"
          />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill={`url(#${id})`} />
    </svg>
  );
}

/** 작은 태극 마크. */
export function YinYangMark({ size = 14 }: { size?: number }) {
  return (
    <svg viewBox="0 0 20 20" width={size} height={size} aria-hidden="true" focusable="false" className="motif-yinyang">
      <circle cx="10" cy="10" r="7.6" fill="none" stroke="currentColor" strokeWidth="1.2" />
      <path d="M10 2.4a7.6 7.6 0 0 1 0 15.2 3.8 3.8 0 0 1 0-7.6 3.8 3.8 0 0 0 0-7.6z" fill="currentColor" />
      <circle cx="10" cy="6.2" r="1.1" fill="var(--surface, #fffaf1)" />
      <circle cx="10" cy="13.8" r="1.1" fill="currentColor" />
    </svg>
  );
}

/** 낙관(도장) 느낌의 사각 스탬프. 일진 간지 같은 짧은 글자를 담는다. */
export function SealStamp({ text }: { text: string }) {
  return (
    <span className="motif-seal" aria-hidden="true">
      <svg viewBox="0 0 44 44" focusable="false">
        <rect x="2.5" y="2.5" width="39" height="39" rx="7" fill="none" stroke="currentColor" strokeWidth="2.4" />
        <rect x="7.5" y="7.5" width="29" height="29" rx="4" fill="none" stroke="currentColor" strokeWidth="1" opacity="0.5" />
        <text x="22" y="28.5" textAnchor="middle" className="motif-seal__text">
          {text}
        </text>
      </svg>
    </span>
  );
}
