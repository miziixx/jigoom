import { buildReadingProgress, buildReadingSectionStatuses, type ReadingSectionStatus } from "../lib/readingProgress";
import { sectionAnchor } from "./reading/readingBlocks";
import type { AnswerDepth, ReadingType } from "../types";

const STATUS_LABEL: Record<ReadingSectionStatus["status"], string> = {
  done: "읽기 ›",
  writing: "쓰는 중…",
  waiting: "대기",
};

/**
 * 리포트 진행 화면 (B-3, 재기획안 §11·시안 ③).
 *
 * "멈춘 3분"을 "읽으면서 도착"으로 재해석한다 — 섹션이 스트리밍으로 도착하는 대로 목차에서
 * ✅로 바뀌고, 클릭하면 해당 섹션(이미 화면에 그려져 있음)으로 바로 스크롤한다. 새 계산은
 * 하지 않는다 — readingProgress.ts가 이미 실시간 텍스트에서 뽑아내는 섹션 진행 정보를
 * 목차 형태로 보여주기만 한다.
 *
 * 평생사주(advanced) 전용으로 마운트한다 — 짧은 리딩은 기존 LoadingNotice 미니게임으로 충분하고,
 * 시안 ③ 자체가 "프리미엄 — 기다림의 재해석"이라 긴 유료 리포트를 겨냥한 것이기 때문.
 */
export default function ReportProgress({
  type,
  hasQuestion,
  replyText,
  depth,
  loading,
}: {
  type: ReadingType;
  hasQuestion: boolean;
  replyText: string;
  depth?: AnswerDepth;
  loading: boolean;
}) {
  const progress = buildReadingProgress(type, hasQuestion, replyText, depth);
  if (progress.total === 0) return null;

  const rawStatuses = buildReadingSectionStatuses(type, hasQuestion, replyText, depth);
  // 스트림이 완전히 끝났으면(loading=false) "쓰는 중"으로 남아있던 마지막 섹션도 완료로 본다.
  const statuses = loading ? rawStatuses : rawStatuses.map((s) => (s.status === "writing" ? { ...s, status: "done" as const } : s));
  const doneCount = statuses.filter((s) => s.status === "done").length;
  const firstDone = statuses.find((s) => s.status === "done");

  if (doneCount === statuses.length) return null; // 다 도착했으면 본문이 곧 이 자리를 대체하니 진행 화면은 접는다

  return (
    <section className="card report-progress">
      <div className="report-progress__hero">
        <span className="report-progress__emoji" aria-hidden="true">
          📜
        </span>
        <h3 className="card-title">리포트를 정성껏 뽑는 중이에요</h3>
        <p className="report-progress__desc">
          완성된 부분부터 먼저 읽을 수 있어요.
          <br />
          다 되면 알려드릴게요.
        </p>
        <div className="report-progress__track">
          <div className="report-progress__fill" style={{ width: `${progress.percent}%` }} />
        </div>
        <p className="report-progress__label">
          {statuses.length}개 섹션 중 {doneCount}개 도착
        </p>
      </div>

      <ul className="report-progress__toc">
        {statuses.map((s) => (
          <li className={`report-progress__item report-progress__item--${s.status}`} key={s.title}>
            {s.status === "done" ? (
              <a href={`#${sectionAnchor(s.title)}`}>
                <span>✅ {s.title}</span>
                <span className="report-progress__status">{STATUS_LABEL.done}</span>
              </a>
            ) : (
              <span>
                <span>{s.status === "writing" ? "✍️" : "◌"} {s.title}</span>
                <span className="report-progress__status">{STATUS_LABEL[s.status]}</span>
              </span>
            )}
          </li>
        ))}
      </ul>

      <p className="report-progress__note">
        긴 리포트는 원래 오래 걸려요 — 대신 멈춘 화면 대신
        <br />
        도착한 섹션부터 읽는 구조로 바꿉니다.
      </p>

      {firstDone && (
        <a className="btn btn--primary report-progress__cta" href={`#${sectionAnchor(firstDone.title)}`}>
          {firstDone.title}부터 읽기 시작 →
        </a>
      )}
    </section>
  );
}
