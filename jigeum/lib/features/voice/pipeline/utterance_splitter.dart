/// 긴 중얼거림을 실행 가능한 짧은 조각으로 나눈다.
///
/// 라우터는 "한 조각 → 한 착지점"에 집중하고, 이 레이어가 "이것도 하고
/// 저것도 해야 되고, 이건 빼고" 같은 실제 말투를 여러 조각으로 풀어준다.
library;

class VoiceFragment {
  const VoiceFragment({
    required this.text,
    this.skipped = false,
  });

  final String text;
  final bool skipped;
}

class UtteranceSplitter {
  const UtteranceSplitter();

  static final RegExp _punctuation = RegExp(r'[,.;!?，。！？;\n]+');
  static final RegExp _connector = RegExp(
    r'\s+(?:그리고|또|그다음|그 다음|다음으로|아참|아 그리고)\s+',
  );
  static final RegExp _trailingBoilerplate = RegExp(
    r'\s*(?:도)?\s*(?:해야\s*되(?:고|는데)?|해야되(?:고|는데)?|'
    r'해야\s*할\s*거\s*같(?:고|은데|아)?|해야할거같(?:고|은데|아)?|'
    r'해야\s*될\s*거\s*같(?:고|은데|아)?|해야될거같(?:고|은데|아)?|'
    r'해야\s*하(?:고|는데)?|할\s*거\s*같(?:고|은데|아)?|할거같(?:고|은데|아)?|'
    r'넣고|추가하고|적어주고|잡아주고)$',
  );
  static final RegExp _boilerplateDivider = RegExp(
    r'\s*(?:도)?\s*(?:해야\s*되고|해야되고|해야\s*되는데|해야되는데|'
    r'해야\s*할\s*거\s*같고|해야할거같고|'
    r'해야\s*될\s*거\s*같고|해야될거같고|해야\s*하고)\s+',
  );
  static final RegExp _positiveDivider = RegExp(
    r'(?:\s+하고\s+|하고\s+|넣고\s+|추가하고\s+|적어주고\s+|잡아주고\s+)',
  );
  static final RegExp _exclusion = RegExp(
    r'\s*(?:빼고|말고|제외하고|하지\s*말고|안\s*하고)\s*',
  );
  static final RegExp _leadingNoise = RegExp(
    r'^(?:그리고|또|그다음|그 다음|다음으로|아참|아|어|음)\s+',
  );
  static final RegExp _onlyDemonstrative = RegExp(
    r'^(?:이거|이것|저거|저것|그거|그것|이건|저건|그건|이것도|저것도|그것도)$',
  );

  List<VoiceFragment> split(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const [];

    final out = <VoiceFragment>[];
    var cursor = 0;
    var hadExclusion = false;
    for (final m in _exclusion.allMatches(text)) {
      hadExclusion = true;
      _add(out, text.substring(cursor, m.start), skipped: true);
      cursor = m.end;
    }
    _splitPositive(text.substring(cursor), out);

    if (out.isEmpty) {
      if (hadExclusion) return const [];
      final cleaned = _clean(text);
      return cleaned.isEmpty ? const [] : [VoiceFragment(text: cleaned)];
    }
    return _dedupe(out);
  }

  void _splitPositive(String text, List<VoiceFragment> out) {
    var normalized = text
        .replaceAll('너고', '넣고')
        .replaceAll(_punctuation, '|')
        .replaceAll(_connector, '|')
        .replaceAll(_boilerplateDivider, '|')
        .replaceAll(_positiveDivider, '|');
    normalized = normalized.replaceAll(_trailingBoilerplate, '|');
    for (final part in normalized.split('|')) {
      _add(out, part);
    }
  }

  void _add(List<VoiceFragment> out, String text, {bool skipped = false}) {
    final cleaned = _clean(text);
    if (cleaned.isEmpty) return;
    out.add(VoiceFragment(text: cleaned, skipped: skipped));
  }

  String _clean(String text) {
    var s = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    while (_leadingNoise.hasMatch(s)) {
      s = s.replaceFirst(_leadingNoise, '').trim();
    }
    final stripped = s.replaceAll(_trailingBoilerplate, '').trim();
    if (stripped.isNotEmpty && !_onlyDemonstrative.hasMatch(stripped)) {
      s = stripped;
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    if (s.length < 2 || _onlyDemonstrative.hasMatch(s)) return '';
    return s;
  }

  List<VoiceFragment> _dedupe(List<VoiceFragment> fragments) {
    final seen = <String>{};
    final unique = <VoiceFragment>[];
    for (final f in fragments) {
      final key = '${f.skipped}:${f.text}';
      if (seen.add(key)) unique.add(f);
    }
    return unique;
  }
}
