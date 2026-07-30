import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/dialogs.dart';
import 'core/journal.dart';
import 'core/theme.dart';
import 'data/repos/time_track_repository.dart';
import 'features/all/all_view.dart';
import 'features/capture/dump_view.dart';
import 'features/capture/quick_capture_input.dart';
import 'features/fortune/fortune_view.dart';
import 'features/habit/habit_view.dart';
import 'features/home/home_view.dart';
import 'features/matrix/matrix_view.dart';
import 'features/schedule/calendar_view.dart';
import 'features/schedule/time_hub.dart';
import 'features/shell/app_drawer.dart';
import 'features/timetrack/time_track_screen.dart';
import 'features/today/goal_editor.dart';
import 'features/today/today_view.dart';
import 'providers.dart';

/// 셸: 오늘 / 매트릭스 / 아웃라인 / 전체.
/// 입력바는 body 안에 있어 키보드가 올라와도 항상 보인다.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // 6 = 홈(대시보드). 기존 탭 인덱스(0~5)는 그대로 유지해 음성/FAB 로직 보존.
  // 사이드바 드로어가 어느 화면에서든 탭을 바꿀 수 있게 provider 로 관리한다.
  int get _index => ref.read(homeTabProvider);
  void _setTab(int i) => ref.read(homeTabProvider.notifier).state = i;

  @override
  void initState() {
    super.initState();
    // 포커스·매트릭스 위젯 탭 진입 → 빠른 담기 입력창.
    quickCaptureFocusRequest.addListener(_onQuickCapture);
    // 타임트래커 위젯 탭 진입 → 현재 블록 입력창.
    timeTrackLaunchRequest.addListener(_onTimeTrackLaunch);
    // 캘린더 위젯 탭 진입 → 달력 화면.
    calendarLaunchRequest.addListener(_onCalendarLaunch);
    // 위젯 음성 버튼 진입 → 마이크 시작(결과는 GlobalMicButton 구독이 라우팅).
    voiceCaptureRequest.addListener(_onVoiceCapture);
    // 목표 위젯 진입 → 오늘의 목표 편집기.
    goalEditRequest.addListener(_onGoalEdit);
  }

  @override
  void dispose() {
    quickCaptureFocusRequest.removeListener(_onQuickCapture);
    timeTrackLaunchRequest.removeListener(_onTimeTrackLaunch);
    calendarLaunchRequest.removeListener(_onCalendarLaunch);
    voiceCaptureRequest.removeListener(_onVoiceCapture);
    goalEditRequest.removeListener(_onGoalEdit);
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

  /// 위젯 음성 버튼으로 앱이 열렸을 때 마이크를 시작한다. 받아쓴 결과는
  /// 화면에 떠 있는 GlobalMicButton 의 구독이 그대로 분류·라우팅(하이브리드)한다.
  Future<void> _onVoiceCapture() async {
    if (!mounted) return;
    final stt = ref.read(sttServiceProvider);
    try {
      if (!await stt.isAvailable()) {
        _voiceNotice('이 기기에서 음성 인식을 찾지 못했어요.');
        return;
      }
      if (!await stt.requestPermission()) {
        _voiceNotice('마이크 권한이 꺼져 있어요. 앱 권한에서 마이크를 허용해 주세요.');
        return;
      }
      await stt.start(localeId: 'ko_KR');
    } catch (_) {
      _voiceNotice('음성 인식을 시작하지 못했어요. 잠시 뒤 다시 시도해 주세요.');
    }
  }

  Future<void> _onGoalEdit() async {
    if (!mounted) return;
    await showGoalEditor(context, ref);
  }

  void _voiceNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('🎙️ $message'),
      ));
  }

  static const _titles = ['오늘', '매트릭스', '쏟아내기', '일과', '습관', '전체', '홈'];
  // 제목 위 모노 eyebrow (v17 레퍼런스 헤더). _titles 와 인덱스 정렬.
  static const _eyebrows = [
    'TODAY',
    'MATRIX',
    'DUMP',
    'ROUTINE',
    'HABIT',
    'ALL',
    'MY DAY',
  ];

  @override
  Widget build(BuildContext context) {
    // 탭 인덱스 변화(드로어·바텀내브)에 셸이 다시 그려지도록 구독.
    ref.watch(homeTabProvider);
    final body = switch (_index) {
      0 => const TodayView(),
      1 => const MatrixView(),
      2 => const DumpView(),
      3 => const TimeHub(),
      4 => const HabitView(),
      6 => HomeView(
          onOpenTab: _setTab,
          onOpenCalendar: _openCalendar,
          onOpenFortune: _openFortune,
        ),
      _ => const AllView(),
    };

    return Scaffold(
      resizeToAvoidBottomInset: true,
      endDrawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Builder(
              builder: (ctx) => Masthead(
                title: _titles[_index],
                eyebrow: _eyebrows[_index],
                actions: _mastheadActions(ctx),
              ),
            ),
            Expanded(child: body),
            // v17: 하단 '빠르게 담기' 바 제거 — 가운데 ＋(담기)가 그 역할을 한다.
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
      actions.add(_act('＋ 습관', _newHabit));
    }
    actions.add(_menuBtn(ctx));
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

  /// 레퍼런스 .menu-btn — 원형(테두리) 안 햄버거(3줄) 아이콘.
  Widget _menuBtn(BuildContext ctx) {
    final tk = t(context);
    Widget line() => Container(width: 15, height: 1.4, color: tk.ink);
    return GestureDetector(
      onTap: () => Scaffold.of(ctx).openEndDrawer(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(left: 10),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: tk.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [line(), const SizedBox(height: 4), line(), const SizedBox(height: 4), line()],
        ),
      ),
    );
  }

  /// 현재 탭에 맞는 빠른 담기 유형 — 습관 탭→습관, 일과→일정, 쏟아내기→메모,
  /// 그 외(홈·오늘·매트릭스·전체)→할 일.
  static String _captureTypeForTab(int index) => switch (index) {
        4 => 'habit',
        3 => 'schedule',
        2 => 'memo',
        _ => 'task',
      };

  /// 하단 탭 — 홈/오늘/＋(담기)/일과/전체. 활성 = 세이지 밑줄, 가운데 초록 ＋ 원.
  Widget _bottomNav(BuildContext context) {
    final tk = t(context);

    // 아이콘 + 라벨(얇게) 세로 스택, 활성 = 잉크 색 + 밑줄. (레퍼런스 하단바 굵기 유지)
    Widget item(int idx, String label, IconData icon) {
      final active = _index == idx;
      final color = active ? tk.ink : tk.inkSoft;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setTab(idx),
          behavior: HitTestBehavior.opaque,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: active
                      ? BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: tk.mark, width: 1.2)))
                      : null,
                  // active 인자 제거 → 항상 얇게(w400).
                  child: Text(label, style: AppText.nav(color)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tk.line, width: 1))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              item(6, '홈', Icons.home_outlined),
              item(0, '오늘', Icons.calendar_today_outlined),
              // 가운데 ＋ — 지금 머무는 메뉴에 맞춰 담기(유형 자동 선택).
              Expanded(
                child: GestureDetector(
                  onTap: () => showQuickCaptureInput(context, ref,
                      presetType: _captureTypeForTab(_index)),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: tk.mark, shape: BoxShape.circle),
                        child: Icon(Icons.add, color: tk.paper, size: 24),
                      ),
                      const SizedBox(height: 3),
                      Text('담기', style: AppText.nav(tk.inkSoft)),
                    ],
                  ),
                ),
              ),
              item(3, '일과', Icons.check_box_outlined),
              item(5, '전체', Icons.reorder),
            ],
          ),
        ),
      ),
    );
  }

  /// 새 습관 만들기 (이름만 — 카테고리는 상세에서).
  Future<void> _newHabit() async {
    final name = await showInputDialog(context,
        title: '새 습관',
        subtitle: '매일 반복하고 싶은 작은 행동을 적어주세요.',
        fieldLabel: '습관 이름',
        hint: '예: 물 한 잔 마시기',
        saveLabel: '만들기');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(habitRepoProvider).addHabit(name.trim());
  }

  // 홈 히어로에서 여는 화면(달력·운세)만 셸에 남긴다. 나머지 사이드바
  // 항목은 공용 [AppDrawer] 가 직접 연다.
  void _openFortune() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const FortuneView()));

  void _openCalendar() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
}
