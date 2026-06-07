import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/today_tab.dart';

class TodayTabConfigSheet extends StatefulWidget {
  final TodayTab tab;
  final void Function(TodayTab updated) onConfirm;

  const TodayTabConfigSheet({
    super.key,
    required this.tab,
    required this.onConfirm,
  });

  @override
  State<TodayTabConfigSheet> createState() => _TodayTabConfigSheetState();
}

class _TodayTabConfigSheetState extends State<TodayTabConfigSheet> {
  late TextEditingController _nameCtrl;
  late List<TodaySection> _order; // 전체 6개, 드래그로 변경 가능
  late Map<TodaySection, bool> _checks;

  // 행 높이 고정값 (6개 * 38px)
  static const double _rowH = 38.0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.tab.name);
    _order = List.from(widget.tab.sectionOrder);
    _checks = {
      for (final s in TodaySection.values) s: widget.tab.sections.contains(s),
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final name = _nameCtrl.text.trim();
    // 체크된 섹션들을 현재 _order 순서대로 추출
    final sections = _order.where((s) => _checks[s] == true).toList();
    widget.onConfirm(
      widget.tab.copyWith(
        name: name.isEmpty ? widget.tab.name : name,
        sections: sections,
        sectionOrder: List.from(_order),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.75),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder)),
              ),
              child: Text(
                '// 탭 구성 편집',
                style: mono(color: kDim, fontSize: 10, letterSpacing: 0.8),
              ),
            ),
            // tab name input
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder)),
              ),
              child: Row(
                children: [
                  Text(
                    '탭 이름  ',
                    style: mono(color: kDim, fontSize: 10, letterSpacing: 0.5),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      style: mono(color: kText, fontSize: 12),
                      cursorColor: kMint,
                      maxLength: 8,
                      decoration: InputDecoration(
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        filled: true,
                        fillColor: kBg,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: kBorder),
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: kBorder),
                          borderRadius: BorderRadius.zero,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: kMint),
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // section title
            Container(
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '섹션 선택 · 드래그로 순서 변경',
                      style: mono(
                        color: kText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '⠿ 드래그',
                    style: mono(
                      color: kDim.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            // section list — ReorderableListView (fixed height for 6 items)
            SizedBox(
              height: TodaySection.values.length * _rowH,
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _order.length,
                itemBuilder: (ctx, i) {
                  final s = _order[i];
                  final on = _checks[s] == true;
                  return _SectionReorderRow(
                    key: ValueKey(s),
                    index: i,
                    label: s.label,
                    checked: on,
                    onTap: () => setState(() => _checks[s] = !on),
                  );
                },
                onReorderItem: (oldIdx, newIdx) {
                  setState(() {
                    final item = _order.removeAt(oldIdx);
                    _order.insert(newIdx, item);
                  });
                },
              ),
            ),
            // actions
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SheetBtn(
                    label: '취소',
                    color: kDim,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  _SheetBtn(label: '확인', color: kMint, onTap: _apply),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 드래그 가능한 섹션 행 ──────────────────────────────────────────────────────

class _SectionReorderRow extends StatelessWidget {
  final int index;
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _SectionReorderRow({
    required super.key,
    required this.index,
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: kBorder.withValues(alpha: 0.4)),
          ),
          color: checked ? kMint.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            // checkbox
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                border: Border.all(color: checked ? kMint : kBorder),
                color: checked ? kMint : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: checked
                  ? Text('✓', style: mono(color: kBg, fontSize: 9))
                  : null,
            ),
            const SizedBox(width: 10),
            // label
            Expanded(
              child: Text(
                label,
                style: mono(color: checked ? kText : kDim, fontSize: 12),
              ),
            ),
            // drag handle — ⠿ 텍스트로 터미널 감성 유지
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
                child: Text(
                  '⠿',
                  style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 확인/취소 버튼 ─────────────────────────────────────────────────────────────

class _SheetBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: mono(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
