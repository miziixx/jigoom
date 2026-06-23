// 가계부 (5단계에서 구현 예정).
// 4단계까지는 자리만 잡아두고, 장보기 '구매 완료' 시 일지에 지출이 아닌 구매로 기록됨.
export default function LedgerPage() {
  return (
    <div className="page">
      <div className="empty">
        <p>가계부는 5단계에서 열려요.</p>
        <p className="dim">지출 기록 · 월 요약 · 장보기 연동이 들어올 자리예요.</p>
      </div>
    </div>
  );
}
