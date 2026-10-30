import 'dart:async';

import 'package:flutter/material.dart';

import 'data/examples.dart';
import 'screens/docs_page.dart';
import 'screens/examples_page.dart';
import 'screens/executor_page.dart';
import 'state/executor_state.dart';
import 'theme/cbr_theme.dart';
import 'widgets/cbr_logo.dart';
import 'widgets/settings_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CbrApp());
}

enum CbrPage {
  executor('Editor', Icons.code_rounded),
  documentacao('Documentação', Icons.menu_book_rounded),
  exemplos('Exemplos', Icons.widgets_outlined);

  const CbrPage(this.label, this.icon);

  final String label;
  final IconData icon;
}

class CbrApp extends StatefulWidget {
  const CbrApp({super.key});

  @override
  State<CbrApp> createState() => _CbrAppState();
}

class _CbrAppState extends State<CbrApp> {
  final ExecutorState _state = ExecutorState();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  CbrPage _page = CbrPage.executor;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _state.addListener(_scheduleSave);
    unawaited(_state.restore());
  }

  void _scheduleSave() {
    if (_state.dirty) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 900), () {
        unawaited(_state.persist());
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _state.removeListener(_scheduleSave);
    _state.dispose();
    super.dispose();
  }

  void _snack(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 17, color: CbrColors.green),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openExample(CbrExample example) {
    _state.loadProgram(example.code, name: example.filename);
    setState(() => _page = CbrPage.executor);
    _snack('Exemplo carregado.');
  }

  void _tryCode(String code) {
    _state.loadProgram(code, name: 'main.cbr', markAsDirty: true);
    setState(() => _page = CbrPage.executor);
    _snack('Código carregado no editor.');
  }

  void _go(CbrPage page) {
    if (_page != page) setState(() => _page = page);
    _scaffoldKey.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C Brasil (cbr)',
      debugShowCheckedModeBanner: false,
      theme: buildCbrTheme(),
      scaffoldMessengerKey: _messengerKey,
      home: Builder(
        builder: (homeContext) => Scaffold(
          key: _scaffoldKey,
          backgroundColor: CbrColors.background,
          drawer: MediaQuery.of(homeContext).size.width < 760
              ? _Drawer(current: _page, onSelected: _go)
              : null,
          body: _Background(
            child: SafeArea(
              child: Column(
                children: [
                  _Header(
                    page: _page,
                    onSelected: _go,
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    onSettings: () => SettingsDialog.show(homeContext, _state),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: _body(),
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

  Widget _body() {
    switch (_page) {
      case CbrPage.executor:
        return ExecutorPage(state: _state);
      case CbrPage.documentacao:
        return DocsPage(onTryCode: _tryCode);
      case CbrPage.exemplos:
        return ExamplesPage(onLoadExample: _openExample);
    }
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: CbrColors.background, child: child);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.page,
    required this.onSelected,
    required this.onMenu,
    required this.onSettings,
  });

  final CbrPage page;
  final ValueChanged<CbrPage> onSelected;
  final VoidCallback onMenu;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final medium = constraints.maxWidth < 1080;
        return Container(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 10, compact ? 12 : 20, 10),
          decoration: const BoxDecoration(
            color: CbrColors.surface,
            border: Border(bottom: BorderSide(color: CbrColors.border, width: 0.8)),
          ),
          child: Row(
            children: [
              if (compact) ...[
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu_rounded, color: CbrColors.textMuted),
                  tooltip: 'Menu',
                ),
                const SizedBox(width: 2),
              ],
              CbrWordmark(
                logoSize: compact ? 30 : 36,
                onTap: () => onSelected(CbrPage.executor),
              ),
              if (!compact) ...[
                const SizedBox(width: 24),
                Expanded(child: _nav(medium)),
                const SizedBox(width: 8),
              ] else
                const Spacer(),
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.tune_rounded, size: 19, color: CbrColors.textMuted),
                tooltip: 'Preferências',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _nav(bool medium) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in CbrPage.values)
            _NavItem(
              page: item,
              selected: item == page,
              dense: medium,
              onTap: () => onSelected(item),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.page,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final CbrPage page;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CbrColors.greenBright : CbrColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? CbrColors.green.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? CbrColors.green.withValues(alpha: 0.28) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(page.icon, size: 15, color: color),
              const SizedBox(width: 7),
              Text(
                page.label,
                style: CbrTextStyles.body.copyWith(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Drawer extends StatelessWidget {
  const _Drawer({required this.current, required this.onSelected});

  final CbrPage current;
  final ValueChanged<CbrPage> onSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: CbrColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: CbrWordmark(
                logoSize: 34,
                onTap: () => onSelected(CbrPage.executor),
              ),
            ),
            const Divider(height: 1, color: CbrColors.border),
            for (final item in CbrPage.values)
              ListTile(
                onTap: () => onSelected(item),
                leading: Icon(
                  item.icon,
                  size: 18,
                  color: item == current ? CbrColors.greenBright : CbrColors.textMuted,
                ),
                title: Text(
                  item.label,
                  style: CbrTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: item == current ? FontWeight.w600 : FontWeight.w400,
                    color: item == current ? CbrColors.text : CbrColors.textMuted,
                  ),
                ),
                trailing: item == current
                    ? const Icon(Icons.chevron_right_rounded, color: CbrColors.green)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
