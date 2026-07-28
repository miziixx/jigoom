import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../db.dart';

const _uuid = Uuid();

/// 루틴 블록(그룹) + 순서 스텝 저장소. 드래그 재정렬·하루 체크·연속(streak) 관리.
class RoutineBuilderRepository {
  RoutineBuilderRepository(this.db);

  final AppDatabase db;

  // ------------------------------------------------------------- 조회
  Stream<List<RoutineGroup>> watchGroups() {
    return (db.select(db.routineGroups)
          ..orderBy([
            (g) => OrderingTerm.asc(g.sortOrder),
            (g) => OrderingTerm.asc(g.createdAt),
          ]))
        .watch();
  }

  Stream<List<RoutineStep>> watchSteps() {
    return (db.select(db.routineSteps)
          ..orderBy([
            (s) => OrderingTerm.asc(s.sortOrder),
            (s) => OrderingTerm.asc(s.createdAt),
          ]))
        .watch();
  }

  // ------------------------------------------------------------- 블록
  Future<String> addGroup(String title) async {
    final id = _uuid.v4();
    final maxOrder = await _maxGroupOrder();
    await db.into(db.routineGroups).insert(RoutineGroupsCompanion.insert(
          id: id,
          title: title,
          sortOrder: Value(maxOrder + 1),
          createdAt: DateTime.now(),
        ));
    return id;
  }

  Future<void> renameGroup(String id, String title) =>
      (db.update(db.routineGroups)..where((g) => g.id.equals(id)))
          .write(RoutineGroupsCompanion(title: Value(title)));

  Future<void> setGroupCollapsed(String id, bool collapsed) =>
      (db.update(db.routineGroups)..where((g) => g.id.equals(id)))
          .write(RoutineGroupsCompanion(collapsed: Value(collapsed)));

  Future<void> deleteGroup(String id) async {
    await db.transaction(() async {
      await (db.delete(db.routineSteps)..where((s) => s.groupId.equals(id)))
          .go();
      await (db.delete(db.routineGroups)..where((g) => g.id.equals(id))).go();
    });
  }

