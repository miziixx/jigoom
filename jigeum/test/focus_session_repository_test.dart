import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/data/db.dart';
import 'package:jigeum/data/repos/focus_session_repository.dart';

void main() {
  late AppDatabase db;
  late FocusSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FocusSessionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('세션 시작/종료', () {
    test('start 는 세션을 만들고 계획 시간/노드를 기록', () async {
      final id = await repo.start(nodeId: 'node-1', plannedMinutes: 3);
      final s = await repo.findById(id);
      expect(s, isNotNull);
      expect(s!.nodeId, 'node-1');
      expect(s.plannedMinutes, 3);
      expect(s.endedAt, isNull);
      expect(s.actualSeconds, 0);
    });

    test('몰입모드는 plannedMinutes 가 null', () async {
      final id = await repo.start(plannedMinutes: null);
      final s = await repo.findById(id);
      expect(s!.plannedMinutes, isNull);
    });

    test('end 는 종료시각과 실제 경과 초를 기록', () async {
      final id = await repo.start(plannedMinutes: 10);
      await repo.end(id, 185);
      final s = await repo.findById(id);
      expect(s!.endedAt, isNotNull);
      expect(s.actualSeconds, 185);
    });
  });

  group('최근 평균 지속시간', () {
    test('표본이 minCount 미만이면 null', () async {
      final a = await repo.start(plannedMinutes: 3);
      await repo.end(a, 60);
      final b = await repo.start(plannedMinutes: 3);
      await repo.end(b, 120);
      // 2개뿐 → 기본 minCount=3 미만
      expect(await repo.averageActualMinutes(), isNull);
    });

    test('표본이 충분하면 실제 분 평균을 계산', () async {
      for (final sec in [60, 120, 180]) {
        final id = await repo.start(plannedMinutes: 3);
        await repo.end(id, sec);
      }
      // (60+120+180)/3 = 120초 = 2.0분
      final avg = await repo.averageActualMinutes();
      expect(avg, isNotNull);
      expect(avg, closeTo(2.0, 1e-9));
    });

    test('종료 안 됐거나 0초인 세션은 평균에서 제외', () async {
      // 완료 3개(각 120초=2분)
      for (var i = 0; i < 3; i++) {
        final id = await repo.start(plannedMinutes: 3);
        await repo.end(id, 120);
      }
      // 미종료 1개 + 0초 종료 1개 → 무시돼야 함
      await repo.start(plannedMinutes: 3); // 미종료
      final zero = await repo.start(plannedMinutes: 3);
      await repo.end(zero, 0);

      final avg = await repo.averageActualMinutes();
      expect(avg, closeTo(2.0, 1e-9));
    });
  });
}
