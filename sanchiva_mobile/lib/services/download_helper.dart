import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart' as impl;

/// Download bytes in browser; no-op on other platforms (use share there).
void downloadBytes(List<int> bytes, String filename, String mime) {
  impl.downloadBytes(bytes, filename, mime);
}
