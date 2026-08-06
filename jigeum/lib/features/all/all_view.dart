import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../capture/quick_capture_input.dart';
import '../today/today_view.dart';

/// 전체 탭 — 편집형 목차: 전체 할 일(날짜 필터) / LATER / DONE.
class AllView extends ConsumerStatefulWidget {
  const AllView({super.key});

  @override
  ConsumerState<AllView> createState() => _AllViewState();
}

class _AllViewState extends ConsumerState<AllView> {
  /// 0 전체 · 1 오늘 · 2 7일 · 3 이번 달.
  int _range = 0;

  bool _inRange(Node n) {
    if (_range == 0) return true;
    final d = n.date;
    if (d == null) return false; // 날짜 없는 일은 '전체'에서만.
    final today = todayDate();
    return switch (_range) {
      1 => dateOnly(d) == today,
      2 => !dateOnly(d).isBefore(today) &&
          dateOnly(d).isBefore(today.add(const Duration(days: 7))),
      3 => d.year == today.year && d.month == today.month,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final all = ref.watch(allNodesProvider).valueOrNull ?? const [];

    final openAll = all
        .where(
            (n) => n.status == NodeStatus.open && n.type != NodeType.folder)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final open = openAll.where(_inRange).toList();

    final rows = <Widget>[];


    // ── § 전체 할 일 + 날짜 필터(전체/오늘/7일/이번 달/기간) ──────────
    rows.add(_sectionHead(tk, '전체 할 일', '＋ 할 일',
        () => showQuickCaptureInput(context, ref)));
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              PillChip(
                label: const ['전체', '오늘', '7일', '이번 달', '기간'][i],
                selected: _range == i,
                onTap: () => setState(() => _range = i),
              ),
            ],
          ],
        ),
      ),
    ));
    if (open.isEmpty) {
      rows.add(emptyNote(
          context, _range == 0 ? '담아둔 게 없어요' : '이 기간엔 할 일이 없어요'));
    } else {
      for (final n in open) {
        rows.add(SimpleTile(node: n));
      }
    }


    rows.add(const SizedBox(height: 16));

    return Container(
      color: tk.paper,
      child: ListView(padding: EdgeInsets.zero, children: rows),
    );
  }

  /// § 세리프 섹션 제목 + 우측 액션 + 하단 헤어라인.
  Widget _sectionHead(
      AppTokens tk, String title, String action, VoidCallback onAction) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 18, kGutter, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('' /*§제거*/, style: AppText.hTitle(tk.mark).copyWith(fontSize: 15)),
              Text(title, style: AppText.hTitle(tk.ink).copyWith(fontSize: 16)),
              const Spacer(),
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text(action, style: AppText.meta(tk.mark, size: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: tk.line),
        ],
      ),
    );
  }
}
