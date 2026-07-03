import type { ReadingContext } from "../types";

const DEPTH_ETA: Record<NonNullable<ReadingContext["depth"]>, string> = {
  light: "핵심만 먼저 정리하는 모드예요. 보통 금방 첫 문장이 떠요.",
  basic: "전체 흐름을 압축해서 쓰는 중이에요. 보통 10~20초 정도 걸려요.",
  advanced: "근거와 행동 조언을 함께 엮는 중이에요. 30~60초 정도 걸릴 수 있어요.",
  expert: "가장 자세한 리딩이라 1~2분 정도 걸릴 수 있어요. 먼저 뜨는 내용부터 읽어도 괜찮아요.",
};

const STEPS = ["사주 계산 완료", "핵심 흐름 정리", "현실 조언 작성"];

/** 계산은 이미 끝났고 AI가 문장을 만드는 동안 보여주는 안내. depth를 알면 예상 소요시간을 함께 보여준다. */
export default function LoadingNotice({ depth }: { depth?: ReadingContext["depth"] }) {
  return (
    <div className="loading-notice">
      <div className="loading-notice__head">
        <span className="loading-notice__spinner" aria-hidden="true" />
        <span>계산은 끝났고, 풀이를 쓰고 있어요. {depth ? DEPTH_ETA[depth] : "곧 첫 점괘부터 뜨기 시작해요."}</span>
      </div>
      <div className="loading-steps" aria-label="리딩 생성 단계">
        {STEPS.map((step, i) => (
          <span className={`loading-step${i === STEPS.length - 1 ? " loading-step--active" : ""}`} key={step}>
            {step}
          </span>
        ))}
      </div>
    </div>
  );
}
