import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../db.dart';

const _uuid = Uuid();

/// 습관(해빗 트래커) CRUD + 체크 토글.
class HabitRepository {
  HabitRepository(this.db);

  final AppDatabase db;

  Stream<List<Habit>> watchHabits() {
    final q = db.select(db.habits)
      ..orderBy([(h) => OrderingTerm.asc(h.createdAt)]);
    return q.watch();
  }

  Stream<List<HabitTick>> watchTicks(String habitId) {
    final q = db.select(db.habitTicks)
      ..where((t) => t.habitId.equals(habitId));
    return q.watch();
  }

  Future<String> addHabit(String title) async {
    final id = _uuid.v4();
    await db.into(db.habits).insert(HabitsCompanion.insert(
          id: id,
          title: title,
          createdAt: todayDate(),
        ));
    return id;
  }

  Future<void> deleteHabit(String id) async {
    await (db.delete(db.habitTicks)..where((t) => t.habitId.equals(id))).go();
    await (db.delete(db.habits)..where((h) => h.id.equals(id))).go();
  }

  /// 해당 날짜 체크 토글. 반환 = 토글 후 체크 여부.
  Future<bool> toggleTick(String habitId, DateTime date) async {
    final d = dateOnly(date);
    final existing = await (db.select(db.habitTicks)
          ..where((t) => t.habitId.equals(habitId) & t.date.equals(d)))
        .getSingleOrNull();
    if (existing != null) {
      await (db.delete(db.habitTicks)
            ..where((t) => t.habitId.equals(habitId) & t.date.equals(d)))
          .go();
      return false;
    }
    await db.into(db.habitTicks).insert(
        HabitTicksCompanion.insert(habitId: habitId, date: d));
    return true;
  }
}
