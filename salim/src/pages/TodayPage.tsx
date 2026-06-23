import { useMemo, useState } from "react";
import { useStore } from "../store/useStore";
import PlantGauge from "../components/PlantGauge";
import TipCard from "../components/TipCard";
import { houseScore } from "../lib/condition";
import { isDue } from "../lib/chores";
import { isRunningLow, avgGapDays } from "../lib/predict";
import { seasonTips } from "../data/seasonTips";
import { todayStr, shortKor } from "../lib/date";
import { EFFORT_LABEL, CYCLE } from "../data/cycles";
import type { Chore, Effort } from "../types";

type TimeFilter = "all" | "15" | "30";
type EnergyFilter = "all" | "normal" | "easy";

function passTime(c: Chore, f: TimeFilter): boolean {
  if (f === "all") return true;
  if (f === "15") return c.durationMin <= 15;
  return c.durationMin <= 30;
}
function passEnergy(c: Chore, f: EnergyFilter): boolean {
  if (f === "all") return true;
  if (f === "normal") return c.effort !== "heavy";
  return c.effort === "easy";
}

const EFFORT_RANK: Record<Effort, number> = { easy: 0, normal: 1, heavy: 2 };

export default function TodayPage() {
  const chores = useStore((s) => s.chores);
  const completeChore = useStore((s) => s.completeChore);
  const addChoreByName = useStore((s) => s.addChoreByName);

  const [time, setTime] = useState<TimeFilter>("all");
  const [energy, setEnergy] = useState<EnergyFilter>("all");
  const [pinned, setPinned] = useState<Set<string>>(new Set()); // 계절 제안으로 끌어올린 이름

  const score = useMemo(() => houseScore(chores), [chores]);
  const tips = useMemo(() => seasonTips(), []);

  const todays = useMemo(() => {
    return chores
      .filter((c) => isDue(c) || pinned.has(c.name))
      .filter((c) => passTime(c, time) && passEnergy(c, energy))
      .sort((a, b) => EFFORT_RANK[a.effort] - EFFORT_RANK[b.effort] || a.durationMin - b.durationMin);
  }, [chores, time, energy, pinned]);

  const pullToToday = (name: string) => {
    addChoreByName(name); // 내 집안일에 없으면 추가
    setPinned((prev) => new Set(prev).add(name));
  };

  return (
    <div className="page">
      {/* 1-5/1-6: 집 컨디션 히어로 */}
      <section className="hero card">
        <PlantGauge score={score} />
        <div className="gauge-bar">
          <div className="gauge-fill" style={{ width: `${score}%` }} />
        </div>
      </section>

      {/* 2-2: 날씨/계절 제안 배너 */}
      {tips.length > 0 && (
        <section className="banner">
          {tips.map((t) => (
            <div key={t.text} className="banner-row">
              <span>🌤 {t.text}</span>
              {t.chore && (
                <button className="link-btn" onClick={() => pullToToday(t.chore!)}>
                  오늘 할 일로
                </button>
              )}
            </div>
          ))}
        </section>
      )}

      {/* 2-1: 시간·기운 필터 */}
      <section className="filters">
        <div className="chip-row">
          <span className="chip-label">시간</span>
          {(["all", "30", "15"] as TimeFilter[]).map((f) => (
            <button key={f} className={`chip ${time === f ? "chip-on" : ""}`} onClick={() => setTime(f)}>
              {f === "all" ? "넉넉" : `${f}분`}
            </button>
          ))}
        </div>
        <div className="chip-row">
          <span className="chip-label">기운</span>
          {(["all", "normal", "easy"] as EnergyFilter[]).map((f) => (
            <button key={f} className={`chip ${energy === f ? "chip-on" : ""}`} onClick={() => setEnergy(f)}>
              {f === "all" ? "쌩쌩" : f === "normal" ? "보통" : "방전"}
            </button>
          ))}
        </div>
      </section>

      {/* 1-4: 오늘 할 일 */}
      <section>
        <h2 className="sec-title">오늘 할 일</h2>
        {chores.length === 0 ? (
          <div className="empty">
            <p>아직 담은 집안일이 없어요.</p>
            <p className="dim">'집안일' 탭에서 우리 집 집안일을 골라 담아보세요.</p>
          </div>
        ) : todays.length === 0 ? (
          <div className="empty">
            <p>지금 할 차례인 일이 없어요 👏</p>
            <p className="dim">필터를 바꾸거나 푹 쉬어도 좋아요.</p>
          </div>
        ) : (
          <ul className="list">
            {todays.map((c) => (
              <li key={c.id} className="card chore due">
                <div className="chore-row">
                  <button className="check" onClick={() => completeChore(c.id)} aria-label="완료">
                    ○
                  </button>
                  <div className="chore-main">
                    <div className="chore-name">{c.name}</div>
                    <div className="chore-sub dim">
                      {CYCLE[c.cycle].label} · {c.durationMin}분 · {EFFORT_LABEL[c.effort]}
                    </div>
                  </div>
                </div>
                <TipCard tip={c.tip} howtoId={c.howtoId} />
              </li>
            ))}
          </ul>
        )}
      </section>

      {/* 4-5: 곧 떨어져요 요약 */}
      <RunningLowSummary />

      {/* 2-3 / 2-4: 일지 */}
      <Journal />
    </div>
  );
}

function RunningLowSummary() {
  const inventory = useStore((s) => s.inventory);
  const low = inventory.filter((it) => isRunningLow(it));
  if (low.length === 0) return null;
  return (
    <section>
      <h2 className="sec-title">곧 떨어져요</h2>
      <ul className="list">
        {low.map((it) => {
          const gap = avgGapDays(it);
          return (
            <li key={it.id} className="card mini">
              <span>{it.name}</span>
              <span className="dim">
                {it.qty <= it.threshold ? "재고 부족" : gap ? `보통 ${gap}일 주기` : "곧 소진"}
              </span>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

function Journal() {
  const logs = useStore((s) => s.logs);
  const [showPast, setShowPast] = useState(false);
  const today = todayStr();
  const todayLogs = logs.filter((l) => l.date === today);
  const pastLogs = logs.filter((l) => l.date !== today);

  const grouped = useMemo(() => {
    const map = new Map<string, typeof pastLogs>();
    for (const l of pastLogs) {
      const arr = map.get(l.date) ?? [];
      arr.push(l);
      map.set(l.date, arr);
    }
    return Array.from(map.entries());
  }, [pastLogs]);

  return (
    <section>
      <h2 className="sec-title">오늘의 일지</h2>
      {todayLogs.length === 0 ? (
        <p className="dim small">오늘 기록이 아직 없어요. 하나 끝내면 여기 쌓여요.</p>
      ) : (
        <ul className="timeline">
          {todayLogs.map((l) => (
            <li key={l.id} className="tl-row">
              <span className="tl-dot" />
              <span>{l.label}</span>
            </li>
          ))}
        </ul>
      )}

      {pastLogs.length > 0 && (
        <button className="link-btn" onClick={() => setShowPast((v) => !v)}>
          {showPast ? "지난 기록 접기" : "지난 기록 보기"}
        </button>
      )}
      {showPast &&
        grouped.map(([date, items]) => (
          <div key={date} className="past-group">
            <div className="past-date dim">{shortKor(date)}</div>
            <ul className="timeline">
              {items.map((l) => (
                <li key={l.id} className="tl-row">
                  <span className="tl-dot" />
                  <span>{l.label}</span>
                </li>
              ))}
            </ul>
          </div>
        ))}
    </section>
  );
}
