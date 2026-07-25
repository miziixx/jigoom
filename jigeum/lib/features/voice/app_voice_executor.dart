/// 음성 실행 seam 의 **앱 구현체**. 기획서 §6 + 커밋10(통합).
///
/// [VoiceExecutor] 를 확장해 라우팅 결정([VoiceResult])을 실제 A~J drift
/// repository 호출로 옮긴다. [VoiceController] 는 이 구현체에만 의존하므로
/// 오케스트레이션 로직(검증됨)은 그대로 두고, 여기서 side effect 만 연결한다.
///
/// ⚠️ 앱(Flutter/Riverpod) 계층 — 이 환경(Flutter 없음)에서 컴파일 검증 못 함.
/// 기기에서 `flutter analyze`/실행으로 확인 필요.
///
/// 되돌리기(§9)는 생성한 엔티티의 참조를 [_UndoRef] 로 돌려주고, [deleteEntity]
/// 에서 그 참조로 원상복구한다. 일부 지점(습관 추가·포커스 시작)은 아직 삭제
/// API 가 없어 되돌리기가 no-op 이다(주석 표시). nav/help 계열은 UI 동작이라
/// 여기서 생성하지 않는다(마이크 버튼 쪽에서 별도 처리 예정).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/repos/time_track_repository.dart';
import '../../providers.dart';
import 'models/intent_type.dart';
import 'models/time_parse_result.dart';
import 'models/voice_result.dart';
import 'voice_executor.dart';

class AppVoiceExecutor extends VoiceExecutor {
  AppVoiceExecutor(this._ref);

  final Ref _ref;

  @override
  Future<Object?> createEntity(VoiceResult result) async {
    switch (result.routedTo) {
      // A 빠른담기 — 오늘 할 일(task) 노드.
      case RoutePoint.quickCapture:
        final id = await _ref.read(nodeRepoProvider).create(
              type: NodeType.task,
              title: _titleOf(result),
              important: result.slots.important,
              urgent: result.slots.urgent,
              date: result.slots.date ?? todayDate(),
            );
        return _NodeRef(id);

      // B 매트릭스 — 중요/긴급 축이 붙은 task 노드.
      case RoutePoint.matrix:
        final id = await _ref.read(nodeRepoProvider).create(
              type: NodeType.task,
              title: _titleOf(result),
              important: result.slots.important,
              urgent: result.slots.urgent,
              date: result.slots.date,
            );
        return _NodeRef(id);

      // C 일정 — 날짜·시각(있으면)으로 스케줄 생성.
      case RoutePoint.schedule:
        final id = await _addSchedule(result);
        return _ScheduleRef(id);

      // G 목표 — goal 노드.
      case RoutePoint.goal:
        final id = await _ref.read(nodeRepoProvider).create(
              type: NodeType.goal,
              title: _titleOf(result),
            );
        return _NodeRef(id);

      // I 오늘의목표 — 날짜별 자유 텍스트(kv). 기존 값에 덧붙인다.
      case RoutePoint.goalToday:
        final repo = _ref.read(scheduleRepoProvider);
        final today = todayDate();
        final prev = (await repo.getDayGoal(today))?.trim() ?? '';
        final line = result.slots.text?.trim().isNotEmpty ?? false
            ? result.slots.text!.trim()
            : _titleOf(result);
        await repo.setDayGoal(today, prev.isEmpty ? line : '$prev\n$line');
        return _DayGoalRef(today, prev);

      // D 지금기록 / 타임트래커 — 현재 30분 블록 내용에 덧붙인다.
      case RoutePoint.logNow:
      case RoutePoint.timeTrack:
        final repo = _ref.read(timeTrackRepoProvider);
        final today = todayDate();
        final block = TimeTrackRepository.blockOfNow();
        final prev = (await repo.getBlock(today, block))?.content ?? '';
        final line = _titleOf(result);
        await repo.setBlock(today, block, prev.isEmpty ? line : '$prev $line');
        return _LogBlockRef(today, block, prev);

      // E 습관 — 체크(등록 습관명 대조) 또는 신규 습관 추가.
      case RoutePoint.habit:
        return _handleHabit(result);

      // F 루틴 — 그룹(+스텝) 생성.
      case RoutePoint.routine:
        final repo = _ref.read(routineBuilderRepoProvider);
        final groupName = result.slots.groupName?.trim();
        final gid = await repo
            .addGroup(groupName?.isNotEmpty ?? false ? groupName! : _titleOf(result));
        final step = result.slots.stepName?.trim();
        if (step != null && step.isNotEmpty) {
          await repo.addStep(gid, title: step);
        }
        return _RoutineGroupRef(gid);

      // J 포커스 — 세션 시작. (되돌리기 API 미구현 → no-op)
      case RoutePoint.focus:
        await _ref
            .read(focusSessionRepoProvider)
            .start(plannedMinutes: result.slots.durationMin);
        return null;

      // nav/help/inbox 는 여기서 생성하지 않는다(§ 위 주석).
      case RoutePoint.nav:
      case RoutePoint.helpStuck:
      case RoutePoint.helpFortune:
      case RoutePoint.inbox:
        return null;
    }
  }

