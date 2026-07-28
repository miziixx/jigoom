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
}
