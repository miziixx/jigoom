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
