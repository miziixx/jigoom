import { Link } from "react-router-dom";

const PRIMARY_OPTIONS = [
  {
    to: "/saju",
    title: "내 사주 정밀 리포트",
    desc: "원국 구조, 운 흐름, 성향과 생활 조언을 근거 중심으로 정리합니다.",
  },
  {
    to: "/combo",
    title: "지금 고민 상담",
    desc: "사주 장기 흐름과 타로 현재 흐름을 함께 보고 선택 기준을 잡습니다.",
  },
  {
    to: "/compatibility",
    title: "궁합·관계 분석",
    desc: "두 사람의 원국을 비교해 맞는 지점, 반복 갈등, 보완 방법을 봅니다.",
  },
];

const SECONDARY_OPTIONS = [
  {
    to: "/tarot",
    title: "타로",
    desc: "질문과 카드 조합으로 지금 상황을 빠르게 확인합니다.",
  },
  {
    to: "/tarot-today",
    title: "오늘의 카드",
    desc: "오늘 하루의 분위기와 바로 해볼 조언을 타로 카드 1장으로 가볍게 확인합니다.",
  },
  {
    to: "/today",
    title: "오늘 흐름",
    desc: "오늘 일진이 내 원국과 맺는 관계로, 오늘 하루를 잘 쓰는 법을 짧고 실용적으로 알려드립니다.",
  },
  {
    to: "/fortune",
    title: "오늘의 운세",
    desc: "십성·합충·신살·오행 조력을 계산해 카테고리별 점수와 행운 아이템까지, 매일 갱신되는 오늘의 운세를 카드로 정리합니다.",
  },
  {
    to: "/flow",
    title: "흐름 캘린더",
    desc: "올해 12개월 월운을 모두 계산해, 시도하기 좋은 시기와 조심할 시기를 흐름으로 읽어드립니다.",
  },
  {
    to: "/naming",
    title: "이름 감정·추천",
    desc: "가진 이름이 사주와 얼마나 맞는지 감정하고, 사주에 어울리는 새 이름(한글+한자 뜻)도 추천받을 수 있어요. 페이지 상단에서 감정/추천 탭을 고르세요.",
  },
];

export default function LandingPage() {
  return (
    <section className="page">
      <section className="landing-hero">
        <span>전통명리 계산 기준 기반</span>
        <h2>무엇을 판단해드릴까요?</h2>
        <p>
          계산은 만세력 기준으로 정밀하게, 해석은 좋은 말보다 근거와 선택 기준을 먼저 보여드립니다. 생년월일 원본을 저장하지 않고,
          계산된 사주 구조와 질문만으로 리포트를 만듭니다.
        </p>
      </section>

      <div className="landing-primary-grid">
        {PRIMARY_OPTIONS.map((opt) => (
          <Link key={opt.to} to={opt.to} className="card landing-card landing-card--primary">
            <h3>{opt.title}</h3>
            <p>{opt.desc}</p>
            <b>상담 시작</b>
          </Link>
        ))}
      </div>

      <h3 className="landing-section-title">가볍게 확인하기</h3>
      <div className="landing-grid">
        {SECONDARY_OPTIONS.map((opt) => (
          <Link key={opt.to} to={opt.to} className="card landing-card">
            <h3>{opt.title}</h3>
            <p>{opt.desc}</p>
          </Link>
        ))}
      </div>
    </section>
  );
}
