import 'package:flutter/services.dart';

const _channel = MethodChannel('app/flavor');
String _flavorName = 'personal';

Future<void> initFlavor() async {
  try {
    _flavorName =
        await _channel.invokeMethod<String>('getFlavor') ?? 'personal';
  } catch (_) {
    _flavorName = 'personal';
  }
}

bool get isStoreFlavor => _flavorName == 'store' || _flavorName == 'nemo2store';
bool get isNemo2 => _flavorName == 'nemo2' || _flavorName == 'nemo2store';
bool get isNemo2Test => _flavorName == 'nemo2test';
bool get isLogroom => _flavorName == 'logroom';
bool get isLogroomTemp => _flavorName == 'logroomtemp';
bool get isLogroomUi => isLogroom || isLogroomTemp || isNemo2Test;
