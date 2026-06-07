class QuickTab {
  final String id;
  final String label;
  final bool isTag; // true = tag tab, false = folder tab
  final String? folderId; // when !isTag; null = inbox
  final String? tag; // when isTag

  const QuickTab({
    required this.id,
    required this.label,
    required this.isTag,
    this.folderId,
    this.tag,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'isTag': isTag,
    'folderId': folderId,
    'tag': tag,
  };

  factory QuickTab.fromJson(Map<String, dynamic> json) => QuickTab(
    id: json['id'] as String,
    label: json['label'] as String,
    isTag: (json['isTag'] as bool?) ?? false,
    folderId: json['folderId'] as String?,
    tag: json['tag'] as String?,
  );
}
