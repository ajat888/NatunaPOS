part of '../kelola_screen.dart';

class _CategoriesTab extends StatelessWidget {
  final KelolaScreenState state;
  const _CategoriesTab({required this.state});

  Future<void> _showCategoryDialog(BuildContext context, {Category? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryDialog(existing: existing, service: state._service),
    );
    if (result == true) await state.reloadData();
  }

  Future<void> _confirmDeleteCategory(BuildContext context, Category category) async {
    final isRestoring = state._showInactiveCategories;
    final title = isRestoring ? 'Aktifkan Kategori' : 'Nonaktifkan Kategori';
    final content = isRestoring
        ? 'Yakin ingin mengaktifkan kembali "${category.name}"?'
        : 'Yakin ingin menonaktifkan "${category.name}"?\nProduk di kategori ini akan menjadi Tanpa Kategori.';
    final confirmText = isRestoring ? 'AKTIFKAN' : 'NONAKTIFKAN';
    final btnColor = isRestoring ? Colors.green : AppTheme.dangerColor;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: btnColor),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText)),
        ],
      ),
    );
    if (confirmed != true) return;

    if (isRestoring) {
      await state._service.restoreCategory(category.id);
    } else {
      await state._service.deleteCategory(category.id);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isRestoring ? 'Kategori diaktifkan kembali' : 'Kategori dinonaktifkan'),
        backgroundColor: Colors.green));
    await state.reloadData();
  }

  @override
  Widget build(BuildContext context) {
    final baseCategories = state._showInactiveCategories ? state._inactiveCategories : state._categories;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () => state.setState(() {
                      state._showInactiveCategories = !state._showInactiveCategories;
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: state._showInactiveCategories ? AppTheme.dangerColor.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: state._showInactiveCategories ? AppTheme.dangerColor : AppTheme.primaryColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(state._showInactiveCategories ? Icons.visibility_off : Icons.visibility, size: 14, color: state._showInactiveCategories ? AppTheme.dangerColor : AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            state._showInactiveCategories ? 'Nonaktif' : 'Aktif',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: state._showInactiveCategories ? AppTheme.dangerColor : AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: baseCategories.isEmpty
                  ? Center(
                      child: Text(
                          state._showInactiveCategories
                              ? 'Tidak ada kategori nonaktif.'
                              : 'Belum ada kategori. Tambahkan kategori pertama Anda.',
                          style: const TextStyle(color: AppTheme.textLightColor)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      itemCount: baseCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final category = baseCategories[index];
                        final count = state._products.where((p) => p.categoryId == category.id).length;
                        return Container(
                          decoration: BoxDecoration(
                              color: state._showInactiveCategories ? Colors.grey.shade100 : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(category.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: state._showInactiveCategories ? AppTheme.textLightColor : AppTheme.textColor)),
                            subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('$count produk',
                                    style: const TextStyle(color: AppTheme.textLightColor, fontSize: 13))),
                            trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!state._showInactiveCategories)
                                    IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                                        onPressed: () => _showCategoryDialog(context, existing: category),
                                        tooltip: 'Edit'),
                                  IconButton(
                                      icon: Icon(state._showInactiveCategories ? Icons.restore : Icons.delete_outline,
                                          color: state._showInactiveCategories ? Colors.green : AppTheme.dangerColor),
                                      onPressed: () => _confirmDeleteCategory(context, category),
                                      tooltip: state._showInactiveCategories ? 'Aktifkan' : 'Nonaktifkan'),
                                ]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        if (!state._showInactiveCategories)
          Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onPressed: () => _showCategoryDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Kategori'))),
      ],
    );
  }
}