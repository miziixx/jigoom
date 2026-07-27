import 'package:flutter/services.dart';

const _channel = MethodChannel('app/flavor');
String _flavorName = 'personal';
final DateTime appStartTime = DateTime.now();

Future<void> initFlavor() async {
  try {
    _flavorName =
        await _channel.invokeMethod<String>('getFlavor') ?? 'personal';
  } catch (_) {
    _flavorName = 'personal';
  }
}

String get flavorName => _flavorName;
bool get isStoreFlavor => _flavorName == 'store' || _flavorName == 'nemo2store';
bool get isNemo2 => _flavorName == 'nemo2' || _flavorName == 'nemo2store';
bool get isLogroom => _flavorName == 'logroom';
bool get isLogroomTemp => _flavorName == 'logroomtemp';
bool get isLogroomUi => isLogroom || isLogroomTemp;
