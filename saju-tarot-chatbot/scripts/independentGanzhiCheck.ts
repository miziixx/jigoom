/**
 * lunar-javascript와 무관한 독립 간지 검산기.
 *
 * 목적: 앱 엔진(lunar-javascript 기반)의 일주·시주가, 완전히 다른
 * 알고리즘(JDN 60갑자 + 五鼠遁 시두법)으로 계산해도 같은 값이 나오는지 확인한다.
 * 외부 만세력 웹사이트가 세션 네트워크 정책으로 차단된 상황의 보조 검증이다.
 *
 * 일주: 그레고리력 civil date의 율리우스적일(JDN)을 60으로 나눈 나머지.
 *   - 앵커: 1990-12-23(양력) = 임술일(壬戌, 60갑자 index 58).
 *     이 값은 외부 만세력 3곳(coldcow·goodcycle·사주매니아)이 교차 확인한 값이라
 *     (docs/validation/external-manse-comparison.md 케이스 1) 독립 앵커로 신뢰할 수 있다.
 *   - dayIndex = ((JDN - JDN(1990-12-23)) + 58) mod 60, 0 = 갑자.
 * 시주: 일간(日干)으로 五鼠遁 → 자시 천간을 잡고 시지 순서대로. (완전 결정론적 규칙)
 */

const GAN = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"];
const ZHI = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"];

function ganzhi(index: number): string {
  const i = ((index % 60) + 60) % 60;
  return GAN[i % 10] + ZHI[i % 12];
}

/** 그레고리력 → 정오 기준 JDN (정수). */
function gregorianToJDN(y: number, m: number, d: number): number {
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

const ANCHOR_JDN = gregorianToJDN(1990, 12, 23); // 임술일(index 58), 외부 3곳 교차확인
const ANCHOR_INDEX = 58;

/** 양력 civil date의 일주 (자시 처리 적용 후의 '일주 귀속일'을 넘겨야 함). */
export function dayPillar(y: number, m: number, d: number): string {
  const idx = gregorianToJDN(y, m, d) - ANCHOR_JDN + ANCHOR_INDEX;
  return ganzhi(idx);
}

/** 五鼠遁: 일간으로 시주 간지. hour = 0~23 (보정 후 지역시). */
export function hourPillar(dayGan: string, hour: number): string {
  // 시지: 23~0시=자, 1~2=축, ... 2시간 단위. 23시는 자시.
  const branchIdx = Math.floor(((hour + 1) % 24) / 2); // 0=자
  // 자시 천간: 甲己→갑, 乙庚→병, 丙辛→무, 丁壬→경, 戊癸→임
  const ziStemByDay: Record<string, number> = {
    갑: 0, 기: 0, 을: 2, 경: 2, 병: 4, 신: 4, 정: 6, 임: 6, 무: 8, 계: 8,
  };
  const ziStem = ziStemByDay[dayGan];
  const stemIdx = (ziStem + branchIdx) % 10;
  return GAN[stemIdx] + ZHI[branchIdx];
}

// --- 앱 엔진 결과와 대조 (일주·시주만; 연·월주는 절기 astronomy 필요해 웹 대조로 남김) ---
type Row = {
  name: string;
  // 일주 귀속일(자시 처리 반영한 civil date)
  dY: number; dM: number; dD: number;
  dayGan: string;
  // 보정 후 지역시 (서머타임/경도 보정 반영)
  corrHour: number | null;
  appDay: string;
  appHour: string;
};

const rows: Row[] = [
  { name: "1. 1990-12-23 08:00", dY: 1990, dM: 12, dD: 23, dayGan: "임", corrHour: 8, appDay: "임술", appHour: "갑진" },
  { name: "2. 1984-02-05 02:00", dY: 1984, dM: 2, dD: 5, dayGan: "기", corrHour: 2, appDay: "기사", appHour: "을축" },
  { name: "3. 음 1987-6-15 → 양 1987-07-10 11:00(보정)", dY: 1987, dM: 7, dD: 10, dayGan: "경", corrHour: 11, appDay: "경신", appHour: "임오" },
  { name: "4. 음 윤6-15 → 양 1987-08-09 11:00(보정)", dY: 1987, dM: 8, dD: 9, dayGan: "경", corrHour: 11, appDay: "경인", appHour: "임오" },
  // 야자시: 일주는 당일(무오) 유지, 시주는 익일 자시 천간(기 일간 기준) → 五鼠遁 갑자. dayGan은 시주 계산용이라 기.
  { name: "5. 2000-01-01 23:30 야자시(일주 당일/시주 익일)", dY: 2000, dM: 1, dD: 1, dayGan: "기", corrHour: 23, appDay: "무오", appHour: "갑자" },
  { name: "6. 2000-01-01 23:30 조자시(익일)", dY: 2000, dM: 1, dD: 2, dayGan: "기", corrHour: 23, appDay: "기미", appHour: "갑자" },
  { name: "7. 1988-06-01 → 보정 10:28", dY: 1988, dM: 6, dD: 1, dayGan: "정", corrHour: 10, appDay: "정해", appHour: "을사" },
];

let allOk = true;
for (const r of rows) {
  const indDay = dayPillar(r.dY, r.dM, r.dD);
  const indHour = r.corrHour === null ? "-" : hourPillar(r.dayGan, r.corrHour);
  const dayOk = indDay === r.appDay;
  const hourOk = indHour === r.appHour;
  if (!dayOk || !hourOk) allOk = false;
  console.log(`\n### ${r.name}`);
  console.log(`  일주  독립=${indDay}  앱=${r.appDay}  ${dayOk ? "일치 ✅" : "불일치 ❌"}`);
  console.log(`  시주  독립=${indHour}  앱=${r.appHour}  ${hourOk ? "일치 ✅" : "불일치 ❌"}`);
}
console.log(`\n=== 독립 검산 종합: ${allOk ? "전부 일치 ✅" : "불일치 있음 ❌"} ===`);
