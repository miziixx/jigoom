import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as g;

import 'gcal_auth.dart';

/// 캘린더 API 얇은 래퍼 — 캘린더 목록 + 이벤트 CRUD + 증분 동기화.
class GcalApi {
  Future<g.CalendarApi?> _api() async {
    final client = await GcalAuth.instance.authClient();
    if (client == null) return null;
    return g.CalendarApi(client);
  }

  /// 내 캘린더 목록.
  Future<List<g.CalendarListEntry>> calendars() async {
    final api = await _api();
    if (api == null) return const [];
    try {
      final list = await api.calendarList.list(showHidden: false);
      return list.items ?? const [];
    } catch (e) {
      debugPrint('gcal calendars 실패: $e');
      return const [];
    }
  }

  /// 캘린더의 이벤트를 증분(syncToken)으로 가져온다. 페이지 전체를 모은 뒤
  /// (events, nextSyncToken) 반환. syncToken 만료(410)면 전체 재동기화로 자동 폴백.
  Future<GcalPull> pull(
    String calendarId, {
    String? syncToken,
    DateTime? timeMin,
  }) async {
    final api = await _api();
    if (api == null) return const GcalPull([], null, false);

    final all = <g.Event>[];
    String? pageToken;
    String? next;
    var token = syncToken;
    var expired = false;

    while (true) {
      g.Events resp;
      try {
        resp = await api.events.list(
          calendarId,
          syncToken: token,
          pageToken: pageToken,
          singleEvents: true,
          // 전체 동기화일 때만 기간 필터. 증분(token)일 땐 필터 금지(400).
          timeMin: token == null ? timeMin?.toUtc() : null,
          maxResults: 250,
        );
      } on g.DetailedApiRequestError catch (e) {
        if (e.status == 410 && token != null) {
          // syncToken 만료 → 처음부터 전체 재동기화.
          token = null;
          pageToken = null;
          next = null;
          expired = true;
          all.clear();
          continue;
        }
        debugPrint('gcal pull 실패($calendarId): $e');
        rethrow;
      }
      all.addAll(resp.items ?? const []);
      next = resp.nextSyncToken ?? next;
      pageToken = resp.nextPageToken;
      if (pageToken == null) break;
    }
    return GcalPull(all, next, expired);
  }

  Future<g.Event?> insert(String calendarId, g.Event event) async {
    final api = await _api();
    if (api == null) return null;
    return api.events.insert(event, calendarId);
  }

  Future<g.Event?> patch(
      String calendarId, String eventId, g.Event event) async {
    final api = await _api();
    if (api == null) return null;
    return api.events.patch(event, calendarId, eventId);
  }

  Future<void> delete(String calendarId, String eventId) async {
    final api = await _api();
    if (api == null) return;
    try {
      await api.events.delete(calendarId, eventId);
    } on g.DetailedApiRequestError catch (e) {
      if (e.status == 404 || e.status == 410) return; // 이미 없음 → 성공 취급
      rethrow;
    }
  }
}

/// pull 결과. [expired] 는 syncToken 만료로 전체 재동기화가 일어났는지.
@immutable
class GcalPull {
  const GcalPull(this.events, this.nextSyncToken, this.expired);
  final List<g.Event> events;
  final String? nextSyncToken;
  final bool expired;
}
