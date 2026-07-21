import 'package:drift/drift.dart';

import '../../core/constants.dart';
import '../db.dart';

/// 타임트래커: 하루 30분 단위(0~47) 기록.
class TimeTrackRepository {
  TimeTrackRepository(this.db);

  final AppDatabase db;

  /// 지금 시각의 블록 번호 (0~47).
  static int blockOfNow([DateTime? now]) {
    final n = now ?? DateTime.now();
    return (n.hour * 60 + n.minute) ~/ 30;
  }

  Stream<List<TimeBlock>> watchForDate(DateTime date) {
    final d = dateOnly(date);
    final q = db.select(db.timeBlocks)
      ..where((t) => t.date.equals(d))
      ..orderBy([(t) => OrderingTerm.asc(t.block)]);
    return q.watch();
  }

  Future<TimeBlock?> getBlock(DateTime date, int block) {
    return (db.select(db.timeBlocks)
          ..where((t) => t.date.equals(dateOnly(date)) & t.block.equals(block)))
        .getSingleOrNull();
  }

  /// 블록 저장. 빈 문자열이면 삭제.
  Future<void> setBlock(DateTime date, int block, String text) async {
    final d = dateOnly(date);
    final t = text.trim();
    if (t.isEmpty) {
      await (db.delete(db.timeBlocks)
            ..where((x) => x.date.equals(d) & x.block.equals(block)))
          .go();
      return;
    }
    await db.into(db.timeBlocks).insertOnConflictUpdate(
        TimeBlocksCompanion.insert(date: d, block: block, text: t));
  }
}
