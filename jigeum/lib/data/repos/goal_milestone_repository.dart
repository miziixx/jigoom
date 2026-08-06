import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';

const _uuid = Uuid();

/// 목표 마일스톤(단계) CRUD. 추가형 테이블 — 기존 목표/할 일 데이터엔 손대지 않는다.
/// 마일스톤이 하나도 없으면 화면은 기존처럼 하위 할 일 완료에서 여정을 유도한다.
class GoalMilestoneRepository {
  GoalMilestoneRepository(this.db);

  final AppDatabase db;

  /// 한 목표의 마일스톤들 (정렬 순서 → 생성 순).
  Stream<List<GoalMilestone>> watchForGoal(String goalId) {
    final q = db.select(db.goalMilestones)
      ..where((m) => m.goalId.equals(goalId))
      ..orderBy([
        (m) => OrderingTerm.asc(m.sortOrder),
        (m) => OrderingTerm.asc(m.createdAt),
      ]);
    return q.watch();
  }

  Future<List<GoalMilestone>> listForGoal(String goalId) {
    final q = db.select(db.goalMilestones)
      ..where((m) => m.goalId.equals(goalId))
      ..orderBy([
        (m) => OrderingTerm.asc(m.sortOrder),
        (m) => OrderingTerm.asc(m.createdAt),
      ]);
    return q.get();
  }

  /// 마일스톤 추가 — 맨 뒤(가장 큰 sortOrder + 1)에 붙인다.
  Future<String> add(String goalId, String title, {DateTime? targetDate}) async {
    final id = _uuid.v4();
    final existing = await listForGoal(goalId);
    final nextOrder =
        existing.isEmpty ? 0 : existing.map((m) => m.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await db.into(db.goalMilestones).insert(GoalMilestonesCompanion.insert(
          id: id,
          goalId: goalId,
          title: title,
          sortOrder: Value(nextOrder),
          targetDate: Value(targetDate),
          createdAt: DateTime.now(),
        ));
    return id;
  }

  Future<void> rename(String id, String title) async {
    await (db.update(db.goalMilestones)..where((m) => m.id.equals(id)))
        .write(GoalMilestonesCompanion(title: Value(title)));
  }

  Future<void> setTargetDate(String id, DateTime? targetDate) async {
    await (db.update(db.goalMilestones)..where((m) => m.id.equals(id)))
        .write(GoalMilestonesCompanion(targetDate: Value(targetDate)));
  }

  /// 완료 토글 — 완료로 바꾸면 그 마일스톤은 '현재(isCurrent)' 표시를 내린다.
  Future<void> setCompleted(String id, bool completed) async {
    await (db.update(db.goalMilestones)..where((m) => m.id.equals(id))).write(
      GoalMilestonesCompanion(
        completedAt: Value(completed ? DateTime.now() : null),
        isCurrent: completed ? const Value(false) : const Value.absent(),
      ),
    );
  }

  /// 한 마일스톤을 '현재 단계'로 지정 — 같은 목표의 다른 마일스톤 현재 표시는 내린다.
  Future<void> setCurrent(String goalId, String id) async {
    await db.transaction(() async {
      await (db.update(db.goalMilestones)..where((m) => m.goalId.equals(goalId)))
          .write(const GoalMilestonesCompanion(isCurrent: Value(false)));
      await (db.update(db.goalMilestones)..where((m) => m.id.equals(id)))
          .write(const GoalMilestonesCompanion(isCurrent: Value(true)));
    });
  }

  Future<void> delete(String id) async {
    await (db.delete(db.goalMilestones)..where((m) => m.id.equals(id))).go();
  }

  /// 새 순서로 sortOrder 재부여 (드래그 정렬 후).
  Future<void> reorder(List<String> orderedIds) async {
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (db.update(db.goalMilestones)..where((m) => m.id.equals(orderedIds[i])))
            .write(GoalMilestonesCompanion(sortOrder: Value(i)));
      }
    });
  }
}
