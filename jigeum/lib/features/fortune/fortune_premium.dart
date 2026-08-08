/// 오늘의 운세 — HTML 기준(reference_merged) 프리미엄 패널 이식.
///
/// 기준 HTML(design-reference/jigeum_reference_merged_v5.html · data-screen="fortune")
/// 의 premium-fortune 구성을 그대로 옮긴다:
///   개요(천체지도+핵심구조) · 점수 그리드 · 레이더 · 하루 에너지 곡선 ·
///   오행 분포 · 핵심 상호작용 · 권장 시간대 · 상세 4카드 · 세부 지표 · 행동 카드.
///
/// 수치는 프로토타입 예시가 아니라 실제 계산(fortune.categories 점수, chart.wuxingScore
/// 오행 가중치)에 연결한다. 시각 표현(레이더·에너지·천체)만 HTML 레이아웃을 따른다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/explain.dart';
import '../../core/fortune.dart';
import '../../core/fortune_text.dart';
import '../../core/saju.dart';
import '../../core/theme.dart';

// 미네랄 팔레트 — HTML mineral-* 토큰과 동일 계열.
const _sage = Color(0xFF728D78); // mineral-sage
const _blue = Color(0xFF6F86A7); // mineral-blue
const _ochre = Color(0xFFAA8B57); // mineral-ochre
const _plum = Color(0xFF8F6F86); // mineral-plum
const _rose = Color(0xFFB77568); // mineral-rose
const _steel = Color(0xFF7D8996); // 금(金)

// 오행 색 — 목/화/토/금/수. (HTML five-elements-panel 막대 색과 동일)
const _elementColors = [_sage, _rose, _ochre, _steel, _blue];

const _mono = 'monospace';

/// 운세 프리미엄 패널 묶음. FortuneView 의 스크롤 상단에 통째로 얹는다.
class FortunePremiumPanels extends StatelessWidget {
  const FortunePremiumPanels({
    super.key,
    required this.fortune,
    required this.chart,
    required this.level,
  });

  final DailyFortune fortune;
  final SajuChart chart;
  final ExplainLevel level;

  FortuneCategory _cat(String key) => fortune.categories.firstWhere(
        (c) => c.key == key,
        orElse: () => fortune.categories.first,
      );

