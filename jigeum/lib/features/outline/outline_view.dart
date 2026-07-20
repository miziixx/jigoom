import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../today/node_detail_sheet.dart';

/// 아웃라이너 — 저널형 타임라인 디자인.
/// 왼쪽 세로 레일 + 알약 배지(폴더/목표, 기간 모드에선 날짜),
/// 둥근 사각 체크박스, 마감 pill, 하위할일 진행(1/4), 헤어라인 구분.
class OutlineView extends ConsumerStatefulWidget {
  const OutlineView({super.key});

  @override
  ConsumerState<OutlineView> createState() => _OutlineViewState();
}

const double _kRailX = 27; // 타임라인 세로선 x 위치
const double _kRowLeft = 52; // 할 일 행 들여쓰기 시작

class _OutlineViewState extends ConsumerState<OutlineView> {
  final Set<String> _collapsed = {}; // 기본 펼침, 접은 것만 기록

  /// null = 전체(트리 모드). 값이 있으면 기간 필터 모드.
  ({DateTime start, DateTime end, String label})? _range;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg =
        isDark ? const Color(0xFF0D1013) : const Color(0xFFF3F2EF);
    final cardBg = Theme.of(context).scaffoldBackgroundColor;
    final hairline =
        Theme.of(context).dividerTheme.color ?? Colors.black12;

    return Container(
      color: pageBg,
      child: Column(
        children: [
          _filterBar(context),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: hairline, width: 0.5),
              ),
              child: _range == null ? _tree() : _filtered(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 필터바
  Widget _filterBar(BuildContext context) {
    final today = todayDate();
    Widget chip(String label, ({DateTime start, DateTime end})? r) {
      final selected =
          (_range == null && r == null) || (_range?.label == label);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          selected: selected,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          onSelected: (_) => setState(() {
            _range = r == null
                ? null
                : (start: r.start, end: r.end, label: label);
          }),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          chip('전체', null),
          chip('오늘', (start: today, end: today.add(const Duration(days: 1)))),
          chip('7일', (start: today, end: today.add(const Duration(days: 7)))),
          chip(
              '이번달',
              (
                start: DateTime(today.year, today.month, 1),
                end: DateTime(today.year, today.month + 1, 1)
              )),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              avatar: const Icon(Icons.date_range, size: 14),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              label: Text(
                  _range?.label.contains('~') == true
                      ? _range!.label
                      : '기간 선택',
                  style: const TextStyle(fontSize: 12)),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              onPressed: _pickRange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: todayDate().add(const Duration(days: 730)),
      helpText: '볼 기간을 선택하세요 (하루도, 한 달도 가능)',
      cancelText: '취소',
      confirmText: '보기',
    );
    if (picked == null) return;
    final fmt = DateFormat('M/d');
    setState(() => _range = (
          start: picked.start,
          end: picked.end.add(const Duration(days: 1)),
          label: '${fmt.format(picked.start)}~${fmt.format(picked.end)}',
        ));
  }

  // ---------------------------------------------------- 타임라인 공통 골격
  /// 세로 레일 위에 rows 를 얹는다.
  Widget _timeline(List<Widget> rows) {
    final hairline =
        Theme.of(context).dividerTheme.color ?? Colors.black12;
    return Stack(
      children: [
        Positioned(
          left: _kRailX,
          top: 0,
          bottom: 0,
          child: Container(width: 1, color: hairline),
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(0, 14, 12, 20),
          children: rows,
        ),
      ],
    );
  }

  /// 레일 위 알약 배지 (레퍼런스의 점선 시간 배지 역할).
  Widget _pill(String label, {VoidCallback? onTap, VoidCallback? onLong}) {
    final theme = Theme.of(context);
    final hairline = theme.dividerTheme.color ?? Colors.black12;
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 10, bottom: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            onLongPress: onLong,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: hairline, width: 0.8),
              ),
              child: Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontSize: 11, letterSpacing: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- 기간 필터 모드
  Widget _filtered() {
    final r = _range!;
    final nodes = ref
            .watch(dateRangeNodesProvider((start: r.start, end: r.end)))
            .valueOrNull ??
        const [];
    if (nodes.isEmpty) {
      return Center(
          child: Text('이 기간엔 비어 있어요',
              style: Theme.of(context).textTheme.bodySmall));
    }

    final byDate = <DateTime, List<Node>>{};
    for (final n in nodes) {
      byDate.putIfAbsent(dateOnly(n.date!), () => []).add(n);
    }
    final dates = byDate.keys.toList()..sort();

    final rows = <Widget>[];
    for (final d in dates) {
      rows.add(_pill(DateFormat('M월 d일 (E)', 'ko').format(d)));
      final list = byDate[d]!;
      for (var i = 0; i < list.length; i++) {
        rows.add(_TaskRow(node: list[i], showDeadline: false));
        if (i != list.length - 1) rows.add(_rowDivider());
      }
    }
    return _timeline(rows);
  }

  // ------------------------------------------------------------ 트리 모드
  Widget _tree() {
    final roots = ref.watch(rootsProvider).valueOrNull ?? const [];
    if (roots.isEmpty) {
      return Center(
          child: Text('아직 아무것도 없어요',
              style: Theme.of(context).textTheme.bodySmall));
    }

    // 섹션 = 폴더/목표. 소속 없는 할 일은 "할 일" 섹션.
    final sections = <Node>[];
    final loose = <Node>[];
    for (final n in roots) {
      if (n.type == NodeType.folder || n.type == NodeType.goal) {
        sections.add(n);
      } else {
        loose.add(n);
      }
    }

    final rows = <Widget>[];

    void addTasks(List<Node> list, int depth) {
      for (var i = 0; i < list.length; i++) {
        final n = list[i];
        rows.add(_swipeable(n, _TaskRow(node: n, depth: depth)));
        // 하위 항목 (펼침 상태일 때)
        final children =
            ref.watch(childrenProvider(n.id)).valueOrNull ?? const [];
        if (children.isNotEmpty && !_collapsed.contains(n.id)) {
          addTasks(children, depth + 1);
        }
        if (i != list.length - 1 && depth == 0) rows.add(_rowDivider());
      }
    }

    if (loose.isNotEmpty) {
      rows.add(_pill('할 일'));
      addTasks(loose, 0);
    }

    for (final s in sections) {
      final children =
          ref.watch(childrenProvider(s.id)).valueOrNull ?? const [];
      final open = !_collapsed.contains(s.id);
      rows.add(_pill(
        s.type == NodeType.goal ? '🎯 ${s.title}' : s.title,
        onTap: () => setState(() {
          open ? _collapsed.add(s.id) : _collapsed.remove(s.id);
        }),
        onLong: () => showNodeDetailSheet(context, s),
      ));
      if (open) {
        if (children.isEmpty) {
          rows.add(Padding(
            padding: const EdgeInsets.only(left: _kRowLeft, bottom: 6),
            child: Text('비어 있어요',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 12)),
          ));
        } else {
          addTasks(children, 0);
        }
      }
    }

    return _timeline(rows);
  }

