// 일관된 라인 아이콘 세트 (이모지 대체). 24x24 그리드, currentColor 스트로크.
// 색은 부모의 color를 따르고, 크기는 size prop으로 조절.

export type IconName =
  | "home"
  | "clean"
  | "basket"
  | "wallet"
  | "archive"
  | "book"
  | "search"
  | "edit"
  | "sprout"
  | "chevron"
  | "sun"
  | "calendar"
  | "flame"
  | "alert"
  | "trash"
  | "pin"
  | "close"
  | "plus";

const PATHS: Record<IconName, JSX.Element> = {
  home: (
    <>
      <path d="M3.5 11.5 12 4.5l8.5 7" />
      <path d="M5.5 10.5V20h13v-9.5" />
      <path d="M9.5 20v-5.5h5V20" />
    </>
  ),
  clean: (
    <>
      <path d="M12 3.5l1.7 4.6L18.3 10l-4.6 1.9L12 16.5l-1.7-4.6L5.7 10l4.6-1.9z" />
      <path d="M18.3 14.3l.8 1.9 1.9.8-1.9.8-.8 1.9-.8-1.9-1.9-.8 1.9-.8z" />
    </>
  ),
  basket: (
    <>
      <path d="M5 9h14l-1.1 8.8a2 2 0 0 1-2 1.7H8.1a2 2 0 0 1-2-1.7z" />
      <path d="M9.2 9 11 4.5M14.8 9 13 4.5" />
      <path d="M9.6 12.5v3.5M14.4 12.5v3.5" />
    </>
  ),
  wallet: (
    <>
      <path d="M3.5 8A2.5 2.5 0 0 1 6 5.5h10.5a1 1 0 0 1 1 1V8" />
      <rect x="3.5" y="8" width="17" height="11" rx="2.5" />
      <circle cx="16.5" cy="13.5" r="1.4" />
    </>
  ),
  archive: (
    <>
      <rect x="3.5" y="4.5" width="17" height="4.5" rx="1.5" />
      <path d="M5 9v8.5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9" />
      <path d="M10 13h4" />
    </>
  ),
  book: (
    <>
      <path d="M12 7v12" />
      <path d="M12 7C10.3 5.7 7.8 5.2 4 5.5V17c3.8-.3 6.3.2 8 1.5 1.7-1.3 4.2-1.8 8-1.5V5.5c-3.8-.3-6.3.2-8 1.5z" />
    </>
  ),
  search: (
    <>
      <circle cx="11" cy="11" r="7" />
      <path d="M20 20l-3.4-3.4" />
    </>
  ),
  edit: (
    <>
      <path d="M4 20h4L19 9a2 2 0 0 0-3-3L5 17z" />
      <path d="M14.5 7.5l3 3" />
    </>
  ),
  sprout: (
    <>
      <path d="M12 20v-7.5" />
      <path d="M12 13C12 9.4 9.4 7 5.8 7 5.8 10.6 8.4 13 12 13z" />
      <path d="M12 11c0-3 2.2-5.2 5.2-5.2C17.2 8.8 15 11 12 11z" />
    </>
  ),
  chevron: <path d="M9.5 5.5 16 12l-6.5 6.5" />,
  sun: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 3v2.2M12 18.8V21M3 12h2.2M18.8 12H21M5.6 5.6l1.6 1.6M16.8 16.8l1.6 1.6M18.4 5.6l-1.6 1.6M7.2 16.8l-1.6 1.6" />
    </>
  ),
  calendar: (
    <>
      <rect x="4" y="5.5" width="16" height="15" rx="2.5" />
      <path d="M4 10h16M8.5 3.5v4M15.5 3.5v4" />
    </>
  ),
  flame: (
    <path d="M12 3.5c3 3.4 4.8 5.8 4.8 8.7a4.8 4.8 0 0 1-9.6 0c0-1.7.8-3.1 1.9-4.2.3 1.1.9 1.8 1.8 2C11.2 8.2 11.6 6 12 3.5z" />
  ),
  alert: (
    <>
      <path d="M12 4.5 21.5 19.5H2.5z" />
      <path d="M12 10v4.2M12 17.2h.01" />
    </>
  ),
  trash: (
    <>
      <path d="M5 7h14" />
      <path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7" />
      <path d="M6.5 7l.8 11a2 2 0 0 0 2 1.9h5.4a2 2 0 0 0 2-1.9l.8-11" />
      <path d="M10 11v5M14 11v5" />
    </>
  ),
  pin: (
    <>
      <path d="M12 21s6-5.3 6-10a6 6 0 1 0-12 0c0 4.7 6 10 6 10z" />
      <circle cx="12" cy="11" r="2.3" />
    </>
  ),
  close: <path d="M6 6l12 12M18 6 6 18" />,
  plus: <path d="M12 5.5v13M5.5 12h13" />,
};

export default function Icon({
  name,
  size = 22,
  strokeWidth = 1.7,
  className,
}: {
  name: IconName;
  size?: number;
  strokeWidth?: number;
  className?: string;
}) {
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {PATHS[name]}
    </svg>
  );
}
