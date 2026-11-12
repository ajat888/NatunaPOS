part of 'main_layout.dart';

class _SyncBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _SyncBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: SyncStatusService.instance.state,
      builder: (context, state, _) {
        return ValueListenableBuilder<int>(
          valueListenable: SyncStatusService.instance.pendingCount,
          builder: (context, pendingCount, __) {
            IconData icon;
            Color color;
            String label;
            String tooltip;
            switch (state) {
              case SyncState.syncing:
                icon = Icons.sync;
                color = AppTheme.primaryColor;
                label = 'SYNC';
                tooltip = 'Menyinkronkan...';
                break;
              case SyncState.pending:
                icon = Icons.cloud_upload_outlined;
                color = Colors.orange.shade800;
                label = '$pendingCount';
                tooltip = '$pendingCount perubahan menunggu. Ketuk untuk sync.';
                break;
              case SyncState.failed:
                icon = Icons.cloud_off;
                color = AppTheme.dangerColor;
                label = 'GAGAL';
                tooltip = 'Sinkronisasi gagal. Ketuk untuk coba lagi.';
                break;
              case SyncState.idle:
                icon = Icons.cloud_done_outlined;
                color = Colors.green.shade700;
                label = 'OK';
                tooltip = 'Semua data tersinkron. Ketuk untuk sync manual.';
                break;
            }
            return Tooltip(
              message: tooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

extension _MainLayoutDrawerExt on _MainLayoutState {
  Widget _buildDrawerItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.08),
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textLightColor,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
        ),
      ),
      onTap: () => _selectDestination(index),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: 280,
      backgroundColor: AppTheme.surfaceColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.storefront, color: AppTheme.primaryColor, size: 32),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NatunaPOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Smart POS & Business Analytics',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'STATUS SYNC',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textLightColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  _SyncBadge(onTap: _trySync),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(0, Icons.dashboard_outlined, 'Beranda'),
                  _buildDrawerItem(1, Icons.point_of_sale_outlined, 'Kasir'),
                  _buildDrawerItem(2, Icons.inventory_2_outlined, 'Kelola'),
                  _buildDrawerItem(3, Icons.receipt_long_outlined, 'Riwayat'),
                  _buildDrawerItem(4, Icons.account_balance_wallet_outlined, 'Pengeluaran'),
                  _buildDrawerItem(5, Icons.settings_outlined, 'Pengaturan'),
                  _buildDrawerItem(6, Icons.bar_chart_outlined, 'Laporan'),
                  _buildDrawerItem(7, Icons.lock_clock_outlined, 'Closing Harian'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}