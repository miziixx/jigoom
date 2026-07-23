import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';

/// 새 폴더(카테고리) 생성 시트 — 윈도우 탐색기/스킬트리 느낌.
/// 기존 폴더 계층을 들여쓰기 가이드와 함께 보여주고, 넣을 위치(상위 폴더)를 골라 중첩 생성.
Future<void> showFolderCreateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => const _FolderCreateSheet(),
  );
}

class _FolderCreateSheet extends ConsumerStatefulWidget {
  const _FolderCreateSheet();

  @override
  ConsumerState<_FolderCreateSheet> createState() => _FolderCreateSheetState();
}

class _FolderCreateSheetState extends ConsumerState<_FolderCreateSheet> {
  final _name = TextEditingController();
  String? _parentId; // null = 최상위

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _name.text.trim();
    if (title.isEmpty) return;
    await ref.read(nodeRepoProvider).create(
          type: NodeType.folder,
          title: title,
          parentId: _parentId,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final roots = ref.watch(rootsProvider).valueOrNull ?? const [];
    final topFolders =
        roots.where((n) => n.type == NodeType.folder).toList();

    return Container(
      color: tk.paper,
      padding: EdgeInsets.only(
        left: kGutter,
        right: kGutter,
        top: 18,
        bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 마스트헤드
          Text('새 폴더',
              style: AppText.meta(tk.inkSoft, size: 10)
                  .copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Container(height: 1, color: tk.ink),
          const SizedBox(height: 14),
          // 이름 입력
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Text('▸', style: AppText.glyph(tk.mark, size: 14)),
              ),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  cursorColor: tk.mark,
                  style: AppText.body(tk.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '폴더 이름 (예: 회사, 집, 공부)',
                    hintStyle: AppText.meta(tk.inkSoft, size: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('넣을 위치', style: AppText.meta(tk.inkSoft, size: 10)),
          const SizedBox(height: 6),
          // 탐색기 트리 (최상위 + 폴더 계층)
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _locRow(tk, depth: 0, label: '홈 (최상위)', id: null, glyph: '▚'),
                  for (final f in topFolders) ..._folderRows(tk, f, 1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 액션
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('취소', style: AppText.nav(tk.inkSoft)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _save,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  color: tk.ink,
                  child:
                      Text('만들기', style: AppText.nav(tk.paper, active: true)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 한 폴더와 그 하위 폴더들을 재귀로 펼친 행 목록.
  List<Widget> _folderRows(AppTokens tk, Node folder, int depth) {
    final children =
        ref.watch(childrenProvider(folder.id)).valueOrNull ?? const [];
    final subFolders =
        children.where((n) => n.type == NodeType.folder).toList();
    return [
      _locRow(tk, depth: depth, label: folder.title, id: folder.id),
      for (final sf in subFolders) ..._folderRows(tk, sf, depth + 1),
    ];
  }

  /// 탐색기 행 — 들여쓰기 가이드선 + 폴더 글리프 + 이름 + 선택 표시.
  Widget _locRow(AppTokens tk,
      {required int depth,
      required String label,
      required String? id,
      String glyph = '▸'}) {
    final selected = _parentId == id;
    return GestureDetector(
      onTap: () => setState(() => _parentId = id),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: selected ? tk.ink : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // 들여쓰기 가이드선 (스킬트리 느낌)
            for (var i = 0; i < depth; i++)
              Container(
                width: 18,
                alignment: Alignment.centerLeft,
                child: Text(i == depth - 1 ? '└' : ' ',
                    style: AppText.glyph(
                        selected ? tk.paper : tk.inkSoft,
                        size: 12)),
              ),
            const SizedBox(width: 2),
            Text(glyph,
                style: AppText.glyph(
                    selected ? tk.paper : tk.mark,
                    size: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(selected ? tk.paper : tk.ink)),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('여기',
                    style: AppText.chip(tk.paper)),
              ),
          ],
        ),
      ),
    );
  }
}
