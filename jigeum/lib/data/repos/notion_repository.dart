import 'package:drift/drift.dart';

import '../db.dart';

/// 노션에 내보낼 기록 유형. 각 유형 = 노션 데이터베이스 1개로 매핑된다.
enum NotionSyncType {
  nodes('nodes', '할 일·목표·메모'),
  schedules('schedules', '일정'),
  habits('habits', '습관'),
  timeBlocks('timeBlocks', '타임트래커');

  const NotionSyncType(this.key, this.label);

  /// Settings kv·노션 DB 제목에 쓰는 안정적 키.
  final String key;

  /// 설정 화면 표시 이름.
  final String label;
}

/// 노션 연동 설정(토큰·부모 페이지·유형별 on/off·DB id·워터마크)과
/// "무엇을 밀지"(변경분 조회)를 담당하는 저장소.
///
/// 새 Drift 테이블을 추가하지 않으려고 모든 설정을 기존 [Settings] key-value 에
/// 저장한다. gcal 의 [GcalRepository] 에 대응한다.
class NotionRepository {
  NotionRepository(this.db);

  final AppDatabase db;

  // ---- kv 키 ----
  static const _kToken = 'notion.token';
  static const _kParentPage = 'notion.parentPage';
  static const _kAutoShare = 'notion.autoShare';
  static String _kEnabled(NotionSyncType t) => 'notion.enabled.${t.key}';
  static String _kDbId(NotionSyncType t) => 'notion.db.${t.key}';
  static String _kWatermark(NotionSyncType t) => 'notion.watermark.${t.key}';

  // ---- 저수준 kv (settings_controller 와 동일 패턴) ----
  Future<String?> _get(String key) async {
    final row = await (db.select(db.settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _set(String key, String value) async {
    await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value));
  }

  Future<void> _delete(String key) async {
    await (db.delete(db.settings)..where((s) => s.key.equals(key))).go();
  }

  // ---- 연결 설정 ----
  Future<String?> token() => _get(_kToken);
  Future<String?> parentPageId() => _get(_kParentPage);

  Future<bool> isConfigured() async {
    final tk = await token();
    final pp = await parentPageId();
    return (tk != null && tk.trim().isNotEmpty) &&
        (pp != null && pp.trim().isNotEmpty);
  }

  Future<void> saveConnection(
      {required String token, required String parentPageId}) async {
    await _set(_kToken, token.trim());
    await _set(_kParentPage, _normalizePageId(parentPageId));
  }

  /// 연동 끄기 — 토큰·페이지·DB 매핑·워터마크를 모두 지운다(노션 쪽은 안 건드림).
  Future<void> clear() async {
    await _delete(_kToken);
    await _delete(_kParentPage);
    await _delete(_kAutoShare);
    for (final t in NotionSyncType.values) {
      await _delete(_kEnabled(t));
      await _delete(_kDbId(t));
      await _delete(_kWatermark(t));
    }
  }

  // ---- 실시간 자동 공유 마스터 스위치 ----
  Future<bool> autoShare() async => (await _get(_kAutoShare)) == '1';
  Future<void> setAutoShare(bool v) => _set(_kAutoShare, v ? '1' : '0');

  // ---- 유형별 on/off ----
  /// 기본값: 할 일·일정은 켜짐, 나머지는 꺼짐.
  Future<bool> isTypeEnabled(NotionSyncType t) async {
    final v = await _get(_kEnabled(t));
    if (v == null) {
      return t == NotionSyncType.nodes || t == NotionSyncType.schedules;
    }
    return v == '1';
  }

  Future<void> setTypeEnabled(NotionSyncType t, bool v) =>
      _set(_kEnabled(t), v ? '1' : '0');

  // ---- 유형별 노션 DB id ----
  Future<String?> dbId(NotionSyncType t) => _get(_kDbId(t));
  Future<void> setDbId(NotionSyncType t, String id) => _set(_kDbId(t), id);

  // ---- 유형별 워터마크(이 시각 이후 변경분만 push) ----
  Future<DateTime?> watermark(NotionSyncType t) async {
    final v = await _get(_kWatermark(t));
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  Future<void> setWatermark(NotionSyncType t, DateTime at) =>
      _set(_kWatermark(t), at.toIso8601String());

  // ---- 변경분 조회 (워터마크보다 나중에 바뀐 레코드만) ----
  /// 워터마크가 null 이면 전부(첫 동기화) 반환. 유효 시각(effective time)이
  /// 워터마크보다 큰 것만 남긴다. 개인용 데이터라 전량 로드 후 Dart 필터로 충분.
  Future<List<Node>> changedNodes(DateTime? since) async {
    final rows = await db.select(db.nodes).get();
    return _after(rows, since, (n) => n.updatedAt);
  }

  Future<List<Schedule>> changedSchedules(DateTime? since) async {
    final rows = await db.select(db.schedules).get();
    return _after(rows, since, (s) => s.updatedAt ?? s.createdAt);
  }

  Future<List<Habit>> changedHabits(DateTime? since) async {
    final rows = await db.select(db.habits).get();
    return _after(rows, since, (h) => h.createdAt);
  }

  Future<List<TimeBlock>> changedTimeBlocks(DateTime? since) async {
    final rows = await db.select(db.timeBlocks).get();
    return _after(rows, since, (t) => t.updatedAt ?? t.date);
  }

  List<T> _after<T>(List<T> rows, DateTime? since, DateTime Function(T) at) {
    if (since == null) return rows;
    return [
      for (final r in rows)
        if (at(r).isAfter(since)) r
    ];
  }

  /// 부모 페이지 URL 또는 32자 hex 를 대시 있는 UUID 로 정규화.
  /// Notion 은 하이픈 유무 모두 받지만 붙여 저장해 일관성을 둔다.
  static String _normalizePageId(String raw) {
    var s = raw.trim();
    // URL 이면 마지막 조각에서 32-hex 를 추출.
    final hex = RegExp(r'[0-9a-fA-F]{32}').firstMatch(s.replaceAll('-', ''));
    if (hex != null) {
      final h = hex.group(0)!.toLowerCase();
      return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
          '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
    }
    return s;
  }
}
