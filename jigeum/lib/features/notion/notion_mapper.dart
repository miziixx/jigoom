import '../../data/db.dart';
import '../../data/repos/notion_repository.dart';

/// 지금의 레코드 ↔ 노션 페이지 속성(properties) 변환기.
///
/// 두 가지를 만든다:
///  1. [schema] — 데이터베이스를 처음 만들 때 넘길 속성 정의(createDatabase 용).
///  2. `*Props` — 페이지 하나를 만들거나 갱신할 때 넘길 실제 값(create/updatePage 용).
///
/// 모든 DB 는 공통으로 `JigeumId`(rich_text)를 가지며, 이 값이 원본 레코드 id 다.
/// 동기화는 이 id 로 기존 페이지를 찾아 upsert 한다(중복 없이 갱신).
class NotionMapper {
  const NotionMapper._();

  /// 유형별 노션 데이터베이스 속성 정의.
  static Map<String, dynamic> schema(NotionSyncType t) {
    switch (t) {
      case NotionSyncType.nodes:
        return {
          'Name': {'title': <String, dynamic>{}},
          'Status': _selectSchema(['open', 'done', 'drawer']),
          'Type': _selectSchema(['task', 'goal', 'memo', 'folder']),
          'Important': {'checkbox': <String, dynamic>{}},
          'Urgent': {'checkbox': <String, dynamic>{}},
          'Date': {'date': <String, dynamic>{}},
          'Note': {'rich_text': <String, dynamic>{}},
          'JigeumId': {'rich_text': <String, dynamic>{}},
          'UpdatedAt': {'date': <String, dynamic>{}},
        };
      case NotionSyncType.schedules:
        return {
          'Name': {'title': <String, dynamic>{}},
          'Status': _selectSchema(['open', 'done']),
          'Date': {'date': <String, dynamic>{}},
          'AllDay': {'checkbox': <String, dynamic>{}},
          'Note': {'rich_text': <String, dynamic>{}},
          'JigeumId': {'rich_text': <String, dynamic>{}},
          'UpdatedAt': {'date': <String, dynamic>{}},
        };
      case NotionSyncType.habits:
        return {
          'Name': {'title': <String, dynamic>{}},
          'Category': {'rich_text': <String, dynamic>{}},
          'Date': {'date': <String, dynamic>{}},
          'JigeumId': {'rich_text': <String, dynamic>{}},
          'UpdatedAt': {'date': <String, dynamic>{}},
        };
      case NotionSyncType.timeBlocks:
        return {
          'Name': {'title': <String, dynamic>{}},
          'Date': {'date': <String, dynamic>{}},
          'JigeumId': {'rich_text': <String, dynamic>{}},
          'UpdatedAt': {'date': <String, dynamic>{}},
        };
      case NotionSyncType.routines:
        return {
          'Name': {'title': <String, dynamic>{}},
          'Time': {'rich_text': <String, dynamic>{}},
          'Weekdays': {'rich_text': <String, dynamic>{}},
          'Active': {'checkbox': <String, dynamic>{}},
          'Note': {'rich_text': <String, dynamic>{}},
          'JigeumId': {'rich_text': <String, dynamic>{}},
          'UpdatedAt': {'date': <String, dynamic>{}},
        };
      case NotionSyncType.focusSessions:
        return {
          'Name': {'title': <String, dynamic>{}},
          'Date': {'date': <String, dynamic>{}},
          'PlannedMinutes': {'number': <String, dynamic>{}},
          'ActualMinutes': {'number': <String, dynamic>{}},
          'JigeumId': {'rich_text': <String, dynamic>{}},
          'UpdatedAt': {'date': <String, dynamic>{}},
        };
    }
  }

  // ---- upsert 키(JigeumId) ----
  static String nodeId(Node n) => n.id;
  static String scheduleId(Schedule s) => s.id;
  static String habitId(Habit h) => h.id;
  static String routineId(Routine r) => r.id;
  static String focusSessionId(FocusSession f) => f.id;

  /// 타임블록은 (date, block) 복합 PK → 안정적 문자열 키로 합친다.
  static String timeBlockId(TimeBlock t) =>
      'tb_${_ymd(t.date)}_${t.block}';

