import 'append_note.dart';

class Memo {
  final String id;
  final String content;
  final DateTime createdAt;
  final String? folderId;
  final List<DateTime> editHistory; // timestamps of edits (creation not included)
  final DateTime? reminderAt;       // scheduled notification time, null = no reminder
  final String reminderRepeat;      // 'none' | 'daily' | 'weekly' | 'monthly'
  final DateTime? scheduledAt;      // appointment/schedule time (! shortcut), null = not scheduled
  final bool isChecklist;           // dedicated checklist mode (inline add/delete items)
  final List<AppendNote> appendNotes; // notes appended after creation
  final String? sourceUrl;            // origin link when memo was created via share
  final List<String> imagePaths;      // attached image file paths

  const Memo({
    required this.id,
    required this.content,
    required this.createdAt,
    this.folderId,
    this.editHistory = const [],
    this.reminderAt,
    this.reminderRepeat = 'none',
    this.scheduledAt,
    this.isChecklist = false,
    this.appendNotes = const [],
    this.sourceUrl,
    this.imagePaths = const [],
  });

  String get dateKey {
    final d = createdAt;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // [4] Seconds included: HH:MM:SS
  String get timeStr {
    final d = createdAt;
    return '${d.hour.toString().padLeft(2, '0')}'
        ':${d.minute.toString().padLeft(2, '0')}'
        ':${d.second.toString().padLeft(2, '0')}';
  }

  List<String> get tags {
    final regex = RegExp(r'(?<![^\s])#([a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣][a-zA-Z0-9_ㄱ-ㅎㅏ-ㅣ가-힣]*)');
    return regex
        .allMatches(content)
        .map((m) => m.group(1)!)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
  }

  Memo copyWith({
    String? content,
    String? folderId,
    bool clearFolder = false,
    List<DateTime>? editHistory,
    DateTime? reminderAt,
    bool clearReminder = false,
    String? reminderRepeat,
    DateTime? scheduledAt,
    bool clearSchedule = false,
    bool? isChecklist,
    List<AppendNote>? appendNotes,
    String? sourceUrl,
    bool clearSourceUrl = false,
    List<String>? imagePaths,
  }) =>
      Memo(
        id: id,
        content: content ?? this.content,
        createdAt: createdAt,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        editHistory: editHistory ?? this.editHistory,
        reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
        reminderRepeat: clearReminder ? 'none' : (reminderRepeat ?? this.reminderRepeat),
        scheduledAt: clearSchedule ? null : (scheduledAt ?? this.scheduledAt),
        isChecklist: isChecklist ?? this.isChecklist,
        appendNotes: appendNotes ?? this.appendNotes,
        sourceUrl: clearSourceUrl ? null : (sourceUrl ?? this.sourceUrl),
        imagePaths: imagePaths ?? this.imagePaths,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'folderId': folderId,
        'editHistory':
            editHistory.map((d) => d.toIso8601String()).toList(),
        'reminderAt': reminderAt?.toIso8601String(),
        'reminderRepeat': reminderRepeat,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'isChecklist': isChecklist,
        'appendNotes': appendNotes.map((n) => n.toJson()).toList(),
        'sourceUrl': sourceUrl,
        'imagePaths': imagePaths,
      };

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
        id: json['id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        folderId: json['folderId'] as String?,
        editHistory: (json['editHistory'] as List<dynamic>?)
                ?.map((e) => DateTime.parse(e as String))
                .toList() ??
            [],
        reminderAt: json['reminderAt'] != null
            ? DateTime.tryParse(json['reminderAt'] as String)
            : null,
        reminderRepeat: (json['reminderRepeat'] as String?) ?? 'none',
        scheduledAt: json['scheduledAt'] != null
            ? DateTime.tryParse(json['scheduledAt'] as String)
            : null,
        isChecklist: (json['isChecklist'] as bool?) ?? false,
        appendNotes: (json['appendNotes'] as List<dynamic>?)
                ?.map((e) => AppendNote.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        sourceUrl: json['sourceUrl'] as String?,
        imagePaths: (json['imagePaths'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}
