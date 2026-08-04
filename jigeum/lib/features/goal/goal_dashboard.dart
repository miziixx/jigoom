import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../data/db.dart';
import '../../data/repos/node_repository.dart';
import '../../providers.dart';

/// 목표 상세 대시보드 데이터 계층.
///
/// 이 기능은 기존 앱과 **한 데이터 모델을 공유**한다(중복 없음):
///  - "단계" = 목표(type=goal)의 하위 할 일(자식 task 노드). 목표 관리 목록의
///    진행률(하위 할 일 완료율)과 대시보드 진행률이 항상 일치한다.
///  - 목표 메모 = 목표 노드의 기존 `note` 컬럼.
///  - 기록/메모 저장 시각만 기존 key-value `Settings` 테이블에 JSON 으로 넣는다
///    (키 접두사 `goal.`). 스키마(테이블/컬럼)는 바꾸지 않는다.
///
/// 분석·진행률·활동 그래프는 실제 데이터(하위 할 일 완료·집중 세션)에서 계산한다.

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// 모델
// ---------------------------------------------------------------------------

/// 진행 기록 타임라인의 한 항목.
class GoalEvent {
  const GoalEvent({required this.at, required this.title, required this.detail});

  final DateTime at;
  final String title; // 굵은 한 줄 (예: "단계 완료")
  final String detail; // 보조 설명

  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'title': title, 'detail': detail};

  factory GoalEvent.fromJson(Map<String, dynamic> j) => GoalEvent(
        at: DateTime.parse(j['at'] as String),
        title: (j['title'] ?? '') as String,
        detail: (j['detail'] ?? '') as String,
      );
}

/// 분석 4개 셀 중 한 칸(제목 + 설명).
class GoalInsight {
  const GoalInsight(this.title, this.text);
  final String title;
  final String text;
}

/// 화면이 그리는 데 필요한 계산 결과 묶음.
class GoalDashboardData {
  const GoalDashboardData({
    required this.title,
    required this.progress,
    required this.ddayLabel,
    required this.deadlineLabel,
    required this.completedSteps,
    required this.totalSteps,
    required this.weekActivityCount,
    required this.forecastLabel,
    required this.steps,
    required this.pace,
    required this.consistency,
    required this.risk,
    required this.focus,
    required this.nextAction,
    required this.activity,
    required this.note,
    required this.noteSavedLabel,
    required this.history,
  });

  final String title;
  final int progress; // 0~100
  final String ddayLabel; // 예: "D-12" / "D-DAY" / "D-—"
  final String deadlineLabel; // 예: "마감 8월 31일" / "마감일 없음"
  final int completedSteps;
  final int totalSteps;
  final int weekActivityCount;
  final String forecastLabel; // 예: "8월 27일" / "—"
  final List<Node> steps; // 하위 할 일(자식 task) — 정렬됨
  final GoalInsight pace;
  final GoalInsight consistency;
  final GoalInsight risk;
  final GoalInsight focus;
  final String nextAction;
  final List<int> activity; // 이번 주 월~일 활동 횟수 (길이 7)
  final String note;
  final String noteSavedLabel; // 예: "마지막 저장 14:20" / "아직 저장하지 않음"
  final List<GoalEvent> history;
}

// ---------------------------------------------------------------------------
// 리포지토리
// ---------------------------------------------------------------------------

class GoalDashboardRepository {
  GoalDashboardRepository(this.db, this.nodes);

  final AppDatabase db;
  final NodeRepository nodes;

  String _eventsKey(String goalId) => 'goal.events.$goalId';
  String _noteAtKey(String goalId) => 'goal.noteAt.$goalId';

