import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers.dart';
import '../outline/node_tile.dart';

/// 사분면 전체 리스트 화면.
class QuadrantListScreen extends ConsumerWidget {
  const QuadrantListScreen({
    super.key,
    required this.title,
    required this.important,
    required this.urgent,
  });

  final String title;
  final bool important;
  final bool urgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref
            .watch(quadrantProvider((important: important, urgent: urgent)))
            .valueOrNull ??
        const [];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: nodes.isEmpty
          ? Center(
              child: Text('지금은 비어 있어요',
                  style: Theme.of(context).textTheme.bodySmall))
          : ListView(
              children: [
                for (final n in nodes)
                  NodeTile(
                    node: n,
                    onToggleDone: () {
                      final repo = ref.read(nodeRepoProvider);
                      n.status == NodeStatus.done
                          ? repo.reopen(n.id)
                          : repo.complete(n.id);
                    },
                  ),
              ],
            ),
    );
  }
}
