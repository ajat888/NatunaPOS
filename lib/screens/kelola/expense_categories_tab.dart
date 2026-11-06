part of '../kelola_screen.dart';

class _ExpenseCategoriesTab extends StatelessWidget {
  final KelolaScreenState state;
  const _ExpenseCategoriesTab({required this.state});

  Future<void> _showCategoryDialog(BuildContext context, {ExpenseCategory? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExpenseCategoryDialog(existing: existing, service: state._expenseService),
    );
    if (result == true) await state.reloadData();
  }

  Future<void> _confirmDeleteCategory(BuildContext context, ExpenseCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Nonaktifkan Kategori'),
        content: Text('Yakin ingin menonaktifkan "${category.name}"?\nItem di bawah kategori ini juga tidak akan muncul saat input.'),
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

    await state._expenseService.deleteExpenseCategory(category.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori pengeluaran dinonaktifkan'), backgroundColor: Colors.green));
    await state.reloadData();
  }

  @override
  Widget build(BuildContext context) {
    final categories = state._expenseCategories;

    return Stack(
      children: [
        categories.isEmpty
            ? const Center(
                child: Text('Belum ada kategori pengeluaran.', style: TextStyle(color: AppTheme.textLightColor)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final count = state._expenseItems.where((i) => i.categoryId == category.id).length;
                  return Container(
                    decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _ExpenseItemsScreen(
                              category: category,
                              items: state._expenseItems.where((i) => i.categoryId == category.id).toList(),
                              service: state._expenseService,
                            ),
                          ),
                        ).then((_) => state.reloadData());
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textColor)),
                      subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('$count item', style: const TextStyle(color: AppTheme.textLightColor, fontSize: 13))),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                                onPressed: () => _showCategoryDialog(context, existing: category),
                                tooltip: 'Edit'),
                            IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
                                onPressed: () => _confirmDeleteCategory(context, category),
                                tooltip: 'Nonaktifkan'),
                          ]),
                    ),
                  );
                },
              ),
        Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onPressed: () => _showCategoryDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Kategori Baru'))),
      ],
    );
  }
}