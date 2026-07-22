import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/fortune.dart';
import '../../core/journal.dart';
import '../../core/saju.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../settings/settings_screen.dart';

/// 오늘의 운세 — 정통 사주팔자 + 서양 점성술 기반, 카테고리별 상세 풀이.
/// 설정에 저장된 생년월일(+시각)으로 오프라인 계산.
class FortuneView extends ConsumerWidget {
  const FortuneView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final s = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 운세')),
      body: Container(
        color: tk.paper,
        child: s.hasBirth
            ? _FortuneBody(birth: s.birth!, hasTime: s.birthHasTime)
            : const _EmptyState(),
      ),
    );
  }
}

/// 사주 미입력 안내 — 설정으로 유도.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('☯', style: AppText.glyph(tk.inkSoft, size: 40)),
            const SizedBox(height: 16),
            Text('생년월일시를 입력하면\n오늘의 운세를 볼 수 있어요',
                textAlign: TextAlign.center, style: AppText.body(tk.ink)),
            const SizedBox(height: 8),
            Text('사주팔자 + 서양 점성술로 카테고리별 풀이',
                textAlign: TextAlign.center, style: AppText.meta(tk.inkSoft)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: const Text('설정에서 입력하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FortuneBody extends StatelessWidget {
  const _FortuneBody({required this.birth, required this.hasTime});
  final DateTime birth;
  final bool hasTime;

  @override
  Widget build(BuildContext context) {
    final chart = computeSaju(birth, hasHour: hasTime);
    final fortune = computeDailyFortune(chart, DateTime.now());

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _TodayHeader(fortune: fortune),
        const SectionLabel('MY 사주 원국'),
        _ChartCard(chart: chart),
        const SectionLabel('오늘의 카테고리'),
        for (final c in fortune.categories) _CategoryCard(cat: c),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: Text(
            '※ 사주(만세력 간지·오행·십신)와 서양 태양 별자리를 규칙으로 조합한 해석입니다. '
            '재미와 참고로 즐겨 주세요.',
            style: AppText.meta(t(context).inkSoft),
          ),
        ),
      ],
    );
  }
}

/// 상단: 오늘 날짜·일진·총점.
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.fortune});
  final DailyFortune fortune;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final d = fortune.date;
    final wd = ['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${d.year}.${_2(d.month)}.${_2(d.day)} ($wd)',
              style: AppText.meta(tk.inkSoft, size: 12)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fortune.overall}',
                  style: TextStyle(
                      fontFamily: kMonoFamily,
                      fontSize: 44,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: tk.ink)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('점 · ${fortune.overallGrade}',
                    style: AppText.meta(tk.mark, size: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '오늘 일진 ${fortune.todayPillar.hanja}(${fortune.todayPillar.kor}일)'
            '${fortune.solarTerm != null ? ' · 절기 ${fortune.solarTerm}' : ''}',
            style: AppText.meta(tk.inkSoft),
          ),
          Text('오늘 기운은 나에게 「${fortune.todayTenGod}」',
              style: AppText.meta(tk.inkSoft)),
        ],
      ),
    );
  }
}

/// 내 사주 원국 카드 — 4기둥 + 오행 밸런스 + 별자리.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.chart});
  final SajuChart chart;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final zodiac = zodiacOf(chart.birth);
    final pillars = <(String, Pillar?)>[
      ('시주', chart.hour),
      ('일주', chart.day),
      ('월주', chart.month),
      ('년주', chart.year),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: tk.line, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (label, p) in pillars)
                Expanded(child: _PillarCell(label: label, pillar: p)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: tk.line, height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('일간(나)',
                        style: AppText.meta(tk.inkSoft, size: 10)),
                    const SizedBox(height: 2),
                    Text(
                        '${stemHanja[chart.dayStem]} ${stemKor[chart.dayStem]}'
                        '·${wuxingKor[stemWuxing(chart.dayStem)]}'
                        '(${wuxingHanja[stemWuxing(chart.dayStem)]})',
                        style: AppText.body(tk.ink)),
                    const SizedBox(height: 2),
                    Text(chart.isStrong ? '신강 — 자기 힘이 강한 사주' : '신약 — 도움을 받아 크는 사주',
                        style: AppText.meta(tk.inkSoft, size: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${zodiac.symbol} ${zodiac.name}',
                      style: AppText.metaSans(tk.ink, size: 13)),
                  const SizedBox(height: 2),
                  Text('${zodiac.eng} · ${zodiac.element}',
                      style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WuxingBalance(chart: chart),
          if (!chart.hasHour) ...[
            const SizedBox(height: 8),
            Text('※ 태어난 시각 미입력 — 시주를 빼고 계산했어요.',
                style: AppText.meta(tk.inkSoft, size: 10)),
          ],
        ],
      ),
    );
  }
}

