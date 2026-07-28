// 커밋9 보류함 데이터 계층 — 저장/목록/재분류/버리기/삭제 + 직렬화.
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/inbox/inbox_item.dart';
import 'package:jigeum/features/inbox/inbox_repository.dart';

void main() {
  late InMemoryInboxRepository repo;
  setUp(() => repo = InMemoryInboxRepository());

  test('담기 → pending 카운트/목록', () {
    final it = repo.add('어… 그거 뭐였지', sttConfidence: 0.4);
    expect(it.status, InboxStatus.pending);
    expect(it.rawText, '어… 그거 뭐였지');
    expect(repo.pendingCount, 1);
    expect(repo.list().single.id, it.id);
  });

  test('목록은 최신순', () {
    final a = repo.add('첫번째', at: DateTime(2026, 7, 24, 9));
    final b = repo.add('두번째', at: DateTime(2026, 7, 24, 10));
    expect(repo.list().map((e) => e.id).toList(), [b.id, a.id]);
  });

  test('재분류 처리하면 pending 에서 빠진다', () {
    final it = repo.add('장보기');
    final r = repo.markReclassified(it.id);
    expect(r!.status, InboxStatus.reclassified);
    expect(repo.pendingCount, 0);
    expect(repo.list(status: InboxStatus.reclassified).length, 1);
    expect(repo.list(status: InboxStatus.pending), isEmpty);
  });

  test('버리기 → dismissed', () {
    final it = repo.add('무시할 말');
    expect(repo.dismiss(it.id)!.status, InboxStatus.dismissed);
    expect(repo.pendingCount, 0);
  });

  test('삭제', () {
    final it = repo.add('삭제 대상');
    expect(repo.remove(it.id), isTrue);
    expect(repo.list(), isEmpty);
    expect(repo.remove('없는id'), isFalse);
  });

  test('없는 id 재분류는 null', () {
    expect(repo.markReclassified('nope'), isNull);
  });

  test('JSON 왕복', () {
    final it = InboxItem(
      id: 'ibx_1',
      rawText: '보험료 9만원',
      createdAt: DateTime(2026, 7, 24, 12, 30),
      sttConfidence: 0.8,
      status: InboxStatus.reclassified,
    );
    final back = InboxItem.fromJson(it.toJson());
    expect(back.id, it.id);
    expect(back.rawText, it.rawText);
    expect(back.createdAt, it.createdAt);
    expect(back.sttConfidence, 0.8);
    expect(back.status, InboxStatus.reclassified);
  });
}
