/// 영속 보류함 저장소. [InboxRepository] 의 동기 인터페이스는 그대로 두고,
/// 실제 저장은 drift `Settings` kv 테이블에 JSON 배열로 write-through 한다.
///
/// 인메모리 캐시(`_items`)가 동기 읽기의 단일 출처다. 앱 시작 시 DB에서 한 번
/// 비동기로 읽어와 캐시에 병합하고, 이후 모든 변경은 캐시를 즉시 갱신한 뒤
/// 비동기로 저장(fire-and-forget)한다. 로드가 끝나면 [notifyListeners] 로
/// 화면(보류함)이 갱신되게 한다.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/db.dart';
import 'inbox_item.dart';
import 'inbox_repository.dart';

const _uuid = Uuid();

class PersistentInboxRepository extends ChangeNotifier
    implements InboxRepository {
  PersistentInboxRepository(this._db) {
    _load();
  }

  final AppDatabase _db;

  /// kv 저장 키(스키마 버전 태그 포함 — 향후 마이그레이션 여지).
  static const _key = 'inbox_items_v1';

  /// 동기 읽기의 단일 출처(생성 오름차순 유지, list()에서 뒤집어 최신순).
  final List<InboxItem> _items = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> _load() async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.key.equals(_key)))
        .getSingleOrNull();
    if (row != null && row.value.isNotEmpty) {
      try {
        final decoded = jsonDecode(row.value) as List<dynamic>;
        final loaded = decoded
            .map((e) => InboxItem.fromJson(e as Map<String, dynamic>))
            .toList();
        // 로드 중에 이미 담긴 항목이 있으면(경합) id 중복은 피하고 병합.
        final existing = _items.map((i) => i.id).toSet();
        _items.addAll(loaded.where((i) => !existing.contains(i.id)));
        _items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } catch (_) {
        // 손상된 값은 무시 — 다음 저장 때 덮어쓴다.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// 캐시를 통째로 JSON 직렬화해 kv 에 저장(write-through, fire-and-forget).
  Future<void> _persist() async {
    final json = jsonEncode(_items.map((i) => i.toJson()).toList());
    await _db.into(_db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: _key, value: json));
  }

  @override
  InboxItem add(String rawText, {double? sttConfidence, DateTime? at}) {
    final item = InboxItem(
      id: _uuid.v4(),
      rawText: rawText,
      createdAt: at ?? DateTime.now(),
      sttConfidence: sttConfidence,
    );
    _items.add(item);
    _persist();
    notifyListeners();
    return item;
  }

  @override
  List<InboxItem> list({InboxStatus? status}) {
    final filtered =
        status == null ? _items : _items.where((i) => i.status == status);
    // 최신순(생성 역순).
    return filtered.toList().reversed.toList();
  }

  @override
  int get pendingCount =>
      _items.where((i) => i.status == InboxStatus.pending).length;

  @override
  InboxItem? markReclassified(String id) =>
      _update(id, InboxStatus.reclassified);

  @override
  InboxItem? dismiss(String id) => _update(id, InboxStatus.dismissed);

  @override
  bool remove(String id) {
    final before = _items.length;
    _items.removeWhere((i) => i.id == id);
    final changed = _items.length != before;
    if (changed) {
      _persist();
      notifyListeners();
    }
    return changed;
  }

  InboxItem? _update(String id, InboxStatus status) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return null;
    final updated = _items[idx].copyWith(status: status);
    _items[idx] = updated;
    _persist();
    notifyListeners();
    return updated;
  }
}
