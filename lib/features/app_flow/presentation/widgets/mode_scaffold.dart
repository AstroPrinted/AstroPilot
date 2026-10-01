import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ap_widgets.dart';
import '../../application/app_flow_state.dart';

/// Vuelve a Inicio (la primera ruta de la app).
void goHome(BuildContext context) {
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
}

/// AppBar de los modos: Inicio (o atrás) a la izquierda y el estado de la
/// conexión a la derecha.
class ModeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool back;
  final bool showConnection;
  final List<Widget> actions;
  final Widget? titleWidget;

  const ModeAppBar({
    super.key,
    required this.title,
    this.back = false,
    this.showConnection = true,
    this.actions = const [],
    this.titleWidget,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final connected = context.select<AppFlowState, bool>((s) => s.isConnected);
    return AppBar(
      automaticallyImplyLeading: false,
      leading: back
          ? IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : IconButton(
              tooltip: 'Volver al inicio',
              icon: const Icon(Icons.home),
              onPressed: () => goHome(context),
            ),
      title: titleWidget ?? Text(title, overflow: TextOverflow.ellipsis),
      actions: [
        ...actions,
        if (showConnection && connected)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: ApPill('OE4 conectado', tone: ApTone.ok, small: true),
            ),
          ),
      ],
    );
  }
}

/// Cuerpo desplazable con el espaciado del diseño (16 px de margen, 14 px
/// entre bloques). [header] queda fijo arriba (stepper, banner).
class ModeBody extends StatelessWidget {
  final List<Widget> header;
  final List<Widget> children;
  final double gap;

  const ModeBody({
    super.key,
    this.header = const [],
    required this.children,
    this.gap = 14,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: apSpaced(children, gap: gap),
    );
    if (header.isEmpty) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...header,
        Expanded(child: list),
      ],
    );
  }
}

/// Texto pequeño centrado bajo un botón.
class CenteredSmall extends StatelessWidget {
  final String text;
  const CenteredSmall(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: ApText.small, textAlign: TextAlign.center);
}
