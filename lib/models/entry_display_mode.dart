enum EntryDisplayMode { symbol, text, hybrid }

extension EntryDisplayModeX on EntryDisplayMode {
  String get storageValue => name;

  String get settingsLabel {
    switch (this) {
      case EntryDisplayMode.symbol:
        return '기호';
      case EntryDisplayMode.text:
        return '텍스트';
      case EntryDisplayMode.hybrid:
        return '혼합';
    }
  }

  static EntryDisplayMode parse(String? value) {
    switch (value) {
      case 'symbol':
        return EntryDisplayMode.symbol;
      case 'text':
        return EntryDisplayMode.text;
      case 'hybrid':
      default:
        return EntryDisplayMode.hybrid;
    }
  }
}
