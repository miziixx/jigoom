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
        ? _formatDate(widget.dateKey).toUpperCase()
        : widget.dateKey.toUpperCase();

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
              padding: const EdgeInsets.fromLTRB(15, 8, 15, 4),
              child: Row(
                children: [
                  Text(
                    label,
                    style: mono(
                      color: isToday ? kMint : kDim,
                      fontSize: tsAlt,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: kBorder.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _collapsed ? '▶' : '▼',
                    style: mono(color: kDim, fontSize: tsTiny),
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
      padding: const EdgeInsets.fromLTRB(15, 2, 15, 8),
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
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Text(
                  '$h시·${slot.count}',
                  style: mono(color: kDim.withValues(alpha: 0.75), fontSize: tsMeta),
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
