import 'dart:async';

import 'package:flutter/material.dart';

import 'data/examples.dart';
import 'screens/about_page.dart';
import 'screens/docs_page.dart';
import 'screens/examples_page.dart';
import 'screens/executor_page.dart';
import 'services/platform_service.dart';
import 'services/upstream_service.dart';
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
  exemplos('Exemplos', Icons.widgets_outlined),
  sobre('Sobre', Icons.info_outline_rounded);

  const CbrPage(this.label, this.icon);

  final String label;
  final IconData icon;
}

class CbrApp extends StatefulWidget {
  const CbrApp({super.key, this.autoCheckUpstream = true});

  /// Desligado nos testes para não depender da rede.
  final bool autoCheckUpstream;

  @override
  State<CbrApp> createState() => _CbrAppState();
}

class _CbrAppState extends State<CbrApp> {
  final ExecutorState _state = ExecutorState();
  final UpstreamService _upstream = UpstreamService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  CbrPage _page = CbrPage.executor;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _state.addListener(_scheduleSave);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _state.restore();
    if (!mounted) return;
    if (widget.autoCheckUpstream) {
      _upstream.startWatching();
    }
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
    _upstream.dispose();
    super.dispose();
  }

  Future<void> _checkUpdates() async {
    await _upstream.refresh();
    if (!mounted) return;
    final state = _upstream.state;
    _snack(
      state.hasUpdate
          ? 'O repositório da linguagem tem uma versão mais nova.'
          : state.online
              ? 'Você está na versão mais recente da linguagem.'
              : 'Não foi possível consultar o GitHub agora.',
      error: !state.online,
    );
  }

  void _snack(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.cloud_off_rounded : Icons.check_circle_outline_rounded,
              size: 17,
              color: error ? CbrColors.red : CbrColors.green,
            ),
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
    _snack('Exemplo "${example.title}" carregado no editor.');
  }

  void _tryCode(String code) {
    _state.loadProgram(code, name: 'main.cbr', markAsDirty: true);
    setState(() => _page = CbrPage.executor);
    _snack('Código copiado para o editor. Use Executar para rodar.');
  }

  void _go(CbrPage page) {
    if (_page == page) return;
    setState(() => _page = page);
    _scaffoldKey.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C Brasil (CBR) — Executor',
      debugShowCheckedModeBanner: false,
      theme: buildCbrTheme(),
      home: ScaffoldMessenger(
        child: Builder(
          builder: (context) {
            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: CbrColors.background,
              drawer: MediaQuery.of(context).size.width < 760
                  ? _Drawer(
                      current: _page,
                      onSelected: _go,
                      upstream: _upstream,
                    )
                  : null,
              body: _Background(
                child: SafeArea(
                  child: Column(
                    children: [
                      _Header(
                        page: _page,
                        onSelected: _go,
                        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                        onSettings: () => SettingsDialog.show(context, _state),
                        onCheckUpdates: _checkUpdates,
                        upstream: _upstream,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _body(),
                        ),
                      ),
                      _Footer(onSelected: _go),
                    ],
                  ),
                ),
              ),
            );
          },
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
      case CbrPage.sobre:
        return AboutPage(
          upstream: _upstream,
          onCheckUpdates: _checkUpdates,
          onReload: PlatformService.reloadApp,
        );
    }
  }
}

