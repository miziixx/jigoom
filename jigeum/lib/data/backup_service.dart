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
    final schedules = await db.select(db.schedules).get();
    final routines = await db.select(db.routines).get();
    final routineGroups = await db.select(db.routineGroups).get();
    final routineSteps = await db.select(db.routineSteps).get();
    final timeBlocks = await db.select(db.timeBlocks).get();

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
            'nextStep': n.nextStep,
            'triggerCondition': n.triggerCondition,
            'obstacleNote': n.obstacleNote,
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
          {
            'habitId': t.habitId,
            'date': d(t.date),
            'completedAt': d(t.completedAt),
          }
      ],
      'schedules': [
        for (final s in schedules)
          {
            'id': s.id,
            'date': d(s.date),
            'endDate': s.endDate == null ? null : d(s.endDate!),
            'title': s.title,
            'note': s.note,
            'color': s.color,
            'startMin': s.startMin,
            'endMin': s.endMin,
            'done': s.done,
            'doneAt': d(s.doneAt),
            'routineId': s.routineId,
            'createdAt': d(s.createdAt),
            'allDay': s.allDay,
            'gcalCalendarId': s.gcalCalendarId,
            'gcalId': s.gcalId,
            'gcalEtag': s.gcalEtag,
            'dirty': s.dirty,
            'deleted': s.deleted,
            'updatedAt': d(s.updatedAt),
          }
      ],
      'routines': [
        for (final r in routines)
          {
            'id': r.id,
            'title': r.title,
            'note': r.note,
            'color': r.color,
            'startMin': r.startMin,
            'endMin': r.endMin,
            'weekdays': r.weekdays,
            'active': r.active,
            'createdAt': d(r.createdAt),
          }
      ],
      'routineGroups': [
        for (final g in routineGroups)
          {
            'id': g.id,
            'title': g.title,
            'sortOrder': g.sortOrder,
            'weekdays': g.weekdays,
            'collapsed': g.collapsed,
            'active': g.active,
            'createdAt': d(g.createdAt),
          }
      ],
      'routineSteps': [
        for (final s in routineSteps)
          {
            'id': s.id,
            'groupId': s.groupId,
            'sortOrder': s.sortOrder,
            'trigger': s.trigger,
            'title': s.title,
            'streak': s.streak,
            'lastDone': d(s.lastDone),
            'lastDoneAt': d(s.lastDoneAt),
            'createdAt': d(s.createdAt),
          }
      ],
      'timeBlocks': [
        for (final t in timeBlocks)
          {'date': d(t.date), 'block': t.block, 'text': t.content}
      ],
    });
  }

  // --------------------------------------------------------------- 복원
  /// 전체 교체 복원. 형식이 맞지 않으면 예외 → 기존 데이터는 건드리지 않음.
  /// 백업 복원.
  /// - [merge] false(기본): 전체 교체 — 현재 데이터를 모두 지우고 백업만 남긴다.
  /// - [merge] true: 병합(덮어쓰기) — 현재 데이터는 두고, 백업을 그 위에 얹는다
  ///   (같은 id 는 백업 값으로 덮어쓰고, 백업에 없는 내 기록은 유지).
  Future<void> importJson(String jsonStr, {bool merge = false}) async {
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
          nextStep: Value(m['nextStep'] as String?),
          triggerCondition: Value(m['triggerCondition'] as String?),
          obstacleNote: Value(m['obstacleNote'] as String?),
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
          habitId: m['habitId'] as String,
          date: pr(m['date']),
          completedAt: Value(p(m['completedAt'])),
        )
    ];
    final schedules = [
      for (final m in (map['schedules'] as List? ?? const []))
        SchedulesCompanion.insert(
          id: m['id'] as String,
          date: pr(m['date']),
          endDate: Value(p(m['endDate'])),
          title: m['title'] as String,
          note: Value(m['note'] as String? ?? ''),
          color: Value(m['color'] as int? ?? 0),
          startMin: m['startMin'] as int,
          endMin: m['endMin'] as int,
          done: Value(m['done'] as bool? ?? false),
          doneAt: Value(p(m['doneAt'])),
          routineId: Value(m['routineId'] as String?),
          createdAt: pr(m['createdAt']),
          allDay: Value(m['allDay'] as bool? ?? false),
          gcalCalendarId: Value(m['gcalCalendarId'] as String?),
          gcalId: Value(m['gcalId'] as String?),
          gcalEtag: Value(m['gcalEtag'] as String?),
          dirty: Value(m['dirty'] as bool? ?? false),
          deleted: Value(m['deleted'] as bool? ?? false),
          updatedAt: Value(p(m['updatedAt'])),
        )
    ];
    final routineGroups = [
      for (final m in (map['routineGroups'] as List? ?? const []))
        RoutineGroupsCompanion.insert(
          id: m['id'] as String,
          title: m['title'] as String,
          sortOrder: Value(m['sortOrder'] as int? ?? 0),
          weekdays: Value(m['weekdays'] as String? ?? '1,2,3,4,5,6,7'),
          collapsed: Value(m['collapsed'] as bool? ?? false),
          active: Value(m['active'] as bool? ?? true),
          createdAt: pr(m['createdAt']),
        )
    ];
    final routineSteps = [
      for (final m in (map['routineSteps'] as List? ?? const []))
        RoutineStepsCompanion.insert(
          id: m['id'] as String,
          groupId: m['groupId'] as String,
          sortOrder: Value(m['sortOrder'] as int? ?? 0),
          trigger: Value(m['trigger'] as String? ?? ''),
          title: m['title'] as String,
          streak: Value(m['streak'] as int? ?? 0),
          lastDone: Value(p(m['lastDone'])),
          lastDoneAt: Value(p(m['lastDoneAt'])),
          createdAt: pr(m['createdAt']),
        )
    ];
    final routines = [
      for (final m in (map['routines'] as List? ?? const []))
        RoutinesCompanion.insert(
          id: m['id'] as String,
          title: m['title'] as String,
          note: Value(m['note'] as String? ?? ''),
          color: Value(m['color'] as int? ?? 0),
          startMin: m['startMin'] as int,
          endMin: m['endMin'] as int,
          weekdays: Value(m['weekdays'] as String? ?? '1,2,3,4,5,6,7'),
          active: Value(m['active'] as bool? ?? true),
          createdAt: pr(m['createdAt']),
        )
    ];
    final timeBlocks = [
      for (final m in (map['timeBlocks'] as List? ?? const []))
        TimeBlocksCompanion.insert(
          date: pr(m['date']),
          block: m['block'] as int,
          content: m['text'] as String,
        )
    ];

    // 병합이면 같은 키를 백업 값으로 덮어쓰고(upsert), 전체 교체면 단순 insert.
    final mode = merge ? InsertMode.insertOrReplace : InsertMode.insert;
    await db.transaction(() async {
      if (!merge) {
        await db.delete(db.habitTicks).go();
        await db.delete(db.habits).go();
        await db.delete(db.settings).go();
        await db.delete(db.nodes).go();
        await db.delete(db.schedules).go();
        await db.delete(db.routines).go();
        await db.delete(db.routineSteps).go();
        await db.delete(db.routineGroups).go();
        await db.delete(db.timeBlocks).go();
      }
      for (final n in nodes) {
        await db.into(db.nodes).insert(n, mode: mode);
      }
      for (final s in settings) {
        await db.into(db.settings).insert(s, mode: mode);
      }
      for (final h in habits) {
        await db.into(db.habits).insert(h, mode: mode);
      }
      for (final t in ticks) {
        await db.into(db.habitTicks).insert(t, mode: mode);
      }
      for (final s in schedules) {
        await db.into(db.schedules).insert(s, mode: mode);
      }
      for (final r in routines) {
        await db.into(db.routines).insert(r, mode: mode);
      }
      for (final g in routineGroups) {
        await db.into(db.routineGroups).insert(g, mode: mode);
      }
      for (final s in routineSteps) {
        await db.into(db.routineSteps).insert(s, mode: mode);
      }
      for (final t in timeBlocks) {
        await db.into(db.timeBlocks).insert(t, mode: mode);
      }
    });
  }
}
