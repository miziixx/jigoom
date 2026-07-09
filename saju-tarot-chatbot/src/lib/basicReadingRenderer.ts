import type { EventForecast, Gender, LuckCycles, SajuChart, TopicDeepTopic } from "../types/index.js";
import { buildInstantSummary, type InstantSummary } from "./instantSummary.js";
import { buildPsychLayer, type PsychLayer } from "./psychLayer.js";
import { buildEventForecast } from "./eventEngine.js";
import { describeMonthFlow } from "./monthFlowNarrative.js";
import { buildLifestyleGuide, type LifestyleGuide } from "./lifestyleGuide.js";

/**
 * 무료 "기본 리딩" 룰 렌더러 (재기획안 §3 3층 · §8 무료 기본 리딩 7블록).
 *
 * 이미 계산돼 있는 값(SajuChart/LuckCycles)만으로, API 호출 없이 즉시(3초 내 목표) 조립한다.
 * "판단 없는 범용 문장 = NO" 기준(§3)을 만족하기 위해 이 렌더러는 실제 판단 로직(instantSummary·
 * psychLayer·eventEngine·monthFlowNarrative·lifestyleGuide)을 새로 만들지 않고 재배치만 한다 —
 * 이 다섯 엔진은 이미 골든 테스트로 검증된 계산·판단 층이다.
 *
 * 블록 1(소름 검증)은 C-1에서 구현됐지만, saju.ts 호출(computePastYearRawSignals)이 필요해
 * 이 가벼운 렌더러(saju.ts 비의존 원칙) 안에는 넣지 않았다 — `GoosebumpCheck.tsx` 컴포넌트가
 * 별도로 이 블록을 담당하고, `DefaultReadingTemplate.tsx`에서 이 렌더러보다 먼저(블록 1 자리에)
 * 마운트된다. 그래서 gooseBumpCheck는 이 구조체 안에서는 항상 null로 남는다.
 */

/** types/index.ts의 TopicDeepTopic과 동일 — A-2(토픽 심화 파이프라인)의 analysisMode="topicDeep" topic과 맞춘다. */
export type BasicReadingTopic = TopicDeepTopic;

/** 블록 7 "이 부분 깊게 보기" — 각 블록이 어느 유료 토픽 심화로 이어지는지. */
export interface DeepDiveCta {
  label: string;
  topic: BasicReadingTopic;
}

export interface BasicReadingBlock<T> {
  key: string;
  title: string;
  data: T;
  deepDiveCta: DeepDiveCta | null;
}

export interface YearFlowMonth {
  month: number;
  ganZhi: string;
  label: string;
  detail: string;
  level: 0 | 1 | 2 | 3;
}

export interface BasicReading {
  generatedAt: string;
  /** 블록 1: 소름 검증 — C-1 착수 전까지 항상 null. */
  gooseBumpCheck: null;
  /** 블록 2: 원국 스냅샷 + 일간 한 줄 */
  snapshot: BasicReadingBlock<InstantSummary> | null;
  /** 블록 3: 내 사용 설명서 */
  userManual: BasicReadingBlock<PsychLayer> | null;
  /** 블록 4: 분야별 현재 신호 */
  domainSignals: BasicReadingBlock<EventForecast> | null;
  /** 블록 5: 올해 흐름 미니 캘린더 */
  yearFlow: BasicReadingBlock<YearFlowMonth[]> | null;
  /** 블록 6: 생활 처방 */
  lifestyle: BasicReadingBlock<LifestyleGuide> | null;
}

export interface BasicReadingInput {
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  gender?: Gender;
}

function buildYearFlow(luckCycles?: LuckCycles): YearFlowMonth[] {
  const months = luckCycles?.monthlyFlow ?? [];
  return months.map((mf) => {
    const { label, detail, level } = describeMonthFlow(mf);
    return { month: mf.month, ganZhi: mf.ganZhi, label, detail, level };
  });
}

export function buildBasicReading(input: BasicReadingInput): BasicReading {
  const { sajuChart, luckCycles, gender } = input;
  const todayGanZhi = luckCycles?.dayGanZhi;

  const snapshot = buildInstantSummary(sajuChart, luckCycles);
  const userManual = buildPsychLayer(sajuChart);
  const domainSignals = buildEventForecast(sajuChart, luckCycles, gender);
  const yearFlow = buildYearFlow(luckCycles);
  const lifestyle = sajuChart ? buildLifestyleGuide(sajuChart, { todayGanZhi }) : null;

  return {
    generatedAt: new Date().toISOString(),
    gooseBumpCheck: null,
    snapshot: snapshot
      ? { key: "snapshot", title: "원국 스냅샷", data: snapshot, deepDiveCta: null }
      : null,
    userManual: userManual
      ? {
          key: "userManual",
          title: "내 사용 설명서",
          data: userManual,
          deepDiveCta: { label: "성격·관계 더 깊게 보기", topic: "love" },
        }
      : null,
    domainSignals: domainSignals
      ? {
          key: "domainSignals",
          title: "분야별 지금 신호",
          data: domainSignals,
          deepDiveCta: { label: "가장 움직이는 분야 깊게 보기", topic: domainSignals.activeDomains[0] === "money" ? "money" : "career" },
        }
      : null,
    yearFlow:
      yearFlow.length > 0
        ? {
            key: "yearFlow",
            title: "올해 흐름 미니 캘린더",
            data: yearFlow,
            deepDiveCta: { label: "올해운 자세히 보기", topic: "year" },
          }
        : null,
    lifestyle: lifestyle
      ? { key: "lifestyle", title: "생활 처방", data: lifestyle, deepDiveCta: { label: "건강운 자세히 보기", topic: "health" } }
      : null,
  };
}

/** 조립된 블록 중 실제로 채워진 것만 순서대로 (UI가 순회하기 쉽게). */
export function basicReadingBlocks(reading: BasicReading): BasicReadingBlock<unknown>[] {
  const blocks: (BasicReadingBlock<unknown> | null)[] = [
    reading.snapshot,
    reading.userManual,
    reading.domainSignals,
    reading.yearFlow,
    reading.lifestyle,
  ];
  return blocks.filter((b): b is BasicReadingBlock<unknown> => b !== null);
}
