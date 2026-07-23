import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import 'gcal_controller.dart';

/// 설정 화면의 "구글 캘린더" 섹션 — 연결/해제 · 종류별 동기화 선택 · 지금 동기화.
class GcalSettingsSection extends ConsumerWidget {
  const GcalSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: Text('동기화할 캘린더 (종류별)',
              style: AppText.meta(tk.inkSoft, size: 11)
                  .copyWith(letterSpacing: 1.2)),
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
            return Column(
              children: [
                for (final c in cals) _CalRow(cal: c, ctrl: ctrl),
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
  const _CalRow({required this.cal, required this.ctrl});
  final GcalCalendar cal;
  final GcalController ctrl;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
      child: Row(
        children: [
          Container(width: 10, height: 10, color: dot),
          const SizedBox(width: 10),
          Expanded(
            child: Text(cal.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(tk.ink)),
          ),
          if (cal.accessRole == 'reader')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('읽기', style: AppText.meta(tk.inkSoft, size: 9)),
            ),
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
