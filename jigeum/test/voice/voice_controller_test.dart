// 커밋10 로직 — 오케스트레이션(실행/보류/되돌리기/다르게담기). 위젯 없음.
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/inbox/inbox_repository.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';
import 'package:jigeum/features/voice/models/voice_result.dart';
import 'package:jigeum/features/voice/voice_controller.dart';
import 'package:jigeum/features/voice/voice_executor.dart';
import 'package:jigeum/features/voice/voice_router.dart';

class _FakeExec extends VoiceExecutor {
  final List<VoiceResult> created = [];
  final List<Object?> deleted = [];
  int _n = 0;
  @override
  Future<Object?> createEntity(VoiceResult r) async {
    created.add(r);
    return 'e${_n++}';
  }

  @override
  Future<void> deleteEntity(VoiceResult r, Object? ref) async {
    deleted.add(ref);
  }
}

void main() {
  final base = DateTime(2026, 7, 24);
  late InMemoryInboxRepository inbox;
  late _FakeExec exec;
  late VoiceController c;

  setUp(() {
    inbox = InMemoryInboxRepository();
    exec = _FakeExec();
    c = VoiceController(router: VoiceRouter(), inbox: inbox, executor: exec);
  });

  test('미인식 → 보류함 저장, 실행기 미호출', () async {
    final fb = await c.handle('어… 그거 있잖아 뭐였지', now: base);
    expect(fb.message, '보류함에 담았어요');
    expect(exec.created, isEmpty);
    expect(inbox.pendingCount, 1);
    expect(fb.undoable, isTrue);
  });

  test('확정 → 실행기로 생성 + 확정 피드백', () async {
    final fb = await c.handle('내일 3시에 치과 예약', now: base);
    expect(fb.message, '일정에 담았어요');
    expect(exec.created.length, 1);
    expect(exec.created.single.slots.title, '치과');
    expect(fb.reclassifyTo, isNotEmpty); // 다르게 담기 칩
  });

  test('되돌리기 → 엔티티 삭제 + 원문 보류함 복원', () async {
    await c.handle('내일 3시에 치과 예약', now: base);
    await c.undo();
    expect(exec.deleted.length, 1);
    expect(inbox.list().single.rawText, '내일 3시에 치과 예약');
    expect(c.lastExecution, isNull);
  });

  test('다르게 담기 → 취소 + 재생성 + 학습', () async {
    await c.handle('파란색 그거 처리', now: base); // todoAdd → A
    final fb = await c.reclassifyLast(RoutePoint.matrix);
    expect(fb.message, '매트릭스(으)로 옮겼어요');
    expect(exec.deleted.length, 1); // 기존 취소
    expect(exec.created.length, 2); // 최초 + 재분류
    expect(exec.created.last.routedTo, RoutePoint.matrix);
    expect(exec.created.last.intent, IntentType.todoMatrix);
  });

  test('쏟아내기 드래그 → 매트릭스 사분면 축을 슬롯에 저장', () {
    final staged = c.classify('블로그 글 구조 잡기', now: base);
    final moved = c.rerouteToMatrixQuadrant(
      staged,
      important: true,
      urgent: false,
    );

    expect(moved.routedTo, RoutePoint.matrix);
    expect(moved.intent, IntentType.todoMatrix);
    expect(moved.slots.important, isTrue);
    expect(moved.slots.urgent, isFalse);
  });

  test('긴 중얼거림 → 여러 조각으로 나눠 각각 담기', () async {
    final fb = await c.handle(
      '내일 3시에 치과 예약하고 장보기 넣고 중요한 보고서 정리 해야 되고 아침 루틴에 스트레칭 추가',
      now: base,
    );

    expect(fb.message, contains('4개로 나눠 담았어요'));
    expect(exec.created.length, 4);
    expect(exec.created.map((r) => r.rawText), [
      '내일 3시에 치과 예약',
      '장보기',
      '중요한 보고서 정리',
      '아침 루틴에 스트레칭 추가',
    ]);
    expect(exec.created.map((r) => r.routedTo), contains(RoutePoint.schedule));
    expect(exec.created.map((r) => r.routedTo), contains(RoutePoint.matrix));
    expect(exec.created.map((r) => r.routedTo), contains(RoutePoint.routine));
  });

  test('빼고/말고 말투 → 제외 조각은 만들지 않음', () async {
    final fb = await c.handle(
      '치과 예약 빼고 장보기 넣고 물 마시기 습관 만들어',
      now: base,
    );

    expect(fb.message, contains('1개 제외'));
    expect(exec.created.map((r) => r.rawText), ['장보기', '물 마시기 습관 만들어']);
  });

  test('멀티 담기 되돌리기 → 만든 항목들을 모두 삭제', () async {
    await c.handle('장보기 넣고 중요한 보고서 정리 해야 되고', now: base);

    await c.undo();

    expect(exec.created.length, 2);
    expect(exec.deleted, ['e1', 'e0']);
  });
}
