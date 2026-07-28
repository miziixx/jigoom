/// 슬롯 추출기. 기획서 §3-1("뽑는 슬롯") + §5 커밋7.
///
/// 인텐트가 정해진 뒤, 정규화문과 시간 파싱 결과로부터 인텐트별 슬롯을 채운다.
///  - 제목/내용 : 파서가 시간부를 잘라낸(`stripFrom`) 뒤, 인텐트별 구조어
///                (§ 사전 stripWords)를 마저 걷어내 순수 제목만 남긴다.
///  - 중요/긴급 : todo.matrix 형용사로 두 축을 채운다.
///  - 그룹/스텝 : routine 은 "아침 루틴에 스트레칭" → 그룹=아침, 스텝=스트레칭.
///  - 분/날짜/시각 : 파서 결과를 그대로 슬롯에 옮긴다.
///
/// 프레임워크 비의존(순수 Dart).
library;

import '../data/intent_lexicon.dart';
import '../models/intent_type.dart';
import '../models/time_parse_result.dart';
import '../models/voice_result.dart';
import 'ko_money_parser.dart';

class SlotExtractor {
  const SlotExtractor({this.knownHabits = const <String>{}});

  /// §11-2 등록 습관명 — habit.check 대상 이름 확정에 쓴다.
  final Set<String> knownHabits;

  static const KoMoneyParser _money = KoMoneyParser();

  /// [intent] 에 맞는 슬롯을 [normalized] 와 [tp] 로부터 뽑는다.
  VoiceSlots extract(
    IntentType intent,
    String normalized,
    TimeParseResult tp,
  ) {
    // 시간부(날짜/시각/기간/과거마커)를 걷어낸 제목 후보.
    final base = tp.stripFrom(normalized);

    switch (intent) {
      case IntentType.scheduleAdd:
        final tm = _titleMoney(base, intent);
        return VoiceSlots(
          title: tm.title,
          amount: tm.amount,
          date: tp.date,
          time: tp.time,
        );

      case IntentType.todoAdd:
        final tm = _titleMoney(base, intent);
        return VoiceSlots(
          title: tm.title,
          amount: tm.amount,
          date: tp.date, // 마감일 후보(있으면).
        );

      case IntentType.todoMatrix:
        return VoiceSlots(
          title: _nullIfEmpty(_strip(base, intent)),
          important: _hasAny(normalized, const ['중요', '당장', '오늘까지']),
          urgent: _hasAny(normalized, const ['급해', '긴급', '빨리', '당장', '오늘까지']),
        );

      case IntentType.logNow:
      case IntentType.timeTrack:
        final tm = _titleMoney(base, intent);
        return VoiceSlots(
          title: tm.title,
          amount: tm.amount,
          durationMin: tp.durationMin,
        );

      case IntentType.habitAdd:
        final name = _nullIfEmpty(_strip(base, intent));
        return VoiceSlots(title: name, habitName: name);

      case IntentType.habitCheck:
        // 등록 습관명 우선. 없으면 구조어를 걷어낸 나머지를 대상 이름으로.
        final matched = knownHabits.firstWhere(
          (h) => h.isNotEmpty && normalized.contains(h),
          orElse: () => '',
        );
        final name =
            matched.isNotEmpty ? matched : _nullIfEmpty(_strip(base, intent));
        return VoiceSlots(title: name, habitName: name);

      case IntentType.routineAdd:
        return _extractRoutine(base);

      case IntentType.goalAdd:
        return VoiceSlots(title: _nullIfEmpty(_strip(base, intent)));

      case IntentType.goalToday:
        final t = _nullIfEmpty(_strip(base, intent));
        return VoiceSlots(title: t, text: t);

      case IntentType.focusStart:
        return VoiceSlots(
          title: _nullIfEmpty(_strip(base, intent)),
          durationMin: tp.durationMin,
        );

      case IntentType.navMove:
        return VoiceSlots(navDest: _nullIfEmpty(_strip(base, intent)));

      case IntentType.helpStuck:
      case IntentType.helpFortune:
      case IntentType.none:
        return const VoiceSlots();
    }
  }

  // -------------------------------------------------------------- 제목 정리

  /// 구조어를 걷어낸 제목에서 금액(원)까지 분리한다(§13). 금액 문자열은 제목에서
  /// 제거하고 [amount](원)로 뽑는다. (예: "10만원 보험료" → 제목 "보험료", amount 100000)
  ({String? title, int? amount}) _titleMoney(String base, IntentType intent) {
    var title = _strip(base, intent);
    final mp = _money.parse(title);
    if (mp.amount == null || mp.matchText == null) {
      return (title: _nullIfEmpty(title), amount: null);
    }
    title = title
        .replaceAll(mp.matchText!, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return (title: _nullIfEmpty(title), amount: mp.amount);
  }

  /// [base] 에서 [intent] 의 stripWords 를 걷어낸다.
  ///  1) 공백을 포함한 구(예: "할 일로")는 긴 것부터 문자열 치환.
  ///  2) 나머지는 토큰 단위로, stripword 를 **포함하는** 토큰을 통째 제거.
  String _strip(String base, IntentType intent) {
    if (base.isEmpty) return base.trim();
    // 담기·기입 동사(적어줘/추가해줘/넣어놔 …)는 어느 인텐트에서든 제목이 아니다.
    final words = <String>[
      ...?IntentLexicon.stripWords[intent],
      ...IntentLexicon.addVerbs,
    ];
    if (words.isEmpty) return base.trim();

    final phrases = words.where((w) => w.contains(' ')).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final singles = words.where((w) => !w.contains(' ')).toList();

    var s = base;
    for (final p in phrases) {
      s = s.replaceAll(p, ' ');
    }
    final kept = s
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !singles.any(t.contains));
    return kept.join(' ').trim();
  }

  /// 루틴: "아침 루틴에 스트레칭 추가" → 그룹=아침, 스텝/제목=스트레칭.
  VoiceSlots _extractRoutine(String base) {
    final tokens =
        base.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final routineIdx = tokens.indexWhere((t) => t.contains('루틴'));
    String? group;
    final drop = <int>{};
    if (routineIdx >= 0) {
      drop.add(routineIdx);
      if (routineIdx > 0) {
        group = tokens[routineIdx - 1];
        drop.add(routineIdx - 1);
      }
    }
    // 보조 구조어 토큰 제거(스텝/추가).
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].contains('스텝') || tokens[i].contains('추가')) drop.add(i);
    }
    final rest = <String>[
      for (var i = 0; i < tokens.length; i++)
        if (!drop.contains(i)) tokens[i],
    ].join(' ').trim();
    final step = rest.isEmpty ? null : rest;
    return VoiceSlots(
      title: step,
      stepName: step,
      groupName: group,
    );
  }

  bool _hasAny(String text, List<String> words) => words.any(text.contains);

  String? _nullIfEmpty(String s) => s.isEmpty ? null : s;
}