  Widget _rowDivider() {
    final hairline =
        Theme.of(context).dividerTheme.color ?? Colors.black12;
    return Container(
      margin: const EdgeInsets.only(left: _kRowLeft, right: 4),
      height: 0.5,
      color: hairline,
    );
  }

  Widget _swipeable(Node node, Widget child) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey('dismiss_${node.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.check_circle, color: AppColors.done),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.east, color: theme.textTheme.bodySmall?.color),
      ),
      confirmDismiss: (dir) async {
        final repo = ref.read(nodeRepoProvider);
        if (dir == DismissDirection.startToEnd) {
          await repo.complete(node.id); // 우 = 완료
        } else {
          await repo.pushToTomorrow(node.id); // 좌 = 내일로
        }
        return false;
      },
      child: child,
    );
  }
}

/// 저널형 할 일 행: 둥근 사각 체크박스 + 제목 + 마감 pill + 하위 진행(1/4).
class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.node, this.depth = 0, this.showDeadline = true});

  final Node node;
  final int depth;
  final bool showDeadline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(nodeRepoProvider);
    final done = node.status == NodeStatus.done;
    final children =
        ref.watch(childrenProvider(node.id)).valueOrNull ?? const [];
    final doneCount =
        children.where((c) => c.status == NodeStatus.done).length;

    return Opacity(
      opacity: done ? 0.45 : 1,
      child: InkWell(
        onTap: () => showNodeDetailSheet(context, node),
        child: Padding(
          padding: EdgeInsets.only(
              left: _kRowLeft + depth * 18, right: 4, top: 8, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 둥근 사각 체크박스
              GestureDetector(
                onTap: () =>
                    done ? repo.reopen(node.id) : repo.complete(node.id),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 11, top: 1),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: done ? AppColors.done : Colors.transparent,
                      border: done
                          ? null
                          : Border.all(
                              color: theme.textTheme.bodySmall?.color ??
                                  Colors.grey,
                              width: 1.3),
                    ),
                    child: done
                        ? const Icon(Icons.check,
                            size: 13, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (node.urgent && !done) ...[
                          Icon(Icons.bolt,
                              size: 13,
                              color: theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(node.title,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if ((showDeadline && node.date != null && !done) ||
                        children.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (showDeadline && node.date != null && !done)
                              _deadlinePill(theme),
                            if (children.isNotEmpty) ...[
                              if (showDeadline &&
                                  node.date != null &&
                                  !done)
                                const SizedBox(width: 6),
                              Icon(Icons.radio_button_unchecked,
                                  size: 10,
                                  color: theme.textTheme.bodySmall?.color),
                              const SizedBox(width: 3),
                              Text('$doneCount/${children.length}',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 마감 pill: 임박(오늘/내일)=잉크 채움, 그 외=테두리.
  Widget _deadlinePill(ThemeData theme) {
    final d = dateOnly(node.date!);
    final today = todayDate();
    final diff = d.difference(today).inDays;

    final String label;
    if (diff <= 0) {
      label = '오늘';
    } else if (diff == 1) {
      label = '내일';
    } else {
      label = DateFormat('M/d').format(d);
    }

    final urgentish = diff <= 1;
    final ink = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final bg = theme.scaffoldBackgroundColor;
    final hairline = theme.dividerTheme.color ?? Colors.black12;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: urgentish ? ink : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: urgentish ? null : Border.all(color: hairline, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: urgentish ? bg : theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
