/**
 * lunar-javascript와 무관한 독립 간지 검산 (일주·시주).
 *
 * 앱 엔진(`computeSajuChart`)은 lunar-javascript로 일주/시주를 뽑는다.
 * 이 모듈은 완전히 다른 방식 — JDN 60갑자 순환 + 五鼠遁 시두법 — 으로 같은 값을 재계산해,
 * 엔진이 라이브러리와 함께 조용히 틀어지는 것을 잡는다. 외부 만세력 웹사이트가 세션
 * 네트워크 정책으로 차단됐을 때의 보조 검증이기도 하다.
 * (연·월주는 절기 태양황경이 필요해 여기서 다루지 않고 외부 웹 대조로 남긴다.)
 */

const GAN = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"];
const ZHI = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"];

function ganzhi(index: number): string {
  const i = ((index % 60) + 60) % 60;
  return GAN[i % 10] + ZHI[i % 12];
}

/** 그레고리력 → 정오 기준 JDN (정수). */
export function gregorianToJDN(y: number, m: number, d: number): number {
  const a = Math.floor((14 - m) / 12);
  const yy = y + 4800 - a;
  const mm = m + 12 * a - 3;
  return (
    d +
    Math.floor((153 * mm + 2) / 5) +
    365 * yy +
    Math.floor(yy / 4) -
    Math.floor(yy / 100) +
    Math.floor(yy / 400) -
    32045
  );
}

// 앵커: 1990-12-23(양력) = 임술일(壬戌, index 58).
// 외부 만세력 3곳(coldcow·goodcycle·사주매니아)이 교차 확인한 값이라 독립 앵커로 신뢰할 수 있다.
// (docs/validation/external-manse-comparison.md 케이스 1)
const ANCHOR_JDN = gregorianToJDN(1990, 12, 23);
const ANCHOR_INDEX = 58;

/**
 * 일주 간지. `y/m/d`는 자시 처리를 반영한 '일주 귀속 양력일'을 넘긴다.
 * (야자시=당일, 조자시=익일. 음력 입력은 양력 변환일을 넘긴다.)
 */
export function independentDayPillar(y: number, m: number, d: number): string {
  return ganzhi(gregorianToJDN(y, m, d) - ANCHOR_JDN + ANCHOR_INDEX);
}

/**
 * 시주 간지 (五鼠遁). `dayGan`은 시주 계산에 쓰는 일간 —
 * 야자시일 때는 일주 천간이 아니라 '익일 자시 천간 기준 일간'을 넘긴다.
 * `hour`는 진태양시/서머타임 보정 후의 지역시(0~23).
 */
export function independentHourPillar(dayGan: string, hour: number): string {
  const branchIdx = Math.floor(((hour + 1) % 24) / 2); // 0=자시(23~0시)
  // 자시 천간: 甲己→갑, 乙庚→병, 丙辛→무, 丁壬→경, 戊癸→임
  const ziStemByDay: Record<string, number> = {
    갑: 0, 기: 0, 을: 2, 경: 2, 병: 4, 신: 4, 정: 6, 임: 6, 무: 8, 계: 8,
  };
  const stemIdx = (ziStemByDay[dayGan] + branchIdx) % 10;
  return GAN[stemIdx] + ZHI[branchIdx];
}
