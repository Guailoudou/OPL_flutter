import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'platform_support.dart';

// Windows releases this handle when the process exits. Keep ownership until then.
int _handle = 0;

bool acquireSingleInstance() {
  if (!PlatformSupport.isWindows || _handle != 0) return true;
  final kernel = DynamicLibrary.open('kernel32.dll');
  final create = kernel.lookupFunction<
      IntPtr Function(Pointer<Void>, Int32, Pointer<Utf16>),
      int Function(Pointer<Void>, int, Pointer<Utf16>)>('CreateMutexW');
  final wait = kernel.lookupFunction<Uint32 Function(IntPtr, Uint32),
      int Function(int, int)>('WaitForSingleObject');
  final close = kernel
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
  final name = 'Local\\OPLConfigManager_SingleInstance'.toNativeUtf16();
  try {
    final handle = create(nullptr, 0, name);
    if (handle == 0) throw StateError('Unable to create single-instance mutex');
    final result = wait(handle, 0);
    if (result == 0 || result == 0x80) {
      // WAIT_ABANDONED also grants ownership after an earlier instance crashed.
      _handle = handle;
      return true;
    }
    close(handle);
    if (result != 0x102) {
      throw StateError('Unable to acquire single-instance mutex');
    }
    _restoreWindow();
    return false;
  } finally {
    calloc.free(name);
  }
}

void _restoreWindow() {
  final user = DynamicLibrary.open('user32.dll');
  final find = user.lookupFunction<
      IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
      int Function(Pointer<Utf16>, Pointer<Utf16>)>('FindWindowW');
  final show = user.lookupFunction<Int32 Function(IntPtr, Int32),
      int Function(int, int)>('ShowWindow');
  final focus = user.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'SetForegroundWindow');
  final title = 'OPL联机工具'.toNativeUtf16();
  try {
    final window = find(nullptr, title);
    if (window != 0) {
      show(window, 9);
      focus(window);
    }
  } finally {
    calloc.free(title);
  }
}
