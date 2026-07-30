import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../core/gcal/device_calendar_bridge.dart';
import '../../core/gcal/gcal_mapper.dart';
import '../../data/db.dart';
import '../../data/repos/gcal_repository.dart';
import '../../data/repos/schedule_repository.dart';

/// 로컬 일정 ↔ 폰 캘린더 양방향 동기화 엔진.
///
/// 순서: (1) 로컬 변경(dirty)을 폰 캘린더로 push → (2) 선택된 캘린더별로 창
/// [과거 60일 ~ 미래 365일]의 이벤트를 pull 해 로컬에 반영. 폰 캘린더에 쓴 것은
/// OS 동기화 어댑터가 구글로 올려준다. 실패해도 예외를 던지지 않는다.
class GcalSync {
  GcalSync(this.bridge, this.gcalRepo, this.scheduleRepo);

  final DeviceCalendarBridge bridge;
  final GcalRepository gcalRepo;
  final ScheduleRepository scheduleRepo;

  static const _back = Duration(days: 60);
  static const _fwd = Duration(days: 365);

  Future<void> run() async {
    try {
      await _push();
      final cals = await gcalRepo.selectedCalendars();
      final now = DateTime.now();
      final start = dateOnly(now.subtract(_back));
      final end = dateOnly(now.add(_fwd));
      for (final c in cals) {
        await _pull(c, start, end);
      }
    } catch (e, s) {
      debugPrint('gcal sync 실패(무시): $e\n$s');
    }
  }

  Future<void> _push() async {
    final dirty = await gcalRepo.dirtySchedules();
    if (dirty.isEmpty) return;
    final fallback = await _defaultWritableCalendarId();

    for (final s in dirty) {
      final calId = s.gcalCalendarId ?? fallback;
      if (calId == null) continue; // 밀 대상 캘린더 없음 → 보류
      try {
        if (s.deleted) {
          if (s.gcalId != null) await bridge.delete(s.gcalId!);
          await gcalRepo.purge(s.id);
          continue;
        }
        final r = GcalMapper.rangeMillis(s);
        if (s.gcalId == null) {
          final id = await bridge.insert(
            calendarId: calId,
            title: s.title,
            note: s.note,
            startMs: r.start,
            endMs: r.end,
            allDay: s.allDay,
          );
          if (id != null) {
            await gcalRepo.markPushed(s.id, gcalId: id, calendarId: calId);
          }
        } else {
          final ok = await bridge.update(
            eventId: s.gcalId!,
            title: s.title,
            note: s.note,
            startMs: r.start,
            endMs: r.end,
            allDay: s.allDay,
          );
          if (ok) {
            await gcalRepo.markPushed(s.id,
                gcalId: s.gcalId!, calendarId: calId);
          }
        }
      } catch (e) {
        debugPrint('gcal push 실패(${s.id}) — 다음에 재시도: $e');
      }
    }
  }

  Future<void> _pull(GcalCalendar c, DateTime start, DateTime end) async {
    final remote = await bridge.events(
      c.id,
      start.millisecondsSinceEpoch,
      end.add(const Duration(days: 1)).millisecondsSinceEpoch,
    );
    if (remote == null) return; // 조회 실패 → 이번엔 건드리지 않음(삭제 오판 방지)

    final seen = <String>{};
    for (final m in remote) {
      final rf = GcalMapper.fromMap(m);
      if (rf == null) continue;
      seen.add(rf.gcalId);
      final local = await gcalRepo.scheduleByGcalId(rf.gcalId);
      if (local == null) {
        await scheduleRepo.addSchedule(
          date: rf.date,
          endDate: rf.endDate,
          title: rf.title,
          note: rf.note,
          startMin: rf.startMin,
          endMin: rf.endMin,
          allDay: rf.allDay,
          gcalCalendarId: c.id,
          gcalId: rf.gcalId,
          dirty: false, // 원격에서 온 것 → 되밀지 않음
        );
      } else {
        if (local.dirty) continue; // 로컬 우선 — push 가 처리
        await gcalRepo.applyRemoteUpdate(
          local.id,
          calendarId: c.id,
          gcalId: rf.gcalId,
          date: rf.date,
          endDate: rf.endDate,
          startMin: rf.startMin,
          endMin: rf.endMin,
          allDay: rf.allDay,
          title: rf.title,
          note: rf.note,
        );
      }
    }

    // 원격에서 삭제된 것 정리 — 창 안에 있는데 이번 pull 에 안 보이면 삭제로 간주.
    final localSynced = await gcalRepo.syncedSchedulesForCalendar(c.id);
    for (final s in localSynced) {
      final d = dateOnly(s.date);
      if (d.isBefore(start) || d.isAfter(end)) continue; // 창 밖은 판단 보류
      if (s.gcalId != null && !seen.contains(s.gcalId)) {
        await gcalRepo.purge(s.id);
      }
    }
  }

  /// 새 일정을 밀 기본 캘린더 — 선택된 것 중 쓰기 가능(writer/owner) 우선,
  /// 주 캘린더 우선.
  Future<String?> _defaultWritableCalendarId() async {
    final cals = await gcalRepo.selectedCalendars();
    if (cals.isEmpty) return null;
    final writable = cals
        .where((c) => c.accessRole == 'writer' || c.accessRole == 'owner')
        .toList();
    final pool = writable.isNotEmpty ? writable : cals;
    pool.sort((a, b) => (b.primaryCal ? 1 : 0) - (a.primaryCal ? 1 : 0));
    return pool.first.id;
  }
}
