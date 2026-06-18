import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/memo.dart';
import '../services/local_search_service.dart';
import '../services/storage_service.dart';
import '../services/wiki_capture_service.dart';

class _Msg {
  final bool isUser;
  final String text;
  _Msg({required this.isUser, required this.text});
}

class BrainScreen extends StatefulWidget {
  final List<Memo> memos;
  const BrainScreen({super.key, required this.memos});

  @override
  State<BrainScreen> createState() => _BrainScreenState();
}

class _BrainScreenState extends State<BrainScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final List<_Msg> _messages = [];
  bool _loading = false;
  String _apiKey = '';
  String _model = 'claude-haiku-4-5-20251001';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _apiKey = await StorageService.loadClaudeApiKey();
    _model = await StorageService.loadClaudeModel();
    if (_apiKey.isEmpty && mounted) {
      setState(() => _messages.add(_Msg(
        isUser: false,
        text: '설정에서 Claude API 키를 먼저 입력해주세요.',
      )));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _ctrl.text.trim();
    if (question.isEmpty || _loading) return;

    _ctrl.clear();
    setState(() {
      _messages.add(_Msg(isUser: true, text: question));
      _loading = true;
    });
    _scrollDown();

    // 관련 메모 찾기 — 순수 로컬 글자 n-gram 유사도 (업로드 0)
    var relevant = LocalSearchService.search(question, widget.memos, limit: 15);
    // 매칭 없으면 최근 메모로 폴백
    if (relevant.isEmpty) relevant = widget.memos.take(15).toList();

    // 메모 컨텍스트 구성 (본문/최근 댓글 + 태그)
    final context = relevant.take(15).map((m) {
      final body = m.appendNotes.isNotEmpty
          ? m.appendNotes.last.content
          : m.content;
      final tags = m.tags.isNotEmpty
          ? '\n태그: ${m.tags.map((t) => '#$t').join(' ')}'
          : '';
      final full = body + tags;
      return full.substring(0, full.length.clamp(0, 600));
    }).join('\n---\n');

    // 대화 히스토리 구성
    final history = _messages
        .where((m) => m != _messages.last)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    final systemPrompt = '''너는 사용자의 개인 세컨드 브레인 AI야.
사용자가 저장한 메모들을 기반으로만 답해. 메모에 없는 내용은 "아직 저장된 내용이 없어요"라고 해.

저장된 메모 (${relevant.length}개):
$context''';

    final answer = await WikiCaptureService.chatWithMemos(
      question: question,
      history: history,
      systemPrompt: systemPrompt,
      apiKey: _apiKey,
      model: _model,
    );

    if (mounted) {
      final footer = answer != null && relevant.isNotEmpty
          ? '\n\n📎 참고한 메모 ${relevant.length}개'
          : '';
      setState(() {
        _loading = false;
        _messages.add(_Msg(
          isUser: false,
          text: (answer ?? '오류가 발생했어요. 다시 시도해보세요.') + footer,
        ));
      });
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(
              children: [
                Text('brain', style: display(fontSize: 17, color: kText)),
                const SizedBox(width: 10),
                Text(
                  '메모 ${widget.memos.length}개',
                  style: mono(fontSize: 10, color: kDim),
                ),
              ],
            ),
          ),

          // 메시지 목록
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('내 메모에게 물어보세요', style: mono(fontSize: 13, color: kDim)),
                        const SizedBox(height: 8),
                        Text('"Flutter 관련 뭐 저장했어?"', style: mono(fontSize: 11, color: kDim.withValues(alpha: 0.5))),
                        Text('"다이어트 정보 정리해줘"', style: mono(fontSize: 11, color: kDim.withValues(alpha: 0.5))),
                        Text('"이번 주 뭐 저장했지?"', style: mono(fontSize: 11, color: kDim.withValues(alpha: 0.5))),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: [
                            SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(color: kMint, strokeWidth: 1.5),
                            ),
                            const SizedBox(width: 10),
                            Text('생각 중...', style: mono(fontSize: 11, color: kDim)),
                          ]),
                        );
                      }
                      final msg = _messages[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.isUser ? 'YOU' : ' AI',
                              style: mono(
                                fontSize: 9,
                                color: msg.isUser ? kTeal : kMint,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                msg.text,
                                style: mono(fontSize: 13, height: 1.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 입력창
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
              color: kSurface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    style: mono(fontSize: 13),
                    cursorColor: kMint,
                    decoration: InputDecoration(
                      hintText: '메모에게 물어보세요...',
                      hintStyle: mono(fontSize: 13, color: kDim),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Text('↑', style: mono(fontSize: 18, color: _loading ? kDim : kMint)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
