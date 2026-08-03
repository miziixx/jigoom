import 'package:flutter/material.dart';

import 'studio_skin.dart';
import 'studio_tokens.dart';
import 'tracker_body.dart';
import 'widget_config.dart';

/// ============================================================
/// WIDGET STUDIO — 위젯 본문 9종 (레퍼런스 widgetContent / calendarContent 이식)
///
/// 각 함수는 .widget-body 안쪽 콘텐츠만 만든다(헤더·리사이즈는 WidgetFrame 담당).
/// 데이터가 없는 편집 미리보기에서는 레퍼런스와 동일한 샘플 문구를 쓴다(§16 —
/// 실데이터 연결은 후속 단계에서 이 본문에 주입).
/// ============================================================

Widget studioWidgetBody(
  WidgetConfig w,
  StudioSkin skin, {
  required TrackerState tracker,
  required ValueChanged<String> onTrackerDraft,
  required VoidCallback onTrackerStart,
  required VoidCallback onTrackerStop,
  int liveTick = 0,
}) {
  switch (w.type) {
    case StudioWidgetType.clock:
      return _clock(skin);
    case StudioWidgetType.goal:
      return _goal(skin, w.title);
    case StudioWidgetType.tracker:
      return TrackerBody(
        skin: skin,
        state: tracker,
        onDraft: onTrackerDraft,
        onStart: onTrackerStart,
        onStop: onTrackerStop,
        liveTick: liveTick,
      );
    case StudioWidgetType.tasks:
      return _tasks(skin, w.title);
    case StudioWidgetType.habits:
      return _habits(skin, w.title);
    case StudioWidgetType.matrix:
      return _matrix(skin);
    case StudioWidgetType.capture:
      return _capture(skin, w.title);
    case StudioWidgetType.fortune:
      return _fortune(skin, w.title);
    case StudioWidgetType.calendar:
      return _calendar(skin, w.view ?? StudioCalView.month);
  }
}

// --- 공용 조각 -------------------------------------------------------------

Widget _rule(StudioSkin s) => Container(height: s.lineWidth, color: s.line);

/// .w-check — 14×14 테두리 박스, done 이면 primary 채움 + ✓.
Widget _check(StudioSkin s, bool done) => Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? s.primary : null,
        border: Border.all(color: done ? s.primary : s.line, width: 1),
      ),
      child: done
          ? const Text('✓',
              style: TextStyle(
                  fontFamily: StudioFont.mono,
                  fontFamilyFallback: StudioFont.monoFallback,
                  fontSize: 9,
                  height: 1,
                  color: Colors.white))
          : null,
    );

/// .w-progress — 4px 트랙(primary 14%) + primary 채움.
Widget _progress(StudioSkin s, double pct) => SizedBox(
      height: 4,
      child: Stack(children: [
        Container(color: s.primary.withValues(alpha: 0.14)),
        FractionallySizedBox(
          widthFactor: pct.clamp(0.0, 1.0),
          child: Container(color: s.primary),
        ),
      ]),
    );

/// .w-row — strong(생략표시) + optional small.
Widget _row(StudioSkin s, String strong, {String? small, List<Widget>? extra}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(strong,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: s.rowStrong),
      if (extra != null) ...extra,
      if (small != null && !s.isTiny) ...[
        const SizedBox(height: 3),
        Text(small,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: s.rowSmall),
      ],
    ],
  );
}

// --- 시계 -----------------------------------------------------------------

Widget _clock(StudioSkin s) {
  final timeStyle = TextStyle(
    fontFamily: StudioFont.clock,
    fontSize: (s.isTiny ? 32 : 54) * s.font,
    fontWeight: FontWeight.w300,
    height: 1,
    letterSpacing: -0.08 * (s.isTiny ? 32 : 54) * s.font,
    color: s.primaryDark,
  );
  return Column(
    children: [
      if (!s.isTiny)
        Center(child: Text('8월 3일 월요일', style: s.wMeta)),
      Expanded(child: Center(child: Text('16:14', style: timeStyle))),
      if (!s.isTiny)
        Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: s.line, width: s.lineWidth))),
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: Text('丙申日 · 보름달', style: s.wMeta, overflow: TextOverflow.ellipsis)),
              Text('지금', style: s.chip),
            ],
          ),
        ),
    ],
  );
}

// --- 오늘의 목표 -----------------------------------------------------------

Widget _goal(StudioSkin s, String title) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TODAY'S GOAL", style: s.wMeta),
          const SizedBox(height: 5),
          Text(title, style: s.wTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (!s.isTiny) ...[
            const SizedBox(height: 5),
            Text('메인 흐름과 타임트래커 구조를 마무리하기',
                style: s.sans(7.8, color: s.muted, height: 1.45),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
      Row(
        children: [
          Expanded(child: _progress(s, 0.62)),
          const SizedBox(width: 8),
          Text('3 / 5', style: s.wMeta),
        ],
      ),
    ],
  );
}

// --- 오늘 할 일 ------------------------------------------------------------

