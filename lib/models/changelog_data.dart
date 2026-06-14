// UPDATE THESE MANUALLY BEFORE EACH BUILD / COMMIT
const kCurrentGitCommit = '04c5b1a';
const kCurrentBranch = 'fix/logroom-entry-rendering-ux';

class ChangelogEntry {
  final String version;
  final String date;
  final List<String> features;
  final List<String> fixes;
  final List<String> design;

  const ChangelogEntry({
    required this.version,
    required this.date,
    this.features = const [],
    this.fixes = const [],
    this.design = const [],
  });
}

const kChangelog = <ChangelogEntry>[
  ChangelogEntry(
    version: 'v0.1',
    date: '2024',
    features: ['메모 작성 / 수정 / 삭제', '기기에 저장'],
  ),
  ChangelogEntry(
    version: 'v0.2',
    date: '2024',
    features: ['태그', '검색', '폴더 관리'],
  ),
  ChangelogEntry(
    version: 'v0.3',
    date: '2024',
    features: ['일정 등록 (! 단축키)', '알림 설정 (🔔)', '알림 기능'],
  ),
  ChangelogEntry(
    version: 'v1.0',
    date: '2024',
    features: ['사이드바', '하단 탭 바', 'Today 탭'],
  ),
  ChangelogEntry(
    version: 'v1.1',
    date: '2024',
    features: ['체크리스트 인라인 편집'],
    fixes: ['체크리스트 항목 순서 유지', '작성 시간 기준 정렬'],
  ),
  ChangelogEntry(
    version: 'v1.2',
    date: '2024',
    features: ['통계 화면', '달력 뷰', '날짜별 그룹 헤더'],
  ),
  ChangelogEntry(
    version: 'v2.0',
    date: '2025',
    features: ['백업 / 복원', 'nemo2 앱 분리 설치'],
    design: ['DOS 테마', 'Minimal 테마'],
  ),
  ChangelogEntry(
    version: 'v2.1',
    date: '2025',
    features: [
      'Today 대시보드 (요약 + 시간 지도)',
      '섹션 접기 / 펼치기',
      'Logroom 시간별 그룹 뷰',
    ],
    design: ['텍스트 크기 통일'],
  ),
  ChangelogEntry(
    version: 'v2.2',
    date: '2026-06-08',
    features: [
      'TXT 가져오기 (빈 줄 분리, 미리보기)',
      'Dev Center (DEV LOG / CHANGELOG / QA)',
      'QA 세션 기록',
      '프로젝트 이력 요약',
    ],
  ),
  ChangelogEntry(
    version: 'v2.3',
    date: '2026-06-09',
    fixes: [
      '도스 테마 강제종료 후 테마 모드 초기화 버그 — 모드 변경 시 즉시 저장하도록 수정',
      '도스 테마 강제종료 후 색상 초기화 버그 — 색상 변경 시 800ms debounce 자동 저장 추가',
    ],
    design: [
      '위젯 메모 입력창 UI 개선 — 메인 앱 logroom 입력창과 동일한 구조로 통일',
      '텍스트 입력창 상단 배치 + 왼쪽 accent dot 추가',
      '툴바를 하단으로 이동, top border 구분선 적용',
      '폴더 버튼을 툴바 안으로 이동',
      'nemo2test 앱 아이콘 변경 — 7×14 도트 토끼 (배경 #0C0B09 / 토끼 #B8882A)',
      '최소 지원 Android 버전: API 24 (Android 7.0 Nougat, 2016)',
      '위젯 입력창 툴바 제거 — ADD 버튼 입력창 오른쪽 인라인 배치',
      '위젯 입력창 폭 화면의 88%로 축소, 텍스트 영역 minLines 3으로 확장',
    ],
  ),
  ChangelogEntry(
    version: 'v2.4',
    date: '2026-06-15',
    features: [
      '개인 위키 — 링크 공유 시 Claude가 자동 요약해 댓글로 첨부',
      'BRAIN 탭 — 저장한 메모 기반 AI 채팅 (사이드바 메뉴 추가)',
      'GRAPH 탭 — 키워드 연결 그래프',
      '브레인 검색을 로컬 글자 n-gram 유사도로 처리 (업로드 0, substring 매칭 대체). 의미 임베딩(온디바이스)은 추후 ②로 예정',
    ],
    fixes: [
      '댓글 수정/추가 다이얼로그 닫을 때 강제종료 — await showDialog 직후 컨트롤러를 dispose 해서 닫힘 애니메이션 중 죽은 컨트롤러를 건드리던 문제. 표면 에러는 _dependents.isEmpty 였으나 실제 원인은 "controller used after dispose". 컨트롤러를 StatefulWidget(_NoteDialog)이 소유하도록 변경',
      '습관/목표 이름 다이얼로그 동일 크래시 — 닫힘 애니메이션 후 dispose 하도록 수정 (전 flavor 영향)',
      'BRAIN 메뉴가 안 열리던 버그 — _brainOpen=true 직후 false로 덮어쓰던 복붙 코드 제거',
    ],
  ),
  // ──────────────────────────────────────────────────────────────────
  // ADD NEW CHANGELOG ENTRY HERE ↑
  // newest entry last — CHANGELOG tab reverses order automatically.
  //
  // Template:
  //   ChangelogEntry(
  //     version: 'vX.Y',
  //     date: 'YYYY-MM-DD',
  //     features: ['새 기능'],    // optional
  //     fixes: ['버그 수정'],     // optional
  //     design: ['디자인 변경'],  // optional
  //   ),
  // ──────────────────────────────────────────────────────────────────
];
