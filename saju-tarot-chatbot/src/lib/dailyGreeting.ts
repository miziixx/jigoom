import { Solar } from "lunar-javascript";
import { ganzhiForKstDate, kstDateOf } from "./fortune.js";

/**
 * lunar-javascript는 절기 이름을 한자로만 반환한다(라이브러리 내 한글 로케일 없음,
 * node_modules/lunar-javascript/lunar.js의 I18n 메시지 테이블에 'jq.xiaoShu': '小暑'(중국어
 * 기본)/'Lesser Heat'(영어)만 존재, 한글 키 없음 확인됨). 24절기 한자→한글 변환표로 보완한다.
 */
const SOLAR_TERM_KO: Record<string, string> = {
  小寒: "소한", 大寒: "대한", 立春: "입춘", 雨水: "우수", 驚蟄: "경칩", 春分: "춘분",
  清明: "청명", 穀雨: "곡우", 立夏: "입하", 小滿: "소만", 芒種: "망종", 夏至: "하지",
  小暑: "소서", 大暑: "대서", 立秋: "입추", 處暑: "처서", 白露: "백로", 秋分: "추분",
  寒露: "한로", 霜降: "상강", 立冬: "입동", 小雪: "소설", 大雪: "대설", 冬至: "동지",
};

/**
 * 홈 카드 개편(재기획안 §5)용 오늘 인사말 — 출생정보 없이 "오늘 날짜만"으로 계산한다.
 * §5: "첫인사는 일진·절기 계산으로 매일 자동 생성 — 첫 문장부터 '진짜 계산' 증명."
 * 접수처식 멘트("무슨 일로 왔어요?") 금지(운영자 반려 이력, 기획안 §5) — 계산된 사실을 짧게 건넨다.
 */
export interface DailyGreeting {
  /** "7월 9일 목요일" */
  dateLabel: string;
  /** 오늘의 일진 간지(한글), 예: "병오" */
  dayGanZhi: string;
  /** 지금 절기 이름, 예: "소서" */
  solarTerm: string;
  /** "7월 9일 목요일 · 병오일 · 소서 무렵" */
  headline: string;
}

export function buildDailyGreeting(now: Date = new Date()): DailyGreeting {
  const kst = kstDateOf(now);
  const ganzhi = ganzhiForKstDate(kst);
  const solar = Solar.fromYmdHms(kst.year, kst.month, kst.day, 12, 0, 0);
  const lunar = solar.getLunar();
  const rawSolarTerm = lunar.getPrevJieQi(true).getName();
  const solarTerm = SOLAR_TERM_KO[rawSolarTerm] ?? rawSolarTerm;

  const dateLabel = `${kst.month}월 ${kst.day}일 ${kst.weekday}요일`;
  return {
    dateLabel,
    dayGanZhi: ganzhi.day,
    solarTerm,
    headline: `${dateLabel} · ${ganzhi.day}일 · ${solarTerm} 무렵`,
  };
}
