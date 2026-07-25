// 내 코퍼스(550문장) 기준 baseline 정확도 측정 + 혼동행렬.
//
// 실제 엔진(VoiceRouter)에 각 문장을 태워 예측 버킷을 뽑고, 기대 카테고리와
// 대조한다. 통과/실패 판정용이 아니라 **측정 리포트**다 — 출력(print)을 CI
// 로그에서 읽어 튜닝 방향(혼동 쌍)을 잡는 게 목적. 그래서 임계 단정은 최소.
//
// 카테고리 → 엔진 RoutePoint 매핑:
//   일정=schedule · 빠른담기=quickCapture · 매트릭스=matrix ·
//   지금기록=logNow · 습관=habit · 보류함=inbox
//   타임트래커 = 엔진에 대응 버킷 없음(현재 어디로 새는지만 관찰).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';
import 'package:jigeum/features/voice/voice_router.dart';

/// 예측된 RoutePoint 를 코퍼스 버킷 라벨로 환원.
String bucketOf(RoutePoint r) => switch (r) {
      RoutePoint.schedule => '일정',
      RoutePoint.quickCapture => '빠른담기',
      RoutePoint.matrix => '매트릭스',
      RoutePoint.logNow => '지금기록',
      RoutePoint.habit => '습관',
      RoutePoint.timeTrack => '타임트래커',
      RoutePoint.inbox => '보류함',
      _ => '기타',
    };

void main() {
  test('내 코퍼스 baseline — 혼동행렬 + 정확도', () {
    final f = File('test/voice/corpus/my_corpus.csv');
    expect(f.existsSync(), isTrue, reason: '코퍼스 CSV 를 못 찾음');

    final rows = f
        .readAsLinesSync()
        .skip(1) // 헤더
        .where((l) => l.trim().isNotEmpty)
        .toList();
    expect(rows.length, greaterThan(500));

    const cats = ['일정', '빠른담기', '매트릭스', '지금기록', '습관', '보류함', '타임트래커'];
    const buckets = [
      '일정', '빠른담기', '매트릭스', '지금기록', '습관', '보류함', '타임트래커', '기타'
    ];

    final conf = {
      for (final c in cats) c: {for (final b in buckets) b: 0}
    };
    final catTotal = {for (final c in cats) c: 0};

    var cleanTot = 0, cleanOk = 0;
    var typoTot = 0, typoRawOk = 0, typoNormOk = 0;
    final misses = <String>[];

    final router = VoiceRouter();
    final now = DateTime(2026, 7, 25, 10, 0); // 파싱 기준 고정(재현성)

    for (final line in rows) {
      final p = line.split(',');
      if (p.length < 3) continue;
      final sent = p[0].trim();
      final cat = p[1].trim();
      final isTypo = (p.length > 2 ? p[2].trim() : 'N') == 'Y';
      final norm = p.length > 3 ? p.sublist(3).join(',').trim() : '';
      if (!cats.contains(cat) || sent.isEmpty) continue;

      final pred = bucketOf(router.analyze(sent, now: now).routedTo);
      conf[cat]![pred] = conf[cat]![pred]! + 1;
      catTotal[cat] = catTotal[cat]! + 1;

      final ok = pred == cat; // 타임트래커도 이제 버킷이 있어 매칭 대상.

      if (!isTypo) {
        cleanTot++;
        if (ok) cleanOk++;
      } else {
        typoTot++;
        if (ok) typoRawOk++;
        if (norm.isNotEmpty) {
          final predN = bucketOf(router.analyze(norm, now: now).routedTo);
          if (predN == cat) typoNormOk++;
        }
      }

      if (!ok && misses.length < 80) {
        misses.add('  [기대 $cat → 예측 $pred] $sent');
      }
    }

    final b = StringBuffer()
      ..writeln('\n=== 내 코퍼스 BASELINE (${rows.length}문장) ===')
      ..writeln('\n[혼동행렬]  기대(개수) → 예측 분포   [정확도]');
    for (final c in cats) {
      final dist = buckets
          .where((x) => conf[c]![x]! > 0)
          .map((x) => '$x:${conf[c]![x]}')
          .join('  ');
      final total = catTotal[c]!;
      final acc = total == 0 ? 0.0 : conf[c]![c]! * 100 / total;
      b.writeln('  $c ($total) → $dist   [${acc.toStringAsFixed(1)}%]');
    }

    final cleanAcc = cleanTot == 0 ? 0.0 : cleanOk * 100 / cleanTot;
    final typoRawAcc = typoTot == 0 ? 0.0 : typoRawOk * 100 / typoTot;
    final typoNormAcc = typoTot == 0 ? 0.0 : typoNormOk * 100 / typoTot;
    b
      ..writeln('\n[정확도 요약]')
      ..writeln('  깨끗한 문장(오타X): $cleanOk/$cleanTot = '
          '${cleanAcc.toStringAsFixed(1)}%   ← 진짜 분류 정확도')
      ..writeln('  오타 문장 원문:     $typoRawOk/$typoTot = '
          '${typoRawAcc.toStringAsFixed(1)}%')
      ..writeln('  오타 문장 정규화후: $typoNormOk/$typoTot = '
          '${typoNormAcc.toStringAsFixed(1)}%   ← 오타만 고치면 이만큼')
      ..writeln('\n[오답 예시 ${misses.length}개]');
    for (final m in misses) {
      b.writeln(m);
    }
    b.writeln('=== 끝 ===\n');

    // ignore: avoid_print
    print(b.toString());
  });
}
