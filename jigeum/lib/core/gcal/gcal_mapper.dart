import '../../data/db.dart';
import '../constants.dart';

/// 로컬 [Schedule] ↔ 폰 캘린더 이벤트(네이티브 map) 변환.
///
/// 시간은 epoch millis(로컬 순간)로 주고받는다. 종일 이벤트는 [allDay]=true.
class GcalMapper {
  /// 로컬 일정의 시작/끝 epoch millis.
  static ({int start, int end}) rangeMillis(Schedule s) {
    final day = dateOnly(s.date);
    if (s.allDay) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      return (start: start.millisecondsSinceEpoch, end: end.millisecondsSinceEpoch);
    }
    var endMin = s.endMin;
    if (endMin <= s.startMin) endMin = s.startMin + 30;
    final start =
        DateTime(day.year, day.month, day.day).add(Duration(minutes: s.startMin));
    final end =
        DateTime(day.year, day.month, day.day).add(Duration(minutes: endMin));
    return (
      start: start.millisecondsSinceEpoch,
      end: end.millisecondsSinceEpoch,
    );
  }

  /// 네이티브 이벤트 map → 로컬 필드. 형식이 이상하면 null.
  static RemoteEvent? fromMap(Map<String, dynamic> m) {
    final id = m['id']?.toString();
    if (id == null) return null;
    final startMs = (m['startMs'] as num?)?.toInt();
    if (startMs == null) return null;
    final allDay = m['allDay'] == true;
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final endMs = (m['endMs'] as num?)?.toInt() ??
        start.add(const Duration(minutes: 30)).millisecondsSinceEpoch;
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);

    final day = dateOnly(start);
    int startMin;
    int endMin;
    if (allDay) {
      startMin = 0;
      endMin = 0;
    } else {
      startMin = start.hour * 60 + start.minute;
      endMin = dateOnly(end) == day ? end.hour * 60 + end.minute : 1439;
      if (endMin <= startMin) endMin = (startMin + 30).clamp(0, 1439);
    }

    return RemoteEvent(
      gcalId: id,
      date: day,
      startMin: startMin,
      endMin: endMin,
      allDay: allDay,
      title: (m['title'] as String?)?.trim().isNotEmpty == true
          ? m['title'] as String
          : '(제목 없음)',
      note: (m['note'] as String?) ?? '',
    );
  }
}

/// 폰 캘린더 이벤트에서 뽑은 로컬 표현.
class RemoteEvent {
  const RemoteEvent({
    required this.gcalId,
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.allDay,
    required this.title,
    required this.note,
  });

  final String gcalId;
  final DateTime date;
  final int startMin;
  final int endMin;
  final bool allDay;
  final String title;
  final String note;
}
