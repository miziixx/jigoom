/// 보류함 화면. 기획서 §5 커밋9(화면) + §9(뱃지) + 커밋10.
///
/// ⚠️ 위젯 레이어 — 이 환경(Flutter 없음)에서 컴파일 검증 못 함. 기기 확인 필요.
/// 쌓인 원문을 목록으로 보고, 한 건을 다른 곳으로 재분류하거나 버린다.
/// 데이터/재분류 로직은 [InboxRepository](검증됨)에 있다.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
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
    final repo = widget.repository;
    _repoListenable = repo is Listenable ? repo : null;
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final items = widget.repository.list(status: InboxStatus.pending);
    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(
        backgroundColor: t.paper,
        elevation: 0,
        title: Text('보류함', style: AppText.hTitle(t.ink)),
      ),
      body: items.isEmpty
          ? Center(child: Text('비어 있어요', style: AppText.meta(t.inkSoft)))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: t.line),
              itemBuilder: (context, i) => _row(context, t, items[i]),
            ),
    );
  }

  Widget _row(BuildContext context, AppTokens t, InboxItem item) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(item.rawText, style: AppText.body(t.ink))),
            if (widget.onReclassify != null)
              IconButton(
                icon: Icon(Icons.call_split, color: t.inkSoft, size: 20),
                tooltip: '다시 분류',
                onPressed: () {
                  widget.repository.markReclassified(item.id);
                  widget.onReclassify!(item);
                  setState(() {});
                },
              ),
            IconButton(
              icon: Icon(Icons.close, color: t.inkSoft, size: 20),
              tooltip: '버리기',
              onPressed: () {
                widget.repository.dismiss(item.id);
                setState(() {});
              },
            ),
          ],
        ),
      );
}
