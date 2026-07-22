import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';

const _uuid = Uuid();

/// 집중 세션(적응형 타임박싱) CRUD + 최근 실제 지속시간 평균.
///
/// 에세이의 "먼저 측정 → 기본값 제안"을 가볍게 반영: 버튼 시간을 자동으로
/// 바꾸진 않고 [averageActualMinutes] 를 힌트 텍스트로만 노출한다.
class FocusSessionRepository {
  FocusSessionRepository(this.db);

  final AppDatabase db;

  /// 세션 시작 — 새 FocusSession row 생성 후 id 반환.
  /// plannedMinutes=null 이면 몰입모드(무제한).
  Future<String> start({String? nodeId, int? plannedMinutes}) async {
    final id = _uuid.v4();
    await db.into(db.focusSessions).insert(FocusSessionsCompanion.insert(
          id: id,
          nodeId: Value(nodeId),
          plannedMinutes: Value(plannedMinutes),
          startedAt: DateTime.now(),
        ));
    return id;
  }

  /// 세션 종료 — endedAt + 실제 경과 초 기록.
  Future<void> end(String id, int actualSeconds) async {
    await (db.update(db.focusSessions)..where((s) => s.id.equals(id))).write(
      FocusSessionsCompanion(
        endedAt: Value(DateTime.now()),
        actualSeconds: Value(actualSeconds),
      ),
    );
  }

  Future<FocusSession?> findById(String id) {
    return (db.select(db.focusSessions)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  /// 최근 종료된 세션들의 실제 지속시간(분) 평균. 데이터 없으면 null.
  /// [minCount] 개 미만이면(표본 부족) null 을 반환해 성급한 힌트를 피한다.
  Future<double?> averageActualMinutes({int recent = 10, int minCount = 3}) async {
    final q = db.select(db.focusSessions)
      ..where((s) => s.endedAt.isNotNull() & s.actualSeconds.isBiggerThanValue(0))
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
      ..limit(recent);
    final rows = await q.get();
    if (rows.length < minCount) return null;
    final totalSec =
        rows.fold<int>(0, (sum, s) => sum + s.actualSeconds);
    return totalSec / rows.length / 60.0;
  }
}
