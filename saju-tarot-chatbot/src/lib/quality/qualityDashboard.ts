import { ENGINE_VERSION, QUALITY_SCHEMA_VERSION, type QualityEvent } from "./qualityTypes.js";
import { computeQualityMetrics, type QualityMetrics } from "./qualityMetrics.js";
import {
  computeEngineHealth,
  explainHealthChange,
  type EngineHealth,
  type HealthChangeExplanation,
} from "./qualityHealth.js";

/**
 * Quality Dashboard view-model 조립 (순수).
 *
 * 저장소에서 읽은 QualityEvent[] → UI가 그대로 그리는 하나의 모델.
 * UI 컴포넌트는 계산을 하지 않고 이 모델만 렌더한다 (로직/뷰 분리, 확장성).
 */

export interface QualityDashboardModel {
  generatedAt: string;
  eventCount: number;
  schemaVersion: string;
  engineVersion: string;
  /** 전체 이벤트 기준 종합 Health */
  health: EngineHealth;
  /** 최근 7일 vs 그 이전 7일 Health 변화 (양쪽 데이터가 있을 때만) */
  healthTrend: HealthChangeExplanation | null;
  metrics: QualityMetrics;
}

const DAY_MS = 24 * 60 * 60 * 1000;

export interface DashboardOptions {
  now?: Date;
  /** trend 비교 창 크기(일). 기본 7 */
  trendWindowDays?: number;
}

function inWindow(events: QualityEvent[], fromMs: number, toMs: number): QualityEvent[] {
  return events.filter((e) => {
    const t = Date.parse(e.timestamp);
    return !Number.isNaN(t) && t >= fromMs && t < toMs;
  });
}

export function buildQualityDashboard(
  events: QualityEvent[],
  options: DashboardOptions = {},
): QualityDashboardModel {
  const now = options.now ?? new Date();
  const windowDays = options.trendWindowDays ?? 7;
  const metrics: QualityMetrics = computeQualityMetrics(events, now);
  const health = computeEngineHealth(events, metrics);

  // Health 추세: 최근 창 vs 직전 창
  const nowMs = now.getTime();
  const curFrom = nowMs - windowDays * DAY_MS;
  const prevFrom = nowMs - 2 * windowDays * DAY_MS;
  const currentWindow = inWindow(events, curFrom, nowMs + 1);
  const previousWindow = inWindow(events, prevFrom, curFrom);
  const healthTrend =
    currentWindow.length > 0 && previousWindow.length > 0
      ? explainHealthChange(
          computeEngineHealth(previousWindow),
          computeEngineHealth(currentWindow),
        )
      : null;

  return {
    generatedAt: now.toISOString(),
    eventCount: events.length,
    schemaVersion: QUALITY_SCHEMA_VERSION,
    engineVersion: ENGINE_VERSION,
    health,
    healthTrend,
    metrics,
  };
}
