import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../models/memo.dart';
import 'storage_service.dart';

// ── Graph data models ──────────────────────────────────────────────

class GraphNode {
  final String keyword;
  final bool isTag; // #태그 허브 노드 여부
  double x;
  double y;
  double vx;
  double vy;
  final int count;
  final List<String> memoIds;

  GraphNode({
    required this.keyword,
    this.isTag = false,
    required this.x,
    required this.y,
    required this.count,
    required this.memoIds,
  })  : vx = 0,
        vy = 0;
}

class GraphEdge {
  final String from;
  final String to;
  final int weight;

  const GraphEdge({required this.from, required this.to, required this.weight});
}

class GraphData {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  const GraphData({required this.nodes, required this.edges});

  bool get isEmpty => nodes.isEmpty;
}

// ── Keyword extraction service ────────────────────────────────────

class KeywordService {
  static const _stopwords = {
    // 시간 부사
    '오늘', '어제', '내일', '요즘', '최근', '나중', '나중에', '이때', '그때',
    '언제', '아직', '이미', '다시', '계속', '갑자기', '갑자', '아마', '아마도',
    // 정도 부사
    '그냥', '진짜', '정말', '좀', '너무', '매우', '아주', '약간', '별로',
    // 지시어
    '이거', '저거', '그거', '이게', '그게', '저게', '이걸', '저걸', '그걸',
    '여기', '저기', '거기', '이런', '저런', '그런', '어떤', '모든',
    '이렇게', '저렇게', '그렇게', '어떻게',
    // 접속사
    '그리고', '하지만', '그런데', '근데', '그래서', '또한', '그러나', '또는',
    '왜냐면', '왜냐하면', '따라서', '그러므로',
    // 동사/형용사 활용
    '있다', '없다', '했다', '이다', '하다', '되다', '않다', '같다',
    '같아', '같은', '같이', '않게', '않아', '않는', '않을',
    '해야', '하면', '하고', '해서', '하니', '하는', '한다', '했고', '했는데',
    '했어', '할거', '할게', '하겠다', '하겠어', '하겠지', '해야지', '해야겠다',
    '싶어', '싶은', '싶다', '싶었',
    '봐야', '봐야지', '봐야겠다',
    '뭐가', '뭔가', '뭔지', '누가', '누구',
    '것같다', '것같아', '것같은',
    // 의존명사
    '거', '것', '수', '때', '줄', '듯', '만큼', '대로',
    // 기타
    '때문에', '만약', '어쩌다', '어디', '모르겠다', '모르겠어',
    '생각', '느낌', '이고', '이며',
  };

  // 동사/형용사 활용 어미 — 이걸로 끝나는 단어는 의미없는 활용형
  static const _verbEndings = [
    '물어봐야지', '어야겠다', '아야겠다', '해야겠다', '봐야겠다',
    '어야지', '아야지', '해야지', '겠는데', '이렇게', '저렇게', '그렇게', '어떻게',
    '겠다', '겠어', '겠지', '겠죠', '같아', '같은', '같이', '않게', '않아',
    '않는', '않을', '싶어', '싶은', '면서', '으면', '아도', '어도',
    '도록', '려고', '으려', '지만', '니까', '으니', '라도', '더라', '던데',
    '봐야', '해야', '아야', '어야',
  ];

  // 긴 조사부터 먼저 체크해야 부분 매칭 방지
  static const _particles = [
    '에서부터', '에게서', '한테서', '으로부터', '로부터',
    '에서', '에게', '한테', '으로', '이랑', '부터', '까지', '이야', '에요',
    '이에요', '이고', '이며', '이나', '이라', '이면', '이라서',
    '랑', '와', '과', '을', '를', '이', '가', '은', '는', '의', '에', '로', '도',
    '만', '야', '아',
  ];

  static String _stripParticle(String word) {
    for (final p in _particles) {
      if (word.length > p.length + 1 && word.endsWith(p)) {
        return word.substring(0, word.length - p.length);
      }
    }
    return word;
  }

  static bool _isVerbForm(String word) {
    for (final ending in _verbEndings) {
      if (word.endsWith(ending)) return true;
    }
    return false;
  }

