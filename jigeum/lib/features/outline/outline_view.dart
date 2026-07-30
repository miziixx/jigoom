import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../today/node_detail_sheet.dart';

/// 아웃라이너 — 편집형 목차. 폴더/목표 = 섹션 라벨 + 규칙선, 할 일 = 글리프 줄.
/// 카드·레일 없음. 기간 필터는 대문자 모노 칩.
class OutlineView extends ConsumerStatefulWidget {
  const OutlineView({super.key});

  @override
  ConsumerState<OutlineView> createState() => _OutlineViewState();
}

class _OutlineViewState extends ConsumerState<OutlineView> {
  final Set<String> _collapsed = {}; // 기본 펼침, 접은 것만 기록


  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(color: tk.paper, child: _tree());
  }

  // ---------------------------------------------------------------- 필터바

  Future<void> _newNode(String type, String title) async {
    final isFolder = type == NodeType.folder;
    final name = await showInputDialog(context,
        title: isFolder ? '새 폴더' : '새 목표',
        subtitle: isFolder ? '할 일을 묶어둘 폴더를 만듭니다.' : '이루고 싶은 결과를 짧게 적어주세요.',
        fieldLabel: isFolder ? '폴더 이름' : '목표 이름',
        hint: isFolder ? '폴더 이름' : '이루고 싶은 것',
        saveLabel: '만들기');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(nodeRepoProvider).create(type: type, title: name.trim());
  }

  // ------------------------------------------------------------ 트리 모드
  Widget _tree() {
    final all = ref.watch(rootsProvider).valueOrNull ?? const [];
    // 레퍼런스: 폴더·목표를 먼저, 낱개 할 일은 그 뒤로.
    final roots = [
      ...all.where(
          (n) => n.type == NodeType.folder || n.type == NodeType.goal),
      ...all.where(
          (n) => n.type != NodeType.folder && n.type != NodeType.goal),
    ];
    final rows = <Widget>[_folderGoalHeader()];

    void render(List<Node> list, int depth) {
      for (final n in list) {
        final children =
            ref.watch(childrenProvider(n.id)).valueOrNull ?? const [];
        final isSection =
            n.type == NodeType.folder || n.type == NodeType.goal;
        final row = _iconRow(n, depth, children);
        rows.add(isSection ? row : _swipeable(n, row));
        if (children.isNotEmpty &&
            isSection &&
            !_collapsed.contains(n.id)) {
          render(children, depth + 1);
        } else if (children.isNotEmpty && !isSection) {
          render(children, depth + 1);
        }
      }
    }

    if (roots.isEmpty) {
      rows.add(emptyNote(context, '아직 아무것도 없어요'));
    } else {
      render(roots, 0);
    }
    rows.add(const SizedBox(height: 16));
    return ListView(padding: EdgeInsets.zero, children: rows);
  }

  /// § 폴더와 목표 + 폴더 / + 목표.
  Widget _folderGoalHeader() {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('§ ', style: AppText.hTitle(tk.mark).copyWith(fontSize: 15)),
              Text('폴더와 목표',
                  style: AppText.hTitle(tk.ink).copyWith(fontSize: 16)),
              const Spacer(),
              GestureDetector(
                onTap: () => _newNode(NodeType.folder, ''),
                behavior: HitTestBehavior.opaque,
                child: Text('＋ 폴더', style: AppText.meta(tk.mark, size: 11)),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => _newNode(NodeType.goal, ''),
                behavior: HitTestBehavior.opaque,
                child: Text('＋ 목표', style: AppText.meta(tk.mark, size: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: tk.line),
        ],
      ),
    );
  }

  /// 아이콘박스 트리 행 — [F/G/T] + 제목 + 메타 + (섹션 −/+ · 할 일 ›).
  Widget _iconRow(Node n, int depth, List<Node> children) {
    final tk = t(context);
    final isFolder = n.type == NodeType.folder;
    final isGoal = n.type == NodeType.goal;
    final isSection = isFolder || isGoal;
    final done = n.status == NodeStatus.done;
    final open = !_collapsed.contains(n.id);
    final letter = isFolder ? 'F' : (isGoal ? 'G' : 'T');

    String meta;
    if (isFolder) {
      final t = children.where((c) => c.type == NodeType.task).length;
      final g = children.where((c) => c.type == NodeType.goal).length;
      meta = [if (t > 0) '할 일 $t개', if (g > 0) '목표 $g개'].join(' · ');
      if (meta.isEmpty) meta = '비어 있음';
    } else if (isGoal) {
      final total = children.length;
      final doneC = children.where((c) => c.status == NodeStatus.done).length;
      meta = total == 0
          ? '목표'
          : '진행률 ${(doneC / total * 100).round()}%';
    } else {
      meta = n.date == todayDate()
          ? '오늘'
          : (n.date != null
              ? '${n.date!.month}/${n.date!.day}'
              : (n.note.isNotEmpty ? n.note : ''));
    }

    return GestureDetector(
      onTap: () => isSection
          ? setState(() =>
              open ? _collapsed.add(n.id) : _collapsed.remove(n.id))
          : showNodeDetailSheet(context, n),
      onLongPress: () => showNodeDetailSheet(context, n),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        padding: EdgeInsets.fromLTRB(kGutter + depth * 20, 12, kGutter, 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: tk.line),
                color: isSection ? tk.paper2 : Colors.transparent,
              ),
              child: Text(letter,
                  style: AppText.meta(tk.inkSoft, size: 11)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                          done ? tk.ink.withValues(alpha: 0.5) : tk.ink)),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta(tk.inkSoft, size: 9)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(isSection ? (open ? '−' : '+') : '›',
                style: AppText.glyph(tk.mark, size: 16)),
          ],
        ),
      ),
    );
  }

  Widget _swipeable(Node node, Widget child) {
    final tk = t(context);
    Widget bg(Alignment a, String g) => Container(
          alignment: a,
          color: tk.paper2,
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 16)),
        );
    return Dismissible(
      key: ValueKey('dismiss_${node.id}'),
      background: bg(Alignment.centerLeft, '■'),
      secondaryBackground: bg(Alignment.centerRight, '→'),
      confirmDismiss: (dir) async {
        final repo = ref.read(nodeRepoProvider);
        if (dir == DismissDirection.startToEnd) {
          await repo.complete(node.id); // 우 = 완료
        } else {
          await repo.pushToTomorrow(node.id); // 좌 = 내일로
        }
        return false;
      },
      child: child,
    );
  }
}

/// 대문자 모노 필터 칩 (각진 1px 규칙선, 선택 = 잉크 반전).
