import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../app_theme.dart';
import '../flavor.dart';
import '../models/memo.dart';
import '../models/memo_actions.dart';
import '../models/folder.dart';
import '../widgets/date_group_header.dart';
import '../widgets/memo_tile.dart';
import '../widgets/input_bar.dart';
import '../widgets/sidebar.dart';
import 'settings_screen.dart';
import '../widgets/bottom_tab_bar.dart';
import '../models/quick_tab.dart';
import '../models/append_note.dart';
import '../models/entry_display_mode.dart';
import '../services/storage_service.dart';
import '../services/local_search_service.dart';
import '../services/wiki_capture_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../services/image_service.dart';
import '../utils/memo_view_calculations.dart';
import '../utils/logroom_entries.dart';
import '../widgets/calendar_view.dart';
import '../widgets/logroom_entry_tile.dart';
import 'stats_screen.dart';
import 'schedule_screen.dart';
import 'today_screen.dart';
import 'graph_screen.dart';
import 'brain_screen.dart';

// Below this width → mobile overlay sidebar; above → desktop inline sidebar
const _kNarrowBreak = 700.0;

// Logroom v3: hour separator marker inserted between memo entries
class _HourMarker {
  final int hour;
  final int count;
  const _HourMarker(this.hour, {this.count = 0});
}

// Logroom v3: silence gap inserted when consecutive entries are far apart in time
class _SilenceGap {
  final int minutes;
  const _SilenceGap(this.minutes);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const int _nameLimit = 10;
  final _memos = <Memo>[];
  final _folders = <Folder>[];
  final _tabs = <QuickTab>[];
  final _bottomMenus = <String>['TODAY', 'LIST', 'CAL', 'MORE'];
  final _scrollController = ScrollController();
  final _inputBarKey = GlobalKey();
  final _memoKeys = <String, GlobalKey>{};

  bool _sidebarOpen = true;
  bool _didSetInitialSidebar = false;
  bool _tabLocked = false;
  bool _calendarOpen = false;
  bool _statsOpen = false;
  bool _scheduleOpen = false;
  bool _tasksOnly = false;
  bool _tagsOpen = false;
  bool _graphOpen = false;
  bool _brainOpen = false;
  bool _todayOpen = false;
  String? _selectedFolderId;
  String? _selectedTag;
  String? _selectedTabId;
  String? _highlightedMemoId; // briefly highlighted after notification tap
  Memo? _editingMemo;

  // ── Drag state ──────────────────────────────────────────────────
  Memo? _draggingMemo;
  String? _mergeTargetId; // memo id being hovered for merge
  int? _reorderInsertIndex; // list index for reorder drop zone

  int _dayCount = 1;
  bool _habitActivated = false;
  bool _goalActivated = false;

  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final _collapsedDates = <String>{};
  final _expandedLogroomGroups = <String>{};
  final _logroomHourSlots = <String, List<HourSlot>>{};
  final _logroomDaySummaries = <String, DaySummary>{};
  List<Object> _flatItems = const [];

