import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 폰 캘린더(안드로이드 CalendarContract) 브리지 — 플러그인 없이 MethodChannel.
///
/// 폰에 이미 구글 계정으로 동기화된 캘린더를 앱이 직접 읽고 쓴다. 여기에 쓴
/// 이벤트는 OS 동기화 어댑터가 구글로 다시 올려준다(양방향). OAuth/GCP/SHA-1 불필요.
/// 필요한 건 READ_CALENDAR/WRITE_CALENDAR 런타임 권한뿐.
///
/// 시간은 epoch millis(로컬 기준 순간)로 주고받는다. 모든 진입점은 예외를 삼킨다.
class DeviceCalendarBridge {
  // 캘린더 네이티브 핸들러(calendarPermission/requestCalendarPermission/
  // listCalendars/queryEvents/insertEvent/updateEvent/deleteEvent)는
  // MainActivity 가 'jigeum/widget' 채널에 등록한다. 반드시 동일 채널이어야
  // 호출이 닿는다 — 예전엔 'jigeum/calendar' 로 어긋나 권한을 허용해도 앱이
  // 항상 '허용 안 함'으로 보던 버그가 있었다.
  static const _channel = MethodChannel('jigeum/widget');

  /// 캘린더 권한이 이미 허용됐는지(프롬프트 없이 확인).
  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('calendarPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 캘린더 권한 요청(시스템 팝업). 허용되면 true.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('requestCalendarPermission') ??
          false;
    } catch (e) {
      debugPrint('캘린더 권한 요청 실패: $e');
      return false;
    }
  }

  /// 폰의 캘린더 목록. 각 항목: {id,name,account,colorHex,accessRole,primary}.
  Future<List<Map<String, dynamic>>> calendars() async {
    if (kIsWeb) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listCalendars');
      return _normalizeList(raw);
    } catch (e) {
      debugPrint('캘린더 목록 실패: $e');
      return const [];
    }
  }

  /// 한 캘린더의 [startMs,endMs) 이벤트. 각 항목:
  /// {id,title,note,startMs,endMs,allDay}. 조회 자체가 실패하면 null
  /// (빈 캘린더의 []과 구분 — 실패를 "원격에서 다 지워짐"으로 오해하지 않도록).
  Future<List<Map<String, dynamic>>?> events(
      String calendarId, int startMs, int endMs) async {
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('queryEvents', {
        'calendarId': calendarId,
        'start': startMs,
        'end': endMs,
      });
      return _normalizeList(raw);
    } catch (e) {
      debugPrint('이벤트 조회 실패($calendarId): $e');
      return null;
    }
  }

  /// 이벤트 생성 → 새 이벤트 id(문자열). 실패 null.
  Future<String?> insert({
    required String calendarId,
    required String title,
    required String note,
    required int startMs,
    required int endMs,
    required bool allDay,
  }) async {
    if (kIsWeb) return null;
    try {
      final id = await _channel.invokeMethod<String>('insertEvent', {
        'calendarId': calendarId,
        'title': title,
        'note': note,
        'start': startMs,
        'end': endMs,
        'allDay': allDay,
      });
      return id;
    } catch (e) {
      debugPrint('이벤트 생성 실패: $e');
      return null;
    }
  }

  /// 이벤트 수정. 성공 true.
  Future<bool> update({
    required String eventId,
    required String title,
    required String note,
    required int startMs,
    required int endMs,
    required bool allDay,
  }) async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('updateEvent', {
            'eventId': eventId,
            'title': title,
            'note': note,
            'start': startMs,
            'end': endMs,
            'allDay': allDay,
          }) ??
          false;
    } catch (e) {
      debugPrint('이벤트 수정 실패: $e');
      return false;
    }
  }

  /// 이벤트 삭제. 이미 없으면 true 취급.
  Future<bool> delete(String eventId) async {
    if (kIsWeb) return false;
    try {
      return await _channel
              .invokeMethod<bool>('deleteEvent', {'eventId': eventId}) ??
          false;
    } catch (e) {
      debugPrint('이벤트 삭제 실패: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> _normalizeList(List<dynamic>? raw) {
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }
}
