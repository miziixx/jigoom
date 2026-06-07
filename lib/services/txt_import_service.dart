// TXT 파일을 메모 블록 단위로 파싱합니다.
// 분리 기준: 빈 줄 1개 이상(\n\n), 또는 ---로만 이뤄진 줄.
List<String> parseTxtBlocks(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  // \n{2,}: 빈 줄 1개 이상 / ^-{3,}\s*$: --- 구분선 (multiLine: ^$가 각 줄에 매칭)
  final blocks = normalized.split(RegExp(r'\n{2,}|^-{3,}\s*$', multiLine: true));
  return blocks.map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
}
