import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/core/theme.dart';
import 'package:jigeum/features/inbox/inbox_repository.dart';
import 'package:jigeum/features/voice/models/voice_result.dart';
import 'package:jigeum/features/voice/ui/global_mic_button.dart';
import 'package:jigeum/features/voice/voice_controller.dart';
import 'package:jigeum/features/voice/voice_executor.dart';
import 'package:jigeum/features/voice/voice_router.dart';

import 'support/fake_stt_service.dart';

class _FakeExec extends VoiceExecutor {
  final created = <VoiceResult>[];

  @override
  Future<Object?> createEntity(VoiceResult result) async {
    created.add(result);
    return 'entity-${created.length}';
  }
}

void main() {
  late FakeSttService stt;
  late _FakeExec exec;
  late VoiceController controller;

  setUp(() {
    stt = FakeSttService();
    exec = _FakeExec();
    controller = VoiceController(
      router: VoiceRouter(),
      inbox: InMemoryInboxRepository(),
      executor: exec,
    );
  });

  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.fromKey('manila', systemFont: true),
      home: Scaffold(
        body: Center(
          child: GlobalMicButton(stt: stt, controller: controller),
        ),
      ),
    ));
  }

  testWidgets('탭하면 권한/가용성 확인 뒤 한국어 STT 를 시작한다', (tester) async {
    await pumpButton(tester);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();

    expect(stt.calls, ['isAvailable', 'requestPermission', 'start:ko_KR']);
    expect(find.text('듣는 중'), findsOneWidget);
  });

  testWidgets('STT 미지원이면 시작하지 않고 안내한다', (tester) async {
    stt.available = false;
    await pumpButton(tester);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();

    expect(stt.calls, ['isAvailable']);
    expect(find.textContaining('음성 인식을 찾지 못했어요'), findsOneWidget);
  });

  testWidgets('최종 인식 결과는 음성 컨트롤러로 전달된다', (tester) async {
    await pumpButton(tester);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    stt.emitFinal('블로그 글 구조 잡기', confidence: 0.8);
    await tester.pump();

    expect(exec.created.single.rawText, '블로그 글 구조 잡기');
    expect(find.textContaining('담았어요'), findsOneWidget);
  });
}
