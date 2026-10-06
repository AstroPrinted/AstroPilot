import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Inserta [gap] entre los hijos de una columna.
List<Widget> apSpaced(List<Widget> children, {double gap = 12}) {
  final visible = children.toList();
  return [
    for (var i = 0; i < visible.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      visible[i],
    ],
  ];
}

/// Tarjeta base (`.ap-card`). Con [accent] dibuja el degradado diagonal de la
/// pestaña Técnico; con [error] el borde y degradado rojos.
class ApCard extends StatelessWidget {
  final List<Widget> children;
  final Color? accent;
  final bool error;
  final EdgeInsetsGeometry padding;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  const ApCard({
    super.key,
    required this.children,
    this.accent,
    this.error = false,
    this.padding = const EdgeInsets.all(16),
    this.gap = 12,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    final tint = error ? ApColors.error : accent;
    return Container(
      decoration: BoxDecoration(
        color: ApColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error
              ? ApColors.error.withValues(alpha: 0.45)
              : ApColors.border,
        ),
        gradient: tint == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: error ? 0.14 : 0.10),
                  Colors.transparent,
                ],
                stops: [0, error ? 0.7 : 0.55],
              ),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: apSpaced(children, gap: gap),
      ),
    );
  }
}

/// Encabezado de tarjeta: ícono de acento + título.
class ApCardHead extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Widget? trailing;

  const ApCardHead({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor ?? ApColors.secondary),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: ApText.title)),
        ?trailing,
      ],
    );
  }
}

class ApPill extends StatelessWidget {
  final String label;
  final ApTone tone;
  final bool small;
  final bool dot;

  const ApPill(
    this.label, {
    super.key,
    this.tone = ApTone.info,
    this.small = false,
    this.dot = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = tone.color;
    return Container(
      height: small ? 22 : 26,
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: small ? 6 : 7,
              height: small ? 6 : 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: small ? 5 : 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: small ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill alineada a la izquierda dentro de una columna estirada.
class ApPillLeft extends StatelessWidget {
  final ApPill pill;
  const ApPillLeft(this.pill, {super.key});

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.centerLeft, widthFactor: 1, child: pill);
}

class ApBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const ApBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ApTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  /// Valor de texto (no numérico): fuente normal en vez de monoespaciada.
  final bool isText;
  final double? fontSize;

  const ApTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.isText = false,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ApColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              height: 15 / 11.5,
              color: ApColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize ?? (isText ? 16 : 18),
              fontWeight: FontWeight.w600,
              color: valueColor ?? ApColors.text,
              fontFamily: isText ? null : ApText.mono,
              fontFeatures: isText
                  ? null
                  : const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grilla de tiles de 2 o 3 columnas.
class ApTiles extends StatelessWidget {
  final List<Widget> tiles;
  final int columns;

  const ApTiles({super.key, required this.tiles, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      final row = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (j > 0) row.add(const SizedBox(width: 10));
        final index = i + j;
        row.add(
          Expanded(
            child: index < tiles.length ? tiles[index] : const SizedBox(),
          ),
        );
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: row,
          ),
        ),
      );
    }
    return Column(children: apSpaced(rows, gap: 10));
  }
}

/// Aviso en línea (`.ap-notice`).
class ApNotice extends StatelessWidget {
  final IconData icon;
  final ApTone tone;
  final Color? color;
  final String? text;
  final Widget? child;

  const ApNotice({
    super.key,
    required this.icon,
    this.tone = ApTone.info,
    this.color,
    this.text,
    this.child,
  }) : assert(text != null || child != null);

  @override
  Widget build(BuildContext context) {
    final c = color ?? tone.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 12.5,
                height: 18 / 12.5,
                color: ApColors.text,
              ),
              child: child ?? Text(text!),
            ),
          ),
        ],
      ),
    );
  }
}

class ApStepBadge extends StatelessWidget {
  final String label;
  const ApStepBadge(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    // widthFactor keeps the badge compact inside a Wrap or Row.
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ApColors.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF93C5FD),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ApSectionLabel extends StatelessWidget {
  final String text;
  const ApSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: ApText.section);
}

class ApMonoBlock extends StatelessWidget {
  final String? label;
  final String text;

