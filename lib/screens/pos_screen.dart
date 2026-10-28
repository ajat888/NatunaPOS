// lib/screens/pos_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/open_order.dart';
import '../core/local_db.dart';
import '../core/theme.dart';
import '../core/breakpoints.dart';
import '../widgets/common/main_menu_scope.dart';
import '../widgets/common/thousand_formatter.dart';

part 'pos/pos_table_view.dart';
part 'pos/pos_menu_picker.dart';
part 'pos/pos_order_detail.dart';
part 'pos/pos_payment_dialog.dart';

enum PosView { tables, menu, orderDetail }

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _service = SupabaseService();
  final _localDb = LocalDb.instance;

  PosView _view = PosView.tables;
  PosView _afterMenuView = PosView.tables;
  String? _activeOrderKey;
  String? _activeOrderType;
  int? _activeTableNumber;

  List<Product> _products = [];
  List<Category> _categories = [];
  List<OpenOrder> _openOrders = [];
  final Map<int, int> _cart = {};
  int? _filterCategoryId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final products = await _localDb.getProducts();
      final categories = await _localDb.getCategories();
      final openOrders = await _localDb.getOpenOrders();
      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = categories;
        _openOrders = openOrders;
        _isLoading = false;
      });
      _service.syncData().then((_) async {
        if (!mounted) return;
        try {
          final p = await _localDb.getProducts();
          final c = await _localDb.getCategories();
          final o = await _localDb.getOpenOrders();
          if (!mounted) return;
          setState(() {
            _products = p;
            _categories = c;
            _openOrders = o;
          });
        } catch (e) {
          debugPrint('Reload after sync failed: $e');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data lokal.';
      });
    }
  }

  Future<void> _reloadOpenOrders() async {
    final o = await _localDb.getOpenOrders();
    if (!mounted) return;
    setState(() => _openOrders = o);
  }

  OpenOrder? _findOrder(String key) {
    for (final o in _openOrders) {
      if (o.orderKey == key) return o;
    }
    return null;
  }

  Product? _findProduct(int id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _openEmptyTable(int tableNumber) {
    setState(() {
      _afterMenuView = PosView.tables;
      _view = PosView.menu;
      _activeOrderKey = 'M-${tableNumber.toString().padLeft(2, '0')}';
      _activeOrderType = 'dine_in';
      _activeTableNumber = tableNumber;
      _cart.clear();
      _filterCategoryId = null;
    });
  }

  Future<void> _openTakeAway() async {
    final key = await _localDb.nextTakeAwayKey();
    if (!mounted) return;
    setState(() {
      _afterMenuView = PosView.tables;
      _view = PosView.menu;
      _activeOrderKey = key;
      _activeOrderType = 'take_away';
      _activeTableNumber = null;
      _cart.clear();
      _filterCategoryId = null;
    });
  }

  void _openOrderDetail(OpenOrder order) {
    setState(() {
      _view = PosView.orderDetail;
      _activeOrderKey = order.orderKey;
      _activeOrderType = order.orderType;
      _activeTableNumber = order.tableNumber;
    });
  }

  void _startAddToExisting() {
    setState(() {
      _afterMenuView = PosView.orderDetail;
      _cart.clear();
      _filterCategoryId = null;
      _view = PosView.menu;
    });
  }

  void _backToTables() {
    setState(() {
      _view = PosView.tables;
      _activeOrderKey = null;
      _activeOrderType = null;
      _activeTableNumber = null;
      _cart.clear();
    });
  }

  void _addToCart(Product product) {
    setState(() => _cart[product.id] = (_cart[product.id] ?? 0) + 1);
  }

  void _removeFromCart(Product product) {
    setState(() {
      final qty = _cart[product.id] ?? 0;
      if (qty <= 1) {
        _cart.remove(product.id);
      } else {
        _cart[product.id] = qty - 1;
      }
    });
  }

  int get _cartTotal {
    int t = 0;
    _cart.forEach((id, qty) {
      final p = _findProduct(id);
      if (p != null) t += p.price * qty;
    });
    return t;
  }

  int get _cartItemCount {
    int t = 0;
    _cart.forEach((id, qty) {
      if (_findProduct(id) != null) t += qty;
    });
    return t;
  }

  Future<void> _promptSaveOrder() async {
    if (_cart.isEmpty) return;
    final target = _activeOrderType == 'take_away'
        ? '$_activeOrderKey'
        : 'Meja $_activeTableNumber';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Simpan Pesanan?'),
        content: Text('Simpan $_cartItemCount item ke $target?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('EDIT')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('YA')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _saveOrder();
  }

  Future<void> _saveOrder() async {
    if (_cart.isEmpty || _activeOrderKey == null) return;
    final lines = <OpenOrderLine>[];
    _cart.forEach((id, qty) {
      final p = _findProduct(id);
      if (p == null) return;
      lines.add(OpenOrderLine(
        productId: p.id,
        productName: p.name,
        price: p.price,
        hpp: p.hpp,
        qty: qty,
      ));
    });
    if (lines.isEmpty) return;
    final existing = _findOrder(_activeOrderKey!);
    if (existing == null) {
      await _localDb.createOpenOrder(
        orderKey: _activeOrderKey!,
        orderType: _activeOrderType!,
        tableNumber: _activeTableNumber,
        lines: lines,
      );
    } else {
      await _localDb.appendToOpenOrder(
        orderKey: _activeOrderKey!,
        lines: lines,
      );
    }
    await _reloadOpenOrders();
    if (!mounted) return;
    if (_afterMenuView == PosView.orderDetail) {
      final o = _findOrder(_activeOrderKey!);
      if (o != null) {
        _openOrderDetail(o);
        return;
      }
    }
    _backToTables();
  }

  void _showPaymentFor(OpenOrder order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        order: order,
        service: _service,
        onSuccess: () async {
          await _reloadOpenOrders();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pembayaran berhasil'),
            backgroundColor: Colors.green,
          ));
          _backToTables();
        },
      ),
    );
  }

  Future<void> _adjustOpenOrderItemQty(
      OpenOrder order, OpenOrderItem item, int delta) async {
    final newQty = item.qty + delta;
    await _localDb.updateOpenOrderItemQty(item.id, newQty);
    final updated = await _localDb.getOpenOrder(order.orderKey);
    if (updated != null && updated.items.isEmpty) {
      await _localDb.deleteOpenOrder(order.orderKey);
      await _reloadOpenOrders();
      if (!mounted) return;
      _backToTables();
      return;
    }
    await _reloadOpenOrders();
    if (!mounted) return;
    final refreshed = _findOrder(order.orderKey);
    if (refreshed != null) _openOrderDetail(refreshed);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!,
                  style: const TextStyle(color: AppTheme.dangerColor)),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadData, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    switch (_view) {
      case PosView.tables:
        return _buildTablesView();
      case PosView.menu:
        return _buildMenuView();
      case PosView.orderDetail:
        return _buildOrderDetailView();
    }
  }

  Widget _buildTablesView() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenuScope.of(context)?.openMenu(),
        ),
        title: const Text('Kasir'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Muat ulang'),
        ],
      ),
      body: _PosTablesView(
        openOrders: _openOrders,
        onTapEmptyTable: _openEmptyTable,
        onTapOpenOrder: _openOrderDetail,
        onTapTakeAway: _openTakeAway,
        onTapPay: _showPaymentFor,
      ),
    );
  }

  Widget _buildMenuView() {
    return _PosMenuPicker(
      products: _products,
      categories: _categories,
      cart: _cart,
      filterCategoryId: _filterCategoryId,
      onFilterChanged: (id) => setState(() => _filterCategoryId = id),
      onAdd: _addToCart,
      onRemove: _removeFromCart,
      cartTotal: _cartTotal,
      cartItemCount: _cartItemCount,
      onSave: _promptSaveOrder,
      onBack: () {
        if (_afterMenuView == PosView.orderDetail) {
          final o = _findOrder(_activeOrderKey ?? '');
          if (o != null) {
            _openOrderDetail(o);
            return;
          }
        }
        _backToTables();
      },
      title: _activeOrderType == 'take_away'
          ? 'Pesan $_activeOrderKey'
          : 'Pesan Meja $_activeTableNumber',
    );
  }

  Widget _buildOrderDetailView() {
    final order =
        _activeOrderKey != null ? _findOrder(_activeOrderKey!) : null;
    if (order == null) return _buildTablesView();
    return _PosOrderDetailView(
      order: order,
      onBack: _backToTables,
      onAddMore: _startAddToExisting,
      onPay: () => _showPaymentFor(order),
      onAdjustQty: (item, delta) => _adjustOpenOrderItemQty(order, item, delta),
      onVoid: () async {
        await _localDb.deleteOpenOrder(order.orderKey);
        await _reloadOpenOrders();
        if (!mounted) return;
        _backToTables();
      },
    );
  }
}