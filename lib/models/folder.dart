class Folder {
  final String id;
  final String name;
  final String? parentId; // null = root level
  final int order;

  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    this.order = 0,
  });

  Folder copyWith({
    String? name,
    String? parentId,
    int? order,
    bool clearParent = false,
  }) =>
      Folder(
        id: id,
        name: name ?? this.name,
        parentId: clearParent ? null : (parentId ?? this.parentId),
        order: order ?? this.order,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'order': order,
      };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as String,
        name: json['name'] as String,
        parentId: json['parentId'] as String?,
        order: (json['order'] as int?) ?? 0,
      );
}
