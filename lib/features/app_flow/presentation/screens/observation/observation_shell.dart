import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/widgets/ap_widgets.dart';
import '../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../../oe4_control/presentation/screens/oe4_control_screen.dart';
import '../../../application/app_flow_state.dart';
import '../../widgets/mode_scaffold.dart';
import 'alignment_summary_screen.dart';
import 'observation_catalog_screen.dart';
import 'observation_tutorial.dart';
import 'observe_object_screen.dart';

/// Modo Observación: pestañas Conexión (solo sin conexión), Alineación,
/// Catálogo y Técnico. Cada pestaña tiene su propia pila de pantallas.
class ObservationShell extends StatefulWidget {
  const ObservationShell({super.key});

  @override
  State<ObservationShell> createState() => _ObservationShellState();
}

class _ObservationShellState extends State<ObservationShell> {
  late final AppFlowState _flow;
  late ObservationTab _tab;
  final Map<ObservationTab, GlobalKey<NavigatorState>> _navigators = {
    for (final tab in ObservationTab.values) tab: GlobalKey<NavigatorState>(),
  };

  @override
  void initState() {
    super.initState();
    _flow = context.read<AppFlowState>();
    _tab = _flow.takeRequestedTab() ?? _defaultTab();
    _flow.addListener(_onFlowChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prepareTutorial();
      _openPendingObject();
    });
  }

  @override
  void dispose() {
    _flow.removeListener(_onFlowChanged);
    super.dispose();
  }

  ObservationTab _defaultTab() =>
      _flow.isConnected ? ObservationTab.alignment : ObservationTab.connection;

  /// Al entrar con el tutorial a medias, salta los pasos que ya están
  /// hechos (nunca retrocede: un paso elegido a propósito se respeta).
  void _prepareTutorial() {
    if (_flow.tutorialCompleted) return;
    final calibration = context.read<CalibrationController>();
    final step = !_flow.isConnected
        ? ObservationStep.connection
        : !_flow.isZeroFixed
        ? ObservationStep.leveling
        : !calibration.isInitialAligned
        ? ObservationStep.alignment
        : ObservationStep.fineAdjust;
    if (step.index > _flow.tutorialStep.index) _flow.setTutorialStep(step);
  }

  void _onFlowChanged() {
    final requested = _flow.takeRequestedTab();
    if (requested != null) {
      _select(requested);
      return;
    }
    final tabs = _visibleTabs();
    if (!tabs.contains(_tab)) _select(ObservationTab.alignment);
  }

  List<ObservationTab> _visibleTabs() => [
    if (!_flow.isConnected) ObservationTab.connection,
    ObservationTab.alignment,
    ObservationTab.catalog,
    ObservationTab.technical,
  ];

  void _select(ObservationTab tab) {
    if (!mounted) return;
    if (tab == _tab) {
      // Tocar la pestaña activa vuelve a su pantalla inicial.
      _navigators[tab]?.currentState?.popUntil((r) => r.isFirst);
    }
    setState(() => _tab = tab);
    if (tab == ObservationTab.catalog) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingObject());
    }
  }

  /// Un objeto elegido en Educativo se abre en Catálogo cuando ya hay
  /// alineación.
  void _openPendingObject() {
    if (!mounted || _tab != ObservationTab.catalog) return;
    final object = _flow.pendingObject;
    if (object == null ||
        !context.read<CalibrationController>().isInitialAligned) {
      return;
    }
    _flow.setPendingObject(null);
    final navigator = _navigators[ObservationTab.catalog]?.currentState;
    navigator?.popUntil((r) => r.isFirst);
    navigator?.push(
      MaterialPageRoute<void>(
        builder: (_) => ObserveObjectScreen(object: object),
      ),
    );
  }

  Widget _root(ObservationTab tab) => switch (tab) {
    ObservationTab.connection => const ObservationTutorial(
      connectionOnly: true,
    ),
    ObservationTab.alignment => const _AlignmentTabRoot(),
    ObservationTab.catalog => const ObservationCatalogScreen(),
    ObservationTab.technical => const Oe4ControlScreen(
      appBar: ModeAppBar(title: 'Técnico'),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final connected = context.select<AppFlowState, bool>((s) => s.isConnected);
    final tabs = [
      if (!connected) ObservationTab.connection,
      ObservationTab.alignment,
      ObservationTab.catalog,
      ObservationTab.technical,
    ];
    final current = tabs.contains(_tab) ? _tab : ObservationTab.alignment;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = _navigators[current]?.currentState;
        if (navigator != null && await navigator.maybePop()) return;
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: ObservationTab.values.indexOf(current),
          children: [
            for (final tab in ObservationTab.values)
              HeroControllerScope.none(
                child: Navigator(
                  key: _navigators[tab],
                  onGenerateRoute: (_) =>
                      MaterialPageRoute<void>(builder: (_) => _root(tab)),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _ObservationNavBar(
          tabs: tabs,
          current: current,
          onSelect: _select,
        ),
      ),
    );
  }
}

class _AlignmentTabRoot extends StatelessWidget {
  const _AlignmentTabRoot();

  @override
  Widget build(BuildContext context) {
    final completed = context.select<AppFlowState, bool>(
      (s) => s.tutorialCompleted,
    );
    return completed
        ? const AlignmentSummaryScreen()
        : const ObservationTutorial();
  }
}

class _ObservationNavBar extends StatelessWidget {
  final List<ObservationTab> tabs;
  final ObservationTab current;
  final ValueChanged<ObservationTab> onSelect;

  const _ObservationNavBar({
    required this.tabs,
    required this.current,
    required this.onSelect,
  });

  static (IconData, String) _item(ObservationTab tab) => switch (tab) {
    ObservationTab.connection => (Icons.bluetooth, 'Conexión'),
    ObservationTab.alignment => (Icons.center_focus_strong, 'Alineación'),
    ObservationTab.catalog => (Icons.auto_awesome, 'Catálogo'),
    ObservationTab.technical => (Icons.precision_manufacturing, 'Técnico'),
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1A94A3B8))),
      ),
      child: BottomNavigationBar(
        currentIndex: tabs.indexOf(current),
        onTap: (i) => onSelect(tabs[i]),
        items: [
          for (final tab in tabs)
            BottomNavigationBarItem(
              icon: Icon(_item(tab).$1),
              label: _item(tab).$2,
            ),
        ],
      ),
    );
  }
}

/// Aviso de alineación perdida con sus dos salidas.
class ReferenceLostBanner extends StatelessWidget {
  const ReferenceLostBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlowState>();
    if (!flow.referenceLost) return const SizedBox.shrink();
    final connected = flow.isConnected;
    return ApBanner(
      title: connected
          ? 'Alineación perdida.'
          : 'Se desconectó el telescopio. Alineación perdida.',
      text: 'Vuelve a alinear con una estrella.',
      // Perder la conexión también invalida el 0 / 0, así que se repite
      // desde el primer paso que falta.
      actions: [
        ApSmallButton(
          label: 'Alinear de nuevo',
          danger: true,
          onPressed: () {
            flow.startTutorialAt(
              connected ? ObservationStep.leveling : ObservationStep.connection,
            );
            flow.requestTab(
              connected ? ObservationTab.alignment : ObservationTab.connection,
            );
          },
        ),
      ],
    );
  }
}
