import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ics_file_saver.dart';

Future<SavedIcsFile> saveIcsFileImpl(
  String fileName,
  String content, {
  required IcsSaveLocation location,
}) async {
  final directory = switch (location) {
    IcsSaveLocation.temporary => await getTemporaryDirectory(),
    IcsSaveLocation.downloads => await getDownloadsDirectory(),
  };
  if (directory == null) {
    throw FileSystemException('$location directory is unavailable');
  }

  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(content);
  return SavedIcsFileResult(
    fileName: fileName,
    filePath: file.path,
    launchUri: Uri.file(file.path),
  );
}
