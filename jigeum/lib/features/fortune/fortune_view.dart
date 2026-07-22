import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/fortune.dart';
import '../../core/journal.dart';
import '../../core/saju.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../settings/settings_screen.dart';

/// 오늘의 운세 + 사주 정밀 분석 대시보드.
/// 설정의 생년월일(양력 변환)·시각·출생지·성별로 오프라인 계산.
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
        child: s.hasBirth ? _FortuneBody(settings: s) : const _EmptyState(),
      ),
    );
  }
}

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
            Text('생년월일시를 입력하면\n오늘의 운세와 사주 분석을 볼 수 있어요',
                textAlign: TextAlign.center, style: AppText.body(tk.ink)),
            const SizedBox(height: 8),
            Text('사주팔자 + 서양 점성술 · 진태양시 보정 · 대운/세운',
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
  const _FortuneBody({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final chart = computeSaju(
      settings.birth!,
      hasHour: settings.birthHasTime,
      longitude: settings.birthLongitude,
      male: settings.birthMale,
    );
    final fortune = computeDailyFortune(chart, DateTime.now());

    return ListView(
      padding: const EdgeInsets.only(bottom: 44),
      children: [
        _TodayHeader(fortune: fortune),
        const SectionLabel('오늘의 카테고리'),
        for (final c in fortune.categories) _CategoryCard(cat: c),
        const SizedBox(height: 8),
        const SectionLabel('사주 원국 (정밀)'),
        _ChartCard(chart: chart),
        const SectionLabel('오행 분석'),
        _WuxingAnalysis(chart: chart),
        const SectionLabel('십신 분포'),
        _TenGodDist(chart: chart),
        const SectionLabel('대운 · 세운'),
        _DaeunTimeline(chart: chart),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: Text(
            '※ 만세력 간지·지장간·오행·십신·대운과 서양 태양 별자리를 규칙으로 조합한 '
            '해석입니다. 신강신약·용신은 대표 규칙에 따른 근사예요. 재미와 참고로 즐겨 주세요.',
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

/// 사주 원국 카드 — 4기둥(십신·지장간) + 일간·별자리 + 보정 정보.
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, p) in pillars)
                  Expanded(
                      child: _PillarCell(
                          label: label, pillar: p, dayStem: chart.dayStem)),
              ],
            ),
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
                    Text('일간(나)', style: AppText.meta(tk.inkSoft, size: 10)),
                    const SizedBox(height: 2),
                    Text(
                        '${stemHanja[chart.dayStem]} ${stemKor[chart.dayStem]}'
                        '·${wuxingKor[stemWuxing(chart.dayStem)]}'
                        '(${wuxingHanja[stemWuxing(chart.dayStem)]})',
                        style: AppText.body(tk.ink)),
                    const SizedBox(height: 2),
                    Text(
                        chart.isStrong
                            ? '신강 ${chart.strengthPct}% — 자기 힘이 강함'
                            : '신약 ${chart.strengthPct}% — 도움받아 크는 사주',
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
          if (!chart.hasHour) ...[
            const SizedBox(height: 10),
            Text('※ 시각 미입력 — 시주 제외, 진태양시 보정 없음.',
                style: AppText.meta(tk.inkSoft, size: 10)),
          ] else if (chart.trueTime != null) ...[
            const SizedBox(height: 10),
            Text(
                '진태양시 보정: 경도 ${chart.trueTime!.lonCorrMin >= 0 ? '+' : ''}'
                '${chart.trueTime!.lonCorrMin}분, 균시차 '
                '${chart.trueTime!.eotMin >= 0 ? '+' : ''}${chart.trueTime!.eotMin}분'
                '${chart.trueTime!.dst ? ', 서머타임 −60분' : ''} → 실제 '
                '${_2(chart.effective.hour)}:${_2(chart.effective.minute)}',
                style: AppText.meta(tk.inkSoft, size: 10)),
          ],
        ],
      ),
    );
  }
}

class _PillarCell extends StatelessWidget {
  const _PillarCell(
      {required this.label, required this.pillar, required this.dayStem});
  final String label;
  final Pillar? pillar;
  final int dayStem;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final isDay = pillar != null && pillar!.stem == dayStem && label == '일주';
    return Column(
      children: [
        Text(label, style: AppText.meta(tk.inkSoft, size: 10)),
        const SizedBox(height: 4),
        if (pillar == null) ...[
          Text('시 모름', style: AppText.meta(tk.inkSoft, size: 10)),
          const SizedBox(height: 20),
          Text('—', style: AppText.glyph(tk.inkSoft, size: 22)),
        ] else ...[
          Text(isDay ? '일원' : tenGodName(dayStem, pillar!.stem),
              style: AppText.meta(tk.mark, size: 9)),
          const SizedBox(height: 3),
          Text(stemHanja[pillar!.stem], style: _big(tk)),
          Text(branchHanja[pillar!.branch], style: _big(tk)),
          const SizedBox(height: 3),
          Text(tenGodName(dayStem, mainHiddenStem(pillar!.branch)),
              style: AppText.meta(tk.inkSoft, size: 9)),
          const SizedBox(height: 3),
          Text(
              hiddenStems(pillar!.branch)
                  .map((s) => stemHanja[s])
                  .join(),
              style: AppText.meta(tk.inkSoft, size: 10)),
        ],
      ],
    );
  }

  TextStyle _big(AppTokens tk) => TextStyle(
      fontFamily: kMonoFamily,
      fontSize: 23,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: tk.ink);
}

