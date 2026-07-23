import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

/// 구글 로그인 + 캘린더 API 인증 클라이언트(싱글턴).
///
/// Android 는 GCP 콘솔에 등록한 OAuth 클라이언트(패키지명 `com.ziia.jigeum` +
/// 앱 서명 SHA-1)로 자동 매칭되므로 코드에 clientId 를 넣을 필요가 없다.
/// 설정 방법은 `docs/google-calendar-setup.md` 참고.
///
/// 모든 진입점은 예외를 삼켜 앱 흐름을 막지 않는다(연동은 부가 기능).
class GcalAuth {
  GcalAuth._();
  static final GcalAuth instance = GcalAuth._();

  /// 캘린더 읽기·쓰기 스코프. (읽기만 원하면 calendarReadonlyScope 로 축소 가능)
  final GoogleSignIn _google = GoogleSignIn(
    scopes: <String>[gcal.CalendarApi.calendarScope],
  );

  GoogleSignInAccount? _account;

  GoogleSignInAccount? get account => _account;
  bool get isConnected => _account != null;
  String? get email => _account?.email;
  String? get displayName => _account?.displayName;

  /// 앱 시작 시 이전 로그인 조용히 복구. 성공하면 true.
  Future<bool> restore() async {
    try {
      _account = await _google.signInSilently();
      return _account != null;
    } catch (e) {
      debugPrint('gcal restore 실패(무시): $e');
      return false;
    }
  }

  /// 사용자 상호작용 로그인(동의 화면). 성공하면 true.
  Future<bool> connect() async {
    try {
      _account = await _google.signIn();
      return _account != null;
    } catch (e) {
      debugPrint('gcal connect 실패: $e');
      return false;
    }
  }

  /// 연결 해제(토큰 회수 + 로그아웃).
  Future<void> disconnect() async {
    try {
      await _google.disconnect();
    } catch (_) {}
    try {
      await _google.signOut();
    } catch (_) {}
    _account = null;
  }

  /// 캘린더 스코프가 실제로 승인됐는지 확인(필요 시 요청).
  Future<bool> ensureScopes() async {
    try {
      final ok = await _google.requestScopes(
          <String>[gcal.CalendarApi.calendarScope]);
      return ok;
    } catch (e) {
      debugPrint('gcal ensureScopes 실패: $e');
      return false;
    }
  }

  /// 인증된 http 클라이언트. 로그인 안 됐으면 null.
  Future<http.Client?> authClient() async {
    var acc = _account;
    if (acc == null) {
      acc = await _google.signInSilently();
      _account = acc;
    }
    if (acc == null) return null;
    try {
      return await _google.authenticatedClient();
    } catch (e) {
      debugPrint('gcal authClient 실패: $e');
      return null;
    }
  }
}
