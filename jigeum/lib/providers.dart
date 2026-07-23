import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'data/backup_service.dart';
import 'data/db.dart';
import 'data/repos/focus_session_repository.dart';
import 'data/repos/gcal_repository.dart';
import 'data/repos/habit_repository.dart';
import 'data/repos/node_repository.dart';
import 'data/repos/routine_builder_repository.dart';
import 'data/repos/schedule_repository.dart';
import 'data/repos/time_track_repository.dart';

/// 포커스·매트릭스 위젯 탭 진입 시 빠른 담기 입력창(모달)을 여는 트리거.
/// 값이 증가할 때마다 AppShell 이 showQuickCaptureInput 을 띄운다.
final ValueNotifier<int> quickCaptureFocusRequest = ValueNotifier<int>(0);

/// 타임트래커 위젯 탭 진입 시 현재 블록 입력창을 여는 트리거.
final ValueNotifier<int> timeTrackLaunchRequest = ValueNotifier<int>(0);

/// 캘린더 위젯 탭 진입 시 달력 화면을 여는 트리거.
final ValueNotifier<int> calendarLaunchRequest = ValueNotifier<int>(0);

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final nodeRepoProvider = Provider<NodeRepository>((ref) {
  return NodeRepository(ref.watch(dbProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(dbProvider));
});

/// 집중 세션 리포지토리 (적응형 타임박싱).
final focusSessionRepoProvider = Provider<FocusSessionRepository>((ref) {
  return FocusSessionRepository(ref.watch(dbProvider));
});

/// 오늘 "시작한" 집중 세션 수 (완료 아닌 시작을 세는 자기효능감 지표).
final startedTodayProvider = StreamProvider<int>((ref) {
  return ref.watch(focusSessionRepoProvider).watchStartedCount(todayDate());
});

/// 인박스 (parentId=null, type=memo, open)
final inboxProvider = StreamProvider<List<Node>>((ref) {
  return ref.watch(nodeRepoProvider).watchInbox();
});

/// 루트 노드 (아웃라이너 최상위)
final rootsProvider = StreamProvider<List<Node>>((ref) {
  return ref.watch(nodeRepoProvider).watchRoots();
});

/// 자식 노드
final childrenProvider =
    StreamProvider.family<List<Node>, String>((ref, parentId) {
  return ref.watch(nodeRepoProvider).watchChildren(parentId);
});

/// 오늘 open 노드 (오늘 날짜 + 날짜 미지정 포함)
final todayNodesProvider = StreamProvider<List<Node>>((ref) {
  return ref.watch(nodeRepoProvider).watchTodayOpen(todayDate());
});

/// 전체 노드 (전체 탭용)
final allNodesProvider = StreamProvider<List<Node>>((ref) {
  return ref.watch(nodeRepoProvider).watchAll();
});

/// 폴더 목록
final foldersProvider = StreamProvider<List<Node>>((ref) {
  return ref.watch(nodeRepoProvider).watchFolders();
});

/// 습관 리포지토리 & 목록 & 체크 기록
final habitRepoProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(dbProvider));
});

final habitsProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitRepoProvider).watchHabits();
});

final habitTicksProvider =
    StreamProvider.family<List<HabitTick>, String>((ref, habitId) {
  return ref.watch(habitRepoProvider).watchTicks(habitId);
});

/// 특정 날짜에 완료된 습관 틱들.
final habitTicksOnDateProvider =
    StreamProvider.family<List<HabitTick>, DateTime>((ref, d) {
  return ref.watch(habitRepoProvider).watchTicksOn(d);
});

/// 기간 내 습관 틱들 (주간 플랜용).
final habitTicksInRangeProvider = StreamProvider.family<List<HabitTick>,
    ({DateTime start, DateTime end})>((ref, r) {
  return ref.watch(habitRepoProvider).watchTicksInRange(r.start, r.end);
});

/// 일과(일정) & 루틴
final scheduleRepoProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(dbProvider));
});

/// 구글 캘린더 저장소 (캘린더 목록 + 동기화 상태).
final gcalRepoProvider = Provider<GcalRepository>((ref) {
  return GcalRepository(ref.watch(dbProvider));
});

/// 루틴 블록(그룹) + 순서 스텝 저장소.
final routineBuilderRepoProvider = Provider<RoutineBuilderRepository>((ref) {
  return RoutineBuilderRepository(ref.watch(dbProvider));
});

final routineGroupsProvider = StreamProvider<List<RoutineGroup>>((ref) {
  return ref.watch(routineBuilderRepoProvider).watchGroups();
});

final routineStepsProvider = StreamProvider<List<RoutineStep>>((ref) {
  return ref.watch(routineBuilderRepoProvider).watchSteps();
});

final schedulesForDateProvider =
    StreamProvider.family<List<Schedule>, DateTime>((ref, date) {
  return ref.watch(scheduleRepoProvider).watchForDate(date);
});

final routinesProvider = StreamProvider<List<Routine>>((ref) {
  return ref.watch(scheduleRepoProvider).watchRoutines();
});

/// 기간 일정 (달력 점 표시)
final schedulesInRangeProvider = StreamProvider.family<List<Schedule>,
    ({DateTime start, DateTime end})>((ref, r) {
  return ref.watch(scheduleRepoProvider).watchForRange(r.start, r.end);
});

/// 타임트래커
final timeTrackRepoProvider = Provider<TimeTrackRepository>((ref) {
  return TimeTrackRepository(ref.watch(dbProvider));
});

final timeBlocksForDateProvider =
    StreamProvider.family<List<TimeBlock>, DateTime>((ref, date) {
  return ref.watch(timeTrackRepoProvider).watchForDate(date);
});

/// 기간 내 기록 블록들 (주간 플랜용).
final timeBlocksInRangeProvider = StreamProvider.family<List<TimeBlock>,
    ({DateTime start, DateTime end})>((ref, r) {
  return ref.watch(timeTrackRepoProvider).watchForRange(r.start, r.end);
});

/// 날짜 범위 노드 (아웃라이너 기간 필터)
final dateRangeNodesProvider =
    StreamProvider.family<List<Node>, ({DateTime start, DateTime end})>(
        (ref, r) {
  return ref.watch(nodeRepoProvider).watchDateRange(r.start, r.end);
});

/// 오늘의 승리
final todayWinsProvider = StreamProvider<List<Node>>((ref) {
  return ref.watch(nodeRepoProvider).watchWinsForDate(todayDate());
});

/// 포커스 노드 (Future — 노드 변경 시 refresh)
final focusProvider = FutureProvider<Node?>((ref) {
  // today 노드가 바뀌면 포커스도 재계산
  ref.watch(todayNodesProvider);
  return ref.watch(nodeRepoProvider).selectFocus();
});

/// 매트릭스 사분면
final quadrantProvider =
    StreamProvider.family<List<Node>, ({bool important, bool urgent})>(
        (ref, key) {
  return ref
      .watch(nodeRepoProvider)
      .watchQuadrant(important: key.important, urgent: key.urgent);
});
