import 'package:flutter/material.dart';

import '../data/examples.dart';
import '../theme/cbr_theme.dart';
import '../widgets/cbr_panel.dart';
import '../widgets/highlighted_text.dart';

/// Galeria de exemplos prontos.
class ExamplesPage extends StatefulWidget {
  const ExamplesPage({super.key, required this.onLoadExample});

  final void Function(CbrExample example) onLoadExample;

  @override
  State<ExamplesPage> createState() => _ExamplesPageState();
}

class _ExamplesPageState extends State<ExamplesPage> {
  CbrDialect? _filter;

  List<CbrExample> get _visible => _filter == null
      ? cbrExamples
      : cbrExamples.where((example) => example.dialect == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.widgets_outlined, color: CbrColors.yellow, size: 22),
              const SizedBox(width: 10),
              Text('Exemplos', style: CbrTextStyles.headline.copyWith(fontSize: 26)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('Todos', null),
              for (final dialect in CbrDialect.values)
                _filterChip(dialect.label, dialect),
            ],
          ),
          const SizedBox(height: 18),
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
                itemCount: _visible.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 318,
                ),
                itemBuilder: (context, index) => _card(_visible[index]),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _filterChip(String label, CbrDialect? dialect) {
    final selected = _filter == dialect;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _filter = dialect),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? CbrColors.green.withValues(alpha: 0.14) : CbrColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? CbrColors.green.withValues(alpha: 0.5) : CbrColors.border,
          ),
        ),
        child: Text(
          label,
          style: CbrTextStyles.body.copyWith(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? CbrColors.greenBright : CbrColors.textMuted,
          ),
        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        example.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CbrTextStyles.title.copyWith(fontSize: 14.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CbrChip(
                      label: example.dialect.label,
                      color: example.dialect == CbrDialect.didatico
                          ? CbrColors.green
                          : CbrColors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  example.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CbrTextStyles.bodyMuted.copyWith(fontSize: 12),
                ),
              ],
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
                    child: Icon(Icons.keyboard_rounded,
                        size: 15, color: CbrColors.yellow),
                  )
                else
                  Icon(Icons.terminal_rounded,
                      size: 15, color: CbrColors.textFaint),
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
                  onPressed: () => widget.onLoadExample(example),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
