import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/core/formatting/color_hex.dart';
import 'package:openx11se/core/theme/nocturne_palette.dart';
import 'package:openx11se/core/theme/nocturne_theme.dart';
import 'package:openx11se/ui/shell/appearance_view_model.dart';
import 'package:openx11se/ui/widgets/segmented_control.dart';
import 'package:openx11se/ui/widgets/toggle.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildNocturneTheme(nocturneDark),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('hex colour round-trips', () {
    expect(parseHexColor('#8b6cff'), const Color(0xFF8B6CFF));
    expect(parseHexColor('abc'), const Color(0xFFAABBCC));
    expect(parseHexColor('#12345'), isNull);
    expect(formatHexColor(const Color(0xFF8B6CFF)), '#8B6CFF');
  });

  test('accent override derives ramp steps', () {
    final vm = AppearanceViewModel()..accentOverride = stageColorDefaults[0];
    final n = vm.darkTheme.extension<NocturneTheme>()!;
    expect(n.accent, stageColorDefaults[0]);
    expect(n.palette.a(800), isNot(nocturneDark.a(800)));
    vm.accentOverride = null;
    expect(
      vm.darkTheme.extension<NocturneTheme>()!.accent,
      nocturneDark.accent,
    );
  });

  testWidgets('switch toggles', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => AppSwitch(
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('segmented control selects option', (tester) async {
    var selected = 1000;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => SegmentedControl<int>(
            selected: selected,
            onChanged: (v) => setState(() => selected = v),
            options: const [
              SegmentOption(value: 500, label: '500 Hz'),
              SegmentOption(value: 1000, label: '1000 Hz'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('500 Hz'));
    await tester.pumpAndSettle();
    expect(selected, 500);
  });
}
