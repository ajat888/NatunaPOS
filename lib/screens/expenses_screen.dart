import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/breakpoints.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../models/expense_item.dart';
import '../services/app_settings.dart';
import '../services/expense_service.dart';
import '../widgets/common/main_menu_scope.dart';

part 'expenses/expense_input_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => ExpensesScreenState();
}

class ExpensesScreenState extends State<ExpensesScreen> {
  final _service = ExpenseService.instance;
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    reloadData();
  }

  Future<void> reloadData() async {
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final list = await _service.getLocalExpenses();
      if (!mounted) return;
      setState(() {
        _expenses = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data pengeluaran.';
      });
    }
  }

  Future<void> _showInputDialog() async {
    final items = await _service.getLocalExpenseItemsForInput();
    final categories = await _service.getLocalExpenseCategories();
    if (items.isEmpty || categories.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tambahkan Kategori & Item di menu Kelola terlebih dahulu.'),
        backgroundColor: AppTheme.dangerColor,
      ));
      return;
    }

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExpenseInputDialog(
        categories: categories,
        items: items,
        cashierName: AppSettings.instance.cashierName.value.isEmpty 
            ? 'Kasir' 
            : AppSettings.instance.cashierName.value,
      ),
    );
    if (result == true) await reloadData();
  }

  Future<void> _voidExpense(Expense exp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Void Pengeluaran'),
        content: Text('Yakin ingin membatalkan pengeluaran "${exp.itemName}" sebesar Rp ${NumberFormat.decimalPattern('id').format(exp.amount)}?\nData tidak akan dihapus permanen (audit).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BATAL')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('VOID')),
        ],
      ),
    );
    if (confirm != true) return;

    await _service.voidExpense(exp.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengeluaran di-void'), backgroundColor: Colors.green));
    await reloadData();
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenuScope.of(context)?.openMenu(),
        ),
        title: const Text('Pengeluaran'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: reloadData, tooltip: 'Muat ulang'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppTheme.dangerColor)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: reloadData, child: const Text('Coba Lagi'))
                    ]))
              : _expenses.isEmpty
                  ? const Center(child: Text('Belum ada pengeluaran.', style: TextStyle(color: AppTheme.textLightColor)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final exp = _expenses[index];
                        return Container(
                          decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(exp.itemName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor)),
                                ),
                                Text('- Rp ${formatCurrency.format(exp.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dangerColor)),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${exp.categoryName} • ${dateFormat.format(exp.createdAt)} • oleh: ${exp.createdBy}', style: const TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
                                  if (exp.description != null && exp.description!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('"${exp.description}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textLightColor)),
                                    ),
                                ],
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.cancel_outlined, color: AppTheme.dangerColor, size: 20),
                              onPressed: () => _voidExpense(exp),
                              tooltip: 'Void',
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onPressed: _showInputDialog,
        icon: const Icon(Icons.add),
        label: const Text('Catat Pengeluaran'),
      ),
    );
  }
}