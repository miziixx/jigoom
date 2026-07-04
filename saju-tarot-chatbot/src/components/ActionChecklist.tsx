import { useState } from "react";
import { buildLifestyleGuide } from "../lib/lifestyleGuide";
import type { LuckCycles, SajuChart } from "../types";

interface ChecklistGroup {
  title: string;
  items: string[];
}

/**
 * 실행 체크리스트: 오늘 / 이번 주 / 피할 패턴을 체크박스로.
 * 계산된 생활 처방(todayActions·playfulActions·workStyle·caution)을 형태만 체크리스트로 바꾼다.
 * 체크 상태는 로컬(만족감용, 저장 불필요).
 */
export default function ActionChecklist({
  sajuChart,
  luckCycles,
}: {
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
}) {
  const [checked, setChecked] = useState<Record<string, boolean>>({});
  if (!sajuChart) return null;
  const guide = buildLifestyleGuide(sajuChart, { todayGanZhi: luckCycles?.dayGanZhi });

  const groups: ChecklistGroup[] = [
    { title: "오늘", items: guide.todayActions.slice(0, 3) },
    { title: "이번 주", items: [...guide.playfulActions, ...guide.recovery].slice(0, 3) },
    { title: "피할 패턴", items: [guide.caution].filter(Boolean) },
  ].filter((g) => g.items.length > 0);

  if (groups.length === 0) return null;

  return (
    <section className="card action-checklist">
      <div className="section-heading-row">
        <h3 className="card-title">실행 가이드 체크리스트</h3>
        <span className="feature-badge">바로 실천</span>
      </div>
      <p className="action-checklist__intro">좋은 말에서 끝나지 않게, 오늘·이번 주 할 것과 피할 패턴으로 정리했어요.</p>
      <div className="action-checklist__groups">
        {groups.map((group) => (
          <div className="action-checklist__group" key={group.title}>
            <b className="action-checklist__group-title">{group.title}</b>
            <ul>
              {group.items.map((item, i) => {
                const id = `${group.title}-${i}`;
                return (
                  <li key={id}>
                    <label className={checked[id] ? "action-checklist__item action-checklist__item--done" : "action-checklist__item"}>
                      <input
                        type="checkbox"
                        checked={!!checked[id]}
                        onChange={() => setChecked((prev) => ({ ...prev, [id]: !prev[id] }))}
                      />
                      <span>{item}</span>
                    </label>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </div>
    </section>
  );
}
