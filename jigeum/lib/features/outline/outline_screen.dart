/// 아웃라인 독립 화면. 하단 탭에서 사이드바(드로어)로 이동하면서, 탭 마스트헤드의
/// +폴더·+목표 액션을 여기로 옮겨 담았다. 본문은 기존 [OutlineView] 그대로.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../today/intention_sheet.dart';
import '../today/two_minute_sheet.dart';
import 'folder_create_sheet.dart';
import 'outline_view.dart';

class OutlineScreen extends ConsumerStatefulWidget {
  const OutlineScreen({super.key});

  @override
  ConsumerState<OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends ConsumerState<OutlineScreen> {
  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Scaffold(
      backgroundColor: tk.paper,
      appBar: AppBar(
        backgroundColor: tk.paper,
        elevation: 0,
        iconTheme: IconThemeData(color: tk.ink),
        title: Text('아웃라인', style: AppText.hTitle(tk.ink)),
        actions: [
          _act('+폴더', _newFolder),
          _act('+목표', _newGoal),
          const SizedBox(width: 12),
        ],
      ),
      body: const OutlineView(),
    );
  }

  Widget _act(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(label, style: AppText.meta(t(context).inkSoft, size: 12)),
        ),
      );

  /// 새 폴더(카테고리) 생성 — 탐색기/스킬트리형 시트.
  Future<void> _newFolder() async {
    await showFolderCreateSheet(context);
  }

  /// 새 목표 → 저장 직후 첫 2분 행동 시트, 이어서 실행의도(선택) 시트.
  Future<void> _newGoal() async {
    final title =
        await showInputDialog(context, title: '새 목표', hint: '이루고 싶은 것');
    if (title == null || title.trim().isEmpty || !mounted) return;
    final id = await ref
        .read(nodeRepoProvider)
        .create(type: NodeType.goal, title: title.trim());
    if (!mounted) return;
    final saved = await showTwoMinuteSheet(context, ref,
        goalId: id, goalTitle: title.trim());
    if (saved == true && mounted) {
      await showIntentionSheet(context, ref,
          goalId: id, goalTitle: title.trim());
    }
  }
}
