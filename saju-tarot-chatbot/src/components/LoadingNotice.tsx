import type { ReadingContext } from "../types";

const DEPTH_ETA: Record<NonNullable<ReadingContext["depth"]>, string> = {
  light: "보통 몇 초 안에 끝나요.",
  basic: "보통 10~20초 정도 걸려요.",
  advanced: "내용이 많아 30~60초 정도 걸릴 수 있어요.",
  expert: "가장 자세한 리딩이라 1~2분 정도 걸릴 수 있어요. 화면을 켠 채로 잠시만 기다려주세요.",
};

/** 계산은 이미 끝났고 AI가 문장을 만드는 동안 보여주는 안내. depth를 알면 예상 소요시간을 함께 보여준다. */
export default function LoadingNotice({ depth }: { depth?: ReadingContext["depth"] }) {
  return (
    <div className="loading-notice">
      <span className="loading-notice__spinner" aria-hidden="true" />
      <span>사주 계산을 마치고 해석을 쓰고 있어요. {depth ? DEPTH_ETA[depth] : "잠시만 기다려주세요."}</span>
    </div>
  );
}
