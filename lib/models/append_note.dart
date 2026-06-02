class AppendNote {
  final String content;
  final DateTime addedAt;

  const AppendNote({required this.content, required this.addedAt});

  Map<String, dynamic> toJson() => {
        'content': content,
        'addedAt': addedAt.toIso8601String(),
      };

  factory AppendNote.fromJson(Map<String, dynamic> json) => AppendNote(
        content: json['content'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}
