// §11-5 "본인 말투 회귀 코퍼스" — 사용자가 실제 쓰는 말투를 고정한 방어선.
//
// 사용자 말투 패턴(사용자 제공):
//   ① 조사 생략  ② ~날 접미사  ③ 명령어미 ~줘/~놔/~바  ④ 한 문장 명령 2개(복합)
//   ⑤ 과거형=기록 · 미래형=등록  ⑥ 금액은 만원 단위
//
// 판정 정책(§8 안전망 + §2):
//   - **모든 문장은 크래시 없이, 원문을 보존한 채** 어딘가로 라우팅돼야 한다(rawText 단정).
//   - 범위 내(콜로케이션·담기동사·체크·과거기록·양력공휴일)는 인텐트/라우팅/슬롯까지 정확히.
//   - 범위 밖(복합·삭제·수정·음력·기간·반복·알림·금액·질문)은 안전망(A/보류함/기록)에
//     떨어지되 **말을 버리지 않는다**. 상세 로드맵은 spec §13.
//
// 기준일 base = 2026-07-24(금).
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';
import 'package:jigeum/features/voice/models/time_parse_result.dart';
import 'package:jigeum/features/voice/voice_router.dart';

/// 한 문장의 기대치. 채운 필드만 단정한다(null 은 검증 안 함).
class Exp {
  const Exp(
    this.raw, {
    this.intent,
    this.route,
    this.title,
    this.date,
    this.time,
    this.durationMin,
    this.isPast,
    this.note,
  });

  final String raw;
  final IntentType? intent;
  final RoutePoint? route;
  final String? title;
  final DateTime? date;
  final ParsedTime? time;
  final int? durationMin;
  final bool? isPast;

  /// 범위 밖/미지원 사유(문서용). 있으면 안전망만 검증하는 케이스임을 표시.
  final String? note;
}

final DateTime base = DateTime(2026, 7, 24);

