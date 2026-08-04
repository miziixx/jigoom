import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jigeum/core/constants.dart';
import 'package:jigeum/core/settings_controller.dart';
import 'package:jigeum/data/db.dart';
import 'package:jigeum/providers.dart';
import 'package:jigeum/features/widget_studio/studio_controller.dart';
import 'package:jigeum/features/widget_studio/studio_live_data.dart';
import 'package:jigeum/features/widget_studio/studio_tokens.dart';
import 'package:jigeum/features/widget_studio/widget_config.dart';

/// 조건이 참이 될 때까지(또는 타임아웃) 대기 — 컨트롤러의 비동기 kv 로드/저장을 기다린다.
Future<void> _until(bool Function() cond,
    {Duration timeout = const Duration(seconds: 2)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('디자인 토큰 (레퍼런스 값 고정)', () {
    test('기본 위젯 크기 9종 — 오차 0px', () {
      expect(kDefaultWidgetSizes[StudioWidgetType.clock], const Size(220, 150));
      expect(kDefaultWidgetSizes[StudioWidgetType.calendar], const Size(354, 230));
      expect(kDefaultWidgetSizes[StudioWidgetType.goal], const Size(354, 100));
      expect(kDefaultWidgetSizes[StudioWidgetType.tracker], const Size(354, 224));
      expect(kDefaultWidgetSizes[StudioWidgetType.tasks], const Size(220, 210));
      expect(kDefaultWidgetSizes[StudioWidgetType.habits], const Size(220, 180));
      expect(kDefaultWidgetSizes[StudioWidgetType.matrix], const Size(354, 230));
      expect(kDefaultWidgetSizes[StudioWidgetType.capture], const Size(144, 88));
      expect(kDefaultWidgetSizes[StudioWidgetType.fortune], const Size(220, 130));
    });

    test('프레임 상수 — 레퍼런스와 동일', () {
      expect(StudioFrame.headerHeight, 27);
      expect(StudioFrame.radius, 14);
      expect(StudioFrame.lineWidth, 0.7);
      expect(StudioFrame.minWidth, 110);
      expect(StudioFrame.minHeight, 72);
      expect(StudioFrame.bgAlpha, 0.92);
    });

    test('반응형 상태 임계값 (normal/compact/tiny)', () {
      expect(studioStateFor(354, 230), StudioSizeState.normal);
      expect(studioStateFor(220, 210), StudioSizeState.compact); // width<230
      expect(studioStateFor(354, 120), StudioSizeState.compact); // height<125
      expect(studioStateFor(150, 200), StudioSizeState.tiny); // width<160
      expect(studioStateFor(300, 85), StudioSizeState.tiny); // height<90
    });

    test('테마 8종 + INK NIGHT 색상 정확', () {
      expect(StudioTheme.all.length, 8);
      final ink = StudioTheme.byKey('ink');
      expect(ink.label, 'INK NIGHT');
      expect(ink.bg, const Color(0xFF191B1D));
      expect(ink.primary, const Color(0xFF8BA99B));
      // 알 수 없는 키는 sage 로 폴백.
      expect(StudioTheme.byKey('nope').key, 'sage');
    });

    test('크기 프리셋 6종', () {
      expect(kSizePresets.map((p) => p.size).toList(), const [
        Size(144, 88),
        Size(220, 100),
        Size(220, 168),
        Size(354, 112),
        Size(354, 184),
        Size(354, 270),
      ]);
    });
  });

  group('데이터 모델 직렬화', () {
    test('WidgetConfig 라운드트립', () {
      const w = WidgetConfig(
        id: 'a',
        type: StudioWidgetType.calendar,
        title: '캘린더',
        x: 12,
        y: 34,
        width: 354,
        height: 230,
        zIndex: 5,
        view: StudioCalView.week,
        theme: 'cobalt',
        surface: StudioSurface.paper,
        backgroundOpacity: 80,
        opacity: 90,
        fontScale: 110,
        radius: 8,
        lineWidth: 1.2,
        lineColor: 0xFF112233,
        accentColor: 0xFF445566,
      );
      final r = WidgetConfig.fromJson(w.toJson());
      expect(r.id, 'a');
      expect(r.type, StudioWidgetType.calendar);
      expect(r.view, StudioCalView.week);
      expect(r.surface, StudioSurface.paper);
      expect(r.backgroundOpacity, 80);
      expect(r.lineColor, 0xFF112233);
      expect(r.accentColor, 0xFF445566);
      expect(r.sizeState, StudioSizeState.normal);
    });

    test('TimeRecord.parse — 첫 줄 제목 + 이후 작업', () {
      final p = TimeRecord.parse('앱 개발 기록\n홈 정렬 수정\n타임트래커 점검');
      expect(p.title, '앱 개발 기록');
      expect(p.work, ['홈 정렬 수정', '타임트래커 점검']);
      expect(TimeRecord.parse('   ').title, '기록'); // 빈 입력 폴백
    });

    test('studioClock — 실시간 시계 값(날짜·시간·일진·월상)', () {
      final c = studioClock(DateTime(2026, 8, 3, 16, 14));
      expect(c.date, '8월 3일 월요일');
      expect(c.time, '16:14');
      // 일진: 간지 2자 + 日.
      expect(RegExp(r'^.{2}日$').hasMatch(c.ganzhi), true);
      expect(c.moon.isNotEmpty, true);
      // 자정 근처 자릿수 패딩.
      expect(studioClock(DateTime(2026, 1, 9, 9, 5)).time, '09:05');
    });
  });

  group('StudioController — 배치·타임트래커·영속화', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container =
          ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    StudioController ctrl() => container.read(studioControllerProvider.notifier);
    StudioSession sess() => container.read(studioControllerProvider);

    test('최초 실행 시 초기 6위젯 로드', () async {
      ctrl();
      await _until(() => sess().widgets.isNotEmpty);
      expect(sess().widgets.length, 6);
      expect(sess().widgets.any((w) => w.type == StudioWidgetType.tracker), true);
    });

    test('위젯 추가 → 개수 증가 + 선택', () async {
      final c = ctrl();
      await _until(() => sess().widgets.isNotEmpty);
      c.addWidget(StudioWidgetType.clock);
      expect(sess().widgets.length, 7);
      expect(sess().selected?.type, StudioWidgetType.clock);
      // 기본 크기 적용.
      expect(sess().selected!.width, 220);
    });

    test('타임트래커: 초안 없으면 시작 불가, 있으면 시작→종료→기록 저장', () async {
      final c = ctrl();
      await _until(() => sess().widgets.isNotEmpty);
      final tw = sess().widgets.firstWhere((w) => w.type == StudioWidgetType.tracker);

      expect(c.trackerStart(tw.id), false); // 초안 없음
      c.trackerDraft(tw.id, '앱 개발 기록\n홈 정렬 수정');
      expect(c.trackerStart(tw.id), true);
      expect(sess().trackerFor(tw.id).running, true);
      expect(sess().trackerFor(tw.id).startedAt, isNotNull);

      c.trackerStop(tw.id);
      final t = sess().trackerFor(tw.id);
      expect(t.running, false);
      expect(t.startedAt, isNull);
      expect(t.draft, ''); // 종료 후 초기화
      expect(t.records.length, 1);
      expect(t.records.first.title, '앱 개발 기록');
      expect(t.records.first.work, ['홈 정렬 수정']);
      expect(t.records.first.endedAt >= t.records.first.startedAt, true);
    });

    test('영속화: 배치·타이머·기록이 재시작(새 컨트롤러)에도 유지', () async {
      final c = ctrl();
      await _until(() => sess().widgets.isNotEmpty);
      final tw = sess().widgets.firstWhere((w) => w.type == StudioWidgetType.tracker);
      c.trackerDraft(tw.id, '지속 기록\n작업A');
      c.trackerStart(tw.id); // 실행 중 저장 → startedAt 영속
      c.setGlobalTheme('cobalt');
      c.addWidget(StudioWidgetType.fortune);
      final widgetCount = sess().widgets.length;
      await _until(() => true, timeout: const Duration(milliseconds: 120));

      // 같은 db 로 새 컨트롤러(=앱 재시작) 생성.
      final container2 =
          ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
      addTearDown(container2.dispose);
      container2.read(studioControllerProvider.notifier);
      await _until(() =>
          container2.read(studioControllerProvider).widgets.isNotEmpty);
      final s2 = container2.read(studioControllerProvider);
      expect(s2.widgets.length, widgetCount);
      expect(s2.studio.globalTheme, 'cobalt');
      final t2 = s2.trackerFor(tw.id);
      expect(t2.running, true); // 실행 중 상태 복원
      expect(t2.startedAt, isNotNull);
      expect(t2.draft, '지속 기록\n작업A');
    });

    test('대형 캔버스 전환 시 밖으로 나간 위젯을 안으로 되돌림', () async {
      final c = ctrl();
      await _until(() => sess().widgets.isNotEmpty);
      c.addWidget(StudioWidgetType.calendar);
      final id = sess().selected!.id;
      c.select(id);
      c.mutateSelected((w) => w.copyWith(x: 400, y: 900)); // 큰 캔버스 기준
      c.setLargeCanvas(false); // 390×844 로
      final w = sess().widgets.firstWhere((e) => e.id == id);
      expect(w.x + w.width <= 390, true);
      expect(w.y + w.height <= 844, true);
    });
  });

  group('StudioLiveData — 실제 앱 데이터 연결(§16)', () {
    late AppDatabase db;
    late ProviderContainer container;
    final today = todayDate();

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container =
          ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('데이터 없으면 리스트 비움(본문은 이때만 샘플 폴백)', () async {
      // 모든 스트림 로드 대기.
      await container.read(todayNodesProvider.future);
      await container.read(habitsProvider.future);
      final d = container.read(studioLiveDataProvider);
      expect(d.tasks, isEmpty);
      expect(d.habits, isEmpty);
      expect(d.dayEvents, isEmpty);
      expect(d.goal, isNull);
    });

    test('할 일·습관·목표·오늘 일정을 실데이터로 매핑', () async {
      final now = DateTime.now();
      // 열린 할 일(오늘, 중요).
      await db.into(db.nodes).insert(NodesCompanion.insert(
            id: 'task1',
            sortOrder: 0,
            type: NodeType.task,
            title: '위젯 데이터 연결',
            important: const Value(true),
            date: Value(today),
            status: const Value(NodeStatus.open),
            createdAt: now,
            updatedAt: now,
          ));
      // 완료(오늘 승리).
      await db.into(db.nodes).insert(NodesCompanion.insert(
            id: 'win1',
            sortOrder: 1,
            type: NodeType.task,
            title: '아침 정리',
            date: Value(today),
            status: const Value(NodeStatus.done),
            doneAt: Value(now),
            createdAt: now,
            updatedAt: now,
          ));
      // 목표.
      await db.into(db.nodes).insert(NodesCompanion.insert(
            id: 'goal1',
            sortOrder: 0,
            type: NodeType.goal,
            title: '이번 주 목표',
            note: const Value('핵심 흐름 마무리'),
            createdAt: now,
            updatedAt: now,
          ));
      // 습관 + 오늘 체크.
      await db.into(db.habits).insert(HabitsCompanion.insert(
          id: 'h1', title: '물 한 잔', category: const Value('아침'), createdAt: today));
      await db.into(db.habitTicks).insert(HabitTicksCompanion.insert(
          habitId: 'h1', date: today, completedAt: Value(now)));
      // 오늘 일정 09:00.
      await db.into(db.schedules).insert(SchedulesCompanion.insert(
            id: 's1',
            date: today,
            title: '팀 미팅',
            startMin: 540,
            endMin: 600,
            createdAt: now,
          ));
      // 이번 주 월요일 14:00 일정(주간 격자 검증용, 요일 고정).
      final monday = today.subtract(Duration(days: today.weekday - 1));
      await db.into(db.schedules).insert(SchedulesCompanion.insert(
            id: 's2',
            date: monday,
            title: '주간 회의',
            startMin: 840,
            endMin: 900,
            createdAt: now,
          ));

      // 스트림 첫 방출 대기.
      await container.read(todayNodesProvider.future);
      await container.read(todayWinsProvider.future);
      await container.read(goalsProvider.future);
      await container.read(habitsProvider.future);
      await container.read(habitTicksInRangeProvider(
              (start: today.subtract(const Duration(days: 60)), end: today))
          .future);
      await container.read(schedulesForDateProvider(today).future);
      await container.read(schedulesInRangeProvider((
        start: DateTime(today.year, today.month, 1),
        end: DateTime(today.year, today.month + 1, 0)
      )).future);
      await container.read(schedulesInRangeProvider(
              (start: monday, end: monday.add(const Duration(days: 6))))
          .future);
      for (final k in const [
        (important: true, urgent: true),
        (important: true, urgent: false),
        (important: false, urgent: true),
        (important: false, urgent: false),
      ]) {
        await container.read(quadrantProvider(k).future);
      }

      final d = container.read(studioLiveDataProvider);

      // 할 일: 승리 1 + 열린 1.
      expect(d.tasks.length, 2);
      expect(d.tasks.first.done, true);
      expect(d.tasks.first.chip, '완료');
      expect(d.tasks[1].title, '위젯 데이터 연결');
      expect(d.tasks[1].tags.contains('#중요'), true);
      expect(d.tasks[1].chip, '오늘');

      // 습관: '아침 · 1일 연속', 오늘 완료.
      expect(d.habits.length, 1);
      expect(d.habits.first.title, '물 한 잔');
      expect(d.habits.first.sub, '아침 · 1일 연속');
      expect(d.habits.first.done, true);

      // 목표: 제목·부제 + 진행률(완료 1 / 전체 2).
      expect(d.goal, isNotNull);
      expect(d.goal!.title, '이번 주 목표');
      expect(d.goal!.sub, '핵심 흐름 마무리');
      expect(d.goal!.doneCount, 1);
      expect(d.goal!.total, 2);

      // 오늘 일정.
      expect(d.dayEvents.length, 1);
      expect(d.dayEvents.first.time, '09:00');
      expect(d.dayEvents.first.title, '팀 미팅');

      // 매트릭스: task1(중요·비긴급) → SCHEDULE 칸(index 1).
      expect(d.matrix.length, 4);
      expect(d.matrix[1].body, '위젯 데이터 연결');
      expect(d.matrix[1].count, 1);
      expect(d.matrix[0].body, '현재 비어 있음'); // 긴급·중요 없음

      // 캘린더 MONTH: 오늘 + 월요일이 '일정 있는 날'.
      expect(d.cal.monthEventDays.contains(today.day), true);
      expect(d.cal.monthEventDays.contains(monday.day), true);
      // 캘린더 WEEK: 월요일 14:00 → col0(월)·row1(12시대) 블록.
      final mon = d.cal.weekBlocks
          .where((b) => b.col == 0 && b.row == 1 && b.title == '주간 회의');
      expect(mon.length, 1);
    });

    test('생일 설정 시 운세 카드 실데이터, 미설정이면 null(샘플 폴백)', () async {
      // 미설정: 운세 null.
      await container.read(todayNodesProvider.future);
      expect(container.read(studioLiveDataProvider).fortune, isNull);

      // 설정 후: 상위 카테고리 헤드라인 + 실천 조언.
      final sc = container.read(settingsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 30)); // _load 완료 대기
      await sc.setBirth(DateTime(1992, 3, 20, 9, 30),
          hasTime: true, longitude: 126.98, latitude: 37.57, male: true);
      final d = container.read(studioLiveDataProvider);
      expect(d.fortune, isNotNull);
      expect(d.fortune!.headline.trim().isNotEmpty, true);
      expect(d.fortune!.action.trim().isNotEmpty, true);
    });
  });
}
