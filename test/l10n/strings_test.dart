import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/core/l10n/strings.dart';

void main() {
  tearDown(() => AppStrings.language = AppLanguage.english);

  test('english leaves text unchanged', () {
    expect(tr('Performance'), 'Performance');
  });

  test('arabic translates exact, patterned and composite text', () {
    AppStrings.language = AppLanguage.arabic;
    expect(tr('Performance'), 'الأداء');
    expect(tr('Stage 3'), 'المرحلة 3');
    expect(tr('6 of 8 enabled'), '6 من 8 مفعّلة');
    expect(tr('2.4 GHz · Asleep'), '2.4 GHz · في السكون');
    expect(
      tr(' Your edits are kept — apply them when the mouse is back.'),
      ' تعديلاتك محفوظة — طبّقها عند عودة الفأرة.',
    );
    expect(tr('Delete “Work”?'), 'حذف «Work»؟');
    expect(tr('X11SE'), 'X11SE');
    expect(tr('2,400'), '2,400');
  });

  test('language codes fall back to english', () {
    expect(AppLanguage.fromCode('ar'), AppLanguage.arabic);
    expect(AppLanguage.fromCode('xx'), AppLanguage.english);
    expect(AppLanguage.arabic.isRtl, isTrue);
  });
}
