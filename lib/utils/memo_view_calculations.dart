import '../models/memo.dart';

List<String> collectVisibleTags(List<Memo> memos) {
  final tags = <String>{};
  for (final memo in memos) {
    tags.addAll(memo.tags);
  }
  tags.removeAll({'habit', 'goal'});
  return tags.toList()..sort();
}

Map<String, int> countTags(List<Memo> memos) {
  final counts = <String, int>{};
  for (final memo in memos) {
    for (final tag in memo.tags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  return counts;
}

Map<String?, int> countMemosByFolder(List<Memo> memos) {
  final counts = <String?, int>{};
  for (final memo in memos) {
    counts[memo.folderId] = (counts[memo.folderId] ?? 0) + 1;
  }
  return counts;
}

List<Memo> recentMemos(List<Memo> memos) {
  final sorted = [...memos]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(3).toList();
}
