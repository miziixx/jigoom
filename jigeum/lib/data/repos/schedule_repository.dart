import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../db.dart';

const _uuid = Uuid();
const _kLastRoutineGen = 'last_routine_gen';

/// 하루 일정(일과) + 루틴.
class ScheduleRepository {
  ScheduleRepository(this.db);

  final AppDatabase db;

  // ------------------------------------------------------------- 일정
  Stream<List<Schedule>> watchForDate(DateTime date) {
    final d = dateOnly(date);
    final q = db.select(db.schedules)
      ..where((s) => s.date.equals(d))
      ..orderBy([(s) => OrderingTerm.asc(s.startMin)]);
    return q.watch();
  }

  Future<String> addSchedule({
    required DateTime date,
    required String title,
    String note = '',
    int color = 0,
    required int startMin,
    required int endMin,
    String? routineId,
  }) async {
    final id = _uuid.v4();
    await db.into(db.schedules).insert(SchedulesCompanion.insert(
          id: id,
          date: dateOnly(date),
          title: title,
          note: Value(note),
          color: Value(color),
          startMin: startMin,
          endMin: endMin,
          routineId: Value(routineId),
          createdAt: DateTime.now(),
        ));
    return id;
  }

  Future<void> updateSchedule(Schedule s) {
    return db.update(db.schedules).replace(s);
  }

  Future<void> toggleDone(String id, bool done) async {
    await (db.update(db.schedules)..where((s) => s.id.equals(id)))
        .write(SchedulesCompanion(done: Value(done)));
  }

  Future<void> deleteSchedule(String id) async {
    await (db.delete(db.schedules)..where((s) => s.id.equals(id))).go();
  }

  // ------------------------------------------------------------- 루틴
  Stream<List<Routine>> watchRoutines() {
    final q = db.select(db.routines)
      ..orderBy([(r) => OrderingTerm.asc(r.startMin)]);
    return q.watch();
  }

  Future<String> addRoutine({
    required String title,
    String note = '',
    int color = 0,
    required int startMin,
    required int endMin,
    String weekdays = '1,2,3,4,5,6,7',
  }) async {
    final id = _uuid.v4();
    await db.into(db.routines).insert(RoutinesCompanion.insert(
          id: id,
          title: title,
          note: Value(note),
          color: Value(color),
          startMin: startMin,
          endMin: endMin,
          weekdays: Value(weekdays),
          createdAt: DateTime.now(),
        ));
    // 오늘 요일에 해당하면 오늘 일정으로 바로 생성.
    await _materializeOne(id, todayDate());
    return id;
  }

  Future<void> setRoutineActive(String id, bool active) async {
    await (db.update(db.routines)..where((r) => r.id.equals(id)))
        .write(RoutinesCompanion(active: Value(active)));
  }

  Future<void> deleteRoutine(String id) async {
    await (db.delete(db.routines)..where((r) => r.id.equals(id))).go();
  }

  Future<void> _materializeOne(String routineId, DateTime date) async {
    final r = await (db.select(db.routines)
          ..where((x) => x.id.equals(routineId)))
        .getSingleOrNull();
    if (r == null || !r.active) return;
    final weekday = dateOnly(date).weekday; // 1=월 ~ 7=일
    if (!r.weekdays.split(',').contains('$weekday')) return;

    // 이미 그 날짜에 이 루틴으로 만든 일정이 있으면 skip.
    final exists = await (db.select(db.schedules)
          ..where((s) =>
              s.routineId.equals(routineId) & s.date.equals(dateOnly(date))))
        .getSingleOrNull();
    if (exists != null) return;

    await addSchedule(
      date: date,
      title: r.title,
      note: r.note,
      color: r.color,
      startMin: r.startMin,
      endMin: r.endMin,
      routineId: routineId,
    );
  }

  /// 앱 시작 시: 오늘 활성 루틴을 오늘 일정으로 생성 (하루 1회 가드).
  Future<void> generateTodayRoutines({DateTime? now}) async {
    final today = dateOnly(now ?? DateTime.now());
    final last = await _getSetting(_kLastRoutineGen);
    if (last == today.toIso8601String()) return;

    final routines = await (db.select(db.routines)
          ..where((r) => r.active.equals(true)))
        .get();
    for (final r in routines) {
      await _materializeOne(r.id, today);
    }
    await _setSetting(_kLastRoutineGen, today.toIso8601String());
  }

  Future<String?> _getSetting(String key) async {
    final row = await (db.select(db.settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _setSetting(String key, String value) async {
    await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value));
  }
}
