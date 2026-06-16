// Platform-conditional drift executor.
//
// Mobile/desktop use native sqlite via FFI (`native.dart`); web uses the
// sqlite3 WASM build (`web.dart`). The right one is selected at compile time so
// the web bundle never references `dart:ffi`.
export 'unsupported.dart'
    if (dart.library.io) 'native.dart'
    if (dart.library.js_interop) 'web.dart';
