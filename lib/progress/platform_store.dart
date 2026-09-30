// The device's save store: a file on Android and iOS, the browser's local
// storage on the web. The web half is compiled only for the web.
export 'platform_store_io.dart' if (dart.library.js_interop) 'platform_store_web.dart';
