/// 쏟아내기(brain dump) 화면. 기획: "판단 끄고 다 뱉기 → 엔진이 자동 분류".
///
/// 칩 없는 초간단 입력 하나. 적고 엔터 → 같은 분류 엔진([VoiceController])이
/// 일정/할일/매트릭스/… 로 알아서 갈라 실제로 담고, 방금 담은 게 태그와 함께
/// 위로 쌓인다. 음성 없이 타이핑만으로 "쏟아내면 갈라진다".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers.dart';

class DumpView extends ConsumerStatefulWidget {
  const DumpView({super.key});

  @override
  ConsumerState<DumpView> createState() => _DumpViewState();
}

/// 방금 쏟아낸 한 줄 + 어디로 갈렸는지.
class _Dumped {
  const _Dumped(this.text, this.bucket);
  final String text;
  final String bucket; // 예: "일정", "빠른담기"
}

class _DumpViewState extends ConsumerState<DumpView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final List<_Dumped> _items = [];

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focus.requestFocus();
    // 같은 엔진으로 분류 + 실제 담기. 메시지 "○○에 담았어요"에서 버킷만 뽑는다.
    final fb = await ref.read(voiceControllerProvider).handle(text);
    if (!mounted) return;
    final bucket = fb.message.replaceAll(RegExp(r'(에|으로|로) 담았어요$'), '').trim();
    setState(() => _items.insert(0, _Dumped(text, bucket)));
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더 — 판단 끄라는 안내 + 카운터.
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('판단은 나중에 · 생각나는 대로',
                        style: AppText.meta(tk.inkSoft, size: 11)),
                    const SizedBox(height: 2),
                    Text('머릿속을 비워요',
                        style: AppText.hTitle(tk.ink)),
                  ],
                ),
              ),
              if (_items.isNotEmpty)
                Text('${_items.length}개 쏟아냄',
                    style: AppText.meta(tk.mark, size: 11)),
            ],
          ),
        ),

        // 입력 — 칩 없이 프롬프트 한 줄.
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: tk.ink, width: 1),
              bottom: BorderSide(color: tk.line, width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Text('›', style: AppText.glyph(tk.mark, size: 16)),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  cursorColor: tk.mark,
                  style: AppText.body(tk.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '적고 엔터 · 또 적고 엔터_',
                    hintStyle: AppText.meta(tk.inkSoft, size: 13),
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
                  child: Text('쏟기', style: AppText.nav(tk.ink, active: true)),
                ),
              ),
            ],
          ),
        ),

        // 방금 쏟아낸 것들 — 엔진이 어디로 갈랐는지 태그와 함께.
        Expanded(
          child: _items.isEmpty
              ? _empty(tk)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: kGutter, vertical: 10),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: tk.line),
                  itemBuilder: (_, i) => _row(tk, _items[i]),
                ),
        ),
      ],
    );
  }

  Widget _row(AppTokens tk, _Dumped d) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(child: Text(d.text, style: AppText.body(tk.ink))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: tk.line)),
              child: Text(d.bucket, style: AppText.meta(tk.inkSoft, size: 11)),
            ),
          ],
        ),
      );

  Widget _empty(AppTokens tk) => Center(
        child: Padding(
          padding: const EdgeInsets.all(kGutter),
          child: Text(
            '떠오르는 대로 적고 엔터.\n엔진이 알아서 일정·할일·매트릭스로 갈라 담아요.',
            textAlign: TextAlign.center,
            style: AppText.meta(tk.inkSoft, size: 13),
          ),
        ),
      );
}
