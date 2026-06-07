// UPDATE THESE MANUALLY BEFORE EACH BUILD / COMMIT
const kCurrentGitCommit = '04c5b1a';
const kCurrentBranch = 'fix/logroom-entry-rendering-ux';

class ChangelogEntry {
  final String version;
  final String? date;
  final String? category;
  final List<String> changes;
  final String? developerNote;

  const ChangelogEntry({
    required this.version,
    this.date,
    this.category,
    required this.changes,
    this.developerNote,
  });
}

const kChangelog = <ChangelogEntry>[
  ChangelogEntry(
    version: 'v0.1',
    date: '2024',
    changes: ['메모 작성 · 수정 · 삭제', '로컬 저장 (SharedPreferences)'],
  ),
  ChangelogEntry(
    version: 'v0.2',
    date: '2024',
    changes: ['태그', '검색', '폴더 관리'],
  ),
  ChangelogEntry(
    version: 'v0.3',
    date: '2024',
    changes: [
      'scheduledAt (일정, ! 단축키)',
      'reminderAt (알림, 🔔)',
      '알림 서비스 (NotificationService)',
    ],
  ),
  ChangelogEntry(
    version: 'v1.0',
    date: '2024',
    changes: ['사이드바', 'QuickTab 바텀 탭', 'Today 탭'],
  ),
  ChangelogEntry(
    version: 'v1.1',
    date: '2024',
    changes: ['체크리스트 인라인 편집', '체크리스트 항목 순서 유지', 'createdAt 정렬'],
  ),
  ChangelogEntry(
    version: 'v1.2',
    date: '2024',
    changes: ['통계 화면 (stats)', '달력 뷰 (CalendarView)', '날짜별 그룹 헤더'],
  ),
  ChangelogEntry(
    version: 'v2.0',
    date: '2025',
    changes: ['nemo2 플레이버 분리', '백업 / 복원', 'DOS 테마', 'Minimal 테마'],
  ),
  ChangelogEntry(
    version: 'v2.1',
    date: '2025',
    changes: [
      'Today 대시보드 재구성 (Summary · Time Map)',
      '섹션 접기/펼치기',
      'Logroom 날짜 그룹 Hour 오버뷰',
      '타이포그래피 스케일 통일',
    ],
  ),
  ChangelogEntry(
    version: 'v2.2',
    date: '2025',
    changes: [
      'TXT Import v1 (빈 줄 기준 분리, 미리보기)',
      'nemo2test Dev Center (DEV / CHANGELOG / QA)',
      'Dev Center: QA Session 로그, Project History 요약, REPO 정보',
    ],
  ),
  // ──────────────────────────────────────────────────────────────────
  // ADD NEW CHANGELOG ENTRY HERE ↑
  // newest entry last — CHANGELOG tab reverses order automatically.
  //
  // Template:
  //   ChangelogEntry(
  //     version: 'vX.Y',
  //     date: 'YYYY',
  //     category: 'feature|fix|refactor',   // optional
  //     changes: ['변경사항 1', '변경사항 2'],
  //     developerNote: '내부 메모',         // optional
  //   ),
  // ──────────────────────────────────────────────────────────────────
];
