import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'data/backup_service.dart';
import 'data/db.dart';
import 'data/repos/habit_repository.dart';
import 'data/repos/node_repository.dart';
import 'data/repos/schedule_repository.dart';
import 'data/repos/time_track_repository.dart';

/// 위젯 탭 진입 시 퀵캡처 입력창에 포커스를 요청하는 트리거.
/// 값이 증가할 때마다 QuickCaptureBar 가 포커스+키보드를 연다.
final ValueNotifier<int> quickCaptureFocusRequest = ValueNotifier<int>(0);

/// 타임트래커 위젯 탭 진입 시 현재 블록 입력창을 여는 트리거.
final ValueNotifier<int> timeTrackLaunchRequest = ValueNotifier<int>(0);

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

/// 일과(일정) & 루틴
final scheduleRepoProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(dbProvider));
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
