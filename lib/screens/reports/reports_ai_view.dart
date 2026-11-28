part of '../reports_screen.dart';

class _AiAnalysisSheet extends StatelessWidget {
  final String analysis;
  final DateTime from;
  final DateTime to;
  final int transactionCount;
  const _AiAnalysisSheet({
    required this.analysis,
    required this.from,
    required this.to,
    required this.transactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle Bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Analisis AI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      tooltip: 'Salin teks',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: analysis));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Teks analisis disalin')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Periode: ${dateFmt.format(from)} — ${dateFmt.format(to)}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textLightColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (transactionCount < 5) ...[
                        const SizedBox(height: 8),
                        _dataWarning(transactionCount),
                      ],
                      const SizedBox(height: 12),
                      _AiMarkdownView(markdown: analysis),
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'Analisis ini dibuat otomatis oleh AI dari data laporan di atas. Angka utamanya tetap bisa Anda cek di layar Laporan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppTheme.textLightColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dataWarning(int count) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade800.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade800.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 0
                  ? 'Belum ada transaksi pada periode ini, jadi saran AI belum bisa dipakai.'
                  : 'Periode ini baru $count transaksi. Saran AI masih kasar; pilih 7 atau 30 hari untuk gambaran yang lebih stabil.',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textColor, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMarkdownView extends StatelessWidget {
  final String markdown;
  const _AiMarkdownView({required this.markdown});

  @override
  Widget build(BuildContext context) {
    final lines = markdown.split('\n');
    final children = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      if (line.startsWith('### ')) {
        children.add(_heading(line.substring(4).trim(), 15));
      } else if (line.startsWith('## ')) {
        children.add(_heading(line.substring(3).trim(), 17));
      } else if (line.startsWith('# ')) {
        children.add(_heading(line.substring(2).trim(), 19));
      } else if (line.trim() == '---' ||
          line.trim() == '***' ||
          line.trim() == '___') {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ));
      } else if (RegExp(r'^\s*[-*]\s+').hasMatch(line)) {
        final content = line.replaceFirst(RegExp(r'^\s*[-*]\s+'), '');
        children.add(_bullet(content, '•'));
      } else if (RegExp(r'^\s*\d+\.\s+').hasMatch(line)) {
        final m = RegExp(r'^\s*(\d+)\.\s+').firstMatch(line);
        final n = m?.group(1) ?? '1';
        final content = line.replaceFirst(RegExp(r'^\s*\d+\.\s+'), '');
        children.add(_bullet(content, '$n.'));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _richText(line),
        ));
      }
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _heading(String text, double size) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
      ),
    );
  }

  Widget _bullet(String text, String marker) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              marker,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: _richText(text)),
        ],
      ),
    );
  }

  Widget _richText(String text) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    int cursor = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(2),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.shade200,
          ),
        ));
      }
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textColor,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }
}