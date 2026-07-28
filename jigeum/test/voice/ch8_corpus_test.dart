// 기획서 §8 "테스트 문장 세트 (완료 판정 기준)" 를 코드로 고정한 회귀 코퍼스.
//
// 커밋4(파서) 전에 먼저 고정한다(§5 지시: "테스트 케이스부터 고정하고 구현").
//  - 활성: 날짜·시간 파싱 단정 → 커밋4 KoDateTimeParser 로 green 이 되어야 완료.
//  - skip: 인텐트·라우팅·슬롯 단정 → 커밋6~8(IntentClassifier/SlotExtractor/
//    VoiceRouter) 이후 활성화. 지금은 기대값을 데이터로만 박아둔다.
//
// 기준일 now = 2026-07-24(금). "내일"=07-25, "금요일"=당일(가장 가까운 미래 요일).
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';
import 'package:jigeum/features/voice/models/time_parse_result.dart';
import 'package:jigeum/features/voice/models/voice_result.dart';
import 'package:jigeum/features/voice/pipeline/ko_datetime_parser.dart';
import 'package:jigeum/features/voice/pipeline/text_normalizer.dart';
import 'package:jigeum/features/voice/voice_router.dart';

/// §8 한 문장의 기대치.
class Case {
  const Case(
    this.raw, {
    required this.intent,
    required this.route,
    this.dateOffset,
    this.weekday,
    this.time,
    this.durationMin,
    this.isPast = false,
    this.title,
  });

  /// 말한 원문.
  final String raw;

  /// 기대 인텐트(§8). 안전망은 none.
  final IntentType intent;

  /// 기대 라우팅 지점(§8).
  final RoutePoint route;

  /// now 로부터의 날짜 오프셋(일). null = 날짜 없음.
  final int? dateOffset;

  /// 날짜를 요일로만 검증(예: 금요일). dateOffset 과 택1.
  final int? weekday;

  /// 기대 시각. null = 없음.
  final ParsedTime? time;

  /// 기대 기간(분). null = 없음.
  final int? durationMin;

  /// 과거 시제 여부.
  final bool isPast;

  /// 기대 제목/내용(슬롯). 커밋7에서 검증.
  final String? title;

  bool get expectsDate => dateOffset != null || weekday != null;
}

/// 기준일 — 2026-07-24 은 금요일.
final DateTime base = DateTime(2026, 7, 24);

/// §8 표 15문장.
final List<Case> corpus = [
  const Case('내일 3시에 치과 예약',
      intent: IntentType.scheduleAdd,
      route: RoutePoint.schedule,
      dateOffset: 1,
      time: ParsedTime(15, 0),
      title: '치과'),
  const Case('금요일에 장보기',
      intent: IntentType.scheduleAdd,
      route: RoutePoint.schedule,
      weekday: DateTime.friday,
      title: '장보기'),
  const Case('장보기 할 일로 넣어줘',
      intent: IntentType.todoAdd, route: RoutePoint.quickCapture, title: '장보기'),
  const Case('이거 중요하고 급해 보고서',
      intent: IntentType.todoMatrix, route: RoutePoint.matrix, title: '보고서'),
  const Case('방금 30분 코딩했어',
      intent: IntentType.logNow,
      route: RoutePoint.logNow,
      durationMin: 30,
      isPast: true,
      title: '코딩'),
  const Case('물 마시기 습관 만들어',
      intent: IntentType.habitAdd, route: RoutePoint.habit, title: '물 마시기'),
  const Case('아침 루틴에 스트레칭 추가',
      intent: IntentType.routineAdd, route: RoutePoint.routine, title: '스트레칭'),
  const Case('영어공부 목표 세울래',
      intent: IntentType.goalAdd, route: RoutePoint.goal, title: '영어공부'),
  const Case('오늘 목표는 보고서 끝내기',
      intent: IntentType.goalToday,
      route: RoutePoint.goalToday,
      dateOffset: 0,
      title: '보고서 끝내기'),
  const Case('지금 25분만 집중할래',
      intent: IntentType.focusStart,
      route: RoutePoint.focus,
      durationMin: 25),
  const Case('오늘 운세 봐줘',
      intent: IntentType.helpFortune,
      route: RoutePoint.helpFortune,
      dateOffset: 0),
  const Case('이번 달 달력 보여줘',
      intent: IntentType.navMove, route: RoutePoint.nav),
  const Case('막혔어 못하겠어',
      intent: IntentType.helpStuck, route: RoutePoint.helpStuck),
  const Case('어… 그거 있잖아 뭐였지',
      intent: IntentType.none, route: RoutePoint.inbox),
  const Case('파란색 그거 처리',
      intent: IntentType.todoAdd, route: RoutePoint.quickCapture, title: '파란색 그거 처리'),
];

