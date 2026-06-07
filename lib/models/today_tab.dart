enum TodaySection { stats, habits, upcoming, memos, todo, timelog }

extension TodaySectionX on TodaySection {
  String get label {
    switch (this) {
      case TodaySection.stats:
        return '통계 요약';
      case TodaySection.habits:
        return '습관';
      case TodaySection.upcoming:
        return '이벤트/일정';
      case TodaySection.memos:
        return '메모';
      case TodaySection.todo:
        return '할일';
      case TodaySection.timelog:
        return '시간일기';
    }
  }

  String get headerKey {
    switch (this) {
      case TodaySection.stats:
        return 'STATS';
      case TodaySection.habits:
        return 'HABITS';
      case TodaySection.upcoming:
        return 'UPCOMING';
      case TodaySection.memos:
        return 'MEMOS';
      case TodaySection.todo:
        return 'TODO';
      case TodaySection.timelog:
        return 'TIMELOG';
    }
  }
}

// 체크된 sections에 없는 나머지를 enum 순서로 뒤에 붙여 전체 목록 생성
List<TodaySection> _defaultSectionOrder(List<TodaySection> checked) {
  final rest = TodaySection.values.where((s) => !checked.contains(s));
  return [...checked, ...rest];
}

TodaySection? _parseSection(String s) {
  try {
    return TodaySection.values.firstWhere((e) => e.name == s);
  } catch (_) {
    return null;
  }
}

class TodayTab {
  final String id;
  final String name;

  /// 체크된(표시할) 섹션 목록, 표시 순서 기준
  final List<TodaySection> sections;

  /// 전체 6개 섹션의 사용자 지정 순서 (체크 여부 무관)
  final List<TodaySection> sectionOrder;

  TodayTab({
    required this.id,
    required this.name,
    required this.sections,
    List<TodaySection>? sectionOrder,
  }) : sectionOrder = sectionOrder ?? _defaultSectionOrder(sections);

  TodayTab copyWith({
    String? name,
    List<TodaySection>? sections,
    List<TodaySection>? sectionOrder,
  }) => TodayTab(
    id: id,
    name: name ?? this.name,
    sections: sections ?? List.from(this.sections),
    sectionOrder: sectionOrder ?? List.from(this.sectionOrder),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sections': sections.map((s) => s.name).toList(),
    'sectionOrder': sectionOrder.map((s) => s.name).toList(),
  };

  factory TodayTab.fromJson(Map<String, dynamic> json) {
    final rawSections =
        (json['sections'] as List<dynamic>?)?.cast<String>() ?? [];
    final sections = rawSections
        .map(_parseSection)
        .whereType<TodaySection>()
        .toList();

    // sectionOrder: 구버전 JSON에 없으면 기본값 사용
    List<TodaySection>? sectionOrder;
    final rawOrder = (json['sectionOrder'] as List<dynamic>?)?.cast<String>();
    if (rawOrder != null) {
      final parsed = rawOrder
          .map(_parseSection)
          .whereType<TodaySection>()
          .toList();
      // 모든 섹션이 포함된 경우에만 사용 (파싱 손실 방지)
      if (parsed.toSet().length == TodaySection.values.length) {
        sectionOrder = parsed;
      }
    }

    return TodayTab(
      id: json['id'] as String,
      name: json['name'] as String,
      sections: sections,
      sectionOrder: sectionOrder,
    );
  }
}

List<TodayTab> defaultTodayTabs() => [
  TodayTab(
    id: 't0',
    name: '요약',
    sections: [
      TodaySection.stats,
      TodaySection.habits,
      TodaySection.upcoming,
      TodaySection.memos,
    ],
  ),
  TodayTab(id: 't1', name: '시간일기', sections: [TodaySection.timelog]),
  TodayTab(id: 't2', name: '할일', sections: [TodaySection.todo]),
];
