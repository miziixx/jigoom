import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import 'plant_view.dart';

/// 정원 — 지난 날들의 작은 식물 숲. 하루 한 그루, 그날 완료·시작(물)만큼 자란다.
/// 잔잔한 회고용. 경쟁·점수·시들기 없음.
class GardenPage extends ConsumerWidget {
  const GardenPage({super.key});

  static const _weeks = 6; // 최근 6주

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final today = todayDate();
    final rawStart = today.subtract(const Duration(days: _weeks * 7 - 1));
    // 주 시작(일요일)에 정렬.
    final start = rawStart.subtract(Duration(days: rawStart.weekday % 7));

    final wins = ref
            .watch(winCountsInRangeProvider((start: start, end: today)))
            .valueOrNull ??
        const <DateTime, int>{};
    final starts = ref
            .watch(startedCountsInRangeProvider((start: start, end: today)))
            .valueOrNull ??
        const <DateTime, int>{};

    int waterOf(DateTime d) => (wins[d] ?? 0) + (starts[d] ?? 0);

    var total = 0;
    var activeDays = 0;
    for (var c = start; !c.isAfter(today); c = c.add(const Duration(days: 1))) {
      final w = waterOf(c);
      total += w;
      if (w > 0) activeDays++;
    }
    final streak = ref.watch(streakProvider);

    const dows = ['일', '월', '화', '수', '목', '금', '토'];

    final rows = <Widget>[];
    for (var wk = start;
        !wk.isAfter(today);
        wk = wk.add(const Duration(days: 7))) {
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        final day = wk.add(Duration(days: i));
        final future = day.isAfter(today);
        final water = future ? 0 : waterOf(day);
        final isToday = day == today;
        cells.add(Expanded(
          child: Opacity(
            opacity: future ? 0.0 : 1.0,
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: PlantGlyph(water: water, height: 50),
                ),
                const SizedBox(height: 2),
                Text('${day.day}',
                    style: isToday
                        ? AppText.meta(tk.mark, size: 10)
                        : AppText.metaSans(tk.inkSoft, size: 10)),
              ],
            ),
          ),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.end, children: cells),
      ));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('정원')),
      body: Container(
        color: tk.paper,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 0),
              child: Text('완료·시작이 쌓일수록 그날의 식물이 자라요. 시들지 않아요.',
                  style: AppText.meta(tk.inkSoft, size: 12)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
              child: Text(
                  [
                    if (streak >= 2) '$streak일 연속',
                    '$activeDays일 · 물 $total번',
                  ].join('   ·   '),
                  style: AppText.metaSans(tk.inkSoft, size: 11)),
            ),
            // 요일 머리글
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Text(dows[i],
                          textAlign: TextAlign.center,
                          style: AppText.metaSans(
                              i == 0 ? tk.mark : tk.inkSoft,
                              size: 10)),
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 1,
              color: tk.line,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: Column(children: rows),
            ),
          ],
        ),
      ),
    );
  }
}
