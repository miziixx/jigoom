import 'folder.dart';
import 'memo.dart';

/// Single object that bundles every callback MemoTile, CalendarView,
/// and StatsView need. Create one instance in HomeScreen and pass it
/// everywhere — no more per-view wiring.
class MemoActions {
  final List<Folder> folders;
  final void Function(Memo) onDelete;
  final void Function(Memo, String) onUpdate;
  final void Function(Memo, String?) onMove;
  final void Function(
    Memo,
    DateTime?,
    String repeat,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  ) onSetReminder;
  final void Function(
    Memo,
    DateTime?,
    String scheduleRepeat,
    DateTime? rangeEndDate,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  ) onSetSchedule;
  final void Function(Memo, String) onAddNote;
  final void Function(Memo, int, String) onUpdateNote;
  final void Function(Memo, int) onDeleteNote;
  final void Function(Memo dragged, Memo target) onMerge;
  final void Function(Memo, String) onAddImage;
  final void Function(String tag)? onTagTap;

  const MemoActions({
    required this.folders,
    required this.onDelete,
    required this.onUpdate,
    required this.onMove,
    required this.onSetReminder,
    required this.onSetSchedule,
    required this.onAddNote,
    required this.onUpdateNote,
    required this.onDeleteNote,
    required this.onMerge,
    required this.onAddImage,
    this.onTagTap,
  });
}
