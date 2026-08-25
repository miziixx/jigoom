import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../capture/quick_capture_input.dart';
import '../today/node_detail_sheet.dart';

/// 전체 할 일 — 기준 HTML `data-screen="tasks"`.
/// 탭(전체/오늘/중요/대기/완료) + task-line(원형 체크 · 제목 · 메타 · 우측 시간).
/// (지금 v1 의 날짜필터·글리프 목록 레이아웃 제거.)
class AllView extends ConsumerStatefulWidget {
  const AllView({super.key});

  @override
  ConsumerState<AllView> createState() => _AllViewState();
}

class _AllViewState extends ConsumerState<AllView> {
  int _tab = 0; // 0 전체 · 1 오늘 · 2 중요 · 3 대기 · 4 완료

  bool _match(Node n) {
    final today = todayDate();
    switch (_tab) {
      case 1:
        return n.date != null && dateOnly(n.date!) == today;
      case 2:
        return n.important;
      case 3:
        return n.status == NodeStatus.drawer;
      case 4:
        return n.status == NodeStatus.done;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final all = ref.watch(allNodesProvider).valueOrNull ?? const <Node>[];
    final tasks = all.where((n) => n.type == NodeType.task).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final list = tasks.where(_match).toList();

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _tabs(tk),
          if (list.isEmpty)
            emptyStateBear(
                context, _tab == 4 ? '완료한 일이 없어요' : '해당하는 일이 없어요')
          else
            for (final n in list) _taskLine(tk, n),
        ],
      ),
    );
  }

  // 기준 HTML .tabs — 가로 텍스트 탭 + 활성 밑 점.
  Widget _tabs(AppTokens tk) {
    const labels = ['전체', '오늘', '중요', '대기', '완료'];
    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => setState(() => _tab = i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 21, top: 2, bottom: 11),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Text(labels[i],
                        style: AppText.body(_tab == i ? tk.ink : tk.inkSoft)
                            .copyWith(fontSize: 12)),
                    if (_tab == i)
                      Positioned(
                        bottom: -6,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: tk.mark),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: () => showQuickCaptureInput(context, ref),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Text('＋', style: AppText.glyph(tk.mark, size: 18)),
            ),
          ),
        ],
      ),
    );
  }

  // 기준 HTML .task-line — 원형 체크 · 제목 · 메타 · 우측 tail.
  Widget _taskLine(AppTokens tk, Node n) {
    final done = n.status == NodeStatus.done;
    final today = todayDate();
    final repo = ref.read(nodeRepoProvider);

    final metaBits = <String>[
      if (n.important) '중요',
      if (n.urgent) '긴급',
      if (n.note.isNotEmpty) n.note,
    ];
    String tail;
    if (done) {
      tail = n.doneAt != null ? DateFormat('HH:mm').format(n.doneAt!) : '완료';
    } else if (n.status == NodeStatus.drawer) {
      tail = '대기';
    } else if (n.date != null && dateOnly(n.date!) == today) {
      tail = '오늘';
    } else if (n.date != null) {
      tail = DateFormat('M/d').format(n.date!);
    } else {
      tail = '';
    }

    return InkWell(
      onTap: () => showNodeDetailSheet(context, n),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: kGutter),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  done ? repo.reopen(n.id) : repo.complete(n.id),
              child: Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? tk.mark : Colors.transparent,
                  border: Border.all(
                      color: done ? tk.mark : tk.inkSoft, width: 1),
                ),
                child:
                    done ? Icon(Icons.check, size: 11, color: tk.paper) : null,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(done ? tk.inkSoft : tk.ink).copyWith(
                          fontSize: 13,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: tk.inkSoft)),
                  if (metaBits.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(metaBits.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta(tk.inkSoft, size: 10)),
                    ),
                ],
              ),
            ),
            if (tail.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(tail, style: AppText.meta(tk.inkSoft, size: 9)),
            ],
          ],
        ),
      ),
    );
  }
}
