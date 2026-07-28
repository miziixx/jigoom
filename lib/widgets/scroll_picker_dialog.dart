import 'package:flutter/material.dart';
import '../app_theme.dart';

const kPickerItemH = 36.0;

class ScrollPickerDialog extends StatefulWidget {
  final List<int> values;
  final List<String> labels;
  final int initialValue;

  const ScrollPickerDialog({
    super.key,
    required this.values,
    required this.labels,
    required this.initialValue,
  });

  @override
  State<ScrollPickerDialog> createState() => _ScrollPickerDialogState();
}

class _ScrollPickerDialogState extends State<ScrollPickerDialog> {
  late ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final idx = widget.values.indexOf(widget.initialValue);
    _scroll = ScrollController(
      initialScrollOffset: (idx >= 0 ? idx : 0) * kPickerItemH,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double _contentWidth() {
    if (widget.labels.isEmpty) return 48;
    final style = mono(fontSize: 13, fontWeight: FontWeight.normal);
    final tp = TextPainter(
      text: TextSpan(text: widget.labels.first, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width + 20;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: kBorder.withValues(alpha: 0.5)),
        ),
        child: SizedBox(
          width: _contentWidth(),
          height: kPickerItemH * 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: ListView.builder(
              controller: _scroll,
              itemExtent: kPickerItemH,
              padding: EdgeInsets.symmetric(vertical: kPickerItemH),
              itemCount: widget.values.length,
              itemBuilder: (_, i) {
                final v = widget.values[i];
                final isSel = v == widget.initialValue;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, v),
                  child: Container(
                    color: isSel
                        ? kMint.withValues(alpha: 0.12)
                        : Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      widget.labels[i],
                      style: mono(
                        color: isSel ? kMint : kDim,
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.normal : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<int?> showScrollPicker({
  required BuildContext context,
  required List<int> values,
  required List<String> labels,
  required int initialValue,
}) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withValues(alpha: 0.2),
    pageBuilder: (_, __, ___) => ScrollPickerDialog(
      values: values,
      labels: labels,
      initialValue: initialValue,
    ),
  );
}
