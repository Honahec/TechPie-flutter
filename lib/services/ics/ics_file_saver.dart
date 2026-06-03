import "ics_file_saver_native_impl.dart"
    if (dart.library.html) "ics_file_saver_web_impl.dart" as impl;

abstract class SavedIcsFile {
  String get fileName;
  String? get filePath;
  Uri? get launchUri;
}

enum IcsSaveLocation { temporary, downloads }

class SavedIcsFileResult implements SavedIcsFile {
  const SavedIcsFileResult({
    required this.fileName,
    this.filePath,
    this.launchUri,
  });

  @override
  final String fileName;

  @override
  final String? filePath;

  @override
  final Uri? launchUri;
}

Future<SavedIcsFile> saveIcsFile(
  String fileName,
  String content, {
  required IcsSaveLocation location,
}) {
  return impl.saveIcsFileImpl(fileName, content, location: location);
}