  // ---- 페이지 속성 ----
  static Map<String, dynamic> nodeProps(Node n) => _clean({
        'Name': _title(n.title),
        'Status': _select(n.status),
        'Type': _select(n.type),
        'Important': {'checkbox': n.important},
        'Urgent': {'checkbox': n.urgent},
        'Date': _date(n.date),
        'Note': _richText(n.note),
        'JigeumId': _richText(n.id),
        'UpdatedAt': _dateTime(n.updatedAt),
      });

  static Map<String, dynamic> scheduleProps(Schedule s) => _clean({
        'Name': _title(s.title),
        'Status': _select(s.done ? 'done' : 'open'),
        'Date': _date(s.date),
        'AllDay': {'checkbox': s.allDay},
        'Note': _richText(s.note),
        'JigeumId': _richText(s.id),
        'UpdatedAt': _dateTime(s.updatedAt ?? s.createdAt),
      });

  static Map<String, dynamic> habitProps(Habit h) => _clean({
        'Name': _title(h.title),
        'Category': _richText(h.category),
        'Date': _date(h.createdAt),
        'JigeumId': _richText(h.id),
        'UpdatedAt': _dateTime(h.createdAt),
      });

  static Map<String, dynamic> timeBlockProps(TimeBlock t) => _clean({
        'Name': _title(t.content.isEmpty ? '(빈 블록)' : t.content),
        'Date': _date(t.date),
        'JigeumId': _richText(timeBlockId(t)),
        'UpdatedAt': _dateTime(t.updatedAt ?? t.date),
      });

  static Map<String, dynamic> routineProps(Routine r) => _clean({
        'Name': _title(r.title),
        'Time': _richText('${_hm(r.startMin)}–${_hm(r.endMin)}'),
        'Weekdays': _richText(r.weekdays),
        'Active': {'checkbox': r.active},
        'Note': _richText(r.note),
        'JigeumId': _richText(r.id),
        'UpdatedAt': _dateTime(r.createdAt),
      });

  static Map<String, dynamic> focusSessionProps(FocusSession f) => _clean({
        'Name': _title('집중 ${(f.actualSeconds / 60).round()}분'),
        'Date': _date(f.startedAt),
        'PlannedMinutes': _number(f.plannedMinutes),
        'ActualMinutes': _number((f.actualSeconds / 60).round()),
        'JigeumId': _richText(f.id),
        'UpdatedAt': _dateTime(f.endedAt ?? f.startedAt),
      });

  // ---- 빌더 헬퍼 ----
  static Map<String, dynamic> _selectSchema(List<String> options) => {
        'select': {
          'options': [for (final o in options) {'name': o}]
        }
      };

  static Map<String, dynamic> _title(String v) => {
        'title': [
          {
            'text': {'content': _cap(v.isEmpty ? '(제목 없음)' : v)}
          }
        ]
      };

  static Map<String, dynamic> _richText(String v) => {
        'rich_text': v.isEmpty
            ? const []
            : [
                {
                  'text': {'content': _cap(v)}
                }
              ]
      };

  /// 빈 문자열이면 null 반환 → [_clean] 이 속성 자체를 뺀다(노션은 빈 select 거부).
  static Map<String, dynamic>? _select(String v) =>
      v.isEmpty ? null : {'select': {'name': v}};

  /// 숫자 속성 — null 이면 [_clean] 이 속성 자체를 뺀다.
  static Map<String, dynamic>? _number(num? v) =>
      v == null ? null : {'number': v};

  /// 분(0~1439) → "HH:MM" 표시.
  static String _hm(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic> _date(DateTime? d) =>
      {'date': d == null ? null : {'start': _ymd(d)}};

  static Map<String, dynamic> _dateTime(DateTime? d) =>
      {'date': d == null ? null : {'start': d.toIso8601String()}};

  /// null 값(=제외할 속성)을 걸러낸 최종 properties.
  static Map<String, dynamic> _clean(Map<String, dynamic> m) => {
        for (final e in m.entries)
          if (e.value != null) e.key: e.value
      };

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 노션 rich_text/title 은 조각당 2000자 제한 → 안전하게 자른다.
  static String _cap(String v) => v.length > 1900 ? v.substring(0, 1900) : v;
}
