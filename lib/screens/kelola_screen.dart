import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/expense_category.dart';
import '../models/expense_item.dart';
import '../services/supabase_service.dart';
import '../services/expense_service.dart';
import '../widgets/common/main_menu_scope.dart';
import '../widgets/common/thousand_formatter.dart';
import '../widgets/common/title_case_formatter.dart';

part 'kelola/products_tab.dart';
part 'kelola/categories_tab.dart';
part 'kelola/expense_categories_tab.dart';
part 'kelola/product_dialog.dart';
part 'kelola/category_dialog.dart';
part 'kelola/product_card.dart';
part 'kelola/expense_dialogs.dart';
part 'kelola/expense_items_screen.dart';

class KelolaScreen extends StatefulWidget {
  const KelolaScreen({super.key});

  @override
  State<KelolaScreen> createState() => KelolaScreenState();
}

class KelolaScreenState extends State<KelolaScreen>
    with SingleTickerProviderStateMixin {
  final _service = SupabaseService();
  final _expenseService = ExpenseService.instance;
  late final TabController _tabController;

  List<Product> _products = [];
  List<Product> _inactiveProducts = [];
  List<Category> _categories = [];
  List<Category> _inactiveCategories = [];

  List<ExpenseCategory> _expenseCategories = [];
  List<ExpenseItem> _expenseItems = [];

  int? _filterCategoryId;
  bool _showInactive = false;
  bool _showInactiveCategories = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    reloadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void toggleShowInactive() {
    setState(() {
      _showInactive = !_showInactive;
      _filterCategoryId = null;
    });
  }

  void toggleShowInactiveCategories() {
    setState(() {
      _showInactiveCategories = !_showInactiveCategories;
    });
  }

  void setFilterCategory(int? id) {
    setState(() {
      _filterCategoryId = id;
    });
  }

Future<void> reloadData() async {
  if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

  try {
    final products = await _service.getLocalProducts();
    final inactiveProducts = await _service.getLocalInactiveProducts();
    final categories = await _service.getLocalCategories();
    final inactiveCategories = await _service.getLocalInactiveCategories();

    final expCats = await _expenseService.getLocalExpenseCategories();
    final expItems = await _expenseService.getLocalExpenseItems();

    if (!mounted) return;

    final base = _showInactive ? inactiveProducts : products;
    if (_filterCategoryId != null && _filterCategoryId != -1) {
      final hasCat = categories.any((c) => c.id == _filterCategoryId) &&
                     base.any((p) => p.categoryId == _filterCategoryId);
      if (!hasCat) _filterCategoryId = null;
    }

    setState(() {
      _products = products;
      _inactiveProducts = inactiveProducts;
      _categories = categories;
      _inactiveCategories = inactiveCategories;
      _expenseCategories = expCats;
      _expenseItems = expItems;
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = 'Gagal memuat data lokal.';
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenuScope.of(context)?.openMenu(),
        ),
        title: const Text('Kelola Data'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: reloadData,
              tooltip: 'Muat ulang')
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textLightColor,
          indicatorColor: AppTheme.primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [
            Tab(text: 'PRODUK'),
            Tab(text: 'KATEGORI'),
            Tab(text: 'PENGELUARAN'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: AppTheme.dangerColor)),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: reloadData,
                          child: const Text('Coba Lagi'))
                    ]))
              : TabBarView(controller: _tabController, children: [
                  _ProductsTab(state: this),
                  _CategoriesTab(state: this),
                  _ExpenseCategoriesTab(state: this),
                ]),
    );
  }
}