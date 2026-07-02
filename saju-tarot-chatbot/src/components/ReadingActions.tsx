import { downloadShareImage } from "../lib/shareImage";
import { useReadingStore } from "../store/useReadingStore";
import type { ReadingSession } from "../types";

/** PDF 저장: 접힌 섹션을 모두 펼친 뒤 인쇄 다이얼로그(PDF로 저장)를 연다 */
function printReading() {
  const detailsList = document.querySelectorAll<HTMLDetailsElement>(".reading-result details");
  const wasClosed: HTMLDetailsElement[] = [];
  detailsList.forEach((d) => {
    if (!d.open) {
      d.open = true;
      wasClosed.push(d);
    }
  });
  window.print();
  wasClosed.forEach((d) => {
    d.open = false;
  });
}

export default function ReadingActions({ session }: { session: ReadingSession }) {
  const toggleFavoriteById = useReadingStore((s) => s.toggleFavoriteById);

  return (
    <div className="reading-actions">
      <button className="btn btn--secondary" onClick={() => toggleFavoriteById(session.id)}>
        {session.favorite ? "★ 즐겨찾기 해제" : "☆ 즐겨찾기"}
      </button>
      <button className="btn btn--secondary" onClick={printReading}>
        PDF 저장
      </button>
      <button className="btn btn--secondary" onClick={() => downloadShareImage(session)}>
        이미지로 공유
      </button>
    </div>
  );
}
