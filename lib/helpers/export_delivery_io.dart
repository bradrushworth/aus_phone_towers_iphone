import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'export_file.dart';

/// Mobile/desktop delivery: write into the Exports folder (deleting files older than 30 days
/// first), then open the system share sheet with the files. [shareOrigin] anchors the iPad
/// popover.
Future<void> deliverExportFiles(List<ExportFile> files, {Rect? shareOrigin}) async {
  final Directory docs = await getApplicationDocumentsDirectory();
  final Directory dir = Directory(p.join(docs.path, kExportsFolder));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final DateTime now = DateTime.now();
  await for (final FileSystemEntity entity in dir.list()) {
    if (entity is! File) continue;
    try {
      if (isExportExpired(await entity.lastModified(), now)) {
        await entity.delete();
      }
    } on FileSystemException {
      // Locked or already gone: leave it for a later export.
    }
  }
  final List<XFile> shared = <XFile>[];
  for (final ExportFile f in files) {
    final File out = File(p.join(dir.path, f.name));
    await out.writeAsBytes(utf8.encode(f.text), flush: true);
    shared.add(XFile(out.path, mimeType: f.mimeType, name: f.name));
  }
  await SharePlus.instance.share(ShareParams(files: shared, sharePositionOrigin: shareOrigin));
}
