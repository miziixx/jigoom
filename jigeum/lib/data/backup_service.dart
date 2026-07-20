import 'dart:convert';

import 'package:drift/drift.dart';

import 'db.dart';

/// 전체 데이터 백업/복원 (JSON).
/// 복원은 전체 교체: 현재 데이터를 지우고 백업 시점으로 되돌린다.
class BackupService {
  BackupService(this.db);

  final AppDatabase db;

  static const formatVersion = 1;

  // ------------------------------------------------------------- 내보내기
  Future<String> exportJson() async {
    final nodes = await db.select(db.nodes).get();
    final settings = await db.select(db.settings).get();
    final habits = await db.select(db.habits).get();
    final ticks = await db.select(db.habitTicks).get();

    String? d(DateTime? v) => v?.toIso8601String();

    return jsonEncode({
      'app': 'jigeum',
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'nodes': [
        for (final n in nodes)
          {
            'id': n.id,
            'parentId': n.parentId,
            'sortOrder': n.sortOrder,
            'type': n.type,
            'title': n.title,
            'note': n.note,
            'important': n.important,
            'urgent': n.urgent,
            'date': d(n.date),
            'slot': n.slot,
            'status': n.status,
            'doneAt': d(n.doneAt),
            'carriedCount': n.carriedCount,
            'createdAt': d(n.createdAt),
            'updatedAt': d(n.updatedAt),
          }
      ],
      'settings': [
        for (final s in settings) {'key': s.key, 'value': s.value}
      ],
      'habits': [
        for (final h in habits)
          {
            'id': h.id,
            'title': h.title,
            'category': h.category,
            'createdAt': d(h.createdAt),
          }
      ],
      'habitTicks': [
        for (final t in ticks)
          {'habitId': t.habitId, 'date': d(t.date)}
      ],
    });
  }

  // --------------------------------------------------------------- 복원
  /// 전체 교체 복원. 형식이 맞지 않으면 예외 → 기존 데이터는 건드리지 않음.
  Future<void> importJson(String jsonStr) async {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (map['app'] != 'jigeum') {
      throw const FormatException('지금(jigeum) 백업 파일이 아니에요');
    }

    DateTime? p(dynamic v) => v == null ? null : DateTime.parse(v as String);
    DateTime pr(dynamic v) => DateTime.parse(v as String);

    // 먼저 전부 파싱 (여기서 실패하면 DB 는 그대로).
    final nodes = [
      for (final m in (map['nodes'] as List? ?? const []))
        NodesCompanion.insert(
          id: m['id'] as String,
          parentId: Value(m['parentId'] as String?),
          sortOrder: m['sortOrder'] as int,
          type: m['type'] as String,
          title: m['title'] as String,
          note: Value(m['note'] as String? ?? ''),
          important: Value(m['important'] as bool? ?? false),
          urgent: Value(m['urgent'] as bool? ?? false),
          date: Value(p(m['date'])),
          slot: Value(m['slot'] as String?),
          status: Value(m['status'] as String? ?? 'open'),
          doneAt: Value(p(m['doneAt'])),
          carriedCount: Value(m['carriedCount'] as int? ?? 0),
          createdAt: pr(m['createdAt']),
          updatedAt: pr(m['updatedAt']),
        )
    ];
    final settings = [
      for (final m in (map['settings'] as List? ?? const []))
        SettingsCompanion.insert(
            key: m['key'] as String, value: m['value'] as String)
    ];
    final habits = [
      for (final m in (map['habits'] as List? ?? const []))
        HabitsCompanion.insert(
          id: m['id'] as String,
          title: m['title'] as String,
          category: Value(m['category'] as String? ?? ''),
          createdAt: pr(m['createdAt']),
        )
    ];
    final ticks = [
      for (final m in (map['habitTicks'] as List? ?? const []))
        HabitTicksCompanion.insert(
            habitId: m['habitId'] as String, date: pr(m['date']))
    ];

    await db.transaction(() async {
      await db.delete(db.habitTicks).go();
      await db.delete(db.habits).go();
      await db.delete(db.settings).go();
      await db.delete(db.nodes).go();
      for (final n in nodes) {
        await db.into(db.nodes).insert(n);
      }
      for (final s in settings) {
        await db.into(db.settings).insert(s);
      }
      for (final h in habits) {
        await db.into(db.habits).insert(h);
      }
      for (final t in ticks) {
        await db.into(db.habitTicks).insert(t);
      }
    });
  }
}
