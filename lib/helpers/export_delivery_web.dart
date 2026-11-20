import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:web/web.dart' as web;

import 'export_file.dart';

/// Web delivery: build the bytes in memory and trigger a browser download through a Blob link.
/// No dart:io. [shareOrigin] is unused on the web.
Future<void> deliverExportFiles(List<ExportFile> files, {Rect? shareOrigin}) async {
  for (final ExportFile f in files) {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(f.text));
    final web.Blob blob =
        web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: f.mimeType));
    final String url = web.URL.createObjectURL(blob);
    final web.HTMLAnchorElement a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = url;
    a.download = f.name;
    a.style.display = 'none';
    web.document.body!.append(a);
    a.click();
    a.remove();
    web.URL.revokeObjectURL(url);
  }
}