  StreamSubscription? _shareSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themeNotifier.addListener(_onThemeChanged);
    _loadData();
    _initNotifications();
    _processPendingWidgetMemos();
    _initShareIntent();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _processPendingWidgetMemos();
    }
  }

  Future<void> _processPendingWidgetMemos() async {
    final pending = await WidgetService.collectPending();
    if (pending.isEmpty || !mounted) return;
    setState(() => _memos.addAll(pending));
    StorageService.saveMemos(_memos);
    for (final memo in pending) {
      if (memo.reminderAt != null) {
        NotificationService.schedule(
          memoId: memo.id,
          content: memo.content,
          scheduledAt: memo.reminderAt!,
          repeat: memo.reminderRepeat,
        );
      }
    }
  }

  void _initShareIntent() {
    if (kIsWeb) return;
    // Hot-start: app already running when another app shares to us
    _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((
      List<SharedMediaFile> files,
    ) {
      _handleSharedFiles(files);
      ReceiveSharingIntent.instance.reset();
    });
    // Cold-start: app launched via share intent
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _handleSharedFiles(files);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  static String _sourceTag(String? url) {
    if (url == null) return '#공유기사';
    final u = url.toLowerCase();
    if (u.contains('instagram.com')) return '#공유인스타';
    if (u.contains('threads.net') || u.contains('threads.com')) return '#공유스레드';
    if (u.contains('kakao')) return '#공유카톡';
    if (u.contains('youtube.com') || u.contains('youtu.be')) return '#공유유튜브';
    if (u.contains('twitter.com') || u.contains('x.com')) return '#공유X';
    if (u.contains('tiktok.com')) return '#공유틱톡';
    if (u.contains('facebook.com') || u.contains('fb.com')) return '#공유페북';
    if (u.contains('chatgpt.com') || u.contains('chat.openai.com'))
      return '#공유GPT';
    if (u.contains('google.com')) return '#공유구글';
    if (u.contains('naver.com')) return '#공유네이버';
    if (u.contains('blog.') || u.contains('/blog')) return '#공유블로그';
    return '#공유기사';
  }

  static String _stripSharedMemoText(String raw) => raw
      .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
      .replaceAll(RegExp(r'#[a-zA-Z0-9_ㄱ-ㅎㅏ-ㅣ가-힣]+'), '')
      .replaceAll(RegExp(r'\n+'), ' ')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim();

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (!mounted) return;
    final textFiles = files
        .where(
          (f) =>
              f.type == SharedMediaType.text || f.type == SharedMediaType.url,
        )
        .toList();
    if (textFiles.isEmpty) return;

    final raw = textFiles.first.path.trim();
    if (raw.isEmpty) return;

    final urlRegex = RegExp(r'https?://\S+', caseSensitive: false);
    final urlMatch = urlRegex.firstMatch(raw);
    final detectedUrl = urlMatch?.group(0);

    final sourceTag = _sourceTag(detectedUrl);
    final tags = '#공유 $sourceTag';

    final initialContent = _stripSharedMemoText(raw);

    _showShareDialog(
      initialContent: initialContent,
      detectedUrl: detectedUrl,
      initialTags: tags,
    );
  }

  void _showShareDialog({
    required String initialContent,
    required String initialTags,
    String? detectedUrl,
  }) {
    final contentController = TextEditingController(text: initialContent);
    final urlController = TextEditingController(text: detectedUrl ?? '');
    final tagController = TextEditingController(text: initialTags);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: kSurface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHARED CONTENT',
                  style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: kBorder),
                const SizedBox(height: 12),

                // Memo content field
                Text('메모 내용', style: mono(color: kDim, fontSize: 10)),
                const SizedBox(height: 5),
                Container(
                  color: kBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: TextField(
                    controller: contentController,
                    maxLines: 4,
                    minLines: 2,
                    style: mono(fontSize: 12, height: 1.5),
                    cursorColor: kMint,
                    decoration: InputDecoration(
                      hintText: '내용을 입력하거나 비워두세요...',
                      hintStyle: mono(
                        color: kDim.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Source URL field
                Text('출처 URL', style: mono(color: kDim, fontSize: 10)),
                const SizedBox(height: 5),
                Container(
                  color: kBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: TextField(
                    controller: urlController,
                    maxLines: 1,
                    style: mono(fontSize: 11, height: 1.4, color: kTeal),
                    cursorColor: kMint,
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      hintStyle: mono(
                        color: kDim.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Text('태그', style: mono(color: kDim, fontSize: 10)),
                const SizedBox(height: 5),
                Container(
                  color: kBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: TextField(
                    controller: tagController,
                    maxLines: 1,
                    style: mono(fontSize: 11, height: 1.4, color: kTeal),
                    cursorColor: kMint,
                    decoration: InputDecoration(
                      hintText: '#공유',
                      hintStyle: mono(
                        color: kDim.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogBtn(
                      action: _DialogAction(
                        label: '취소',
                        color: kDim,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DialogBtn(
                      action: _DialogAction(
                        label: '저장',
                        color: kMint,
                        onTap: () {
                          Navigator.pop(ctx);
                          final memoText = contentController.text.trim();
                          final tagText = tagController.text.trim();
                          final content = [
                            memoText,
                            tagText,
                          ].where((part) => part.isNotEmpty).join('\n');
                          final url = urlController.text.trim().isNotEmpty
                              ? urlController.text.trim()
                              : null;
                          _addMemoWithSource(content, url);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      contentController.dispose();
      urlController.dispose();
      tagController.dispose();
    });
  }

  void _addMemoWithSource(String content, String? sourceUrl) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _memos.add(
        Memo(
          id: id,
          content: content,
          createdAt: DateTime.now(),
          folderId: _selectedFolderId,
          sourceUrl: sourceUrl,
        ),
      );
    });
    StorageService.saveMemos(_memos);
    if (sourceUrl != null) _autoSummarize(id, sourceUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _memoKeys[id];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  void _autoSummarize(String memoId, String sourceUrl) {
    Future(() async {
      final apiKey = await StorageService.loadClaudeApiKey();
      if (apiKey.isEmpty) return;
      final model = await StorageService.loadClaudeModel();

      // 1. 요약
      final summary = await WikiCaptureService.summarize(sourceUrl, apiKey, model: model);
      if (summary == null || summary.isEmpty) return;

      // 2. 연결 찾기
      final otherMemos = _memos.where((m) => m.id != memoId).toList();
      final connectedIds = await WikiCaptureService.findConnections(
        summary, otherMemos, apiKey, model: model,
      );

      String fullNote = summary;
      if (connectedIds.isNotEmpty) {
        final connectedTitles = connectedIds.map((id) {
          final m = _memos.firstWhere(
            (m) => m.id == id,
            orElse: () => Memo(id: id, content: '', createdAt: DateTime.now()),
          );
          return m.content.split('\n').first.trim();
        }).where((t) => t.isNotEmpty).take(3).join(', ');
        fullNote += '\n\n**연결된 메모**: $connectedTitles';
      }

      // 요약에서 #태그 추출해서 메모 본문에 자동 추가
      final tagMatches = RegExp(r'#[\w가-힣]+').allMatches(fullNote);
      final autoTags = tagMatches.map((m) => m.group(0)!).toSet().join(' ');

      final memos = await StorageService.loadMemos();
      final idx = memos.indexWhere((m) => m.id == memoId);
      if (idx == -1) return;

      final existingContent = memos[idx].content;
      final newContent = autoTags.isNotEmpty &&
              !existingContent.contains(autoTags.split(' ').first)
          ? '$existingContent\n$autoTags'
          : existingContent;

      final updated = memos[idx].copyWith(
        content: newContent,
        appendNotes: [
          ...memos[idx].appendNotes,
          AppendNote(content: fullNote, addedAt: DateTime.now()),
        ],
      );
      memos[idx] = updated;
      await StorageService.saveMemos(memos);

      if (mounted) setState(() {
        final i = _memos.indexWhere((m) => m.id == memoId);
        if (i != -1) _memos[i] = updated;
      });
    });
  }

  Future<void> _initNotifications() async {
    NotificationService.onNotificationTap = _navigateToMemo;
    NotificationService.pendingMemoId.addListener(_onPendingNotification);
    await NotificationService.checkLaunchDetails();
    if (NotificationService.pendingMemoId.value != null) {
      _onPendingNotification();
    }

    // Staggered permission requests so dialogs don't stack.
    Future.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      // 1. POST_NOTIFICATIONS (Android 13+)
      await NotificationService.requestPermissions();

      // 2. SCHEDULE_EXACT_ALARM (Android 12+) — opens Settings if not granted
      await Future.delayed(const Duration(milliseconds: 400));
      await NotificationService.ensureExactAlarmPermission();

      // 3. Battery optimization exemption — critical for Samsung Galaxy
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final ignoringBattery =
          await NotificationService.isIgnoringBatteryOptimizations();
      if (!ignoringBattery && mounted) {
        _showBatteryOptimizationPrompt();
      }
    });
  }

  void _showBatteryOptimizationPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kSurface,
        duration: const Duration(seconds: 8),
        content: Text(
          '알림이 차단될 수 있습니다. 배터리 최적화에서 이 앱을 제외해주세요.',
          style: mono(color: kText, fontSize: 12),
        ),
        action: SnackBarAction(
          label: '설정 열기',
          textColor: kMint,
          onPressed: () {
            NotificationService.requestBatteryOptimizationExemption();
          },
        ),
      ),
    );
  }

  void _onPendingNotification() {
    final id = NotificationService.pendingMemoId.value;
    if (id == null) return;
    NotificationService.pendingMemoId.value = null;
    _navigateToMemo(id);
  }

  void _openSearch() {
    setState(() {
      _searchOpen = true;
      _searchQuery = '';
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocusNode.requestFocus(),
    );
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  List<Memo> _getSearchResults() {
    final q = _searchQuery.trim();
    if (q.isEmpty) return [];
    if (isNemo2Test) return LocalSearchService.search(q, _memos);
    return _memos.where((m) {
      if (m.content.toLowerCase().contains(q.toLowerCase())) return true;
      if (m.tags.any((t) => t.toLowerCase().contains(q.toLowerCase()))) return true;
      if (m.dateKey.contains(q)) return true;
      return false;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _navigateToMemo(String memoId) {
    final memo = _memos.where((m) => m.id == memoId).firstOrNull;
    if (memo == null) return;
    setState(() {
      _selectedFolderId = memo.folderId;
      _selectedTag = null;
      _selectedTabId = null;
      _highlightedMemoId = memoId;
      _calendarOpen = false;
      _statsOpen = false;
      _scheduleOpen = false;
    });
    // Remove highlight after 3 seconds.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightedMemoId = null);
    });
    // Scroll to top so the user can see the memo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSetInitialSidebar) {
      _didSetInitialSidebar = true;
      // Start with sidebar closed on narrow (phone) screens
      if (MediaQuery.of(context).size.width < _kNarrowBreak) {
        _sidebarOpen = false;
      }
    }
  }

  Future<void> _loadData() async {
    final memos = await StorageService.loadMemos();
    final folders = await StorageService.loadFolders();
    final tabs = await StorageService.loadTabs();
    final bottomMenus = await StorageService.loadBottomMenus();
    final tabLocked = await StorageService.loadTabLocked();
    final dayCount = await StorageService.getDayCount();
    final habitActivated = await StorageService.getHabitActivated();
    final goalActivated = await StorageService.getGoalActivated();
    if (!mounted) return;
    setState(() {
      _memos.addAll(memos);
      _folders.addAll(folders);
      _tabs.addAll(tabs);
      _bottomMenus
        ..clear()
        ..addAll(_sanitizeBottomMenus(bottomMenus));
      _tabLocked = tabLocked;
      _dayCount = dayCount;
      _habitActivated = habitActivated;
      _goalActivated = goalActivated;
    });
    _rescheduleReminders(memos);
  }

  void _rescheduleReminders(List<Memo> memos) {
    if (kIsWeb) return;
    final now = DateTime.now();
    for (final memo in memos) {
      // Reschedule one-shot future reminders, and all repeating reminders
      // (the service rolls a repeating reminder forward to its next occurrence).
      if (memo.reminderAt != null &&
          (memo.reminderRepeat != 'none' || memo.reminderAt!.isAfter(now))) {
        NotificationService.schedule(
          memoId: memo.id,
          content: memo.content,
          scheduledAt: memo.reminderAt!,
          repeat: memo.reminderRepeat,
        );
      }
    }
  }

  // ── System folder activation ───────────────────────

  Future<void> _activateHabit(String name) async {
    await StorageService.setHabitActivated(true);
    setState(() => _habitActivated = true);
    _addMemo('$name #habit', false, null);
  }

  Future<void> _activateGoal(String name) async {
    await StorageService.setGoalActivated(true);
    setState(() => _goalActivated = true);
    _addMemo('$name #goal', false, null);
  }

  // ── Memo CRUD ──────────────────────────────────────

  void _addMemo(
    String content,
    bool isChecklist,
    DateTime? reminderAt, [
    String? folderOverride,
    List<String>? imagePaths,
    String reminderRepeat = 'none',
    DateTime? scheduledAt,
    DateTime? rangeEndDate,
    String scheduleRepeat = 'none',
    String repeatEndType = 'infinite',
    int repeatEndCount = 5,
    DateTime? repeatEndDate,
  ]) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final targetFolder = folderOverride ?? _selectedFolderId;
    setState(() {
      _memos.add(
        Memo(
          id: id,
          content: content,
          createdAt: DateTime.now(),
          folderId: targetFolder,
          isChecklist: isChecklist,
          reminderAt: reminderAt,
          reminderRepeat: reminderRepeat,
          scheduledAt: scheduledAt,
          imagePaths: imagePaths ?? const [],
          rangeEndDate: rangeEndDate,
          scheduleRepeat: scheduleRepeat,
          repeatEndType: repeatEndType,
          repeatEndCount: repeatEndCount,
          repeatEndDate: repeatEndDate,
        ),
      );
      if (folderOverride != null) _selectedFolderId = folderOverride;
    });
    StorageService.saveMemos(_memos);
    if (reminderAt != null) {
      NotificationService.schedule(
        memoId: id,
        content: content,
        scheduledAt: reminderAt,
        repeat: reminderRepeat,
        repeatEndDate: repeatEndDate,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Add memo with a specific date (used from calendar view).
  // Uses the selected day's date but current time so timeStr is accurate.
  void _addMemoOnDate(
    String content,
    DateTime date,
    bool isChecklist,
    DateTime? reminderAt, [
    List<String>? imagePaths,
    String reminderRepeat = 'none',
    DateTime? scheduledAt,
    DateTime? rangeEndDate,
    String scheduleRepeat = 'none',
    String repeatEndType = 'infinite',
    int repeatEndCount = 5,
    DateTime? repeatEndDate,
  ]) {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final createdAt = DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
    );
    final scheduleDate = scheduledAt == null
        ? null
        : DateTime(
            date.year,
            date.month,
            date.day,
            scheduledAt.hour,
            scheduledAt.minute,
            scheduledAt.second,
          );
    setState(() {
      _memos.add(
        Memo(
          id: id,
          content: content,
          createdAt: createdAt,
          isChecklist: isChecklist,
          reminderAt: reminderAt,
          reminderRepeat: reminderRepeat,
          imagePaths: imagePaths ?? const [],
          scheduledAt: scheduleDate,
          rangeEndDate: rangeEndDate,
          scheduleRepeat: scheduleRepeat,
          repeatEndType: repeatEndType,
          repeatEndCount: repeatEndCount,
          repeatEndDate: repeatEndDate,
        ),
      );
    });
    StorageService.saveMemos(_memos);
    if (reminderAt != null) {
      NotificationService.schedule(
        memoId: id,
        content: content,
        scheduledAt: reminderAt,
        repeat: reminderRepeat,
      );
    }
  }

  void _addNote(Memo memo, String content) {
    final note = AppendNote(content: content, addedAt: DateTime.now());
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i != -1) {
        _memos[i] = _memos[i].copyWith(
          appendNotes: [..._memos[i].appendNotes, note],
        );
      }
    });
    StorageService.saveMemos(_memos);
  }

  void _updateNote(Memo memo, int index, String content) {
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i != -1) {
        final notes = [..._memos[i].appendNotes];
        if (index >= 0 && index < notes.length) {
          notes[index] = AppendNote(
            content: content,
            addedAt: notes[index].addedAt,
          );
          _memos[i] = _memos[i].copyWith(appendNotes: notes);
        }
      }
    });
    StorageService.saveMemos(_memos);
  }

  void _deleteNote(Memo memo, int index) {
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i != -1) {
        final notes = [..._memos[i].appendNotes];
        if (index >= 0 && index < notes.length) {
          notes.removeAt(index);
          _memos[i] = _memos[i].copyWith(appendNotes: notes);
        }
      }
    });
    StorageService.saveMemos(_memos);
  }

  void _updateMemo(String id, String newContent) {
    setState(() {
      final i = _memos.indexWhere((m) => m.id == id);
      if (i != -1) {
        final original = _memos[i];
        String content = newContent;
        for (final sysTag in ['habit', 'goal']) {
          if (original.tags.contains(sysTag)) {
            final tempTags = Memo(
              id: '',
              content: content,
              createdAt: DateTime.now(),
            ).tags;
            if (!tempTags.contains(sysTag)) content += ' #$sysTag';
          }
        }
        _memos[i] = original.copyWith(
          content: content,
          editHistory: [...original.editHistory, DateTime.now()],
        );
      }
    });
    StorageService.saveMemos(_memos);
  }

  void _updateMemoFromInput(
    Memo memo,
    String content,
    bool isChecklist,
    DateTime? reminderAt,
    String? folderId,
    List<String> imagePaths,
    String reminderRepeat,
    DateTime? scheduledAt,
    DateTime? rangeEndDate,
    String scheduleRepeat,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  ) {
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i != -1) {
        final contentToSave = _contentPreservingSourceTags(_memos[i], content);
        _memos[i] = _memos[i].copyWith(
          content: contentToSave,
          isChecklist: isChecklist,
          reminderAt: reminderAt,
          clearReminder: reminderAt == null,
          reminderRepeat: reminderAt == null ? 'none' : reminderRepeat,
          scheduledAt: scheduledAt,
          clearSchedule: scheduledAt == null,
          rangeEndDate: rangeEndDate,
          clearRangeEnd: rangeEndDate == null,
          scheduleRepeat: scheduledAt == null ? 'none' : scheduleRepeat,
          repeatEndType: repeatEndType,
          repeatEndCount: repeatEndCount,
          repeatEndDate: repeatEndDate,
          clearRepeatEndDate: repeatEndDate == null,
          imagePaths: imagePaths,
          folderId: folderId,
          clearFolder: folderId == null,
          editHistory: [..._memos[i].editHistory, DateTime.now()],
        );
      }
      _editingMemo = null;
    });
    StorageService.saveMemos(_memos);
    if (reminderAt == null) {
      NotificationService.cancel(memo.id);
    } else {
      NotificationService.schedule(
        memoId: memo.id,
        content: content,
        scheduledAt: reminderAt,
        repeat: reminderRepeat,
        repeatEndDate: repeatEndDate,
      );
    }
  }

  String _contentPreservingSourceTags(Memo memo, String content) {
    if (memo.sourceUrl == null) return content;
    final submittedTags = Memo(
      id: '',
      content: content,
      createdAt: DateTime.now(),
    ).tags;
    if (submittedTags.isNotEmpty) return content;
    final existingTags = memo.tags
        .where((tag) => tag != 'habit' && tag != 'goal')
        .map((tag) => '#$tag')
        .join(' ');
    if (existingTags.isEmpty) return content;
    return [
      content.trim(),
      existingTags,
    ].where((part) => part.isNotEmpty).join('\n');
  }

  void _addImageToMemo(Memo memo, String imagePath) {
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i != -1) {
        _memos[i] = _memos[i].copyWith(
          imagePaths: [..._memos[i].imagePaths, imagePath],
        );
      }
    });
    StorageService.saveMemos(_memos);
  }

  void _deleteImageFromMemo(Memo memo, int index) {
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i != -1 && index >= 0 && index < _memos[i].imagePaths.length) {
        final paths = [..._memos[i].imagePaths];
        final removed = paths.removeAt(index);
        _memos[i] = _memos[i].copyWith(imagePaths: paths);
        ImageService.deleteImages([removed]);
      }
    });
    StorageService.saveMemos(_memos);
  }

  Future<void> _confirmAndMerge(Memo dragged, Memo target) async {
    if (dragged.id == target.id) return;
    final preview = dragged.content.length > 40
        ? '${dragged.content.substring(0, 40)}...'
        : dragged.content;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('메모 합치기', style: mono(color: kText, fontSize: 13)),
        content: Text(
          '"$preview"\n\n위 메모를 대상 메모에 합칩니다.',
          style: mono(color: kDim, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: mono(color: kDim, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('합치기', style: mono(color: kMint, fontSize: 12)),
          ),
        ],
      ),
    );
    if (confirmed == true) _mergeMemos(dragged, target);
  }

  void _reorderMemo(Memo memo, int insertBefore, List<Memo> visibleMemos) {
    final targetIndex = insertBefore.clamp(0, visibleMemos.length - 1);
    final neighbor = visibleMemos[targetIndex];
    if (neighbor.id == memo.id) return;

    final newTime = neighbor.createdAt.subtract(const Duration(seconds: 1));
    final idx = _memos.indexWhere((m) => m.id == memo.id);
    if (idx == -1) return;
    final old = _memos[idx];
    setState(() => _memos[idx] = Memo(
      id: old.id,
      content: old.content,
      createdAt: newTime,
      folderId: old.folderId,
      editHistory: old.editHistory,
      reminderAt: old.reminderAt,
      reminderRepeat: old.reminderRepeat,
      scheduledAt: old.scheduledAt,
      isChecklist: old.isChecklist,
      appendNotes: old.appendNotes,
      sourceUrl: old.sourceUrl,
      imagePaths: old.imagePaths,
      rangeEndDate: old.rangeEndDate,
      scheduleRepeat: old.scheduleRepeat,
      repeatEndType: old.repeatEndType,
      repeatEndCount: old.repeatEndCount,
      repeatEndDate: old.repeatEndDate,
    ));
    StorageService.saveMemos(_memos);
  }

  void _mergeMemos(Memo dragged, Memo target) {
    if (dragged.id == target.id) return;

    // Snapshot for undo
    final draggedSnapshot = dragged;
    final draggedIndex = _memos.indexWhere((m) => m.id == dragged.id);

    // Append dragged content as a note on target
    _addNote(target, dragged.content);

    // Delete the dragged memo
    if (dragged.reminderAt != null) NotificationService.cancel(dragged.id);
    setState(() => _memos.removeWhere((m) => m.id == dragged.id));
    StorageService.saveMemos(_memos);
    _checkAndDeleteEmptyFolder(dragged.folderId);

    // Undo snackbar
    ScaffoldMessenger.of(context).clearSnackBars();

    void doUndo() {
      final targetIdx = _memos.indexWhere((m) => m.id == target.id);
      setState(() {
        final insertAt = draggedIndex.clamp(0, _memos.length);
        _memos.insert(insertAt, draggedSnapshot);
        if (targetIdx != -1) {
          final notes = [..._memos[targetIdx].appendNotes];
          if (notes.isNotEmpty) notes.removeLast();
          _memos[targetIdx] = _memos[targetIdx].copyWith(appendNotes: notes);
        }
      });
      StorageService.saveMemos(_memos);
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kSurface,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        content: Row(
          children: [
            Text('메모를 합쳤습니다', style: mono(color: kText, fontSize: 12)),
            const Spacer(),
            GestureDetector(
              onTap: doUndo,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.undo, color: kMint, size: kFontSize + 4),
                  const SizedBox(width: 4),
                  Text(
                    '되돌리기',
                    style: mono(color: kMint, fontSize: kFontSize * 0.8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMemo(Memo memo) {
    showDialog(
      context: context,
      builder: (ctx) => _TerminalDialog(
        title: 'DELETE MEMO',
        body:
            '"${memo.content.length > 50 ? '${memo.content.substring(0, 50)}...' : memo.content}"',
        actions: [
          _DialogAction(
            label: '취소',
            color: kDim,
            onTap: () => Navigator.pop(ctx),
          ),
          _DialogAction(
            label: '삭제',
            color: Colors.red.shade400,
            onTap: () {
              Navigator.pop(ctx);
              final folderId = memo.folderId;
              if (memo.imagePaths.isNotEmpty) {
                ImageService.deleteImages(memo.imagePaths);
              }
              if (memo.reminderAt != null) {
                NotificationService.cancel(memo.id);
              }
              setState(() => _memos.removeWhere((m) => m.id == memo.id));
              StorageService.saveMemos(_memos);
              _checkAndDeleteEmptyFolder(folderId);
            },
          ),
        ],
      ),
    );
  }

  // ── Folder CRUD ────────────────────────────────────

  void _createFolder(String name, String? parentId) {
    final safeName = name.trim();
    final limitedName = safeName.length > _nameLimit
        ? safeName.substring(0, _nameLimit)
        : safeName;
    if (limitedName.isEmpty) return;
    final siblingCount = _folders.where((f) => f.parentId == parentId).length;
    final folder = Folder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: limitedName,
      parentId: parentId,
      order: siblingCount,
    );
    setState(() {
      _folders.add(folder);
      _selectedFolderId = folder.id;
    });
    StorageService.saveFolders(_folders);
  }

  void _renameFolder(String id, String newName) {
    final i = _folders.indexWhere((f) => f.id == id);
    if (i == -1) return;
    final safeName = newName.trim();
    final limitedName = safeName.length > _nameLimit
        ? safeName.substring(0, _nameLimit)
        : safeName;
    if (limitedName.isEmpty) return;
    setState(() => _folders[i] = _folders[i].copyWith(name: limitedName));
    StorageService.saveFolders(_folders);
  }

  void _deleteFolder(String id) {
    final idsToDelete = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final folder in _folders) {
        if (folder.parentId != null &&
            idsToDelete.contains(folder.parentId) &&
            idsToDelete.add(folder.id)) {
          changed = true;
        }
      }
    }

    setState(() {
      _folders.removeWhere((f) => idsToDelete.contains(f.id));
      for (var i = 0; i < _memos.length; i++) {
        if (idsToDelete.contains(_memos[i].folderId)) {
          _memos[i] = _memos[i].copyWith(clearFolder: true);
        }
      }
      if (idsToDelete.contains(_selectedFolderId)) {
        _selectedFolderId = null;
      }
      _tabs.removeWhere(
        (t) =>
            !t.isTag && t.folderId != null && idsToDelete.contains(t.folderId),
      );
      if (_selectedTabId != null && !_tabs.any((t) => t.id == _selectedTabId)) {
        _selectedTabId = null;
      }
    });
    StorageService.saveFolders(_folders);
    StorageService.saveMemos(_memos);
    StorageService.saveTabs(_tabs);
  }

  void _moveMemoToFolder(Memo memo, String? newFolderId) {
    if (memo.tags.any((t) => t == 'habit' || t == 'goal')) return;
    if (memo.folderId == newFolderId) return;
    final oldFolderId = memo.folderId;
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i == -1) return;
      _memos[i] = newFolderId == null
          ? memo.copyWith(clearFolder: true)
          : memo.copyWith(folderId: newFolderId);
    });
    StorageService.saveMemos(_memos);
    _checkAndDeleteEmptyFolder(oldFolderId);
  }

  // ── Reminders ──────────────────────────────────────

  void _setSchedule(
    Memo memo,
    DateTime? newTime, [
    String scheduleRepeat = 'none',
    DateTime? rangeEndDate,
    String repeatEndType = 'infinite',
    int repeatEndCount = 5,
    DateTime? repeatEndDate,
  ]) {
    final current = _memos.where((m) => m.id == memo.id).firstOrNull ?? memo;
    final updated = current.copyWith(
      scheduledAt: newTime,
      clearSchedule: newTime == null,
      scheduleRepeat: newTime == null ? 'none' : scheduleRepeat,
      rangeEndDate: rangeEndDate,
      clearRangeEnd: rangeEndDate == null,
      repeatEndType: repeatEndType,
      repeatEndCount: repeatEndCount,
      repeatEndDate: repeatEndDate,
      clearRepeatEndDate: repeatEndDate == null,
    );
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i != -1) _memos[i] = updated;
    });
    StorageService.saveMemos(_memos);
  }

  void _setReminder(
    Memo memo,
    DateTime? newTime, [
    String repeat = 'none',
    String repeatEndType = 'infinite',
    int repeatEndCount = 5,
    DateTime? repeatEndDate,
  ]) {
    final current = _memos.where((m) => m.id == memo.id).firstOrNull ?? memo;
    final updated = current.copyWith(
      reminderAt: newTime,
      clearReminder: newTime == null,
      reminderRepeat: newTime == null ? 'none' : repeat,
      repeatEndType: repeatEndType,
      repeatEndCount: repeatEndCount,
      repeatEndDate: repeatEndDate,
      clearRepeatEndDate: repeatEndDate == null,
    );
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i != -1) _memos[i] = updated;
    });
    StorageService.saveMemos(_memos);

    () async {
      try {
        await NotificationService.cancel(memo.id);
      } catch (_) {}
      if (newTime != null) {
        try {
          await NotificationService.schedule(
            memoId: memo.id,
            content: memo.content,
            scheduledAt: newTime,
            repeat: repeat,
            repeatEndDate: repeatEndDate,
          );
        } catch (_) {}
      }
    }();
  }

  // [3] Auto-delete folder when its last memo is removed/moved
  void _checkAndDeleteEmptyFolder(String? folderId) {
    if (folderId == null) return;
    final hasMemos = _memos.any((m) => m.folderId == folderId);
    if (hasMemos) return;
    final hasSubFolders = _folders.any((f) => f.parentId == folderId);
    if (hasSubFolders) return;
    setState(() {
      _folders.removeWhere((f) => f.id == folderId);
      if (_selectedFolderId == folderId) _selectedFolderId = null;
    });
    StorageService.saveFolders(_folders);
  }

  bool _isDescendant(String ancestorId, String checkId) {
    var currentId = checkId;
    while (true) {
      final folder = _folders.where((f) => f.id == currentId).firstOrNull;
      if (folder == null || folder.parentId == null) return false;
      if (folder.parentId == ancestorId) return true;
      currentId = folder.parentId!;
    }
  }

  int _folderDepth(String? folderId) {
    var depth = 0;
    var currentId = folderId;
    while (currentId != null) {
      final folder = _folders.where((f) => f.id == currentId).firstOrNull;
      if (folder == null) return depth;
      depth++;
      currentId = folder.parentId;
    }
    return depth;
  }

  int _folderSubtreeDepth(String folderId) {
    final children = _folders.where((f) => f.parentId == folderId).toList();
    if (children.isEmpty) return 1;
    return 1 +
        children
            .map((f) => _folderSubtreeDepth(f.id))
            .reduce((a, b) => a > b ? a : b);
  }

  void _moveFolder(String folderId, String? newParentId, int insertIndex) {
    if (folderId == newParentId) return;
    if (newParentId != null && _isDescendant(folderId, newParentId)) return;

    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    if (_folderDepth(newParentId) + _folderSubtreeDepth(folderId) > 5) return;

    setState(() {
      final moved = _folders[idx];
      var targetIndex = insertIndex;
      if (moved.parentId == newParentId && moved.order < targetIndex) {
        targetIndex--;
      }
      final siblings =
          _folders
              .where((f) => f.parentId == newParentId && f.id != folderId)
              .toList()
            ..sort(
              (a, b) => a.order != b.order
                  ? a.order.compareTo(b.order)
                  : a.name.compareTo(b.name),
            );

      final pos = targetIndex.clamp(0, siblings.length);

      for (int i = 0; i < siblings.length; i++) {
        final newOrder = i < pos ? i : i + 1;
        final si = _folders.indexWhere((f) => f.id == siblings[i].id);
        if (si != -1) {
          _folders[si] = Folder(
            id: siblings[i].id,
            name: siblings[i].name,
            parentId: siblings[i].parentId,
            order: newOrder,
          );
        }
      }
      _folders[idx] = Folder(
        id: moved.id,
        name: moved.name,
        parentId: newParentId,
        order: pos,
      );
    });
    StorageService.saveFolders(_folders);
  }

  // ── Tab management ─────────────────────────────────

  void _addTab(QuickTab tab) {
    if (_tabs.length >= 5) return;
    // Prevent duplicate folder/tag tabs
    final duplicate = _tabs.any((t) {
      if (t.isTag != tab.isTag) return false;
      if (tab.isTag) return t.tag == tab.tag;
      return t.folderId == tab.folderId;
    });
    if (duplicate) return;
    setState(() => _tabs.add(tab));
    StorageService.saveTabs(_tabs);
  }

  void _updateTab(QuickTab tab) {
    setState(() {
      final i = _tabs.indexWhere((t) => t.id == tab.id);
      if (i != -1) _tabs[i] = tab;
    });
    StorageService.saveTabs(_tabs);
  }

  void _deleteTab(String id) {
    setState(() {
      if (_selectedTabId == id) _selectedTabId = null;
      _tabs.removeWhere((t) => t.id == id);
    });
    StorageService.saveTabs(_tabs);
  }

  void _selectTab(QuickTab tab) {
    setState(() {
      _selectedTabId = tab.id;
      _calendarOpen = false;
      _statsOpen = false;
      if (tab.isTag && tab.tag != null) {
        _selectedTag = tab.tag;
        _selectedFolderId = null;
      } else {
        _selectedFolderId = tab.folderId;
        _selectedTag = null;
      }
    });
  }

  List<String> _sanitizeBottomMenus(List<String> menus) {
    final result = <String>[];
    for (final menu in menus) {
      final upper = menu.toUpperCase();
      if (upper == 'SEARCH') continue;
      if (!nemo2TestMenuOptions.contains(upper) && upper != 'MORE') continue;
      if (result.contains(upper)) continue;
      result.add(upper);
      if (result.length == 4) break;
    }
    for (final fallback in const ['TODAY', 'LIST', 'CAL', 'MORE']) {
      if (result.length == 4) break;
      if (!result.contains(fallback)) result.add(fallback);
    }
    return result;
  }

  String get _activeBottomMenu {
    if (_todayOpen) return 'TODAY';
    if (_calendarOpen) return 'CAL';
    if (_scheduleOpen) return 'EVENTS';
    if (_tasksOnly) return 'TASKS';
    if (_selectedTag == 'habit') return 'HABITS';
    if (_selectedTag == 'goal') return 'GOALS';
    if (_statsOpen) return 'STATS';
    if (_tagsOpen) return 'TAGS';
    if (_graphOpen) return 'GRAPH';
    if (_brainOpen) return 'BRAIN';
    return 'LIST';
  }

  void _selectBottomMenu(String menu, {bool narrow = false}) {
    switch (menu) {
      case 'TODAY':
        setState(() {
          _todayOpen = true;
          _calendarOpen = false;
          _statsOpen = false;
          _scheduleOpen = false;
          _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
          _tasksOnly = false;
          _selectedTabId = null;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'CAL':
        setState(() {
          _calendarOpen = true;
          _selectedTabId = null;
          _statsOpen = false;
          _scheduleOpen = false;
          _todayOpen = false;
          _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
          _tasksOnly = false;
          _selectedTag = null;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'EVENTS':
        setState(() {
          _scheduleOpen = true;
          _statsOpen = false;
          _calendarOpen = false;
          _tasksOnly = false;
          _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
          _todayOpen = false;
          _selectedTabId = null;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'TASKS':
        setState(() {
          _tasksOnly = true;
          _calendarOpen = false;
          _statsOpen = false;
          _scheduleOpen = false;
          _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
          _todayOpen = false;
          _selectedTag = null;
          _selectedFolderId = null;
          _selectedTabId = null;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'HABITS':
        setState(() {
          _selectedTag = 'habit';
          _selectedFolderId = null;
          _selectedTabId = null;
          _tasksOnly = false;
          _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
          _calendarOpen = false;
          _statsOpen = false;
          _scheduleOpen = false;
          _todayOpen = false;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'GOALS':
        setState(() {
          _selectedTag = 'goal';
          _selectedFolderId = null;
          _selectedTabId = null;
          _tasksOnly = false;
          _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
          _calendarOpen = false;
          _statsOpen = false;
          _scheduleOpen = false;
          _todayOpen = false;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'STATS':
        setState(() {
          _statsOpen = true;
          _calendarOpen = false;
          _scheduleOpen = false;
          _todayOpen = false;
          _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
          _tasksOnly = false;
          _selectedTabId = null;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'SETTINGS':
        _showSettings();
        break;
      case 'TAGS':
        setState(() {
          _tagsOpen = true;
          _tasksOnly = false;
          _calendarOpen = false;
          _statsOpen = false;
          _scheduleOpen = false;
          _todayOpen = false;
          _graphOpen = false;
          _brainOpen = false;
          _selectedTag = null;
          _selectedFolderId = null;
          _selectedTabId = null;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'GRAPH':
        setState(() {
          _graphOpen = true;
          _brainOpen = false;
          _tagsOpen = false;
          _tasksOnly = false;
          _calendarOpen = false;
          _statsOpen = false;
          _scheduleOpen = false;
          _todayOpen = false;
          _selectedTag = null;
          _selectedFolderId = null;
          _selectedTabId = null;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'BRAIN':
        setState(() {
          _brainOpen = true;
          _graphOpen = false;
          _tagsOpen = false;
          _tasksOnly = false;
          _calendarOpen = false;
          _statsOpen = false;
          _scheduleOpen = false;
          _todayOpen = false;
          _selectedTag = null;
          _selectedFolderId = null;
          _selectedTabId = null;
          if (narrow) _sidebarOpen = false;
        });
        break;
      case 'MORE':
        setState(() => _sidebarOpen = true);
        break;
      case 'LIST':
      default:
        setState(() {
          _selectedFolderId = null;
          _selectedTag = null;
          _selectedTabId = null;
          _calendarOpen = false;
          _statsOpen = false;
          _scheduleOpen = false;
          _tasksOnly = false;
          _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
          _todayOpen = false;
          _searchOpen = false;
          if (narrow) _sidebarOpen = false;
        });
    }
  }

  void _showBottomMenuReplaceSheet(int index) {
    final current = _bottomMenus[index];
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            children: [
              Text('REPLACE $current', style: mono(color: kMint, fontSize: 12)),
              const SizedBox(height: 8),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 6),
              ...nemo2TestMenuOptions.map((menu) {
                final duplicate =
                    _bottomMenus.contains(menu) && menu != current;
                return Opacity(
                  opacity: duplicate ? 0.35 : 1,
                  child: ListTile(
                    dense: true,
                    title: Text(menu, style: mono(color: kText, fontSize: 13)),
                    trailing: duplicate
                        ? Text('USED', style: mono(color: kDim, fontSize: 10))
                        : null,
                    onTap: duplicate
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            setState(() => _bottomMenus[index] = menu);
                            StorageService.saveBottomMenus(_bottomMenus);
                            _selectBottomMenu(menu);
                          },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showTabDialog(QuickTab? existing) {
    showDialog(
      context: context,
      builder: (_) => TabEditDialog(
        tab: existing,
        folders: _folders,
        allTags: _allTags,
        onSave: (tab) => existing == null ? _addTab(tab) : _updateTab(tab),
        onDelete: existing != null ? () => _deleteTab(existing.id) : null,
      ),
    );
  }

  void _confirmDeleteTab(QuickTab tab) {
    showDialog(
      context: context,
      builder: (ctx) => _TerminalDialog(
        title: 'DELETE TAB',
        body: '"${tab.label}" 탭을 삭제하시겠습니까?',
        actions: [
          _DialogAction(
            label: '취소',
            color: kDim,
            onTap: () => Navigator.pop(ctx),
          ),
          _DialogAction(
            label: '삭제',
            color: Colors.red.shade400,
            onTap: () {
              Navigator.pop(ctx);
              _deleteTab(tab.id);
            },
          ),
        ],
      ),
    );
  }

  // ── Computed tag data ──────────────────────────────

  List<String> get _allTags => collectVisibleTags(_memos);

  Map<String, int> get _tagCounts => countTags(_memos);

  int get _taskCount => _memos.where((m) => m.isChecklist).length;
  int get _habitCount => _memos.where((m) => m.tags.contains('habit')).length;

  MemoActions get _memoActions => MemoActions(
    folders: _folders,
    onDelete: _deleteMemo,
    onEditRequest: (memo) {
      setState(() => _editingMemo = memo);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _inputBarKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: 1,
          );
        }
      });
    },
    onUpdate: (m, c) => _updateMemo(m.id, c),
    onMove: _moveMemoToFolder,
    onSetReminder: _setReminder,
    onSetSchedule: _setSchedule,
    onAddNote: _addNote,
    onUpdateNote: _updateNote,
    onDeleteNote: _deleteNote,
    onMerge: _mergeMemos,
    onAddImage: _addImageToMemo,
    onDeleteImage: _deleteImageFromMemo,
    onTagTap: (tag) => setState(() => _selectedTag = tag),
    onNavigateToMemo: _navigateToMemo,
    onWikiLinkTap: (linkText) {
      final q = linkText.trim().toLowerCase();
      final match = _memos.where((m) {
        final first = m.content.split('\n').first.toLowerCase();
        return first.contains(q);
      }).firstOrNull ?? LocalSearchService.search(linkText, _memos).firstOrNull;
      if (match != null) _navigateToMemo(match.id);
    },
  );

  String get _activeSidebarSection {
    if (_calendarOpen) return 'calendar';
    if (_statsOpen) return 'stats';
    if (_scheduleOpen) return 'event';
    if (_todayOpen) return 'today';
    if (_searchOpen) return 'search';
    if (_tasksOnly) return 'tasks';
    if (_tagsOpen) return 'tags';
    if (_graphOpen) return 'graph';
    if (_brainOpen) return 'brain';
    if (_selectedTag == 'habit') return 'habits';
    if (_selectedTag == 'goal') return 'goals';
    return 'memo';
  }

  int get _streak {
    if (_memos.isEmpty) return 0;
    final days =
        _memos
            .map((m) {
              final d = m.createdAt;
              return DateTime(d.year, d.month, d.day);
            })
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime check;
    if (days.contains(today)) {
      check = today;
    } else if (days.contains(yesterday)) {
      check = yesterday;
    } else {
      return 0;
    }
    int streak = 0;
    for (final day in days) {
      if (day == check) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else if (day.isBefore(check)) {
        break;
      }
    }
    return streak;
  }

  // ── List builder ───────────────────────────────────

  List<Object> _buildFlatList() {
    final List<Memo> visible;
    if (_tasksOnly) {
      visible = _memos.where((m) => m.isChecklist).toList();
    } else if (_selectedTag != null) {
      // Tag filter: all memos containing this tag (across folders)
      visible = _memos.where((m) => m.tags.contains(_selectedTag)).toList();
    } else {
      visible = _memos.where((m) => m.folderId == _selectedFolderId).toList();
    }
    final grouped = <String, List<Memo>>{};
    for (final memo in visible) {
      grouped.putIfAbsent(_listDateKey(memo), () => []).add(memo);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final items = <Object>[];
    for (final dateKey in sortedDates) {
      items.add(dateKey);
      if (!_collapsedDates.contains(dateKey)) {
        final dayMemos = grouped[dateKey]!
          ..sort((a, b) => _listSortDate(b).compareTo(_listSortDate(a)));
        items.addAll(dayMemos);
      }
    }
    return items;
  }

  List<Object> _buildLogroomFlatList() {
    final List<Memo> visible;
    if (_tasksOnly) {
      visible = _memos.where((m) => m.isChecklist).toList();
    } else if (_selectedTag != null) {
      visible = _memos.where((m) => m.tags.contains(_selectedTag)).toList();
    } else {
      visible = _memos.where((m) => m.folderId == _selectedFolderId).toList();
    }
    visible.sort((a, b) => _listSortDate(b).compareTo(_listSortDate(a)));
    final grouped = <String, List<Memo>>{};
    for (final memo in visible) {
      grouped
          .putIfAbsent(_logroomGroupKey(_listSortDate(memo)), () => [])
          .add(memo);
    }
    _logroomHourSlots.clear();
    _logroomDaySummaries.clear();
    final items = <Object>[];
    for (final entry in grouped.entries) {
      final key = entry.key;
      items.add(key);
      // compute day summary (count + top tags) — always, regardless of collapse
      final tagCounts = <String, int>{};
      for (final m in entry.value) {
        for (final t in m.tags) {
          tagCounts[t] = (tagCounts[t] ?? 0) + 1;
        }
      }
      final topTags = (tagCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(4)
          .map((e) => (tag: e.key, n: e.value))
          .toList();
      _logroomDaySummaries[key] = DaySummary(
        count: entry.value.length,
        topTags: topTags,
      );
      final autoCollapsed = _isAutoCollapsedLogroomGroup(key);
      final collapsed = autoCollapsed
          ? !_expandedLogroomGroups.contains(key)
          : _collapsedDates.contains(key);
      if (!autoCollapsed) {
        _logroomHourSlots[key] = _computeHourSlots(entry.value);
        // Pre-populate memoKeys so _scrollToMemo can look them up before rendering
        for (final m in entry.value) {
          _memoKeys.putIfAbsent(m.id, () => GlobalKey());
        }
      }
      if (!collapsed) {
        final hourCounts = <int, int>{};
        for (final m in entry.value) {
          hourCounts[m.createdAt.hour] = (hourCounts[m.createdAt.hour] ?? 0) + 1;
        }
        int? lastHour;
        DateTime? lastMemoTime;
        for (final m in entry.value) {
          final h = _listSortDate(m).hour;
          final memoTime = _listSortDate(m);
          if (lastMemoTime != null) {
            final gapMin = lastMemoTime.difference(memoTime).inMinutes;
            if (gapMin >= 120) items.add(_SilenceGap(gapMin));
          }
          if (lastHour == null || h != lastHour) {
            items.add(_HourMarker(h, count: hourCounts[h] ?? 0));
            lastHour = h;
          }
          items.add(m);
          lastMemoTime = memoTime;
        }
      }
    }
    return items;
  }

  List<HourSlot> _computeHourSlots(List<Memo> memos) {
    final buckets = <int, List<String>>{};
    for (final m in memos) {
      buckets.putIfAbsent(m.createdAt.hour, () => []).add(m.id);
    }
    final hours = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return hours
        .map((h) => HourSlot(hour: h, count: buckets[h]!.length, firstMemoId: buckets[h]!.first))
        .toList();
  }

  // v3 hour group marker — inserted between memo entries when hour changes.
  // Left lane (26px) mirrors _LogroomTimelineLane: full-height line + larger dot.
  // Right side: time text + entry count + faint horizontal rule. Does not collapse.
  Widget _buildHourMarker(int hour, {int count = 0}) {
    final timeLabel = '${hour.toString().padLeft(2, '0')}:00';
    final label = count > 0 ? '$timeLabel · $count' : timeLabel;
    return Container(
      color: kBg,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline lane — mirrors _LogroomTimelineLane width
            SizedBox(
              width: appSpace(34),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Continuous vertical line
                  Positioned(
                    left: appSpace(16) - 0.5,
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: Container(color: kTlLine),
                  ),
                  // Larger hollow dot — signals a time group boundary
                  Positioned(
                    left: appSpace(16) - appSpace(4),
                    top: appSpace(10),
                    child: Container(
                      width: appSpace(8),
                      height: appSpace(8),
                      decoration: BoxDecoration(
                        color: kBg4,
                        shape: BoxShape.circle,
                        border: Border.all(color: kTlDot, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Time label + horizontal rule
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(appSpace(6), appSpace(7), appSpace(12), appSpace(7)),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: tsMeta * (kFontSize / 13.0),
                        color: kText3,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(width: appSpace(8)),
                    Expanded(
                      child: Container(height: 1, color: kTlLine),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSilenceGap(int minutes) {
    final h = minutes ~/ 60;
    final label = h >= 1 ? '${h}h' : '${minutes}m';
    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: appSpace(34),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: appSpace(16) - 0.5,
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: Container(color: kTlLine.withValues(alpha: 0.35)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(appSpace(6), 0, appSpace(12), 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(height: 1, color: kTlLine.withValues(alpha: 0.25)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Text(
                      label,
                      style: mono(color: kText3.withValues(alpha: 0.30), fontSize: tsMeta),
                    ),
                  ),
                  Expanded(
                    child: Container(height: 1, color: kTlLine.withValues(alpha: 0.25)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToMemo(String memoId) {
    void onFound() {
      final k = _memoKeys[memoId];
      if (k?.currentContext == null) return;
      debugPrint('[HourToc] ensureVisible: $memoId');
      Scrollable.ensureVisible(
        k!.currentContext!,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.05,
      );
      if (mounted) setState(() => _highlightedMemoId = memoId);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _highlightedMemoId = null);
      });
    }

    final key = _memoKeys[memoId];
    if (key?.currentContext != null) {
      onFound();
      return;
    }

    if (!_scrollController.hasClients) return;
    final idx = _flatItems.indexWhere((it) => it is Memo && it.id == memoId);
    debugPrint('[HourToc] idx=$idx / ${_flatItems.length}');
    if (idx < 0) return;

    final maxExtent = _scrollController.position.maxScrollExtent;
    final vp = _scrollController.position.viewportDimension;
    final estimated = ((idx / _flatItems.length) * maxExtent).clamp(0.0, maxExtent);
    debugPrint('[HourToc] estimated=$estimated maxExtent=$maxExtent vp=$vp');

    _scrollController
        .animateTo(estimated, duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
        .then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_memoKeys[memoId]?.currentContext != null) {
          onFound();
        } else {
          debugPrint('[HourToc] scan start');
          _scrollToMemoScan(memoId, estimated, maxExtent, vp, onFound, 0);
        }
      });
    });
  }

  void _scrollToMemoScan(
    String memoId,
    double base,
    double maxExtent,
    double vp,
    VoidCallback onFound,
    int attempt,
  ) {
    if (attempt >= 8) {
      debugPrint('[HourToc] scan failed after 8 attempts');
      return;
    }
    // Forward-biased scan (recent entries tend to be taller → actual pos > estimate)
    final offsets = [vp, vp * 2, vp * 3, vp * 4, vp * 5, -vp, -vp * 2, -vp * 3];
    final target = (base + offsets[attempt]).clamp(0.0, maxExtent);
    debugPrint('[HourToc] scan attempt $attempt → $target');
    _scrollController.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_memoKeys[memoId]?.currentContext != null) {
        debugPrint('[HourToc] scan hit at attempt $attempt');
        onFound();
      } else {
        _scrollToMemoScan(memoId, base, maxExtent, vp, onFound, attempt + 1);
      }
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  DateTime _listSortDate(Memo memo) => memo.createdAt;

  String _listDateKey(Memo memo) {
    final d = _listSortDate(memo);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _logroomGroupKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    if (day == today) return '오늘';
    if (!day.isBefore(weekStart)) return _logroomDateLabel(dt);
    if (dt.year == now.year && dt.month == now.month) {
      final week = ((dt.day - 1) ~/ 7) + 1;
      return '${dt.year} ${dt.month.toString().padLeft(2, '0')}월 $week주차';
    }
    if (dt.year == now.year) {
      return '${dt.year} ${dt.month.toString().padLeft(2, '0')}월';
    }
    return '${dt.year}';
  }

  String _logroomDateLabel(DateTime dt) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${weekdays[dt.weekday - 1]}';
  }

  bool _isAutoCollapsedLogroomGroup(String key) {
    if (key == '오늘') return false;
    if (RegExp(r'^\d{2}\.\d{2} ').hasMatch(key)) return false;
    return true;
  }

  // ── Settings ───────────────────────────────────────

  static int _colorToInt(Color c) {
    int ch(double v) => (v * 255.0).round().clamp(0, 255);
    return (0xFF << 24) | (ch(c.r) << 16) | (ch(c.g) << 8) | ch(c.b);
  }

  Map<String, dynamic> _buildSettingsMap() => {
    'bg_color': _colorToInt(kBg),
    'text_color': _colorToInt(kText),
    'font_family': kFontFamily,
    'font_size': kFontSize,
    'tab_locked': _tabLocked,
    'entry_display_mode': entryDisplayModeNotifier.value.storageValue,
    'app_theme_mode': appThemeModeNotifier.value.storageValue,
  };

  void _applyBackupData(Map<String, dynamic> backup, {bool merge = false}) {
    final backupMemos =
        (backup['memos'] as List?)
            ?.map((e) => Memo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final backupFolders =
        (backup['folders'] as List?)
            ?.map((e) => Folder.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final backupTabs =
        (backup['tabs'] as List?)
            ?.map((e) => QuickTab.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final settings = backup['settings'] as Map<String, dynamic>?;

    final List<Memo> memos;
    final List<Folder> folders;
    final List<QuickTab> tabs;

    if (merge) {
      final existingMemoIds = _memos.map((m) => m.id).toSet();
      final existingFolderIds = _folders.map((f) => f.id).toSet();
      final existingTabIds = _tabs.map((t) => t.id).toSet();
      memos = [
        ..._memos,
        ...backupMemos.where((m) => !existingMemoIds.contains(m.id)),
      ];
      folders = [
        ..._folders,
        ...backupFolders.where((f) => !existingFolderIds.contains(f.id)),
      ];
      tabs = [
        ..._tabs,
        ...backupTabs.where((t) => !existingTabIds.contains(t.id)),
      ];
    } else {
      memos = backupMemos;
      folders = backupFolders;
      tabs = backupTabs;
    }

    setState(() {
      _memos
        ..clear()
        ..addAll(memos);
      _folders
        ..clear()
        ..addAll(folders);
      _tabs
        ..clear()
        ..addAll(tabs);
      _selectedFolderId = null;
      _selectedTag = null;
      _selectedTabId = null;
      if (settings != null) {
        _tabLocked = (settings['tab_locked'] as bool?) ?? false;
      }
    });

    StorageService.saveMemos(_memos);
    StorageService.saveFolders(_folders);
    StorageService.saveTabs(_tabs);
    StorageService.saveTabLocked(_tabLocked);

    if (settings != null) {
      final bgInt = settings['bg_color'] as int?;
      final textInt = settings['text_color'] as int?;
      if (bgInt != null && textInt != null) {
        final bg = Color(bgInt);
        final text = Color(textInt);
        if (isLogroomUi) {
          applyColors(bg, text);
        } else {
          applyColors(bg, text);
        }
        StorageService.saveColors(bg, text);
      }
      final fontFamily = settings['font_family'] as String?;
      final fontSize = (settings['font_size'] as num?)?.toDouble();
      if (fontFamily != null && fontSize != null) {
        applyFont(fontFamily, fontSize);
        StorageService.saveFont(fontFamily, fontSize);
      }
      final entryDisplayMode = EntryDisplayModeX.parse(
        settings['entry_display_mode'] as String?,
      );
      applyEntryDisplayMode(entryDisplayMode);
      StorageService.saveEntryDisplayMode(entryDisplayMode);
      final appThemeMode = AppThemeModeX.parse(
        settings['app_theme_mode'] as String?,
      );
      applyAppThemeMode(appThemeMode);
      StorageService.saveAppThemeMode(appThemeMode);
    }
  }

  void _showSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SettingsScreen(
          initialBg: kBg,
          initialText: kText,
          initialTabLocked: _tabLocked,
          initialFontFamily: kFontFamily,
          initialFontSize: kFontSize,
          onSave: (bg, text, fontFamily, fontSize, tabLocked) {
            if (isLogroomUi) {
              applyColors(bg, text);
            } else {
              applyColors(bg, text);
            }
            StorageService.saveColors(bg, text);
            StorageService.saveFont(fontFamily, fontSize);
            StorageService.saveTabLocked(tabLocked);
            setState(() => _tabLocked = tabLocked);
          },
          onBackupSave: () => BackupService.exportToPhone(
            memos: _memos,
            folders: _folders,
            tabs: _tabs,
            settings: _buildSettingsMap(),
          ),
          onRestoreConfirmed: _applyBackupData,
          onClearCache: _clearAllCache,
          onImportTxt: _importTxtMemos,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeInOut)),
          child: child,
        ),
      ),
    );
  }

  void _importTxtMemos(List<String> blocks) {
    final now = DateTime.now();
    final imported = List.generate(
      blocks.length,
      (i) => Memo(
        id: (now.millisecondsSinceEpoch + i).toString(),
        content: blocks[i],
        createdAt: now.add(Duration(milliseconds: i)),
        folderId: _selectedFolderId,
      ),
    );
    setState(() => _memos.addAll(imported));
    StorageService.saveMemos(_memos);
  }

  void _clearAllCache() {
    StorageService.clearAll();
    applyColors(const Color(0xFFEDF2ED), const Color(0xFF556B2F));
    applyFont('JetBrains Mono', 13.0);
    setState(() {
      _memos.clear();
      _folders.clear();
      _tabs.clear();
      _bottomMenus
        ..clear()
        ..addAll(const ['TODAY', 'LIST', 'CAL', 'MORE']);
      _tabLocked = false;
      _selectedFolderId = null;
      _selectedTag = null;
      _selectedTabId = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeNotifier.removeListener(_onThemeChanged);
    NotificationService.pendingMemoId.removeListener(_onPendingNotification);
    NotificationService.onNotificationTap = null;
    _shareSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleBackPress(BuildContext context) async {
    final isNarrow = MediaQuery.of(context).size.width < _kNarrowBreak;

    if (_searchOpen) {
      setState(() {
        _searchOpen = false;
        _searchQuery = '';
      });
      return;
    }

    if (isNarrow && _sidebarOpen) {
      setState(() => _sidebarOpen = false);
      return;
    }

    if (_todayOpen || _calendarOpen || _statsOpen || _scheduleOpen || _tasksOnly || _tagsOpen || _graphOpen || _brainOpen) {
      setState(() {
        _todayOpen = false;
        _calendarOpen = false;
        _statsOpen = false;
        _scheduleOpen = false;
        _tasksOnly = false;
        _tagsOpen = false;
        _graphOpen = false;
        _brainOpen = false;
      });
      return;
    }

    if (_selectedFolderId != null || _selectedTag != null || _selectedTabId != null) {
      setState(() {
        _selectedFolderId = null;
        _selectedTag = null;
        _selectedTabId = null;
      });
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('앱 종료', style: TextStyle(color: kText, fontSize: tsHeading, fontFamily: kFontFamily)),
        content: Text('앱을 종료하시겠습니까?', style: TextStyle(color: kText, fontSize: tsBody, fontFamily: kFontFamily)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('취소', style: TextStyle(color: kDim, fontFamily: kFontFamily)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('종료', style: TextStyle(color: kMint, fontFamily: kFontFamily)),
          ),
        ],
      ),
    );

    if (shouldExit == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final items =
        (_calendarOpen ||
            _statsOpen ||
            _scheduleOpen ||
            _tagsOpen ||
            _todayOpen ||
            _graphOpen ||
            _brainOpen)
        ? const <Object>[]
        : (isLogroomUi ? _buildLogroomFlatList() : _buildFlatList());
    _flatItems = items;
    // Header path
    final folderName = _selectedFolderId == null
        ? (isNemo2Test ? '/INBOX' : '/inbox')
        : '/${_folders.firstWhere(
            (f) => f.id == _selectedFolderId,
            orElse: () => Folder(id: '', name: isNemo2Test ? 'INBOX' : 'inbox'),
          ).name}';
    final selectedPath = _calendarOpen
        ? 'CAL'
        : (_statsOpen
              ? 'STATS'
              : (_scheduleOpen
                    ? 'event'
                    : (_todayOpen
                          ? 'TODAY'
                          : (_tagsOpen
                                ? 'tags'
                                : (_tasksOnly
                                      ? 'tasks'
                                      : (_selectedTag != null &&
                                                _selectedFolderId != null
                                            ? '$folderName  #$_selectedTag'
                                            : (_selectedTag != null
                                                  ? '#$_selectedTag'
                                                  : folderName)))))));

    final allTags = _allTags;
    final tagCounts = _tagCounts;
    final streak = _streak;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPress(context);
      },
      child: Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < _kNarrowBreak;

            final sidebar = Sidebar(
              favorites: _tabs,
              onSelectFavorite: (tab) {
                _selectTab(tab);
                if (isNarrow) setState(() => _sidebarOpen = false);
              },
              onSelectMemo: () => setState(() {
                _selectedFolderId = null;
                _selectedTag = null;
                _selectedTabId = null;
                _calendarOpen = false;
                _statsOpen = false;
                _scheduleOpen = false;
                _tasksOnly = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                _todayOpen = false;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectCalendar: () => setState(() {
                _calendarOpen = true;
                _statsOpen = false;
                _scheduleOpen = false;
                _tasksOnly = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                _todayOpen = false;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectToday: () => setState(() {
                _todayOpen = true;
                _calendarOpen = false;
                _statsOpen = false;
                _scheduleOpen = false;
                _tasksOnly = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectTasks: () => setState(() {
                _tasksOnly = true;
                _calendarOpen = false;
                _statsOpen = false;
                _scheduleOpen = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                _todayOpen = false;
                _selectedTag = null;
                _selectedFolderId = null;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectTags: () => setState(() {
                _tagsOpen = true;
                _tasksOnly = false;
                _calendarOpen = false;
                _statsOpen = false;
                _scheduleOpen = false;
                _todayOpen = false;
                _selectedTag = null;
                _selectedFolderId = null;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectSearch: () {
                if (isNarrow) setState(() => _sidebarOpen = false);
                _openSearch();
              },
              onSelectStats: () => setState(() {
                _statsOpen = true;
                _calendarOpen = false;
                _scheduleOpen = false;
                _tasksOnly = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                _todayOpen = false;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectSchedule: () => setState(() {
                _scheduleOpen = true;
                _statsOpen = false;
                _calendarOpen = false;
                _tasksOnly = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                _todayOpen = false;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectGraph: () => setState(() {
                _graphOpen = true;
                _brainOpen = false;
                _statsOpen = false;
                _calendarOpen = false;
                _scheduleOpen = false;
                _tasksOnly = false;
                _tagsOpen = false;
                _todayOpen = false;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectBrain: () => setState(() {
                _brainOpen = true;
                _graphOpen = false;
                _statsOpen = false;
                _calendarOpen = false;
                _scheduleOpen = false;
                _tasksOnly = false;
                _tagsOpen = false;
                _todayOpen = false;
                _selectedTag = null;
                _selectedFolderId = null;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSettingsTap: () {
                if (isNarrow) setState(() => _sidebarOpen = false);
                _showSettings();
              },
              onCreate: _createFolder,
              onRenameFolder: _renameFolder,
              onDeleteFolder: _deleteFolder,
              onMoveFolder: _moveFolder,
              activeSection: _activeSidebarSection,
              folders: _folders,
              selectedFolderId: _selectedFolderId,
              onSelectFolder: (id) => setState(() {
                _selectedFolderId = id;
                _selectedTag = null;
                _selectedTabId = null;
                _calendarOpen = false;
                _statsOpen = false;
                _scheduleOpen = false;
                _tasksOnly = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                _todayOpen = false;
                if (isNarrow) _sidebarOpen = false;
              }),
              dayCount: _dayCount,
              habitActivated: _habitActivated,
              goalActivated: _goalActivated,
              streak: streak,
              onActivateHabit: _activateHabit,
              onActivateGoal: _activateGoal,
              onSelectHabit: () => setState(() {
                _selectedTag = 'habit';
                _selectedFolderId = null;
                _selectedTabId = null;
                _tasksOnly = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                _calendarOpen = false;
                _statsOpen = false;
                _scheduleOpen = false;
                _todayOpen = false;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectGoal: () => setState(() {
                _selectedTag = 'goal';
                _selectedFolderId = null;
                _selectedTabId = null;
                _tasksOnly = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                _calendarOpen = false;
                _statsOpen = false;
                _scheduleOpen = false;
                _todayOpen = false;
                if (isNarrow) _sidebarOpen = false;
              }),
              noteCount: _memos.length,
              taskCount: _taskCount,
              habitCount: _habitCount,
              allTags: allTags,
              tagCounts: tagCounts,
              selectedTag: _selectedTag,
              onSelectTag: (tag) => setState(() {
                _selectedTag = tag;
                _selectedFolderId = null;
                _selectedTabId = null;
                _calendarOpen = false;
                _statsOpen = false;
                _scheduleOpen = false;
                _tasksOnly = false;
                _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                if (isNarrow) _sidebarOpen = false;
              }),
            );

            final mainContent = Column(
              children: [
                _AppHeader(
                  sidebarOpen: _sidebarOpen,
                  isNarrow: isNarrow,
                  onToggle: () => setState(() => _sidebarOpen = !_sidebarOpen),
                  selectedPath: selectedPath,
                  calendarOpen: _calendarOpen,
                  statsOpen: _statsOpen,
                  scheduleOpen: _scheduleOpen,
                  todayOpen: _todayOpen,
                  tagsOpen: _tagsOpen,
                  tasksOnly: _tasksOnly,
                  onShowList: () => setState(() {
                    _calendarOpen = false;
                    _statsOpen = false;
                    _scheduleOpen = false;
                    _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                    _tasksOnly = false;
                    _todayOpen = false;
                  }),
                  onShowCal: () => setState(() {
                    _calendarOpen = true;
                    _selectedTabId = null;
                    _statsOpen = false;
                    _scheduleOpen = false;
                    _todayOpen = false;
                    _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                    _tasksOnly = false;
                    _selectedTag = null;
                    if (isNarrow) _sidebarOpen = false;
                  }),
                  onSelectStats: () => setState(() {
                    _statsOpen = true;
                    _calendarOpen = false;
                    _scheduleOpen = false;
                    _todayOpen = false;
                    _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                    _tasksOnly = false;
                    _selectedTabId = null;
                    if (isNarrow) _sidebarOpen = false;
                  }),
                  onSelectToday: () => setState(() {
                    _todayOpen = true;
                    _calendarOpen = false;
                    _statsOpen = false;
                    _scheduleOpen = false;
                    _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                    _tasksOnly = false;
                    _selectedTabId = null;
                    if (isNarrow) _sidebarOpen = false;
                  }),
                  searchOpen: _searchOpen,
                  onSearchTap: () {
                    if (_searchOpen) {
                      _closeSearch();
                    } else {
                      _openSearch();
                    }
                  },
                  folders: _folders,
                  selectedFolderId: _selectedFolderId,
                  onSelectFolder: (id) => setState(() {
                    _selectedFolderId = id;
                    _selectedTag = null;
                    _selectedTabId = null;
                    _scheduleOpen = false;
                    _calendarOpen = false;
                    _statsOpen = false;
                    _tasksOnly = false;
                    _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                    _todayOpen = false;
                  }),
                  onSelectSchedule: () => setState(() {
                    _scheduleOpen = true;
                    _statsOpen = false;
                    _calendarOpen = false;
                    _tasksOnly = false;
                    _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                    _todayOpen = false;
                    _selectedTabId = null;
                    if (isNarrow) _sidebarOpen = false;
                  }),
                  onSelectTasks: () => setState(() {
                    _tasksOnly = true;
                    _calendarOpen = false;
                    _statsOpen = false;
                    _scheduleOpen = false;
                    _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                    _todayOpen = false;
                    _selectedTag = null;
                    _selectedFolderId = null;
                    _selectedTabId = null;
                    if (isNarrow) _sidebarOpen = false;
                  }),
                  onSelectTags: () => setState(() {
                    _tagsOpen = true;
                    _tasksOnly = false;
                    _calendarOpen = false;
                    _statsOpen = false;
                    _scheduleOpen = false;
                    _todayOpen = false;
                    _selectedTag = null;
                    _selectedFolderId = null;
                    _selectedTabId = null;
                    if (isNarrow) _sidebarOpen = false;
                  }),
                  onSelectHabit: () => setState(() {
                    _selectedTag = 'habit';
                    _selectedFolderId = null;
                    _selectedTabId = null;
                    _tasksOnly = false;
                    _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                    _calendarOpen = false;
                    _statsOpen = false;
                    _scheduleOpen = false;
                    _todayOpen = false;
                    if (isNarrow) _sidebarOpen = false;
                  }),
                  onSelectGoal: () => setState(() {
                    _selectedTag = 'goal';
                    _selectedFolderId = null;
                    _selectedTabId = null;
                    _tasksOnly = false;
                    _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                    _calendarOpen = false;
                    _statsOpen = false;
                    _scheduleOpen = false;
                    _todayOpen = false;
                    if (isNarrow) _sidebarOpen = false;
                  }),
                  onSelectGraph: () => setState(() {
                    _graphOpen = true;
                    _statsOpen = false;
                    _calendarOpen = false;
                    _scheduleOpen = false;
                    _tasksOnly = false;
                    _tagsOpen = false;
                    _todayOpen = false;
                    _selectedTabId = null;
                    if (isNarrow) _sidebarOpen = false;
                  }),
                  onSettings: _showSettings,
                  habitActivated: _habitActivated,
                  goalActivated: _goalActivated,
                  onScrollTop: _scrollToTop,
                ),
                Container(height: 1, color: kBorder),

                // ── Search bar ──
                if (_searchOpen) ...[
                  _SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    onClose: _closeSearch,
                  ),
                  Container(height: 1, color: kBorder),
                ],

                // ── Main area: search OR calendar view OR memo list ──
                if (_searchOpen) ...[
                  Builder(
                    builder: (context) {
                      final results = _getSearchResults();
                      final q = _searchQuery.trim();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (q.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 7, 16, 5),
                              child: Text(
                                results.isEmpty
                                    ? 'no results for "$q"'
                                    : '${results.length} result${results.length == 1 ? '' : 's'}',
                                style: mono(color: kDim, fontSize: 10),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: kBorder.withValues(alpha: 0.4),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final results = _getSearchResults();
                        final q = _searchQuery.trim();
                        if (q.isEmpty) {
                          return Center(
                            child: Text(
                              'type to search...',
                              style: mono(
                                color: kDim.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        if (results.isEmpty) {
                          return Center(
                            child: Text(
                              'no results',
                              style: mono(
                                color: kDim.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final memo = results[i];
                            if (isLogroomUi) {
                              return LogroomEntryTile(
                                memo: memo,
                                actions: _memoActions,
                                onTap: () {
                                  _closeSearch();
                                  _navigateToMemo(memo.id);
                                },
                              );
                            }
                            return _SearchTile(
                              memo: memo,
                              query: q,
                              onTap: () {
                                _closeSearch();
                                _navigateToMemo(memo.id);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ] else if (_tagsOpen) ...[
                  Expanded(
                    child: _TagsBrowseView(
                      allTags: allTags,
                      tagCounts: tagCounts,
                      onSelectTag: (tag) => setState(() {
                        _tagsOpen = false;
                        _graphOpen = false;
          _brainOpen = false;
                        _selectedTag = tag;
                        _selectedFolderId = null;
                        _selectedTabId = null;
                      }),
                    ),
                  ),
                ] else if (_brainOpen) ...[
                  Expanded(
                    child: BrainScreen(memos: _memos),
                  ),
                ] else if (_graphOpen) ...[
                  Expanded(
                    child: GraphScreen(
                      memos: _memos,
                      onSelectKeyword: (keyword, memoIds) {
                        setState(() {
                          _graphOpen = false;
          _brainOpen = false;
                          _searchOpen = true;
                          _searchQuery = keyword;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _searchController.text = keyword;
                          _searchFocusNode.requestFocus();
                        });
                      },
                    ),
                  ),
                ] else if (_statsOpen) ...[
                  Expanded(
                    child: StatsView(
                      memos: _selectedTag != null
                          ? _memos
                                .where((m) => m.tags.contains(_selectedTag))
                                .toList()
                          : _memos
                                .where((m) => m.folderId == _selectedFolderId)
                                .toList(),
                      actions: _memoActions,
                      contextLabel: _selectedTag != null
                          ? '#$_selectedTag'
                          : (_selectedFolderId == null
                                ? (isNemo2Test ? 'INBOX' : 'inbox')
                                : _folders
                                      .firstWhere(
                                        (f) => f.id == _selectedFolderId,
                                        orElse: () => Folder(
                                          id: '',
                                          name: isNemo2Test ? 'INBOX' : 'inbox',
                                        ),
                                      )
                                      .name),
                      onEditMemo: _updateMemoFromInput,
                    ),
                  ),
                ] else if (_scheduleOpen) ...[
                  Expanded(
                    child: ScheduleView(
                      memos: _memos,
                      actions: _memoActions,
                      onEditMemo: _updateMemoFromInput,
                      onAddMemo:
                          (
                            c,
                            isCl,
                            rem,
                            fid,
                            imgs,
                            rep,
                            sched,
                            rangeEnd,
                            schedRep,
                            endType,
                            endCount,
                            endDate,
                          ) {
                            final editing = _editingMemo;
                            if (editing != null) {
                              _updateMemoFromInput(
                                editing,
                                c,
                                isCl,
                                rem,
                                fid,
                                imgs,
                                rep,
                                sched,
                                rangeEnd,
                                schedRep,
                                endType,
                                endCount,
                                endDate,
                              );
                              return;
                            }
                            _addMemo(
                              c,
                              isCl,
                              rem,
                              fid,
                              imgs,
                              rep,
                              sched,
                              rangeEnd,
                              schedRep,
                              endType,
                              endCount,
                              endDate,
                            );
                          },
                    ),
                  ),
                ] else if (_calendarOpen) ...[
                  Expanded(
                    child: CalendarView(
                      memos: _memos,
                      actions: _memoActions,
                      onEditMemo: _updateMemoFromInput,
                      onAddMemo:
                          (
                            c,
                            d,
                            isCl,
                            rem,
                            imgs,
                            rep,
                            sched,
                            rangeEnd,
                            schedRep,
                            endType,
                            endCount,
                            endDate,
                          ) => _addMemoOnDate(
                            c,
                            d,
                            isCl,
                            rem,
                            imgs,
                            rep,
                            sched,
                            rangeEnd,
                            schedRep,
                            endType,
                            endCount,
                            endDate,
                          ),
                      highlightedMemoId: _highlightedMemoId,
                    ),
                  ),
                ] else if (_todayOpen) ...[
                  Expanded(
                    child: TodayScreen(
                      memos: _memos,
                      streak: streak,
                      onUpdateMemo: (m, c) => _updateMemo(m.id, c),
                      onEditMemo: _updateMemoFromInput,
                      actions: _memoActions,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: items.isEmpty
                        ? const _EmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.only(top: isNemo2Test ? 6 : 0, bottom: 12),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item is String) {
                                final logroomAutoCollapsed =
                                    isLogroomUi &&
                                    _isAutoCollapsedLogroomGroup(item);
                                return DateGroupHeader(
                                  key: ValueKey('group-$item'),
                                  dateKey: item,
                                  initiallyCollapsed: logroomAutoCollapsed
                                      ? !_expandedLogroomGroups.contains(item)
                                      : _collapsedDates.contains(item),
                                  onCollapsedChanged: (collapsed) {
                                    setState(() {
                                      if (logroomAutoCollapsed) {
                                        if (collapsed) {
                                          _expandedLogroomGroups.remove(item);
                                        } else {
                                          _expandedLogroomGroups.add(item);
                                        }
                                      } else {
                                        if (collapsed) {
                                          _collapsedDates.add(item);
                                        } else {
                                          _collapsedDates.remove(item);
                                        }
                                      }
                                    });
                                  },
                                  hourSlots: isLogroomUi
                                      ? (_logroomHourSlots[item] ?? const [])
                                      : const [],
                                  onHourTap: isLogroomUi ? _scrollToMemo : null,
                                  daySummary: isLogroomUi
                                      ? _logroomDaySummaries[item]
                                      : null,
                                );
                              } else if (item is _HourMarker) {
                                return _buildHourMarker(item.hour, count: item.count);
                              } else if (item is _SilenceGap) {
                                return _buildSilenceGap(item.minutes);
                              } else if (item is Memo) {
                                final memoKey = _memoKeys.putIfAbsent(
                                  item.id,
                                  () => GlobalKey(),
                                );
                                final visibleMemos = items.whereType<Memo>().toList();
                                final memoIndex = visibleMemos.indexOf(item);
                                final isMergeTarget = _mergeTargetId == item.id && _draggingMemo?.id != item.id;
                                final isDropZoneActive = _draggingMemo != null;
                                final tile = isLogroomUi
                                    ? LogroomEntryTile(
                                        memo: item,
                                        actions: _memoActions,
                                        highlighted: _highlightedMemoId == item.id,
                                      )
                                    : MemoTile(
                                        memo: item,
                                        actions: _memoActions,
                                        highlighted: _highlightedMemoId == item.id,
                                        allMemos: _memos,
                                      );
                                return Column(
                                  key: memoKey,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // ── Reorder drop zone (above item) ──
                                    if (isDropZoneActive)
                                      DragTarget<Memo>(
                                        onWillAcceptWithDetails: (d) => d.data.id != item.id,
                                        onAcceptWithDetails: (d) {
                                          setState(() => _reorderInsertIndex = null);
                                          _reorderMemo(d.data, memoIndex, visibleMemos);
                                        },
                                        onMove: (_) => setState(() => _reorderInsertIndex = memoIndex),
                                        onLeave: (_) => setState(() => _reorderInsertIndex = null),
                                        builder: (_, candidate, __) => AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          height: _reorderInsertIndex == memoIndex ? 3 : 2,
                                          color: _reorderInsertIndex == memoIndex
                                              ? kMint
                                              : Colors.transparent,
                                        ),
                                      ),
                                    // ── Memo tile with merge target ──
                                    LongPressDraggable<Memo>(
                                      data: item,
                                      delay: const Duration(milliseconds: 400),
                                      onDragStarted: () => setState(() => _draggingMemo = item),
                                      onDragEnd: (_) => setState(() {
                                        _draggingMemo = null;
                                        _mergeTargetId = null;
                                        _reorderInsertIndex = null;
                                      }),
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: Opacity(
                                          opacity: 0.85,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 320),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: kSurface,
                                                border: Border.all(color: kMint, width: 1),
                                              ),
                                              padding: const EdgeInsets.all(10),
                                              child: Text(
                                                item.content.length > 60
                                                    ? '${item.content.substring(0, 60)}...'
                                                    : item.content,
                                                style: mono(color: kText, fontSize: 11),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(opacity: 0.3, child: tile),
                                      child: DragTarget<Memo>(
                                        onWillAcceptWithDetails: (d) => d.data.id != item.id,
                                        onAcceptWithDetails: (d) {
                                          setState(() => _mergeTargetId = null);
                                          _confirmAndMerge(d.data, item);
                                        },
                                        onMove: (_) => setState(() => _mergeTargetId = item.id),
                                        onLeave: (_) => setState(() => _mergeTargetId = null),
                                        builder: (_, candidate, __) => Container(
                                          decoration: isMergeTarget
                                              ? BoxDecoration(
                                                  border: Border.all(color: kMint, width: 1.5),
                                                )
                                              : null,
                                          child: tile,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                  ),
                  Container(height: 1, color: kBorder),
                  Flexible(
                    flex: 0,
                    fit: FlexFit.loose,
                    child: InputBar(
                      key: _inputBarKey,
                      onSubmit:
                          (
                            c,
                            isCl,
                            rem,
                            fid,
                            imgs,
                            rep,
                            sched,
                            rangeEnd,
                            schedRep,
                            endType,
                            endCount,
                            endDate,
                          ) {
                            final editing = _editingMemo;
                            if (editing != null) {
                              _updateMemoFromInput(
                                editing,
                                c,
                                isCl,
                                rem,
                                fid,
                                imgs,
                                rep,
                                sched,
                                rangeEnd,
                                schedRep,
                                endType,
                                endCount,
                                endDate,
                              );
                              return;
                            }
                            _addMemo(
                              c,
                              isCl,
                              rem,
                              fid,
                              imgs,
                              rep,
                              sched,
                              rangeEnd,
                              schedRep,
                              endType,
                              endCount,
                              endDate,
                            );
                          },
                      folders: _folders,
                      currentFolderId: _selectedFolderId,
                      habitActivated: _habitActivated,
                      goalActivated: _goalActivated,
                      dayCount: _dayCount,
                      streak: streak,
                      onActivateHabit: _activateHabit,
                      onActivateGoal: _activateGoal,
                      editingMemo: _editingMemo,
                      onCancelEdit: () => setState(() => _editingMemo = null),
                    ),
                  ),
                ],

                Container(height: 1, color: kBorder),
                if (isNemo2Test)
                  Nemo2TestBottomNav(
                    menus: _bottomMenus,
                    activeMenu: _activeBottomMenu,
                    onTap: (menu) => _selectBottomMenu(menu, narrow: isNarrow),
                    onReplace: _showBottomMenuReplaceSheet,
                  )
                else if (isLogroomUi)
                  LogroomBottomNav(
                    todaySelected: _todayOpen,
                    entriesSelected:
                        !_calendarOpen &&
                        !_statsOpen &&
                        !_scheduleOpen &&
                        !_todayOpen &&
                        !_tagsOpen &&
                        !_tasksOnly &&
                        !_searchOpen,
                    calendarSelected: _calendarOpen,
                    onTodayTap: () => setState(() {
                      _todayOpen = !_todayOpen;
                      _calendarOpen = false;
                      _statsOpen = false;
                      _scheduleOpen = false;
                      _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                      _tasksOnly = false;
                      _selectedTabId = null;
                    }),
                    onEntriesTap: () => setState(() {
                      _selectedFolderId = null;
                      _selectedTag = null;
                      _selectedTabId = null;
                      _calendarOpen = false;
                      _statsOpen = false;
                      _scheduleOpen = false;
                      _tasksOnly = false;
                      _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                      _todayOpen = false;
                      _searchOpen = false;
                    }),
                    onCalendarTap: () => setState(() {
                      _calendarOpen = true;
                      _selectedTabId = null;
                      _statsOpen = false;
                      _scheduleOpen = false;
                      _todayOpen = false;
                      _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                      _tasksOnly = false;
                      _selectedTag = null;
                      if (isNarrow) _sidebarOpen = false;
                    }),
                    onMoreTap: () => setState(() => _sidebarOpen = true),
                  )
                else
                  BottomTabBar(
                    tabs: _tabs,
                    selectedTabId: _selectedTabId,
                    onSelect: _selectTab,
                    canAdd: _tabs.length < 5,
                    onAddTap: () => _showTabDialog(null),
                    onLongPress: (tab) => _confirmDeleteTab(tab),
                    locked: _tabLocked,
                    calendarSelected: _calendarOpen,
                    onCalendarTap: () => setState(() {
                      if (!_calendarOpen) {
                        _calendarOpen = true;
                        _selectedTabId = null;
                        _statsOpen = false;
                        _scheduleOpen = false;
                      }
                    }),
                    statsSelected: _statsOpen,
                    onStatsTap: () => setState(() {
                      if (!_statsOpen) {
                        _statsOpen = true;
                        _calendarOpen = false;
                        _scheduleOpen = false;
                        _todayOpen = false;
                        _selectedTabId = null;
                      }
                    }),
                    todaySelected: _todayOpen,
                    onTodayTap: () => setState(() {
                      _todayOpen = !_todayOpen;
                      _calendarOpen = false;
                      _statsOpen = false;
                      _scheduleOpen = false;
                      _tagsOpen = false;
          _graphOpen = false;
          _brainOpen = false;
                      _tasksOnly = false;
                      _selectedTabId = null;
                    }),
                  ),
              ],
            );

            // ── Mobile: overlay sidebar ──
            if (isNarrow) {
              return Stack(
                children: [
                  mainContent,
                  // Dimming backdrop — absorbs taps to close sidebar
                  IgnorePointer(
                    ignoring: !_sidebarOpen,
                    child: AnimatedOpacity(
                      opacity: _sidebarOpen ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: GestureDetector(
                        onTap: () => setState(() => _sidebarOpen = false),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                  // Sidebar slides in from left
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    left: _sidebarOpen ? 0 : -210.0,
                    top: 0,
                    bottom: 0,
                    width: 200,
                    child: sidebar,
                  ),
                ],
              );
            }

            // ── Desktop: inline sidebar ──
            return Row(
              children: [
                ClipRect(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    width: _sidebarOpen ? 200.0 : 0.0,
                    child: OverflowBox(
                      minWidth: 200,
                      maxWidth: 200,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(width: 200, child: sidebar),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: _sidebarOpen ? 1.0 : 0.0,
                  color: kBorder,
                ),
                Expanded(child: mainContent),
              ],
            );
          },
        ),
      ),
    ), // Scaffold
    ); // PopScope
  }
}

// ─────────────────────────────────────────────────────────────────
// Search helpers
// ─────────────────────────────────────────────────────────────────

List<TextSpan> _highlightSpans(String text, String query, TextStyle base) {
  if (query.isEmpty) return [TextSpan(text: text, style: base)];
  final spans = <TextSpan>[];
  final lower = text.toLowerCase();
  final q = query.toLowerCase();
  int start = 0;
  while (true) {
    final idx = lower.indexOf(q, start);
    if (idx == -1) {
      if (start < text.length)
        spans.add(TextSpan(text: text.substring(start), style: base));
      break;
    }
    if (idx > start)
      spans.add(TextSpan(text: text.substring(start, idx), style: base));
    spans.add(
      TextSpan(
        text: text.substring(idx, idx + q.length),
        style: base.copyWith(
          color: kMint,
          backgroundColor: kMint.withValues(alpha: 0.18),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    start = idx + q.length;
  }
  return spans;
}

// ─────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '>_ ',
            style: mono(
              color: kMint,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: mono(fontSize: 13, height: 1.4),
              onChanged: onChanged,
              cursorColor: kMint,
              cursorWidth: 2,
              decoration: InputDecoration(
                hintText: 'search memos...',
                hintStyle: mono(
                  color: kDim.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text('×', style: mono(color: kDim, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Search result tile
// ─────────────────────────────────────────────────────────────────

class _SearchTile extends StatefulWidget {
  final Memo memo;
  final String query;
  final VoidCallback onTap;

  const _SearchTile({
    required this.memo,
    required this.query,
    required this.onTap,
  });

  @override
  State<_SearchTile> createState() => _SearchTileState();
}

class _SearchTileState extends State<_SearchTile> {
  bool _hovered = false;

  static final _tagRe = RegExp(
    r'(?<![^\s])#[a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣][a-zA-Z0-9_ㄱ-ㅎㅏ-ㅣ가-힣]*',
  );

  @override
  Widget build(BuildContext context) {
    final memo = widget.memo;
    final q = widget.query;
    final tags = memo.tags;

    // Up to 3 non-empty content lines, prefixes stripped
    final lines = memo.content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(3)
        .map(
          (l) => l
              .replaceAll(_tagRe, '')
              .replaceAll(RegExp(r'^- \[[ x]\] '), '')
              .replaceAll(RegExp(r'^• '), '')
              .trim(),
        )
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              color: _hovered ? kSurface : Colors.transparent,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Text(
                        memo.timeStr,
                        style: mono(color: kDim, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: tags
                              .map(
                                (t) => Text.rich(
                                  TextSpan(
                                    children: _highlightSpans(
                                      '#$t',
                                      q,
                                      mono(color: kTeal, fontSize: 11),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Content lines
                  ...lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: mono(color: kText, fontSize: 12)),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: _highlightSpans(
                                  line,
                                  q,
                                  mono(color: kText, fontSize: 12, height: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Date
                  Text.rich(
                    TextSpan(
                      children: _highlightSpans(
                        memo.dateKey,
                        q,
                        mono(color: kDim, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '- ' * 80,
            style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 9),
            overflow: TextOverflow.clip,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Search toggle button  [/]
// ─────────────────────────────────────────────────────────────────

class _SearchToggleBtn extends StatefulWidget {
  final bool active;
  final VoidCallback onTap;
  const _SearchToggleBtn({required this.active, required this.onTap});

  @override
  State<_SearchToggleBtn> createState() => _SearchToggleBtnState();
}

class _SearchToggleBtnState extends State<_SearchToggleBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? kMint : (_hovered ? kText : kDim);
    return MouseRegion(
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
          child: Icon(Icons.search, size: 16, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Local widgets
// ─────────────────────────────────────────────────────────────────

class _AppHeader extends StatelessWidget {
  final bool sidebarOpen;
  final VoidCallback onToggle;
  final String selectedPath;
  final bool isNarrow;
  final bool calendarOpen;
  final bool statsOpen;
  final bool scheduleOpen;
  final bool todayOpen;
  final bool tagsOpen;
  final bool tasksOnly;
  final VoidCallback onShowList;
  final VoidCallback onShowCal;
  final VoidCallback onSelectStats;
  final VoidCallback onSelectToday;
  final bool searchOpen;
  final VoidCallback onSearchTap;
  final List<Folder> folders;
  final String? selectedFolderId;
  final void Function(String? id) onSelectFolder;
  final VoidCallback onSelectSchedule;
  final VoidCallback onSelectTasks;
  final VoidCallback onSelectTags;
  final VoidCallback onSelectHabit;
  final VoidCallback onSelectGoal;
  final VoidCallback onSelectGraph;
  final VoidCallback onSettings;
  final bool habitActivated;
  final bool goalActivated;
  final VoidCallback? onScrollTop;

  const _AppHeader({
    required this.sidebarOpen,
    required this.onToggle,
    required this.selectedPath,
    required this.isNarrow,
    required this.calendarOpen,
    required this.statsOpen,
    required this.scheduleOpen,
    required this.todayOpen,
    required this.tagsOpen,
    required this.tasksOnly,
    required this.onShowList,
    required this.onShowCal,
    required this.onSelectStats,
    required this.onSelectToday,
    required this.searchOpen,
    required this.onSearchTap,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelectFolder,
    required this.onSelectSchedule,
    required this.onSelectTasks,
    required this.onSelectTags,
    required this.onSelectHabit,
    required this.onSelectGoal,
    required this.onSelectGraph,
    required this.onSettings,
    required this.habitActivated,
    required this.goalActivated,
    this.onScrollTop,
  });

  Future<void> _showPathMenu(BuildContext context, Offset tapPos) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: '__inbox__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          isNemo2Test ? '/INBOX' : '/inbox',
          style: mono(
            color: selectedFolderId == null ? kMint : kText,
            fontSize: 12,
          ),
        ),
      ),
      ...folders.map(
        (f) => PopupMenuItem<String>(
          value: 'folder:${f.id}',
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '/${f.name}',
            style: mono(
              color: selectedFolderId == f.id ? kMint : kText,
              fontSize: 12,
            ),
          ),
        ),
      ),
      PopupMenuItem<String>(
        enabled: false,
        height: 1,
        padding: EdgeInsets.zero,
        child: Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: CustomPaint(
            painter: _DashedLinePainter(color: kText.withValues(alpha: 0.25)),
          ),
        ),
      ),
      PopupMenuItem<String>(
        value: '__tags__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          '> tags',
          style: mono(color: tagsOpen ? kMint : kDim, fontSize: 12),
        ),
      ),
      PopupMenuItem<String>(
        value: '__calendar__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          '> calendar',
          style: mono(color: calendarOpen ? kMint : kDim, fontSize: 12),
        ),
      ),
      PopupMenuItem<String>(
        value: '__today__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          '> today',
          style: mono(color: todayOpen ? kMint : kDim, fontSize: 12),
        ),
      ),
      PopupMenuItem<String>(
        value: '__schedule__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          '> event',
          style: mono(color: scheduleOpen ? kMint : kDim, fontSize: 12),
        ),
      ),
      PopupMenuItem<String>(
        value: '__tasks__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          '> tasks',
          style: mono(color: tasksOnly ? kMint : kDim, fontSize: 12),
        ),
      ),
      if (habitActivated)
        PopupMenuItem<String>(
          value: '__habits__',
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '> habits',
            style: mono(
              color: selectedPath == '#habit' ? kMint : kDim,
              fontSize: 12,
            ),
          ),
        ),
      if (goalActivated)
        PopupMenuItem<String>(
          value: '__goals__',
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '> goals',
            style: mono(
              color: selectedPath == '#goal' ? kMint : kDim,
              fontSize: 12,
            ),
          ),
        ),
      PopupMenuItem<String>(
        value: '__stats__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          '> stats',
          style: mono(color: statsOpen ? kMint : kDim, fontSize: 12),
        ),
      ),
      PopupMenuItem<String>(
        value: '__graph__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          '> graph',
          style: mono(color: kDim, fontSize: 12),
        ),
      ),
      PopupMenuItem<String>(
        enabled: false,
        height: 1,
        padding: EdgeInsets.zero,
        child: Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: CustomPaint(
            painter: _DashedLinePainter(color: kText.withValues(alpha: 0.25)),
          ),
        ),
      ),
      PopupMenuItem<String>(
        value: '__settings__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('> settings', style: mono(color: kDim, fontSize: 12)),
      ),
    ];

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(tapPos.dx, tapPos.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      color: kSurface,
      elevation: 3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      items: items,
    );

    if (result == null) return;
    if (result == '__inbox__') {
      onSelectFolder(null);
    } else if (result.startsWith('folder:')) {
      onSelectFolder(result.substring(7));
    } else if (result == '__tags__') {
      onSelectTags();
    } else if (result == '__calendar__') {
      onShowCal();
    } else if (result == '__today__') {
      onSelectToday();
    } else if (result == '__schedule__') {
      onSelectSchedule();
    } else if (result == '__tasks__') {
      onSelectTasks();
    } else if (result == '__habits__') {
      onSelectHabit();
    } else if (result == '__goals__') {
      onSelectGoal();
    } else if (result == '__stats__') {
      onSelectStats();
    } else if (result == '__graph__') {
      onSelectGraph();
    } else if (result == '__settings__') {
      onSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final dayStr = weekdays[now.weekday - 1];
    final dateStr =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}  $dayStr';

    final pathLabel = selectedPath;

    return Container(
      height: 44,
      color: kBg,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          _ToggleBtn(isOpen: sidebarOpen, onTap: onToggle),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Text(
                  'MEMO',
                  style: mono(
                    color: kTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text('─', style: mono(color: kBorder, fontSize: 12)),
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _showPathMenu(context, d.globalPosition),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        pathLabel,
                        style: mono(color: kTeal, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:
                      (calendarOpen ||
                          statsOpen ||
                          scheduleOpen ||
                          todayOpen ||
                          tagsOpen ||
                          tasksOnly)
                      ? onShowList
                      : onScrollTop,
                  child: _ViewBtn(
                    label: 'LIST',
                    active:
                        !calendarOpen &&
                        !statsOpen &&
                        !scheduleOpen &&
                        !todayOpen &&
                        !tagsOpen &&
                        !tasksOnly,
                  ),
                ),
                const SizedBox(width: 2),
                _SearchToggleBtn(active: searchOpen, onTap: onSearchTap),
              ],
            ),
          ),
          if (!isNarrow) ...[
            const SizedBox(width: 10),
            Text(dateStr, style: mono(color: kDim, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class _ViewBtn extends StatelessWidget {
  final String label;
  final bool active;

  const _ViewBtn({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      color: active ? kMint.withValues(alpha: 0.12) : Colors.transparent,
      child: Text(
        label,
        style: mono(
          color: active ? kMint : kDim,
          fontSize: 10,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _ToggleBtn({required this.isOpen, required this.onTap});

  @override
  State<_ToggleBtn> createState() => _ToggleBtnState();
}

class _ToggleBtnState extends State<_ToggleBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? kMint.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Text(
            '≡',
            style: mono(color: _hovered ? kMint : kDim, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isDosTheme
                ? 'NO LOGS FOUND.'
                : (isNemo2Test ? 'INBOX is empty.' : 'inbox is empty.'),
            style: mono(color: kDim, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'start writing.',
            style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Terminal-style delete dialog
// ─────────────────────────────────────────────────────────────────

class _DialogAction {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DialogAction({
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _TerminalDialog extends StatelessWidget {
  final String title;
  final String body;
  final List<_DialogAction> actions;

  const _TerminalDialog({
    required this.title,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (isDosTheme) {
      return Dialog(
        backgroundColor: kBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: kBorder)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SYSTEM MESSAGE', style: mono(color: kMint, fontSize: 12)),
              const SizedBox(height: 8),
              Text(title, style: mono(color: kText, fontSize: 12)),
              const SizedBox(height: 8),
              Text(body, style: mono(color: kDim, fontSize: 12, height: 1.5)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions
                    .map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _DialogBtn(action: a),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
    }
    return Dialog(
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: kBorder),
            const SizedBox(height: 12),
            Text(body, style: mono(color: kDim, fontSize: 12, height: 1.7)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _DialogBtn(action: a),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogBtn extends StatefulWidget {
  final _DialogAction action;

  const _DialogBtn({required this.action});

  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: a.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? a.color.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Text(
            isDosTheme ? '[ ${a.label.toUpperCase()} ]' : a.label,
            style: mono(color: a.color, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Tags browse view
// ─────────────────────────────────────────────────────────────────

// ── 태그 그룹 분류 ─────────────────────────────────────────────

enum _TagGroup { korean, english, number, special }

_TagGroup _classifyTag(String tag) {
  if (tag.isEmpty) return _TagGroup.special;
  final first = tag.codeUnitAt(0);
  if (first >= 0xAC00 && first <= 0xD7A3) return _TagGroup.korean; // 가~힣
  if (first >= 0x3131 && first <= 0x3163) return _TagGroup.korean; // ㄱ~ㅣ
  if ((first >= 0x41 && first <= 0x5A) || (first >= 0x61 && first <= 0x7A))
    return _TagGroup.english;
  if (first >= 0x30 && first <= 0x39) return _TagGroup.number;
  return _TagGroup.special;
}

const _tagGroupLabel = {
  _TagGroup.korean: 'ㄱㄴㄷ',
  _TagGroup.english: 'ABC',
  _TagGroup.number: '123',
  _TagGroup.special: '#?!',
};

const _tagGroupOrder = [
  _TagGroup.korean,
  _TagGroup.english,
  _TagGroup.number,
  _TagGroup.special,
];

// ──────────────────────────────────────────────────────────────
// Tags browse view — grouped + collapsible
// ──────────────────────────────────────────────────────────────

class _TagsBrowseView extends StatefulWidget {
  final List<String> allTags;
  final Map<String, int> tagCounts;
  final void Function(String tag) onSelectTag;

  const _TagsBrowseView({
    required this.allTags,
    required this.tagCounts,
    required this.onSelectTag,
  });

  @override
  State<_TagsBrowseView> createState() => _TagsBrowseViewState();
}

class _TagsBrowseViewState extends State<_TagsBrowseView> {
  final _collapsed = <_TagGroup>{};

  @override
  Widget build(BuildContext context) {
    if (widget.allTags.isEmpty) {
      return Center(
        child: Text(
          'no tags yet.',
          style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 12),
        ),
      );
    }

    // 그룹별로 분류
    final groups = <_TagGroup, List<String>>{};
    for (final tag in widget.allTags) {
      final g = _classifyTag(tag);
      groups.putIfAbsent(g, () => []).add(tag);
    }

    final items = <Widget>[];
    for (final group in _tagGroupOrder) {
      final tags = groups[group];
      if (tags == null || tags.isEmpty) continue;
      final isCollapsed = _collapsed.contains(group);
      final label = _tagGroupLabel[group]!;

      // 섹션 헤더
      items.add(
        _TagGroupHeader(
          label: label,
          count: tags.length,
          isCollapsed: isCollapsed,
          onTap: () => setState(() {
            if (isCollapsed)
              _collapsed.remove(group);
            else
              _collapsed.add(group);
          }),
        ),
      );

      // 태그 행들
      if (!isCollapsed) {
        for (final tag in tags) {
          items.add(
            _TagBrowseRow(
              tag: tag,
              count: widget.tagCounts[tag] ?? 0,
              onTap: () => widget.onSelectTag(tag),
            ),
          );
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      children: items,
    );
  }
}

class _TagGroupHeader extends StatefulWidget {
  final String label;
  final int count;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _TagGroupHeader({
    required this.label,
    required this.count,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_TagGroupHeader> createState() => _TagGroupHeaderState();
}

class _TagGroupHeaderState extends State<_TagGroupHeader> {
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
          color: _hovered
              ? kBorder.withValues(alpha: 0.15)
              : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 5),
          child: Row(
            children: [
              Text(
                widget.isCollapsed ? '▸ ' : '▾ ',
                style: mono(color: kMint.withValues(alpha: 0.7), fontSize: 10),
              ),
              Text(
                widget.label,
                style: mono(
                  color: kMint.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${widget.count})',
                style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagBrowseRow extends StatefulWidget {
  final String tag;
  final int count;
  final VoidCallback onTap;

  const _TagBrowseRow({
    required this.tag,
    required this.count,
    required this.onTap,
  });

  @override
  State<_TagBrowseRow> createState() => _TagBrowseRowState();
}

class _TagBrowseRowState extends State<_TagBrowseRow> {
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
          color: _hovered
              ? kBorder.withValues(alpha: 0.22)
              : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
          child: Row(
            children: [
              Text('# ', style: mono(color: kTeal, fontSize: 11)),
              Expanded(
                child: Text(
                  widget.tag,
                  style: mono(color: _hovered ? kText : kDim, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${widget.count}',
                style: mono(color: kDim.withValues(alpha: 0.45), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
