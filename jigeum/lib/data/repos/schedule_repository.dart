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
      ..where((s) => s.date.equals(d) & s.deleted.equals(false))
      ..orderBy([(s) => OrderingTerm.asc(s.startMin)]);
    return q.watch();
  }

  /// 전체 일정 변경 스트림 — 구글 동기화 트리거용(디바운스해서 사용).
  Stream<List<Schedule>> watchAll() => db.select(db.schedules).watch();

  /// 기간(start~end, 포함) 일정 — 달력 점 표시용.
  Stream<List<Schedule>> watchForRange(DateTime start, DateTime end) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    final q = db.select(db.schedules)
      ..where((x) =>
          x.date.isBiggerOrEqualValue(s) &
          x.date.isSmallerOrEqualValue(e) &
          x.deleted.equals(false))
      ..orderBy([(x) => OrderingTerm.asc(x.date)]);
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
    bool allDay = false,
    String? gcalCalendarId,
    String? gcalId,
    String? gcalEtag,
    bool dirty = true, // 로컬 생성 → 원격에 밀어야 함(기본). 원격에서 온 건 false.
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
          allDay: Value(allDay),
          gcalCalendarId: Value(gcalCalendarId),
          gcalId: Value(gcalId),
          gcalEtag: Value(gcalEtag),
          dirty: Value(dirty),
          updatedAt: Value(DateTime.now()),
        ));
    return id;
  }

  /// 로컬 수정 — dirty 표시 + updatedAt 갱신(원격으로 밀리도록).
  Future<void> updateSchedule(Schedule s) {
    return db.update(db.schedules).replace(
          s.copyWith(dirty: true, updatedAt: Value(DateTime.now())),
        );
  }

  Future<void> toggleDone(String id, bool done) async {
    await (db.update(db.schedules)..where((s) => s.id.equals(id))).write(
        SchedulesCompanion(
            done: Value(done),
            dirty: const Value(true),
            updatedAt: Value(DateTime.now())));
  }

  /// 삭제. 원격과 연결된(gcalId) 일정은 툼스톤으로 남겨 동기화 때 원격도 지운다.
  Future<void> deleteSchedule(String id) async {
    final row = await (db.select(db.schedules)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    if (row != null && row.gcalId != null) {
      await (db.update(db.schedules)..where((s) => s.id.equals(id))).write(
          SchedulesCompanion(
              deleted: const Value(true),
              dirty: const Value(true),
              updatedAt: Value(DateTime.now())));
    } else {
      await (db.delete(db.schedules)..where((s) => s.id.equals(id))).go();
    }
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
      dirty: false, // 루틴 자동 생성분은 원격에 밀지 않음(로컬 전용).
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

  // 오늘의 목표(날짜별 자유 텍스트) — kv settings 재사용.
  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<String?> getDayGoal(DateTime d) => _getSetting('day_goal_${_ymd(d)}');

  Future<void> setDayGoal(DateTime d, String value) =>
      _setSetting('day_goal_${_ymd(d)}', value);
}