class _PillarCell extends StatelessWidget {
  const _PillarCell({required this.label, required this.pillar});
  final String label;
  final Pillar? pillar;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Column(
      children: [
        Text(label, style: AppText.meta(tk.inkSoft, size: 10)),
        const SizedBox(height: 6),
        if (pillar == null)
          Text('—', style: AppText.glyph(tk.inkSoft, size: 22))
        else ...[
          Text(stemHanja[pillar!.stem],
              style: TextStyle(
                  fontFamily: kMonoFamily,
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: tk.ink)),
          Text(branchHanja[pillar!.branch],
              style: TextStyle(
                  fontFamily: kMonoFamily,
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: tk.ink)),
          const SizedBox(height: 4),
          Text('${stemKor[pillar!.stem]}${branchKor[pillar!.branch]}',
              style: AppText.meta(tk.inkSoft, size: 10)),
        ],
      ],
    );
  }
}

/// 오행 분포 막대 — 목화토금수 5칸.
class _WuxingBalance extends StatelessWidget {
  const _WuxingBalance({required this.chart});
  final SajuChart chart;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final counts = chart.wuxingCount;
    final maxC = counts.values.reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오행 밸런스', style: AppText.meta(tk.inkSoft, size: 10)),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  child: Column(
                    children: [
                      // 세로 막대(높이 = 개수 비율).
                      SizedBox(
                        height: 40,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${counts[i]}',
                                style: AppText.meta(tk.inkSoft, size: 9)),
                            const SizedBox(height: 2),
                            Container(
                              height: maxC == 0
                                  ? 2
                                  : (4 + 24 * counts[i]! / maxC),
                              color: i == chart.dominantWuxing
                                  ? tk.ink
                                  : (counts[i] == 0 ? tk.line : tk.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${wuxingKor[i]}\n${wuxingHanja[i]}',
                          textAlign: TextAlign.center,
                          style: AppText.meta(
                              i == chart.dominantWuxing ? tk.ink : tk.inkSoft,
                              size: 9)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 카테고리 카드 — 제목·점수바·풀이·조언.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.cat});
  final FortuneCategory cat;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tk.line, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                  width: 22,
                  child: Text(cat.glyph, style: AppText.glyph(tk.mark))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(cat.title, style: AppText.body(tk.ink)),
              ),
              Text('${cat.score}',
                  style: TextStyle(
                      fontFamily: kMonoFamily,
                      fontSize: 18,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: tk.ink)),
              const SizedBox(width: 4),
              Text(cat.grade, style: AppText.meta(tk.mark, size: 11)),
            ],
          ),
          const SizedBox(height: 8),
          _ScoreBar(score: cat.score),
          const SizedBox(height: 4),
          Text(cat.summary, style: AppText.meta(tk.inkSoft, size: 11)),
          const SizedBox(height: 10),
          for (final line in cat.lines) ...[
            Text(line, style: AppText.body(tk.ink)),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('→ ', style: AppText.meta(tk.mark)),
              Expanded(
                child: Text(cat.advice,
                    style: AppText.meta(tk.ink, size: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 점수 막대 — 잉크 채움, 규칙선 배경.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            Container(height: 3, width: c.maxWidth, color: tk.line),
            Container(
                height: 3, width: c.maxWidth * score / 100, color: tk.ink),
          ],
        );
      },
    );
  }
}

String _2(int n) => n.toString().padLeft(2, '0');
