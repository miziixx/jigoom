/// 음성 실행 seam. 기획서 §6("voice_router 는 A~J 생성 로직을 호출만") + 커밋10.
///
/// 라우팅 결정([VoiceResult])을 받아 **실제 엔티티 생성/삭제**를 수행하는 경계.
/// 앱 계층(drift repository)이 이 인터페이스를 구현하고, [VoiceController] 는
/// 여기에만 의존한다 — 덕분에 오케스트레이션 로직은 프레임워크 없이 테스트된다.
library;

import 'models/voice_result.dart';

class VoiceExecutor {
  const VoiceExecutor();

  /// [result] 대로 A~J 입력지점에 엔티티를 만든다. 되돌리기용 참조(id 등)를
  /// 돌려준다(없으면 null). 앱 구현이 slots 를 각 repository 모델로 옮긴다.
  Future<Object?> createEntity(VoiceResult result) async => null;

  /// [ref] 로 방금 만든 엔티티를 되돌린다(삭제). 되돌리기(§9)에서 호출.
  Future<void> deleteEntity(VoiceResult result, Object? ref) async {}
}
