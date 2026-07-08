declare module "lunar-javascript" {
  export class DaYun {
    getStartAge(): number;
    getEndAge(): number;
    getStartYear(): number;
    getEndYear(): number;
    getGanZhi(): string;
  }

  export class Yun {
    getDaYun(): DaYun[];
  }

  export class EightChar {
    getYear(): string;
    getMonth(): string;
    getDay(): string;
    getTime(): string;
    getYearShiShenGan(): string;
    getMonthShiShenGan(): string;
    getDayShiShenGan(): string;
    getTimeShiShenGan(): string;
    getYearShiShenZhi(): string[];
    getMonthShiShenZhi(): string[];
    getDayShiShenZhi(): string[];
    getTimeShiShenZhi(): string[];
    /** gender: 1=남성, 0=여성 */
    getYun(gender: number): Yun;
  }

  export class JieQi {
    getName(): string;
    getSolar(): Solar;
  }

  export class Lunar {
    static fromYmdHms(
      year: number,
      month: number,
      day: number,
      hour: number,
      minute: number,
      second: number,
    ): Lunar;
    getEightChar(): EightChar;
    getYearInGanZhi(): string;
    getYearInGanZhiByLiChun(): string;
    getMonthInGanZhi(): string;
    getDayInGanZhi(): string;
    getSolar(): Solar;
    /** 직전 절(節): 현재 월주가 시작된 절입. 월률분야(사령) 경과일 계산에 쓴다. */
    getPrevJie(): JieQi;
    getNextJie(): JieQi;
  }

  export class Solar {
    static fromYmdHms(
      year: number,
      month: number,
      day: number,
      hour: number,
      minute: number,
      second: number,
    ): Solar;
    static fromDate(date: Date): Solar;
    getLunar(): Lunar;
    getYear(): number;
    getMonth(): number;
    getDay(): number;
    getHour(): number;
    getMinute(): number;
    getJulianDay(): number;
  }
}
