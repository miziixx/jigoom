import 'folder.dart';
import 'memo.dart';

/// Single object that bundles every callback MemoTile, CalendarView,
/// and StatsView need. Create one instance in HomeScreen and pass it
/// everywhere — no more per-view wiring.
class MemoActions {
  final List<Folder> folders;
  final void Function(Memo) onDelete;
  final void Function(Memo) onEditRequest;
  final void Function(Memo, String) onUpdate;
  final void Function(Memo, String?) onMove;
  final void Function(
    Memo,
    DateTime?,
    String repeat,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  )
  onSetReminder;
  final void Function(
    Memo,
    DateTime?,
    String scheduleRepeat,
    DateTime? rangeEndDate,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  )
  onSetSchedule;
  final void Function(Memo, String) onAddNote;
  final void Function(Memo, int, String) onUpdateNote;
  final void Function(Memo, int) onDeleteNote;
  final void Function(Memo dragged, Memo target) onMerge;
  final void Function(Memo, String) onAddImage;
  final void Function(Memo, int) onDeleteImage;
  final void Function(String tag)? onTagTap;
  final void Function(String linkText)? onWikiLinkTap;
  final void Function(String memoId)? onNavigateToMemo;

  const MemoActions({
    required this.folders,
    required this.onDelete,
    required this.onEditRequest,
    required this.onUpdate,
    required this.onMove,
    required this.onSetReminder,
    required this.onSetSchedule,
    required this.onAddNote,
    required this.onUpdateNote,
    required this.onDeleteNote,
    required this.onMerge,
    required this.onAddImage,
    required this.onDeleteImage,
    this.onTagTap,
    this.onWikiLinkTap,
    this.onNavigateToMemo,
  });

  MemoActions copyWith({
    List<Folder>? folders,
    void Function(Memo)? onDelete,
    void Function(Memo)? onEditRequest,
    void Function(Memo, String)? onUpdate,
    void Function(Memo, String?)? onMove,
    void Function(
      Memo,
      DateTime?,
      String repeat,
      String repeatEndType,
      int repeatEndCount,
      DateTime? repeatEndDate,
    )?
    onSetReminder,
    void Function(
      Memo,
      DateTime?,
      String scheduleRepeat,
      DateTime? rangeEndDate,
      String repeatEndType,
      int repeatEndCount,
      DateTime? repeatEndDate,
    )?
    onSetSchedule,
    void Function(Memo, String)? onAddNote,
    void Function(Memo, int, String)? onUpdateNote,
    void Function(Memo, int)? onDeleteNote,
    void Function(Memo dragged, Memo target)? onMerge,
    void Function(Memo, String)? onAddImage,
    void Function(Memo, int)? onDeleteImage,
    void Function(String tag)? onTagTap,
    void Function(String linkText)? onWikiLinkTap,
    void Function(String memoId)? onNavigateToMemo,
  }) => MemoActions(
    folders: folders ?? this.folders,
    onDelete: onDelete ?? this.onDelete,
    onEditRequest: onEditRequest ?? this.onEditRequest,
    onUpdate: onUpdate ?? this.onUpdate,
    onMove: onMove ?? this.onMove,
    onSetReminder: onSetReminder ?? this.onSetReminder,
    onSetSchedule: onSetSchedule ?? this.onSetSchedule,
    onAddNote: onAddNote ?? this.onAddNote,
    onUpdateNote: onUpdateNote ?? this.onUpdateNote,
    onDeleteNote: onDeleteNote ?? this.onDeleteNote,
    onMerge: onMerge ?? this.onMerge,
    onAddImage: onAddImage ?? this.onAddImage,
    onDeleteImage: onDeleteImage ?? this.onDeleteImage,
    onTagTap: onTagTap ?? this.onTagTap,
    onWikiLinkTap: onWikiLinkTap ?? this.onWikiLinkTap,
    onNavigateToMemo: onNavigateToMemo ?? this.onNavigateToMemo,
  );
}
