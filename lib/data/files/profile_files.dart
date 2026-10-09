import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../json/profile_file_json.dart';
import 'vendor_file.dart' as vendor;

class ProfileFiles {
  const ProfileFiles();

  bool get supportsVendorImport => vendor.vendorImportSupported;

  Future<Uint8List?> pickProfile() =>
      _pick('Import profile', const [profileFileExtension, 'json']);

  Future<bool> saveProfile(String fileName, Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export profile',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const [profileFileExtension],
    );
    return saved != null;
  }

  Future<Uint8List?> readVendorProfile() async =>
      await vendor.readInstalledVendorProfile() ??
      await _pick('Select the vendor pro.data file', const ['data']);

  Future<Uint8List?> _pick(String title, List<String> extensions) async {
    final file = await FilePicker.pickFile(
      dialogTitle: title,
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    return file?.readAsBytes();
  }
}
