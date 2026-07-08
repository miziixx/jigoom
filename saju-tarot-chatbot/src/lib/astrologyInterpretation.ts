// 점성술 해석 지식베이스 (봇·웹 공용).
//
// 계산(astrology.ts)이 "무엇이 어디에 있는지"를 결정론적으로 내놓으면, 이 파일은 그 배치의
// *표준 의미*를 짧은 gloss로 붙인다. 사주의 iljuTraits·신살풀이가 하는 역할의 점성술판.
//
// 원칙: 여기 담긴 건 어디까지나 "표준 상징 해석 힌트"다. 실제 답변 문장은 LLM이 사용자 질문에
// 맞춰 풀어 쓰되, 없는 배치를 지어내지 않도록 계산된 배치에만 힌트를 붙여 넘긴다.
//
// 행성×별자리는 10×12=120 조합을 통째로 적지 않고, "행성=무엇(기능)" × "별자리=어떻게(방식)"로
// 합성한다. 프로 점성술의 표준 독법(행성=what, 별자리=how, 하우스=where)을 그대로 따른 것.
import type { AstrologyAspect, AstrologyProfile, ZodiacSign } from "../types";

/** 행성/포인트가 "무엇"을 담당하는지 (기능). */
export const PLANET_ROLE: Record<string, string> = {
  태양: "삶의 방향과 핵심 자아",
  달: "감정 습관과 안정 욕구",
  수성: "생각·소통·배우는 방식",
  금성: "사랑받고 끌리는 방식과 취향",
  화성: "욕망·추진력·화내는 방식",
  목성: "확장·기회·믿는 것(과하면 과잉)",
  토성: "책임·한계·성숙의 과제(두려움)",
  천왕성: "독립·변화·틀을 깨는 지점",
  해왕성: "이상·상상·경계가 흐려지는 지점",
  명왕성: "집착·변형·재생이 일어나는 지점",
  상승궁: "첫인상과 세상에 나서는 방식",
  라그나: "삶을 시작하는 몸·기질(베딕)",
  라후: "이생에서 끌리고 과욕하는 방향",
  케투: "이미 익숙해 내려놓는 방향",
};

/** 별자리가 "어떻게"를 물들이는지 (방식/톤). */
export const SIGN_STYLE: Record<ZodiacSign, string> = {
  양자리: "직진으로·즉각·주도적으로",
  황소자리: "느긋하게·안정적으로·감각적으로",
  쌍둥이자리: "재빠르게·호기심으로·말과 정보로",
  게자리: "보살피듯·정서적으로·안으로 품어",
  사자자리: "당당하게·표현하며·중심에서",
  처녀자리: "꼼꼼하게·분석적으로·실용적으로",
  천칭자리: "조화롭게·관계 중심으로·균형을 맞춰",
  전갈자리: "깊고 강렬하게·집요하게·끝까지",
  사수자리: "크게·낙관적으로·자유롭게",
  염소자리: "현실적으로·책임지며·꾸준히",
  물병자리: "독립적으로·개성 있게·거리를 두고",
  물고기자리: "감성적으로·경계 없이·흘러가듯",
};

/** 하우스가 "어느 삶의 영역"인지. astrology.ts의 트랜짓 테마와 결이 같다. */
export const HOUSE_THEME: Record<number, string> = {
  1: "나 자신·몸·시작하는 힘",
  2: "돈·자원·자기 가치",
  3: "소통·일상·가까운 이동",
  4: "집·가족·마음의 뿌리",
  5: "표현·즐거움·연애·창작",
  6: "일상 루틴·건강·직무",
  7: "관계·파트너십·협업",
  8: "깊은 정서·공유 자원·변형",
  9: "배움·시야 확장·먼 여행",
  10: "커리어·사회적 위치·평판",
  11: "동료·커뮤니티·미래 계획",
  12: "내면·휴식·비밀·마무리",
};

/** 각도(어스펙트)의 관계 성질. */
export const ASPECT_GLOSS: Record<AstrologyAspect["aspect"], string> = {
  합: "두 기운이 한 덩어리로 섞임 — 강하지만 따로 떼기 어려움 (0°)",
  육십분: "자연스러운 협력·살릴 수 있는 재능 (60°)",
  사각: "긴장·마찰이지만 밀어붙이는 성장 동력 (90°)",
  삼분: "힘 안 들이고 흐르는 조화·타고난 재능 (120°)",
  충: "정반대로 당겨 균형·자각이 과제가 됨 (180°)",
};

/** 고전 품위(디그니티)의 힘 상태. */
export const DIGNITY_GLOSS: Record<string, string> = {
  도미사일: "제 집에 있음 — 그 기운을 편하게 제 힘으로 씀",
  엑잘테이션: "귀한 손님 자리 — 가장 좋게 발휘됨",
  디트리먼트: "불편한 자리 — 힘 쓰기가 어색하고 애씀",
  폴: "약해지는 자리 — 자신감이 떨어지기 쉬움",
  페레그린: "특별한 연고 없음 — 중립, 주변 배치에 따라감",
};

