import { useEffect } from "react";
import { Link, useParams } from "react-router-dom";

interface SeoArticle {
  title: string;
  description: string;
  sections: Array<{ title: string; body: string[] }>;
  cta: string;
}

const ARTICLES: Record<string, SeoArticle> = {
  "unknown-birth-time": {
    title: "출생시간을 모를 때 사주와 속마음 리딩은 어떻게 달라질까",
    description:
      "출생시간을 모르면 시주 해석은 제한되지만, 연월일 삼주만으로도 일간·월지·오행 흐름·현재 운의 큰 방향은 볼 수 있습니다.",
    cta: "시간 모름으로 속마음 리딩 보기",
    sections: [
      {
        title: "시간을 몰라도 볼 수 있는 것",
        body: [
          "일간은 내가 세상을 받아들이는 기본 방식이고, 월지는 계절과 사회적 환경을 보여줍니다. 이 두 축은 출생시간이 없어도 계산됩니다.",
          "오행의 치우침, 십성의 큰 분포, 올해 들어오는 흐름도 기본 방향은 확인할 수 있습니다.",
        ],
      },
      {
        title: "조심해서 봐야 하는 것",
        body: [
          "시주는 말년, 자녀, 깊은 내면, 세부 습관을 볼 때 중요합니다. 시간이 없으면 이 부분은 단정하지 않는 편이 안전합니다.",
          "속마음 리딩에서도 시간 미입력 표시를 남기고, 확실한 원국 근거 위주로 표현합니다.",
        ],
      },
    ],
  },
  "sample-mystic-reading": {
    title: "속마음 리딩 샘플: 사주 근거를 심리 언어로 읽는 방식",
    description:
      "속마음 리딩은 사주 계산값을 그대로 던지기보다, 오행·십성·운의 흐름을 현재의 감정, 관계, 선택 패턴으로 번역합니다.",
    cta: "내 속마음 리딩 시작하기",
    sections: [
      {
        title: "리딩에 들어가는 핵심 요소",
        body: [
          "오행 분포는 에너지가 어디에 몰리고 어디가 비어 있는지 보여줍니다.",
          "십성은 일, 돈, 관계, 책임, 표현 방식처럼 현실에서 반복되는 행동 패턴을 읽는 데 씁니다.",
          "대운·세운·월운은 지금 왜 특정 주제가 더 크게 느껴지는지 확인하는 보조 근거입니다.",
        ],
      },
      {
        title: "사용자가 읽는 문장",
        body: [
          "전문 용어는 근거로 보존하되, 본문은 생활 언어로 먼저 설명합니다.",
          "예를 들어 관성이 강하다는 말은 책임, 규칙, 압박, 사회적 역할을 크게 느끼기 쉽다는 식으로 풀어냅니다.",
        ],
      },
    ],
  },
  "day-master": {
    title: "일간별 성향을 볼 때 가장 먼저 확인할 것",
    description:
      "일간은 사주의 출발점이지만, 일간 하나만으로 성격을 단정하면 틀리기 쉽습니다. 계절, 오행 균형, 십성 분포를 함께 봐야 합니다.",
    cta: "내 일간과 전체 명식 보기",
    sections: [
      {
        title: "일간은 중심축입니다",
        body: [
          "갑목, 을목, 병화 같은 일간은 내가 기본적으로 어떤 방식으로 반응하는지 보여주는 중심축입니다.",
          "하지만 같은 갑목이라도 봄에 태어났는지, 겨울에 태어났는지, 주변 오행이 무엇인지에 따라 현실 모습은 달라집니다.",
        ],
      },
      {
        title: "속마음 리딩에서는 이렇게 씁니다",
        body: [
          "일간은 기본 기질로 두고, 현재 운에서 흔들리는 지점과 반복되는 선택 패턴을 함께 연결합니다.",
          "그래서 단순한 성격표가 아니라 지금 내 삶에서 어떤 고민이 커지는지까지 이어서 봅니다.",
        ],
      },
    ],
  },
};

function setMeta(name: string, content: string) {
  let tag = document.querySelector<HTMLMetaElement>(`meta[name="${name}"]`);
  if (!tag) {
    tag = document.createElement("meta");
    tag.name = name;
    document.head.appendChild(tag);
  }
  tag.content = content;
}

export default function SeoPage() {
  const { slug = "sample-mystic-reading" } = useParams();
  const article = ARTICLES[slug] ?? ARTICLES["sample-mystic-reading"];

  useEffect(() => {
    document.title = `${article.title} | 속마음 사주 리딩`;
    setMeta("description", article.description);
  }, [article]);

  return (
    <section className="page seo-page">
      <p className="seo-kicker">공개 가이드</p>
      <h2 className="page-title">{article.title}</h2>
      <p className="page-desc">{article.description}</p>

      <div className="seo-article">
        {article.sections.map((section) => (
          <article className="card seo-section" key={section.title}>
            <h3>{section.title}</h3>
            {section.body.map((p) => (
              <p key={p}>{p}</p>
            ))}
          </article>
        ))}
      </div>

      <div className="card seo-cta">
        <strong>내 명식으로 직접 확인하기</strong>
        <p>생년월일시를 입력하면 계산 근거를 바탕으로 속마음, 관계, 선택 패턴을 읽어드립니다.</p>
        <Link className="btn btn--primary" to="/mystic">
          {article.cta}
        </Link>
      </div>
    </section>
  );
}
