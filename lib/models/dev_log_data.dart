class DevMilestone {
  final String title;
  final List<String> items;
  const DevMilestone({required this.title, required this.items});
}

const kDevMilestones = <DevMilestone>[
  DevMilestone(
    title: 'MVP 1',
    items: [
      '메모 작성 / 수정 / 삭제',
      '로컬 저장',
      '태그',
      '검색',
      '폴더 관리',
    ],
  ),
  DevMilestone(
    title: 'MVP 2',
    items: [
      '체크리스트 (인라인 편집)',
      '일정 등록 (! 단축키)',
      '알림 설정 (🔔)',
      '통계 화면',
      '달력 뷰',
      '날짜별 그룹 헤더',
    ],
  ),
  DevMilestone(
    title: 'LOGROOM',
    items: [
      '사이드바',
      '하단 탭 바 (QuickTab)',
      'Today 탭',
      'DOS 테마',
      'Minimal 테마',
      'Today 대시보드 (요약 + 시간 지도)',
      'Logroom 시간별 그룹 뷰',
      '섹션 접기 / 펼치기',
    ],
  ),
  DevMilestone(
    title: 'DATA & IMPORT',
    items: [
      '백업 내보내기 / 복원 (JSON)',
      'TXT 가져오기 (빈 줄 분리, 미리보기)',
    ],
  ),
  DevMilestone(
    title: 'DEV CENTER',
    items: [
      'nemo2test 전용 히든 메뉴',
      'DEV LOG / CHANGELOG / QA 탭',
      'QA 세션 기록',
      '프로젝트 이력 보기',
    ],
  ),
];
