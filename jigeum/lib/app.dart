import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/dialogs.dart';
import 'core/journal.dart';
import 'core/theme.dart';
import 'data/repos/time_track_repository.dart';
import 'features/all/all_view.dart';
import 'features/capture/dump_staging.dart';
import 'features/capture/dump_view.dart';
import 'features/capture/quick_capture_bar.dart';
import 'features/capture/quick_capture_input.dart';
import 'features/fortune/fortune_view.dart';
import 'features/habit/habit_view.dart';
import 'features/matrix/matrix_view.dart';
import 'features/outline/outline_screen.dart';
import 'features/schedule/calendar_view.dart';
import 'features/schedule/time_hub.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/timetrack/time_track_screen.dart';
import 'features/today/today_view.dart';
import 'features/voice/ui/global_mic_button.dart';
import 'providers.dart';

/// 셸: 오늘 / 매트릭스 / 아웃라인 / 전체.
/// 입력바는 body 안에 있어 키보드가 올라와도 항상 보인다.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 포커스·매트릭스 위젯 탭 진입 → 빠른 담기 입력창.
    quickCaptureFocusRequest.addListener(_onQuickCapture);
    // 타임트래커 위젯 탭 진입 → 현재 블록 입력창.
    timeTrackLaunchRequest.addListener(_onTimeTrackLaunch);
    // 캘린더 위젯 탭 진입 → 달력 화면.
    calendarLaunchRequest.addListener(_onCalendarLaunch);
  }

  @override
  void dispose() {
    quickCaptureFocusRequest.removeListener(_onQuickCapture);
    timeTrackLaunchRequest.removeListener(_onTimeTrackLaunch);
    calendarLaunchRequest.removeListener(_onCalendarLaunch);
    super.dispose();
  }

  void _onQuickCapture() {
    if (!mounted) return;
    showQuickCaptureInput(context, ref);
  }

  void _onCalendarLaunch() {
    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
  }

  void _onTimeTrackLaunch() {
    if (!mounted) return;
    showTimeTrackInput(
      context,
      ref,
      date: DateTime.now(),
      block: TimeTrackRepository.blockOfNow(),
    );
  }

  static const _titles = ['오늘', '매트릭스', '쏟아내기', '일과', '습관', '전체'];
  static const _navLabels = ['today', 'matrix', 'dump', 'time', 'habit', 'all'];

  @override
  Widget build(BuildContext context) {
    final body = switch (_index) {
      0 => const TodayView(),
      1 => const MatrixView(),
      2 => const DumpView(),
      3 => const TimeHub(),
      4 => const HabitView(),
      _ => const AllView(),
    };

    return Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: _buildDrawer(context),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
            bottom: _index == 2 || _index == 3 || _index == 4 ? 62 : 130),
        child: GlobalMicButton(
          stt: ref.watch(sttServiceProvider),
          controller: ref.watch(voiceControllerProvider),
          // 쏟아내기 탭(2)에선 마이크 결과를 즉시 라우팅하지 않고, 타이핑과
          // 똑같이 분류만 해서 대기줄에 쌓는다("여기에 나오게").
          onFinalText: _index == 2
              ? (text) async {
                  final results =
                      ref.read(voiceControllerProvider).classifyMany(text);
                  final staging = ref.read(dumpStagingProvider.notifier);
                  for (final r in results) {
                    staging.addResult(r);
                  }
                }
              : null,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // 음성 마이크는 마스트헤드와 하단 입력바를 가리지 않도록 떠 있는 버튼으로 둔다.
      // 입력바가 키보드 위로 따라 올라오도록 body 에 배치.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Builder(
              builder: (ctx) => Masthead(
                title: _titles[_index],
                actions: _mastheadActions(ctx),
              ),
            ),
            Expanded(child: body),
            // 하단 담기 바는 할 일 계열 탭에만 (쏟아내기=2·시간=3·습관=4 제외 —
            // 쏟아내기는 자체 입력, 시간·습관은 담기 바 불필요).
            if (_index != 2 && _index != 3 && _index != 4)
              const QuickCaptureBar(),
            _bottomNav(context),
          ],
        ),
      ),
    );
  }

  /// 마스트헤드 우측: 탭별 액션 + ≡ MENU (모노).
  List<Widget> _mastheadActions(BuildContext ctx) {
    final actions = <Widget>[];
    if (_index == 4) {
      actions.add(_act('+습관', _newHabit));
    }
    actions.add(_act('≡ MENU', () => Scaffold.of(ctx).openDrawer()));
    return actions;
  }

  Widget _act(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 세로 여백으로 터치 영역 확보.
          padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8),
          child: Text(label, style: AppText.meta(t(context).inkSoft, size: 11)),
        ),
      );

  /// 하단 탭 — 소문자 모노, 상단 규칙선, 활성 = ink + 밑줄.
  /// 각 탭은 Expanded + 세로 여백으로 셀 전체가 터치되도록 함.
  Widget _bottomNav(BuildContext context) {
    final tk = t(context);
    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tk.line, width: 1))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              for (var i = 0; i < _navLabels.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _index = i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      alignment: Alignment.center,
                      // 넉넉한 터치 영역(≈44dp).
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _index == i ? tk.ink : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Text(_navLabels[i],
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: AppText.nav(
                                _index == i ? tk.ink : tk.inkSoft,
                                active: _index == i)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 새 습관 만들기 (이름만 — 카테고리는 상세에서).
  Future<void> _newHabit() async {
    final name =
        await showInputDialog(context, title: '새 습관', hint: '예: 아침 산책, 물 마시기');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(habitRepoProvider).addHabit(name.trim());
  }

  /// 아웃라인 — 하단 탭에서 사이드바로 이동. 폴더·목표 정리용.
  void _openOutline() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const OutlineScreen()));

  void _openSettings() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void _openFortune() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const FortuneView()));

  void _openCalendar() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CalendarScreen()));

  /// 보류함 — 음성 미인식·되돌린 원문 목록. 여기서 다시 분류하거나 버린다.
  void _openInbox() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InboxScreen(repository: ref.read(inboxRepoProvider))));

  /// 사이드바 메뉴 (에디토리얼) — 번호 + 라벨 + › 캐럿, 얇은 규칙선.
  Widget _buildDrawer(BuildContext context) {
    final tk = t(context);

    Widget row(String index, String label, VoidCallback onTap,
        {bool last = false}) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context).pop(); // 드로어 닫기
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(bottom: BorderSide(color: tk.line, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(index, style: AppText.meta(tk.inkSoft, size: 11)),
              ),
              Expanded(child: Text(label, style: AppText.body(tk.ink))),
              Text('›', style: AppText.glyph(tk.mark, size: 18)),
            ],
          ),
        ),
      );
    }

    return Drawer(
      backgroundColor: tk.paper,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text('지금', style: AppText.hTitle(tk.ink)),
              const SizedBox(height: 4),
              Text('MENU', style: AppText.meta(tk.inkSoft, size: 10)),
              const SizedBox(height: 10),
              Container(height: 1, color: tk.ink),
              row('01', '아웃라인', _openOutline),
              row('02', '달력', _openCalendar),
              row('03', '오늘의 운세', _openFortune),
              row('04', '보류함', _openInbox),
              row('05', '설정', _openSettings, last: true),
            ],
          ),
        ),
      ),
    );
  }
}
