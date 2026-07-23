import 'package:flutter/foundation.dart';

import '../../core/gcal/gcal_api.dart';
import '../../core/gcal/gcal_mapper.dart';
import '../../data/db.dart';
import '../../data/repos/gcal_repository.dart';
import '../../data/repos/schedule_repository.dart';

/// 로컬 일정 ↔ 구글 캘린더 양방향 동기화 엔진.
///
/// 순서: (1) 로컬 변경(dirty)을 원격에 push → (2) 선택된 캘린더별로 원격 변경을
/// 증분 pull. 충돌은 "로컬이 dirty 면 로컬 우선(push 가 처리), 아니면 원격 반영"
/// 규칙으로 해소한다. 원격 신규는 로컬 일정으로 추가되어 앱·위젯에 나타난다.
class GcalSync {
  GcalSync(this.api, this.gcalRepo, this.scheduleRepo);

  final GcalApi api;
  final GcalRepository gcalRepo;
  final ScheduleRepository scheduleRepo;

  /// 원격에서 처음 당겨올 과거 범위(전체 동기화 시). 너무 옛날 일정 방지.
  static const _pullBack = Duration(days: 60);

  /// 한 번의 완전한 동기화. 실패해도 예외를 던지지 않고 삼킨다.
  Future<void> run() async {
    try {
      await _push();
      final cals = await gcalRepo.selectedCalendars();
      for (final c in cals) {
        await _pullCalendar(c);
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
      if (calId == null) continue; // 밀 대상 캘린더가 없음 → 다음 기회로 보류

      try {
        if (s.deleted) {
          if (s.gcalId != null) await api.delete(calId, s.gcalId!);
          await gcalRepo.purge(s.id);
          continue;
        }
        final body = GcalMapper.toEvent(s);
        if (s.gcalId == null) {
          final created = await api.insert(calId, body);
          if (created?.id != null) {
            await gcalRepo.markPushed(s.id,
                gcalId: created!.id!, etag: created.etag, calendarId: calId);
          }
        } else {
          final updated = await api.patch(calId, s.gcalId!, body);
          await gcalRepo.markPushed(s.id,
              gcalId: s.gcalId!, etag: updated?.etag, calendarId: calId);
        }
      } catch (e) {
        debugPrint('gcal push 실패(${s.id}) — 다음에 재시도: $e');
      }
    }
  }

  Future<void> _pullCalendar(GcalCalendar c) async {
    final GcalPull pull;
    try {
      pull = await api.pull(c.id,
          syncToken: c.syncToken,
          timeMin: DateTime.now().subtract(_pullBack));
    } catch (e) {
      debugPrint('gcal pull 실패(${c.id}): $e');
      return;
    }

    for (final ev in pull.events) {
      final rf = GcalMapper.fromEvent(ev);
      if (rf == null) continue;
      final local = await gcalRepo.scheduleByGcalId(rf.gcalId);

      if (rf.cancelled) {
        await gcalRepo.deleteByGcalId(rf.gcalId);
        continue;
      }
      if (local == null) {
        await scheduleRepo.addSchedule(
          date: rf.date,
          title: rf.title,
          note: rf.note,
          startMin: rf.startMin,
          endMin: rf.endMin,
          allDay: rf.allDay,
          gcalCalendarId: c.id,
          gcalId: rf.gcalId,
          gcalEtag: rf.etag,
          dirty: false, // 원격에서 온 것 → 되밀지 않음
        );
      } else {
        if (local.dirty) continue; // 로컬 우선 — push 가 처리
        await gcalRepo.applyRemoteUpdate(
          local.id,
          calendarId: c.id,
          gcalId: rf.gcalId,
          etag: rf.etag,
          date: rf.date,
          startMin: rf.startMin,
          endMin: rf.endMin,
          allDay: rf.allDay,
          title: rf.title,
          note: rf.note,
        );
      }
    }

    if (pull.nextSyncToken != null) {
      await gcalRepo.setSyncToken(c.id, pull.nextSyncToken);
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
