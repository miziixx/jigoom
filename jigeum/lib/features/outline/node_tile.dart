import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';

/// 아웃라이너/리스트 공용 노드 줄 (편집형).
/// 글리프 체크(□/■) + 제목(한글 Sans) + 우선순위 라벨. 완료 = ■ + inkSoft + 취소선.
class NodeTile extends StatelessWidget {
  const NodeTile({
    super.key,
    required this.node,
    this.depth = 0,
    this.hasChildren = false,
    this.expanded = false,
    this.onToggleExpand,
    this.onToggleDone,
    this.onTap,
    this.showUrgentBolt = true,
  });

  final Node node;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onToggleDone;
  final VoidCallback? onTap;
  final bool showUrgentBolt;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final done = node.status == NodeStatus.done;
    final pri = done
        ? null
        : priorityLabel(context,
            urgent: showUrgentBolt && node.urgent, important: node.important);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(kGutter + depth * 18, 7, kGutter, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 펼침 화살표 (자식 있을 때만)
            SizedBox(
              width: 18,
              child: hasChildren
                  ? GestureDetector(
                      onTap: onToggleExpand,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedRotation(
                        duration: kAnimDuration,
                        turns: expanded ? 0.25 : 0,
                        child: Icon(Icons.chevron_right,
                            size: 16, color: tk.inkSoft),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            GlyphCheck(done: done, onTap: onToggleDone ?? () {}),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.title,
                      style: AppText.body(done ? tk.inkSoft : tk.ink).copyWith(
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: tk.inkSoft),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (done && node.doneAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                          '${DateFormat('HH:mm').format(node.doneAt!)} 완료',
                          style: AppText.meta(tk.mark, size: 10)),
                    ),
                ],
              ),
            ),
            if (pri != null) ...[
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(top: 2), child: pri),
            ],
          ],
        ),
      ),
    );
  }
}
