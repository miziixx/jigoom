import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/astrology.dart' as astro;
import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 일과(시간) 탭 대시보드 — 오늘 날짜·일진(한자)·별자리 + 일정/루틴/기록 요약.
class TimeDashboard extends ConsumerWidget {
  const TimeDashboard({super.key});

  static String _hm(int m) {
    final h = m ~/ 60;
    final mm = m % 60;
    if (h == 0) return '${mm}m';
    if (mm == 0) return '${h}h';
    return '${h}h ${mm}m';
  }

  /// 별자리(서양 점성술) 섹션 — 기호·한글·한자 + 영문·기간 + 원소·지배성 + 상승/하강.
  Widget _zodiacSection(AppTokens tk, DateTime now) {
    final z = zodiacOf(now);
    final rise = risingOf(now);
    final desc = descendantOf(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('ZODIAC'),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(z.symbol, style: AppText.metaSans(tk.ink, size: 22)),
              const SizedBox(width: 10),
              Text(z.name, style: AppText.hTitle(tk.ink)),
              const SizedBox(width: 8),
              Text(z.hanja, style: AppText.metaSans(tk.inkSoft, size: 13)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 3, kGutter, 0),
          child: Text('${z.eng} · ${z.range}',
              style: AppText.metaSans(tk.inkSoft)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 1, kGutter, 0),
          child: Text('원소 ${z.element} · 지배성 ${z.planet}',
              style: AppText.metaSans(tk.inkSoft)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 3, kGutter, 0),
          child: Builder(builder: (_) {
            final moon = astro.signAt(
                astro.signIndexFromLongitude(astro.moonEclipticLongitude(now)));
            return Text('달 ${moon.symbol} ${moon.name}',
                style: AppText.metaSans(tk.ink));
          }),
        ),
        // 상승궁(어센던트)·하강궁(디센던트) — 지금 하늘 근사.
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 7, kGutter, 0),
          child: Text(
              '상승 ${rise.symbol} ${rise.name} · 하강 ${desc.symbol} ${desc.name}',
              style: AppText.metaSans(tk.ink)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 1, kGutter, 0),
          child: Text('지금 하늘 기준 · 근사',
              style: AppText.metaSans(tk.inkSoft, size: 9)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final today = todayDate();
    final now = DateTime.now();
    final sky = ref.watch(settingsProvider);

    final items =
        ref.watch(schedulesForDateProvider(today)).valueOrNull ?? const [];
    final routines = ref.watch(routinesProvider).valueOrNull ?? const [];
    final blocks =
        ref.watch(timeBlocksForDateProvider(today)).valueOrNull ?? const [];

    final totalMin = items.fold<int>(
        0, (a, s) => a + (s.endMin - s.startMin).clamp(0, 1440));
    final activeRoutines = routines.where((r) => r.active).length;
    final filled = {for (final b in blocks) if (b.content.isNotEmpty) b.block};

    final sorted = [...items]..sort((a, b) => a.startMin.compareTo(b.startMin));

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // 날짜 + 일진(한자) + 별자리
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(DateFormat('M월 d일', 'ko').format(now),
                    style: AppText.hTitle(tk.ink)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                      sky.showSaju
                          ? '${DateFormat('EEEE', 'ko').format(now)} · ${sajuLabel(today)}'
                          : DateFormat('EEEE', 'ko').format(now),
                      style: AppText.metaSans(tk.inkSoft)),
                ),
              ],
            ),
          ),

          // 별자리 (점성술)
          if (sky.showZodiac) _zodiacSection(tk, now),

          // 일정
          SectionLabel('SCHEDULE', count: items.length),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
            child: Text('총 ${_hm(totalMin)}', style: AppText.body(tk.ink)),
          ),
          for (final s in sorted.take(4))
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
              child: Row(
                children: [
                  SizedBox(
                      width: 44,
                      child: Text(minToShort(s.startMin),
                          style: AppText.meta(tk.inkSoft))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(tk.ink))),
                ],
              ),
            ),
          if (items.isEmpty) emptyNote(context, '오늘 일정이 없어요'),

          // 루틴
          SectionLabel('ROUTINE', count: routines.length),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
            child: Text('$activeRoutines개 활성', style: AppText.body(tk.ink)),
          ),

          // 기록 (타임트래커)
          SectionLabel('LOG', count: filled.length),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 8),
            child:
                Text('${filled.length} / 48 칸 기록', style: AppText.body(tk.ink)),
          ),
          // 하루 48블록 채움 스트립
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 0),
            child: Row(
              children: [
                for (var i = 0; i < 48; i++)
                  Expanded(
                    child: Container(
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      color: filled.contains(i) ? tk.ink : tk.line,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('00', style: AppText.meta(tk.inkSoft, size: 9)),
                Text('06', style: AppText.meta(tk.inkSoft, size: 9)),
                Text('12', style: AppText.meta(tk.inkSoft, size: 9)),
                Text('18', style: AppText.meta(tk.inkSoft, size: 9)),
                Text('24', style: AppText.meta(tk.inkSoft, size: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
