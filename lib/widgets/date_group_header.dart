import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../flavor.dart';

class HourSlot {
  final int hour;
  final int count;
  final String firstMemoId;
  const HourSlot({required this.hour, required this.count, required this.firstMemoId});
}

class DateGroupHeader extends StatefulWidget {
  final String dateKey;
  final ValueChanged<bool>? onCollapsedChanged;
  final bool initiallyCollapsed;
  final List<HourSlot> hourSlots;
  final ValueChanged<String>? onHourTap;

  const DateGroupHeader({
    super.key,
    required this.dateKey,
    this.onCollapsedChanged,
    this.initiallyCollapsed = false,
    this.hourSlots = const [],
    this.onHourTap,
  });

  @override
  State<DateGroupHeader> createState() => _DateGroupHeaderState();
}

class _DateGroupHeaderState extends State<DateGroupHeader> {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.initiallyCollapsed;
  }

  String _formatDate(String key) {
    try {
      final parts = key.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return '$key  ${weekdays[date.weekday - 1]}';
    } catch (_) {
      return key;
    }
  }

  // v3 date-marker label: "오늘 · 2026-06-08 · 월" / "어제 · ..." / "2026-06-06 · 토"
  String _v3DateLabel(String key) {
    try {
      final parts = key.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(DateTime(date.year, date.month, date.day)).inDays;
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final wd = weekdays[date.weekday - 1];
      if (diff == 0) return '오늘 · $key · $wd';
      if (diff == 1) return '어제 · $key · $wd';
      if (diff == -1) return '내일 · $key · $wd';
      return '$key · $wd';
    } catch (_) {
      return key;
    }
  }

  bool _isToday(String key) {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return key == today;
  }

  void _toggle() {
    setState(() => _collapsed = !_collapsed);
    widget.onCollapsedChanged?.call(_collapsed);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeNotifier,
      builder: (context, value, child) {
        if (isMinimalTheme) return _buildMinimal();
        if (isLogroomUi) return _buildLogroom();
        return _buildClassic();
      },
    );
  }

  Widget _buildMinimal() {
    final isToday = _isToday(widget.dateKey);
    final label = widget.dateKey.contains('-') && widget.dateKey.length == 10
        ? _formatDate(widget.dateKey).toUpperCase()
        : widget.dateKey.toUpperCase();

    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          color: kBg,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: mono(
                    color: isToday ? kMint : kDim,
                    fontSize: tsSmall,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _collapsed ? '▶' : '▼',
                style: mono(color: kDim.withValues(alpha: 0.75), fontSize: tsTiny),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogroom() {
    final isToday = _isToday(widget.dateKey);
    final label = widget.dateKey.contains('-') && widget.dateKey.length == 10
        ? _v3DateLabel(widget.dateKey)
        : widget.dateKey;
    // Active color: today = kMint tinted, others = kText2 (v3 --fg2 equivalent)
    final labelColor = isToday
        ? kMint.withValues(alpha: 0.85)
        : kText2.withValues(alpha: 0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              color: kBg,
              // left padding aligns with timeline lane (26px lane + 8px entry padding = 34px)
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  // v3 date-marker label — italic, muted
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontStyle: FontStyle.italic,
                      fontSize: tsSmall * (kFontSize / 13.0),
                      color: labelColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // horizontal rule
                  Expanded(
                    child: Container(
                      height: 1,
                      color: kTlLine,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // collapse toggle — small and quiet
                  Text(
                    _collapsed ? '›' : '·',
                    style: mono(
                      color: kText3.withValues(alpha: 0.6),
                      fontSize: tsMeta,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_collapsed && widget.hourSlots.isNotEmpty) _buildHourToc(),
      ],
    );
  }

  Widget _buildHourToc() {
    return Container(
      color: kBg,
      // aligns with entry content (26px lane + 8px = 34px, use 34)
      padding: const EdgeInsets.fromLTRB(34, 2, 14, 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        children: widget.hourSlots.map((slot) {
          final h = slot.hour.toString().padLeft(2, '0');
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.onHourTap?.call(slot.firstMemoId);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
                child: Text(
                  '$h:00 · ${slot.count}',
                  style: mono(color: kText3.withValues(alpha: 0.75), fontSize: tsMeta),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClassic() {
    final isToday = _isToday(widget.dateKey);
    final label = isToday
        ? 'TODAY  ${_formatDate(widget.dateKey)}'
        : _formatDate(widget.dateKey);
    final icon = _collapsed ? '▸ ' : '▾ ';

    return GestureDetector(
      onTap: _toggle,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          color: kText,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(
            children: [
              Text(
                icon,
                style: mono(
                  color: kBg,
                  fontSize: tsAlt,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  style: mono(
                    color: kBg,
                    fontSize: tsAlt,
                    fontWeight: FontWeight.w600,
                    letterSpacing: isToday ? 0.8 : 0.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
