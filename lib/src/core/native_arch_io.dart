import 'dart:ffi';

String? get nativeArchitecture {
  final abi = Abi.current().toString();
  if (abi.endsWith('_arm64')) return 'arm64';
  if (abi.endsWith('_x64')) return 'x64';
  return null;
}
