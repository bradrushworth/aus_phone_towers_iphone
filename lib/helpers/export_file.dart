/// One finished export, held in memory. Pure data so the web path never needs dart:io.
class ExportFile {
  const ExportFile({required this.name, required this.text, required this.mimeType});

  final String name;
  final String text;
  final String mimeType;
}

/// Subfolder of the documents directory that exports are written into (mobile). iOS shows it
/// under Files > On My iPhone > Aus Phone Towers (UIFileSharingEnabled in Info.plist).
const String kExportsFolder = 'Exports';

/// Exports older than this are deleted before each new export is written.
const Duration kExportsRetention = Duration(days: 30);

/// True when a file last modified at [modified] is past [kExportsRetention] at [now].
bool isExportExpired(DateTime modified, DateTime now) =>
    now.difference(modified) > kExportsRetention;
