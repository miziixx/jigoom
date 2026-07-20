import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 어느 탭에서든 하단에 상시 노출되는 퀵캡처 입력바.
/// 엔터 → 인박스(parentId=null, type=memo) 적재.
/// [중요][긴급] 토글 선택 시 task 로 저장.
class QuickCaptureBar extends ConsumerStatefulWidget {
  const QuickCaptureBar({super.key});

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}

class _QuickCaptureBarState extends ConsumerState<QuickCaptureBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _important = false;
  bool _urgent = false;

  @override
  void initState() {
    super.initState();
    // 위젯 탭 진입 → 입력창 포커스 + 키보드 열기.
    quickCaptureFocusRequest.addListener(_onFocusRequest);
  }

  void _onFocusRequest() {
    if (!mounted) return;
    _focus.requestFocus();
  }

  @override
  void dispose() {
    quickCaptureFocusRequest.removeListener(_onFocusRequest);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(nodeRepoProvider);

    // 분류 강요 없음: 적으면 곧장 오늘 할 일로. 날짜/중요는 나중에 타일에서.
    await repo.create(
      type: NodeType.task,
      title: text,
      important: _important,
      urgent: _urgent,
      date: todayDate(),
    );

    _controller.clear();
    setState(() {
      _important = false;
      _urgent = false;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.dividerTheme.color ?? Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: hairline, width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom * 0,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _Chip(
              label: '중요',
              selected: _important,
              onTap: () => setState(() => _important = !_important),
            ),
            const SizedBox(width: 6),
            _Chip(
              label: '긴급',
              icon: Icons.bolt,
              selected: _urgent,
              onTap: () => setState(() => _urgent = !_urgent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '빠르게 담기…',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 20),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = selected;
    final fg = on
        ? theme.textTheme.bodyLarge?.color
        : theme.textTheme.bodySmall?.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kAnimDuration,
        curve: kAnimCurve,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: on
                ? (theme.textTheme.bodyLarge?.color ?? Colors.black)
                : (theme.dividerTheme.color ?? Colors.black12),
            width: on ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 2),
            ],
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
