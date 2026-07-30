import 'package:drift/drift.dart';

import '../db.dart';

/// 구글 캘린더 목록 + 일정 동기화 상태 저장소.
class GcalRepository {
  GcalRepository(this.db);

  final AppDatabase db;

  // ---------------------------------------------------------- 캘린더 목록
  Stream<List<GcalCalendar>> watchCalendars() {
    return (db.select(db.gcalCalendars)
          ..orderBy([
            // 숨긴 캘린더는 (편집 모드에서) 목록 맨 아래로.
            (c) => OrderingTerm.asc(c.hidden),
            (c) => OrderingTerm.desc(c.primaryCal),
            (c) => OrderingTerm.asc(c.summary),
          ]))
        .watch();
  }

  Future<List<GcalCalendar>> allCalendars() =>
      db.select(db.gcalCalendars).get();

  Future<List<GcalCalendar>> selectedCalendars() =>
      (db.select(db.gcalCalendars)..where((c) => c.selected.equals(true)))
          .get();

  Future<GcalCalendar?> calendar(String id) =>
      (db.select(db.gcalCalendars)..where((c) => c.id.equals(id)))
          .getSingleOrNull();

  /// 구글에서 받은 목록으로 로컬 목록을 갱신.
  /// 사용자가 고른 [selected] 와 [syncToken] 은 보존한다(이름·색·권한만 갱신).
  /// 처음 보는 캘린더는 내 캘린더(주 캘린더 또는 소유 권한)를 기본 선택 —
  /// 안드로이드의 IS_PRIMARY 플래그가 비어 있는 기기가 많아 주 캘린더만 켜면
  /// 아무 일정도 안 딸려오는 문제가 생겨서, 소유(owner) 권한까지 켠다.
  Future<void> upsertFromRemote(List<RemoteCalendar> items) async {
    final existing = {for (final c in await allCalendars()) c.id: c};
    final seen = <String>{};
    for (final it in items) {
      seen.add(it.id);
      final prev = existing[it.id];
      if (prev == null) {
        await db.into(db.gcalCalendars).insert(GcalCalendarsCompanion.insert(
              id: it.id,
              summary: it.summary,
              colorHex: Value(it.colorHex),
              // 기본: 내 캘린더(주 캘린더 or 소유 권한) on.
              selected: Value(it.primary || it.accessRole == 'owner'),
              primaryCal: Value(it.primary),
              accessRole: Value(it.accessRole),
            ));
      } else {
        await (db.update(db.gcalCalendars)..where((c) => c.id.equals(it.id)))
            .write(GcalCalendarsCompanion(
          summary: Value(it.summary),
          colorHex: Value(it.colorHex),
          primaryCal: Value(it.primary),
          accessRole: Value(it.accessRole),
        ));
      }
    }
    // 구글에서 사라진 캘린더는 로컬에서도 제거.
    for (final id in existing.keys) {
      if (!seen.contains(id)) {
        await (db.delete(db.gcalCalendars)..where((c) => c.id.equals(id))).go();
      }
    }
  }

  Future<void> setSelected(String id, bool selected) async {
    await (db.update(db.gcalCalendars)..where((c) => c.id.equals(id))).write(
        GcalCalendarsCompanion(
            selected: Value(selected),
            // 동기화 껐다 켜면 다음번 전체 동기화(토큰 리셋).
            syncToken:
                selected ? const Value.absent() : const Value<String?>(null)));
  }

  /// 목록에서 캘린더 숨김/보임 토글(편집).
  Future<void> setHidden(String id, bool hidden) async {
    await (db.update(db.gcalCalendars)..where((c) => c.id.equals(id)))
        .write(GcalCalendarsCompanion(hidden: Value(hidden)));
  }

  Future<void> setSyncToken(String id, String? token) async {
    await (db.update(db.gcalCalendars)..where((c) => c.id.equals(id)))
        .write(GcalCalendarsCompanion(syncToken: Value(token)));
  }

  Future<void> clearAllCalendars() async {
    await db.delete(db.gcalCalendars).go();
  }

  // ---------------------------------------------------------- 일정 동기화
  /// 원격에 밀어야 할(dirty) 일정 — 생성/수정/삭제 툼스톤 포함.
  Future<List<Schedule>> dirtySchedules() =>
      (db.select(db.schedules)..where((s) => s.dirty.equals(true))).get();

  Future<Schedule?> scheduleByGcalId(String gcalId) =>
      (db.select(db.schedules)..where((s) => s.gcalId.equals(gcalId)))
          .getSingleOrNull();

