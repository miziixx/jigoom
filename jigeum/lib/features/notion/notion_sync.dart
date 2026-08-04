import 'package:flutter/foundation.dart';

import '../../core/notion/notion_client.dart';
import '../../data/repos/notion_repository.dart';
import 'notion_mapper.dart';

/// 한 번에 밀 레코드 하나 — upsert 키·속성·유효 시각(워터마크 계산용).
class _Item {
  const _Item(this.jigeumId, this.props, this.at);
  final String jigeumId;
  final Map<String, dynamic> props;
  final DateTime at;
}

/// 로컬 기록 → 노션 단방향 push 엔진. gcal 의 [GcalSync] 에 대응한다.
///
/// 유형별로: (1) 노션 DB 가 없으면 만들고 → (2) 워터마크 이후 변경된 레코드만
/// [JigeumId] 로 upsert → (3) 성공분까지 워터마크를 전진. 실패는 다음번에 재시도
/// (upsert 라 중복 없이 갱신). 실패해도 예외를 던지지 않는다(gcal 과 동일).
class NotionSync {
  NotionSync(this.client, this.repo);

  final NotionClient client;
  final NotionRepository repo;

  Future<void> run() async {
    if (!client.usable) return;
    try {
      final parent = await repo.parentPageId();
      if (parent == null || parent.trim().isEmpty) return;
      for (final t in NotionSyncType.values) {
        if (!await repo.isTypeEnabled(t)) continue;
        await _syncType(t, parent);
      }
    } catch (e, s) {
      debugPrint('notion sync 실패(무시): $e\n$s');
    }
  }

  Future<void> _syncType(NotionSyncType t, String parentPageId) async {
    final databaseId = await _ensureDatabase(t, parentPageId);
    if (databaseId == null) return; // DB 준비 실패 → 다음에 재시도

    final since = await repo.watermark(t);
    final items = await _changedItems(t, since);
    if (items.isEmpty) return;

    // 오래된 것부터 밀어 워터마크가 자연스럽게 앞으로 가게 한다.
    items.sort((a, b) => a.at.compareTo(b.at));

    DateTime overallMax = since ?? DateTime.fromMillisecondsSinceEpoch(0);
    DateTime? earliestFailure;
    for (final it in items) {
      if (it.at.isAfter(overallMax)) overallMax = it.at;
      final ok = await _upsert(databaseId, it.jigeumId, it.props);
      if (!ok) {
        earliestFailure ??= it.at;
      }
    }

    // 실패가 있으면 그 지점 직전까지만 전진(실패분·그 이후는 다음에 재시도).
    final next = earliestFailure != null
        ? earliestFailure.subtract(const Duration(milliseconds: 1))
        : overallMax;
    if (since == null || next.isAfter(since)) {
      await repo.setWatermark(t, next);
    }
  }

  /// 유형별 노션 DB 확보 — 없으면 만들고 id 를 저장한다.
  Future<String?> _ensureDatabase(
      NotionSyncType t, String parentPageId) async {
    final existing = await repo.dbId(t);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final id = await client.createDatabase(
      parentPageId: parentPageId,
      title: '지금 · ${t.label}',
      properties: NotionMapper.schema(t),
    );
    if (id != null) await repo.setDbId(t, id);
    return id;
  }

  /// JigeumId 로 찾아 있으면 갱신, 없으면 생성.
  Future<bool> _upsert(
      String databaseId, String jigeumId, Map<String, dynamic> props) async {
    final pageId = await client.findPageByJigeumId(databaseId, jigeumId);
    if (pageId != null) {
      return client.updatePage(pageId: pageId, properties: props);
    }
    return client.createPage(databaseId: databaseId, properties: props);
  }

  /// 유형별 변경분 → 밀 항목 목록.
  Future<List<_Item>> _changedItems(NotionSyncType t, DateTime? since) async {
    switch (t) {
      case NotionSyncType.nodes:
        final rows = await repo.changedNodes(since);
        return [
          for (final n in rows)
            _Item(NotionMapper.nodeId(n), NotionMapper.nodeProps(n),
                n.updatedAt)
        ];
      case NotionSyncType.schedules:
        final rows = await repo.changedSchedules(since);
        return [
          for (final s in rows)
            _Item(NotionMapper.scheduleId(s), NotionMapper.scheduleProps(s),
                s.updatedAt ?? s.createdAt)
        ];
      case NotionSyncType.habits:
        final rows = await repo.changedHabits(since);
        return [
          for (final h in rows)
            _Item(NotionMapper.habitId(h), NotionMapper.habitProps(h),
                h.createdAt)
        ];
      case NotionSyncType.timeBlocks:
        final rows = await repo.changedTimeBlocks(since);
        return [
          for (final b in rows)
            _Item(NotionMapper.timeBlockId(b), NotionMapper.timeBlockProps(b),
                b.updatedAt ?? b.date)
        ];
    }
  }
}
