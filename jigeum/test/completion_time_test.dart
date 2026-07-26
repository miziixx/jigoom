import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/core/constants.dart';
import 'package:jigeum/data/db.dart';
import 'package:jigeum/data/repos/habit_repository.dart';
import 'package:jigeum/data/repos/node_repository.dart';
import 'package:jigeum/data/repos/routine_builder_repository.dart';
import 'package:jigeum/data/repos/schedule_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('할 일 완료 시간은 완료할 때 기록되고 다시 열면 지워진다', () async {
    final repo = NodeRepository(db);
    final id = await repo.create(
      type: NodeType.task,
      title: '완료 시간 확인',
      date: todayDate(),
    );

    await repo.complete(id);
    final done = await repo.findById(id);
    expect(done!.status, NodeStatus.done);
    expect(done.doneAt, isNotNull);

    await repo.reopen(id);
    final reopened = await repo.findById(id);
    expect(reopened!.status, NodeStatus.open);
    expect(reopened.doneAt, isNull);
  });

  test('습관 체크 시간은 체크할 때 기록되고 해제하면 틱이 사라진다', () async {
    final repo = HabitRepository(db);
    final habitId = await repo.addHabit('물 마시기');

    expect(await repo.toggleTick(habitId, todayDate()), isTrue);
    final tick = await (db.select(db.habitTicks)
          ..where(
              (t) => t.habitId.equals(habitId) & t.date.equals(todayDate())))
        .getSingle();
    expect(tick.completedAt, isNotNull);

    expect(await repo.toggleTick(habitId, todayDate()), isFalse);
    final ticks = await db.select(db.habitTicks).get();
    expect(ticks, isEmpty);
  });

  test('일정 완료 시간은 완료할 때 기록되고 취소하면 지워진다', () async {
    final repo = ScheduleRepository(db);
    final id = await repo.addSchedule(
      date: todayDate(),
      title: '아침 루틴',
      startMin: 8 * 60,
      endMin: 9 * 60,
    );

    await repo.toggleDone(id, true);
    final done = await (db.select(db.schedules)..where((s) => s.id.equals(id)))
        .getSingle();
    expect(done.done, isTrue);
    expect(done.doneAt, isNotNull);

    await repo.toggleDone(id, false);
    final reopened = await (db.select(db.schedules)
          ..where((s) => s.id.equals(id)))
        .getSingle();
    expect(reopened.done, isFalse);
    expect(reopened.doneAt, isNull);
  });

  test('루틴 스텝 완료 시간은 완료할 때 기록되고 해제하면 지워진다', () async {
    final repo = RoutineBuilderRepository(db);
    final groupId = await repo.addGroup('모닝');
    final stepId = await repo.addStep(groupId, title: '햇빛 보기');
    var step = await (db.select(db.routineSteps)
          ..where((s) => s.id.equals(stepId)))
        .getSingle();

    await repo.toggleStepDone(step);
    step = await (db.select(db.routineSteps)..where((s) => s.id.equals(stepId)))
        .getSingle();
    expect(step.lastDone, todayDate());
    expect(step.lastDoneAt, isNotNull);

    await repo.toggleStepDone(step);
    step = await (db.select(db.routineSteps)..where((s) => s.id.equals(stepId)))
        .getSingle();
    expect(step.lastDone, isNull);
    expect(step.lastDoneAt, isNull);
  });
}