  /// 개인 카테고리(총운·지구·행운 제외)만.
  List<FortuneCategory> get _personal => fortune.categories
      .where((c) =>
          c.key != 'overall' && c.key != 'earth' && c.key != 'lucky')
      .toList();

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _overview(tk),
        _scoreGrid(tk),
        _radarPanel(tk),
        _energyPanel(tk),
        _fiveElements(tk),
        _aspects(tk),
        _timeWindows(tk),
        _detailGrid(tk),
        _detailIndex(tk),
        _actionCard(context, tk),
        const SizedBox(height: 6),
      ],
    );
  }

  // ---------------------------------------------------------------- 개요 패널
  Widget _overview(AppTokens tk) {
    final d = fortune.date;
    final lunar = fortune.solarTerm != null ? ' · ${fortune.solarTerm}' : '';
    final top = _personal.reduce((a, b) => a.score >= b.score ? a : b);
    final kws = (_personal.toList()..sort((a, b) => b.score - a.score))
        .take(4)
        .map((c) => c.title)
        .toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: tk.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 라인
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  '${d.year}.${_2(d.month)}.${_2(d.day)} · ${_weekday(d)}',
                  style: AppText.meta(tk.inkSoft, size: 11)),
              Flexible(
                child: Text(
                    '${fortune.todayPillar.hanja} '
                    '${fortune.todayPillar.kor}일$lunar',
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta(tk.inkSoft, size: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 천체 지도(개인 별자리 × 오늘 일진) — 장식적 렌더.
          Center(
            child: SizedBox(
              width: 220,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(220, 180),
                    painter: _CelestialPainter(
                      line: tk.line,
                      sage: _sage,
                      blue: _blue,
                      rose: _rose,
                      seed: _seed(),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: tk.ink),
                    child: Text(fortune.todayPillar.hanja,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: _mono,
                            fontSize: 13,
                            height: 1.0,
                            color: tk.paper)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('오늘의 핵심 구조', style: AppText.meta(tk.inkSoft, size: 10)),
          const SizedBox(height: 4),
          Text(_thesisTitle(),
              style: AppText.hTitle(tk.ink).copyWith(fontSize: 20, height: 1.3)),
          const SizedBox(height: 8),
          Text(_thesisBody(top),
              style: AppText.body(tk.ink).copyWith(height: 1.6)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in kws)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: tk.paper2, borderRadius: BorderRadius.circular(99)),
                  child: Text(k, style: AppText.meta(tk.ink, size: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _thesisTitle() {
    if (fortune.overall >= 70) return '흐름을 크게 벌리기 좋은 날';
    if (fortune.overall >= 55) return '정리와 선택이 흐름을 살리는 날';
    return '무리보다 마무리가 이로운 날';
  }

  String _thesisBody(FortuneCategory top) =>
      '오늘 기운은 나에게 「${fortune.todayTenGod}」예요. '
      '해야 할 일을 늘리기보다 이미 시작한 「${top.title}」의 범위를 닫는 편이 '
      '효율적입니다. 판단은 한 번 적어 본 뒤 결정하는 편이 안정적이에요.';

  // ---------------------------------------------------------------- 점수 그리드
  Widget _scoreGrid(AppTokens tk) {
    final items = <(String, FortuneCategory, Color, String)>[
      ('집중', _cat('study'), _sage, '종료 지점이 분명한 작업'),
      ('관계', _cat('relationship'), _blue, '즉답보다 정리된 답변'),
      ('재정', _cat('wealth'), _ochre, '충동 지출 확인'),
      ('회복', _cat('body'), _plum, '저녁 루틴이 핵심'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _scoreCard(tk, items[i])),
          ],
        ],
      ),
    );
  }

  Widget _scoreCard(
      AppTokens tk, (String, FortuneCategory, Color, String) it) {
    final (label, cat, color, note) = it;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: tk.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.meta(tk.inkSoft, size: 10)),
          const SizedBox(height: 4),
          Text('${cat.score}',
              style: TextStyle(
                  fontFamily: _mono,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: tk.ink)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: cat.score / 100,
              minHeight: 3,
              backgroundColor: tk.line,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.meta(tk.inkSoft, size: 8.5)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 레이더
  Widget _radarPanel(AppTokens tk) {
    final axes = <(String, int)>[
      ('집중', _cat('study').score),
      ('관계', _cat('relationship').score),
      ('재정', _cat('wealth').score),
      ('회복', _cat('body').score),
      ('통찰', _cat('mind').score),
    ];
    return _panel(
      tk,
      small: '오늘의 균형도',
      title: '영역별 레이더',
      trailing: '5개 영역',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(
          child: CustomPaint(
            size: const Size(240, 210),
            painter: _RadarPainter(
              axes: axes,
              line: tk.line,
              fill: _sage,
              label: tk.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 에너지 곡선
  Widget _energyPanel(AppTokens tk) {
    return _panel(
      tk,
      small: '시간대별 흐름',
      title: '하루 에너지 곡선',
      trailing: '최적 13–16시',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          CustomPaint(
            size: const Size(double.infinity, 140),
            painter: _EnergyPainter(
              line: tk.line,
              focus: _blue,
              emotion: _rose,
              label: tk.inkSoft,
              seed: _seed(),
              overall: fortune.overall,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot(tk, _blue, '집중'),
              const SizedBox(width: 14),
              _legendDot(tk, _rose, '감정 반응'),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 오행 분포
  Widget _fiveElements(AppTokens tk) {
    final score = chart.wuxingScore;
    final maxS = score.values.fold(0.0, (a, b) => a > b ? a : b);
    const em = ['계획 확장', '표현과 속도', '마무리', '기준 세우기', '정보와 감정'];
    return _panel(
      tk,
      small: '일진과 개인 명식의 상호작용',
      title: '오행 분포',
      trailing: '${wuxingKor[chart.dominantWuxing]} 강',
      child: Column(
        children: [
          const SizedBox(height: 8),
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text('${wuxingKor[i]} ${wuxingHanja[i]}',
                        style: AppText.meta(tk.ink, size: 11)),
                  ),
                  Expanded(
                    child: LayoutBuilder(builder: (context, c) {
                      final frac = maxS == 0 ? 0.0 : (score[i]! / maxS);
                      return Stack(
                        children: [
                          Container(
                              height: 7,
                              width: c.maxWidth,
                              decoration: BoxDecoration(
                                  color: tk.line,
                                  borderRadius: BorderRadius.circular(99))),
                          Container(
                              height: 7,
                              width: c.maxWidth * frac,
                              decoration: BoxDecoration(
                                  color: _elementColors[i],
                                  borderRadius: BorderRadius.circular(99))),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 26,
                    child: Text(score[i]!.toStringAsFixed(0),
                        textAlign: TextAlign.right,
                        style: AppText.meta(tk.inkSoft, size: 10)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Text(em[i],
                        style: AppText.meta(tk.inkSoft, size: 9)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 핵심 상호작용
  Widget _aspects(AppTokens tk) {
    final sorted = _personal.toList()..sort((a, b) => b.score - a.score);
    final strong = sorted.first;
    final weak = sorted.last;
    final mid = _cat('mind');
    final items = <(Color, String, String, String)>[
      (
        _rose,
        '${weak.title} ↔ 판단 속도',
        '먼저 반응하고 나중에 이유를 찾기 쉬운 구조예요. 중요한 답변은 메모 후 보내는 편이 안전합니다.',
        '주의'
      ),
      (
        _sage,
        '${strong.title} ↔ 실행력',
        '작업 범위를 30~50분 단위로 자르면 집중이 빠르게 안정됩니다. 완료 기준을 한 문장으로 적으세요.',
        '강점'
      ),
      (
        _blue,
        '${mid.title} ↔ 과부하',
        '찾아보는 행동이 실행을 대신할 수 있어요. 자료 검색은 15분 타이머를 두는 편이 좋습니다.',
        '조절'
      ),
    ];
    return _panel(
      tk,
      small: '핵심 상호작용',
      title: '오늘의 해석 포인트',
      trailing: '3개',
      child: Column(
        children: [
          const SizedBox(height: 6),
          for (final it in items) _aspectRow(tk, it),
        ],
      ),
    );
  }

  Widget _aspectRow(AppTokens tk, (Color, String, String, String) it) {
    final (color, title, body, tag) = it;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5, right: 10),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(tk.ink)),
                const SizedBox(height: 3),
                Text(body,
                    style: AppText.meta(tk.inkSoft, size: 11)
                        .copyWith(height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(tag, style: AppText.meta(color, size: 10)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 권장 시간대
  Widget _timeWindows(AppTokens tk) {
    final wins = <(String, String, String, bool)>[
      ('06–09', '정리', '가벼운 루틴', false),
      ('09–12', '준비', '자료 모으기', false),
      ('12–16', '집중', '핵심 작업', true),
      ('16–19', '소통', '정리된 답변', false),
      ('19–22', '표현', '감정 과속 주의', false),
      ('22–01', '회복', '자극 줄이기', false),
    ];
    return _panel(
      tk,
      small: '시간 선택',
      title: '권장 시간대',
      trailing: '6구간',
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            for (final w in wins) _timeCell(tk, w),
          ],
        ),
      ),
    );
  }

  Widget _timeCell(AppTokens tk, (String, String, String, bool) w) {
    final (range, label, note, best) = w;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: best ? tk.ink : tk.paper2,
        border: Border.all(color: best ? tk.ink : tk.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(range,
              style: AppText.meta(best ? tk.paper : tk.inkSoft, size: 9)),
          const SizedBox(height: 3),
          Text(label,
              style: AppText.body(best ? tk.paper : tk.ink)
                  .copyWith(fontSize: 13)),
          const SizedBox(height: 2),
          Text(note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.meta(best ? tk.paper : tk.inkSoft, size: 8.5)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 상세 4카드
  Widget _detailGrid(AppTokens tk) {
    final cards = <(String, FortuneCategory, Color)>[
      ('일과 · 학습', _cat('study'), _sage),
      ('관계 · 대화', _cat('relationship'), _blue),
      ('재정 · 소비', _cat('wealth'), _ochre),
      ('몸 · 리듬', _cat('body'), _plum),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          for (final c in cards) ...[
            _detailCard(tk, c),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _detailCard(
      AppTokens tk, (String, FortuneCategory, Color) it) {
    final (label, cat, color) = it;
    final txt = describeCategory(cat, level);
    final body = txt.body.isNotEmpty ? txt.body.first : txt.summary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
        color: tk.paper2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.meta(color, size: 10)),
          const SizedBox(height: 5),
          Text(txt.summary,
              style: AppText.body(tk.ink).copyWith(fontSize: 15, height: 1.4)),
          const SizedBox(height: 6),
          Text(body,
              style: AppText.meta(tk.inkSoft, size: 12).copyWith(height: 1.55)),
          const SizedBox(height: 8),
          _li(tk, '추천', txt.advice),
          if (txt.basis.isNotEmpty) _li(tk, '근거', txt.basis.first),
        ],
      ),
    );
  }

  Widget _li(AppTokens tk, String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$k · ', style: AppText.meta(tk.mark, size: 11)),
            Expanded(child: Text(v, style: AppText.meta(tk.ink, size: 11))),
          ],
        ),
      );

  // ---------------------------------------------------------------- 세부 지표
  Widget _detailIndex(AppTokens tk) {
    final sorted = _personal.toList()..sort((a, b) => b.score - a.score);
    final top = sorted.first;
    final low = sorted.last;
    final nums = _luckyNumbers();
    return _panel(
      tk,
      small: '오늘의 세부 지표',
      title: '행동 가이드',
      trailing: '실용 우선',
      child: Column(
        children: [
          const SizedBox(height: 4),
          _idxRow(tk, '가장 먼저 할 일', '${top.title} 범위부터 좁히기'),
          _idxRow(tk, '피해야 할 패턴', '${low.title} 무리하게 밀어붙이기'),
          _idxRow(tk, '도움이 되는 환경', '방해가 적고 자료가 한곳에 있는 자리'),
          _idxRowWidget(
            tk,
            '오늘의 색',
            Row(children: [
              _chip(_elementColors[chart.dominantWuxing]),
              const SizedBox(width: 6),
              Text(wuxingKor[chart.dominantWuxing],
                  style: AppText.body(tk.ink).copyWith(fontSize: 13)),
              const SizedBox(width: 12),
              _chip(_elementColors[chart.weakestWuxing]),
              const SizedBox(width: 6),
              Text(wuxingKor[chart.weakestWuxing],
                  style: AppText.body(tk.ink).copyWith(fontSize: 13)),
            ]),
          ),
          _idxRow(tk, '오늘의 숫자', nums.join(' · ')),
        ],
      ),
    );
  }

  Widget _idxRow(AppTokens tk, String k, String v) =>
      _idxRowWidget(tk, k, Text(v,
          textAlign: TextAlign.right,
          style: AppText.body(tk.ink).copyWith(fontSize: 13)));

  Widget _idxRowWidget(AppTokens tk, String k, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 108,
                child: Text(k, style: AppText.meta(tk.inkSoft, size: 11))),
            Expanded(child: Align(alignment: Alignment.centerRight, child: v)),
          ],
        ),
      );

  Widget _chip(Color c) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));

  // ---------------------------------------------------------------- 행동 카드
  Widget _actionCard(BuildContext context, AppTokens tk) {
    final top = _personal.reduce((a, b) => a.score >= b.score ? a : b);
    final action = '${top.title} 하나만 작게 시작하기';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: tk.ink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 행동 카드',
              style: AppText.meta(tk.paper, size: 10)
                  .copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Text('지금 실행할 한 가지',
              style: AppText.meta(tk.paper.withValues(alpha: 0.7), size: 11)),
          const SizedBox(height: 6),
          Text(action,
              style: AppText.hTitle(tk.paper).copyWith(fontSize: 20, height: 1.3)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: tk.ink,
                  content: Text('홈 빠른 담기에서 「$action」을 담아 보세요',
                      style: AppText.body(tk.paper)),
                ));
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: tk.paper),
              child: Text('오늘 할 일에 추가',
                  style: AppText.body(tk.ink).copyWith(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 공통 패널 틀
  Widget _panel(AppTokens tk,
      {required String small,
      required String title,
      required String trailing,
      required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: tk.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(small, style: AppText.meta(tk.inkSoft, size: 10)),
                    const SizedBox(height: 2),
                    Text(title,
                        style: AppText.hTitle(tk.ink).copyWith(fontSize: 17)),
                  ],
                ),
              ),
              Text(trailing, style: AppText.meta(tk.inkSoft, size: 10)),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _legendDot(AppTokens tk, Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: AppText.meta(tk.inkSoft, size: 11)),
        ],
      );

  int _seed() =>
      fortune.date.year * 10000 + fortune.date.month * 100 + fortune.date.day;

  List<int> _luckyNumbers() {
    final s = _seed();
    final a = (s % 9) + 1;
    final b = (s ~/ 7 % 22) + 2;
    final c = (s ~/ 13 % 26) + 3;
    return [a, b, c];
  }
}

String _2(int n) => n.toString().padLeft(2, '0');

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
String _weekday(DateTime d) => '${_weekdays[(d.weekday - 1) % 7]}요일';

// ==================================================================== 페인터

/// 레이더(펜타곤) — 5축 점수를 다각형으로.
class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.axes,
    required this.line,
    required this.fill,
    required this.label,
  });

  final List<(String, int)> axes;
  final Color line, fill, label;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;
    final radius = math.min(size.width, size.height) / 2 - 24;
    final n = axes.length;

    Offset pt(double ang, double r) =>
        Offset(cx + r * math.cos(ang), cy + r * math.sin(ang));
    double angleAt(int i) => -math.pi / 2 + (2 * math.pi * i / n);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = line
      ..strokeWidth = 0.7;

    // 동심 다각형 그리드(4단계).
    for (final f in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = pt(angleAt(i), radius * f);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    // 축선.
    for (var i = 0; i < n; i++) {
      canvas.drawLine(Offset(cx, cy), pt(angleAt(i), radius), gridPaint);
    }
    // 데이터 다각형.
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final v = (axes[i].$2.clamp(0, 100)) / 100.0;
      final p = pt(angleAt(i), radius * v);
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();
    canvas.drawPath(
        dataPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = fill.withValues(alpha: 0.22));
    canvas.drawPath(
        dataPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = fill
          ..strokeWidth = 1.4);
    for (var i = 0; i < n; i++) {
      final v = (axes[i].$2.clamp(0, 100)) / 100.0;
      canvas.drawCircle(pt(angleAt(i), radius * v), 3,
          Paint()..color = fill);
    }
    // 라벨.
    for (var i = 0; i < n; i++) {
      final p = pt(angleAt(i), radius + 14);
      _text(canvas, '${axes[i].$1} ${axes[i].$2}', p, label, 9.5);
    }
  }

  void _text(Canvas c, String s, Offset o, Color col, double size) {
    final tp = TextPainter(
      text: TextSpan(
          text: s, style: TextStyle(color: col, fontSize: size)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.axes != axes;
}

/// 하루 에너지 곡선 — 집중/감정 두 선.
class _EnergyPainter extends CustomPainter {
  _EnergyPainter({
    required this.line,
    required this.focus,
    required this.emotion,
    required this.label,
    required this.seed,
    required this.overall,
  });

  final Color line, focus, emotion, label;
  final int seed, overall;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height - 16; // 하단 라벨 여백

    final grid = Paint()
      ..color = line
      ..strokeWidth = 0.7;
    for (var i = 0; i <= 3; i++) {
      final y = h * i / 3;
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    Path curve(int salt, double base, double amp) {
      final path = Path();
      const pts = 7;
      for (var i = 0; i <= pts; i++) {
        final x = w * i / pts;
        final r = (((seed + salt) * (i + 3)) % 100) / 100.0; // 결정적 지터
        final norm = (base + amp * math.sin(i * 0.9 + salt) + (r - 0.5) * 0.15)
            .clamp(0.05, 0.95);
        final y = h * (1 - norm);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      return path;
    }

    final b = (overall.clamp(20, 90)) / 100.0;
    canvas.drawPath(
        curve(1, b, 0.22),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = focus
          ..strokeWidth = 2);
    canvas.drawPath(
        curve(5, b * 0.85, 0.16),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = emotion
          ..strokeWidth = 2);

    // 시간 라벨.
    const marks = ['06', '10', '14', '18', '22'];
    for (var i = 0; i < marks.length; i++) {
      final x = w * i / (marks.length - 1);
      final tp = TextPainter(
        text: TextSpan(
            text: marks[i], style: TextStyle(color: label, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((x - tp.width / 2).clamp(0, w - tp.width), h + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyPainter old) =>
      old.seed != seed || old.overall != overall;
}

/// 천체 지도 — 개인 별자리 × 오늘 일진을 겹친 장식적 링/궤도.
class _CelestialPainter extends CustomPainter {
  _CelestialPainter({
    required this.line,
    required this.sage,
    required this.blue,
    required this.rose,
    required this.seed,
  });

  final Color line, sage, blue, rose;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) / 2 - 6;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = line
      ..strokeWidth = 0.8;
    for (final f in [1.0, 0.74, 0.46]) {
      canvas.drawCircle(Offset(cx, cy), r * f, ring);
    }
    // 하우스 라인(수직/수평/대각).
    final house = Paint()
      ..color = line
      ..strokeWidth = 0.6;
    for (var i = 0; i < 4; i++) {
      final a = math.pi * i / 4;
      canvas.drawLine(
        Offset(cx - r * math.cos(a), cy - r * math.sin(a)),
        Offset(cx + r * math.cos(a), cy + r * math.sin(a)),
        house,
      );
    }
    // 궤도 곡선 3개(sage/blue/rose) — 결정적 위상.
    final orbits = [sage, blue, rose];
    for (var i = 0; i < orbits.length; i++) {
      final phase = ((seed + i * 37) % 360) * math.pi / 180.0;
      final rr = r * (0.55 + 0.13 * i);
      final path = Path();
      for (var k = 0; k <= 40; k++) {
        final a = 2 * math.pi * k / 40;
        final wob = 1 + 0.12 * math.sin(a * 3 + phase);
        final x = cx + rr * wob * math.cos(a);
        final y = cy + rr * wob * 0.62 * math.sin(a);
        k == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = orbits[i].withValues(alpha: 0.55)
            ..strokeWidth = 1.1);
    }
    // 행성 점 3개(태양/달/ASC) — 결정적 각도.
    final dots = [
      (sage, (seed % 360) * math.pi / 180.0, 0.82),
      (blue, ((seed * 7) % 360) * math.pi / 180.0, 0.60),
      (rose, ((seed * 13) % 360) * math.pi / 180.0, 0.90),
    ];
    for (final (col, a, rad) in dots) {
      final p = Offset(cx + r * rad * math.cos(a), cy + r * rad * math.sin(a));
      canvas.drawCircle(p, 4, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(covariant _CelestialPainter old) => old.seed != seed;
}
