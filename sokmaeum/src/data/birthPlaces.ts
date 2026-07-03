// 출생지별 대표 경도 (진태양시 보정용)
export const BIRTH_PLACES: Record<string, { label: string; longitude: number }> = {
  seoul: { label: "서울/경기/인천", longitude: 126.98 },
  gangwon: { label: "강원", longitude: 127.73 },
  daejeon: { label: "대전/세종/충청", longitude: 127.38 },
  jeonbuk: { label: "전북", longitude: 127.15 },
  gwangju: { label: "광주/전남", longitude: 126.85 },
  daegu: { label: "대구/경북", longitude: 128.6 },
  busan: { label: "부산/울산/경남", longitude: 129.08 },
  jeju: { label: "제주", longitude: 126.53 },
};
