import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 빠른 담기 시트 — 레퍼런스 "[ 빠르게 담기 ]" 바텀시트.
/// 핸들 + 세리프 브래킷 제목 + 부제 + 유형 탭(할 일/일정/메모/습관) + 내용 입력
/// + 표시(오늘/중요/긴급/날짜) + 취소/담기.
///
/// - 기본: 홈 가운데 ＋ 에서 진입 → 유형 탭 노출.
/// - [quadrantLabel] 이 있으면(매트릭스 칸) 할 일 고정·중요/긴급 잠금, 유형 탭 숨김.
/// - [toDrawer] 면 날짜 없이 담아 서랍으로.
Future<void> showQuickCaptureInput(
  BuildContext context,
  WidgetRef ref, {
  bool presetImportant = false,
  bool presetUrgent = false,
  String? quadrantLabel,
  bool toDrawer = false,
  String presetType = 'task',
}) async {
  final controller = TextEditingController();
  final locked = quadrantLabel != null;
  var type = presetType; // task | schedule | memo | habit
  var important = presetImportant;
  var urgent = presetUrgent;
  DateTime? date = toDrawer ? null : todayDate();

  Future<void> submit(BuildContext ctx) async {
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      switch (type) {
        case 'schedule':
          await ref.read(scheduleRepoProvider).addSchedule(
                date: date ?? todayDate(),
                title: text,
                startMin: 0,
                endMin: 0,
                allDay: true,
              );
          break;
        case 'memo':
          await ref.read(nodeRepoProvider).create(
                type: NodeType.memo,
                title: text,
                date: date,
              );
          break;
        case 'habit':
          await ref.read(habitRepoProvider).addHabit(text);
          break;
        default:
          await ref.read(nodeRepoProvider).create(
                type: NodeType.task,
                title: text,
                important: important,
                urgent: urgent,
                date: date,
              );
      }
    }
    if (ctx.mounted) Navigator.of(ctx).pop();
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t(context).paper,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final tk = t(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) {
          // 유형 탭 (레퍼런스 .type-grid).
          Widget typeTab(String key, String label) {
            final sel = type == key;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => type = key),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: sel ? tk.mark : Colors.transparent,
                    border: Border.all(color: sel ? tk.mark : tk.line),
                  ),
                  child: Text(label,
                      style: AppText.body(sel ? tk.paper : tk.inkSoft)
                          .copyWith(fontSize: 12)),
                ),
              ),
            );
          }

          // 표시 필터 (레퍼런스 .filter-row) — 밑줄 텍스트 탭.
          Widget flag(String label, bool sel, VoidCallback onTap) {
            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(right: 18),
                padding: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: sel ? tk.ink : Colors.transparent, width: 1.5),
                  ),
                ),
                child: Text(label,
                    style: AppText.body(sel ? tk.ink : tk.inkSoft)
                        .copyWith(fontSize: 12)),
              ),
            );
          }

          Future<void> pickDate() async {
            final now = todayDate();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: date ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 2),
            );
            if (picked != null) setState(() => date = dateOnly(picked));
          }

          final isToday = date != null && date == todayDate();

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                            color: tk.line,
                            borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 브래킷 세리프 제목
                    Text('[ 빠르게 담기 ]',
                        style: AppText.hTitle(tk.ink).copyWith(fontSize: 20)),
                    const SizedBox(height: 6),
                    Text(
                        locked
                            ? '$quadrantLabel 칸에 바로 담아요'
                            : '먼저 적고 필요한 표시만 고르세요.',
                        style: AppText.meta(tk.inkSoft, size: 11)),
                    const SizedBox(height: 16),
                    // 유형 탭 (매트릭스 잠금 시 숨김)
                    if (!locked)
                      Row(
                        children: [
                          typeTab('task', '할 일'),
                          typeTab('schedule', '일정'),
                          typeTab('memo', '메모'),
                          typeTab('habit', '습관'),
                        ],
                      ),
                    if (!locked) const SizedBox(height: 18),
                    Text('내용', style: AppText.meta(tk.inkSoft, size: 10)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(ctx),
                      cursorColor: tk.mark,
                      style: AppText.body(tk.ink).copyWith(fontSize: 15),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '무엇을 담을까요?',
                        hintStyle:
                            AppText.body(tk.inkSoft).copyWith(fontSize: 15),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: tk.line)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: tk.ink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 표시 필터 — 할 일에서만 중요/긴급, 그 외엔 오늘/날짜만.
                    Container(
                      padding: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: tk.line))),
                      child: Row(
                        children: [
                          flag('오늘', isToday,
                              () => setState(() => date = todayDate())),
                          if (type == 'task') ...[
                            flag('중요', important,
                                () => setState(() => important = !important)),
                            flag('긴급', urgent,
                                () => setState(() => urgent = !urgent)),
                          ],
                          flag(
                              date != null && !isToday
                                  ? '${date!.month}/${date!.day}'
                                  : '날짜',
                              date != null && !isToday,
                              pickDate),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 취소 / 담기 — 폭 채움
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration:
                                  BoxDecoration(border: Border.all(color: tk.line)),
                              child: Text('취소',
                                  style: AppText.body(tk.inkSoft)
                                      .copyWith(fontSize: 12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => submit(ctx),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              color: tk.mark,
                              child: Text('담기',
                                  style: AppText.body(tk.paper)
                                      .copyWith(fontSize: 12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
