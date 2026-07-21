import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';

/// 노드 상세 시트: 메모 쓰기/보기 · 폴더 이동 · 날짜 · 삭제.
/// 어느 목록에서든 타일을 탭하면 열린다.
Future<void> showNodeDetailSheet(BuildContext context, Node node) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => _DetailSheet(node: node),
  );
}

class _DetailSheet extends ConsumerStatefulWidget {
  const _DetailSheet({required this.node});
  final Node node;

  @override
  ConsumerState<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends ConsumerState<_DetailSheet> {
  late final TextEditingController _note;
  DateTime? _date;
  String? _parentId;
  late bool _important;
  late bool _urgent;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.node.note);
    _date = widget.node.date;
    _parentId = widget.node.parentId;
    _important = widget.node.important;
    _urgent = widget.node.urgent;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Widget _toggleChip(ThemeData theme, String label, bool on, Color onColor,
      VoidCallback onTap) {
    final border = theme.dividerTheme.color ?? Colors.black12;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? onColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: on ? null : Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: on ? Colors.white : theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(nodeRepoProvider);
    await repo.setNote(widget.node.id, _note.text.trim());
    if (_date != widget.node.date) {
      await repo.setDate(widget.node.id, _date);
    }
    if (_parentId != widget.node.parentId) {
      await repo.setParent(widget.node.id, _parentId);
    }
    if (_important != widget.node.important ||
        _urgent != widget.node.urgent) {
      await repo.setMatrix(widget.node.id,
          important: _important, urgent: _urgent);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folders = ref.watch(foldersProvider).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.node.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),

          // 중요 / 긴급 토글
          Row(
            children: [
              _toggleChip(theme, '중요', _important, AppColors.accent,
                  () => setState(() => _important = !_important)),
              const SizedBox(width: 8),
              _toggleChip(theme, '긴급', _urgent, AppColors.alert,
                  () => setState(() => _urgent = !_urgent)),
            ],
          ),
          const SizedBox(height: 14),

          // 메모
          Text('메모', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 6,
            style: theme.textTheme.bodyMedium,
            decoration: const InputDecoration(
              hintText: '지금이든 나중이든, 남기고 싶은 것',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),

          // 날짜
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 8),
              Text(
                _date == null
                    ? '날짜 없음'
                    : DateFormat('M월 d일 (E)', 'ko').format(_date!),
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date ?? todayDate(),
                    firstDate: DateTime(2024),
                    lastDate: todayDate().add(const Duration(days: 730)),
                    helpText: '언제까지 할까요?',
                    cancelText: '취소',
                    confirmText: '설정',
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: const Text('변경'),
              ),
              if (_date != null)
                TextButton(
                  onPressed: () => setState(() => _date = null),
                  child: Text('지우기', style: theme.textTheme.bodySmall),
                ),
            ],
          ),

          // 폴더
          Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 16, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String?>(
                  value: folders.any((f) => f.id == _parentId)
                      ? _parentId
                      : null,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('폴더 없음'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('폴더 없음')),
                    for (final f in folders)
                      DropdownMenuItem<String?>(
                          value: f.id, child: Text(f.title)),
                  ],
                  onChanged: (v) => setState(() => _parentId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  await ref
                      .read(nodeRepoProvider)
                      .deleteNode(widget.node.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: Icon(Icons.delete_outline,
                    size: 18, color: theme.textTheme.bodySmall?.color),
                label: Text('삭제', style: theme.textTheme.bodySmall),
              ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('저장')),
            ],
          ),
        ],
      ),
    );
  }
}
