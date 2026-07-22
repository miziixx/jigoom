import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repos/focus_session_repository.dart';

/// 집중 세션 진행 상태(경과 초 틱)를 들고 있는 컨트롤러.
/// 뷰가 initState 에서 생성하고 dispose 에서 정리한다. ChangeNotifier 라
/// ListenableBuilder 로 1초마다 경과 표시만 갱신한다(전역 rebuild 없음).
class FocusSessionController extends ChangeNotifier {
  FocusSessionController(this._repo);

  final FocusSessionRepository _repo;

  String? _sessionId;
  String? _nodeId;
  int? _plannedMinutes; // null = 몰입모드(무제한)
  int _elapsedSeconds = 0;
  bool _running = false;
  Timer? _timer;

  String? get sessionId => _sessionId;
  String? get nodeId => _nodeId;
  int? get plannedMinutes => _plannedMinutes;
  int get elapsedSeconds => _elapsedSeconds;
  bool get running => _running;

  bool get isImmersive => _plannedMinutes == null;
  int get plannedSeconds => (_plannedMinutes ?? 0) * 60;

  /// 카운트다운 모드의 남은 초 (몰입모드는 0).
  int get remainingSeconds => isImmersive
      ? 0
      : (plannedSeconds - _elapsedSeconds).clamp(0, plannedSeconds);

  /// 계획 시간을 채웠는지 (몰입모드는 항상 false).
  bool get reachedPlan => !isImmersive && _elapsedSeconds >= plannedSeconds;

  /// 세션 시작. 이미 실행 중이면 무시.
  Future<void> start({String? nodeId, int? plannedMinutes}) async {
    if (_running) return;
    _nodeId = nodeId;
    _plannedMinutes = plannedMinutes;
    _elapsedSeconds = 0;
    _sessionId = await _repo.start(nodeId: nodeId, plannedMinutes: plannedMinutes);
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  /// 세션 종료 + 실제 경과 기록. 종료된 sessionId 반환(후속 흐름용).
  /// 이미 종료됐으면 null.
  Future<String?> stop() async {
    if (!_running) return null;
    _timer?.cancel();
    _timer = null;
    _running = false;
    final id = _sessionId;
    if (id != null) {
      await _repo.end(id, _elapsedSeconds);
    }
    notifyListeners();
    return id;
  }

  /// 화면을 그냥 벗어날 때(시스템 뒤로가기 등) 조용히 종료만 기록.
  /// 리뷰/다음시작점 흐름 없이 세션 dangling 을 막는다. notify 하지 않음.
  void endSilently() {
    if (!_running) return;
    _timer?.cancel();
    _timer = null;
    _running = false;
    final id = _sessionId;
    if (id != null) {
      unawaited(_repo.end(id, _elapsedSeconds));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
