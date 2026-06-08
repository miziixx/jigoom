import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../flavor.dart';
import '../models/folder.dart';
import '../models/memo.dart';
import '../services/image_service.dart';
import 'schedule_sheet.dart';

enum _LogroomDraftKind { entry, task, event, habit, goal }

class _SuggestionChipData {
  final String label;
  final _LogroomDraftKind kind;

  const _SuggestionChipData(this.label, this.kind);
}

String _draftKindLabel(_LogroomDraftKind kind) {
  switch (kind) {
    case _LogroomDraftKind.task:
      return '□ 새 할일';
    case _LogroomDraftKind.event:
      return '△ 새 일정';
    case _LogroomDraftKind.habit:
      return '○ 새 습관';
    case _LogroomDraftKind.goal:
      return '◇ 새 목표';
    case _LogroomDraftKind.entry:
      return '● 새 기록';
  }
}

String _draftKindHint(_LogroomDraftKind kind) {
  switch (kind) {
    case _LogroomDraftKind.task:
      return '새 할일';
    case _LogroomDraftKind.event:
      return '새 일정';
    case _LogroomDraftKind.habit:
      return '새 습관';
    case _LogroomDraftKind.goal:
      return '새 목표';
    case _LogroomDraftKind.entry:
      return '새 기록';
  }
}

class InputBar extends StatefulWidget {
  final void Function(
    String content,
    bool isChecklist,
    DateTime? reminderAt,
    String? folderId,
    List<String> imagePaths,
    String reminderRepeat,
    DateTime? scheduledAt,
    // new fields
    DateTime? rangeEndDate,
    String scheduleRepeat,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  )
  onSubmit;
  final DateTime? initialDate;
  final List<Folder> folders;
  final String? currentFolderId;
  final bool scheduleMode;
  // Logroom habit/goal activation
  final bool habitActivated;
  final bool goalActivated;
  final int dayCount;
  final int streak;
  final void Function(String name)? onActivateHabit;
  final void Function(String name)? onActivateGoal;
  final Memo? editingMemo;
  final VoidCallback? onCancelEdit;