/// 오행 분석 — 가중 점수 막대 + 신강/신약 + 용신.
class _WuxingAnalysis extends StatelessWidget {
  const _WuxingAnalysis({required this.chart});
  final SajuChart chart;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final score = chart.wuxingScore;
    final maxS = score.values.reduce((a, b) => a > b ? a : b);
    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: tk.line, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text('${wuxingKor[i]} ${wuxingHanja[i]}',
                        style: AppText.meta(
                            i == chart.dominantWuxing ? tk.ink : tk.inkSoft,
                            size: 11)),
                  ),
                  Expanded(
                    child: LayoutBuilder(builder: (context, c) {
                      final w = maxS == 0 ? 0.0 : c.maxWidth * score[i]! / maxS;
                      return Stack(
                        children: [
                          Container(height: 8, width: c.maxWidth, color: tk.line),
                          Container(
                              height: 8,
                              width: w,
                              color: i == chart.dominantWuxing
                                  ? tk.ink
                                  : tk.inkSoft),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(score[i]!.toStringAsFixed(1),
                        textAlign: TextAlign.right,
                        style: AppText.meta(tk.inkSoft, size: 10)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Divider(color: tk.line, height: 1),
          const SizedBox(height: 10),
          _kv(tk, '강약', chart.isStrong ? '신강 (${chart.strengthPct}%)' : '신약 (${chart.strengthPct}%)'),
          _kv(tk, '득령', chart.hasMonthCommand ? '월령을 얻음 (뿌리 있음)' : '월령을 못 얻음'),
          _kv(tk, '가장 강한 오행', '${wuxingKor[chart.dominantWuxing]}(${wuxingHanja[chart.dominantWuxing]})'),
          _kv(tk, '가장 약한 오행', '${wuxingKor[chart.weakestWuxing]}(${wuxingHanja[chart.weakestWuxing]})'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: tk.paper2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('용신 ', style: AppText.meta(tk.mark, size: 12)),
                Expanded(
                  child: Text(chart.yongsinReason,
                      style: AppText.body(tk.ink)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(AppTokens tk, String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 92,
                child: Text(k, style: AppText.meta(tk.inkSoft, size: 11))),
            Expanded(child: Text(v, style: AppText.meta(tk.ink, size: 12))),
          ],
        ),
      );
}

/// 십신 분포 — 5그룹 카운트 막대.
class _TenGodDist extends StatelessWidget {
  const _TenGodDist({required this.chart});
  final SajuChart chart;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final dist = chart.tenGodDistribution;
    final maxV = dist.values.fold(1, (a, b) => a > b ? a : b);
    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: tk.line, width: 1)),
      child: Column(
        children: [
          for (final g in TenGodGroup.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tenGodGroupKor[g.index],
                            style: AppText.meta(tk.ink, size: 11)),
                        Text(tenGodGroupDesc[g.index],
                            style: AppText.meta(tk.inkSoft, size: 9)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(builder: (context, c) {
                      return Stack(
                        children: [
                          Container(height: 6, width: c.maxWidth, color: tk.line),
                          Container(
                              height: 6,
                              width: c.maxWidth * dist[g]! / maxV,
                              color: tk.inkSoft),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 18,
                    child: Text('${dist[g]}',
                        textAlign: TextAlign.right,
                        style: AppText.meta(tk.ink, size: 11)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 대운 타임라인 + 세운(올해).
class _DaeunTimeline extends StatelessWidget {
  const _DaeunTimeline({required this.chart});
  final SajuChart chart;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final now = DateTime.now();
    final cur = chart.currentDaeun(now);
    // 세운(올해).
    final yi = yearGanziIndex(now);
    final yearStem = yi % 10;
    final seun = '${yearGanziHanja(now)}(${stemKor[yearStem]}${branchKor[yi % 12]})';
    final seunGod = tenGodName(chart.dayStem, yearStem);

    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: tk.line, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('대운 — ${chart.forward ? '순행' : '역행'} · 첫 대운 ${chart.daeunStartAge}세부터',
              style: AppText.meta(tk.inkSoft, size: 11)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final d in chart.daeun)
                  _daeunCell(tk, d, cur != null && d.startAge == cur.startAge),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: tk.line, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('세운(${now.year}) ', style: AppText.meta(tk.mark, size: 12)),
              Expanded(
                child: Text('$seun · 나에게 「$seunGod」',
                    style: AppText.body(tk.ink)),
              ),
            ],
          ),
          if (cur != null) ...[
            const SizedBox(height: 6),
            Text(
                '현재 대운: ${cur.pillar.hanja}(${cur.pillar.kor}) '
                '${cur.startAge}~${cur.endAge}세 · 천간 「${tenGodName(chart.dayStem, cur.pillar.stem)}」',
                style: AppText.meta(tk.inkSoft, size: 11)),
          ],
        ],
      ),
    );
  }

  Widget _daeunCell(AppTokens tk, Daeun d, bool current) {
    return Container(
      width: 52,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        border: Border.all(
            color: current ? tk.ink : tk.line, width: current ? 1.5 : 1),
        color: current ? tk.paper2 : null,
      ),
      child: Column(
        children: [
          Text('${d.startAge}세', style: AppText.meta(tk.inkSoft, size: 9)),
          const SizedBox(height: 4),
          Text(stemHanja[d.pillar.stem],
              style: TextStyle(
                  fontFamily: kMonoFamily,
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: tk.ink)),
          Text(branchHanja[d.pillar.branch],
              style: TextStyle(
                  fontFamily: kMonoFamily,
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: tk.ink)),
        ],
      ),
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
              Expanded(child: Text(cat.title, style: AppText.body(tk.ink))),
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
                child: Text(cat.advice, style: AppText.meta(tk.ink, size: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