  const ApMonoBlock({super.key, this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ApColors.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
          fontFamily: ApText.mono,
          fontSize: 12.5,
          height: 18 / 12.5,
          color: ApColors.text,
        ),
      ),
    );
    if (label == null) return block;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: ApText.small),
        const SizedBox(height: 6),
        block,
      ],
    );
  }
}

class ApDivider extends StatelessWidget {
  const ApDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: ApColors.border);
}

/// Línea de información pequeña con ícono (`ap-small` con ícono `info`).
class ApInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;
  final bool center;

  const ApInfoLine({
    super.key,
    required this.text,
    this.icon = Icons.info,
    this.iconColor = ApColors.secondary,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: ApText.small,
            textAlign: center ? TextAlign.center : TextAlign.start,
          ),
        ),
      ],
    );
  }
}

/// Fila de verificación (ícono de estado + título + detalle).
class ApCheckRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String detail;
  final bool monoDetail;

  const ApCheckRow({
    super.key,
    required this.leading,
    required this.title,
    required this.detail,
    this.monoDetail = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ApText.strong),
              const SizedBox(height: 2),
              Text(
                detail,
                style: monoDetail
                    ? ApText.small.merge(ApText.number)
                    : ApText.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ícono cuadrado de lista (`.ap-list-icon`).
class ApListIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const ApListIcon(
    this.icon, {
    super.key,
    this.color = ApColors.secondary,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ApColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

/// Miniatura cuadrada de una imagen incluida en la app. Si no hay imagen (o
/// no carga) muestra [fallback], que debe medir lo mismo.
class ApThumbnail extends StatelessWidget {
  final String? asset;
  final double size;
  final Widget fallback;

  const ApThumbnail({
    super.key,
    required this.asset,
    required this.fallback,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    if (asset == null) return fallback;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Lists decode a thumbnail, not the full 4:3 picture.
        cacheWidth: pixels * 4 ~/ 3,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// Foto 4:3 de una ficha, con el crédito de la imagen debajo.
class ApPhoto extends StatelessWidget {
  final String asset;
  final String? credit;
  final String semanticLabel;

  const ApPhoto({
    super.key,
    required this.asset,
    required this.semanticLabel,
    this.credit,
  });

  @override
  Widget build(BuildContext context) {
    final credit = this.credit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              semanticLabel: semanticLabel,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: ApColors.surface2,
                child: Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: ApColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (credit != null && credit.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Imagen: $credit',
            style: ApText.small.copyWith(fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

/// Opción seleccionable tipo radio (`.ap-option`).
class ApOption extends StatelessWidget {
  final Widget child;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final IconData? icon;

  const ApOption({
    super.key,
    required this.child,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? ApColors.ok : ApColors.outline;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected
            ? ApColors.ok.withValues(alpha: 0.10)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon ??
                        (selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                    size: 22,
                    color: selected ? ApColors.ok : ApColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(
                        fontSize: 14,
                        color: ApColors.text,
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de método (`.ap-method`).
class ApMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool highlighted;

  const ApMethodTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: highlighted
            ? ApColors.primary.withValues(alpha: 0.18)
            : ApColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: highlighted
                ? ApColors.primary.withValues(alpha: 0.45)
                : ApColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: ApColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ApText.strong),
                      const SizedBox(height: 2),
                      Text(subtitle, style: ApText.small),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    const Icon(
                      Icons.chevron_right,
                      color: ApColors.muted,
                      size: 22,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador de progreso indeterminado (`.ap-progress`).
class ApProgress extends StatelessWidget {
  const ApProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        minHeight: 4,
        color: ApColors.primary,
        backgroundColor: ApColors.primary.withValues(alpha: 0.2),
      ),
    );
  }
}

/// Botones de ancho completo del diseño.
class ApButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool iconAfter;
  final VoidCallback? onPressed;
  final ApButtonKind kind;
  final bool large;
  final bool busy;
  final Color? foreground;

  const ApButton({
    super.key,
    required this.label,
    this.icon,
    this.iconAfter = false,
    this.onPressed,
    this.kind = ApButtonKind.filled,
    this.large = false,
    this.busy = false,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final height = large ? 52.0 : 40.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(height / 2),
    );
    final textStyle = TextStyle(
      fontSize: large ? 16 : 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    );
    final leading = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kind == ApButtonKind.filled || kind == ApButtonKind.danger
                  ? Colors.white
                  : ApColors.primary,
            ),
          )
        : icon == null
        ? null
        : Icon(icon, size: 18);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null && !iconAfter) ...[
          leading,
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (leading != null && iconAfter) ...[
          const SizedBox(width: 8),
          leading,
        ],
      ],
    );
    final size = Size(double.infinity, height);
    final onTap = busy ? null : onPressed;
    switch (kind) {
      case ApButtonKind.filled:
      case ApButtonKind.danger:
        return FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            minimumSize: size,
            shape: shape,
            textStyle: textStyle,
            backgroundColor: kind == ApButtonKind.danger
                ? ApColors.error
                : ApColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ApColors.text.withValues(alpha: 0.12),
            disabledForegroundColor: ApColors.text.withValues(alpha: 0.38),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: content,
        );
      case ApButtonKind.outlined:
        return OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            shape: shape,
            textStyle: textStyle,
            foregroundColor: foreground ?? ApColors.primary,
            side: BorderSide(
              color: onTap == null
                  ? ApColors.text.withValues(alpha: 0.12)
                  : ApColors.outline,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: content,
        );
      case ApButtonKind.text:
        return TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: size,
            shape: shape,
            textStyle: textStyle,
            foregroundColor: foreground ?? ApColors.primary,
          ),
          child: content,
        );
    }
  }
}

enum ApButtonKind { filled, outlined, danger, text }

/// Botón que repite su acción mientras se mantiene presionado. Cada repetición
/// espera a que termine la anterior (un movimiento del telescopio).
class ApHoldButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool iconAfter;
  final Future<void> Function()? onAction;

  const ApHoldButton({
    super.key,
    required this.label,
    required this.icon,
    this.iconAfter = false,
    this.onAction,
  });

  @override
  State<ApHoldButton> createState() => _ApHoldButtonState();
}

class _ApHoldButtonState extends State<ApHoldButton> {
  static const _repeatDelay = Duration(milliseconds: 250);
  bool _pressed = false;
  bool _running = false;

  Future<void> _start() async {
    final action = widget.onAction;
    if (action == null || _running) return;
    _pressed = true;
    _running = true;
    try {
      do {
        await action();
        if (!mounted || !_pressed) break;
        await Future<void>.delayed(_repeatDelay);
      } while (mounted && _pressed);
    } finally {
      _running = false;
    }
  }

  void _release() => _pressed = false;

  @override
  void dispose() {
    _pressed = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onAction != null;
    return Listener(
      onPointerDown: enabled ? (_) => unawaited(_start()) : null,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      // Claims vertical drags so a finger that drifts while holding does not
      // scroll the page out from under the button.
      child: GestureDetector(
        onVerticalDragStart: enabled ? (_) {} : null,
        onVerticalDragUpdate: enabled ? (_) {} : null,
        child: ApButton(
          label: widget.label,
          icon: widget.icon,
          iconAfter: widget.iconAfter,
          // The Listener drives the action; the button only paints the state.
          onPressed: enabled ? () {} : null,
        ),
      ),
    );
  }
}

/// Joystick de flechas (`.ap-joy`).
class ApJoystick extends StatelessWidget {
  final Future<void> Function()? onUp;
  final Future<void> Function()? onDown;
  final Future<void> Function()? onLeft;
  final Future<void> Function()? onRight;
  final String caption;

  const ApJoystick({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApHoldButton(label: 'Arriba', icon: Icons.arrow_upward, onAction: onUp),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ApHoldButton(
                label: 'Izquierda',
                icon: Icons.arrow_back,
                onAction: onLeft,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ApHoldButton(
                label: 'Derecha',
                icon: Icons.arrow_forward,
                iconAfter: true,
                onAction: onRight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ApHoldButton(
          label: 'Abajo',
          icon: Icons.arrow_downward,
          onAction: onDown,
        ),
        const SizedBox(height: 8),
        Text(caption, style: ApText.small, textAlign: TextAlign.center),
      ],
    );
  }
}

enum ApStepState { done, now, todo }

/// Indicador de progreso del tutorial (`.ap-stepper`).
class ApStepper extends StatelessWidget {
  final List<String> labels;
  final List<ApStepState> states;
  final ValueChanged<int>? onTap;

  const ApStepper({
    super.key,
    required this.labels,
    required this.states,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      decoration: const BoxDecoration(
        color: ApColors.surface,
        border: Border(bottom: BorderSide(color: ApColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++) Expanded(child: _item(i)),
        ],
      ),
    );
  }

  Widget _item(int i) {
    final state = states[i];
    final lineOn = state != ApStepState.todo;
    final dot = switch (state) {
      ApStepState.done => Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: ApColors.secondary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 16, color: ApColors.background),
      ),
      ApStepState.now => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Opaque, or the connector line shows through the dot.
          color: Color.alphaBlend(
            ApColors.primary.withValues(alpha: 0.25),
            ApColors.surface,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: ApColors.primary, width: 2),
        ),
        child: Text('${i + 1}', style: _dotText(ApColors.text)),
      ),
      ApStepState.todo => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ApColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: ApColors.muted.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Text('${i + 1}', style: _dotText(ApColors.muted)),
      ),
    };
    final label = Text(
      labels[i],
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: TextStyle(
        fontSize: 10.5,
        height: 13 / 10.5,
        color: switch (state) {
          ApStepState.done => ApColors.secondary,
          ApStepState.now => ApColors.text,
          ApStepState.todo => ApColors.muted,
        },
        fontWeight: state == ApStepState.now ? FontWeight.w500 : null,
      ),
    );
    Color lineColor(bool on) =>
        on ? ApColors.secondary : ApColors.muted.withValues(alpha: 0.22);
    // Each half joins this dot with its neighbour, colored by the later step.
    final nextOn = i + 1 < states.length && states[i + 1] != ApStepState.todo;
    final content = Column(
      children: [
        SizedBox(
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: i > 0
                          ? Container(height: 2, color: lineColor(lineOn))
                          : const SizedBox(),
                    ),
                    Expanded(
                      child: i + 1 < states.length
                          ? Container(height: 2, color: lineColor(nextOn))
                          : const SizedBox(),
                    ),
                  ],
                ),
              ),
              dot,
            ],
          ),
        ),
        const SizedBox(height: 4),
        label,
      ],
    );
    return Semantics(
      button: onTap != null,
      label: 'Paso ${i + 1}: ${labels[i]}',
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(i),
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }

  static TextStyle _dotText(Color color) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color);
}