  Future<String?> _get(String key) async {
    final row = await (db.select(db.settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _set(String key, String value) async {
    await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value));
  }

  Future<List<Node>> _children(String goalId) async {
    final rows = await (db.select(db.nodes)
          ..where((n) =>
              n.parentId.equals(goalId) & n.type.equals(NodeType.task)))
        .get();
    rows.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return rows;
  }

  int _progressOf(List<Node> children) {
    if (children.isEmpty) return 0;
    final done = children.where((c) => c.status == NodeStatus.done).length;
    return (done / children.length * 100).round();
  }

  // ----- 단계 = 하위 할 일 -----

  Future<void> addStep(String goalId, String title) async {
    await nodes.create(
        parentId: goalId,
        type: NodeType.task,
        title: title.trim(),
        important: true);
    await _logEvent(goalId, '단계 추가', title.trim());
  }

  Future<void> editStep(String childId, String title) async {
    await nodes.setTitle(childId, title.trim());
  }

  Future<void> deleteStep(String goalId, String childId) async {
    final before = _progressOf(await _children(goalId));
    await nodes.deleteNode(childId);
    final after = _progressOf(await _children(goalId));
    if (after != before) {
      await _logEvent(goalId, '진행률 변경', '$before% → $after%');
    }
  }

  Future<void> toggleStep(String goalId, Node child) async {
    final before = _progressOf(await _children(goalId));
    if (child.status == NodeStatus.done) {
      await nodes.reopen(child.id);
    } else {
      await nodes.complete(child.id);
    }
    final after = _progressOf(await _children(goalId));
    if (after != before) {
      await _logEvent(goalId, '진행률 변경', '$before% → $after%');
    }
  }

  /// 새 순서(자식 id 나열)를 sortOrder 로 반영.
  Future<void> reorderSteps(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await nodes.reorder(orderedIds[i], i);
    }
  }

  // ----- 메모 (목표 노드의 note 재사용) -----

  Future<void> saveNote(String goalId, String text) async {
    await nodes.setNote(goalId, text.trim());
    await _set(_noteAtKey(goalId), DateTime.now().toIso8601String());
    await _logEvent(goalId, '메모 수정', '목표 메모를 정리했어요');
  }

