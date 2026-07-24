/// 한국어 금액 파서. 사용자 말투 ⑥("금액은 만원 단위") + spec §13-2.
///
/// `원`으로 끝나는 금액 표현을 원(정수)으로 환산한다. 숫자·한자어 수사와 단위
/// (만·천·백)를 섞어 쓰는 실사용 말투를 처리한다:
///   9만원=90000 · 10만원=100000 · 15만 오천원=155000 · 만이천원=12000 · 오천원=5000
///
/// 범위 밖(로드맵): `원` 없이 문맥으로만 만원단위인 bare 수(월세 60, 적금 200) —
/// 문맥 판별이 필요해 미지원. 억 단위도 초기 범위 밖.
///
/// 프레임워크 비의존(순수 Dart).
library;

/// 금액 파싱 결과: [amount]원 과 원문에서 잘라낼 [matchText].
class MoneyParseResult {
  const MoneyParseResult(this.amount, this.matchText);
  final int? amount;
  final String? matchText;

  static const MoneyParseResult none = MoneyParseResult(null, null);
}

class KoMoneyParser {
  const KoMoneyParser();

  /// 한자어 수사(1~9). '일'(1)은 날짜의 '일'과 충돌해 **제외**한다(오검출 방지).
  static const Map<String, int> _sino = {
    '이': 2, '삼': 3, '사': 4, '오': 5, '육': 6, '칠': 7, '팔': 8, '구': 9,
  };

  /// 금액 문자 집합(숫자 + 이~구 + 십백천만억). '일' 제외.
  static const String _cls = r'0-9이삼사오육칠팔구십백천만억';
  static final RegExp _re = RegExp('([$_cls][$_cls\\s]*)\\s*원');

  MoneyParseResult parse(String text) {
    for (final m in _re.allMatches(text)) {
      final amount = _eval(m.group(1)!);
      if (amount != null && amount > 0) {
        return MoneyParseResult(amount, m.group(0));
      }
    }
    return MoneyParseResult.none;
  }

  /// "15만오천" 류를 정수로. 만 경계로 블록을 끊어 누적한다.
  int? _eval(String raw) {
    final s = raw.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return null;

    var total = 0; // 만 이상 확정분 누적
    var block = 0; // 현재 만-블록 내 (천/백/십 확정분)
    var cur = 0; // 현재 자릿수 누적(숫자/수사)
    var sawAny = false;

    for (final ch in s.split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        cur = cur * 10 + digit;
        sawAny = true;
        continue;
      }
      final sino = _sino[ch];
      if (sino != null) {
        cur = cur * 10 + sino;
        sawAny = true;
        continue;
      }
      switch (ch) {
        case '십':
          block += (cur == 0 ? 1 : cur) * 10;
          cur = 0;
          sawAny = true;
        case '백':
          block += (cur == 0 ? 1 : cur) * 100;
          cur = 0;
          sawAny = true;
        case '천':
          block += (cur == 0 ? 1 : cur) * 1000;
          cur = 0;
          sawAny = true;
        case '만':
          final man = (block + cur) == 0 ? 1 : (block + cur);
          total += man * 10000;
          block = 0;
          cur = 0;
          sawAny = true;
        case '억':
          final eok = (total + block + cur) == 0 ? 1 : (total + block + cur);
          total = eok * 100000000;
          block = 0;
          cur = 0;
          sawAny = true;
        default:
          // 알 수 없는 문자 → 무시(정규식이 막지만 방어).
          break;
      }
    }
    if (!sawAny) return null;
    return total + block + cur;
  }
}
