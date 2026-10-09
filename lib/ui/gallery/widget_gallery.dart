import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_palette.dart';
import '../../core/theme/nocturne_theme.dart';
import '../shell/appearance_view_model.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_slider.dart';
import '../widgets/choice.dart';
import '../widgets/colour_picker.dart';
import '../widgets/motion.dart';
import '../widgets/section_header.dart';
import '../widgets/segmented_control.dart';
import '../widgets/status_banner.dart';
import '../widgets/surface_card.dart';
import '../widgets/tag.dart';
import '../widgets/text_input.dart';
import '../widgets/toast_host.dart';
import '../widgets/toggle.dart';

class WidgetGallery extends StatefulWidget {
  const WidgetGallery({super.key});

  @override
  State<WidgetGallery> createState() => _WidgetGalleryState();
}

class _WidgetGalleryState extends State<WidgetGallery> {
  final _toasts = ToastController();
  int _polling = 1000;
  bool _angleSnap = false;
  bool _ripple = true;
  double _sleep = 1;
  double _debounce = 8;
  double _dpiIndex = 30;
  String _playback = 'times';
  int _brightness = 6;
  Color _colour = const Color(0xFF8B6CFF);
  final Set<String> _mods = {'Ctrl'};

  @override
  void dispose() {
    _toasts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final appearance = context.watch<AppearanceViewModel>();

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: n.groundGlow),
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1060),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 18,
                    children: [
                      EntranceTransition(
                        child: SectionHeader(
                          title: 'Widget gallery',
                          description:
                              'Shared components rendered with the Nocturne tokens.',
                          trailing: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SegmentedControl<ThemeMode>(
                                dense: true,
                                selected: appearance.themeMode,
                                onChanged: (m) => appearance.themeMode = m,
                                options: const [
                                  SegmentOption(
                                    value: ThemeMode.dark,
                                    label: 'Dark',
                                    icon: AppIcons.moon,
                                  ),
                                  SegmentOption(
                                    value: ThemeMode.light,
                                    label: 'Light',
                                    icon: AppIcons.sun,
                                  ),
                                  SegmentOption(
                                    value: ThemeMode.system,
                                    label: 'System',
                                    icon: AppIcons.desktop,
                                  ),
                                ],
                              ),
                              SegmentedControl<bool>(
                                dense: true,
                                selected: appearance.accentOverride != null,
                                onChanged: (stage) =>
                                    appearance.accentOverride = stage
                                    ? stageColorDefaults[2]
                                    : null,
                                options: const [
                                  SegmentOption(
                                    value: false,
                                    label: 'OpenX11SE violet',
                                  ),
                                  SegmentOption(
                                    value: true,
                                    label: 'Active DPI stage',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buttons(n),
                      _banners(),
                      _cards(n),
                      _sliders(),
                      _forms(n),
                      _states(n),
                    ],
                  ),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: _toasts,
              builder: (context, _) => Stack(
                children: [
                  ToastHost(toasts: _toasts.toasts, onDismiss: _toasts.dismiss),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(String title, List<Widget> children) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        CardHeading(title: title),
        ...children,
      ],
    ),
  );

  Widget _buttons(NocturneTheme n) => _group('Buttons and tags', [
    Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton.primary(
          label: 'Apply',
          icon: AppIcons.uploadSimple,
          minWidth: 108,
          onPressed: () =>
              _toasts.show('Settings saved to mouse', kind: ToastKind.success),
          trailing: const _CountBadge(count: 3),
        ),
        AppButton(
          label: 'Discard',
          icon: AppIcons.arrowCounterClockwise,
          onPressed: () => _toasts.show('Staged changes discarded'),
        ),
        AppButton.ghost(label: 'Check again', onPressed: () {}),
        const AppButton(label: 'Disabled', onPressed: null),
        AppButton(
          label: 'Restore mouse to factory defaults',
          icon: AppIcons.warning,
          variant: AppButtonVariant.danger,
          onPressed: _confirm,
        ),
        AppButton(
          label: 'Reconnect',
          icon: AppIcons.arrowsClockwise,
          size: AppButtonSize.small,
          onPressed: () {},
        ),
      ],
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppIconButton(
          icon: AppIcons.minus,
          tooltip: 'Previous valid value',
          onPressed: () {},
        ),
        AppIconButton(
          icon: AppIcons.plus,
          tooltip: 'New macro',
          variant: AppButtonVariant.primary,
          onPressed: () {},
        ),
        AppIconButton(
          icon: AppIcons.arrowCounterClockwise,
          tooltip: 'Reset',
          variant: AppButtonVariant.ghost,
          size: 30,
          onPressed: () {},
        ),
        const SizedBox(width: 12),
        const Tag(label: 'Active'),
        const Tag(label: 'Disabled', variant: TagVariant.neutral),
        const Tag(label: 'Outline', variant: TagVariant.outline),
        const Tag(
          label: 'Auto-apply',
          variant: TagVariant.neutral,
          icon: AppIcons.lightning,
        ),
        const Tag(label: 'In use', compact: true),
        const ChangedDot(glow: true),
      ],
    ),
  ]);

  Widget _banners() => Column(
    spacing: 10,
    children: [
      StatusBanner(
        kind: BannerKind.warning,
        icon: AppIcons.plugs,
        message: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'X11SE disconnected. ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text:
                    'Your edits are kept — apply them when the mouse is back.',
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: 'Reconnect',
            icon: AppIcons.arrowsClockwise,
            size: AppButtonSize.small,
            onPressed: () {},
          ),
        ],
      ),
      StatusBanner(
        kind: BannerKind.error,
        icon: AppIcons.xCircle,
        message: const Text(
          "Couldn't write Lighting. Nothing was lost — retry when ready.",
        ),
        actions: [
          AppButton.ghost(
            label: 'Dismiss',
            neutralForeground: true,
            size: AppButtonSize.small,
            onPressed: () {},
          ),
          AppButton.primary(
            label: 'Retry',
            icon: AppIcons.arrowsClockwise,
            size: AppButtonSize.small,
            onPressed: () {},
          ),
        ],
      ),
    ],
  );

  Widget _cards(NocturneTheme n) => LayoutBuilder(
    builder: (context, c) {
      final polling = SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            CardHeading(
              title: 'Polling rate',
              icon: AppIcons.pulse,
              changed: _polling != 1000,
            ),
            SegmentedControl<int>(
              tabular: true,
              selected: _polling,
              onChanged: (v) => setState(() => _polling = v),
              options: [
                for (final hz in const [125, 250, 500, 1000])
                  SegmentOption(value: hz, label: '$hz Hz'),
              ],
            ),
            Text(
              '${(1000 / _polling).toStringAsFixed(_polling > 500 ? 0 : 1)} ms '
              'between reports. Higher is smoother but uses more battery.',
              style: n.text.caption.copyWith(color: n.textSecondary),
            ),
          ],
        ),
      );
      final sensor = SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            const CardHeading(title: 'Sensor', icon: AppIcons.crosshair),
            ToggleRow(
              title: 'Angle snap',
              description: 'Straightens slightly wobbly movement lines.',
              value: _angleSnap,
              changed: _angleSnap,
              onChanged: (v) => setState(() => _angleSnap = v),
            ),
            ToggleRow(
              title: 'Ripple control',
              description: 'Smooths sensor jitter at high DPI.',
              value: _ripple,
              changed: !_ripple,
              onChanged: (v) => setState(() => _ripple = v),
            ),
          ],
        ),
      );
      if (c.maxWidth < 612) {
        return Column(spacing: 12, children: [polling, sensor]);
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Expanded(child: polling),
            Expanded(child: sensor),
          ],
        ),
      );
    },
  );

  Widget _sliders() => Column(
    spacing: 12,
    children: [
      SliderRow(
        title: 'Sleep timer',
        icon: AppIcons.moon,
        description: 'Idle time before the mouse sleeps. Moving it wakes it.',
        changed: _sleep != 1,
        slider: ValueSlider(
          value: _sleep,
          min: 1,
          max: 60,
          unit: 'min',
          semanticLabel: 'Sleep timer',
          onChanged: (v) => setState(() => _sleep = v),
        ),
      ),
      SliderRow(
        title: 'Button debounce',
        icon: AppIcons.timer,
        description:
            'Lower = faster response. Higher = fewer accidental double-clicks.',
        changed: _debounce != 8,
        extra: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in const [4, 8, 16])
              PillChip(
                dense: true,
                label: '$p ms',
                selected: _debounce == p,
                onPressed: () => setState(() => _debounce = p.toDouble()),
              ),
          ],
        ),
        slider: ValueSlider(
          value: _debounce,
          min: 4,
          max: 50,
          step: 2,
          unit: 'ms',
          rangeLabels: const ['4 ms', '2 ms steps', '50 ms'],
          semanticLabel: 'Debounce',
          onChanged: (v) => setState(() => _debounce = v),
        ),
      ),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            const CardHeading(title: 'Large slider with seam'),
            AppSlider(
              value: _dpiIndex,
              min: 0,
              max: 319,
              large: true,
              gradient: true,
              seams: const [198 / 319],
              semanticLabel: 'DPI',
              onChanged: (v) => setState(() => _dpiIndex = v),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _forms(NocturneTheme n) => _group('Inputs and choices', [
    Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        const TextInput(
          label: 'Macro name',
          hint: 'Untitled macro',
          width: 220,
        ),
        const TextInput(
          hint: 'Search macros',
          prefixIcon: AppIcons.magnifyingGlass,
          width: 220,
        ),
        TextInput(
          numeric: true,
          suffixText: 'DPI',
          width: 150,
          textAlign: TextAlign.right,
          style: n.text.valueMedium,
          controller: TextEditingController(text: '1600'),
        ),
        const TextInput(
          numeric: true,
          suffixText: 'ms',
          width: 96,
          dense: true,
        ),
      ],
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        AppRadio<String>(
          value: 'times',
          groupValue: _playback,
          onChanged: (v) => setState(() => _playback = v),
          label: const Text('Play'),
          trailing: Text(
            '3 times',
            style: n.text.caption.copyWith(color: n.textSecondary),
          ),
        ),
        AppRadio<String>(
          value: 'until',
          groupValue: _playback,
          onChanged: (v) => setState(() => _playback = v),
          label: const Text('Repeat until any key is pressed'),
        ),
        AppRadio<String>(
          value: 'held',
          groupValue: _playback,
          onChanged: (v) => setState(() => _playback = v),
          label: const Text('Repeat while held'),
        ),
      ],
    ),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in const ['Ctrl', 'Shift', 'Alt', 'Win'])
          PillChip(
            label: m,
            selected: _mods.contains(m),
            onPressed: () => setState(
              () => _mods.contains(m) ? _mods.remove(m) : _mods.add(m),
            ),
          ),
      ],
    ),
    Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 4,
      children: [
        for (var i = 0; i < 8; i++)
          Expanded(
            child: Semantics(
              label: 'Brightness ${i + 1}',
              child: GestureDetector(
                onTap: () => setState(() => _brightness = i + 1),
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: n.radius.smAll,
                    color: i < _brightness
                        ? n.accent.withValues(alpha: (40 + i * 8.5) / 100)
                        : n.palette.n(800),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    ColourPicker(value: _colour, onChanged: (c) => setState(() => _colour = c)),
  ]);

  Widget _states(NocturneTheme n) => _group('Loading and motion', [
    Row(
      spacing: 24,
      children: [
        const PulseRings(child: _DeviceDisc()),
        Row(
          spacing: 8,
          children: [
            const Spinner(),
            Text(
              'Reading settings from X11SE…',
              style: n.text.small.copyWith(color: n.textSecondary),
            ),
          ],
        ),
        Blink(child: ChangedDot(size: 8, color: n.palette.danger)),
        AppButton(
          label: 'Show toasts',
          onPressed: () {
            _toasts.show(
              'DPI button · stage 4 · 1,600 DPI',
              icon: AppIconsFill.gauge,
            );
            _toasts.show(
              'Battery low — 9%. Connect the cable to charge.',
              kind: ToastKind.warning,
              icon: AppIconsFill.batteryWarning,
            );
          },
        ),
        AppButton(label: 'Rename dialog', onPressed: _rename),
      ],
    ),
    const Skeleton(width: 220, height: 26),
    LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / 132).floor().clamp(1, 8);
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 8; i++) Skeleton(width: w, height: 104),
          ],
        );
      },
    ),
    const Skeleton(height: 120, large: true),
  ]);

  Future<void> _confirm() async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: AppIcons.warning,
        danger: true,
        title: 'Restore mouse to factory defaults?',
        body:
            'Every setting on the mouse — DPI stages, buttons, lighting and '
            'timers — goes back to factory values. Profiles and macros on this '
            'computer are kept.',
        actions: [
          AppButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton(
            label: 'Restore factory defaults',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (ok ?? false) _toasts.show('Defaults restored', kind: ToastKind.success);
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: 'Default');
    final name = await showAppDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        icon: AppIcons.pencilSimple,
        title: 'Rename profile',
        body: 'Profiles are stored on this computer.',
        content: TextInput(
          controller: controller,
          autofocus: true,
          semanticLabel: 'Name',
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppButton.primary(
            label: 'Rename',
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) {
      _toasts.show('Renamed to “$name”', kind: ToastKind.success);
    }
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: n.palette.a(800),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$count',
        style: n.text.tabular(n.text.micro.copyWith(color: n.palette.a(100))),
      ),
    );
  }
}

class _DeviceDisc extends StatelessWidget {
  const _DeviceDisc();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: n.surface,
        shape: BoxShape.circle,
        boxShadow: n.palette.shadowSm,
      ),
      child: Icon(AppIcons.mouseSimple, size: 32, color: n.accent),
    );
  }
}
