part of '../kelola_screen.dart';

class _ExpenseItemsScreen extends StatefulWidget {
  final ExpenseCategory category;
  final List<ExpenseItem> items;
  final ExpenseService service;

  const _ExpenseItemsScreen({required this.category, required this.items, required this.service});

  @override
  State<_ExpenseItemsScreen> createState() => _ExpenseItemsScreenState();
}

class _ExpenseItemsScreenState extends State<_ExpenseItemsScreen> {
  late List<ExpenseItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  Future<void> _reload() async {
    final allItems = await widget.service.getLocalExpenseItems();
    if (!mounted) return;
    setState(() {
      _items = allItems.where((i) => i.categoryId == widget.category.id).toList();
    });
  }

  Future<void> _showItemDialog({ExpenseItem? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExpenseItemDialog(
        categoryId: widget.category.id,
        existing: existing,
        service: widget.service,
      ),
    );
    if (result == true) await _reload();
  }

  Future<void> _confirmDelete(ExpenseItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Hapus Item'),
        content: Text('Yakin ingin menonaktifkan "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BATAL')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('NONAKTIFKAN')),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.service.deleteExpenseItem(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item dinonaktifkan'), backgroundColor: Colors.green));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('Belum ada item.', style: TextStyle(color: AppTheme.textLightColor)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: ListTile(
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                            onPressed: () => _showItemDialog(existing: item)),
                        IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
                            onPressed: () => _confirmDelete(item)),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemDialog(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Item'),
      ),
    );
  }
}