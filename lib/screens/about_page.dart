import 'package:flutter/material.dart';

import '../services/platform_service.dart';
import '../services/upstream_service.dart';
import '../theme/cbr_theme.dart';
import '../widgets/cbr_logo.dart';
import '../widgets/cbr_panel.dart';
import '../widgets/highlighted_text.dart';

/// Tela "Sobre": marca, envio para a Vercel, estado do upstream e privacidade.
class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    required this.upstream,
    required this.onCheckUpdates,
    required this.onReload,
  });

  final UpstreamService upstream;
  final Future<void> Function() onCheckUpdates;
  final VoidCallback onReload;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hero(),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final cards = [
                _upstreamCard(),
                _platformCard(),
                _privacyCard(),
              ];
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      if (index > 0) const SizedBox(width: 16),
                      Expanded(child: cards[index]),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          _changelog(),
          const SizedBox(height: 18),
          _links(),
        ],
      ),
    );
  }

  Widget _hero() {
    return CbrPanel(
      padding: const EdgeInsets.all(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0C2A24), Color(0xFF0A1D2A), Color(0xFF08161F)],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'C Brasil',
                    style: CbrTextStyles.headline.copyWith(fontSize: wide ? 30 : 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(CBR)',
                    style: CbrTextStyles.mono.copyWith(
                      fontSize: wide ? 16 : 13,
                      color: CbrColors.greenBright,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Um ambiente completo para escrever, executar e aprender a '
                'linguagem C Brasil — no navegador, no celular e no computador.',
                style: CbrTextStyles.bodyMuted.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  CbrChip(label: 'Verde • Amarelo • Azul', color: CbrColors.green),
                  CbrChip(label: 'Flutter + Dart', color: CbrColors.blue),
                  CbrChip(label: 'Open source', color: CbrColors.yellow),
                ],
              ),
            ],
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CbrLogo(size: 64, glow: true),
                const SizedBox(height: 16),
                text,
              ],
            );
          }
          return Row(
            children: [
              const CbrLogo(size: 84, glow: true),
              const SizedBox(width: 22),
              Expanded(child: text),
            ],
          );
        },
      ),
    );
  }

  Widget _upstreamCard() {
    final state = widget.upstream.state;
    final latest = state.latest;
    final hasUpdate = state.hasUpdate;
    return CbrPanel(
      padding: const EdgeInsets.all(18),
      color: CbrColors.surface.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_rounded, size: 17, color: CbrColors.blue),
              const SizedBox(width: 9),
              Text('Linguagem oficial', style: CbrTextStyles.title.copyWith(fontSize: 14)),
              const Spacer(),
              _statusDot(state),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            UpstreamService.repository,
            style: CbrTextStyles.mono.copyWith(fontSize: 12.5, color: CbrColors.greenBright),
          ),
          const SizedBox(height: 10),
          _row('Versão da linguagem', UpstreamService.languageVersion),
          _row('Compilado com', UpstreamService.compiledShort),
          _row(
            'Último commit',
            latest == null ? '—' : '${latest.shortSha} · ${latest.message}',
            maxLines: 2,
          ),
          _row(
            'Verificado',
            state.checkedAt == null ? '—' : _time(state.checkedAt!),
          ),
          const SizedBox(height: 12),
          if (hasUpdate)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CbrColors.yellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: CbrColors.yellow.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.new_releases_outlined, size: 15, color: CbrColors.yellow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Há uma atualização no repositório da linguagem. Recarregue '
                      'para usar a versão mais recente do executor.',
                      style: CbrTextStyles.body.copyWith(
                        fontSize: 11.5,
                        color: CbrColors.yellowSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              CbrButton(
                label: 'Verificar',
                icon: Icons.refresh_rounded,
                variant: CbrButtonVariant.secondary,
                compact: true,
                busy: state.checking,
                onPressed: state.checking ? null : () => widget.onCheckUpdates(),
              ),
              const SizedBox(width: 8),
              CbrButton(
                label: 'Recarregar',
                icon: Icons.restart_alt_rounded,
                variant: CbrButtonVariant.ghost,
                compact: false,
                onPressed: PlatformService.canReload ? widget.onReload : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusDot(UpstreamState state) {
    final (color, label) = state.checking
        ? (CbrColors.blue, 'verificando')
        : state.online
            ? (CbrColors.green, 'online')
            : (CbrColors.red, 'offline');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: CbrTextStyles.label.copyWith(color: color, fontSize: 10),
        ),
      ],
    );
  }

  Widget _platformCard() {
    return CbrPanel(
      padding: const EdgeInsets.all(18),
      color: CbrColors.surface.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices_rounded, size: 17, color: CbrColors.greenBright),
              const SizedBox(width: 9),
              Text('Plataformas', style: CbrTextStyles.title.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _platformRow(Icons.language_rounded, 'Web', 'Chrome, Edge, Firefox, Safari'),
          _platformRow(Icons.android_rounded, 'Android', 'APK universal'),
          _platformRow(Icons.phone_iphone_rounded, 'iOS', 'IPA / App Store'),
          _platformRow(Icons.desktop_windows_rounded, 'Windows', 'Executável .exe'),
          _platformRow(Icons.laptop_mac_rounded, 'macOS', 'App universal'),
          _platformRow(Icons.computer_rounded, 'Linux', 'AppImage e tar.gz'),
          const SizedBox(height: 10),
          Text(
            'Todos os builds usam o mesmo código Dart/Flutter — a linguagem é '
            'interpretada localmente, sem servidor.',
            style: CbrTextStyles.bodyMuted.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _platformRow(IconData icon, String name, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 14, color: CbrColors.textMuted),
          const SizedBox(width: 9),
          SizedBox(
            width: 66,
            child: Text(
              name,
              style: CbrTextStyles.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              detail,
              overflow: TextOverflow.ellipsis,
              style: CbrTextStyles.bodyMuted.copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyCard() {
    return CbrPanel(
      padding: const EdgeInsets.all(18),
      color: CbrColors.surface.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 17, color: CbrColors.yellow),
              const SizedBox(width: 9),
              Text('Privacidade', style: CbrTextStyles.title.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in const [
            'Seu código nunca sai do dispositivo: o interpretador roda no próprio app.',
            'Nada de contas, login ou telemetria.',
            'O programa fica salvo apenas no armazenamento local do navegador ou do aparelho.',
            'A única conexão externa é a consulta pública ao GitHub para checar atualizações da linguagem.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 9),
                    child: Icon(Icons.circle, size: 5, color: CbrColors.green),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: CbrTextStyles.bodyMuted.copyWith(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _changelog() {
    final changelog = widget.upstream.changelog;
    if (changelog == null || changelog.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return CbrPanel(
      padding: const EdgeInsets.all(18),
      color: CbrColors.surface.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 17, color: CbrColors.blue),
              const SizedBox(width: 9),
              Text('Notas de versão da linguagem',
                  style: CbrTextStyles.title.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: CodeBlock(
                changelog,
                title: 'CHANGELOG.md',
                fontSize: 11.5,
                showCopy: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _links() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _linkChip(
          'Repositório da linguagem',
          'https://github.com/vorgweb/C-Brasil',
          Icons.code_rounded,
        ),
        _linkChip(
          'Executor no GitHub',
          'https://github.com/Veexdevs/C-Brasil-Executor',
          Icons.folder_copy_outlined,
        ),
        _linkChip(
          'Site publicado',
          'https://c-brasil-executor.vercel.app/',
          Icons.public_rounded,
        ),
      ],
    );
  }

  Widget _linkChip(String label, String url, IconData icon) {
    return InkWell(
      onTap: () => PlatformService.openUrl(url),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: CbrColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: CbrColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: CbrColors.greenBright),
            const SizedBox(width: 8),
            Text(label, style: CbrTextStyles.body.copyWith(fontSize: 12.5)),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded, size: 12, color: CbrColors.textFaint),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(label, style: CbrTextStyles.label.copyWith(fontSize: 10.5)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: CbrTextStyles.body.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
