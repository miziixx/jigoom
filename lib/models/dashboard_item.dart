import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 대시보드에 올릴 수 있는 항목들의 카탈로그.
/// id 는 home_screen 의 _selectBottomMenu(menu) 케이스와 1:1로 대응한다.
class DashboardItem {
  final String id; // _selectBottomMenu 케이스 id (TASKS, EVENTS, ...)
  final String label; // 한글 표시명
  final bool summary; // true = 요약 카드, false = 단순 이동 행

  const DashboardItem(this.id, this.label, {this.summary = false});
}

/// 전체 카탈로그. 순서 변경/이동은 사용자 설정으로 저장되지만,
/// "어떤 항목이 존재하는가"는 여기서 정의한다.
const List<DashboardItem> kDashboardCatalog = [
  DashboardItem('TASKS', '할 일', summary: true),
  DashboardItem('EVENTS', '다가오는 일정', summary: true),
  DashboardItem('HABITS', '습관', summary: true),
  DashboardItem('GOALS', '목표', summary: true),
  DashboardItem('STATS', '이번 주 기록', summary: true),
  DashboardItem('LIST', '전체 기록'),
  DashboardItem('TAGS', '태그'),
  DashboardItem('GRAPH', '그래프'),
  DashboardItem('BRAIN', '브레인'),
  DashboardItem('SETTINGS', '설정'),
];

DashboardItem? dashboardItemById(String id) {
  for (final it in kDashboardCatalog) {
    if (it.id == id) return it;
  }
  return null;
}

/// 대시보드 구성: 위쪽(대시보드에 노출)에 올릴 id 목록과,
/// 아래쪽(더보기 서랍)에 둘 id 목록. 순서까지 그대로 보존한다.
class DashboardConfig {
  List<String> dashboard;
  List<String> more;

  DashboardConfig({required this.dashboard, required this.more});

  static const _key = 'dashboard_config_v1';

  static DashboardConfig defaults() => DashboardConfig(
    dashboard: ['TASKS', 'EVENTS', 'HABITS', 'STATS'],
    more: ['GOALS', 'LIST', 'TAGS', 'GRAPH', 'BRAIN', 'SETTINGS'],
  );

  /// 저장값을 카탈로그와 대조해 정리한다. 카탈로그에 새 항목이 추가되면
  /// (저장값에 없던 id) 자동으로 더보기 서랍 끝에 편입시켜 유실을 막는다.
  DashboardConfig _reconciled() {
    final known = kDashboardCatalog.map((e) => e.id).toSet();
    final seen = <String>{};
    List<String> clean(List<String> src) {
      final out = <String>[];
      for (final id in src) {
        if (known.contains(id) && seen.add(id)) out.add(id);
      }
      return out;
    }

    final dash = clean(dashboard);
    final mr = clean(more);
    for (final it in kDashboardCatalog) {
      if (!seen.contains(it.id)) mr.add(it.id);
    }
    return DashboardConfig(dashboard: dash, more: mr);
  }

  static Future<DashboardConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return defaults();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final cfg = DashboardConfig(
        dashboard: (map['dashboard'] as List).map((e) => e as String).toList(),
        more: (map['more'] as List).map((e) => e as String).toList(),
      );
      return cfg._reconciled();
    } catch (_) {
      return defaults();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({'dashboard': dashboard, 'more': more}),
      );
    } catch (_) {}
  }
}