/** 27 나크샤트라의 한 줄 결. (베딕 달자리 세분) */
export const NAKSHATRA_GLOSS: Record<string, string> = {
  아슈위니: "빠른 시작·치유·개척",
  바라니: "품고 견디는 힘·변형의 관문",
  크리티카: "날카로운 정화·자르고 태우는 결단",
  로히니: "끌어당기는 매력·풍요·감각",
  므리기사라: "탐색·호기심·부드러운 추적",
  아르드라: "폭풍 뒤 정화·격변과 통찰",
  푸나르바수: "회복·되돌아옴·안전한 귀환",
  푸샤: "돌봄·자양·번영의 젖줄",
  아슐레샤: "휘감는 통찰·집중·집요함",
  마가: "권위·조상·자리와 명예",
  "푸르바 팔구니": "즐거움·관계·휴식과 향유",
  "우타라 팔구니": "약속·헌신·꾸준한 지원",
  하스타: "손재주·솜씨·구체적으로 만들어냄",
  치트라: "빛나는 설계·미적 감각·정교함",
  스와티: "독립·유연함·바람처럼 자유로움",
  비샤카: "목표 집념·성취를 향한 이중 추진",
  아누라다: "신의·협력·꾸준한 우정",
  제슈타: "책임진 연장자·보호와 통제",
  물라: "뿌리를 캐는 탐구·근본으로의 해체",
  "푸르바 아샤다": "불굴의 낙관·설득·확장",
  "우타라 아샤다": "끝을 보는 승리·지속되는 성취",
  슈라바나: "경청·배움·이어받아 전함",
  다니슈타: "리듬·부·집단 속 위치",
  샤타비샤: "치유의 비밀·고독한 통찰·경계 넘기",
  "푸르바 바드라파다": "강렬한 이상·불꽃 같은 헌신",
  "우타라 바드라파다": "깊은 안정·인내·마무리의 지혜",
  레바티: "보살핌·마무리·다음 여정으로의 배웅",
};

export interface AstrologyInterpretationHints {
  /** 각 주요 배치: "행성(기능) + 별자리(방식) + (하우스 영역)" 합성 힌트 */
  placements: string[];
  /** 성립한 각도들의 성질 힌트 */
  aspects: string[];
  /** 고전 품위가 뚜렷한 행성들의 힘 상태 */
  dignities: string[];
  /** 베딕 달 나크샤트라 결 */
  nakshatra?: string;
  /** 현재 마하다샤가 주는 시기 톤 */
  dasha?: string;
  /** 세 전통을 한 문장으로 엮는 통합 관점 지침 */
  integrationNote: string;
}

function placementHint(body: string, sign: ZodiacSign, house?: number): string {
  const role = PLANET_ROLE[body] ?? `${body}의 작용`;
  const style = SIGN_STYLE[sign] ?? "";
  const where = house ? ` · ${house}하우스(${HOUSE_THEME[house]}) 영역에서` : "";
  return `${body}: ${role}을(를) ${style} 씀${where}`;
}

/**
 * 계산된 프로파일 + 각도에 표준 상징 해석 힌트를 붙인다.
 * 실재하는 배치에만 힌트를 붙이므로, LLM이 없는 행성을 지어낼 여지를 줄인다.
 */
export function buildAstrologyInterpretationHints(
  profile: AstrologyProfile,
  aspects: AstrologyAspect[],
): AstrologyInterpretationHints {
  const placements: string[] = [];

  // 현대 5대 포인트 (있는 것만)
  const modern = profile.modern;
  const modernPoints = [modern.sun, modern.moon, modern.ascendant, modern.venus, modern.mars].filter(
    (p): p is NonNullable<typeof p> => Boolean(p),
  );
  for (const p of modernPoints) placements.push(placementHint(p.body, p.sign, p.house));

  // 고전 행성 중 현대에서 안 다룬 수·목·토
  const already = new Set(modernPoints.map((p) => p.body));
  for (const p of profile.classical.placements) {
    if (already.has(p.body)) continue;
    placements.push(placementHint(p.body, p.sign, p.house));
    already.add(p.body);
  }
  // 세대 행성(천왕·해왕·명왕): 별자리는 세대 공유라 하우스가 있을 때 특히 개인 의미가 있다.
  for (const p of profile.modern.outer) {
    if (already.has(p.body)) continue;
    placements.push(placementHint(p.body, p.sign, p.house));
    already.add(p.body);
  }

  const aspectHints = aspects.slice(0, 8).map((a) => `${a.bodyA}-${a.bodyB} ${a.aspect}(orb ${a.orb}도): ${ASPECT_GLOSS[a.aspect]}`);

  const dignities = profile.classical.placements
    .filter((p) => p.dignity === "도미사일" || p.dignity === "엑잘테이션" || p.dignity === "디트리먼트" || p.dignity === "폴")
    .map((p) => `${p.body} ${p.dignity}: ${DIGNITY_GLOSS[p.dignity]}`);

  const nak = profile.vedic.moon.nakshatra;
  const nakshatra = nak ? `달 나크샤트라 ${nak}: ${NAKSHATRA_GLOSS[nak] ?? "마음의 기본 결"}` : undefined;

  const dashaLord = profile.vedic.dasha.currentMahaDasha;
  const dasha = `현재 ${dashaLord} 마하다샤(${profile.vedic.dasha.currentMahaDashaStart}~${profile.vedic.dasha.currentMahaDashaEnd}): ${
    PLANET_ROLE[dashaLord] ?? "그 행성"
  }의 주제가 이 시기 삶에 크게 흐름`;

  const integrationNote =
    "세 전통을 각각 따로 읊지 말고 겹치는 주제를 먼저 엮으세요. 예: 현대 태양 별자리·고전 섹트/품위·베딕 달 나크샤트라가 같은 방향을 가리키면 그걸 핵심으로, 엇갈리면 '이 부분은 전통마다 결이 다르다'고 밝히세요. 시간 미상이면 상승궁·하우스 관련 힌트는 쓰지 마세요.";

  return { placements, aspects: aspectHints, dignities, nakshatra, dasha, integrationNote };
}
