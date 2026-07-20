import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../db.dart';

const _uuid = Uuid();
const _kLastCarryDate = 'last_carry_date';
const _kLastPromoteDate = 'last_promote_date';

/// 모든 노드 CRUD + 핵심 비즈니스 규칙.
///
/// 규칙 요약 (기획서 §3):
///  1. 삭제 대신 상태 전이 (done + doneAt)
///  2. 자동 이월 (조용히)
///  3. Q4 자동 서랍
///  4. 포커스 선정
///  5. Q2 아침 승격
class NodeRepository {
  NodeRepository(this.db);

  final AppDatabase db;

  // ---------------------------------------------------------------------------
  // 기본 조회
  // ---------------------------------------------------------------------------

  Stream<List<Node>> watchAll() => db.select(db.nodes).watch();

  Stream<List<Node>> watchInbox() {
    final q = db.select(db.nodes)
      ..where((n) =>
          n.parentId.isNull() &
          n.type.equals(NodeType.memo) &
          n.status.equals(NodeStatus.open))
      ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]);
    return q.watch();
  }

  Stream<List<Node>> watchChildren(String parentId) {
    final q = db.select(db.nodes)
      ..where((n) => n.parentId.equals(parentId))
      ..orderBy([(n) => OrderingTerm.asc(n.sortOrder)]);
    return q.watch();
  }

  Stream<List<Node>> watchRoots() {
    final q = db.select(db.nodes)
      ..where((n) => n.parentId.isNull())
      ..orderBy([(n) => OrderingTerm.asc(n.sortOrder)]);
    return q.watch();
  }

  Stream<List<Node>> watchForDate(DateTime date) {
    final d = dateOnly(date);
    final q = db.select(db.nodes)
      ..where((n) => n.date.equals(d) & n.status.equals(NodeStatus.open))
      ..orderBy([(n) => OrderingTerm.asc(n.sortOrder)]);
    return q.watch();
  }

  Stream<List<Node>> watchWinsForDate(DateTime date) {
    final start = dateOnly(date);
    final end = start.add(const Duration(days: 1));
    final q = db.select(db.nodes)
      ..where((n) =>
          n.status.equals(NodeStatus.done) &
          n.doneAt.isBiggerOrEqualValue(start) &
          n.doneAt.isSmallerThanValue(end))
      ..orderBy([(n) => OrderingTerm.desc(n.doneAt)]);
    return q.watch();
  }

  Future<Node?> findById(String id) {
    return (db.select(db.nodes)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // 생성 / 수정
  // ---------------------------------------------------------------------------

  Future<String> create({
    String? parentId,
    required String type,
    required String title,
    String note = '',
    bool important = false,
    bool urgent = false,
    DateTime? date,
    String? slot,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final order = await _nextSortOrder(parentId);

    // Q4 자동 서랍: task 이면서 important=false, urgent=false → drawer
    var status = NodeStatus.open;
    if (type == NodeType.task && !important && !urgent) {
      status = NodeStatus.drawer;
    }

    await db.into(db.nodes).insert(NodesCompanion.insert(
          id: id,
          parentId: Value(parentId),
          sortOrder: order,
          type: type,
          title: title,
          note: Value(note),
          important: Value(important),
          urgent: Value(urgent),
          date: Value(date == null ? null : dateOnly(date)),
          slot: Value(slot),
          status: Value(status),
          createdAt: now,
          updatedAt: now,
        ));
    return id;
  }

  Future<void> updateNode(Node node) {
    return db.update(db.nodes).replace(node.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> setTitle(String id, String title) async {
    await (db.update(db.nodes)..where((n) => n.id.equals(id))).write(
      NodesCompanion(title: Value(title), updatedAt: Value(DateTime.now())),
    );
  }

  /// 중요/긴급 토글. Q4 규칙에 따라 status 재계산.
  Future<void> setMatrix(String id, {bool? important, bool? urgent}) async {
    final node = await findById(id);
    if (node == null) return;
    final imp = important ?? node.important;
    final urg = urgent ?? node.urgent;

    var status = node.status;
    // done 상태는 건드리지 않음.
    if (node.status != NodeStatus.done && node.type == NodeType.task) {
      status = (!imp && !urg) ? NodeStatus.drawer : NodeStatus.open;
    }

    await (db.update(db.nodes)..where((n) => n.id.equals(id))).write(
      NodesCompanion(
        important: Value(imp),
        urgent: Value(urg),
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 완료 처리 — 삭제하지 않고 상태 전이. (규칙 1)
  Future<void> complete(String id) async {
    await (db.update(db.nodes)..where((n) => n.id.equals(id))).write(
      NodesCompanion(
        status: const Value(NodeStatus.done),
        doneAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reopen(String id) async {
    await (db.update(db.nodes)..where((n) => n.id.equals(id))).write(
      NodesCompanion(
        status: const Value(NodeStatus.open),
        doneAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 내일로 미루기 (스와이프 좌).
  Future<void> pushToTomorrow(String id) async {
    final tomorrow = todayDate().add(const Duration(days: 1));
    await (db.update(db.nodes)..where((n) => n.id.equals(id))).write(
      NodesCompanion(
        date: Value(tomorrow),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setDate(String id, DateTime? date, {String? slot}) async {
    await (db.update(db.nodes)..where((n) => n.id.equals(id))).write(
      NodesCompanion(
        date: Value(date == null ? null : dateOnly(date)),
        slot: Value(slot),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reorder(String id, int sortOrder) async {
    await (db.update(db.nodes)..where((n) => n.id.equals(id))).write(
      NodesCompanion(
        sortOrder: Value(sortOrder),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> _nextSortOrder(String? parentId) async {
    final q = db.selectOnly(db.nodes)
      ..addColumns([db.nodes.sortOrder.max()]);
    if (parentId == null) {
      q.where(db.nodes.parentId.isNull());
    } else {
      q.where(db.nodes.parentId.equals(parentId));
    }
    final row = await q.getSingleOrNull();
    final maxVal = row?.read(db.nodes.sortOrder.max());
    return (maxVal ?? -1) + 1;
  }

  // ---------------------------------------------------------------------------
  // 규칙 2: 자동 이월
  // ---------------------------------------------------------------------------

  /// date < today AND status='open' 인 노드를 오늘로 이동, carriedCount += 1.
  /// 하루 1회만 수행. 반환값 = 이월된 개수.
  Future<int> runCarryOver({DateTime? now}) async {
    final today = dateOnly(now ?? DateTime.now());

    final last = await _getSetting(_kLastCarryDate);
    if (last == today.toIso8601String()) return 0;

    final overdue = await (db.select(db.nodes)
          ..where((n) =>
              n.date.isSmallerThanValue(today) &
              n.status.equals(NodeStatus.open)))
        .get();

    for (final n in overdue) {
      await (db.update(db.nodes)..where((x) => x.id.equals(n.id))).write(
        NodesCompanion(
          date: Value(today),
          carriedCount: Value(n.carriedCount + 1),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    await _setSetting(_kLastCarryDate, today.toIso8601String());
    return overdue.length;
  }

  // ---------------------------------------------------------------------------
  // 규칙 4: 포커스 선정
  // ---------------------------------------------------------------------------

  /// 오늘 뷰 최상단 1개.
  ///  Q1(중요+긴급) 중 sortOrder 최상단 → 없으면 오늘의 Q2 추천 → 없으면 Q3.
  Future<Node?> selectFocus({DateTime? now}) async {
    final today = dateOnly(now ?? DateTime.now());

    Future<Node?> topOf(bool imp, bool urg) async {
      final q = db.select(db.nodes)
        ..where((n) =>
            n.status.equals(NodeStatus.open) &
            n.type.equals(NodeType.task) &
            n.important.equals(imp) &
            n.urgent.equals(urg) &
            (n.date.equals(today) | n.date.isNull()))
        ..orderBy([(n) => OrderingTerm.asc(n.sortOrder)])
        ..limit(1);
      return q.getSingleOrNull();
    }

    // Q1: 중요+긴급
    final q1 = await topOf(true, true);
    if (q1 != null) return q1;

    // Q2: 중요+비긴급 (오늘의 추천)
    final q2 = await topOf(true, false);
    if (q2 != null) return q2;

    // Q3: 비중요+긴급
    final q3 = await topOf(false, true);
    return q3;
  }

  // ---------------------------------------------------------------------------
  // 규칙 4/5: Q2 아침 승격
  // ---------------------------------------------------------------------------

  /// 앱 오픈 시점(콜드 스타트/resume)에 lastPromotedDate != today 이면
  /// Q2에서 1개를 '오늘의 추천'으로 승격 (date=today 부여) 후 날짜 기록.
  /// 시각 트리거 대신 날짜 비교라 언제 열어도 하루 1회 보장.
  /// 반환값 = 승격된 노드 (없으면 null).
  Future<Node?> promoteQ2({DateTime? now}) async {
    final today = dateOnly(now ?? DateTime.now());

    final last = await _getSetting(_kLastPromoteDate);
    if (last == today.toIso8601String()) return null;

    final q2 = db.select(db.nodes)
      ..where((n) =>
          n.status.equals(NodeStatus.open) &
          n.type.equals(NodeType.task) &
          n.important.equals(true) &
          n.urgent.equals(false) &
          n.date.isNull())
      ..orderBy([(n) => OrderingTerm.asc(n.sortOrder)])
      ..limit(1);

    final pick = await q2.getSingleOrNull();
    await _setSetting(_kLastPromoteDate, today.toIso8601String());

    if (pick == null) return null;
    await (db.update(db.nodes)..where((n) => n.id.equals(pick.id))).write(
      NodesCompanion(date: Value(today), updatedAt: Value(DateTime.now())),
    );
    return pick.copyWith(date: Value(today));
  }

  // ---------------------------------------------------------------------------
  // 매트릭스 조회
  // ---------------------------------------------------------------------------

  /// 사분면별 open task 스트림. (important, urgent) 로 분류.
  Stream<List<Node>> watchQuadrant({required bool important, required bool urgent}) {
    final q = db.select(db.nodes)
      ..where((n) =>
          n.type.equals(NodeType.task) &
          n.important.equals(important) &
          n.urgent.equals(urgent) &
          (urgent || important
              ? n.status.equals(NodeStatus.open)
              : n.status.equals(NodeStatus.drawer)))
      ..orderBy([(n) => OrderingTerm.asc(n.sortOrder)]);
    return q.watch();
  }

  // ---------------------------------------------------------------------------
  // settings helpers
  // ---------------------------------------------------------------------------

  Future<String?> _getSetting(String key) async {
    final row = await (db.select(db.settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<String?> getSetting(String key) => _getSetting(key);

  Future<void> _setSetting(String key, String value) async {
    await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value));
  }

  Future<void> setSetting(String key, String value) => _setSetting(key, value);
}
