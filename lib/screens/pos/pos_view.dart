part of '../pos_screen.dart';

extension _PosViewsExt on PosScreenState {
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
              onPressed: () => reloadData(showLoading: true),
              tooltip: 'Muat ulang'),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: AppSettings.instance.tableCount,
        builder: (context, tableCount, _) => _PosTablesView(
          openOrders: _openOrders,
          tableCount: tableCount,
          onTapEmptyTable: _openEmptyTable,
          onTapOpenOrder: _openOrderDetail,
          onTapTakeAway: _openTakeAway,
          onTapPay: _showPaymentFor,
        ),
      ),
    );
  }

  Widget _buildMenuView() {
    return _PosMenuPicker(
      products: _products,
      categories: _categories,
      cart: _cart,
      filterCategoryId: _filterCategoryId,
      onFilterChanged: _updateFilterCategoryId, // <-- Diperbaiki
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
      onReorder: _handleReorderCategories,
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
      onSplit: _openSplitView,
      onAdjustQty: (item, delta) => _adjustOpenOrderItemQty(order, item, delta),
      onVoidSuccess: () async {
        await _reloadOpenOrders();
        if (!mounted) return;
        _backToTables();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan di-void'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  Widget _buildSplitView() {
    final order =
        _activeOrderKey != null ? _findOrder(_activeOrderKey!) : null;
    if (order == null) return _buildTablesView();
    return _PosSplitView(
      order: order,
      onBack: () {
        final o = _findOrder(_activeOrderKey!);
        if (o != null) {
          _openOrderDetail(o);
        } else {
          _backToTables();
        }
      },
      onPay: _handleSplitPay,
    );
  }
}