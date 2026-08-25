/// 보류함 화면. 기획서 §5 커밋9(화면) + §9(뱃지) + 커밋10.
///
/// ⚠️ 위젯 레이어 — 이 환경(Flutter 없음)에서 컴파일 검증 못 함. 기기 확인 필요.
/// 쌓인 원문을 목록으로 보고, 한 건을 다른 곳으로 재분류하거나 버린다.
/// 데이터/재분류 로직은 [InboxRepository](검증됨)에 있다.
library;

import 'package:flutter/material.dart';

import '../../core/dialogs.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../shell/app_bottom_nav.dart';
import 'inbox_item.dart';
import 'inbox_repository.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.repository,
    this.onReclassify,
  });

  final InboxRepository repository;

  /// 한 건을 다시 라우팅 시도할 때(예: 재입력 화면으로). null 이면 버튼 숨김.
  final void Function(InboxItem item)? onReclassify;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  /// 저장소가 [Listenable] 이면(영속 구현) 로드/변경을 구독해 목록을 갱신한다.
  Listenable? _repoListenable;

  @override
  void initState() {
    super.initState();
    // Listenable 은 InboxRepository 의 상위형이 아니라 `is` 승격이 안 되므로
    // (구현체만 둘 다 만족) 명시적으로 캐스팅한다.
    final repo = widget.repository;
    _repoListenable = repo is Listenable ? repo as Listenable : null;
    _repoListenable?.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _repoListenable?.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  // 보류함의 담기 = 보류 항목 추가.
  Future<void> _addHeld() async {
    final text = await showInputDialog(
      context,
      title: '보류함에 담기',
      kicker: 'HOLD',
      hint: '나중에 다시 볼 내용',
      fieldLabel: '내용',
    );
    if (!mounted) return;
    if (text != null && text.trim().isNotEmpty) {
      widget.repository.add(text.trim());
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = Theme.of(context).extension<AppTokens>()!;
    final items = widget.repository.list(status: InboxStatus.pending);
    return Scaffold(
      backgroundColor: tk.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Masthead(
                eyebrow: 'ON HOLD',
                title: '보류함',
                onBack: () => Navigator.of(context).pop(),),
            Expanded(
              child: items.isEmpty
                  ? emptyStateBear(context, '비어 있어요')
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: tk.line),
                      itemBuilder: (context, i) => _row(context, tk, items[i]),
                    ),
            ),
            AppBottomNav(onQuickAdd: _addHeld),
          ],
        ),
      ),
    );
  }

  // 기준 HTML .thread-item — 작은 노드 · 이름 · 우측 tail("보류"). 재분류·버리기 유지.
  Widget _row(BuildContext context, AppTokens t, InboxItem item) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.inkSoft),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(item.rawText,
                  style: AppText.body(t.ink), maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 10),
            Text('보류', style: AppText.meta(t.inkSoft, size: 9)),
            if (widget.onReclassify != null)
              GestureDetector(
                onTap: () {
                  widget.repository.markReclassified(item.id);
                  widget.onReclassify!(item);
                  setState(() {});
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(Icons.call_split, color: t.inkSoft, size: 16),
                ),
              ),
            GestureDetector(
              onTap: () {
                widget.repository.dismiss(item.id);
                setState(() {});
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text('×', style: AppText.glyph(t.inkSoft, size: 16)),
              ),
            ),
          ],
        ),
      );
}
