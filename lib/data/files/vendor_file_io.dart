import 'dart:io';
import 'dart:typed_data';

const _vendorProfilePath = r'\Attack Shark Software\data\ms_10\pro.data';

final bool vendorImportSupported = Platform.isWindows;

Future<Uint8List?> readInstalledVendorProfile() async {
  if (!Platform.isWindows) return null;
  final base =
      Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
  final file = File('$base$_vendorProfilePath');
  try {
    return await file.exists() ? await file.readAsBytes() : null;
  } on FileSystemException {
    return null;
  }
}
