import 'package:flutter/material.dart';

import '../data/examples.dart';
import '../theme/cbr_theme.dart';
import '../widgets/cbr_panel.dart';
import '../widgets/highlighted_text.dart';

/// Galeria de exemplos prontos.
class ExamplesPage extends StatelessWidget {
  const ExamplesPage({super.key, required this.onLoadExample});

  final void Function(CbrExample example) onLoadExample;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.widgets_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text('Exemplos', style: CbrTextStyles.headline.copyWith(fontSize: 26)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1240
                  ? 3
                  : constraints.maxWidth >= 820
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cbrExamples.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 318,
                ),
                itemBuilder: (context, index) => _card(cbrExamples[index]),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _card(CbrExample example) {
    final code = example.code.split('\n').take(11).join('\n');
    return CbrPanel(
      padding: EdgeInsets.zero,
      color: CbrColors.surface,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              example.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CbrTextStyles.title.copyWith(fontSize: 14.5),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: CbrColors.backgroundDeep,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CbrColors.border.withValues(alpha: 0.8)),
              ),
              child: ClipRect(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text.rich(
                    buildHighlightedSpan(code, fontSize: 10.5, height: 1.5),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                if (example.usesInput)
                  const Tooltip(
                    message: 'O programa pede uma entrada',
                    child: Icon(
                      Icons.keyboard_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.terminal_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    example.filename,
                    overflow: TextOverflow.ellipsis,
                    style: CbrTextStyles.mono.copyWith(
                      fontSize: 10.5,
                      color: CbrColors.textFaint,
                    ),
                  ),
                ),
                CbrButton(
                  label: 'Abrir no editor',
                  icon: Icons.edit_note_rounded,
                  variant: CbrButtonVariant.secondary,
                  compact: false,
                  onPressed: () => onLoadExample(example),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