void main() {
  const normalizer = TextNormalizer();
  const parser = KoDateTimeParser();

  TimeParseResult parseOf(Case c) =>
      parser.parse(normalizer.normalize(c.raw), now: base);

  group('§8 코퍼스 — 날짜·시간 파싱 (커밋4 완료 조건)', () {
    for (final c in corpus) {
      test('"${c.raw}"', () {
        final r = parseOf(c);

        // 날짜
        if (c.dateOffset != null) {
          expect(r.date, isNotNull, reason: '날짜가 잡혀야 함');
          final expected = DateTime(base.year, base.month, base.day)
              .add(Duration(days: c.dateOffset!));
          expect(r.date, expected);
        } else if (c.weekday != null) {
          expect(r.date, isNotNull, reason: '요일 날짜가 잡혀야 함');
          expect(r.date!.weekday, c.weekday);
          expect(r.date!.isBefore(base), isFalse, reason: '과거가 아니어야 함');
        } else {
          expect(r.date, isNull, reason: '날짜가 없어야 함(오검출 금지)');
        }

        // 시각
        expect(r.time, c.time);

        // 기간
        expect(r.durationMin, c.durationMin);

        // 과거 시제
        expect(r.isPast, c.isPast);
      });
    }
  });

  test('§8 #1 시간부 제거 후 남는 텍스트가 제목 후보', () {
    final c = corpus.first; // "내일 3시에 치과 예약"
    final normalized = normalizer.normalize(c.raw);
    expect(parseOf(c).stripFrom(normalized), '치과 예약');
  });

  group('코퍼스 자체 정합성(항상 활성)', () {
    test('15문장 + 안전망 2종(보류함·빠른담기) 포함', () {
      expect(corpus.length, 15);
      expect(corpus.any((c) => c.route == RoutePoint.inbox), isTrue);
      expect(corpus.any((c) => c.route == RoutePoint.quickCapture), isTrue);
    });

    test('기대 라우팅은 인텐트 기본 지점과 일치(폴백 제외)', () {
      // "애매→A" 폴백(파란색 그거 처리)만 예외. 나머지는 §3-1 매핑과 같아야 한다.
      for (final c in corpus) {
        if (c.intent == IntentType.todoAdd &&
            c.route == RoutePoint.quickCapture) {
          continue; // todo.add 는 원래 A. 폴백과 구분 불가하지만 동일 지점.
        }
        expect(defaultRoutePointOf(c.intent), c.route, reason: '"${c.raw}"');
      }
    });
  });

  // 커밋6~8 완료로 활성화: 정규화문 → 분류 → 슬롯 → 라우팅 전 구간 검증.
  //
  // 라우팅 단정은 §2 세 갈래 결정에 맞춘다. §8 표의 route 는 "인텐트의 기본
  // 지점"이라, 확정(confirm)일 때만 그 지점으로 간다. 임계 미달이면 §2 대로
  // 빠른담기(A)로, 미인식이면 보류함으로 떨어지는 게 정답이다.
  //  - "금요일에 장보기"(§8 "C 또는 A")·"파란색 그거 처리"(애매) → A 안착.
  //  - 인텐트 자체는 최고점이라 확정 여부와 무관하게 §8 기대치와 같아야 한다.
  group('§8 코퍼스 — 인텐트·라우팅·슬롯', () {
    final router = VoiceRouter();
    for (final c in corpus) {
      test('"${c.raw}" → ${c.intent.code} / ${c.route.label}', () {
        final r = router.analyze(c.raw, now: base);

        // 인텐트: 최고점 인텐트는 §8 기대치와 일치(안전망은 none).
        expect(r.intent, c.intent, reason: '인텐트');

        // 라우팅: 세 갈래 결정에 따라.
        switch (r.decision) {
          case RouteDecision.inbox:
            expect(r.routedTo, RoutePoint.inbox, reason: '미인식→보류함');
            expect(c.route, RoutePoint.inbox, reason: '§8 도 보류함이어야');
          case RouteDecision.quickCapture:
            // 애매 폴백은 항상 A. §8 route 가 A(정상)거나 "C 또는 A" 애매.
            expect(r.routedTo, RoutePoint.quickCapture, reason: '애매→A');
          case RouteDecision.confirm:
            expect(r.routedTo, c.route, reason: '확정 라우팅');
        }

        // 슬롯 제목/내용(있을 때만).
        if (c.title != null) {
          expect(r.slots.title, c.title, reason: '제목/내용');
        }
      });
    }
  });
}