  static List<String> extractKeywordsLocal(String content) {
    var text = content
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'#\S+'), '')
        .replaceAll(RegExp(r'[0-9]+'), '');

    final words = text
        .split(RegExp(r"[\s\.,!?~\-_:;/\\()\[\]{}']+"))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    final keywords = <String>{};
    for (final word in words) {
      if (_isVerbForm(word)) continue;
      final stripped = _stripParticle(word);
      if (stripped.length >= 2 &&
          !_stopwords.contains(stripped) &&
          !_isVerbForm(stripped)) {
        keywords.add(stripped);
      }
    }
    return keywords.toList();
  }

  static String? _extractDomain(String? url) {
    if (url == null) return null;
    try {
      final uri = Uri.parse(url);
      var host = uri.host.replaceFirst('www.', '');
      // 짧게: 첫 번째 점 앞만 (naver, youtube 등)
      final dot = host.indexOf('.');
      return dot > 0 ? host.substring(0, dot) : host;
    } catch (_) {
      return null;
    }
  }

  static final _linkRe = RegExp(r'\[\[id:([^|]+)\|[^\]]+\]\]');

  // appendNotes에서 [[id:...|...]] 역참조 파싱
  static List<String> _parseLinkedIds(Memo memo) {
    final ids = <String>[];
    for (final note in memo.appendNotes) {
      for (final m in _linkRe.allMatches(note.content)) {
        ids.add(m.group(1)!);
      }
    }
    return ids;
  }

  static GraphData buildGraph(List<Memo> memos, {Map<String, List<String>>? aiCache}) {
    final rng = Random(42);
    const cx = 1000.0;
    const cy = 1000.0;

    // ── 1. 태그 허브 노드 ─────────────────────────────────────────
    final tagMemos = <String, Set<String>>{};
    for (final memo in memos) {
      for (final tag in memo.tags) {
        tagMemos.putIfAbsent(tag, () => {}).add(memo.id);
      }
    }
    // 2개 이상 메모에 붙은 태그만 허브로
    final tagNodes = tagMemos.entries
        .where((e) => e.value.length >= 2)
        .map((e) {
          final angle = rng.nextDouble() * 2 * pi;
          final radius = 80 + rng.nextDouble() * 180;
          return GraphNode(
            keyword: '#${e.key}',
            isTag: true,
            x: cx + cos(angle) * radius,
            y: cy + sin(angle) * radius,
            count: e.value.length,
            memoIds: e.value.toList(),
          );
        })
        .toList();

    // ── 2. 키워드 노드 ────────────────────────────────────────────
    final keywordMemos = <String, Set<String>>{};
    for (final memo in memos) {
      final keywords = aiCache != null && aiCache.containsKey(memo.id)
          ? aiCache[memo.id]!
          : extractKeywordsLocal(memo.content);
      for (final kw in keywords) {
        keywordMemos.putIfAbsent(kw, () => {}).add(memo.id);
      }
      // sourceUrl 도메인을 가상 키워드로 추가 (같은 출처 메모들 연결)
      final domain = _extractDomain(memo.sourceUrl);
      if (domain != null && domain.isNotEmpty) {
        keywordMemos.putIfAbsent(domain, () => {}).add(memo.id);
      }
    }

    final filtered = keywordMemos.entries.where((e) => e.value.length >= 3).toList();
    filtered.sort((a, b) => b.value.length.compareTo(a.value.length));

    final kwNodes = filtered.take(40).map((e) {
      final angle = rng.nextDouble() * 2 * pi;
      final radius = 200 + rng.nextDouble() * 350;
      return GraphNode(
        keyword: e.key,
        x: cx + cos(angle) * radius,
        y: cy + sin(angle) * radius,
        count: e.value.length,
        memoIds: e.value.toList(),
      );
    }).toList();

    final nodes = [...tagNodes, ...kwNodes];
    if (nodes.isEmpty) return const GraphData(nodes: [], edges: []);

    // ── 3. 엣지 ──────────────────────────────────────────────────
    final kwSet = {for (final n in kwNodes) n.keyword};
    final tagSet = {for (final n in tagNodes) n.keyword}; // '#태그' 형태
    final edgeMap = <String, int>{};

    for (final memo in memos) {
      final kws = (aiCache != null && aiCache.containsKey(memo.id)
              ? aiCache[memo.id]!
              : extractKeywordsLocal(memo.content))
          .where(kwSet.contains)
          .toList();

      // 키워드 ↔ 키워드 (동시 출현)
      for (int i = 0; i < kws.length; i++) {
        for (int j = i + 1; j < kws.length; j++) {
          final pair = [kws[i], kws[j]]..sort();
          final key = '${pair[0]}|${pair[1]}';
          edgeMap[key] = (edgeMap[key] ?? 0) + 1;
        }
      }

      // 태그 ↔ 키워드 (같은 메모에 태그와 키워드가 함께)
      for (final tag in memo.tags) {
        final hub = '#$tag';
        if (!tagSet.contains(hub)) continue;
        for (final kw in kws) {
          final pair = [hub, kw]..sort();
          final key = '${pair[0]}|${pair[1]}';
          edgeMap[key] = (edgeMap[key] ?? 0) + 1;
        }
      }
    }

    // ── 4. 명시적 연결([[id:...|...]])에서 추가 엣지 (가중치 높게) ──
    // 두 메모가 명시적으로 연결된 경우, 공유하는 키워드 노드 간 엣지 강화
    final memoKeywords = <String, Set<String>>{};
    for (final memo in memos) {
      final kws = (aiCache != null && aiCache.containsKey(memo.id)
              ? aiCache[memo.id]!
              : extractKeywordsLocal(memo.content))
          .where(kwSet.contains)
          .toSet();
      final domain = _extractDomain(memo.sourceUrl);
      if (domain != null && kwSet.contains(domain)) kws.add(domain);
      memoKeywords[memo.id] = kws;
    }

    for (final memo in memos) {
      final linkedIds = _parseLinkedIds(memo);
      for (final linkedId in linkedIds) {
        final kwsA = memoKeywords[memo.id] ?? {};
        final kwsB = memoKeywords[linkedId] ?? {};
        // 두 메모의 키워드 간 크로스 엣지 (연결 강화)
        for (final kA in kwsA) {
          for (final kB in kwsB) {
            if (kA == kB) continue;
            final pair = [kA, kB]..sort();
            final key = '${pair[0]}|${pair[1]}';
            edgeMap[key] = (edgeMap[key] ?? 0) + 3; // 명시적 연결은 가중치 +3
          }
        }
      }
    }

    final edges = edgeMap.entries.map((e) {
      final parts = e.key.split('|');
      return GraphEdge(from: parts[0], to: parts[1], weight: e.value);
    }).toList();

    return GraphData(nodes: nodes, edges: edges);
  }

  // ── 물리 시뮬레이션 ────────────────────────────────────────────

  // 애니메이션용: 매 프레임 호출, steps만큼만 계산
  static void runSimulationStep(
    GraphData data, {
    required int tick,
    required int totalTicks,
    int steps = 5,
  }) {
    final nodes = data.nodes;
    final edges = data.edges;
    if (nodes.isEmpty) return;
    final nodeMap = {for (final n in nodes) n.keyword: n};

    for (int s = 0; s < steps; s++) {
      final t = tick + s;
      if (t >= totalTicks) break;
      final alpha = 1.0 - t / totalTicks;
      _simulateOnce(nodes, edges, nodeMap, alpha);
    }
  }

  static void _simulateOnce(
    List<GraphNode> nodes,
    List<GraphEdge> edges,
    Map<String, GraphNode> nodeMap,
    double alpha,
  ) {
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final ni = nodes[i];
        final nj = nodes[j];
        final dx = nj.x - ni.x;
        final dy = nj.y - ni.y;
        final dist = sqrt(dx * dx + dy * dy).clamp(10.0, 600.0);
        final force = 4000.0 * alpha / (dist * dist);
        final fx = force * dx / dist;
        final fy = force * dy / dist;
        ni.vx -= fx;
        ni.vy -= fy;
        nj.vx += fx;
        nj.vy += fy;
      }
    }
    for (final edge in edges) {
      final ni = nodeMap[edge.from];
      final nj = nodeMap[edge.to];
      if (ni == null || nj == null) continue;
      final dx = nj.x - ni.x;
      final dy = nj.y - ni.y;
      final dist = sqrt(dx * dx + dy * dy).clamp(1.0, double.infinity);
      final force = 0.0008 * alpha * (dist - 100.0) * edge.weight;
      final fx = force * dx / dist;
      final fy = force * dy / dist;
      ni.vx += fx;
      ni.vy += fy;
      nj.vx -= fx;
      nj.vy -= fy;
    }
    const cx = 1000.0;
    const cy = 1000.0;
    for (final n in nodes) {
      n.vx += (cx - n.x) * 0.008 * alpha;
      n.vy += (cy - n.y) * 0.008 * alpha;
      n.vx *= 0.82;
      n.vy *= 0.82;
      n.x += n.vx;
      n.y += n.vy;
    }
  }

  static void runSimulation(GraphData data, {int ticks = 250}) {
    final nodes = data.nodes;
    final edges = data.edges;
    if (nodes.isEmpty) return;
    final nodeMap = {for (final n in nodes) n.keyword: n};
    for (int t = 0; t < ticks; t++) {
      _simulateOnce(nodes, edges, nodeMap, 1.0 - t / ticks);
    }
  }

  // ── Claude API 키워드 추출 ─────────────────────────────────────

  static Future<List<String>> extractKeywordsAI(
    String content,
    String apiKey,
  ) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(
        Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('x-api-key', apiKey)
        ..set('anthropic-version', '2023-06-01');

      final body = jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 80,
        'messages': [
          {
            'role': 'user',
            'content':
                '다음 메모에서 핵심 명사 키워드 3~5개만 쉼표로 구분해서 반환해. 설명 없이 단어만:\n\n$content',
          },
        ],
      });
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final text = (json['content'] as List).first['text'] as String;
        return text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.length <= 10)
            .toList();
      }
    } catch (_) {}
    return extractKeywordsLocal(content);
  }

  static Future<GraphData> buildGraphWithAI(
    List<Memo> memos,
    String apiKey, {
    void Function(int done, int total)? onProgress,
  }) async {
    final cache = await StorageService.loadKeywordCache();
    final uncached = memos.where((m) => !cache.containsKey(m.id)).toList();
    int done = 0;

    for (final memo in uncached) {
      if (memo.content.trim().length < 10) {
        cache[memo.id] = extractKeywordsLocal(memo.content);
      } else {
        cache[memo.id] = await extractKeywordsAI(memo.content, apiKey);
      }
      done++;
      onProgress?.call(done, uncached.length);

      // API 부하 방지
      if (done % 5 == 0) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    if (uncached.isNotEmpty) {
      await StorageService.saveKeywordCache(cache);
    }

    return buildGraph(memos, aiCache: cache);
  }
}
