class QaItem {
  final String id;
  final String label;
  const QaItem({required this.id, required this.label});
}

class QaCategory {
  final String label;
  final List<QaItem> items;
  const QaCategory({required this.label, required this.items});
}

const kQaCategories = <QaCategory>[
  QaCategory(
    label: '메모',
    items: [
      QaItem(id: 'memo_create', label: '메모 작성'),
      QaItem(id: 'memo_edit', label: '메모 수정'),
      QaItem(id: 'memo_delete', label: '메모 삭제'),
      QaItem(id: 'memo_search', label: '검색'),
    ],
  ),
  QaCategory(
    label: '체크리스트',
    items: [
      QaItem(id: 'check_create', label: '체크리스트 생성'),
      QaItem(id: 'check_toggle', label: '체크박스 체크'),
      QaItem(id: 'check_order', label: '순서 확인'),
    ],
  ),
  QaCategory(
    label: '일정',
    items: [
      QaItem(id: 'sched_create', label: '일정 생성'),
      QaItem(id: 'sched_view', label: '일정 화면 확인'),
    ],
  ),
  QaCategory(
    label: '알림',
    items: [
      QaItem(id: 'reminder_set', label: '알림 생성'),
      QaItem(id: 'reminder_cancel', label: '알림 삭제'),
    ],
  ),
  QaCategory(
    label: '데이터',
    items: [
      QaItem(id: 'backup_export', label: '백업 내보내기'),
      QaItem(id: 'backup_restore', label: '백업 복원'),
      QaItem(id: 'txt_import', label: 'TXT 가져오기'),
      QaItem(id: 'cache_clear', label: '캐시 삭제'),
    ],
  ),
  QaCategory(
    label: '테마 / UI',
    items: [
      QaItem(id: 'theme_normal', label: '기본 테마 확인'),
      QaItem(id: 'theme_dos', label: 'DOS 테마 확인'),
      QaItem(id: 'theme_minimal', label: 'Minimal 테마 확인'),
      QaItem(id: 'today_dashboard', label: 'Today 대시보드'),
      QaItem(id: 'logroom_ui', label: 'Logroom UI'),
    ],
  ),
];
