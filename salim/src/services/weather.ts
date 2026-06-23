import type { WeatherTag } from "../types";

// 날씨 연동 (선택, 온라인) — 키 없는 Open-Meteo 사용 (6-2).
// 위치 권한 거부·오프라인·실패 시 빈 배열 → 호출부에서 계절(오프라인) 규칙으로 폴백.

export interface WeatherSuggestion {
  text: string;
  tag?: WeatherTag;
}

interface OpenMeteoResponse {
  current?: {
    temperature_2m?: number;
    relative_humidity_2m?: number;
    weather_code?: number;
  };
  daily?: { precipitation_probability_max?: number[] };
}

function getPosition(): Promise<GeolocationPosition | null> {
  return new Promise((resolve) => {
    if (!("geolocation" in navigator)) return resolve(null);
    navigator.geolocation.getCurrentPosition(
      (p) => resolve(p),
      () => resolve(null),
      { timeout: 8000, maximumAge: 3_600_000 },
    );
  });
}

export async function fetchWeatherSuggestions(): Promise<WeatherSuggestion[]> {
  try {
    const pos = await getPosition();
    if (!pos) return [];
    const { latitude, longitude } = pos.coords;
    const url =
      `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}` +
      `&current=temperature_2m,relative_humidity_2m,weather_code` +
      `&daily=precipitation_probability_max&timezone=auto&forecast_days=1`;
    const res = await fetch(url);
    if (!res.ok) return [];
    const data: OpenMeteoResponse = await res.json();
    const cur = data.current;
    if (!cur) return [];

    const humid = cur.relative_humidity_2m ?? 50;
    const code = cur.weather_code ?? 0;
    const rainProb = data.daily?.precipitation_probability_max?.[0] ?? 0;
    const out: WeatherSuggestion[] = [];

    if (code <= 2 && humid < 60 && rainProb < 30) {
      out.push({ text: "맑고 건조해요 — 빨래·이불 널기 좋은 날.", tag: "sunny" });
    }
    if (rainProb >= 60) {
      out.push({ text: "비 소식이 있어요 — 우산 챙기고 환기는 미뤄요.", tag: "rainy" });
    }
    if (humid >= 78) {
      out.push({ text: "습도가 높아요 — 곰팡이·환기를 신경 써요.", tag: "rainy" });
    }
    return out;
  } catch {
    return [];
  }
}

// 날씨 태그 → 대표 집안일 이름 (오늘 할 일로 끌어올리기용)
export function weatherChore(tag?: WeatherTag): string | undefined {
  if (tag === "sunny") return "빨래 널기·개기";
  if (tag === "rainy") return "곰팡이 점검·제거";
  if (tag === "dusty") return "공기청정기 필터 점검";
  return undefined;
}
