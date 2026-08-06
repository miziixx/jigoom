import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/repos/time_track_repository.dart';
import '../../providers.dart';

/// 특정 블록에 기록 입력 다이얼로그 (화면·위젯 진입 공용).
Future<void> showTimeTrackInput(
  BuildContext context,
  WidgetRef ref, {
  required DateTime date,
  required int block,
}) async {
  final repo = ref.read(timeTrackRepoProvider);
  final existing = await repo.getBlock(date, block);
  if (!context.mounted) return;
  final controller = TextEditingController(text: existing?.content ?? '');
  final start = blockLabel(block);
  final end = blockLabel((block + 1) % 48 == 0 ? 48 : block + 1);
  // 레퍼런스 .sheet — 핸들 + [ 제목 ] + 플랫 필드 + 취소/저장. (Material 팝업 대신)
  final text = await showEditorialSheet<String>(
    context,
    scrollable: false,
    builder: (ctx) {
      final tk = t(ctx);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 제목 — [ 06:00–06:30 ] (대괄호는 포인트색).
          RichText(
            text: TextSpan(children: [
              TextSpan(text: '[ ', style: AppText.serif(tk.mark, size: 17)),
              TextSpan(
                  text: '$start–$end', style: AppText.serif(tk.ink, size: 17)),
              TextSpan(text: ' ]', style: AppText.serif(tk.mark, size: 17)),
            ]),
          ),
          const SizedBox(height: 14),
          // 다중 기록: 첫 줄은 제목, 다음 줄부터 줄바꿈으로 여러 작업.
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 7,
            keyboardType: TextInputType.multiline,
            style: AppText.body(tk.ink),
            cursorColor: tk.mark,
            decoration: InputDecoration(
              isDense: true,
              hintText: '제목\n— 한 일을 줄바꿈으로 여러 개',
              hintStyle: AppText.meta(tk.inkSoft, size: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: tk.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: tk.ink, width: 1.5)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: EdButton(
                  label: '취소',
                  filled: false,
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EdButton(
                  label: '저장',
                  onTap: () => Navigator.of(ctx).pop(controller.text),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  if (text != null) {
    await repo.setBlock(date, block, text);
  }
}

/// 빠른 시간 기록 — 시간(30분 블록)을 ‹ › 로 고르고, 한 줄 적고 '담기'를
/// 누를 때마다 그 시간에 **하나씩** 누적한다. 시간 미선택 시 현재 시간.
/// (기존 기록 편집은 [showTimeTrackInput] 의 여러 줄 편집기를 그대로 쓴다.)
Future<void> showTimeQuickAdd(
  BuildContext context,
  WidgetRef ref, {
  required DateTime date,
  required int block,
}) async {
  await showEditorialSheet<void>(
    context,
    scrollable: false,
    builder: (ctx) => _TimeQuickAdd(date: date, initialBlock: block),
  );
}

class _TimeQuickAdd extends ConsumerStatefulWidget {
  const _TimeQuickAdd({required this.date, required this.initialBlock});
  final DateTime date;
  final int initialBlock;

  @override
  ConsumerState<_TimeQuickAdd> createState() => _TimeQuickAddState();
}

class _TimeQuickAddState extends ConsumerState<_TimeQuickAdd> {
  late int _block = widget.initialBlock;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  int _added = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _step(int d) => setState(() => _block = (_block + d).clamp(0, 47));

  // 담기 = 이 시간 블록에 한 줄 누적 후 입력창 비우고 계속 담기.
  Future<void> _add() async {
    final line = _controller.text.trim();
    if (line.isEmpty) return;
    final repo = ref.read(timeTrackRepoProvider);
    final existing = await repo.getBlock(widget.date, _block);
    final base = (existing?.content ?? '').trim();
    await repo.setBlock(
        widget.date, _block, base.isEmpty ? line : '$base\n$line');
    if (!mounted) return;
    setState(() => _added++);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final start = blockLabel(_block);
    final end = blockLabel((_block + 1) % 48 == 0 ? 48 : _block + 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 시간 스텝퍼 — ‹ [ 12:00–12:30 ] ›
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _stepBtn(tk, '‹', () => _step(-1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: RichText(
                text: TextSpan(children: [
                  TextSpan(text: '[ ', style: AppText.serif(tk.mark, size: 17)),
                  TextSpan(
                      text: '$start–$end',
                      style: AppText.serif(tk.ink, size: 17)),
                  TextSpan(text: ' ]', style: AppText.serif(tk.mark, size: 17)),
                ]),
              ),
            ),
            _stepBtn(tk, '›', () => _step(1)),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _added > 0 ? '이 시간에 $_added개 담음' : '시간 미선택 시 현재 시간',
            style: AppText.meta(tk.inkSoft, size: 9),
          ),
        ),
        const SizedBox(height: 12),
        // 한 줄 입력 — 엔터/담기로 하나 담고 계속.
        TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          style: AppText.body(tk.ink),
          cursorColor: tk.mark,
          decoration: InputDecoration(
            isDense: true,
            hintText: '한 일을 적고 담기',
            hintStyle: AppText.meta(tk.inkSoft, size: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: tk.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: tk.ink, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _btn(tk, '닫기',
                    filled: false, onTap: () => Navigator.of(context).pop())),
            const SizedBox(width: 10),
            Expanded(child: _btn(tk, '담기', filled: true, onTap: _add)),
          ],
        ),
      ],
    );
  }

  Widget _stepBtn(AppTokens tk, String g, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              shape: BoxShape.circle, border: Border.all(color: tk.line)),
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 16)),
        ),
      );

  // 컴팩트 버튼 — 높이 38 · radius 2(레퍼런스 .btn).
  Widget _btn(AppTokens tk, String label,
          {required bool filled, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? tk.ink : Colors.transparent,
            border: filled ? null : Border.all(color: tk.ink, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(label,
              style: AppText.body(filled ? tk.paper : tk.ink)
                  .copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      );
}

/// 타임트래커 화면 (독립 진입용 — Scaffold 래퍼).
class TimeTrackScreen extends StatelessWidget {
  const TimeTrackScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        appBar: null,
        body: SafeArea(child: TimeTrackBody()),
      );
}

/// 타임로그(§ 시간 기록) — v17 레퍼런스: 시간대별로 '기록 없음' + 기록된 시간은
/// 강조 배경 + 제목 + 30분 + '—' 불릿 + 시간범위·작성 시각. 30분×48블록 유지.
class TimeTrackBody extends ConsumerStatefulWidget {
  const TimeTrackBody({super.key});

  @override
  ConsumerState<TimeTrackBody> createState() => _TimeTrackBodyState();
}

class _TimeTrackBodyState extends ConsumerState<TimeTrackBody> {
  DateTime _date = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool get _isToday =>
      _date.year == DateTime.now().year &&
      _date.month == DateTime.now().month &&
      _date.day == DateTime.now().day;

  Future<void> _export(List<TimeBlock> filled) async {
    if (filled.isEmpty) return;
    final buf = StringBuffer('${DateFormat('M.d (E)', 'ko').format(_date)} 시간 기록\n');
    for (final b in filled) {
      buf.writeln('\n${blockLabel(b.block)}');
      for (final l in b.content
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)) {
        buf.writeln('  $l');
      }
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
            content: Text('시간 기록을 복사했어요'),
            duration: Duration(milliseconds: 1200)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final blocks =
        ref.watch(timeBlocksForDateProvider(_date)).valueOrNull ?? const [];
    final byIndex = {
      for (final b in blocks)
        if (b.content.trim().isNotEmpty) b.block: b
    };
    final nowBlock = TimeTrackRepository.blockOfNow();
    final totalMin = byIndex.length * 30;
    final totH = totalMin ~/ 60;
    final totM = totalMin % 60;
    final totalStr = totH > 0 ? '$totH시간 ${totM > 0 ? '$totM분' : ''}'.trim() : '$totM분';

    // 보여줄 시간대: 06:00~23:30(30분 블록 12~47) + 기록이 있는 블록(범위 밖이라도).
    final blockSet = <int>{
      ...List.generate(36, (i) => i + 12),
      ...byIndex.keys,
    }.toList()
      ..sort();

    // 연속 빈 블록은 한 줄로 압축("HH:MM–HH:MM · 기록 없음 · N시간"). 단일 빈
    // 블록은 기존대로. 긴 공백을 길게 나열하지 않는다(스펙 4-2).
    final rows = <Widget>[];
    for (var i = 0; i < blockSet.length;) {
      final blk = blockSet[i];
      final b = byIndex[blk];
      if (b != null) {
        rows.add(_record(tk, b, _isToday && blk == nowBlock));
        i++;
        continue;
      }
      // blk 부터 연속(블록 번호 인접)인 빈 블록 묶기.
      var j = i;
      while (j < blockSet.length &&
          byIndex[blockSet[j]] == null &&
          blockSet[j] == blk + (j - i)) {
        j++;
      }
      final endBlk = blockSet[j - 1];
      if (endBlk == blk) {
        rows.add(_emptyBlock(tk, blk));
      } else {
        rows.add(_emptyRange(tk, blk, endBlk));
      }
      i = j;
    }

    return Container(
      color: tk.paper,
      child: Column(
        children: [
          // § 시간 기록 + 내보내기
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 레퍼런스 .section-title — § (모노·포인트색) + 세리프 제목.
                Text('' /*§제거*/, style: AppText.meta(tk.mark, size: 11)),
                Text('시간 기록', style: AppText.serif(tk.ink, size: 16)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _export(byIndex.values.toList()
                    ..sort((a, b) => a.block.compareTo(b.block))),
                  behavior: HitTestBehavior.opaque,
                  child: Text('내보내기', style: AppText.meta(tk.inkSoft, size: 11)),
                ),
              ],
            ),
          ),
          Container(
              margin: const EdgeInsets.symmetric(horizontal: kGutter),
              height: 1,
              color: tk.line),
          // 날짜 + 총 기록
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 10),
            child: Row(
              children: [
                _arrow(tk, '‹',
                    () => setState(() => _date = _date.subtract(const Duration(days: 1)))),
                const SizedBox(width: 6),
                Text(DateFormat('MM.dd (E)', 'ko').format(_date),
                    style: AppText.meta(tk.ink)),
                const Spacer(),
                Text('총 기록 $totalStr', style: AppText.meta(tk.inkSoft)),
                const SizedBox(width: 6),
                _arrow(tk, '›',
                    () => setState(() => _date = _date.add(const Duration(days: 1)))),
              ],
            ),
          ),
          Container(height: 1, color: tk.line),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 10, bottom: 28),
              children: rows,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(AppTokens tk, String g, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: tk.line),
          ),
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 15)),
        ),
      );

  /// 기록 없는 30분 블록 — 시간 라벨 + 세로 헤어라인 + '기록 없음'.
  Widget _emptyBlock(AppTokens tk, int block) {
    final label = blockLabel(block);
    return GestureDetector(
      onTap: () =>
          showTimeQuickAdd(context, ref, date: _date, block: block),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                    width: 46,
                    child: Text(label,
                        style: AppText.meta(tk.inkSoft, size: 11))),
              ),
              Container(width: 1, color: tk.line),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 0, 16),
                  child: Text('기록 없음',
                      style: AppText.meta(tk.inkSoft, size: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 연속 빈 시간 압축 행 — "HH:MM–HH:MM · 기록 없음 · N시간". 탭하면 시작 블록에 기록.
  Widget _emptyRange(AppTokens tk, int startBlk, int endBlk) {
    final count = endBlk - startBlk + 1;
    final mins = count * 30;
    final h = mins ~/ 60, m = mins % 60;
    final dur = h > 0 ? '$h시간${m > 0 ? ' $m분' : ''}' : '$m분';
    final startL = blockLabel(startBlk);
    final endL = blockLabel(endBlk + 1 >= 48 ? 48 : endBlk + 1);
    return GestureDetector(
      onTap: () =>
          showTimeQuickAdd(context, ref, date: _date, block: startBlk),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                    width: 46,
                    child: Text(startL,
                        style: AppText.meta(tk.inkSoft, size: 11))),
              ),
              Container(width: 1, color: tk.line),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 0, 16),
                  child: Text('$startL–$endL · 기록 없음 · $dur',
                      style: AppText.meta(tk.inkSoft, size: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 기록된 시간 — 강조 배경 + 좌측 포인트선 + 제목/30분 + '—' 불릿 + 범위·작성.
  Widget _record(AppTokens tk, TimeBlock b, bool isNow) {
    final lines = b.content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    // 항목마다 작은 불릿(•) — 첫 줄 '제목' 구분 없이 하나하나 동등하게.
    final items = lines.isEmpty ? const <String>['기록'] : lines;
    final start = blockLabel(b.block);
    final end = blockLabel((b.block + 1) % 48 == 0 ? 48 : b.block + 1);
    final written =
        b.updatedAt != null ? ' · 작성 ${DateFormat('HH:mm').format(b.updatedAt!)}' : '';

    // 레퍼런스 .day-log-row.recorded — 은은한 채움 + 세로 레일(포인트색).
    // 빈 시간줄(_emptyHour)과 동일한 [시간 | 레일 | 본문] 구조로 통일한다.
    return GestureDetector(
      onTap: () =>
          showTimeQuickAdd(context, ref, date: _date, block: b.block),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tk.paper2,
          border: Border(bottom: BorderSide(color: tk.line)),
        ),
        padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: SizedBox(
                    width: 46,
                    child: Text(start,
                        style: AppText.meta(isNow ? tk.ink : tk.inkSoft))),
              ),
              // 기록된 시간의 레일 = 포인트색.
              Container(width: 1, color: tk.mark),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 항목마다 작은 불릿(•). 첫 줄에만 소요(30분) 우측 정렬.
                      for (var i = 0; i < items.length; i++)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2, right: 6),
                                child: Text('•',
                                    style: AppText.meta(tk.inkSoft, size: 8)),
                              ),
                              Expanded(
                                child: Text(items[i],
                                    style: AppText.body(tk.ink)
                                        .copyWith(fontSize: 12)),
                              ),
                              if (i == 0) ...[
                                const SizedBox(width: 8),
                                Text('30분',
                                    style: AppText.meta(tk.inkSoft, size: 10)),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text('$start–$end$written',
                          style: AppText.metaSans(tk.inkSoft, size: 8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
