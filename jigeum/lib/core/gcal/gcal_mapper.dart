import 'package:googleapis/calendar/v3.dart' as g;

import '../../data/db.dart';
import '../constants.dart';

/// 로컬 [Schedule] ↔ 구글 [g.Event] 변환.
///
/// 시각은 UTC(Z) 로 주고받아 표준시 해석을 명확히 한다. 종일 이벤트는
/// start.date/end.date(끝은 배타적, 다음날)로 표현한다.
class GcalMapper {
  /// 로컬 일정 → 원격 이벤트 바디(생성·수정용).
  static g.Event toEvent(Schedule s) {
    final e = g.Event()
      ..summary = s.title
      ..description = s.note.isEmpty ? null : s.note;

    final day = dateOnly(s.date);
    if (s.allDay) {
      e.start = g.EventDateTime()..date = day;
      e.end = g.EventDateTime()..date = day.add(const Duration(days: 1));
    } else {
      final start = DateTime(day.year, day.month, day.day)
          .add(Duration(minutes: s.startMin));
      var endMin = s.endMin;
      if (endMin <= s.startMin) endMin = s.startMin + 30; // 최소 30분 보장
      final end = DateTime(day.year, day.month, day.day)
          .add(Duration(minutes: endMin));
      e.start = g.EventDateTime()..dateTime = start.toUtc();
      e.end = g.EventDateTime()..dateTime = end.toUtc();
    }
    return e;
  }

  /// 원격 이벤트 → 로컬 필드. 취소(cancelled)면 [RemoteEvent.cancelled]=true.
  /// 시간/날짜가 없는 비정상 이벤트는 null.
  static RemoteEvent? fromEvent(g.Event e) {
    final id = e.id;
    if (id == null) return null;
    final cancelled = e.status == 'cancelled';
    if (cancelled) {
      return RemoteEvent(
        gcalId: id,
        etag: e.etag,
        cancelled: true,
        date: dateOnly(DateTime.now()),
        startMin: 0,
        endMin: 0,
        allDay: false,
        title: e.summary ?? '',
        note: e.description ?? '',
      );
    }

    final start = e.start;
    final end = e.end;
    if (start == null) return null;

    if (start.date != null) {
      // 종일 이벤트.
      final day = dateOnly(start.date!.toLocal());
      return RemoteEvent(
        gcalId: id,
        etag: e.etag,
        cancelled: false,
        date: day,
        startMin: 0,
        endMin: 0,
        allDay: true,
        title: e.summary ?? '(제목 없음)',
        note: e.description ?? '',
      );
    }

    final startDt = start.dateTime?.toLocal();
    if (startDt == null) return null;
    final endDt = end?.dateTime?.toLocal() ??
        startDt.add(const Duration(minutes: 30));
    final day = dateOnly(startDt);
    var startMin = startDt.hour * 60 + startDt.minute;
    // 끝이 다음날로 넘어가면 그날 23:59 로 클램프(로컬 모델은 하루 안).
    var endMin = dateOnly(endDt) == day
        ? endDt.hour * 60 + endDt.minute
        : 1439;
    if (endMin <= startMin) endMin = (startMin + 30).clamp(0, 1439);

    return RemoteEvent(
      gcalId: id,
      etag: e.etag,
      cancelled: false,
      date: day,
      startMin: startMin,
      endMin: endMin,
      allDay: false,
      title: e.summary ?? '(제목 없음)',
      note: e.description ?? '',
    );
  }
}

/// 원격 이벤트에서 뽑은 로컬 표현.
class RemoteEvent {
  const RemoteEvent({
    required this.gcalId,
    required this.etag,
    required this.cancelled,
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.allDay,
    required this.title,
    required this.note,
  });

  final String gcalId;
  final String? etag;
  final bool cancelled;
  final DateTime date;
  final int startMin;
  final int endMin;
  final bool allDay;
  final String title;
  final String note;
}
