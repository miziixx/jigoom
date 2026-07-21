import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/db.dart';

/// 아웃라이너/리스트 공용 노드 타일.
/// 완료 노드: 도트→체크(#34C77B) + 흐림(opacity 0.45), 취소선 없음.
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
    final theme = Theme.of(context);
    final done = node.status == NodeStatus.done;

    return Opacity(
      opacity: done ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
              left: 12.0 + depth * 20, right: 12, top: 5, bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 펼침 화살표 (자식 있을 때만)
              SizedBox(
                width: 20,
                child: hasChildren
                    ? GestureDetector(
                        onTap: onToggleExpand,
                        child: AnimatedRotation(
                          duration: kAnimDuration,
                          turns: expanded ? 0.25 : 0,
                          child: Icon(Icons.chevron_right,
                              size: 16,
                              color: theme.textTheme.bodySmall?.color),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // 체크/도트
              GestureDetector(
                onTap: onToggleDone,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10, top: 1),
                  child: done
                      ? const Icon(Icons.check_circle,
                          size: 17, color: AppColors.done)
                      : Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.textTheme.bodySmall?.color ??
                                  Colors.grey,
                              width: 1.4,
                            ),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (showUrgentBolt && node.urgent && !done) ...[
                      Icon(Icons.bolt,
                          size: 14, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 2),
                    ],
                    Flexible(
                      child: Text(
                        node.title,
                        style: theme.textTheme.bodyLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
