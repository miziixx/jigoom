import { Link } from "react-router-dom";

const OPTIONS = [
  {
    to: "/saju",
    title: "사주 보기",
    desc: "생년월일시로 사주 원국을 정확히 계산하고, 성향과 오행 흐름을 근거와 함께 풀이합니다.",
  },
  {
    to: "/tarot",
    title: "타로 보기",
    desc: "질문을 입력하고 카드를 뽑으면, 카드 조합을 근거로 지금 상황을 밀도 있게 해석합니다.",
  },
  {
    to: "/combo",
    title: "사주 + 타로 통합",
    desc: "타고난 장기 흐름(사주)과 지금 이 질문의 단기 흐름(타로)을 함께 짚어드립니다.",
  },
];

export default function LandingPage() {
  return (
    <section className="page">
      <h2 className="page-title">무엇을 봐드릴까요?</h2>
      <p className="page-desc">
        계산은 실제 만세력 기준으로 정확하게, 해석은 단정 대신 근거와 가능성을 밝혀 전달합니다. "100% 적중"을
        주장하지 않습니다 — 이 리딩은 자기이해와 판단을 돕는 참고 자료입니다.
      </p>
      <div className="landing-grid">
        {OPTIONS.map((opt) => (
          <Link key={opt.to} to={opt.to} className="card landing-card">
            <h3>{opt.title}</h3>
            <p>{opt.desc}</p>
          </Link>
        ))}
      </div>
    </section>
  );
}
