/// 보류함 저장소. 기획서 §5 커밋9 + §7.
///
/// 저장/목록/재분류 이동/버리기를 정의한다. 실제 영속화(앱 저장소 연동)는
/// 구현체가 담당하고, 여기 [InMemoryInboxRepository] 는 순수 Dart 인메모리
/// 구현으로 로직을 단위 테스트한다.
///
/// 프레임워크 비의존(순수 Dart).
library;

import 'inbox_item.dart';

/// 보류함 저장소 인터페이스.
abstract class InboxRepository {
  /// 원문을 보류함에 담고 생성된 항목을 돌려준다.
  InboxItem add(String rawText, {double? sttConfidence, DateTime? at});

  /// 항목 목록. [status] 를 주면 그 상태만, 없으면 전체(최신순).
  List<InboxItem> list({InboxStatus? status});

  /// 아직 정리 안 된(pending) 항목 수 — §9 보류함 뱃지용.
  int get pendingCount;

  /// 한 건을 다른 입력지점으로 재분류 처리했다고 표시.
  InboxItem? markReclassified(String id);

  /// 한 건을 버림(무시) 처리.
  InboxItem? dismiss(String id);

  /// 완전 삭제.
  bool remove(String id);
}

/// 인메모리 구현(테스트·초기값). 순수 Dart라 프레임워크 없이 검증된다.
class InMemoryInboxRepository implements InboxRepository {
  InMemoryInboxRepository();

  final List<InboxItem> _items = [];
  int _seq = 0;

  @override
  InboxItem add(String rawText, {double? sttConfidence, DateTime? at}) {
    final item = InboxItem(
      id: 'ibx_${_seq++}',
      rawText: rawText,
      createdAt: at ?? DateTime.now(),
      sttConfidence: sttConfidence,
    );
    _items.add(item);
    return item;
  }

  @override
  List<InboxItem> list({InboxStatus? status}) {
    final filtered = status == null
        ? _items
        : _items.where((i) => i.status == status);
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
    return _items.length != before;
  }

  InboxItem? _update(String id, InboxStatus status) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return null;
    final updated = _items[idx].copyWith(status: status);
    _items[idx] = updated;
    return updated;
  }
}
