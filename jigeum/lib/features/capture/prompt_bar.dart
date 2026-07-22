import 'package:flutter/material.dart';

import '../../core/journal.dart';
import '../../core/theme.dart';

/// 범용 하단 담기 프롬프트 — 칩 없는 터미널 프롬프트(`› {hint}`).
/// 일과 탭의 일정·기록 하위 보기에서 빠른 담기용.
class PromptBar extends StatefulWidget {
  const PromptBar({super.key, required this.hint, required this.onSubmit});

  final String hint;
  final Future<void> Function(String text) onSubmit;

  @override
  State<PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends State<PromptBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await widget.onSubmit(text);
    _controller.clear();
    _focus.requestFocus();
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
          padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 8),
          child: Row(
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
                    hintText: widget.hint,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text('담기', style: AppText.nav(tk.ink, active: true)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
