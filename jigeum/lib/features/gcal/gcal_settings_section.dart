import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import 'gcal_controller.dart';

/// 설정 화면의 "구글 캘린더" 섹션 — 연결/해제 · 종류별 동기화 선택 · 지금 동기화.
class GcalSettingsSection extends ConsumerStatefulWidget {
  const GcalSettingsSection({super.key});

  @override
  ConsumerState<GcalSettingsSection> createState() =>
      _GcalSettingsSectionState();
}

class _GcalSettingsSectionState extends ConsumerState<GcalSettingsSection> {
  // 편집 모드: 켜면 각 캘린더를 목록에서 숨기거나 다시 보이게 할 수 있다.
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final state = ref.watch(gcalControllerProvider);
    final ctrl = ref.read(gcalControllerProvider.notifier);

    if (!state.connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
            child: Text('폰에 있는 구글 캘린더와 일정을 양방향으로 동기화해요. '
                '로그인 없이 캘린더 접근 허용만 하면 됩니다.',
                style: AppText.body(tk.ink)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
            child: _Btn(
              label: '캘린더 연동 켜기',
              filled: true,
              onTap: () => ctrl.connect(),
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
              child: Text(state.error!, style: AppText.meta(tk.mark, size: 12)),
            ),
        ],
      );
    }

    // 연결됨.
    final calsAsync = ref.watch(gcalCalendarsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 계정 + 동기화 상태
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('폰 캘린더 연동됨', style: AppText.body(tk.ink)),
                    const SizedBox(height: 2),
                    Text(
                      state.syncing
                          ? '동기화 중…'
                          : state.lastSyncAt == null
                              ? '아직 동기화 안 함'
                              : '마지막 동기화 ${_ago(state.lastSyncAt!)}',
                      style: AppText.meta(tk.inkSoft, size: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => ctrl.disconnect(),
                behavior: HitTestBehavior.opaque,
                child: Text('연동 끄기', style: AppText.meta(tk.mark, size: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: _Btn(
            label: state.syncing ? '동기화 중…' : '지금 동기화',
            filled: false,
            onTap: state.syncing ? null : () => ctrl.syncNow(),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('동기화할 캘린더 (종류별)',
                    style: AppText.meta(tk.inkSoft, size: 11)
                        .copyWith(letterSpacing: 1.2)),
              ),
              if (calsAsync.asData?.value.isNotEmpty ?? false)
                GestureDetector(
                  onTap: () => setState(() => _editing = !_editing),
                  behavior: HitTestBehavior.opaque,
                  child: Text(_editing ? '완료' : '편집',
                      style: AppText.meta(tk.mark, size: 12)),
                ),
            ],
          ),
        ),
        calsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
            child: Text('불러오는 중…', style: AppText.meta(tk.inkSoft)),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
            child: Text('목록을 불러오지 못했어요', style: AppText.meta(tk.mark)),
          ),
          data: (cals) {
            if (cals.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
                child: Text('캘린더가 없어요. "지금 동기화"로 목록을 불러오세요.',
                    style: AppText.meta(tk.inkSoft)),
              );
            }
            // 편집 모드면 숨긴 것까지 다 보여주고, 아니면 보이는 것만.
            final visible =
                _editing ? cals : [for (final c in cals) if (!c.hidden) c];
            final hiddenCount = cals.where((c) => c.hidden).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 2),
                    child: Text('안 쓰는 캘린더는 "숨기기"로 목록에서 감춰요. '
                        '숨기면 동기화도 꺼집니다.',
                        style: AppText.meta(tk.inkSoft, size: 11)),
                  ),
                for (final c in visible)
                  _CalRow(cal: c, ctrl: ctrl, editing: _editing),
                if (!_editing && hiddenCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _editing = true),
                      behavior: HitTestBehavior.opaque,
                      child: Text('숨긴 캘린더 $hiddenCount개 · 편집에서 다시 보이기',
                          style: AppText.meta(tk.inkSoft, size: 11)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '방금';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    return '${d.inDays}일 전';
  }
}

class _CalRow extends StatelessWidget {
  const _CalRow(
      {required this.cal, required this.ctrl, required this.editing});
  final GcalCalendar cal;
  final GcalController ctrl;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    Color dot;
    try {
      final hex = cal.colorHex.replaceFirst('#', '');
      dot = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      dot = tk.inkSoft;
    }
    // 편집 모드에서 숨긴 항목은 흐리게.
    final dim = editing && cal.hidden;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
      child: Row(
        children: [
          Opacity(
            opacity: dim ? 0.35 : 1,
            child: Container(width: 10, height: 10, color: dot),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(cal.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(dim ? tk.inkSoft : tk.ink)),
          ),
          if (!editing && cal.accessRole == 'reader')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('읽기', style: AppText.meta(tk.inkSoft, size: 9)),
            ),
          if (editing)
            GestureDetector(
              onTap: () => ctrl.setCalendarHidden(cal.id, !cal.hidden),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(cal.hidden ? '보이기' : '숨기기',
                    style: AppText.meta(cal.hidden ? tk.inkSoft : tk.mark,
                        size: 12)),
              ),
            )
          else
            Switch(
              value: cal.selected,
              onChanged: (v) => ctrl.setCalendarSelected(cal.id, v),
            ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.filled, this.onTap});
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? tk.ink : Colors.transparent,
          border: Border.all(color: tk.ink, width: 1),
        ),
        child: Text(
          label,
          style: AppText.nav(filled ? tk.paper : tk.ink, active: true),
        ),
      ),
    );
  }
}