  const InputBar({
    super.key,
    required this.onSubmit,
    this.initialDate,
    this.folders = const [],
    this.currentFolderId,
    this.scheduleMode = false,
    this.habitActivated = true,
    this.goalActivated = true,
    this.dayCount = 0,
    this.streak = 0,
    this.onActivateHabit,
    this.onActivateGoal,
    this.editingMemo,
    this.onCancelEdit,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  // Reminder (alarm icon)
  DateTime? _reminderAt;
  String _reminderRepeat = 'none';
  String _reminderRepeatEndType = 'infinite';
  int _reminderRepeatEndCount = 5;
  DateTime? _reminderRepeatEndDate;
  // Schedule / event (calendar icon)
  DateTime? _scheduledAt;
  DateTime? _rangeEndDate;
  String _scheduleRepeat = 'none';
  String _scheduleRepeatEndType = 'infinite';
  int _scheduleRepeatEndCount = 5;
  DateTime? _scheduleRepeatEndDate;

  String? _selectedFolderId;
  final _pendingImages = <String>[];
  String? _editingSourceUrl;
  bool _forceChecklist = false;
  _LogroomDraftKind _draftKind = _LogroomDraftKind.entry;
  _LogroomDraftKind? _suggestionSelectedKind;
  String _prevText = '';
  bool _processingExcl = false;
  bool _schedulePickerOpened = false;
  bool _resettingDraft = false;

  static final _tagRe = RegExp(r'#([a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣][a-zA-Z0-9_ㄱ-ㅎㅏ-ㅣ가-힣]*)');

  List<String> get _tags => _tagRe
      .allMatches(_controller.text)
      .map((m) => m.group(1)!)
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  String _sourceEditText(Memo memo) {
    final sourceUrl = memo.sourceUrl;
    if (sourceUrl == null) return memo.content;
    final stripped = memo.content
        .replaceAll(sourceUrl, '')
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(_tagRe, '')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return stripped.isEmpty ? '' : memo.content;
  }

  String _linkLabel(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isEmpty ? url : uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.currentFolderId;
    _loadEditingMemo(widget.editingMemo);
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      setState(() {});
      if (widget.scheduleMode &&
          _focusNode.hasFocus &&
          _scheduledAt == null &&
          !_schedulePickerOpened) {
        _schedulePickerOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSchedulePicker();
        });
      }
    });
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            HardwareKeyboard.instance.isShiftPressed) {
          _submit();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void didUpdateWidget(covariant InputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingMemo?.id != widget.editingMemo?.id) {
      _loadEditingMemo(widget.editingMemo);
      if (widget.editingMemo != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showKeyboardNow();
        });
      }
    }
  }

  void _loadEditingMemo(Memo? memo) {
    if (memo == null) return;
    _editingSourceUrl = memo.sourceUrl;
    _controller.text = _sourceEditText(memo);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _selectedFolderId = memo.folderId;
    _pendingImages
      ..clear()
      ..addAll(memo.imagePaths);
    _reminderAt = memo.reminderAt;
    _reminderRepeat = memo.reminderRepeat;
    _scheduledAt = memo.scheduledAt;
    _rangeEndDate = memo.rangeEndDate;
    _scheduleRepeat = memo.scheduleRepeat;
    _scheduleRepeatEndType = memo.repeatEndType;
    _scheduleRepeatEndCount = memo.repeatEndCount;
    _scheduleRepeatEndDate = memo.repeatEndDate;
    _forceChecklist = memo.isChecklist;
    _draftKind = memo.isChecklist
        ? _LogroomDraftKind.task
        : (memo.tags.contains('habit')
              ? _LogroomDraftKind.habit
              : (memo.tags.contains('goal')
                    ? _LogroomDraftKind.goal
                    : (memo.scheduledAt != null
                          ? _LogroomDraftKind.event
                          : _LogroomDraftKind.entry)));
    _suggestionSelectedKind = null;
  }

  void _onTextChanged() {
    if (_resettingDraft) {
      _prevText = _controller.text;
      setState(() {});
      return;
    }
    if (_processingExcl) {
      setState(() {});
      return;
    }
    final newText = _controller.text;
    final hadTags = _tagRe.hasMatch(_prevText);
    if (_scheduledAt == null &&
        newText.contains('!') &&
        !_prevText.contains('!')) {
      _processingExcl = true;
      final excIdx = newText.indexOf('!');
      final cleaned = newText.replaceFirst('!', '');
      _controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(
          offset: excIdx.clamp(0, cleaned.length),
        ),
      );
      _processingExcl = false;
      _prevText = cleaned;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSchedulePicker();
      });
    } else {
      _prevText = newText;
    }
    final shouldClearSuggestion = _shouldClearSuggestionSelection(
      _controller.text,
    );
    final hasTags = _tagRe.hasMatch(_controller.text);
    final hadFocus = _focusNode.hasFocus;
    setState(() {
      if (shouldClearSuggestion) {
        _draftKind = _LogroomDraftKind.entry;
        _forceChecklist = false;
        _suggestionSelectedKind = null;
      }
      if (_controller.text.trim().isEmpty && widget.editingMemo == null) {
        _draftKind = _LogroomDraftKind.entry;
        _forceChecklist = false;
        _suggestionSelectedKind = null;
      }
    });
    // 태그 배지가 나타나면서 레이아웃이 변해 Android가 IME를 내리는 경우 방지.
    // hasFocus가 true인 상태에서도 키보드가 내려갈 수 있으므로
    // requestFocus + TextInput.show 를 조건 없이 호출해 키보드를 명시적으로 복구.
    if (hadFocus) _restoreInputFocus(extraDelayed: hasTags && !hadTags);
  }

  void _showSchedulePicker() {
    final previousScheduledAt = _scheduledAt;
    showScheduleSheet(
      context,
      mode: ScheduleSheetMode.event,
      current: _scheduledAt,
      rangeEndDate: _rangeEndDate,
      currentRepeat: _scheduleRepeat,
      repeatEndType: _scheduleRepeatEndType,
      repeatEndCount: _scheduleRepeatEndCount,
      repeatEndDate: _scheduleRepeatEndDate,
      initialNotifyForEvent: _isSameMinute(_reminderAt, _scheduledAt),
      onResult:
          (dt, repeat, rangeEnd, endType, endCount, endDate, notifyForEvent) {
            setState(() {
              _scheduledAt = dt;
              _rangeEndDate = rangeEnd;
              _scheduleRepeat = repeat;
              _scheduleRepeatEndType = endType;
              _scheduleRepeatEndCount = endCount;
              _scheduleRepeatEndDate = endDate;
              if (dt == null) {
                if (_isSameMinute(_reminderAt, previousScheduledAt)) {
                  _reminderAt = null;
                  _reminderRepeat = 'none';
                  _reminderRepeatEndType = 'infinite';
                  _reminderRepeatEndCount = 5;
                  _reminderRepeatEndDate = null;
                }
              } else if (notifyForEvent) {
                _reminderAt = dt;
                _reminderRepeat = 'none';
                _reminderRepeatEndType = 'infinite';
                _reminderRepeatEndCount = 5;
                _reminderRepeatEndDate = null;
              } else if (_isSameMinute(_reminderAt, previousScheduledAt)) {
                _reminderAt = null;
                _reminderRepeat = 'none';
                _reminderRepeatEndType = 'infinite';
                _reminderRepeatEndCount = 5;
                _reminderRepeatEndDate = null;
              }
            });
          },
    );
  }

  bool _isSameMinute(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  bool get _isChecklist {
    if (_forceChecklist || _draftKind == _LogroomDraftKind.task) return true;
    return _looksChecklist(_controller.text);
  }

  bool _looksChecklist(String value) {
    final lines = value.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return false;
    return lines.every(
      (l) =>
          l.startsWith('- [ ] ') ||
          l.startsWith('- [x] ') ||
          l.startsWith('• '),
    );
  }

  bool _hasChecklistMarker(String value) {
    return value
        .split('\n')
        .any((l) => l.startsWith('- [ ] ') || l.startsWith('- [x] '));
  }

  bool _textLooksChecklist(String value) {
    final lines = value.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return false;
    return lines.every(
      (l) =>
          l.startsWith('- [ ] ') ||
          l.startsWith('- [x] ') ||
          l.startsWith('• '),
    );
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  bool _hasMinimumSuggestionText(String text) {
    return text.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length >= 2;
  }

  bool _matchesSuggestionKind(String raw, _LogroomDraftKind kind) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty || !_hasMinimumSuggestionText(text)) return false;

    final schedule =
        _hasAny(text, const [
          '내일',
          '오늘',
          '다음주',
          '다음 주',
          '다음달',
          '다음 달',
          '예약',
          '약속',
          '병원',
          '회의',
          '방문',
          '오전',
          '오후',
        ]) ||
        RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(text) ||
        RegExp(r'\b\d{1,2}/\d{1,2}\b').hasMatch(text) ||
        RegExp(r'\d{1,2}월\s*\d{1,2}일').hasMatch(text);
    final task =
        _hasAny(text, const [
          '해야',
          '하기',
          '사기',
          '구매',
          '보내기',
          '확인',
          '정리',
          '제출',
          '전화',
          '해야지',
          '해야겠다',
        ]) ||
        RegExp(r'(해야지|해야겠다)\b').hasMatch(text);
    final habit = _hasAny(text, const [
      '매일',
      '오늘도',
      '물',
      '운동',
      '명상',
      '독서',
      '약 먹기',
      '약먹기',
    ]);
    final goal =
        _hasAny(text, const [
          '목표',
          '달성',
          '감량',
          '합격',
          '출시',
          '저축',
          '만들기',
          '하고 싶다',
          '되기',
        ]) ||
        RegExp(r'-\s*\d+\s*kg').hasMatch(text);

    return switch (kind) {
      _LogroomDraftKind.event => schedule,
      _LogroomDraftKind.task => task,
      _LogroomDraftKind.habit => habit,
      _LogroomDraftKind.goal => goal,
      _LogroomDraftKind.entry => true,
    };
  }

  bool _shouldClearSuggestionSelection(String raw) {
    final selected = _suggestionSelectedKind;
    if (selected == null) return false;
    if (raw.trim().isEmpty) return true;
    return !_matchesSuggestionKind(raw, selected);
  }

  List<_SuggestionChipData> _suggestionsForText(String raw) {
    if (!isNemo2Test) return const [];
    final text = raw.trim().toLowerCase();
    if (text.isEmpty || _draftKind != _LogroomDraftKind.entry) return const [];
    if (!_hasMinimumSuggestionText(text)) return const [];

    final suggestions = <_SuggestionChipData>[];
    if (_matchesSuggestionKind(text, _LogroomDraftKind.event)) {
      suggestions.add(
        const _SuggestionChipData('일정으로 만들기', _LogroomDraftKind.event),
      );
    }
    if (_matchesSuggestionKind(text, _LogroomDraftKind.task)) {
      suggestions.add(
        const _SuggestionChipData('할일로 만들기', _LogroomDraftKind.task),
      );
    }
    if (_matchesSuggestionKind(text, _LogroomDraftKind.habit)) {
      suggestions.add(
        const _SuggestionChipData('습관으로 기록', _LogroomDraftKind.habit),
      );
    }
    if (_matchesSuggestionKind(text, _LogroomDraftKind.goal)) {
      suggestions.add(
        const _SuggestionChipData('목표로 만들기', _LogroomDraftKind.goal),
      );
    }
    return suggestions.take(3).toList();
  }

  Future<void> _applySuggestion(_LogroomDraftKind kind) async {
    if (kind == _LogroomDraftKind.habit && !widget.habitActivated) {
      await _showHabitActivation();
      return;
    }
    if (kind == _LogroomDraftKind.goal && !widget.goalActivated) {
      await _showGoalActivation();
      return;
    }
    setState(() {
      _draftKind = kind;
      _forceChecklist = kind == _LogroomDraftKind.task;
      _suggestionSelectedKind = kind;
    });
  }

  void _showKeyboardNow() {
    if (!mounted) return;
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  void _restoreInputFocus({bool extraDelayed = false}) {
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showKeyboardNow();
      Future<void>.delayed(const Duration(milliseconds: 80), _showKeyboardNow);
      if (extraDelayed) {
        Future<void>.delayed(
          const Duration(milliseconds: 180),
          _showKeyboardNow,
        );
      }
    });
  }

  void _wrapSelection(String prefix, String suffix) {
    final sel = _controller.selection;
    final old = _controller.text;
    if (sel.isValid && !sel.isCollapsed) {
      final selected = old.substring(sel.start, sel.end);
      final newText = old.replaceRange(
        sel.start,
        sel.end,
        '$prefix$selected$suffix',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start + prefix.length,
          extentOffset: sel.start + prefix.length + selected.length,
        ),
      );
    } else {
      final pos = sel.isValid ? sel.start : old.length;
      final newText =
          old.substring(0, pos) + '$prefix$suffix' + old.substring(pos);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + prefix.length),
      );
    }
    _restoreInputFocus();
  }

  void _insertText(String text) {
    final sel = _controller.selection;
    final old = _controller.text;
    final String newText;
    final int offset;
    if (sel.isValid && sel.start >= 0) {
      newText = old.replaceRange(sel.start, sel.end, text);
      offset = sel.start + text.length;
    } else {
      newText = old + text;
      offset = newText.length;
    }
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
    _restoreInputFocus();
  }

  void _insertListPrefix(String prefix) {
    final sel = _controller.selection;
    final old = _controller.text;
    if (old.isEmpty || !sel.isValid || sel.start <= 0) {
      final newText = prefix + old;
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: prefix.length),
      );
    } else {
      final insert = '\n$prefix';
      final newText =
          old.substring(0, sel.start) + insert + old.substring(sel.end);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + insert.length),
      );
    }
    _restoreInputFocus();
  }

  String _fmtReminder(DateTime dt) {
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$mo/$d $hh:$mm';
  }

  String _repeatLabel(String repeat) {
    switch (repeat) {
      case 'daily':
        return ' ↻매일';
      case 'weekly':
        return ' ↻매주';
      case 'monthly':
        return ' ↻매월';
      default:
        return '';
    }
  }

  void _showReminderPicker() {
    showScheduleSheet(
      context,
      mode: ScheduleSheetMode.reminder,
      current: _reminderAt,
      currentRepeat: _reminderRepeat,
      repeatEndType: _reminderRepeatEndType,
      repeatEndCount: _reminderRepeatEndCount,
      repeatEndDate: _reminderRepeatEndDate,
      onResult: (dt, repeat, _, endType, endCount, endDate, __) {
        setState(() {
          _reminderAt = dt;
          _reminderRepeat = repeat;
          _reminderRepeatEndType = endType;
          _reminderRepeatEndCount = endCount;
          _reminderRepeatEndDate = endDate;
        });
      },
    );
  }

  void _showFolderDropdown() async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final pos = renderBox.localToGlobal(Offset.zero);

    final result = await showMenu<String?>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(pos.dx + 14, pos.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      color: kSurface,
      elevation: 3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      items: [
        PopupMenuItem<String?>(
          value: '__inbox__',
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '/inbox',
            style: mono(
              color: _selectedFolderId == null ? kMint : kText,
              fontSize: 12,
            ),
          ),
        ),
        ...widget.folders.map(
          (f) => PopupMenuItem<String?>(
            value: f.id,
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '/${f.name}',
              style: mono(
                color: _selectedFolderId == f.id ? kMint : kText,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
    if (result != null) {
      setState(() => _selectedFolderId = result == '__inbox__' ? null : result);
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) return;
    final source = await _showImageSourceSheet();
    if (source == null) return;

    if (_pendingImages.length >= ImageService.maxImagesPerMemo) {
      _showSnack('이미지는 최대 10개까지 첨부할 수 있습니다');
      return;
    }

    if (source == ImageSource.gallery) {
      final result = await ImageService.pickManyFromGallery(
        remainingSlots: ImageService.maxImagesPerMemo - _pendingImages.length,
      );
      if (!mounted) return;
      if (result.paths.isNotEmpty) {
        setState(() => _pendingImages.addAll(result.paths));
      }
      if (result.rejectedCount > 0) {
        _showSnack('일부 이미지는 용량이 커서 첨부하지 못했습니다');
      }
      return;
    }

    final path = await ImageService.pick(source);
    if (!mounted) return;

    if (path == '__TOO_LARGE__') {
      _showSnack('이미지 용량이 너무 커서 첨부하지 못했습니다');
      return;
    }

    if (path != null) setState(() => _pendingImages.add(path));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kSurface,
        duration: const Duration(seconds: 2),
        content: Text(message, style: mono(color: kText, fontSize: 12)),
      ),
    );
  }

  Future<ImageSource?> _showImageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이미지 추가',
                    style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: kBorder),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SheetBtn(
                        label: '갤러리',
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                      const SizedBox(width: 12),
                      _SheetBtn(
                        label: '카메라',
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

String _contentForDraftKind(String raw) {
    var content = raw.trim();
    if (_draftKind == _LogroomDraftKind.task &&
        !_hasChecklistMarker(content) &&
        !_textLooksChecklist(content)) {
      content = content
          .split('\n')
          .map((line) => line.trim().isEmpty ? line : '- [ ] ${line.trim()}')
          .join('\n');
    }
    if (_draftKind == _LogroomDraftKind.habit &&
        !_tags.any((t) => t.toLowerCase() == 'habit')) {
      content = '$content #habit'.trim();
    }
    if (_draftKind == _LogroomDraftKind.goal &&
        !_tags.any((t) => t.toLowerCase() == 'goal')) {
      content = '$content #goal'.trim();
    }
    return content;
  }

  Future<void> _showLogroomCreateMenu() async {
    final result = await showModalBottomSheet<_LogroomDraftKind>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEW', style: mono(color: kMint, fontSize: 12)),
                  const SizedBox(height: 12),
                  _LogroomDraftOption(
                    symbol: '●',
                    label: '새 기록',
                    onTap: () => Navigator.pop(ctx, _LogroomDraftKind.entry),
                  ),
                  _LogroomDraftOption(
                    symbol: '□',
                    label: '새 할일',
                    onTap: () => Navigator.pop(ctx, _LogroomDraftKind.task),
                  ),
                  _LogroomDraftOption(
                    symbol: '△',
                    label: '새 일정',
                    onTap: () => Navigator.pop(ctx, _LogroomDraftKind.event),
                  ),
                  _LogroomDraftOption(
                    symbol: '○',
                    label: '새 습관',
                    onTap: () => Navigator.pop(ctx, _LogroomDraftKind.habit),
                  ),
                  _LogroomDraftOption(
                    symbol: '◇',
                    label: '새 목표',
                    onTap: () => Navigator.pop(ctx, _LogroomDraftKind.goal),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;

    if (result == _LogroomDraftKind.habit && !widget.habitActivated) {
      await _showHabitActivation();
      return;
    }
    if (result == _LogroomDraftKind.goal && !widget.goalActivated) {
      await _showGoalActivation();
      return;
    }

    setState(() {
      _draftKind = result;
      _forceChecklist = result == _LogroomDraftKind.task;
      _suggestionSelectedKind = null;
    });
    _restoreInputFocus();
    if (result == _LogroomDraftKind.event) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSchedulePicker();
      });
    }
  }

  Future<void> _showHabitActivation() async {
    if (!mounted) return;
    final ctx = context;
    final confirmed = await showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: kBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: kTeal, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          child: _ActivationSheetContent(
            title: 'habits',
            body: widget.dayCount >= 14
                ? '"2주 됐어요. 잘하고 있어요."\n"이제 큰 그림도 그릴 수 있어요."'
                : widget.dayCount >= 7
                ? '"일주일째네요."\n"습관을 좀 더 단단히 들여볼 때예요."'
                : widget.dayCount >= 5
                ? '"벌써 ${widget.dayCount}일째예요!"\n"슬슬 습관 하나 잡아볼까요?"'
                : '"습관 하나 만들어볼까요?"\n"탭 한 번이면 기록돼요."',
            actionLabel: widget.dayCount >= 5 ? '만들기' : '해보기',
            laterLabel: '나중에',
            onActivate: () => Navigator.pop(sheetCtx, true),
            onLater: () => Navigator.pop(sheetCtx, false),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _showNameDialog(isHabit: true);
  }

  Future<void> _showGoalActivation() async {
    if (!mounted) return;
    final ctx = context;
    if (widget.dayCount < 14) {
      await showModalBottomSheet<void>(
        context: ctx,
        backgroundColor: kBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        builder: (sheetCtx) => Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: kTeal, width: 2)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'goals',
                  style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: kBorder.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('아직 열리지 않았어요.', style: mono(color: kDim, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  '  Day ${widget.dayCount}  —  ${14 - widget.dayCount}일 후에 만나요.',
                  style: mono(color: kDim.withValues(alpha: 0.7), fontSize: 11),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetCtx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        color: kMint,
                        child: Text(
                          '알겠어요',
                          style: mono(color: kBg, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: kBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: kTeal, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          child: _ActivationSheetContent(
            title: 'goals',
            body: '"14일이 지났어요."\n"이제 목표를 만들 수 있어요."',
            actionLabel: '만들기',
            laterLabel: '나중에',
            onActivate: () => Navigator.pop(sheetCtx, true),
            onLater: () => Navigator.pop(sheetCtx, false),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _showNameDialog(isHabit: false);
  }

  Future<void> _showNameDialog({required bool isHabit}) async {
    if (!mounted) return;
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => focusNode.requestFocus(),
        );
        return Dialog(
          backgroundColor: kSurface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHabit ? '습관 이름' : '목표 이름',
                  style: mono(color: kMint, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: mono(color: kText, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: isHabit ? '예: 물 2L, 운동 30분' : '예: 체중 관리',
                    hintStyle: mono(color: kDim, fontSize: 12),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: kBorder),
                      borderRadius: BorderRadius.zero,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: kBorder),
                      borderRadius: BorderRadius.zero,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: kMint),
                      borderRadius: BorderRadius.zero,
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '취소',
                          style: mono(color: kDim, fontSize: 12),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final v = controller.text.trim();
                        if (v.isNotEmpty) Navigator.pop(ctx, v);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '확인',
                          style: mono(color: kMint, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (name == null || !mounted) return;
    if (isHabit) {
      widget.onActivateHabit?.call(name);
    } else {
      widget.onActivateGoal?.call(name);
    }
    // After activation, set draft kind so user can continue adding entries
    setState(() {
      _draftKind = isHabit ? _LogroomDraftKind.habit : _LogroomDraftKind.goal;
      _suggestionSelectedKind = null;
    });
    _restoreInputFocus();
  }

  void _submit() {
    final raw = _contentForDraftKind(_controller.text);
    if (raw.isEmpty &&
        _pendingImages.isEmpty &&
        widget.editingMemo?.sourceUrl == null) {
      return;
    }
    widget.onSubmit(
      raw,
      _isChecklist,
      _reminderAt,
      _selectedFolderId,
      List<String>.from(_pendingImages),
      _reminderRepeat,
      _scheduledAt,
      _rangeEndDate,
      _scheduleRepeat,
      _scheduleRepeatEndType,
      _scheduleRepeatEndCount,
      _scheduleRepeatEndDate,
    );
    _resetDraftState();
    widget.onCancelEdit?.call();
    FocusScope.of(context).unfocus();
  }

  void _cancelEdit() {
    _resetDraftState();
    widget.onCancelEdit?.call();
    FocusScope.of(context).unfocus();
  }

  void _resetDraftState() {
    _resettingDraft = true;
    _controller.clear();
    _prevText = '';
    setState(() {
      _reminderAt = null;
      _reminderRepeat = 'none';
      _reminderRepeatEndType = 'infinite';
      _reminderRepeatEndCount = 5;
      _reminderRepeatEndDate = null;
      _scheduledAt = null;
      _rangeEndDate = null;
      _scheduleRepeat = 'none';
      _scheduleRepeatEndType = 'infinite';
      _scheduleRepeatEndCount = 5;
      _scheduleRepeatEndDate = null;
      _pendingImages.clear();
      _editingSourceUrl = null;
      _forceChecklist = false;
      _draftKind = _LogroomDraftKind.entry;
      _suggestionSelectedKind = null;
      _schedulePickerOpened = false;
    });
    _resettingDraft = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = _tags;
    final visibleTags = _focusNode.hasFocus ? const <String>[] : tags;
    final suggestions = _suggestionsForText(_controller.text);
    final badgeChildren = <Widget>[
      if (widget.editingMemo != null)
        Text('✏️ 메모 수정중', style: mono(color: kMint, fontSize: 10)),
      if (isLogroomUi && _draftKind != _LogroomDraftKind.entry)
        Text(
          _draftKindLabel(_draftKind),
          style: mono(color: kMint, fontSize: 10),
        ),
      ...visibleTags.map(
        (t) => Text('#$t', style: mono(color: kTeal, fontSize: 11)),
      ),
      if (_scheduledAt != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '! ${_fmtReminder(_scheduledAt!)}',
              style: mono(color: kMint, fontSize: 10),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() => _scheduledAt = null),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  '×',
                  style: mono(color: kDim.withValues(alpha: 0.6), fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      if (_reminderAt != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🔔 ${_fmtReminder(_reminderAt!)}${_repeatLabel(_reminderRepeat)}',
              style: mono(color: kMint, fontSize: 10),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() {
                _reminderAt = null;
                _reminderRepeat = 'none';
              }),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  '×',
                  style: mono(color: kDim.withValues(alpha: 0.6), fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      if (_editingSourceUrl != null)
        Text(
          '🔗 ${_linkLabel(_editingSourceUrl!)}',
          style: mono(color: kTeal, fontSize: 10),
        ),
    ];
    if (isDosTheme) {
      return _buildDosInput(tags: tags, suggestions: suggestions);
    }
    if (isMinimalTheme) {
      return _buildMinimalInput(
        tags: tags,
        suggestions: suggestions,
        badgeChildren: badgeChildren,
      );
    }
    if (isLogroomUi) {
      return _buildLogroomInput(
        tags: tags,
        suggestions: suggestions,
        badgeChildren: badgeChildren,
      );
    }
    return Container(
      color: kBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar row ───────────────────────────────────
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 1, 6, 1),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: kBorder.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TextFmtBtn(
                            label: 'B',
                            bold: true,
                            onTap: () => _wrapSelection('**', '**'),
                          ),
                          _TextFmtBtn(
                            label: 'I',
                            italic: true,
                            onTap: () => _wrapSelection('*', '*'),
                          ),
                          _TextFmtBtn(
                            label: 'S',
                            strike: true,
                            onTap: () => _wrapSelection('~~', '~~'),
                          ),
                          Container(
                            width: 1,
                            height: 14,
                            color: kBorder.withValues(alpha: 0.6),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                          if (isLogroomUi) ...[
                            _ToolBtn(
                              icon: Icons.add,
                              tooltip: '새 항목',
                              active: _draftKind != _LogroomDraftKind.entry,
                              onTap: _showLogroomCreateMenu,
                            ),
                            Container(
                              width: 1,
                              height: 14,
                              color: kBorder.withValues(alpha: 0.6),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                            ),
                          ],
                          _ToolBtn(
                            icon: Icons.check_box_outline_blank,
                            tooltip: '체크박스',
                            onTap: () => _insertListPrefix('- [ ] '),
                          ),
                          _ToolBtn(
                            icon: Icons.format_list_bulleted,
                            tooltip: '불릿',
                            onTap: () => _insertListPrefix('• '),
                          ),
                          _ToolBtn(
                            icon: Icons.tag,
                            tooltip: '태그',
                            onTap: () => _insertText('#'),
                          ),
                          _ToolBtn(
                            icon: Icons.calendar_today,
                            tooltip: 'event',
                            active: _scheduledAt != null,
                            onTap: _showSchedulePicker,
                          ),
                          _ToolBtn(
                            icon: Icons.alarm_outlined,
                            tooltip: 'task 알림',
                            active: _reminderAt != null,
                            onTap: _showReminderPicker,
                          ),
                          if (!kIsWeb)
                            _ToolBtn(
                              icon: Icons.image_outlined,
                              tooltip: '이미지',
                              active: _pendingImages.isNotEmpty,
                              onTap: _pickImage,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AddBtn(
                    label: widget.editingMemo == null ? '추가' : '수정 완료',
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ),

          // ── Badges: tags + reminder ────────────────────────
          if (badgeChildren.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: badgeChildren
                      .map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: w,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),

          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: suggestions
                      .map(
                        (suggestion) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _SuggestionChip(
                            label: suggestion.label,
                            onTap: () => _applySuggestion(suggestion.kind),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),

          // ── Pending images row ─────────────────────────────
          if (_pendingImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingImages.length,
                  itemBuilder: (ctx, i) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: Image.file(
                              File(_pendingImages[i]),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _pendingImages.removeAt(i)),
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.close,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Text input ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 7),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: mono(fontSize: 13, height: 1.35),
              maxLines: 6,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              cursorColor: kMint,
              cursorWidth: 2,
              decoration: InputDecoration(
                hintText: isLogroomUi
                    ? _draftKindHint(_draftKind)
                    : (widget.scheduleMode ? '! new event' : 'new memo'),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintStyle: mono(
                  color: kDim.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ),
          ),

          if (widget.editingMemo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [_TextActionBtn(label: '취소', onTap: _cancelEdit)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDosInput({
    required List<String> tags,
    required List<_SuggestionChipData> suggestions,
  }) {
    final action = widget.editingMemo == null ? '[ SAVE ]' : '[ UPDATE ]';
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _DosTool(
                  label: '[ B ]',
                  onTap: () => _wrapSelection('**', '**'),
                ),
                _DosTool(label: '[ I ]', onTap: () => _wrapSelection('*', '*')),
                _DosTool(
                  label: '[ TODO ]',
                  onTap: () => _insertListPrefix('- [ ] '),
                ),
                _DosTool(
                  label: '[ LIST ]',
                  onTap: () => _insertListPrefix('• '),
                ),
                _DosTool(label: '[ TAG ]', onTap: () => _insertText('#')),
                _DosTool(label: '[ SCHED ]', onTap: _showSchedulePicker),
                _DosTool(label: '[ ALARM ]', onTap: _showReminderPicker),
                if (!kIsWeb) _DosTool(label: '[ IMG ]', onTap: _pickImage),
                const SizedBox(width: 8),
                _DosTool(label: action, onTap: _submit),
                if (widget.editingMemo != null)
                  _DosTool(label: '[ CANCEL ]', onTap: _cancelEdit),
              ],
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 3,
              children: suggestions
                  .map(
                    (s) => GestureDetector(
                      onTap: () => _applySuggestion(s.kind),
                      child: Text(
                        '[ ${s.label} ]',
                        style: mono(color: kTeal, fontSize: 9),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (tags.isNotEmpty ||
              _scheduledAt != null ||
              _reminderAt != null ||
              _editingSourceUrl != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 7,
              runSpacing: 2,
              children: [
                ...tags.map(
                  (t) => Text('#$t', style: mono(color: kTeal, fontSize: 9)),
                ),
                if (_scheduledAt != null)
                  Text(
                    '[SCHED: ${_fmtReminder(_scheduledAt!)}]',
                    style: mono(color: kTeal, fontSize: 9),
                  ),
                if (_reminderAt != null)
                  Text(
                    '[ALARM: ${_fmtReminder(_reminderAt!)}]',
                    style: mono(color: kTeal, fontSize: 9),
                  ),
                if (_editingSourceUrl != null)
                  Text(
                    '[LINK: ${_linkLabel(_editingSourceUrl!)}]',
                    style: mono(color: kTeal, fontSize: 9),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 5),
          Container(
            decoration: BoxDecoration(border: Border.all(color: kBorder)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('C:\\LOGROOM> ', style: mono(color: kMint, fontSize: 12)),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: mono(fontSize: 12, height: 1.35),
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    cursorColor: kMint,
                    decoration: InputDecoration(
                      hintText: _draftKindHint(_draftKind),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintStyle: mono(color: kDim, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _logroomInputHint() => switch (_draftKind) {
    _LogroomDraftKind.entry => '지금 무슨 생각을 하고 있나요?',
    _LogroomDraftKind.task  => '새 할일',
    _LogroomDraftKind.event => '새 일정',
    _LogroomDraftKind.habit => '새 습관',
    _LogroomDraftKind.goal  => '새 목표',
  };

  // v3 Logroom input — text field first, toolbar below and muted.
  Widget _buildLogroomInput({
    required List<String> tags,
    required List<_SuggestionChipData> suggestions,
    required List<Widget> badgeChildren,
  }) {
    return Container(
      color: kBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Text input (first, with left accent dot) ──────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline-style accent dot (7px matches HTML q-dot)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: mono(fontSize: 13, height: 1.35),
                    maxLines: 6,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    cursorColor: kAccent,
                    cursorWidth: 1.5,
                    decoration: InputDecoration(
                      hintText: _logroomInputHint(),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintStyle: mono(
                        color: kText3.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Badges ────────────────────────────────────────────
          if (badgeChildren.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 14, 3),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: badgeChildren
                      .map((w) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: w,
                          ))
                      .toList(),
                ),
              ),
            ),

          // ── Suggestions ───────────────────────────────────────
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 14, 3),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: suggestions
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _SuggestionChip(
                              label: s.label,
                              onTap: () => _applySuggestion(s.kind),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),

          // ── Pending images ────────────────────────────────────
          if (_pendingImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 14, 0),
              child: SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingImages.length,
                  itemBuilder: (ctx, i) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: Image.file(
                              File(_pendingImages[i]),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _pendingImages.removeAt(i)),
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close,
                                    size: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Toolbar (below text, muted) ───────────────────────
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 1, 6, 1),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: kTlLine),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TextFmtBtn(
                            label: 'B',
                            bold: true,
                            onTap: () => _wrapSelection('**', '**'),
                          ),
                          _TextFmtBtn(
                            label: 'I',
                            italic: true,
                            onTap: () => _wrapSelection('*', '*'),
                          ),
                          _TextFmtBtn(
                            label: 'S',
                            strike: true,
                            onTap: () => _wrapSelection('~~', '~~'),
                          ),
                          Container(
                            width: 1,
                            height: 12,
                            color: kTlLine,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                          _ToolBtn(
                            icon: Icons.add,
                            tooltip: '새 항목',
                            active: _draftKind != _LogroomDraftKind.entry,
                            onTap: _showLogroomCreateMenu,
                          ),
                          Container(
                            width: 1,
                            height: 12,
                            color: kTlLine,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                          _ToolBtn(
                            icon: Icons.check_box_outline_blank,
                            tooltip: '체크박스',
                            onTap: () => _insertListPrefix('- [ ] '),
                          ),
                          _ToolBtn(
                            icon: Icons.format_list_bulleted,
                            tooltip: '불릿',
                            onTap: () => _insertListPrefix('• '),
                          ),
                          _ToolBtn(
                            icon: Icons.tag,
                            tooltip: '태그',
                            onTap: () => _insertText('#'),
                          ),
                          _ToolBtn(
                            icon: Icons.calendar_today,
                            tooltip: 'event',
                            active: _scheduledAt != null,
                            onTap: _showSchedulePicker,
                          ),
                          _ToolBtn(
                            icon: Icons.alarm_outlined,
                            tooltip: 'task 알림',
                            active: _reminderAt != null,
                            onTap: _showReminderPicker,
                          ),
                          if (!kIsWeb)
                            _ToolBtn(
                              icon: Icons.image_outlined,
                              tooltip: '이미지',
                              active: _pendingImages.isNotEmpty,
                              onTap: _pickImage,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AddBtn(
                    label: widget.editingMemo == null ? '추가' : '수정 완료',
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ),

          if (widget.editingMemo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [_TextActionBtn(label: '취소', onTap: _cancelEdit)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMinimalInput({
    required List<String> tags,
    required List<_SuggestionChipData> suggestions,
    required List<Widget> badgeChildren,
  }) {
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MinimalTool(
                          label: 'B',
                          onTap: () => _wrapSelection('**', '**'),
                        ),
                        _MinimalTool(
                          label: 'I',
                          onTap: () => _wrapSelection('*', '*'),
                        ),
                        _MinimalTool(
                          label: 'S',
                          onTap: () => _wrapSelection('~~', '~~'),
                        ),
                        const SizedBox(width: 6),
                        if (isLogroomUi)
                          _MinimalTool(
                            label: '+',
                            active: _draftKind != _LogroomDraftKind.entry,
                            onTap: _showLogroomCreateMenu,
                          ),
                        _MinimalTool(
                          label: 'TODO',
                          onTap: () => _insertListPrefix('- [ ] '),
                        ),
                        _MinimalTool(
                          label: 'LIST',
                          onTap: () => _insertListPrefix('• '),
                        ),
                        _MinimalTool(
                          label: 'TAG',
                          onTap: () => _insertText('#'),
                        ),
                        _MinimalTool(
                          label: 'SCHED',
                          active: _scheduledAt != null,
                          onTap: _showSchedulePicker,
                        ),
                        _MinimalTool(
                          label: 'ALARM',
                          active: _reminderAt != null,
                          onTap: _showReminderPicker,
                        ),
                        if (!kIsWeb)
                          _MinimalTool(
                            label: 'IMG',
                            active: _pendingImages.isNotEmpty,
                            onTap: _pickImage,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MinimalSubmitBtn(
                  label: widget.editingMemo == null ? '추가' : '수정 완료',
                  onTap: _submit,
                ),
              ],
            ),
          ),
          if (badgeChildren.isNotEmpty) ...[
            const SizedBox(height: 3),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: badgeChildren
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: w,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 3),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: suggestions
                    .map(
                      (suggestion) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _SuggestionChip(
                          label: suggestion.label,
                          onTap: () => _applySuggestion(suggestion.kind),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (_pendingImages.isNotEmpty) ...[
            const SizedBox(height: 5),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                itemBuilder: (ctx, i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.file(
                            File(_pendingImages[i]),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 1,
                          right: 1,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _pendingImages.removeAt(i)),
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close,
                                size: 9,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 4),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: mono(fontSize: 13, height: 1.32),
            maxLines: 5,
            minLines: 1,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            cursorColor: kMint,
            cursorWidth: 1.5,
            decoration: InputDecoration(
              hintText: isLogroomUi
                  ? _draftKindHint(_draftKind)
                  : (widget.scheduleMode ? '! new event' : 'new memo'),
              filled: false,
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: kBorder.withValues(alpha: 0.24)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: kBorder.withValues(alpha: 0.24)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: kMint.withValues(alpha: 0.42)),
              ),
              contentPadding: const EdgeInsets.fromLTRB(0, 3, 0, 5),
              isDense: true,
              hintStyle: mono(
                color: kDim.withValues(alpha: 0.48),
                fontSize: 13,
              ),
            ),
          ),
          if (widget.editingMemo != null)
            Align(
              alignment: Alignment.centerRight,
              child: _TextActionBtn(label: '취소', onTap: _cancelEdit),
            ),
        ],
      ),
    );
  }
}

class _DosTool extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DosTool({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
        child: Text(label, style: mono(color: kMint, fontSize: 10)),
      ),
    );
  }
}

class _MinimalTool extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _MinimalTool({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 3),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: active ? kMint.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: mono(
            color: active ? kMint : kDim,
            fontSize: 9,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _MinimalSubmitBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MinimalSubmitBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: kMint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: mono(
            color: kMint,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Tool button
// ─────────────────────────────────────────────────────────────────

class _SuggestionChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = _hovered ? kText : kDim;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _hovered ? kSurface : Colors.transparent,
            border: Border.all(color: kBorder.withValues(alpha: 0.55)),
          ),
          child: Text(widget.label, style: mono(color: fg, fontSize: 9)),
        ),
      ),
    );
  }
}

class _ToolBtn extends StatefulWidget {
  final IconData? icon;
  final String? iconText; // text-based icon (e.g. '◷')
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;

  const _ToolBtn({
    this.icon,
    this.iconText,
    required this.onTap,
    this.active = false,
    this.tooltip,
  }) : assert(icon != null || iconText != null);

  @override
  State<_ToolBtn> createState() => _ToolBtnState();
}

class _ToolBtnState extends State<_ToolBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? kMint
        : (_hovered ? kText : kDim.withValues(alpha: 0.55));

    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: widget.active
                ? kMint.withValues(alpha: 0.1)
                : (_hovered ? kSurface : Colors.transparent),
          ),
          child: widget.iconText != null
              ? Text(widget.iconText!, style: mono(color: color, fontSize: 17))
              : Icon(widget.icon!, size: 15, color: color),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        textStyle: mono(color: kText, fontSize: 10),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
        ),
        child: btn,
      );
    }
    return btn;
  }
}

class _LogroomDraftOption extends StatefulWidget {
  final String symbol;
  final String label;
  final VoidCallback onTap;

  const _LogroomDraftOption({
    required this.symbol,
    required this.label,
    required this.onTap,
  });

  @override
  State<_LogroomDraftOption> createState() => _LogroomDraftOptionState();
}

class _LogroomDraftOptionState extends State<_LogroomDraftOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          color: _hovered ? kMint.withValues(alpha: 0.08) : Colors.transparent,
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  widget.symbol,
                  style: mono(color: _hovered ? kMint : kText, fontSize: 13),
                ),
              ),
              Text(
                widget.label,
                style: mono(color: _hovered ? kMint : kText, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ADD submit button
// ─────────────────────────────────────────────────────────────────

class _AddBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _AddBtn({required this.label, required this.onTap});

  @override
  State<_AddBtn> createState() => _AddBtnState();
}

class _AddBtnState extends State<_AddBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? kMint.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: mono(color: _hovered ? kMint : kDim, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _TextActionBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _TextActionBtn({required this.label, required this.onTap});

  @override
  State<_TextActionBtn> createState() => _TextActionBtnState();
}

class _TextActionBtnState extends State<_TextActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Text(
            widget.label,
            style: mono(color: _hovered ? kText : kDim, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Folder button
// ─────────────────────────────────────────────────────────────────

class _FolderBtn extends StatefulWidget {
  final String? label;
  final VoidCallback? onTap;
  const _FolderBtn({required this.label, this.onTap});

  @override
  State<_FolderBtn> createState() => _FolderBtnState();
}

class _FolderBtnState extends State<_FolderBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    final displayLabel = widget.label != null && widget.label!.isNotEmpty
        ? '${widget.label} ▾'
        : '폴더 선택';
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered && active
                ? kMint.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Text(
            displayLabel,
            style: mono(
              color: _hovered ? kMint : kDim.withValues(alpha: 0.55),
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Image source sheet button
// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────
// Markdown formatting button (B / I / S)
// ─────────────────────────────────────────────────────────────────

class _TextFmtBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;
  final bool strike;

  const _TextFmtBtn({
    required this.label,
    required this.onTap,
    this.bold = false,
    this.italic = false,
    this.strike = false,
  });

  @override
  State<_TextFmtBtn> createState() => _TextFmtBtnState();
}

class _TextFmtBtnState extends State<_TextFmtBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? kText : kDim.withValues(alpha: 0.55);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => widget.onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? kSurface : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12,
              color: color,
              fontWeight: widget.bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
              decoration: widget.strike ? TextDecoration.lineThrough : null,
              decorationColor: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SheetBtn({required this.label, required this.onTap});

  @override
  State<_SheetBtn> createState() => _SheetBtnState();
}

class _SheetBtnState extends State<_SheetBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? kMint.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(color: kBorder),
          ),
          child: Text(
            widget.label,
            style: mono(color: _hovered ? kMint : kDim, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _ActivationSheetContent extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final String laterLabel;
  final VoidCallback onActivate;
  final VoidCallback onLater;

  const _ActivationSheetContent({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.laterLabel,
    required this.onActivate,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: kBorder.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(body, style: mono(color: kDim, fontSize: 12, height: 1.7)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: onLater,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(border: Border.all(color: kBorder)),
                child: Text(laterLabel, style: mono(color: kDim, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onActivate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                color: kMint,
                child: Text(actionLabel, style: mono(color: kBg, fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
