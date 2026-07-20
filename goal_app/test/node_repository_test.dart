import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_app/core/constants.dart';
import 'package:goal_app/data/db.dart';
import 'package:goal_app/data/repos/node_repository.dart';

void main() {
  late AppDatabase db;
  late NodeRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NodeRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('자동 이월', () {
    test('어제 open 노드를 오늘로 이동하고 carriedCount 증가', () async {
      final today = todayDate();
      final yesterday = today.subtract(const Duration(days: 1));
      final id = await repo.create(
        type: NodeType.task,
        title: '어제 할 일',
        important: true,
        date: yesterday,
      );

      final moved = await repo.runCarryOver();
      expect(moved, 1);

      final node = await repo.findById(id);
      expect(node!.date, today);
      expect(node.carriedCount, 1);
    });

    test('done 노드는 이월하지 않음', () async {
      final yesterday = todayDate().subtract(const Duration(days: 1));
      final id = await repo.create(
        type: NodeType.task,
        title: '어제 끝낸 것',
        important: true,
        date: yesterday,
      );
      await repo.complete(id);

      final moved = await repo.runCarryOver();
      expect(moved, 0);
      final node = await repo.findById(id);
      expect(node!.date, yesterday); // 그대로
    });

    test('하루 1회만 실행', () async {
      final yesterday = todayDate().subtract(const Duration(days: 1));
      await repo.create(
        type: NodeType.task,
        title: 'x',
        important: true,
        date: yesterday,
      );
      expect(await repo.runCarryOver(), 1);
      expect(await repo.runCarryOver(), 0); // 두 번째는 no-op
    });
  });

  group('포커스 선정', () {
    test('Q1(중요+긴급) 최우선', () async {
      await repo.create(
          type: NodeType.task, title: 'Q2', important: true, urgent: false);
      final q1 = await repo.create(
          type: NodeType.task, title: 'Q1', important: true, urgent: true);

      final focus = await repo.selectFocus();
      expect(focus!.id, q1);
    });

    test('Q1 없으면 Q2', () async {
      await repo.create(
          type: NodeType.task, title: 'Q3', important: false, urgent: true);
      final q2 = await repo.create(
          type: NodeType.task, title: 'Q2', important: true, urgent: false);

      final focus = await repo.selectFocus();
      expect(focus!.id, q2);
    });

    test('Q1/Q2 없으면 Q3', () async {
      final q3 = await repo.create(
          type: NodeType.task, title: 'Q3', important: false, urgent: true);
      final focus = await repo.selectFocus();
      expect(focus!.id, q3);
    });

    test('done 노드는 포커스 대상 아님', () async {
      final id = await repo.create(
          type: NodeType.task, title: 'Q1', important: true, urgent: true);
      await repo.complete(id);
      final focus = await repo.selectFocus();
      expect(focus, isNull);
    });
  });

  group('Q2 승격', () {
    test('중요+비긴급+날짜없음 중 최상단 1개에 오늘 날짜 부여', () async {
      final first = await repo.create(
          type: NodeType.task, title: 'Q2-1', important: true, urgent: false);
      await repo.create(
          type: NodeType.task, title: 'Q2-2', important: true, urgent: false);

      final promoted = await repo.promoteQ2();
      expect(promoted!.id, first);

      final node = await repo.findById(first);
      expect(node!.date, todayDate());
    });

    test('하루 1회만 승격', () async {
      await repo.create(
          type: NodeType.task, title: 'Q2', important: true, urgent: false);
      expect(await repo.promoteQ2(), isNotNull);
      expect(await repo.promoteQ2(), isNull); // 두 번째 no-op
    });

    test('Q2 없으면 null', () async {
      final promoted = await repo.promoteQ2();
      expect(promoted, isNull);
    });
  });

  group('Q4 자동 서랍', () {
    test('비중요+비긴급 task 는 drawer 상태', () async {
      final id = await repo.create(
          type: NodeType.task,
          title: '언젠가',
          important: false,
          urgent: false);
      final node = await repo.findById(id);
      expect(node!.status, NodeStatus.drawer);
    });

    test('중요 토글 시 open 으로 복귀', () async {
      final id = await repo.create(
          type: NodeType.task,
          title: '언젠가',
          important: false,
          urgent: false);
      await repo.setMatrix(id, important: true);
      final node = await repo.findById(id);
      expect(node!.status, NodeStatus.open);
    });
  });
}
