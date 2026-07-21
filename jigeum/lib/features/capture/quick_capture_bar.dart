import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 어느 탭에서든 하단에 상시 노출되는 빠른 담기 — 터미널 프롬프트.
/// `› 빠르게 담기_` (캐럿 mark). 칩 중요/긴급/오늘 로 분류·날짜 지정.
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
  DateTime _date = todayDate();

  @override
  void initState() {
    super.initState();
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
    await ref.read(nodeRepoProvider).create(
          type: NodeType.task,
          title: text,
          important: _important,
          urgent: _urgent,
          date: _date,
        );
    _controller.clear();
    setState(() {
      _important = false;
      _urgent = false;
      _date = todayDate();
    });
    _focus.requestFocus();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: todayDate(),
      lastDate: todayDate().add(const Duration(days: 730)),
      helpText: '이 할 일을 언제로 담을까요?',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(
      decoration: BoxDecoration(
        color: tk.paper,
        border: Border(top: BorderSide(color: tk.ink, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 칩 줄
              Row(
                children: [
                  _chip('중요', _important,
                      () => setState(() => _important = !_important)),
                  const SizedBox(width: 8),
                  _chip('긴급', _urgent,
                      () => setState(() => _urgent = !_urgent), mark: true),
                  const SizedBox(width: 8),
                  _chip(
                      _date == todayDate()
                          ? '오늘'
                          : DateFormat('M/d').format(_date),
                      _date != todayDate(),
                      _pickDate),
                ],
              ),
              const SizedBox(height: 10),
              // 프롬프트 줄
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 2),
                    child: Text('›', style: AppText.glyph(tk.mark, size: 15)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      cursorColor: tk.mark,
                      style: AppText.body(tk.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '빠르게 담기_',
                        hintStyle: AppText.meta(tk.inkSoft, size: 12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _submit,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Text('담기', style: AppText.nav(tk.ink, active: true)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {bool mark = false}) {
    final tk = t(context);
    final fill = mark ? tk.mark : tk.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? fill : Colors.transparent,
          border: Border.all(color: selected ? fill : tk.line, width: 1),
        ),
        child: Text(label, style: AppText.chip(selected ? tk.paper : tk.inkSoft)),
      ),
    );
  }
}
