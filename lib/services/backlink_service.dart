import '../models/memo.dart';

/// 메모 간 백링크(역참조) 계산 — 순수 로컬, 업로드 0.
///
/// 두 종류를 구분한다:
///  - linked: 다른 메모가 명시적으로 `[[id:THIS|...]]`로 연결한 경우
///  - unlinked: 명시 링크는 없지만 다른 메모 본문에 이 메모의 제목이 등장하는 경우
///    (옵시디언의 "unlinked mentions"에 해당)
class BacklinkService {
  static final _linkRe = RegExp(r'\[\[id:([^|\]]+)\|([^\]]+)\]\]');

  /// 메모의 제목(첫 줄, 태그/체크박스 마크 제거).
  static String titleOf(Memo m) {
    final first = m.content.split('\n').first;
    return first
        .replaceAll(RegExp(r'#[\w가-힣]+'), '')
        .replaceAll(RegExp(r'^- \[[ x]\] '), '')
        .replaceAll(RegExp(r'^•\s*'), '')
        .replaceAll(RegExp(r'^#+\s*'), '')
        .trim();
  }

  /// [target]을 명시적으로 링크한 메모들.
  static List<Memo> linkedBacklinks(Memo target, List<Memo> all) {
    final result = <Memo>[];
    for (final m in all) {
      if (m.id == target.id) continue;
      if (_mentionsId(m, target.id)) result.add(m);
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// 명시 링크 없이 [target]의 제목을 본문에 언급한 메모들.
  static List<Memo> unlinkedMentions(Memo target, List<Memo> all,
      {int limit = 5}) {
    final title = titleOf(target);
    if (title.length < 2) return const [];
    final needle = title.toLowerCase();
    final result = <Memo>[];
    for (final m in all) {
      if (m.id == target.id) continue;
      if (_mentionsId(m, target.id)) continue; // 이미 명시 링크면 제외
      final hay = '${m.content} '
              '${m.appendNotes.map((n) => n.content).join(' ')}'
          .toLowerCase();
      if (hay.contains(needle)) result.add(m);
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result.take(limit).toList();
  }

  static bool _mentionsId(Memo m, String id) {
    final blob = '${m.content}\n${m.appendNotes.map((n) => n.content).join('\n')}';
    for (final match in _linkRe.allMatches(blob)) {
      if (match.group(1) == id) return true;
    }
    return false;
  }
}