/// 카테고리별 코퍼스. (사용자 제공 40여 문장 + 앞선 10문장)
final Map<String, List<Exp>> corpus = {
  '일정 등록': [
    Exp('1월 1일날 데이트 적어줘',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        date: DateTime(2027, 1, 1),
        title: '데이트'),
    Exp('29년 3월 13일 14시 보험료 9만원 적어줘',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        date: DateTime(2029, 3, 13),
        time: const ParsedTime(14, 0),
        note: '금액(9만원) 미지원 → 제목에 잔류'),
    Exp('24일날 10만원 보험료 추가해줘',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        date: DateTime(2026, 7, 24),
        note: '금액(10만원) 미지원'),
    Exp('담주 화요일 3시에 치과 잡아줘',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        time: const ParsedTime(15, 0),
        title: '치과'),
    Exp('다음달 15일날 엄마 생신 넣어줘',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        date: DateTime(2026, 8, 15),
        title: '엄마 생신'),
    Exp('모레 저녁 7시 반에 약속 하나 추가',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        date: DateTime(2026, 7, 26),
        time: const ParsedTime(19, 30)),
    Exp('내년 1월 2일부터 4일까지 여행 걸어줘',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        date: DateTime(2027, 1, 2),
        note: '기간(부터~까지) 미지원 → 시작일만'),
    Exp('8월 첫째주 금요일에 회식 있다고 적어놔',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        note: '주차(첫째주) 미지원 → 날짜 부정확'),
    Exp('매주 수요일 저녁에 헬스 반복으로 넣어줘',
        note: '반복(매주) 미지원 → 단발 일정으로 안착'),
  ],
  '할일 추가': [
    Exp('자기 전에 약 먹기 추가해줘',
        intent: IntentType.todoAdd,
        route: RoutePoint.quickCapture,
        title: '자기 전에 약 먹기'),
    Exp('주말에 세차하기 하나 넣어놔',
        intent: IntentType.todoAdd,
        route: RoutePoint.quickCapture,
        note: '주말 날짜 미지원'),
    Exp('내일까지 서류 제출하는거 잊지말라고 띄워줘',
        note: '마감(까지) 할일 → 일정으로 안착(할일+마감 미분리)'),
    Exp('오늘 안에 택배 부치기 넣어줘',
        note: '오늘까지 할일 → 일정으로 안착'),
  ],
  '지금기록(과거형=기록 ⑤)': [
    Exp('오늘 책읽기 했어',
        intent: IntentType.logNow,
        route: RoutePoint.logNow,
        isPast: true,
        title: '책읽기'),
    Exp('10시 반에 주문넣음',
        intent: IntentType.logNow,
        route: RoutePoint.logNow,
        time: const ParsedTime(10, 30),
        isPast: true,
        title: '주문'),
    Exp('9시 40분에 퇴근 찍음',
        intent: IntentType.logNow,
        route: RoutePoint.logNow,
        time: const ParsedTime(9, 40),
        isPast: true,
        title: '퇴근'),
    Exp('아까 2시간 정도 작업했다고 넣어줘',
        intent: IntentType.logNow,
        route: RoutePoint.logNow,
        durationMin: 120,
        isPast: true),
    Exp('방금 배송 출발함',
        intent: IntentType.logNow,
        route: RoutePoint.logNow,
        isPast: true,
        title: '배송'),
    Exp('지금부터 공부 시작',
        note: '"시작"(타이머/기록 개시) 트리거 미지원 → 보류함'),
  ],
  '습관 체크': [
    Exp('오늘 습관에 독서하기 체크해줘',
        intent: IntentType.habitCheck,
        route: RoutePoint.habit,
        title: '독서하기'),
    Exp('오늘 물 마시기 다 채웠어',
        intent: IntentType.habitCheck, route: RoutePoint.habit),
    Exp('오늘 금연 성공',
        intent: IntentType.habitCheck, route: RoutePoint.habit),
    Exp('어제꺼 운동 체크 안했는데 지금 해줘',
        note: '부정문(안했는데) → 과거로 오인 가능'),
    Exp('이번주 독서 몇번 했지',
        intent: IntentType.none,
        route: RoutePoint.inbox,
        note: '질문(몇번/했지) → 보류함(질문 감지 미지원)'),
  ],
  '기념일/공휴일': [
    Exp('광복절날 일하기 추가해줘',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        date: DateTime(2026, 8, 15),
        title: '일하기'),
    Exp('어린이날에 놀이공원 적어줘',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        date: DateTime(2027, 5, 5)),
    Exp('크리스마스 이브에 저녁 예약 추가',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        note: '"크리스마스 이브" 공백 → 이브 미반영(12/25로 인식)'),
    Exp('제헌절 쉬는날 맞나',
        note: '질문+공휴일 → A(질문 감지 미지원)'),
    Exp('올해 추석에 본가가기 추가해줘',
        intent: IntentType.todoAdd,
        route: RoutePoint.quickCapture,
        note: '추석 음력 미지원 + 연휴 다일 미지원 → 날짜 없이 A'),
    Exp('설날에 큰집가기 넣어줘 연휴 내내로',
        intent: IntentType.todoAdd,
        route: RoutePoint.quickCapture,
        note: '설날 음력 미지원'),
  ],
  '지출/금액 (⑥ 만원단위, 미지원)': [
    Exp('어제 점심 만이천원 썼어',
        intent: IntentType.logNow, route: RoutePoint.logNow, isPast: true),
    Exp('이번달 관리비 15만 오천원 나감',
        intent: IntentType.logNow, route: RoutePoint.logNow, isPast: true),
    Exp('30년 5월에 적금 만기 200 들어옴',
        intent: IntentType.logNow, route: RoutePoint.logNow, isPast: true),
    Exp('25일날 월세 60 빠져나가는거 등록',
        intent: IntentType.scheduleAdd,
        route: RoutePoint.schedule,
        date: DateTime(2026, 7, 25),
        note: '금액(60만원) 미지원'),
    Exp('아까 카페에서 오천원 결제함',
        intent: IntentType.logNow, route: RoutePoint.logNow, isPast: true),
  ],
  '복합 명령 (④ 미지원)': [
    Exp('낼모레 안경사기 추가해줘 아 거기에 돗수 다시재기 메모추가해줘',
        note: '복합(2개) + STT오타(돗수→도수) → 앞 동작만'),
    Exp('목요일에 미용실 추가하고 컷트만 한다고 메모 달아줘',
        note: '복합 명령 미지원 → 앞 동작만'),
    Exp('내일 회의 넣어줘 아 장소 3층 회의실로 적어놔',
        note: '복합 명령 미지원 → 장소 메모 유실'),
    Exp('다음주 월요일 병원 넣고 알림 한시간전으로 해줘',
        note: '알림(reminder) 미지원 + 복합'),
    Exp('15일에 이사 적어주고 그날 하루종일로 해줘',
        note: '하루종일(allday) + 복합 미지원'),
  ],
  '수정/삭제/취소 (§12 범위 밖)': [
    Exp('내일 약속 2시로 미뤄줘', note: '수정(미뤄줘) §12 밖 → 새 일정 오생성 위험'),
    Exp('아까 넣은 보험료 9만원 말고 8만원이야', note: '수정 §12 밖'),
    Exp('금요일 저녁 약속 지워줘', note: '삭제(지워줘) §12 밖 → 오히려 생성 위험'),
    Exp('이번주 헬스 다 취소', note: '취소 §12 밖'),
    Exp('어제 적은거 잘못 적었어 빼줘', note: '삭제(빼줘) §12 밖'),
  ],
};

void main() {
  final router = VoiceRouter();

  corpus.forEach((category, cases) {
    group('§11-5 $category', () {
      for (final e in cases) {
        test('"${e.raw}"', () {
          // ── 안전망 불변식: 크래시 없이 원문 보존 (말을 버리지 않음) ──
          // analyze 가 던지면 이 줄에서 테스트가 실패한다(= 크래시 방어선).
          final res = router.analyze(e.raw, now: base);
          expect(res.rawText, e.raw, reason: '원문 보존(되돌리기 안전망)');
          // 라우팅은 언제나 유효한 목적지(none 인텐트는 보류함이어야).
          if (res.intent == IntentType.none) {
            expect(res.routedTo, RoutePoint.inbox);
          }

          // ── 채운 필드만 정밀 단정 ──
          if (e.intent != null) {
            expect(res.intent, e.intent, reason: '인텐트');
          }
          if (e.route != null) {
            expect(res.routedTo, e.route, reason: '라우팅');
          }
          if (e.title != null) {
            expect(res.slots.title, e.title, reason: '제목/내용');
          }
          if (e.date != null) {
            expect(res.timeParse.date, e.date, reason: '날짜');
          }
          if (e.time != null) {
            expect(res.timeParse.time, e.time, reason: '시각');
          }
          if (e.durationMin != null) {
            expect(res.timeParse.durationMin, e.durationMin, reason: '기간');
          }
          if (e.isPast != null) {
            expect(res.timeParse.isPast, e.isPast, reason: '과거 시제');
          }
        });
      }
    });
  });

  test('코퍼스 규모(§11-5: 실사용 말투를 계속 확장)', () {
    final total = corpus.values.fold<int>(0, (n, l) => n + l.length);
    expect(total, greaterThanOrEqualTo(40));
  });
}