  /// 블록 순서 재배치 — 화면에 보이는 순서대로 id 리스트를 준다.
  Future<void> reorderGroups(List<String> idsInOrder) async {
    await db.transaction(() async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await (db.update(db.routineGroups)
              ..where((g) => g.id.equals(idsInOrder[i])))
            .write(RoutineGroupsCompanion(sortOrder: Value(i)));
      }
    });
  }

  // ------------------------------------------------------------- 스텝
  Future<String> addStep(String groupId,
      {String trigger = '', required String title}) async {
    final id = _uuid.v4();
    final maxOrder = await _maxStepOrder(groupId);
    await db.into(db.routineSteps).insert(RoutineStepsCompanion.insert(
          id: id,
          groupId: groupId,
          sortOrder: Value(maxOrder + 1),
          trigger: Value(trigger),
          title: title,
          createdAt: DateTime.now(),
        ));
    return id;
  }

  Future<void> updateStep(String id,
          {required String trigger, required String title}) =>
      (db.update(db.routineSteps)..where((s) => s.id.equals(id))).write(
          RoutineStepsCompanion(trigger: Value(trigger), title: Value(title)));

  Future<void> deleteStep(String id) =>
      (db.delete(db.routineSteps)..where((s) => s.id.equals(id))).go();

  /// 스텝 순서 재배치(같은 블록 안) — 화면 순서대로 id 리스트.
  Future<void> reorderSteps(List<String> idsInOrder) async {
    await db.transaction(() async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await (db.update(db.routineSteps)
              ..where((s) => s.id.equals(idsInOrder[i])))
            .write(RoutineStepsCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// 스텝을 다른 블록으로 옮기며 순서까지 한 번에 반영.
  /// [stepIdsByGroup] = 화면에 보이는 그대로 (blockId → 그 안의 스텝 id 순서).
  Future<void> applyStepLayout(Map<String, List<String>> stepIdsByGroup) async {
    await db.transaction(() async {
      for (final entry in stepIdsByGroup.entries) {
        final ids = entry.value;
        for (var i = 0; i < ids.length; i++) {
          await (db.update(db.routineSteps)..where((s) => s.id.equals(ids[i])))
              .write(RoutineStepsCompanion(
                  groupId: Value(entry.key), sortOrder: Value(i)));
        }
      }
    });
  }

  /// 자주 쓰는 스텝 제목 — 지금까지 만든 스텝 중 많이 쓴 순서.
  /// (같은 블록에 이미 있는 제목은 [excludeInGroup] 으로 빼고 추천한다.)
  Future<List<String>> frequentStepTitles({
    String? excludeInGroup,
    int limit = 6,
  }) async {
    final rows = await db.select(db.routineSteps).get();
    final used = excludeInGroup == null
        ? const <String>{}
        : rows
            .where((s) => s.groupId == excludeInGroup)
            .map((s) => s.title.trim())
            .toSet();
    return _rank(
      rows.map((s) => s.title).toList(),
      // 아직 쓴 게 없을 때 보여줄 기본 추천.
      fallback: const ['물 한 잔', '스트레칭', '이불 정리', '오늘 할 일 3개', '산책', '일기'],
      exclude: used,
      limit: limit,
    );
  }

  /// 자주 쓰는 트리거 — "언제" 칸 추천.
  Future<List<String>> frequentTriggers({int limit = 6}) async {
    final rows = await db.select(db.routineSteps).get();
    return _rank(
      rows.map((s) => s.trigger).toList(),
      fallback: const ['눈 뜨면', '씻고 나서', '밥 먹고', '집 나서면', '집 오면', '자기 전'],
      limit: limit,
    );
  }

  /// 값들을 사용 횟수 내림차순으로 정렬해 상위 [limit] 개. 모자라면 [fallback] 로 채움.
  List<String> _rank(
    List<String> values, {
    required List<String> fallback,
    Set<String> exclude = const {},
    required int limit,
  }) {
    final counts = <String, int>{};
    for (final raw in values) {
      final v = raw.trim();
      if (v.isEmpty || exclude.contains(v)) continue;
      counts[v] = (counts[v] ?? 0) + 1;
    }
    final ranked = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    for (final f in fallback) {
      if (ranked.length >= limit) break;
      if (!counts.containsKey(f) && !exclude.contains(f)) ranked.add(f);
    }
    return ranked.take(limit).toList();
  }

  /// 하루 체크 토글. 오늘 완료면 해제, 아니면 완료 + 연속(streak) 갱신.
  Future<void> toggleStepDone(RoutineStep s) async {
    final today = todayDate();
    final done = s.lastDone != null && dateOnly(s.lastDone!) == today;
    if (done) {
      // 해제 — streak 1 줄이고 lastDone 을 어제(또는 없음)로.
      final newStreak = (s.streak - 1).clamp(0, 1 << 30);
      final back = newStreak > 0
          ? Value(today.subtract(const Duration(days: 1)))
          : const Value<DateTime?>(null);
      await (db.update(db.routineSteps)..where((x) => x.id.equals(s.id))).write(
          RoutineStepsCompanion(
              streak: Value(newStreak),
              lastDone: back,
              lastDoneAt: const Value(null)));
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      final continued =
          s.lastDone != null && dateOnly(s.lastDone!) == yesterday;
      final newStreak = continued ? s.streak + 1 : 1;
      await (db.update(db.routineSteps)..where((x) => x.id.equals(s.id))).write(
          RoutineStepsCompanion(
              streak: Value(newStreak),
              lastDone: Value(today),
              lastDoneAt: Value(DateTime.now())));
    }
  }

  // ------------------------------------------------------------- 헬퍼
  Future<int> _maxGroupOrder() async {
    final rows = await (db.select(db.routineGroups)
          ..orderBy([(g) => OrderingTerm.desc(g.sortOrder)])
          ..limit(1))
        .get();
    return rows.isEmpty ? 0 : rows.first.sortOrder;
  }

  Future<int> _maxStepOrder(String groupId) async {
    final rows = await (db.select(db.routineSteps)
          ..where((s) => s.groupId.equals(groupId))
          ..orderBy([(s) => OrderingTerm.desc(s.sortOrder)])
          ..limit(1))
        .get();
    return rows.isEmpty ? 0 : rows.first.sortOrder;
  }
}
