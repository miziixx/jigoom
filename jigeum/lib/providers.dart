import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'data/db.dart';
import 'data/repos/node_repository.dart';

/// 위젯 탭 진입 시 퀵캡처 입력창에 포커스를 요청하는 트리거.
/// 값이 증가할 때마다 QuickCaptureBar 가 포커스+키보드를 연다.
final ValueNotifier<int> quickCaptureFocusRequest = ValueNotifier<int>(0);

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final nodeRepoProvider = Provider<NodeRepository>((ref) {
  return NodeRepository(ref.watch(dbProvider));
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
