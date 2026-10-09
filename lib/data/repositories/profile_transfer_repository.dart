import 'dart:convert';
import 'dart:typed_data';

import '../../domain/button_assignment.dart';
import '../../domain/device_settings.dart';
import '../../domain/macro.dart';
import '../../domain/profile.dart';
import '../json/profile_file_json.dart';
import '../vendor/vendor_profile.dart';
import 'macro_repository.dart';
import 'profile_repository.dart';

class VendorImport {
  const VendorImport(this.profile, this.unmappedSlots);

  final Profile profile;
  final List<int> unmappedSlots;
}

class ProfileTransferRepository {
  ProfileTransferRepository(this._profiles, this._macros);

  final ProfileRepository _profiles;
  final MacroRepository _macros;

  Future<Uint8List> export(String name, DeviceSettings settings) async {
    final macros = <int, Macro>{};
    for (final b in settings.buttons) {
      if (b case MacroButton(:final macroId?)) {
        final macro = await _macros.macro(macroId);
        if (macro != null) macros[macroId] = macro;
      }
    }
    final json = encodeProfileFile(
      ProfileFile(name: name, settings: settings, macros: macros),
    );
    return Uint8List.fromList(utf8.encode(json));
  }

  Future<Profile> importFile(Uint8List bytes) async {
    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('Not a profile file');
    }
    final file = decodeProfileFile(source);
    final ids = <int, int>{};
    for (final MapEntry(:key, :value) in file.macros.entries) {
      ids[key] = (await _macros.create(value)).id!;
    }
    final buttons = [
      for (final b in file.settings.buttons)
        b is MacroButton
            ? MacroButton(macroId: ids[b.macroId], playback: b.playback)
            : b,
    ];
    return _profiles.create(
      file.name,
      settings: file.settings.copyWith(buttons: buttons),
    );
  }

  Future<VendorImport> importVendor(Uint8List bytes) async {
    final vendor = decodeVendorProfile(bytes);
    final buttons = [...vendor.settings.buttons];
    for (final MapEntry(key: slot, :value) in vendor.macros.entries) {
      final macro = await _macros.create(value.macro);
      buttons[slot] = MacroButton(macroId: macro.id, playback: value.playback);
    }
    final name = vendor.name.isEmpty ? 'Profile' : vendor.name;
    final profile = await _profiles.create(
      'Vendor · $name',
      settings: vendor.settings.copyWith(buttons: buttons),
    );
    return VendorImport(profile, vendor.unmappedSlots);
  }
}