  /// 한 캘린더에 동기화된(원격 연결·dirty 아님) 로컬 일정 — 원격 삭제 감지용.
  Future<List<Schedule>> syncedSchedulesForCalendar(String calendarId) =>
      (db.select(db.schedules)
            ..where((s) =>
                s.gcalCalendarId.equals(calendarId) &
                s.gcalId.isNotNull() &
                s.dirty.equals(false) &
                s.deleted.equals(false)))
          .get();

  /// push 성공 → dirty 해제 + 원격 식별자 저장.
  Future<void> markPushed(String id,
      {required String gcalId, String? etag, String? calendarId}) async {
    await (db.update(db.schedules)..where((s) => s.id.equals(id))).write(
        SchedulesCompanion(
      gcalId: Value(gcalId),
      gcalEtag: Value(etag),
      gcalCalendarId:
          calendarId == null ? const Value.absent() : Value(calendarId),
      dirty: const Value(false),
    ));
  }

  /// 삭제 툼스톤을 원격까지 반영 완료 → 로컬 행 제거.
  Future<void> purge(String id) async {
    await (db.delete(db.schedules)..where((s) => s.id.equals(id))).go();
  }

  /// 캘린더 동기화 해제 시 그 캘린더에서 온 일정을 로컬에서 제거(안 보이게).
  /// 로컬에서 편집한(dirty) 건은 보존 — 실수로 내 수정본을 잃지 않도록.
  Future<void> deleteSyncedForCalendar(String calendarId) async {
    await (db.delete(db.schedules)
          ..where((s) =>
              s.gcalCalendarId.equals(calendarId) & s.dirty.equals(false)))
        .go();
  }

  /// 원격에서 받은 이벤트를 로컬에 반영(신규 insert 는 repo 밖에서 처리).
  Future<void> applyRemoteUpdate(
    String scheduleId, {
    required String calendarId,
    required String gcalId,
    String? etag,
    required DateTime date,
    DateTime? endDate,
    required int startMin,
    required int endMin,
    required bool allDay,
    required String title,
    required String note,
  }) async {
    await (db.update(db.schedules)..where((s) => s.id.equals(scheduleId)))
        .write(SchedulesCompanion(
      gcalCalendarId: Value(calendarId),
      gcalId: Value(gcalId),
      gcalEtag: Value(etag),
      date: Value(date),
      endDate: Value(endDate),
      startMin: Value(startMin),
      endMin: Value(endMin),
      allDay: Value(allDay),
      title: Value(title),
      note: Value(note),
      dirty: const Value(false),
      deleted: const Value(false),
    ));
  }

  /// 원격에서 삭제된 이벤트 → 로컬 행 제거(로컬이 dirty 가 아니면).
  Future<void> deleteByGcalId(String gcalId) async {
    await (db.delete(db.schedules)
          ..where((s) => s.gcalId.equals(gcalId) & s.dirty.equals(false)))
        .go();
  }

  /// 같은 gcalId 중복 행 정리(→ [dedupeGcalSchedules]).
  Future<int> dedupeByGcalId() => dedupeGcalSchedules(db);
}

/// 같은 구글 이벤트(gcalId)가 로컬에 여러 행으로 있으면 하나만 남기고 나머지
/// 로컬 행을 제거한다(원격은 건드리지 않음). 백업 "합치기(merge)" 복원이 같은
/// 일정을 다른 로컬 id 로 다시 넣어 생기는 중복을 정리하는 용도.
/// 보존 우선순위: dirty(로컬 편집/삭제 툼스톤) > 최신 updatedAt/createdAt.
Future<int> dedupeGcalSchedules(AppDatabase db) async {
  final rows = await (db.select(db.schedules)
        ..where((s) => s.gcalId.isNotNull()))
      .get();
  final byGid = <String, List<Schedule>>{};
  for (final s in rows) {
    (byGid[s.gcalId!] ??= <Schedule>[]).add(s);
  }
  var removed = 0;
  for (final group in byGid.values) {
    if (group.length < 2) continue;
    final list = [...group]..sort((a, b) {
        if (a.dirty != b.dirty) return a.dirty ? -1 : 1; // 편집/툼스톤 보존
        final au = a.updatedAt ?? a.createdAt;
        final bu = b.updatedAt ?? b.createdAt;
        return bu.compareTo(au); // 최신 우선
      });
    for (final dup in list.skip(1)) {
      await (db.delete(db.schedules)..where((x) => x.id.equals(dup.id))).go();
      removed++;
    }
  }
  return removed;
}

/// 구글 캘린더 목록 항목(원격에서 받은 최소 표현).
class RemoteCalendar {
  const RemoteCalendar({
    required this.id,
    required this.summary,
    required this.colorHex,
    required this.primary,
    required this.accessRole,
  });
  final String id;
  final String summary;
  final String colorHex;
  final bool primary;
  final String accessRole;
}
