import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../app_theme.dart';
import '../models/memo.dart';
import '../services/keyword_service.dart';
import '../services/storage_service.dart';

class GraphScreen extends StatefulWidget {
  final List<Memo> memos;
  final void Function(String keyword, List<String> memoIds) onSelectKeyword;

  const GraphScreen({
    super.key,
    required this.memos,
    required this.onSelectKeyword,
  });

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen>
    with SingleTickerProviderStateMixin {
  GraphData? _graphData;
  bool _loading = true;
  bool _useAI = false;
  String _apiKey = '';
  int _aiProgress = 0;
  int _aiTotal = 0;
  String? _selectedKeyword;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _transformController = TransformationController();

  late Ticker _ticker;
  int _tickCount = 0;
  static const _maxTicks = 300;
  double _scale = 1.0;

  static const _canvasSize = 2000.0;
  static const _initialScale = 0.38;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _transformController.addListener(_onTransformChanged);
    _init();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    final data = _graphData;
    if (data == null || _tickCount >= _maxTicks) {
      _ticker.stop();
      return;
    }
    KeywordService.runSimulationStep(
        data, tick: _tickCount, totalTicks: _maxTicks, steps: 5);
    _tickCount += 5;
    setState(() {});
  }

  void _onTransformChanged() {
    final s = _transformController.value.getMaxScaleOnAxis();
    if ((s - _scale).abs() > 0.001) setState(() => _scale = s);
  }

  Future<void> _init() async {
    _apiKey = await StorageService.loadClaudeApiKey();
    setState(() => _useAI = _apiKey.isNotEmpty);
    await _buildGraph();
  }

  Future<void> _buildGraph() async {
    setState(() {
      _loading = true;
      _aiProgress = 0;
      _aiTotal = 0;
    });

    GraphData data;
    if (_useAI && _apiKey.isNotEmpty) {
      data = await KeywordService.buildGraphWithAI(
        widget.memos,
        _apiKey,
        onProgress: (done, total) {
          if (mounted) setState(() { _aiProgress = done; _aiTotal = total; });
        },
      );
    } else {
      data = await Future.microtask(() => KeywordService.buildGraph(widget.memos));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      const s = _initialScale;
      final tx = (size.width - _canvasSize * s) / 2;
      final ty = (size.height - _canvasSize * s) / 2 - 30;
      _transformController.value = Matrix4.identity()
        ..translate(tx, ty)
        ..scale(s);
      _scale = s;
    });

