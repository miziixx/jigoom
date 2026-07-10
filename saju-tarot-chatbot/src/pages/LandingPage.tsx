import { useMemo } from "react";
import { Link } from "react-router-dom";
import { buildDailyGreeting } from "../lib/dailyGreeting";
import { TOPIC_LABEL } from "../components/TopicDeepChat";
import type { TopicDeepTopic } from "../types";

// 절기별 짧은 안내문 — 계산된 절기(dailyGreeting.ts)에 따라 매일 자동으로 바뀐다.
// 접수처식 멘트("무슨 일로 왔어요?") 금지, 단정·공포 언어 금지(재기획안 §5) — 계절감만 짧게 전달한다.
const SOLAR_TERM_MOOD: Record<string, string> = {
  소한: "한 해의 첫 추위예요. 서두르기보다 준비하기 좋은 때예요.",
  대한: "가장 추운 고비예요. 무리하지 않고 컨디션부터 챙기기 좋은 때예요.",
  입춘: "봄이 들어서는 절기예요. 새로 시작하기 좋은 흐름이에요.",
  우수: "얼음이 풀리는 절기예요. 막혔던 일이 조금씩 풀리기 좋은 때예요.",
  경칩: "겨울잠 자던 것들이 깨어나는 절기예요. 움직여보기 좋은 때예요.",
  춘분: "낮과 밤의 길이가 같아지는 절기예요. 균형을 맞추기 좋은 때예요.",
  청명: "하늘이 맑아지는 절기예요. 계획을 점검하기 좋은 때예요.",
  곡우: "봄비가 곡식을 기르는 절기예요. 씨를 뿌리듯 준비하기 좋은 때예요.",
  입하: "여름이 들어서는 절기예요. 속도를 올려보기 좋은 때예요.",
  소만: "생기가 차오르는 절기예요. 벌여둔 일을 키우기 좋은 때예요.",
  망종: "씨 뿌리고 거두는 절기예요. 결정을 실행에 옮기기 좋은 때예요.",
  하지: "낮이 가장 긴 절기예요. 에너지를 잘 쓰는 게 중요한 때예요.",
  소서: "더위가 여무는 절기예요. 벌이기보다 고르기 좋은 때예요.",
  대서: "가장 더운 고비예요. 무리한 결정은 잠시 미뤄두기 좋은 때예요.",
  입추: "가을이 들어서는 절기예요. 정리를 시작하기 좋은 때예요.",
  처서: "더위가 물러서는 절기예요. 벌인 일을 다잡기 좋은 때예요.",
  백로: "이슬이 맺히는 절기예요. 차분히 마무리를 챙기기 좋은 때예요.",
  추분: "낮과 밤의 길이가 같아지는 절기예요. 다시 균형을 잡기 좋은 때예요.",
  한로: "찬 이슬이 내리는 절기예요. 한 해를 정리하기 시작하기 좋은 때예요.",
  상강: "서리가 내리는 절기예요. 마무리 지을 것과 남길 것을 가리기 좋은 때예요.",
  입동: "겨울이 들어서는 절기예요. 속도를 늦추고 다지기 좋은 때예요.",
  소설: "첫눈이 오는 절기예요. 한 해를 돌아보기 좋은 때예요.",
  대설: "눈이 많아지는 절기예요. 무리 없이 마무리하기 좋은 때예요.",
  동지: "밤이 가장 긴 절기예요. 새로운 흐름을 준비하기 좋은 때예요.",
};

const TOPIC_ICON: Record<TopicDeepTopic, string> = {
  love: "💘",
  money: "💰",
  career: "💼",
  health: "🌿",
  year: "🎆",
};

const TOPIC_ORDER: TopicDeepTopic[] = ["love", "money", "career", "health", "year"];

