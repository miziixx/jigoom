import 'package:flutter/material.dart';
import '../app_theme.dart';

class DateGroupHeader extends StatefulWidget {
  final String dateKey; // 'YYYY-MM-DD'
  final ValueChanged<bool>? onCollapsedChanged;
  final bool initiallyCollapsed;

  const DateGroupHeader({
    super.key,
    required this.dateKey,
    this.onCollapsedChanged,
    this.initiallyCollapsed = false,
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
      builder: (_, __, ___) {
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
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: mono(
                        color: kBg,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: isToday ? 0.8 : 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