Widget _tasks(StudioSkin s, String title) {
  final items = <(bool, String, String, String)>[
    (true, '고양이 밥주기', '#오늘 #생활', '완료'),
    (false, '위젯 크기 조절 구현', '#중요 #앱', '오늘'),
    (false, '달력 일진 표시 확인', '#긴급', '17:00'),
    (false, '백업 복원 테스트', '#앱', '내일'),
  ];
  final limit = s.isTiny ? 2 : (s.isCompact ? 3 : items.length);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: s.wTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 5),
      _rule(s),
      for (final it in items.take(limit))
        Container(
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: s.line, width: s.lineWidth))),
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _check(s, it.$1),
              const SizedBox(width: 7),
              Expanded(child: _row(s, it.$2, small: it.$3)),
              const SizedBox(width: 7),
              Text(it.$4, style: s.chip),
            ],
          ),
        ),
    ],
  );
}

// --- 습관 -----------------------------------------------------------------

Widget _habits(StudioSkin s, String title) {
  final items = <(String, String, String, bool)>[
    ('01', '물 한 잔', '아침 · 7일 연속', true),
    ('02', '5분 정리', '저녁 · 2일 연속', false),
    ('03', '10분 읽기', '밤 · 4일 연속', false),
  ];
  final limit = s.isTiny ? 2 : items.length;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: s.wTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 5),
      _rule(s),
      for (final it in items.take(limit))
        Container(
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: s.line, width: s.lineWidth))),
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(
                  width: 25,
                  child: Text(it.$1,
                      style: s.mono(7, color: s.primary, letterEm: 0))),
              Expanded(child: _row(s, it.$2, small: it.$3)),
              const SizedBox(width: 7),
              _check(s, it.$4),
            ],
          ),
        ),
    ],
  );
}

// --- 아이젠하워 매트릭스 ---------------------------------------------------

Widget _matrix(StudioSkin s) {
  Widget cell(Color bg, String h, String tag, String body) => Container(
        padding: const EdgeInsets.all(7),
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h,
                style: s.sans(8.2, weight: FontWeight.w600, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(tag, style: s.mono(5.8, color: s.muted, letterEm: 0.08)),
            if (!s.isTiny) ...[
              const SizedBox(height: 7),
              Text(body,
                  style: s.sans(6.7, height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      );

  final danger = const Color(0xFFA4514D).withValues(alpha: 0.10);
  final ochre = const Color(0xFFB08052).withValues(alpha: 0.11);
  final weak = s.primary.withValues(alpha: 0.08);
  return Column(
    children: [
      Expanded(
        child: Row(children: [
          Expanded(child: cell(danger, '긴급하고 중요', 'DO FIRST', 'UI 수정안 완성')),
          const SizedBox(width: 5),
          Expanded(
              child: cell(weak, '중요하지만\n긴급하지 않음', 'SCHEDULE', '콘텐츠 구조 설계')),
        ]),
      ),
      const SizedBox(height: 5),
      Expanded(
        child: Row(children: [
          Expanded(
              child: cell(ochre, '긴급하지만\n중요하지 않음', 'DELEGATE', '테스트 알림 확인')),
          const SizedBox(width: 5),
          Expanded(child: cell(weak, '둘 다 아님', 'DELETE', '현재 비어 있음')),
        ]),
      ),
    ],
  );
}

// --- 빠른 입력 -------------------------------------------------------------

Widget _capture(StudioSkin s, String title) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('＋',
            style: TextStyle(
                fontFamily: StudioFont.sans,
                fontSize: 27 * s.font,
                fontWeight: FontWeight.w200,
                height: 1,
                color: s.primary)),
        const SizedBox(height: 3),
        Text(title,
            style: s.sans(9, weight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (!s.isTiny) ...[
          const SizedBox(height: 4),
          Text('할 일 · 일정 · 기록 · 음성', style: s.sans(6.5, color: s.muted)),
        ],
      ],
    ),
  );
}

// --- 오늘의 운세 -----------------------------------------------------------

Widget _fortune(StudioSkin s, String title) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('☾', style: s.serif(25, color: s.primary, letterEm: 0)),
        const SizedBox(height: 7),
        if (!s.isTiny) Text("TODAY'S ACTION", style: s.wMeta),
        if (!s.isTiny) const SizedBox(height: 7),
        Text(title, style: s.wTitle, textAlign: TextAlign.center),
        const SizedBox(height: 7),
        Text('가장 가까운 일 하나를 10분만 시작하세요.',
            textAlign: TextAlign.center,
            style: s.sans(8, height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

// --- 캘린더 (DAY / WEEK / MONTH) ------------------------------------------

Widget _calendar(StudioSkin s, StudioCalView view) {
  final title = view == StudioCalView.month
      ? '2026년 8월'
      : view == StudioCalView.week
          ? '8.3 – 8.9'
          : '8월 3일';

  Widget tab(String label, bool active) => Text(
        label,
        style: s.mono(5.8, color: active ? s.primary : s.muted, letterEm: 0).copyWith(
              decoration: active ? TextDecoration.underline : null,
              decorationColor: s.primary,
            ),
      );

  final head = Container(
    decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.line, width: s.lineWidth))),
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CALENDAR', style: s.wMeta),
              Text(title, style: s.serif(15, weight: FontWeight.w500)),
            ],
          ),
        ),
        Row(children: [
          tab('DAY', view == StudioCalView.day),
          const SizedBox(width: 8),
          tab('WEEK', view == StudioCalView.week),
          const SizedBox(width: 8),
          tab('MONTH', view == StudioCalView.month),
        ]),
      ],
    ),
  );

  Widget body;
  switch (view) {
    case StudioCalView.day:
      body = _calendarDay(s);
      break;
    case StudioCalView.week:
      body = _calendarWeek(s);
      break;
    case StudioCalView.month:
      body = _calendarMonth(s);
      break;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [head, const SizedBox(height: 5), Flexible(child: body)],
  );
}

