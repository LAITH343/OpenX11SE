import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../../core/formatting/color_hex.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/nocturne_palette.dart';
import '../../core/theme/nocturne_theme.dart';
import 'app_button.dart';
import 'app_dialog.dart';
import 'choice.dart';
import 'pressable.dart';
import 'text_input.dart';

class ColourPicker extends StatefulWidget {
  const ColourPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.presets = swatchPresets,
  });

  final Color value;
  final ValueChanged<Color> onChanged;
  final List<Color> presets;

  @override
  State<ColourPicker> createState() => _ColourPickerState();
}

class _ColourPickerState extends State<ColourPicker> {
  late final TextEditingController _hex = TextEditingController(
    text: formatHexColor(widget.value),
  );
  final FocusNode _hexFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _hexFocus.addListener(() {
      if (!_hexFocus.hasFocus) _commitHex();
    });
  }

  @override
  void didUpdateWidget(covariant ColourPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_hexFocus.hasFocus) {
      _hex.text = formatHexColor(widget.value);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  void _commitHex() {
    final c = parseHexColor(_hex.text);
    if (c != null && c != widget.value) widget.onChanged(c);
    _hex.text = formatHexColor(c ?? widget.value);
  }

  void _onHexChanged(String text) {
    final c = parseHexColor(text);
    if (c != null && text.replaceAll('#', '').length == 6) {
      widget.onChanged(c);
    }
  }

  Future<void> _openCustom() async {
    final picked = await showAppDialog<Color>(
      context: context,
      builder: (_) => _CustomColourDialog(initial: widget.value),
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final current = widget.value.toARGB32();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in widget.presets)
              ColorSwatchButton(
                color: c,
                selected: c.toARGB32() == current,
                tooltip: formatHexColor(c),
                onPressed: () => widget.onChanged(c),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Pressable(
              onPressed: _openCustom,
              tooltip: 'Custom colour',
              builder: (context, _) => Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: n.radius.mdAll,
                  gradient: const SweepGradient(colors: spectrumStops),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextInput(
              controller: _hex,
              focusNode: _hexFocus,
              width: 110,
              monospace: true,
              maxLength: 7,
              semanticLabel: 'Hex colour',
              onChanged: _onHexChanged,
              onSubmitted: (_) => _commitHex(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
              ],
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: n.motion.medium,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.value,
                borderRadius: n.radius.mdAll,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CustomColourDialog extends StatefulWidget {
  const _CustomColourDialog({required this.initial});

  final Color initial;

  @override
  State<_CustomColourDialog> createState() => _CustomColourDialogState();
}

class _CustomColourDialogState extends State<_CustomColourDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final color = _hsv.toColor();
    return AppDialog(
      title: 'Custom colour',
      width: 360,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.6,
            child: _SaturationValueArea(
              hsv: _hsv,
              onChanged: (v) => setState(() => _hsv = v),
            ),
          ),
          const SizedBox(height: 12),
          _HueStrip(
            hue: _hsv.hue,
            onChanged: (h) => setState(() => _hsv = _hsv.withHue(h)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: n.radius.mdAll,
                ),
              ),
              const SizedBox(width: 10),
              Text(tr(formatHexColor(color)), style: n.text.mono),
            ],
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: 'Use colour',
          onPressed: () => Navigator.of(context).pop(color),
        ),
      ],
    );
  }
}

class _SaturationValueArea extends StatelessWidget {
  const _SaturationValueArea({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return LayoutBuilder(
      builder: (context, c) {
        void update(Offset p) {
          final s = (p.dx / c.maxWidth).clamp(0.0, 1.0);
          final v = 1 - (p.dy / c.maxHeight).clamp(0.0, 1.0);
          onChanged(hsv.withSaturation(s).withValue(v));
        }

        final hue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
        final ink = n.palette.n(900);
        return GestureDetector(
          onPanDown: (d) => update(d.localPosition),
          onPanUpdate: (d) => update(d.localPosition),
          child: ClipRRect(
            borderRadius: n.radius.mdAll,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [n.palette.n(100), hue]),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [ink.withValues(alpha: 0), ink],
                    ),
                  ),
                ),
                Positioned(
                  left: hsv.saturation * c.maxWidth - 7,
                  top: (1 - hsv.value) * c.maxHeight - 7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: n.palette.n(100), width: 2),
                      boxShadow: [BoxShadow(color: ink, blurRadius: 3)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HueStrip extends StatelessWidget {
  const _HueStrip({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return LayoutBuilder(
      builder: (context, c) {
        void update(Offset p) =>
            onChanged((p.dx / c.maxWidth).clamp(0.0, 1.0) * 359.9);
        return GestureDetector(
          onPanDown: (d) => update(d.localPosition),
          onPanUpdate: (d) => update(d.localPosition),
          child: SizedBox(
            height: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: n.radius.pillAll,
                    gradient: LinearGradient(
                      colors: [
                        for (var h = 0; h <= 360; h += 60)
                          HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: hue / 360 * c.maxWidth - 8,
                  top: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                      border: Border.all(color: n.palette.n(100), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
