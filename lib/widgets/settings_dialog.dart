import 'package:flutter/material.dart';

import '../services/platform_service.dart';
import '../state/executor_state.dart';
import '../theme/cbr_theme.dart';
import 'cbr_panel.dart';

/// Preferências do editor.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.state});

  final ExecutorState state;

  static Future<void> show(BuildContext context, ExecutorState state) {
    return showDialog<void>(
      context: context,
      builder: (_) => SettingsDialog(state: state),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double _fontSize = widget.state.fontSize;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      title: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 19, color: CbrColors.greenBright),
          const SizedBox(width: 10),
          Text('Preferências', style: CbrTextStyles.title.copyWith(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('Tamanho da fonte', style: CbrTextStyles.body),
                  const Spacer(),
                  CbrChip(label: '${_fontSize.round()} px', color: CbrColors.blue),
                ],
              ),
              Slider(
                value: _fontSize,
                min: 10,
                max: 24,
                divisions: 14,
                activeColor: CbrColors.green,
                inactiveColor: CbrColors.border,
                onChanged: (value) => setState(() => _fontSize = value),
                onChangeEnd: (value) => widget.state.setFontSize(value),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CbrColors.backgroundDeep,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CbrColors.border),
                ),
                child: Text(
                  'inicio\n    escreva("Olá, C Brasil!")\nfim',
                  style: CbrTextStyles.mono.copyWith(fontSize: _fontSize),
                ),
              ),
              const SizedBox(height: 18),
              Text('Execução', style: CbrTextStyles.label),
              const SizedBox(height: 8),
              _infoRow('Limite de instruções', '4 000 000'),
              _infoRow('Limite de tempo', '20 segundos'),
              const SizedBox(height: 18),
              Text('Dados locais', style: CbrTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'O programa atual fica salvo no aparelho e reaparece na '
                      'próxima vez que você abrir o executor.',
                      style: CbrTextStyles.bodyMuted.copyWith(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CbrButton(
                    label: 'Restaurar exemplo inicial',
                    icon: Icons.restore_rounded,
                    variant: CbrButtonVariant.secondary,
                    compact: false,
                    onPressed: () {
                      widget.state.newProgram();
                      Navigator.of(context).pop();
                    },
                  ),
                  if (PlatformService.canReload) ...[
                    const SizedBox(width: 8),
                    CbrButton(
                      label: 'Recarregar app',
                      icon: Icons.restart_alt_rounded,
                      variant: CbrButtonVariant.ghost,
                      compact: false,
                      onPressed: PlatformService.reloadApp,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: CbrTextStyles.bodyMuted.copyWith(fontSize: 12)),
          ),
          Text(
            value,
            style: CbrTextStyles.mono.copyWith(
              fontSize: 11.5,
              color: CbrColors.greenBright,
            ),
          ),
        ],
      ),
    );
  }
}
