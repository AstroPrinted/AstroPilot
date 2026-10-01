import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../space_education/presentation/screens/space_education_screen.dart';
import '../../../../student_mode/presentation/screens/student_mode_screen.dart';
import '../../widgets/mode_scaffold.dart';
import 'education_catalog_screen.dart';

enum _EducationTab { catalog, quiz, satellites }

/// Modo Educativo: Catálogo, Quiz y Satélites. No controla el telescopio.
class EducationShell extends StatefulWidget {
  const EducationShell({super.key});

  @override
  State<EducationShell> createState() => _EducationShellState();
}

class _EducationShellState extends State<EducationShell> {
  _EducationTab _tab = _EducationTab.catalog;
  final Map<_EducationTab, GlobalKey<NavigatorState>> _navigators = {
    for (final tab in _EducationTab.values) tab: GlobalKey<NavigatorState>(),
  };

  Widget _root(_EducationTab tab) => switch (tab) {
    _EducationTab.catalog => const EducationCatalogScreen(),
    _EducationTab.quiz => const StudentQuizPage(
      appBar: ModeAppBar(title: 'Quiz astronómico', showConnection: false),
    ),
    _EducationTab.satellites => const SpaceEducationScreen(
      appBar: ModeAppBar(
        title: 'Satélites y exploración',
        showConnection: false,
      ),
    ),
  };

  void _select(int index) {
    final tab = _EducationTab.values[index];
    if (tab == _tab) {
      _navigators[tab]?.currentState?.popUntil((r) => r.isFirst);
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = _navigators[_tab]?.currentState;
        if (navigator != null && await navigator.maybePop()) return;
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            for (final tab in _EducationTab.values)
              HeroControllerScope.none(
                child: Navigator(
                  key: _navigators[tab],
                  onGenerateRoute: (_) =>
                      MaterialPageRoute<void>(builder: (_) => _root(tab)),
                ),
              ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: ApColors.border)),
          ),
          child: BottomNavigationBar(
            currentIndex: _tab.index,
            onTap: _select,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome),
                label: 'Catálogo',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
              BottomNavigationBarItem(
                icon: Icon(Icons.satellite_alt),
                label: 'Satélites',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