const DEEP_REPORTS = [
  {
    to: "/saju",
    icon: "📜",
    title: "평생사주 리포트",
    desc: "타고난 구조부터 대운 인생 지도까지. 신청 화면에서 깊이를 '고급'으로 선택하면 볼 수 있어요.",
    badge: "정성 리포트",
  },
  {
    to: "/saju",
    icon: "🔬",
    title: "나 해부 리포트",
    desc: "반복 패턴부터 그림자와 결핍까지. 신청 화면에서 완전분석을 켜면 볼 수 있어요.",
    badge: "정성 리포트",
  },
  {
    to: "/combo",
    icon: "🔮",
    title: "고민상담 리딩",
    desc: "질문과 선택지를 사주·타로로 함께 비교해 판단 기준을 잡아드려요.",
    badge: "질문 먼저",
  },
];

const RELATION_CARDS = [
  {
    to: "/compatibility",
    icon: "💞",
    title: "정밀 궁합",
    desc: "두 사람의 원국을 비교해 맞는 지점과 반복 갈등, 보완 방법을 봐요.",
  },
  {
    to: "/compatibility",
    icon: "🕵️",
    title: "상대 해부",
    desc: "궁합 화면에서 '상대 해부' 모드를 켜면 더 깊게 볼 수 있어요.",
  },
];

export default function LandingPage() {
  const greeting = useMemo(() => buildDailyGreeting(), []);
  const mood = SOLAR_TERM_MOOD[greeting.solarTerm] ?? "오늘 하루, 계산된 흐름을 살펴보세요.";

  return (
    <section className="page">
      <section className="landing-hero">
        <span className="landing-hero__date">{greeting.headline}</span>
        <h2>{mood}</h2>
        <p>
          계산은 만세력 기준으로 정밀하게, 해석은 좋은 말보다 근거와 선택 기준을 먼저 보여드립니다. 생년월일 원본을 저장하지 않고,
          계산된 사주 구조와 질문만으로 리포트를 만듭니다.
        </p>
      </section>

      <Link to="/fortune" className="card landing-today-card">
        <span className="landing-today-card__emoji" aria-hidden>
          ☀️
        </span>
        <span className="landing-today-card__body">
          <span className="landing-today-card__title">
            오늘의 흐름 자세히 <b className="feature-badge">무료 · 즉시</b>
          </span>
          <span className="landing-today-card__desc">내 사주 기준으로 오늘 하루의 리듬 + 타로 한 장 →</span>
        </span>
      </Link>

      <div className="landing-section-row">
        <h3 className="landing-section-title">궁금한 운만 골라보기</h3>
        <span className="landing-section-hint">약 30초 · 원국 저장 시 입력 생략</span>
      </div>
      <div className="landing-topic-grid">
        {TOPIC_ORDER.map((topic) => (
          <Link key={topic} to="/saju" className={`landing-topic landing-topic--${topic}`}>
            <span className="landing-topic__emoji" aria-hidden>
              {TOPIC_ICON[topic]}
            </span>
            <span className="landing-topic__name">{TOPIC_LABEL[topic]}</span>
            <span className="landing-topic__badge">약 30초</span>
          </Link>
        ))}
      </div>

      <div className="landing-section-row">
        <h3 className="landing-section-title">깊게 보기</h3>
        <span className="landing-section-hint">정성 리포트 · PDF 포함</span>
      </div>
      <div className="landing-report-list">
        {DEEP_REPORTS.map((r) => (
          <Link key={r.title} to={r.to} className="card landing-report">
            <span className="landing-report__emoji" aria-hidden>
              {r.icon}
            </span>
            <span className="landing-report__body">
              <span className="landing-report__title">{r.title}</span>
              <span className="landing-report__desc">{r.desc}</span>
            </span>
            <span className="premium-badge landing-report__badge">{r.badge}</span>
          </Link>
        ))}
      </div>

      <h3 className="landing-section-title" style={{ marginTop: 20 }}>
        관계
      </h3>
      <div className="landing-relation-grid">
        {RELATION_CARDS.map((r) => (
          <Link key={r.title} to={r.to} className="card landing-topic">
            <span className="landing-topic__emoji" aria-hidden>
              {r.icon}
            </span>
            <span className="landing-topic__name">{r.title}</span>
            <span className="landing-relation__desc">{r.desc}</span>
          </Link>
        ))}
      </div>

      <div className="landing-foot">
        <Link to="/naming">이름 감정·작명 ›</Link>
      </div>
    </section>
  );
}
