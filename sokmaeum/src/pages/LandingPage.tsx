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
  {
    to: "/today",
    title: "오늘의 흐름",
    desc: "오늘 일진이 내 원국과 맺는 관계로, 오늘 하루를 잘 쓰는 법을 짧고 실용적으로 알려드립니다.",
  },
  {
    to: "/fortune",
    title: "오늘의 운세",
    desc: "십성·합충·신살·오행 조력을 계산해 카테고리별 점수와 행운 아이템까지, 매일 갱신되는 오늘의 운세를 카드로 정리합니다.",
  },
  {
    to: "/flow",
    title: "월간·연간 운 흐름",
    desc: "올해 12개월 월운을 모두 계산해, 시도하기 좋은 시기와 조심할 시기를 흐름으로 읽어드립니다.",
  },
];

const TRUST_BADGES = ["근거 펼치기", "저장 안 함", "100% 적중 주장 안 함"];

const SEO_GUIDES = [
  { to: "/seo/unknown-birth-time", title: "출생시간을 모를 때", desc: "시간 미입력 리딩에서 볼 수 있는 것과 조심할 점" },
  { to: "/seo/day-master", title: "일간별 성향 읽기", desc: "일간만으로 단정하지 않고 전체 명식을 함께 보는 법" },
  { to: "/seo/sample-mystic-reading", title: "속마음 리딩 샘플", desc: "사주 근거를 심리 언어로 번역하는 방식" },
];

export default function LandingPage() {
  return (
    <section className="page">
      <div className="hero">
        <h1 className="hero-title">내 사주를 한 번에 이해하는 개인 명식 리포트</h1>
        <p className="hero-sub">
          어렵고 흩어진 사주풀이를, 쉬운말·전문가 근거·현실 조언으로 정리해드립니다.
        </p>
        <Link to="/mystic" className="hero-cta">
          내 명식 리포트 받기
        </Link>
        <ul className="trust-badges">
          {TRUST_BADGES.map((b) => (
            <li key={b} className="trust-badge">
              {b}
            </li>
          ))}
        </ul>
      </div>

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

      <h2 className="page-title seo-guide-title">처음 보는 분을 위한 가이드</h2>
      <div className="seo-guide-grid">
        {SEO_GUIDES.map((guide) => (
          <Link key={guide.to} to={guide.to} className="card landing-card seo-guide-card">
            <h3>{guide.title}</h3>
            <p>{guide.desc}</p>
          </Link>
        ))}
      </div>
    </section>
  );
}