/// Aviso global bajo el AppBar (`.ap-banner`), p. ej. alineación perdida.
class ApBanner extends StatelessWidget {
  final String title;
  final String text;
  final List<Widget> actions;

  const ApBanner({
    super.key,
    required this.title,
    required this.text,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          ApColors.error.withValues(alpha: 0.14),
          ApColors.surface,
        ),
        border: Border(
          bottom: BorderSide(color: ApColors.error.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 20, color: ApColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$title ',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(text: text),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    color: ApColors.text,
                  ),
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Botón pequeño para banners (`.ap-btn--sm`).
class ApSmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  const ApSmallButton({
    super.key,
    required this.label,
    this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder();
    const text = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
    const padding = EdgeInsets.symmetric(horizontal: 14);
    if (danger) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ApColors.error,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 36),
          shape: shape,
          textStyle: text,
          padding: padding,
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: ApColors.primary,
        side: const BorderSide(color: ApColors.outline),
        minimumSize: const Size(0, 36),
        shape: shape,
        textStyle: text,
        padding: padding,
      ),
      child: Text(label),
    );
  }
}

/// Campo numérico del diseño (`.ap-field`).
class ApNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool enabled;
  final bool signed;

  const ApNumberField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.enabled = true,
    this.signed = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(
        signed: signed,
        decimal: true,
      ),
      style: const TextStyle(
        fontFamily: ApText.mono,
        fontSize: 16,
        color: ApColors.text,
      ),
      decoration: InputDecoration(labelText: label, helperText: helper),
    );
  }
}

/// Parsea un número aceptando coma decimal.
double? parseApNumber(String raw) =>
    double.tryParse(raw.trim().replaceAll(',', '.'));

String formatDeg(double? value, {int decimals = 2}) =>
    value == null ? '—' : '${value.toStringAsFixed(decimals)}°';

String formatSignedDeg(double value, {int decimals = 2}) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(decimals)}°';

String formatClock(DateTime time) {
  final local = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
