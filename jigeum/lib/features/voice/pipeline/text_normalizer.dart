/// 정규화기. 기획서 §1 ② 단계 + §5 커밋3.
///
/// STT raw text 를 뒷단(파서·분류기)이 다루기 쉬운 형태로 다듬는다. **의미를
/// 지우지 않는 보수적 정리만** 한다:
///  1. 공백 정리 — 모든 공백 런을 단일 공백으로, 앞뒤 trim.
///  2. 문장부호 제거 — 한글/숫자/영문/공백만 남기고 나머지는 공백으로.
///  3. 군말(간투사) 제거 — "어", "음" 같은 **토큰 전체 일치**만. 부분일치는 안 함
///     (예: "그거"·"뭐였지" 는 보존).
///  4. 전각 숫자 → 반각.
///
/// 한글 수사(세시·한시간 등) → 아라비아 숫자 변환은 **파서(§4-5)** 담당이라
/// 여기서 하지 않는다. 원문 보존이 필요한 곳(보류함)은 정규화 전 raw 를 쓴다.
library;

class TextNormalizer {
  const TextNormalizer();

  /// 토큰 전체가 이와 정확히 일치하면 군말로 보고 제거한다.
  static const Set<String> _fillers = {
    '어',
    '음',
    '아',
    '엄',
    '으',
    '응',
    '그',
    '저',
    '뭐',
    '막',
    '이제',
    '그냥',
  };

  /// STT 흔한 오타 → 표준형(§ 오타 케이스). 순서대로 치환하므로 더 구체적인
  /// 패턴을 앞에 둔다. 실단어 오검출 위험이 낮은 것만 보수적으로 담는다.
  static const List<List<String>> _typoFixes = [
    ['빠른대미', '빠른담기'],
    ['걸어노아', '걸어놔'],
    ['보류하메', '보류함에'],
    ['주문너음', '주문넣음'],
    ['출바람', '출발함'],
    ['습과으로', '습관으로'],
    ['자바주', '잡아주'],
    ['자바줘', '잡아줘'],
    ['저거놔', '적어놔'],
    ['저거줘', '적어줘'],
    ['저거놓', '적어놓'],
    ['지워조', '지워줘'],
    ['시자칸', '시작한'],
    ['다라줘', '달아줘'],
    ['내이 ', '내일 '],
    ['추카', '추가'],
    ['너어', '넣어'],
    ['너코', '넣고'],
    ['너고', '넣고'],
    ['너음', '넣음'],
    ['해조', '해줘'],
    ['그팜', '급함'],
    ['그파', '급하'],
    ['임바', '임박'],
    ['핻어', '했어'],
    ['왇어', '왔어'],
    ['끈냈어', '끝냈어'],
    ['돗수', '도수'],
  ];

  /// 한글/숫자/영문/공백이 아니면 공백으로 치환하는 패턴.
  static final RegExp _nonContent = RegExp(r'[^0-9A-Za-z가-힣ㄱ-ㆎ\s]');
  static final RegExp _spaces = RegExp(r'\s+');

  String normalize(String raw) {
    if (raw.isEmpty) return '';
    // 0) STT 오타 교정(표준형으로) — 파싱/분류 전에 먼저.
    var fixed = raw;
    for (final pair in _typoFixes) {
      fixed = fixed.replaceAll(pair[0], pair[1]);
    }
    // 1) 전각 숫자 → 반각.
    final halfWidth = _toHalfWidthDigits(fixed);
    // 2) 문장부호 → 공백.
    final cleaned = halfWidth.replaceAll(_nonContent, ' ');
    // 3) 공백 분해 + 군말 제거.
    final tokens = cleaned
        .split(_spaces)
        .where((t) => t.isNotEmpty && !_fillers.contains(t));
    // 4) 재조립.
    return tokens.join(' ').trim();
  }

  String _toHalfWidthDigits(String s) {
    final buf = StringBuffer();
    for (final rune in s.runes) {
      // 전각 '０'(0xFF10) ~ '９'(0xFF19) → 반각 '0'~'9'.
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        buf.writeCharCode(rune - 0xFF10 + 0x30);
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }
}