  Future<DateTime?> noteSavedAt(String goalId) async {
    final raw = await _get(_noteAtKey(goalId));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  // ----- 기록 이벤트 (메모 수정·진행률 변경만 저장, 나머지는 파생) -----

  Future<List<GoalEvent>> _getEvents(String goalId) async {
    final raw = await _get(_eventsKey(goalId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list) GoalEvent.fromJson(e as Map<String, dynamic>)
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _logEvent(String goalId, String title, String detail) async {
    final events = await _getEvents(goalId);
    events.add(GoalEvent(at: DateTime.now(), title: title, detail: detail));
    final trimmed =
        events.length > 120 ? events.sublist(events.length - 120) : events;
    await _set(_eventsKey(goalId),
        jsonEncode([for (final e in trimmed) e.toJson()]));
  }

  // ----- 집중 시작(NEXT ACTION) -----

  /// NEXT ACTION 의 "지금 시작" — 목표에 연결된 집중 세션을 시작한다.
  /// 실제 집중 세션 데이터라 활동 그래프·기록에 자동 반영된다.
  Future<void> startFocus(String goalId, String actionLabel) async {
    await db.into(db.focusSessions).insert(FocusSessionsCompanion.insert(
          id: _uuid.v4(),
          nodeId: Value(goalId),
          startedAt: DateTime.now(),
        ));
    await _logEvent(goalId, '집중 시작', actionLabel);
  }

  // ----- 계산 -----

  Future<GoalDashboardData> load(Node goal) async {
    final goalId = goal.id;
    final children = await _children(goalId);
    final childIds = [for (final c in children) c.id];
    final sessionIds = [goalId, ...childIds];
    final sessions = await (db.select(db.focusSessions)
          ..where((s) => s.nodeId.isIn(sessionIds)))
        .get();
    final events = await _getEvents(goalId);

    final total = children.length;
    final done = children.where((c) => c.status == NodeStatus.done).length;
    final progress = total == 0
        ? (goal.status == NodeStatus.done ? 100 : 0)
        : (done / total * 100).round();

    // 마감일 · D-day
    final today = todayDate();
    final deadline = goal.date == null ? null : dateOnly(goal.date!);
    final String ddayLabel;
    final String deadlineLabel;
    if (deadline == null) {
      ddayLabel = 'D-—';
      deadlineLabel = '마감일 없음';
    } else {
      final diff = deadline.difference(today).inDays;
      ddayLabel =
          diff == 0 ? 'D-DAY' : (diff > 0 ? 'D-$diff' : 'D+${-diff}');
      deadlineLabel = '마감 ${DateFormat('M월 d일').format(deadline)}';
    }

    // 이번 주(월~일) 활동 — 하위 할 일 완료 + 집중 세션 시각을 요일별 집계.
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final activity = List<int>.filled(7, 0);
    final activityTimes = <DateTime>[];
    void addActivity(DateTime? at) {
      if (at == null) return;
      activityTimes.add(at);
      if (!at.isBefore(weekStart) && at.isBefore(weekEnd)) {
        final idx = dateOnly(at).difference(weekStart).inDays;
        if (idx >= 0 && idx < 7) activity[idx]++;
      }
    }

    for (final c in children) {
      if (c.status == NodeStatus.done) addActivity(c.doneAt);
    }
    for (final s in sessions) {
      addActivity(s.startedAt);
    }

    final weekActivityCount = activity.fold<int>(0, (a, b) => a + b);
    final activeDays = activity.where((v) => v > 0).length;

    // 예상 완료일 — 실제 진행 속도(경과일당 완료량)로 추정.
    DateTime? forecastDate;
    if (total > 0 && done > 0) {
      if (done >= total) {
        forecastDate = today;
      } else {
        final createdDay = dateOnly(goal.createdAt);
        final elapsed = today.difference(createdDay).inDays;
        final perDay = done / (elapsed < 1 ? 1 : elapsed);
        if (perDay > 0) {
          final daysNeeded = ((total - done) / perDay).ceil();
          forecastDate = today.add(Duration(days: daysNeeded.clamp(1, 3650)));
        }
      }
    }
    final forecastLabel =
        forecastDate == null ? '—' : DateFormat('M월 d일').format(forecastDate);

    // 마지막 활동 이후 경과일
    DateTime? lastActivity;
    for (final at in activityTimes) {
      if (lastActivity == null || at.isAfter(lastActivity)) lastActivity = at;
    }
    final daysSinceLast = lastActivity == null
        ? null
        : today.difference(dateOnly(lastActivity)).inDays;

    final behindSchedule = deadline != null &&
        forecastDate != null &&
        forecastDate.isAfter(deadline);

    // 다음 행동 — 남은 첫 단계(하위 할 일) → 없으면 안내.
    String nextAction = '';
    for (final c in children) {
      if (c.status != NodeStatus.done) {
        nextAction = c.title;
        break;
      }
    }
    if (nextAction.isEmpty) {
      nextAction = (total > 0 && done >= total)
          ? '모든 단계를 마쳤어요'
          : '가장 작은 단계 하나를 추가해요';
    }

    // 분석 (실제 값 기반)
    final GoalInsight pace;
    if (behindSchedule) {
      pace = const GoalInsight(
          '마감보다 느림', '지금 속도면 마감을 넘길 수 있어요. 단계를 더 작게 나눠 봐요.');
    } else if (progress >= 55) {
      pace = GoalInsight(
          '좋은 속도',
          deadline == null
              ? '현재 흐름을 유지하면 곧 마무리할 수 있어요.'
              : '현재 흐름을 유지하면 마감 전에 안정적으로 완료할 수 있어요.');
    } else if (progress >= 30) {
      pace =
          const GoalInsight('보통 속도', '한두 번만 더 움직이면 예정 흐름에 다시 올라설 수 있어요.');
    } else {
      pace = const GoalInsight('천천히 진행 중', '다음 행동을 더 작게 쪼개면 시작하기 쉬워져요.');
    }

    final GoalInsight consistency = GoalInsight(
      '주 $activeDays회',
      activeDays >= 4
          ? '이번 주 꾸준히 움직이고 있어요.'
          : activeDays >= 1
              ? '이번 주 최근 며칠 사이 활동이 있었어요.'
              : '이번 주에는 아직 활동이 없어요.',
    );

    final GoalInsight risk;
    final highRisk =
        behindSchedule || (daysSinceLast != null && daysSinceLast >= 7);
    final midRisk =
        progress < 30 || (daysSinceLast != null && daysSinceLast >= 4);
    if (highRisk) {
      risk = GoalInsight(
          '높음',
          behindSchedule
              ? '현재 속도라면 마감을 넘길 수 있어요.'
              : '한동안 움직임이 없었어요. 작은 행동으로 다시 시작해요.');
    } else if (midRisk) {
      risk = const GoalInsight('주의', '정체 구간이 조금 길어지고 있어요.');
    } else {
      risk = const GoalInsight('낮음', '현재 흐름이면 큰 위험 없이 진행할 수 있어요.');
    }

    final focus = GoalInsight('다음 한 걸음', nextAction);

    // 기록 타임라인 — 저장 이벤트(메모·진행률) + 파생(생성·단계 완료·집중) 병합.
    final history = <GoalEvent>[
      ...events,
      GoalEvent(
          at: goal.createdAt,
          title: '목표 생성',
          detail: '"${goal.title}" 목표를 시작했어요.'),
      for (final c in children)
        if (c.status == NodeStatus.done && c.doneAt != null)
          GoalEvent(at: c.doneAt!, title: '단계 완료', detail: c.title),
      for (final s in sessions)
        GoalEvent(
            at: s.startedAt,
            title: '집중 기록',
            detail: s.endedAt == null
                ? '집중을 시작했어요'
                : '${(s.actualSeconds / 60).round()}분 집중'),
    ]..sort((a, b) => b.at.compareTo(a.at));

    final savedAt = await noteSavedAt(goalId);
    final noteSavedLabel = savedAt == null
        ? '아직 저장하지 않음'
        : '마지막 저장 ${_savedTimeLabel(savedAt)}';

    return GoalDashboardData(
      title: goal.title,
      progress: progress,
      ddayLabel: ddayLabel,
      deadlineLabel: deadlineLabel,
      completedSteps: done,
      totalSteps: total,
      weekActivityCount: weekActivityCount,
      forecastLabel: forecastLabel,
      steps: children,
      pace: pace,
      consistency: consistency,
      risk: risk,
      focus: focus,
      nextAction: nextAction,
      activity: activity,
      note: goal.note,
      noteSavedLabel: noteSavedLabel,
      history: history.length > 40 ? history.sublist(0, 40) : history,
    );
  }

  static String _savedTimeLabel(DateTime at) {
    final today = todayDate();
    final d = dateOnly(at);
    if (d == today) return DateFormat('HH:mm').format(at);
    return DateFormat('M월 d일 HH:mm').format(at);
  }
}

/// 기록 타임라인의 시각 라벨 — "오늘 14:20" / "어제 23:10" / "8월 1일".
String goalEventTimeLabel(DateTime at) {
  final today = todayDate();
  final d = dateOnly(at);
  final diff = today.difference(d).inDays;
  if (diff == 0) return '오늘 ${DateFormat('HH:mm').format(at)}';
  if (diff == 1) return '어제 ${DateFormat('HH:mm').format(at)}';
  return DateFormat('M월 d일').format(at);
}

// ---------------------------------------------------------------------------
// provider (이 기능 안에서만 선언)
// ---------------------------------------------------------------------------

final goalDashboardRepoProvider = Provider<GoalDashboardRepository>((ref) {
  return GoalDashboardRepository(
      ref.watch(dbProvider), ref.watch(nodeRepoProvider));
});
