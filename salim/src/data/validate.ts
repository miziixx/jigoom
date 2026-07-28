import { CHORE_TEMPLATES } from "./choreTemplates";
import { HOWTOS } from "./howtos";

// 개발 중에만 호출되는 데이터 무결성 검사.
// 집안일(choreTemplates)과 살림백과(howtos)는 'howtoId'·'relatedChores 이름'
// 같은 문자열로 연결돼 있어, 오타·이름 변경 시 링크가 조용히 끊긴다.
// 빌드 타임 타입 검사로는 못 잡으므로 여기서 런타임(dev) 경고로 방어한다.
export function validateLinks(): string[] {
  const problems: string[] = [];
  const howtoIds = new Set(HOWTOS.map((h) => h.id));
  const choreNames = new Set(CHORE_TEMPLATES.map((c) => c.name));

  // 1) 집안일의 howtoId가 실제 백과 항목을 가리키는지
  for (const c of CHORE_TEMPLATES) {
    if (c.howtoId && !howtoIds.has(c.howtoId)) {
      problems.push(`집안일 "${c.name}" → howtoId "${c.howtoId}" 가 살림백과에 없음`);
    }
  }

  // 2) 백과의 relatedChores 이름이 실제 집안일 마스터에 있는지
  for (const h of HOWTOS) {
    for (const name of h.relatedChores ?? []) {
      if (!choreNames.has(name)) {
        problems.push(`살림백과 "${h.id}" → relatedChores "${name}" 가 집안일 마스터에 없음`);
      }
    }
  }

  // 3) 백과 항목 ID 중복
  const seen = new Set<string>();
  for (const h of HOWTOS) {
    if (seen.has(h.id)) problems.push(`살림백과 중복 ID: "${h.id}"`);
    seen.add(h.id);
  }

  // 4) 집안일 이름 중복 (담기 시 이름으로 매칭하므로 중복은 혼란을 부름)
  const seenChore = new Set<string>();
  for (const c of CHORE_TEMPLATES) {
    if (seenChore.has(c.name)) problems.push(`집안일 마스터 중복 이름: "${c.name}"`);
    seenChore.add(c.name);
  }

  return problems;
}
