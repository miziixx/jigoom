import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../app_theme.dart';
import '../models/memo.dart';
import '../models/folder.dart';
import '../widgets/date_group_header.dart';
import '../widgets/memo_tile.dart';
import '../widgets/input_bar.dart';
import '../widgets/sidebar.dart';
import 'settings_screen.dart';
import '../widgets/bottom_tab_bar.dart';
import '../models/quick_tab.dart';
import '../models/append_note.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../services/image_service.dart';
import '../widgets/calendar_view.dart';
import 'stats_screen.dart';

// Below this width → mobile overlay sidebar; above → desktop inline sidebar
const _kNarrowBreak = 700.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _memos = <Memo>[];
  final _folders = <Folder>[];
  final _tabs = <QuickTab>[];
  final _scrollController = ScrollController();
  final _memoKeys = <String, GlobalKey>{};

  bool _sidebarOpen = true;
  bool _didSetInitialSidebar = false;
  bool _tabLocked = false;
  bool _calendarOpen = false;
  bool _statsOpen = false;
  String? _selectedFolderId;
  String? _selectedTag;
  String? _selectedTabId;
  String? _highlightedMemoId; // briefly highlighted after notification tap

  int _dayCount = 1;
  bool _habitActivated = false;
  bool _goalActivated = false;

  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final _collapsedDates = <String>{};

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
        );
      }
    }
  }

  void _initShareIntent() {
    if (kIsWeb) return;
    // Hot-start: app already running when another app shares to us
    _shareSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> files) {
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
    if (u.contains('instagram.com'))                               return '#공유인스타';
    if (u.contains('threads.net') || u.contains('threads.com'))   return '#공유스레드';
    if (u.contains('kakao'))                                       return '#공유카톡';
    if (u.contains('youtube.com') || u.contains('youtu.be'))      return '#공유유튜브';
    if (u.contains('twitter.com') || u.contains('x.com'))         return '#공유X';
    if (u.contains('tiktok.com'))                                  return '#공유틱톡';
    if (u.contains('facebook.com') || u.contains('fb.com'))       return '#공유페북';
    if (u.contains('chatgpt.com') || u.contains('chat.openai.com')) return '#공유GPT';
    if (u.contains('google.com'))                                  return '#공유구글';
    if (u.contains('naver.com'))                                   return '#공유네이버';
    if (u.contains('blog.') || u.contains('/blog'))               return '#공유블로그';
    return '#공유기사';
  }

  static Future<String?> _fetchPageTitle(String url) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 4));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final bodyBytes = <int>[];
      await for (final chunk in res.timeout(const Duration(seconds: 4))) {
        bodyBytes.addAll(chunk);
        if (bodyBytes.length > 32000) break;
      }
      final body = utf8.decode(bodyBytes, allowMalformed: true);
      final match = RegExp(
        r'<title[^>]*>(.*?)</title>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(body);
      return match?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ');
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (!mounted) return;
    final textFiles = files
        .where((f) => f.type == SharedMediaType.text || f.type == SharedMediaType.url)
        .toList();
    if (textFiles.isEmpty) return;

    final raw = textFiles.first.path.trim();
    if (raw.isEmpty) return;

    final urlRegex = RegExp(r'https?://\S+', caseSensitive: false);
    final urlMatch = urlRegex.firstMatch(raw);
    final detectedUrl = urlMatch?.group(0);

    final sourceTag = _sourceTag(detectedUrl);
    final tags = '#공유 $sourceTag';

    // Title: non-URL text in the shared content, or fetched from page <title>
    String? title;
    final nonUrl = raw.replaceAll(urlRegex, '').replaceAll(RegExp(r'\n+'), ' ').trim();
    if (nonUrl.isNotEmpty) {
      title = nonUrl;
    } else if (detectedUrl != null) {
      title = await _fetchPageTitle(detectedUrl);
    }

    if (!mounted) return;

    final String initialContent;
    if (title != null && title.isNotEmpty) {
      initialContent = detectedUrl != null
          ? '$tags\n$title\n$detectedUrl'
          : '$tags\n$title';
    } else if (detectedUrl != null) {
      initialContent = '$tags\n$detectedUrl';
    } else {
      initialContent = '$tags\n$raw';
    }

    _showShareDialog(sharedText: raw, initialContent: initialContent, detectedUrl: detectedUrl);
  }

  void _showShareDialog({
    required String sharedText,
    required String initialContent,
    String? detectedUrl,
  }) {
    final contentController = TextEditingController(text: initialContent);
    final urlController = TextEditingController(text: detectedUrl ?? '');

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
                Text('[ SHARED CONTENT ]',
                    style: mono(color: kMint, fontSize: 13, letterSpacing: 1)),
                const SizedBox(height: 10),
                Container(height: 1, color: kBorder),
                const SizedBox(height: 12),

                // Source preview
                Container(
                  padding: const EdgeInsets.all(10),
                  color: kBg,
                  child: Text(
                    sharedText.length > 200
                        ? '${sharedText.substring(0, 200)}...'
                        : sharedText,
                    style: mono(color: kDim, fontSize: 11, height: 1.5),
                  ),
                ),
                const SizedBox(height: 14),

                // Memo content field
                Text('메모 내용', style: mono(color: kDim, fontSize: 10)),
                const SizedBox(height: 5),
                Container(
                  color: kBg,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: TextField(
                    controller: contentController,
                    maxLines: 4,
                    minLines: 2,
                    style: mono(fontSize: 12, height: 1.5),
                    cursorColor: kMint,
                    decoration: InputDecoration(
                      hintText: '내용을 입력하거나 비워두세요...',
                      hintStyle: mono(color: kDim.withValues(alpha: 0.5), fontSize: 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: TextField(
                    controller: urlController,
                    maxLines: 1,
                    style: mono(fontSize: 11, height: 1.4, color: kTeal),
                    cursorColor: kMint,
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      hintStyle: mono(color: kDim.withValues(alpha: 0.4), fontSize: 11),
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
                    _DialogBtn(action: _DialogAction(
                      label: '[ CANCEL ]',
                      color: kDim,
                      onTap: () => Navigator.pop(ctx),
                    )),
                    const SizedBox(width: 8),
                    _DialogBtn(action: _DialogAction(
                      label: '[ SAVE ]',
                      color: kMint,
                      onTap: () {
                        Navigator.pop(ctx);
                        final content = contentController.text.trim().isNotEmpty
                            ? contentController.text.trim()
                            : sharedText;
                        final url = urlController.text.trim().isNotEmpty
                            ? urlController.text.trim()
                            : null;
                        _addMemoWithSource(content, url);
                      },
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addMemoWithSource(String content, String? sourceUrl) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _memos.add(Memo(
        id: id,
        content: content,
        createdAt: DateTime.now(),
        folderId: _selectedFolderId,
        sourceUrl: sourceUrl,
      ));
    });
    StorageService.saveMemos(_memos);
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
    setState(() { _searchOpen = true; _searchQuery = ''; });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _searchFocusNode.requestFocus());
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  List<Memo> _getSearchResults() {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) return [];
    return _memos.where((m) {
      if (m.content.toLowerCase().contains(q)) return true;
      if (m.tags.any((t) => t.toLowerCase().contains(q))) return true;
      if (m.dateKey.contains(q)) return true;
      return false;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _navigateToMemo(String memoId) {
    final memo = _memos.where((m) => m.id == memoId).firstOrNull;
    if (memo == null) return;
    setState(() {
      _selectedFolderId  = memo.folderId;
      _selectedTag       = null;
      _selectedTabId     = null;
      _highlightedMemoId = memoId;
      _calendarOpen      = false;
      _statsOpen         = false;
    });
    // Remove highlight after 3 seconds.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightedMemoId = null);
    });
    // Scroll to top so the user can see the memo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
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
    final tabLocked = await StorageService.loadTabLocked();
    final dayCount = await StorageService.getDayCount();
    final habitActivated = await StorageService.getHabitActivated();
    final goalActivated = await StorageService.getGoalActivated();
    if (!mounted) return;
    setState(() {
      _memos.addAll(memos);
      _folders.addAll(folders);
      _tabs.addAll(tabs);
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
      if (memo.reminderAt != null && memo.reminderAt!.isAfter(now)) {
        NotificationService.schedule(
          memoId: memo.id,
          content: memo.content,
          scheduledAt: memo.reminderAt!,
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

  void _addMemo(String content, bool isChecklist, DateTime? reminderAt, [String? folderOverride, List<String>? imagePaths]) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final targetFolder = folderOverride ?? _selectedFolderId;
    setState(() {
      _memos.add(Memo(
        id: id,
        content: content,
        createdAt: DateTime.now(),
        folderId: targetFolder,
        isChecklist: isChecklist,
        reminderAt: reminderAt,
        imagePaths: imagePaths ?? const [],
      ));
      if (folderOverride != null) _selectedFolderId = folderOverride;
    });
    StorageService.saveMemos(_memos);
    if (reminderAt != null) {
      NotificationService.schedule(
          memoId: id, content: content, scheduledAt: reminderAt);
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
      String content, DateTime date, bool isChecklist, DateTime? reminderAt, [List<String>? imagePaths]) {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final createdAt = DateTime(
        date.year, date.month, date.day, now.hour, now.minute, now.second);
    setState(() {
      _memos.add(Memo(
        id: id,
        content: content,
        createdAt: createdAt,
        isChecklist: isChecklist,
        reminderAt: reminderAt,
        imagePaths: imagePaths ?? const [],
      ));
    });
    StorageService.saveMemos(_memos);
    if (reminderAt != null) {
      NotificationService.schedule(
          memoId: id, content: content, scheduledAt: reminderAt);
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
              content: content, addedAt: notes[index].addedAt);
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
        _memos[i] = _memos[i].copyWith(
          content: newContent,
          editHistory: [..._memos[i].editHistory, DateTime.now()],
        );
      }
    });
    StorageService.saveMemos(_memos);
  }

  void _deleteMemo(Memo memo) {
    showDialog(
      context: context,
      builder: (ctx) => _TerminalDialog(
        title: '[ DELETE MEMO ]',
        body:
            '"${memo.content.length > 50 ? '${memo.content.substring(0, 50)}...' : memo.content}"',
        actions: [
          _DialogAction(
              label: '[ CANCEL ]',
              color: kDim,
              onTap: () => Navigator.pop(ctx)),
          _DialogAction(
            label: '[ DELETE ]',
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
    final siblingCount =
        _folders.where((f) => f.parentId == parentId).length;
    final folder = Folder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
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
    setState(() => _folders[i] = _folders[i].copyWith(name: newName));
    StorageService.saveFolders(_folders);
  }

  void _moveMemoToFolder(Memo memo, String? newFolderId) {
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

  void _setReminder(Memo memo, DateTime? newTime) {
    // Update UI and storage immediately — don't await OS notification calls.
    final updated = memo.copyWith(
      reminderAt: newTime,
      clearReminder: newTime == null,
    );
    setState(() {
      final i = _memos.indexWhere((m) => m.id == memo.id);
      if (i != -1) _memos[i] = updated;
    });
    StorageService.saveMemos(_memos);

    // Fire-and-forget: cancel old notification then schedule new one.
    // Errors are swallowed so OS issues never affect the UI.
    () async {
      try { await NotificationService.cancel(memo.id); } catch (_) {}
      if (newTime != null) {
        try {
          await NotificationService.schedule(
            memoId: memo.id,
            content: memo.content,
            scheduledAt: newTime,
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
      final folder =
          _folders.where((f) => f.id == currentId).firstOrNull;
      if (folder == null || folder.parentId == null) return false;
      if (folder.parentId == ancestorId) return true;
      currentId = folder.parentId!;
    }
  }

  void _moveFolder(String folderId, String? newParentId, int insertIndex) {
    if (folderId == newParentId) return;
    if (newParentId != null && _isDescendant(folderId, newParentId)) return;

    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;

    setState(() {
      final moved = _folders[idx];
      final siblings = _folders
          .where((f) => f.parentId == newParentId && f.id != folderId)
          .toList()
        ..sort((a, b) => a.order != b.order
            ? a.order.compareTo(b.order)
            : a.name.compareTo(b.name));

      final pos = insertIndex.clamp(0, siblings.length);

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
      _calendarOpen  = false;
      _statsOpen     = false;
      if (tab.isTag && tab.tag != null) {
        _selectedTag = tab.tag;
        _selectedFolderId = null;
      } else {
        _selectedFolderId = tab.folderId;
        _selectedTag = null;
      }
    });
  }

  void _showTabDialog(QuickTab? existing) {
    showDialog(
      context: context,
      builder: (_) => TabEditDialog(
        tab: existing,
        folders: _folders,
        allTags: _allTags,
        onSave: (tab) =>
            existing == null ? _addTab(tab) : _updateTab(tab),
        onDelete: existing != null ? () => _deleteTab(existing.id) : null,
      ),
    );
  }

  // ── Computed tag data ──────────────────────────────

  List<String> get _allTags {
    final tags = <String>{};
    for (final memo in _memos) {
      tags.addAll(memo.tags);
    }
    tags.removeAll({'habit', 'goal'});
    return tags.toList()..sort();
  }

  Map<String, int> get _tagCounts {
    final counts = <String, int>{};
    for (final memo in _memos) {
      for (final tag in memo.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String?, int> get _memoCounts {
    final counts = <String?, int>{};
    for (final memo in _memos) {
      counts[memo.folderId] = (counts[memo.folderId] ?? 0) + 1;
    }
    return counts;
  }

  List<Memo> get _recentMemos {
    final sorted = [..._memos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(3).toList();
  }

  int get _totalWords =>
      _memos.fold(0, (sum, m) => sum + m.content.length);

  int get _streak {
    if (_memos.isEmpty) return 0;
    final days = _memos
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
    if (_selectedTag != null) {
      // Tag filter: all memos containing this tag (across folders)
      visible = _memos.where((m) => m.tags.contains(_selectedTag)).toList();
    } else {
      visible = _memos.where((m) => m.folderId == _selectedFolderId).toList();
    }
    final grouped = <String, List<Memo>>{};
    for (final memo in visible) {
      grouped.putIfAbsent(memo.dateKey, () => []).add(memo);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final items = <Object>[];
    for (final dateKey in sortedDates) {
      items.add(dateKey);
      if (!_collapsedDates.contains(dateKey)) {
        final dayMemos = grouped[dateKey]!
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        items.addAll(dayMemos);
      }
    }
    return items;
  }

  // ── Settings ───────────────────────────────────────

  static int _colorToInt(Color c) {
    int ch(double v) => (v * 255.0).round().clamp(0, 255);
    return (0xFF << 24) | (ch(c.r) << 16) | (ch(c.g) << 8) | ch(c.b);
  }

  Map<String, dynamic> _buildSettingsMap() => {
        'bg_color':    _colorToInt(kBg),
        'text_color':  _colorToInt(kText),
        'font_family': kFontFamily,
        'font_size':   kFontSize,
        'tab_locked':  _tabLocked,
      };

  void _applyBackupData(Map<String, dynamic> backup, {bool merge = false}) {
    final backupMemos = (backup['memos'] as List?)
            ?.map((e) => Memo.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
    final backupFolders = (backup['folders'] as List?)
            ?.map((e) => Folder.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
    final backupTabs = (backup['tabs'] as List?)
            ?.map((e) => QuickTab.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
    final settings = backup['settings'] as Map<String, dynamic>?;

    final List<Memo> memos;
    final List<Folder> folders;
    final List<QuickTab> tabs;

    if (merge) {
      final existingMemoIds = _memos.map((m) => m.id).toSet();
      final existingFolderIds = _folders.map((f) => f.id).toSet();
      final existingTabIds = _tabs.map((t) => t.id).toSet();
      memos   = [..._memos,   ...backupMemos.where((m) => !existingMemoIds.contains(m.id))];
      folders = [..._folders, ...backupFolders.where((f) => !existingFolderIds.contains(f.id))];
      tabs    = [..._tabs,    ...backupTabs.where((t) => !existingTabIds.contains(t.id))];
    } else {
      memos   = backupMemos;
      folders = backupFolders;
      tabs    = backupTabs;
    }

    setState(() {
      _memos..clear()..addAll(memos);
      _folders..clear()..addAll(folders);
      _tabs..clear()..addAll(tabs);
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
      final bgInt   = settings['bg_color'] as int?;
      final textInt = settings['text_color'] as int?;
      if (bgInt != null && textInt != null) {
        final bg   = Color(bgInt);
        final text = Color(textInt);
        applyColors(bg, text);
        StorageService.saveColors(bg, text);
      }
      final fontFamily = settings['font_family'] as String?;
      final fontSize   = (settings['font_size'] as num?)?.toDouble();
      if (fontFamily != null && fontSize != null) {
        applyFont(fontFamily, fontSize);
        StorageService.saveFont(fontFamily, fontSize);
      }
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
            applyColors(bg, text);
            StorageService.saveColors(bg, text);
            StorageService.saveFont(fontFamily, fontSize);
            StorageService.saveTabLocked(tabLocked);
            setState(() => _tabLocked = tabLocked);
          },
          onBackupShare: () {
            BackupService.export(
              memos: _memos, folders: _folders,
              tabs: _tabs, settings: _buildSettingsMap(),
            );
          },
          onBackupSave: () => BackupService.exportToPhone(
            memos: _memos, folders: _folders,
            tabs: _tabs, settings: _buildSettingsMap(),
          ),
          onRestoreConfirmed: _applyBackupData,
          onClearCache: _clearAllCache,
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

  void _clearAllCache() {
    StorageService.clearAll();
    applyColors(const Color(0xFFEDF2ED), const Color(0xFF556B2F));
    applyFont('JetBrains Mono', 13.0);
    setState(() {
      _memos.clear();
      _folders.clear();
      _tabs.clear();
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

  @override
  Widget build(BuildContext context) {
    final items = (_calendarOpen || _statsOpen) ? const [] : _buildFlatList();
    // Header path
    final folderName = _selectedFolderId == null
        ? '/inbox'
        : '/${_folders.firstWhere((f) => f.id == _selectedFolderId, orElse: () => const Folder(id: '', name: 'inbox')).name}';
    final selectedPath = _calendarOpen
        ? '[CAL]'
        : (_statsOpen
            ? 'stats'
            : (_selectedTag != null && _selectedFolderId != null
                ? '$folderName  #$_selectedTag'
                : (_selectedTag != null
                    ? '#$_selectedTag'
                    : folderName)));

    final allTags = _allTags;
    final tagCounts = _tagCounts;
    final memoCounts = _memoCounts;
    final recentMemos = _recentMemos;
    final totalWords = _totalWords;
    final streak = _streak;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < _kNarrowBreak;

            final sidebar = Sidebar(
              folders: _folders,
              selectedId: _selectedFolderId,
              onSelect: (id) {
                setState(() {
                  _selectedFolderId = id;
                  _selectedTag = null;
                  _selectedTabId = null;
                  if (isNarrow) _sidebarOpen = false;
                });
              },
              onCreate: _createFolder,
              onSettingsTap: _showSettings,
              allTags: allTags,
              tagCounts: tagCounts,
              selectedTag: _selectedTag,
              onSelectTag: (tag) {
                setState(() {
                  _selectedTag = tag;
                  _selectedFolderId = null;
                  _selectedTabId = null;
                  if (isNarrow) _sidebarOpen = false;
                });
              },
              memoCounts: memoCounts,
              recentMemos: recentMemos,
              onSelectRecent: (memo) {
                setState(() {
                  _selectedFolderId = memo.folderId;
                  _selectedTag = null;
                  if (isNarrow) _sidebarOpen = false;
                });
              },
              totalWords: totalWords,
              streak: streak,
              onMoveMemo: _moveMemoToFolder,
              onMoveFolder: _moveFolder,
              onRenameFolder: _renameFolder,
              dayCount: _dayCount,
              habitActivated: _habitActivated,
              goalActivated: _goalActivated,
              onActivateHabit: _activateHabit,
              onActivateGoal: _activateGoal,
              onSelectHabit: () => setState(() {
                _selectedTag = 'habit';
                _selectedFolderId = null;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
              onSelectGoal: () => setState(() {
                _selectedTag = 'goal';
                _selectedFolderId = null;
                _selectedTabId = null;
                if (isNarrow) _sidebarOpen = false;
              }),
            );

            final mainContent = Column(
              children: [
                _AppHeader(
                  sidebarOpen:      _sidebarOpen,
                  isNarrow:         isNarrow,
                  onToggle:         () => setState(() => _sidebarOpen = !_sidebarOpen),
                  selectedPath:     selectedPath,
                  calendarOpen:     _calendarOpen,
                  statsOpen:        _statsOpen,
                  onShowList:       () => setState(() { _calendarOpen = false; _statsOpen = false; }),
                  onShowCal:        () => setState(() {
                    _calendarOpen = true;
                    _selectedTabId = null;
                    _statsOpen = false;
                  }),
                  searchOpen:       _searchOpen,
                  onSearchTap:      () { if (_searchOpen) { _closeSearch(); } else { _openSearch(); } },
                  folders:          _folders,
                  allTags:          allTags,
                  selectedFolderId: _selectedFolderId,
                  selectedTag:      _selectedTag,
                  onSelectFolder:   (id) => setState(() {
                    _selectedFolderId = id;
                    _selectedTag = null;
                    _selectedTabId = null;
                  }),
                  onSelectTag:      (tag) => setState(() {
                    _selectedTag = tag;
                    _selectedFolderId = null;
                    _selectedTabId = null;
                  }),
                ),
                Container(height: 1, color: kBorder),

                // ── Search bar ──
                if (_searchOpen) ...[
                  _SearchBar(
                    controller: _searchController,
                    focusNode:  _searchFocusNode,
                    onChanged:  (v) => setState(() => _searchQuery = v),
                    onClose:    _closeSearch,
                  ),
                  Container(height: 1, color: kBorder),
                ],

                // ── Main area: search OR calendar view OR memo list ──
                if (_searchOpen) ...[
                  Builder(builder: (context) {
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
                          Container(height: 1, color: kBorder.withValues(alpha: 0.4)),
                        ],
                      ],
                    );
                  }),
                  Expanded(
                    child: Builder(builder: (context) {
                      final results = _getSearchResults();
                      final q = _searchQuery.trim();
                      if (q.isEmpty) {
                        return Center(
                          child: Text('type to search...',
                              style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 12)));
                      }
                      if (results.isEmpty) {
                        return Center(
                          child: Text('no results',
                              style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 12)));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: results.length,
                        itemBuilder: (_, i) => _SearchTile(
                          memo:  results[i],
                          query: q,
                          onTap: () {
                            _closeSearch();
                            _navigateToMemo(results[i].id);
                          },
                        ),
                      );
                    }),
                  ),
                ] else if (_statsOpen) ...[
                  Expanded(
                    child: StatsView(
                      memos: _selectedTag != null
                          ? _memos.where((m) => m.tags.contains(_selectedTag)).toList()
                          : _memos.where((m) => m.folderId == _selectedFolderId).toList(),
                      contextLabel: _selectedTag != null
                          ? '#$_selectedTag'
                          : (_selectedFolderId == null
                              ? 'inbox'
                              : _folders.firstWhere(
                                  (f) => f.id == _selectedFolderId,
                                  orElse: () => const Folder(id: '', name: 'inbox'),
                                ).name),
                      onDelete: _deleteMemo,
                      onUpdate: (m, c) => _updateMemo(m.id, c),
                      onMove: _moveMemoToFolder,
                    ),
                  ),
                ] else if (_calendarOpen) ...[
                  Expanded(
                    child: CalendarView(
                      memos:             _memos,
                      onDelete:          _deleteMemo,
                      onUpdate:          _updateMemo,
                      onMove:            _moveMemoToFolder,
                      onSetReminder:     _setReminder,
                      onAddMemo:         (c, d, isCl, rem, imgs) => _addMemoOnDate(c, d, isCl, rem, imgs),
                      onAddNote:         _addNote,
                      onUpdateNote:      _updateNote,
                      onDeleteNote:      _deleteNote,
                      folders:           _folders,
                      highlightedMemoId: _highlightedMemoId,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: items.isEmpty
                        ? const _EmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item is String) {
                                return DateGroupHeader(
                                  dateKey: item,
                                  initiallyCollapsed: _collapsedDates.contains(item),
                                  onCollapsedChanged: (collapsed) {
                                    setState(() {
                                      if (collapsed) {
                                        _collapsedDates.add(item);
                                      } else {
                                        _collapsedDates.remove(item);
                                      }
                                    });
                                  },
                                );
                              } else if (item is Memo) {
                                final memoKey = _memoKeys.putIfAbsent(item.id, () => GlobalKey());
                                return Column(
                                  key: memoKey,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    MemoTile(
                                      memo: item,
                                      onDelete: () => _deleteMemo(item),
                                      onUpdate: (c) => _updateMemo(item.id, c),
                                      onMove: (fid) => _moveMemoToFolder(item, fid),
                                      onSetReminder: (dt) => _setReminder(item, dt),
                                      onAddNote: (c) => _addNote(item, c),
                                      onUpdateNote: (idx, c) => _updateNote(item, idx, c),
                                      onDeleteNote: (idx) => _deleteNote(item, idx),
                                      folders: _folders,
                                      highlighted: _highlightedMemoId == item.id,
                                      onTagTap: (tag) => setState(() => _selectedTag = tag),
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
                      onSubmit: (c, isCl, rem, fid, imgs) => _addMemo(c, isCl, rem, fid, imgs),
                      folders: _folders,
                      currentFolderId: _selectedFolderId,
                    ),
                  ),
                ],

                Container(height: 1, color: kBorder),
                BottomTabBar(
                  tabs:             _tabs,
                  selectedTabId:    _selectedTabId,
                  onSelect:         _selectTab,
                  canAdd:           _tabs.length < 5,
                  onAddTap:         () => _showTabDialog(null),
                  onLongPress:      _showTabDialog,
                  locked:           _tabLocked,
                  calendarSelected: _calendarOpen,
                  onCalendarTap: () => setState(() {
                    if (!_calendarOpen) {
                      _calendarOpen  = true;
                      _selectedTabId = null;
                      _statsOpen     = false;
                    }
                  }),
                  statsSelected: _statsOpen,
                  onStatsTap: () => setState(() {
                    if (!_statsOpen) {
                      _statsOpen     = true;
                      _calendarOpen  = false;
                      _selectedTabId = null;
                    }
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
    );
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
      if (start < text.length) spans.add(TextSpan(text: text.substring(start), style: base));
      break;
    }
    if (idx > start) spans.add(TextSpan(text: text.substring(start, idx), style: base));
    spans.add(TextSpan(
      text: text.substring(idx, idx + q.length),
      style: base.copyWith(
        color: kMint,
        backgroundColor: kMint.withValues(alpha: 0.18),
        fontWeight: FontWeight.bold,
      ),
    ));
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
          Text('>_ ', style: mono(color: kMint, fontSize: 14, fontWeight: FontWeight.bold)),
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
                hintStyle: mono(color: kDim.withValues(alpha: 0.55), fontSize: 13),
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
              child: Text('[×]', style: mono(color: kDim, fontSize: 12)),
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

  const _SearchTile({required this.memo, required this.query, required this.onTap});

  @override
  State<_SearchTile> createState() => _SearchTileState();
}

class _SearchTileState extends State<_SearchTile> {
  bool _hovered = false;

  static final _tagRe = RegExp(r'(?<![^\s])#[a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣][a-zA-Z0-9_ㄱ-ㅎㅏ-ㅣ가-힣]*');

  @override
  Widget build(BuildContext context) {
    final memo  = widget.memo;
    final q     = widget.query;
    final tags  = memo.tags;

    // Up to 3 non-empty content lines, prefixes stripped
    final lines = memo.content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(3)
        .map((l) => l
            .replaceAll(_tagRe, '')
            .replaceAll(RegExp(r'^- \[[ x]\] '), '')
            .replaceAll(RegExp(r'^• '), '')
            .trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit:  (_) => setState(() => _hovered = false),
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
                      Text('[${memo.timeStr}]',
                          style: mono(color: kDim, fontSize: 11)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: tags
                              .map((t) => Text.rich(TextSpan(
                                    children: _highlightSpans(
                                        '#$t', q,
                                        mono(color: kTeal, fontSize: 11)),
                                  )))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Content lines
                  ...lines.map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: mono(color: kText, fontSize: 12)),
                            Expanded(
                              child: Text.rich(TextSpan(
                                children: _highlightSpans(
                                    line, q,
                                    mono(color: kText, fontSize: 12, height: 1.5)),
                              )),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 4),
                  // Date
                  Text.rich(TextSpan(
                    children: _highlightSpans(
                        memo.dateKey, q,
                        mono(color: kDim, fontSize: 10)),
                  )),
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
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.active
                ? kMint.withValues(alpha: 0.1)
                : (_hovered ? kSurface : Colors.transparent),
          ),
          child: Text('SEARCH', style: mono(color: color, fontSize: 10, letterSpacing: 1)),
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
  final VoidCallback onShowList;
  final VoidCallback onShowCal;
  final bool searchOpen;
  final VoidCallback onSearchTap;
  final List<Folder> folders;
  final List<String> allTags;
  final String? selectedFolderId;
  final String? selectedTag;
  final void Function(String? id) onSelectFolder;
  final void Function(String tag) onSelectTag;

  const _AppHeader({
    required this.sidebarOpen,
    required this.onToggle,
    required this.selectedPath,
    required this.isNarrow,
    required this.calendarOpen,
    required this.statsOpen,
    required this.onShowList,
    required this.onShowCal,
    required this.searchOpen,
    required this.onSearchTap,
    required this.folders,
    required this.allTags,
    required this.selectedFolderId,
    required this.selectedTag,
    required this.onSelectFolder,
    required this.onSelectTag,
  });

  Future<void> _showPathMenu(BuildContext context, Offset tapPos) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final folderItems = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: '__inbox__',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('/inbox',
            style: mono(color: selectedFolderId == null && selectedTag == null ? kMint : kText, fontSize: 12)),
      ),
      ...folders.map((f) => PopupMenuItem<String>(
        value: 'folder:${f.id}',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('/${f.name}',
            style: mono(color: selectedFolderId == f.id ? kMint : kText, fontSize: 12)),
      )),
    ];

    final tagItems = <PopupMenuEntry<String>>[
      ...allTags.map((t) => PopupMenuItem<String>(
        value: 'tag:$t',
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('#$t',
            style: mono(color: selectedTag == t ? kMint : kText, fontSize: 12)),
      )),
    ];

    final items = <PopupMenuEntry<String>>[
      ...folderItems,
      if (allTags.isNotEmpty) ...[
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
        ...tagItems,
      ],
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
    } else if (result.startsWith('tag:')) {
      onSelectTag(result.substring(4));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final dayStr = weekdays[now.weekday - 1];
    final dateStr =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}  $dayStr';

    final pathLabel = calendarOpen ? 'calendar' : selectedPath;
    final pathTappable = !calendarOpen;

    return Container(
      height: 44,
      color: kBg,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          _ToggleBtn(isOpen: sidebarOpen, onTap: onToggle),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  '[ MEMO ]',
                  style: mono(
                    color: kTeal,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text('─', style: mono(color: kBorder, fontSize: 12)),
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: pathTappable
                        ? (d) => _showPathMenu(context, d.globalPosition)
                        : null,
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
          const SizedBox(width: 8),
          _ViewToggle(
            calendarOpen: calendarOpen,
            statsOpen: statsOpen,
            onShowList: onShowList,
            onShowCal: onShowCal,
          ),
          const SizedBox(width: 6),
          _SearchToggleBtn(active: searchOpen, onTap: onSearchTap),
          if (!isNarrow) ...[
            const SizedBox(width: 10),
            Text(dateStr, style: mono(color: kDim, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

// ── View toggle widget ─────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool calendarOpen;
  final bool statsOpen;
  final VoidCallback onShowList;
  final VoidCallback onShowCal;

  const _ViewToggle({
    required this.calendarOpen,
    required this.statsOpen,
    required this.onShowList,
    required this.onShowCal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: (calendarOpen || statsOpen) ? onShowList : null,
          child: _ViewBtn(label: 'LIST', active: !calendarOpen && !statsOpen),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: calendarOpen ? null : onShowCal,
          child: _ViewBtn(label: 'CAL', active: calendarOpen),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            color: _hovered ? kMint.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Text(
            '[≡]',
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
          Text('inbox is empty.', style: mono(color: kDim, fontSize: 13)),
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
            Text(title,
                style: mono(color: kMint, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 10),
            Container(height: 1, color: kBorder),
            const SizedBox(height: 12),
            Text(body, style: mono(color: kDim, fontSize: 12, height: 1.7)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: _DialogBtn(action: a),
                      ))
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
            color: _hovered ? a.color.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: Text(a.label, style: mono(color: a.color, fontSize: 12)),
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
