// 출생지별 대표 좌표 (사주 진태양시 보정은 경도만, 점성술 하우스/상승궁은 위도·경도 사용)
export const BIRTH_PLACES: Record<string, { label: string; longitude: number; latitude: number }> = {
  seoul: { label: "서울/경기/인천", longitude: 126.98, latitude: 37.56 },
  gangwon: { label: "강원", longitude: 127.73, latitude: 37.88 },
  daejeon: { label: "대전/세종/충청", longitude: 127.38, latitude: 36.35 },
  jeonbuk: { label: "전북", longitude: 127.15, latitude: 35.82 },
  gwangju: { label: "광주/전남", longitude: 126.85, latitude: 35.16 },
  daegu: { label: "대구/경북", longitude: 128.6, latitude: 35.87 },
  busan: { label: "부산/울산/경남", longitude: 129.08, latitude: 35.18 },
  jeju: { label: "제주", longitude: 126.53, latitude: 33.5 },
};