  @override
  Future<void> deleteEntity(VoiceResult result, Object? ref) async {
    switch (ref) {
      case _NodeRef(:final id):
        await _ref.read(nodeRepoProvider).deleteNode(id);
      case _ScheduleRef(:final id):
        await _ref.read(scheduleRepoProvider).deleteSchedule(id);
      case _DayGoalRef(:final date, :final prev):
        await _ref.read(scheduleRepoProvider).setDayGoal(date, prev);
      case _LogBlockRef(:final date, :final block, :final prev):
        await _ref.read(timeTrackRepoProvider).setBlock(date, block, prev);
      case _HabitTickRef(:final habitId, :final date):
        // 토글은 대칭 — 다시 부르면 방금 만든 체크가 취소된다.
        await _ref.read(habitRepoProvider).toggleTick(habitId, date);
      case _RoutineGroupRef(:final id):
        await _ref.read(routineBuilderRepoProvider).deleteGroup(id);
      default:
        // null: 습관 추가·포커스 시작 등 되돌리기 API 미구현 지점.
        break;
    }
  }

  // -------------------------------------------------------------- helpers

  Future<Object?> _handleHabit(VoiceResult result) async {
    final repo = _ref.read(habitRepoProvider);
    final name = result.slots.habitName?.trim() ?? _titleOf(result);

    if (result.intent == IntentType.habitCheck) {
      // 등록 습관명과 대조해 오늘 체크를 켠다. 못 찾으면 신규 습관으로 폴백.
      final habits = await repo.watchHabits().first;
      final match = habits
          .where((h) => h.title.trim() == name || name.contains(h.title.trim()))
          .toList();
      if (match.isNotEmpty) {
        final today = todayDate();
        await repo.toggleTick(match.first.id, today);
        return _HabitTickRef(match.first.id, today);
      }
    }
    // habitAdd(또는 대조 실패) → 신규 습관. (삭제 API 미구현 → 되돌리기 no-op)
    await repo.addHabit(name);
    return null;
  }

  Future<String> _addSchedule(VoiceResult result) async {
    final tp = result.timeParse;
    final ParsedTime? time = result.slots.time ?? tp.time;
    final date = result.slots.date ?? tp.date ?? todayDate();
    final allDay = time == null;
    final startMin = time == null ? 0 : time.hour * 60 + time.minute;
    final endMin = time == null ? 0 : (startMin + 60 > 1439 ? 1439 : startMin + 60);
    return _ref.read(scheduleRepoProvider).addSchedule(
          date: date,
          title: _titleOf(result),
          startMin: startMin,
          endMin: endMin,
          allDay: allDay,
        );
  }

  /// 슬롯 제목이 비면 정규화문 → 원문 순으로 폴백(§0: 말은 버리지 않는다).
  String _titleOf(VoiceResult result) {
    final t = result.slots.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    final n = result.normalizedText.trim();
    return n.isNotEmpty ? n : result.rawText.trim();
  }
}

// 되돌리기용 참조 타입들. deleteEntity 가 패턴 매칭으로 원상복구한다.
class _NodeRef {
  const _NodeRef(this.id);
  final String id;
}

class _ScheduleRef {
  const _ScheduleRef(this.id);
  final String id;
}

class _DayGoalRef {
  const _DayGoalRef(this.date, this.prev);
  final DateTime date;
  final String prev;
}

class _LogBlockRef {
  const _LogBlockRef(this.date, this.block, this.prev);
  final DateTime date;
  final int block;
  final String prev;
}

class _HabitTickRef {
  const _HabitTickRef(this.habitId, this.date);
  final String habitId;
  final DateTime date;
}

class _RoutineGroupRef {
  const _RoutineGroupRef(this.id);
  final String id;
}