Widget _calendarDay(StudioSkin s) {
  final events = <(String, String, String)>[
    ('09:00', '아침 루틴', '물 한 잔 · 약 챙기기'),
    ('12:30', '앱 개발 기록', '12:30–13:00 · 30분'),
    ('16:00', '레이아웃 검토', '오늘 할 일 2개'),
    ('21:00', '베리 레이키', 'Google Calendar'),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final e in events)
        Container(
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: s.line, width: s.lineWidth))),
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 35, child: Text(e.$1, style: s.mono(6.5, letterEm: 0))),
              const SizedBox(width: 7),
              Container(width: 2, height: 20, color: s.primary),
              const SizedBox(width: 7),
              Expanded(child: _row(s, e.$2, small: e.$3)),
            ],
          ),
        ),
    ],
  );
}

Widget _calendarWeek(StudioSkin s) {
  const days = ['월', '화', '수', '목', '금'];
  // 시간행: [시각, 월,화,수,목,금] — week-block 은 (텍스트|null).
  final rows = <(String, List<String?>)>[
    ('09', [null, '주간 보고', null, '검진', null]),
    ('12', ['리뷰', null, '미팅', null, '핸드오프']),
    ('15', [null, 'UX 발표', null, '로드맵', null]),
    ('18', [null, null, '필라테스', null, null]),
  ];

  Border cellBorder = Border(
    right: BorderSide(color: s.line, width: s.lineWidth),
    bottom: BorderSide(color: s.line, width: s.lineWidth),
  );

  Widget block(String? text) {
    if (text == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(3),
      color: s.primary.withValues(alpha: 0.18),
      child: Text(text,
          style: s.mono(5.8, color: s.ink, letterEm: 0),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // 헤더 행: 34px 빈칸 + 요일 라벨.
      Container(
        decoration: BoxDecoration(border: cellBorder),
        child: Row(children: [
          Container(
              width: 34,
              decoration:
                  BoxDecoration(border: Border(right: BorderSide(color: s.line, width: s.lineWidth))),
              padding: const EdgeInsets.symmetric(vertical: 3)),
          for (final d in days)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: s.line, width: s.lineWidth))),
                padding: const EdgeInsets.symmetric(vertical: 3),
                alignment: Alignment.center,
                child: Text(d, style: s.sans(6)),
              ),
            ),
        ]),
      ),
      for (final r in rows)
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 34,
              decoration: BoxDecoration(border: cellBorder),
              padding: const EdgeInsets.all(2),
              child: Text(r.$1, style: s.mono(5.5, letterEm: 0)),
            ),
            for (final b in r.$2)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: cellBorder),
                  alignment: Alignment.topLeft,
                  child: block(b),
                ),
              ),
          ]),
        ),
    ],
  );
}

Widget _calendarMonth(StudioSkin s) {
  const week = ['일', '월', '화', '수', '목', '금', '토'];
  // days: i<5 ? 27+i : i-4  (레퍼런스). 35칸.
  final days = List<int>.generate(35, (i) => i < 5 ? 27 + i : i - 4);
  const eventDays = {7, 11, 15, 19, 26};

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          for (final d in week)
            Expanded(
                child: Center(child: Text(d, style: s.sans(5.5, color: s.muted)))),
        ],
      ),
      const SizedBox(height: 3),
      Expanded(
        child: GridView.count(
          crossAxisCount: 7,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          children: [
            for (final d in days)
              _monthDay(s, d, isToday: d == 3, hasEvent: eventDays.contains(d)),
          ],
        ),
      ),
    ],
  );
}

Widget _monthDay(StudioSkin s, int d,
    {required bool isToday, required bool hasEvent}) {
  return Container(
    decoration: isToday
        ? BoxDecoration(border: Border.all(color: s.primary, width: 1))
        : null,
    alignment: Alignment.center,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$d',
                style: s.sans(7,
                    color: isToday ? s.primaryDark : s.ink)),
            if (isToday) ...[
              const SizedBox(height: 1),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: s.primary, width: 1)),
              ),
            ],
          ],
        ),
        if (hasEvent)
          Positioned(
            bottom: 1,
            child: Container(
              width: 3,
              height: 3,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: s.primary),
            ),
          ),
      ],
    ),
  );
}
