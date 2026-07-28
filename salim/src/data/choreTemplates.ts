import type { ChoreTemplate } from "../types";

// 집안일 마스터 목록 (기획서 12장). tip/howtoId는 살림백과(16장)와 연결.
export const CHORE_TEMPLATES: ChoreTemplate[] = [
  // 주방
  { category: "주방", name: "설거지", defaultCycle: "daily", durationMin: 10, effort: "easy" },
  { category: "주방", name: "싱크대 물기 닦기", defaultCycle: "daily", durationMin: 3, effort: "easy" },
  { category: "주방", name: "식탁 닦기", defaultCycle: "daily", durationMin: 2, effort: "easy" },
  { category: "주방", name: "가스레인지 닦기", defaultCycle: "daily", durationMin: 5, effort: "easy" },
  { category: "주방", name: "음식물 쓰레기 비우기", defaultCycle: "few_days", durationMin: 5, effort: "easy", tip: "밀폐해서 버리면 초파리·냄새가 확 줄어요.", howtoId: "bug-fruitfly" },
  { category: "주방", name: "행주 삶기", defaultCycle: "weekly", durationMin: 15, effort: "normal" },
  { category: "주방", name: "배수구 청소", defaultCycle: "weekly", durationMin: 10, effort: "normal", tip: "베이킹소다 뿌리고 식초 부어 거품 → 뜨거운 물로 마무리.", howtoId: "smell-drain" },
  { category: "주방", name: "전자레인지 내부 닦기", defaultCycle: "weekly", durationMin: 8, effort: "easy", howtoId: "stain-microwave" },
  { category: "주방", name: "냉장고 속 점검", defaultCycle: "weekly", durationMin: 15, effort: "normal" },
  { category: "주방", name: "냉장고 청소", defaultCycle: "monthly", durationMin: 40, effort: "heavy" },
  { category: "주방", name: "후드/필터 청소", defaultCycle: "monthly", durationMin: 30, effort: "heavy" },
  { category: "주방", name: "정수기 청소·필터", defaultCycle: "quarterly", durationMin: 20, effort: "normal" },
  { category: "주방", name: "식기건조대 물때 청소", defaultCycle: "weekly", durationMin: 10, effort: "normal", howtoId: "kitchen-dishrack" },
  { category: "주방", name: "수세미·솔 교체", defaultCycle: "weekly", durationMin: 1, effort: "easy", tip: "수세미는 세균 온상이라 1~2주마다 교체하거나 삶아 써요." },
  { category: "주방", name: "도마 소독", defaultCycle: "weekly", durationMin: 5, effort: "easy", tip: "베이킹소다+식초 또는 끓는 물로 소독해요.", howtoId: "kitchen-board" },
  { category: "주방", name: "냉동실 정리·성에 제거", defaultCycle: "quarterly", durationMin: 30, effort: "heavy", howtoId: "kitchen-freezer" },

  // 청소 (바닥·방·거실)
  { category: "청소", name: "침대 정리", defaultCycle: "daily", durationMin: 3, effort: "easy" },
  { category: "청소", name: "어질러진 것 정리", defaultCycle: "daily", durationMin: 10, effort: "easy" },
  { category: "청소", name: "청소기 돌리기", defaultCycle: "few_days", durationMin: 20, effort: "normal" },
  { category: "청소", name: "바닥 물걸레질", defaultCycle: "weekly", durationMin: 25, effort: "heavy" },
  { category: "청소", name: "가구 먼지 털기", defaultCycle: "weekly", durationMin: 15, effort: "easy" },
  { category: "청소", name: "거울/유리 닦기", defaultCycle: "biweekly", durationMin: 15, effort: "normal" },
  { category: "청소", name: "문손잡이·스위치 닦기", defaultCycle: "biweekly", durationMin: 10, effort: "easy" },
  { category: "청소", name: "창틀 닦기", defaultCycle: "monthly", durationMin: 25, effort: "normal" },
  { category: "청소", name: "창문 유리 닦기", defaultCycle: "quarterly", durationMin: 40, effort: "heavy", weatherTag: "sunny" },
  { category: "청소", name: "방충망 청소", defaultCycle: "quarterly", durationMin: 30, effort: "heavy", weatherTag: "sunny" },

  // 욕실
  { category: "욕실", name: "세면대 닦기", defaultCycle: "few_days", durationMin: 5, effort: "easy" },
  { category: "욕실", name: "변기 청소", defaultCycle: "weekly", durationMin: 10, effort: "normal", tip: "물티슈·이물질은 변기에 버리지 않기 — 막힘의 주범이에요.", howtoId: "clog-toilet" },
  { category: "욕실", name: "욕실 바닥·타일", defaultCycle: "weekly", durationMin: 20, effort: "heavy" },
  { category: "욕실", name: "욕실 거울 닦기", defaultCycle: "weekly", durationMin: 5, effort: "easy" },
  { category: "욕실", name: "배수구 머리카락 제거", defaultCycle: "weekly", durationMin: 5, effort: "normal", howtoId: "clog-sink" },
  { category: "욕실", name: "샤워부스 물때 제거", defaultCycle: "biweekly", durationMin: 20, effort: "heavy" },
  { category: "욕실", name: "수건 교체", defaultCycle: "weekly", durationMin: 3, effort: "easy" },
  { category: "욕실", name: "곰팡이 점검·제거", defaultCycle: "monthly", durationMin: 25, effort: "heavy", seasonMonths: [6, 7, 8], tip: "환기하며 장갑 끼고, 다른 세제와 절대 섞지 마세요.", howtoId: "mold-silicone" },
  { category: "욕실", name: "환풍기 청소", defaultCycle: "quarterly", durationMin: 20, effort: "normal" },
  { category: "욕실", name: "샤워헤드 세척", defaultCycle: "quarterly", durationMin: 15, effort: "normal", tip: "구연산 물에 담가 막힌 구멍의 물때를 녹여요.", howtoId: "stain-water-spot" },

  // 세탁
  { category: "세탁", name: "빨래 돌리기", defaultCycle: "few_days", durationMin: 5, effort: "easy", tip: "다 되면 바로 널기 — 방치하면 쉰내가 나요.", howtoId: "smell-laundry" },
  { category: "세탁", name: "빨래 널기·개기", defaultCycle: "few_days", durationMin: 15, effort: "easy", weatherTag: "sunny" },
  { category: "세탁", name: "수건 빨래", defaultCycle: "weekly", durationMin: 5, effort: "easy" },
  { category: "세탁", name: "침구 세탁", defaultCycle: "biweekly", durationMin: 10, effort: "normal", weatherTag: "sunny" },
  { category: "세탁", name: "이불 세탁", defaultCycle: "monthly", durationMin: 15, effort: "normal", weatherTag: "sunny" },
  { category: "세탁", name: "세탁조 통세척", defaultCycle: "monthly", durationMin: 10, effort: "easy", tip: "사용 후 문을 열어 말리면 곰팡이가 줄어요.", howtoId: "mold-washer" },
  { category: "세탁", name: "신발 세탁", defaultCycle: "monthly", durationMin: 20, effort: "normal", howtoId: "smell-shoes" },

  // 정리·정돈
  { category: "정리·정돈", name: "우편함·택배 정리", defaultCycle: "few_days", durationMin: 5, effort: "easy" },
  { category: "정리·정돈", name: "책상 정리", defaultCycle: "weekly", durationMin: 10, effort: "easy" },
  { category: "정리·정돈", name: "현관 신발 정돈", defaultCycle: "weekly", durationMin: 5, effort: "easy" },
  { category: "정리·정돈", name: "옷장 정리", defaultCycle: "monthly", durationMin: 30, effort: "normal" },
  { category: "정리·정돈", name: "신발장 정리", defaultCycle: "monthly", durationMin: 20, effort: "normal", howtoId: "smell-shoes" },
  { category: "정리·정돈", name: "서랍·수납 정리", defaultCycle: "quarterly", durationMin: 40, effort: "heavy" },
  { category: "정리·정돈", name: "안 쓰는 물건 비우기", defaultCycle: "quarterly", durationMin: 40, effort: "heavy" },

  // 쓰레기·분리수거
  { category: "쓰레기·분리수거", name: "일반 쓰레기 비우기", defaultCycle: "few_days", durationMin: 5, effort: "easy" },
  { category: "쓰레기·분리수거", name: "분리수거 배출", defaultCycle: "weekly", durationMin: 15, effort: "normal", tip: "내용물 비우고 헹궈서, 택배 송장·테이프는 떼고.", howtoId: "setup-recycle" },
  { category: "쓰레기·분리수거", name: "쓰레기통 세척", defaultCycle: "monthly", durationMin: 10, effort: "normal" },

  // 침실·환기
  { category: "침실·환기", name: "환기(창문 열기)", defaultCycle: "daily", durationMin: 2, effort: "easy" },
  { category: "침실·환기", name: "매트리스 뒤집기", defaultCycle: "quarterly", durationMin: 15, effort: "heavy" },
  { category: "침실·환기", name: "베개 세탁", defaultCycle: "quarterly", durationMin: 10, effort: "normal" },

  // 가전 관리
  { category: "가전 관리", name: "청소기 먼지통 비우기", defaultCycle: "weekly", durationMin: 5, effort: "easy" },
  { category: "가전 관리", name: "공기청정기 필터 점검", defaultCycle: "monthly", durationMin: 10, effort: "easy", weatherTag: "dusty" },
  { category: "가전 관리", name: "청소기 필터 청소", defaultCycle: "monthly", durationMin: 10, effort: "normal" },
  { category: "가전 관리", name: "세탁기 거름망 청소", defaultCycle: "monthly", durationMin: 5, effort: "easy" },
  { category: "가전 관리", name: "에어컨 필터 청소", defaultCycle: "quarterly", durationMin: 20, effort: "normal", seasonMonths: [5, 6, 7, 8] },
  { category: "가전 관리", name: "냉장고 뒷면 먼지", defaultCycle: "quarterly", durationMin: 15, effort: "normal" },
  { category: "가전 관리", name: "보일러 점검", defaultCycle: "yearly", durationMin: 20, effort: "normal", seasonMonths: [10, 11] },
  { category: "가전 관리", name: "TV·모니터 화면 닦기", defaultCycle: "monthly", durationMin: 5, effort: "easy", tip: "전원 끄고 마른 극세사 천으로. 세정액은 천에 묻혀 닦아요." },
  { category: "가전 관리", name: "가습기 세척", defaultCycle: "weekly", durationMin: 10, effort: "normal", seasonMonths: [11, 12, 1, 2], tip: "물때를 방치하면 세균이 공기로 퍼져요. 매일 물 갈기.", howtoId: "limescale-kettle" },

  // 현관·베란다
  { category: "현관·베란다", name: "현관 바닥 닦기", defaultCycle: "biweekly", durationMin: 10, effort: "easy" },
  { category: "현관·베란다", name: "베란다 청소", defaultCycle: "monthly", durationMin: 25, effort: "normal" },
  { category: "현관·베란다", name: "우산·잡동사니 정리", defaultCycle: "monthly", durationMin: 10, effort: "easy" },

  // 식물·반려 (선택)
  { category: "식물·반려", name: "화분 물 주기", defaultCycle: "few_days", durationMin: 5, effort: "easy" },
  { category: "식물·반려", name: "반려동물 밥·물", defaultCycle: "daily", durationMin: 5, effort: "easy" },
  { category: "식물·반려", name: "반려동물 화장실 청소", defaultCycle: "daily", durationMin: 5, effort: "normal" },
  { category: "식물·반려", name: "반려동물 목욕", defaultCycle: "biweekly", durationMin: 30, effort: "heavy" },
  { category: "식물·반려", name: "화분 영양제·분갈이", defaultCycle: "quarterly", durationMin: 30, effort: "normal" },

  // 생활 관리 (선택)
  { category: "생활 관리", name: "생필품 재고 점검", defaultCycle: "weekly", durationMin: 10, effort: "easy" },
  { category: "생활 관리", name: "공과금 납부 확인", defaultCycle: "monthly", durationMin: 10, effort: "easy", tip: "자동이체를 걸어두면 연체를 막을 수 있어요.", howtoId: "setup-utility" },
  { category: "생활 관리", name: "상비약·유통기한 점검", defaultCycle: "quarterly", durationMin: 15, effort: "easy" },
  { category: "생활 관리", name: "사진·문서 백업", defaultCycle: "monthly", durationMin: 15, effort: "easy", howtoId: "save-backup" },
  { category: "생활 관리", name: "구독 서비스 점검", defaultCycle: "monthly", durationMin: 10, effort: "easy", tip: "안 쓰는 구독을 끊으면 매달 새는 돈을 막아요.", howtoId: "save-subscription" },

  // 위생·건강
  { category: "위생·건강", name: "칫솔 교체", defaultCycle: "quarterly", durationMin: 2, effort: "easy", tip: "칫솔은 3개월마다, 감기 앓은 뒤엔 바로 교체해요." },
  { category: "위생·건강", name: "리모컨·스위치·휴대폰 닦기", defaultCycle: "weekly", durationMin: 5, effort: "easy", howtoId: "health-sanitize" },
  { category: "위생·건강", name: "침구 햇볕 소독·털기", defaultCycle: "monthly", durationMin: 15, effort: "normal", weatherTag: "sunny", howtoId: "health-dustmite" },
  { category: "위생·건강", name: "수건 삶기·살균", defaultCycle: "monthly", durationMin: 15, effort: "normal", tip: "삶거나 과탄산소다로 살균하면 쉰내·세균이 줄어요.", howtoId: "smell-laundry" },

  // 수선·관리
  { category: "수선·관리", name: "옷 보풀 제거", defaultCycle: "monthly", durationMin: 10, effort: "easy", howtoId: "mend-lint" },
  { category: "수선·관리", name: "신발 관리·방수", defaultCycle: "monthly", durationMin: 10, effort: "easy", howtoId: "care-shoes" },
  { category: "수선·관리", name: "가죽 제품 관리", defaultCycle: "quarterly", durationMin: 15, effort: "easy", howtoId: "care-leather" },

  // 계절·대청소
  { category: "계절·대청소", name: "커튼 세탁", defaultCycle: "quarterly", durationMin: 30, effort: "heavy", seasonMonths: [3, 4, 9, 10] },
  { category: "계절·대청소", name: "옷장 계절 옷 교체", defaultCycle: "quarterly", durationMin: 60, effort: "heavy", seasonMonths: [3, 9] },
  { category: "계절·대청소", name: "환기구·필터 대청소", defaultCycle: "quarterly", durationMin: 40, effort: "heavy" },
  { category: "계절·대청소", name: "집 전체 대청소", defaultCycle: "quarterly", durationMin: 120, effort: "heavy" },
];

// 카테고리 표시 순서
export const CHORE_CATEGORIES: string[] = Array.from(
  new Set(CHORE_TEMPLATES.map((t) => t.category)),
);
