part of '../expenses_screen.dart';

class _ExpenseInputDialog extends StatefulWidget {
  final List<ExpenseCategory> categories;
  final List<ExpenseItem> items;
  final String cashierName;

  const _ExpenseInputDialog({
    required this.categories,
    required this.items,
    required this.cashierName,
  });

  @override
  State<_ExpenseInputDialog> createState() => _ExpenseInputDialogState();
}

class _ExpenseInputDialogState extends State<_ExpenseInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  
  int? _selectedCategoryId;
  int? _selectedItemId;
  bool _isSaving = false;
  String? _errorMessage;

  List<ExpenseItem> get _filteredItems {
    if (_selectedCategoryId == null) return [];
    return widget.items.where((i) => i.categoryId == _selectedCategoryId).toList();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItemId == null) {
      setState(() => _errorMessage = 'Pilih item pengeluaran');
      return;
    }

    setState(() { _isSaving = true; _errorMessage = null; });
    try {
      final amount = int.parse(_amountController.text.replaceAll('.', '').trim());
      final item = widget.items.firstWhere((i) => i.id == _selectedItemId);
      final category = widget.categories.firstWhere((c) => c.id == _selectedCategoryId);

      await ExpenseService.instance.createExpense(
        categoryId: category.id,
        categoryName: category.name,
        itemId: item.id,
        itemName: item.name,
        amount: amount,
        description: _descController.text,
        createdBy: widget.cashierName,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Catat Pengeluaran'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.dangerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.dangerColor, fontSize: 12))),
                const SizedBox(height: 12),
              ],
              TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandFormatter()],
                  decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp '),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nominal wajib diisi';
                    final n = int.tryParse(v.trim().replaceAll('.', ''));
                    if (n == null || n <= 0) return 'Nominal tidak valid';
                    return null;
                  }),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Kategori (mis. Dapur)'),
                items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = val;
                    _selectedItemId = null;
                  });
                },
                validator: (v) => v == null ? 'Pilih kategori' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedItemId,
                decoration: const InputDecoration(labelText: 'Item (mis. Beras)'),
                items: _filteredItems.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
                onChanged: _selectedCategoryId == null ? null : (val) {
                  setState(() => _selectedItemId = val);
                },
                validator: (v) => v == null ? 'Pilih item' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Keterangan (opsional)'),
                  maxLines: 2,
                  minLines: 1,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context, false), child: const Text('BATAL')),
        ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('SIMPAN')),
      ],
    );
  }
}