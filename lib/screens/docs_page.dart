import 'package:flutter/material.dart';

import '../data/language_reference.dart';
import '../theme/cbr_theme.dart';
import '../widgets/cbr_panel.dart';
import '../widgets/highlighted_text.dart';

/// Documentação da linguagem, com índice lateral e exemplos executáveis.
class DocsPage extends StatefulWidget {
  const DocsPage({super.key, this.onTryCode});

  final void Function(String code)? onTryCode;

  @override
  State<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends State<DocsPage> {
  final Map<String, GlobalKey> _sectionKeys = {
    for (final section in cbrDocumentation) section.id: GlobalKey(),
  };

  String _active = cbrDocumentation.first.id;

  void _jumpTo(String id) {
    setState(() => _active = id);
    final context = _sectionKeys[id]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1020;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide) ...[
              SizedBox(width: 236, child: _index(wide: true)),
              const SizedBox(width: 24),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    if (!wide) ...[
                      const SizedBox(height: 16),
                      _index(wide: false),
                    ],
                    const SizedBox(height: 20),
                    for (final section in cbrDocumentation)
                      Padding(
                        key: _sectionKeys[section.id],
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _sectionCard(section),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        Text('Documentação', style: CbrTextStyles.headline.copyWith(fontSize: 26)),
      ],
    );
  }

  Widget _index({required bool wide}) {
    final items = [
      for (final section in cbrDocumentation)
        _indexItem(section.id, section.title, section.icon, wide),
    ];
    if (!wide) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [for (final item in items) Padding(
          padding: const EdgeInsets.only(right: 8),
          child: item,
        )]),
      );
    }
    return CbrPanel(
      padding: const EdgeInsets.all(10),
      color: CbrColors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Text('Nesta página', style: CbrTextStyles.label),
          ),
          for (final section in cbrDocumentation)
            _indexItem(section.id, section.title, section.icon, true),
        ],
      ),
    );
  }

  Widget _indexItem(String id, String title, IconData icon, bool wide) {
    final selected = _active == id;
    return Padding(
      padding: EdgeInsets.only(bottom: wide ? 2 : 0),
      child: InkWell(
        onTap: () => _jumpTo(id),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: wide ? 10 : 12, vertical: wide ? 8 : 9),
          decoration: BoxDecoration(
            color: selected ? CbrColors.green.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? CbrColors.green.withValues(alpha: 0.4)
                  : (wide ? Colors.transparent : CbrColors.border),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: CbrTextStyles.body.copyWith(
                    fontSize: wide ? 12.5 : 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? CbrColors.text : CbrColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(DocSection section) {
    return CbrPanel(
      padding: const EdgeInsets.all(20),
      color: CbrColors.surface.withValues(alpha: 0.65),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CbrColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: CbrColors.green.withValues(alpha: 0.25)),
                ),
                child: Icon(section.icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  section.title,
                  overflow: TextOverflow.ellipsis,
                  style: CbrTextStyles.title.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final block in section.blocks) ...[
            _block(block),
            const SizedBox(height: 12),
          ],
          if (section.id == 'biblioteca') _builtinSection(),
        ],
      ),
    );
  }

  Widget _builtinSection() {
    final tables = builtinTables();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final table in tables) ...[
          _table(table),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _block(DocBlock block) {
    switch (block) {
      case DocParagraph(:final text):
        return Text(text, style: CbrTextStyles.body.copyWith(color: CbrColors.textMuted));
      case DocBullets(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7, right: 10),
                      child: Icon(Icons.circle, size: 5, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: CbrTextStyles.body.copyWith(color: CbrColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case DocCode(:final code, :final caption):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CodeBlock(code, title: caption, fontSize: 12.5),
            if (widget.onTryCode != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => widget.onTryCode!(code),
                  icon: const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
                  label: const Text('Testar este exemplo'),
                  style: TextButton.styleFrom(
                    foregroundColor: CbrColors.greenBright,
                    textStyle: const TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
          ],
        );
      case DocTable():
        return _table(block);
    }
  }

  Widget _table(DocTable table) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(table.title.toUpperCase(), style: CbrTextStyles.label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: CbrColors.backgroundDeep,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CbrColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: CbrColors.surfaceAlt,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(table.first, style: CbrTextStyles.label),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text(table.second, style: CbrTextStyles.label),
                    ),
                  ],
                ),
              ),
              for (var index = 0; index < table.rows.length; index++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    border: index == 0
                        ? null
                        : const Border(top: BorderSide(color: CbrColors.border, width: 0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: SelectableText(
                          table.rows[index].name,
                          style: CbrTextStyles.mono.copyWith(
                            fontSize: 11.5,
                            color: CbrColors.greenBright,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Text(
                          table.rows[index].description,
                          style: CbrTextStyles.body.copyWith(
                            fontSize: 12.5,
                            color: CbrColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

}
