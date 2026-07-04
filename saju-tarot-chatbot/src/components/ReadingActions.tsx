import { downloadReadingMarkdown } from "../lib/exportMarkdown";
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
  const saveCurrentSession = useReadingStore((s) => s.saveCurrentSession);
  const isSaved = useReadingStore((s) => s.savedSessions.some((saved) => saved.id === session.id));

  return (
    <div className="reading-actions">
      {!isSaved && (
        <button className="btn btn--primary" onClick={() => saveCurrentSession(session)}>
          이 기기에 저장
        </button>
      )}
      {isSaved && (
        <button className="btn btn--secondary" onClick={() => toggleFavoriteById(session.id)}>
          {session.favorite ? "★ 즐겨찾기 해제" : "☆ 즐겨찾기"}
        </button>
      )}
      <button className="btn btn--secondary" onClick={printReading}>
        PDF 저장
      </button>
      <button className="btn btn--secondary" onClick={() => downloadReadingMarkdown(session)}>
        마크다운 저장
      </button>
      <button className="btn btn--secondary" onClick={() => void downloadShareImage(session)}>
        이미지 ZIP 저장
      </button>
      {!isSaved && <p className="field-hint reading-actions__hint">저장 버튼을 누르기 전까지 리딩 기록은 이 기기에 보관되지 않습니다.</p>}
    </div>
  );
}
