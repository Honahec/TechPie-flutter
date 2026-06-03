import "dart:convert";

import "package:web/web.dart" as web;

import "ics_file_saver.dart";

Future<SavedIcsFile> saveIcsFileImpl(
  String fileName,
  String content, {
  required IcsSaveLocation location,
}) async {
  final href = Uri.dataFromString(
    content,
    mimeType: "text/calendar",
    encoding: utf8,
  ).toString();
  final anchor = web.HTMLAnchorElement()
    ..href = href
    ..download = fileName
    ..style.display = "none";
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return SavedIcsFileResult(fileName: fileName);
}