    if (mounted) {
      setState(() {
        _graphData = data;
        _loading = false;
        _tickCount = 0;
      });
      _ticker.stop();
      _ticker.start();
    }
  }

  void _zoomIn() {
    _transformController.value = _transformController.value.clone()..scale(1.25, 1.25);
  }

  void _zoomOut() {
    _transformController.value = _transformController.value.clone()..scale(0.8, 0.8);
  }

  void _resetView() {
    final size = MediaQuery.of(context).size;
    const s = _initialScale;
    final tx = (size.width - _canvasSize * s) / 2;
    final ty = (size.height - _canvasSize * s) / 2 - 30;
    _transformController.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(s);
    setState(() => _selectedKeyword = null);
  }

  void _onTapCanvas(TapDownDetails details) {
    final data = _graphData;
    if (data == null) return;
    final inv = Matrix4.inverted(_transformController.value);
    final local = MatrixUtils.transformPoint(inv, details.localPosition);

    final maxC = data.nodes.isEmpty
        ? 1
        : data.nodes.map((n) => n.count).reduce(math.max);

    GraphNode? hit;
    double bestDist = double.infinity;
    for (final node in data.nodes) {
      final r = _nodeRadius(node, maxC) + 10;
      final d = (Offset(node.x, node.y) - local).distance;
      if (d <= r && d < bestDist) { bestDist = d; hit = node; }
    }

    if (hit != null) {
      setState(() => _selectedKeyword = hit!.keyword);
      _showKeywordSheet(hit);
    } else {
      setState(() => _selectedKeyword = null);
    }
  }

  static double _nodeRadius(GraphNode node, int maxCount) {
    // glow 반지름까지 포함해서 탭 감지 (core * 6 * 0.5 + 여유)
    if (maxCount <= 1) return 14.0;
    final t = (node.count - 1) / (maxCount - 1);
    final cr = 1.5 + math.sqrt(t) * 3.5;
    return cr * 6.0 * 0.5 + 8.0;
  }

  void _showKeywordSheet(GraphNode node) {
    final memos = widget.memos
        .where((m) => node.memoIds.contains(m.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 3,
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: kMint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(node.keyword,
                    style: mono(color: kMint, fontSize: 14, fontWeight: FontWeight.normal)),
                const SizedBox(width: 8),
                Text('${node.count}개',
                    style: mono(color: kDim, fontSize: 11)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSelectKeyword(node.keyword, node.memoIds);
                  },
                  child: Text('목록으로 →', style: mono(color: kMint, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: kBorder, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: memos.length,
              itemBuilder: (_, i) {
                final m = memos[i];
                final preview = m.content.split('\n').first.trim();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preview,
                          style: mono(color: kText, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(_fmtDate(m.createdAt),
                          style: mono(color: kDim, fontSize: 10)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Container(
          color: kBg,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(bottom: BorderSide(color: kBorder, width: 1)),
      ),
      child: Row(
        children: [
          Text('graph', style: display(color: kText, fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _searchController,
                style: mono(color: kText, fontSize: 12),
                decoration: InputDecoration(
                  hintText: '키워드 검색',
                  hintStyle: mono(color: kDim.withValues(alpha: 0.5), fontSize: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (_apiKey.isNotEmpty) ...[
            GestureDetector(
              onTap: () async {
                setState(() => _useAI = !_useAI);
                await _buildGraph();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _useAI ? kMint.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _useAI ? kMint : kBorder),
                ),
                child: Text(
                  _useAI ? 'AI' : 'LOCAL',
                  style: mono(color: _useAI ? kMint : kDim, fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text('${_graphData?.nodes.length ?? 0}',
              style: mono(color: kDim, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 1.2, color: kMint),
            ),
            const SizedBox(height: 12),
            Text(
              _aiTotal > 0
                  ? 'AI 분석 중... $_aiProgress / $_aiTotal'
                  : '그래프 생성 중...',
              style: mono(color: kDim, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final data = _graphData;
    if (data == null || data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('메모가 부족합니다', style: mono(color: kDim, fontSize: 13)),
            const SizedBox(height: 6),
            Text('메모를 더 작성하면 그래프가 나타납니다',
                style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTapDown: _onTapCanvas,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.08,
        maxScale: 6.0,
        constrained: false,
        child: SizedBox(
          width: _canvasSize,
          height: _canvasSize,
          child: CustomPaint(
            painter: _GraphPainter(
              nodes: data.nodes,
              edges: data.edges,
              selectedKeyword: _selectedKeyword,
              searchQuery: _searchQuery,
              scale: _scale,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final pct = (_scale * 100).round();
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FooterBtn(label: '−', onTap: _zoomOut),
          const SizedBox(width: 10),
          Text('$pct%', style: mono(color: kDim, fontSize: 10)),
          const SizedBox(width: 10),
          _FooterBtn(label: '+', onTap: _zoomIn),
          const SizedBox(width: 20),
          _FooterBtn(label: '초기화', onTap: _resetView),
        ],
      ),
    );
  }
}

// ── CustomPainter ──────────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String? selectedKeyword;
  final String searchQuery;
  final double scale;

  late final Map<String, GraphNode> _nodeMap;
  late final int _maxCount;
  late final Set<String> _connected; // 선택 노드와 연결된 이웃

  _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.selectedKeyword,
    required this.searchQuery,
    required this.scale,
  })  : _nodeMap = {for (final n in nodes) n.keyword: n},
        _maxCount = nodes.isEmpty ? 1 : nodes.map((n) => n.count).reduce(math.max) {
    _connected = {};
    if (selectedKeyword != null) {
      for (final e in edges) {
        if (e.from == selectedKeyword) _connected.add(e.to);
        if (e.to == selectedKeyword) _connected.add(e.from);
      }
    }
  }

  // 별자리 4색 팔레트 — 채도 낮춘 먼지 낀 별빛
  static const _palette = [
    Color(0xFF8AAED4), // 스틸 블루
    Color(0xFFC89098), // 모브 로즈
    Color(0xFF7AB8A0), // 세이지 민트
    Color(0xFFC8A870), // 모래 골드
  ];

  // 사이즈: 태그 허브는 항상 크게, 키워드는 빈도 4단계
  double _coreR(GraphNode n) {
    if (n.isTag) return 5.5;    // 태그 허브 고정
    if (_maxCount <= 1) return 2.0;
    final t = (n.count - 1) / (_maxCount - 1);
    if (t >= 0.75) return 6.5;  // ★★★★
    if (t >= 0.45) return 4.0;  // ★★★
    if (t >= 0.20) return 2.5;  // ★★
    return 1.5;                 // ★
  }

  // glow 반지름: core보다 훨씬 크게
  double _glowR(GraphNode n) => _coreR(n) * 5.5;

  bool _matches(GraphNode n) =>
      searchQuery.isEmpty || n.keyword.contains(searchQuery);

  // 색상: 키워드 해시로 고정 배정 (일관성 있게, 다양하게)
  Color _starColor(GraphNode n) {
    if (n.keyword == selectedKeyword) return const Color(0xFFFFFFFF);
    if (n.isTag) return const Color(0xFFEEEEEE);              // 태그 허브: 흰색
    if (_connected.contains(n.keyword)) return const Color(0xFFFFFFAA);
    return _palette[n.keyword.hashCode.abs() % _palette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = kBg,
    );

    final hasSearch = searchQuery.isNotEmpty;
    final hasSelected = selectedKeyword != null;

    // ── 엣지: 별자리 선 — 아주 가늘고 희미하게 ─────────────────────
    for (final edge in edges) {
      final ni = _nodeMap[edge.from];
      final nj = _nodeMap[edge.to];
      if (ni == null || nj == null) continue;

      final isHighlight =
          ni.keyword == selectedKeyword || nj.keyword == selectedKeyword;
      final bothMatch = _matches(ni) && _matches(nj);

      double opacity;
      if (hasSelected) {
        opacity = isHighlight ? 0.40 : 0.04;
      } else if (hasSearch) {
        opacity = bothMatch ? 0.35 : 0.04;
      } else {
        opacity = 0.10;
      }

      canvas.drawLine(
        Offset(ni.x, ni.y),
        Offset(nj.x, nj.y),
        Paint()
          ..color = kText.withValues(alpha: opacity)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke,
      );
    }

    // ── 노드: 별 ──────────────────────────────────────────────────
    for (final node in nodes) {
      final cr   = _coreR(node);
      final gr   = _glowR(node);
      final selected  = node.keyword == selectedKeyword;
      final connected = _connected.contains(node.keyword);
      final matched   = _matches(node);
      final color     = _starColor(node);

      // 전체 불투명도
      double alpha;
      if (hasSelected) {
        alpha = selected ? 1.0 : (connected ? 0.90 : (matched ? 0.18 : 0.06));
      } else if (hasSearch) {
        alpha = matched ? 1.0 : 0.06;
      } else {
        // 기본: 작은 별은 희미하게, 큰 별은 또렷하게
        alpha = 0.35 + (_coreR(node) / 5.0) * 0.65;
      }

      final pos = Offset(node.x, node.y);

      // ── 별빛 glow 3겹 ────────────────────────────────────────────
      // 가장 바깥 — 넓고 희미한 halo
      canvas.drawCircle(pos, gr * 1.6,
          Paint()
            ..color = color.withValues(alpha: 0.04 * alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, gr * 0.9));

      // 중간 — 부드러운 glow
      canvas.drawCircle(pos, gr,
          Paint()
            ..color = color.withValues(alpha: 0.13 * alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, gr * 0.45));

      // 안쪽 — 선명한 corona
      canvas.drawCircle(pos, cr * 2.2,
          Paint()
            ..color = color.withValues(alpha: 0.35 * alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cr * 1.2));

      // ── core: 밝은 점 ─────────────────────────────────────────────
      canvas.drawCircle(pos, cr,
          Paint()..color = color.withValues(alpha: alpha));

      // 하이라이트: 아주 작은 흰 점 (별 반짝임)
      canvas.drawCircle(pos, cr * 0.38,
          Paint()..color = Colors.white.withValues(alpha: 0.55 * alpha));

      // ── 라벨 ─────────────────────────────────────────────────────
      final showByZoom = scale >= 0.55 ||
          (scale >= 0.28 && cr >= 3.0) ||
          (scale >= 0.15 && cr >= 4.5) ||
          selected;

      final showLabel = matched &&
          showByZoom &&
          (!hasSelected || selected || connected || cr >= 3.0) &&
          alpha > 0.12;

      if (showLabel) {
        final labelAlpha = selected ? 1.0 : (connected ? 0.85 : alpha * 0.75);
        final labelColor = selected
            ? kMint
            : connected
                ? kMint.withValues(alpha: labelAlpha)
                : kText.withValues(alpha: labelAlpha * 0.70);

        final tp = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(
                text: '• ',
                style: TextStyle(
                  color: color.withValues(alpha: labelAlpha * 0.55),
                  fontSize: 7.5,
                  fontFamily: kFontFamily,
                ),
              ),
              TextSpan(
                text: node.keyword,
                style: TextStyle(
                  color: labelColor,
                  fontSize: selected ? 11.0 : (cr >= 4.0 ? 9.5 : 8.5),
                  fontFamily: kFontFamily,
                  fontWeight: selected ? FontWeight.normal : FontWeight.normal,
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, Offset(node.x - tp.width / 2, node.y + cr + gr * 0.35 + 3.0));
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.selectedKeyword != selectedKeyword ||
      old.searchQuery != searchQuery ||
      old.nodes != nodes ||
      old.scale != scale;
}

// ── 하단 버튼 ─────────────────────────────────────────────────────

class _FooterBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: kBorder),
        ),
        child: Text(label, style: mono(color: kText, fontSize: 10)),
      ),
    );
  }
}