/// Fundo com brilho suave nas cores da bandeira.
class _Background extends StatelessWidget {
  const _Background({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF07171F), Color(0xFF050E14)],
              ),
            ),
          ),
        ),
        Positioned(
          top: -180,
          left: -120,
          child: _glow(CbrColors.green, 420, 0.10),
        ),
        Positioned(
          top: -140,
          right: -160,
          child: _glow(CbrColors.blue, 460, 0.10),
        ),
        Positioned(
          bottom: -220,
          left: 120,
          child: _glow(CbrColors.yellow, 380, 0.05),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _glow(Color color, double size, double opacity) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.page,
    required this.onSelected,
    required this.onMenu,
    required this.onSettings,
    required this.onCheckUpdates,
    required this.upstream,
  });

  final CbrPage page;
  final ValueChanged<CbrPage> onSelected;
  final VoidCallback onMenu;
  final VoidCallback onSettings;
  final Future<void> Function() onCheckUpdates;
  final UpstreamService upstream;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final medium = constraints.maxWidth < 1080;
        return Container(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 10, compact ? 12 : 20, 10),
          decoration: const BoxDecoration(
            color: Color(0xCC081620),
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
                showSubtitle: false,
                onTap: () => onSelected(CbrPage.executor),
              ),
              if (!compact) ...[
                const SizedBox(width: 20),
                Expanded(child: _nav(medium)),
                const SizedBox(width: 8),
              ] else
                const Spacer(),
              _UpdateBadge(upstream: upstream, onTap: onCheckUpdates),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.tune_rounded, size: 19, color: CbrColors.textMuted),
                tooltip: 'Preferências',
              ),
              if (!compact)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: CbrColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: CbrColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.memory_rounded, size: 13, color: CbrColors.greenBright),
                      const SizedBox(width: 6),
                      Text(
                        UpstreamService.languageVersion,
                        style: CbrTextStyles.mono.copyWith(
                          fontSize: 10.5,
                          color: CbrColors.textMuted,
                        ),
                      ),
                    ],
                  ),
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

/// Aviso discreto quando o repositório oficial da linguagem tem um commit
/// mais novo do que o build atual.
class _UpdateBadge extends StatefulWidget {
  const _UpdateBadge({required this.upstream, required this.onTap});

  final UpstreamService upstream;
  final Future<void> Function() onTap;

  @override
  State<_UpdateBadge> createState() => _UpdateBadgeState();
}

class _UpdateBadgeState extends State<_UpdateBadge> {
  @override
  void initState() {
    super.initState();
    widget.upstream.addListener(_changed);
  }

  @override
  void dispose() {
    widget.upstream.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.upstream.state.hasUpdate) return const SizedBox.shrink();
    final latest = widget.upstream.state.latest;
    return Tooltip(
      message: 'Nova versão da linguagem disponível'
          '${latest == null ? '' : ' (${latest.shortSha})'}',
      child: InkWell(
        onTap: () => widget.onTap(),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: CbrColors.yellow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: CbrColors.yellow.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.new_releases_outlined, size: 13, color: CbrColors.yellow),
              const SizedBox(width: 6),
              Text(
                'atualização',
                style: CbrTextStyles.label.copyWith(
                  fontSize: 10,
                  color: CbrColors.yellowSoft,
                ),
              ),
            ],
          ),
        ),
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
  const _Drawer({
    required this.current,
    required this.onSelected,
    required this.upstream,
  });

  final CbrPage current;
  final ValueChanged<CbrPage> onSelected;
  final UpstreamService upstream;

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
                showSubtitle: true,
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
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'C Brasil (CBR)\n${UpstreamService.languageVersion} • Flutter',
                style: CbrTextStyles.label.copyWith(fontSize: 10.5, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onSelected});

  final ValueChanged<CbrPage> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return Row(
            children: [
              const Icon(Icons.circle, size: 6, color: CbrColors.green),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  compact
                      ? 'Execução local • sem servidor'
                      : 'C Brasil (CBR) • execução local, sem servidor • linguagem em github.com/vorgweb/C-Brasil',
                  overflow: TextOverflow.ellipsis,
                  style: CbrTextStyles.label.copyWith(fontSize: 10.5),
                ),
              ),
              const Spacer(),
              if (!compact) ...[
                _FooterLink(
                  label: 'Linguagem',
                  onTap: () => PlatformService.openUrl('https://github.com/vorgweb/C-Brasil'),
                ),
                _FooterLink(
                  label: 'GitHub',
                  onTap: () =>
                      PlatformService.openUrl('https://github.com/Veexdevs/C-Brasil-Executor'),
                ),
                _FooterLink(
                  label: 'Sobre',
                  onTap: () => onSelected(CbrPage.sobre),
                ),
              ] else
                _FooterLink(label: 'Sobre', onTap: () => onSelected(CbrPage.sobre)),
            ],
          );
        },
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: CbrTextStyles.label.copyWith(
            fontSize: 10.5,
            color: CbrColors.textMuted,
          ),
        ),
      ),
    );
  }
}
