part of '../dashboard_screen.dart';

class _SignalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;

  const _SignalCard({
    required this.icon,
    required this.title,
    required this.accent,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

class _DashboardSyncCard extends StatelessWidget {
  const _DashboardSyncCard();

  @override
  Widget build(BuildContext context) {
    final service = SyncStatusService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([
        service.state,
        service.pendingCount,
        service.rejectedCount,
        service.lastSyncedAt,
      ]),
      builder: (context, _) {
        final state = service.state.value;
        final pending = service.pendingCount.value;
        final rejected = service.rejectedCount.value;
        final last = service.lastSyncedAt.value;
        final failed = state == SyncState.failed;
        final syncing = state == SyncState.syncing;
        final accent = failed || rejected > 0
            ? AppTheme.dangerColor
            : (pending > 0 ? AppTheme.primaryColor : AppTheme.textLightColor);
        final String label;
        if (syncing) {
          label = 'Sedang mengirim data ke server.';
        } else if (failed) {
          label = 'Sinkronisasi gagal. Data masih tersimpan di HP ini.';
        } else if (pending > 0) {
          label = '$pending perubahan belum terkirim ke server.';
        } else {
          label = last == null
              ? 'Semua data terkirim.'
              : 'Semua data terkirim, pukul ${DateFormat('HH:mm').format(last)}.';
        }
        return _SignalCard(
          icon: failed
              ? Icons.cloud_off
              : (syncing
                  ? Icons.cloud_sync
                  : (pending > 0
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_done_outlined)),
          title: 'Status Sinkronisasi',
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textColor,
                ),
              ),
              if (rejected > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$rejected data ditolak server dan tidak akan dikirim ulang.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.dangerColor,
                  ),
                ),
              ],
              if (syncing) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 4),
              ] else if (pending > 0 || failed) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => AutoSyncScheduler.instance
                        .scheduleSync(delay: const Duration(seconds: 1)),
                    child: const Text('SINKRONKAN SEKARANG'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DashboardOpenOrdersCard extends StatelessWidget {
  final int count;
  final int value;
  final int oldestMinutes;
  final VoidCallback? onTap;

  const _DashboardOpenOrdersCard({
    required this.count,
    required this.value,
    required this.oldestMinutes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    final stale = oldestMinutes >= 60;
    return _SignalCard(
      icon: Icons.receipt_long_outlined,
      title: 'Pesanan Belum Dibayar',
      accent: stale ? AppTheme.dangerColor : AppTheme.primaryColor,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count pesanan • Rp ${formatCurrency.format(value)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Terlama menunggu $oldestMinutes menit. Ketuk untuk buka Kasir.',
            style: TextStyle(
              fontSize: 13,
              color: stale ? AppTheme.dangerColor : AppTheme.textLightColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardVoidCard extends StatelessWidget {
  final int count;
  final int total;

  const _DashboardVoidCard({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    return _SignalCard(
      icon: Icons.warning_amber_rounded,
      title: 'Transaksi Dibatalkan Hari Ini',
      accent: AppTheme.dangerColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count transaksi • Rp ${formatCurrency.format(total)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Periksa alasan pembatalan di menu Riwayat.',
            style: TextStyle(fontSize: 13, color: AppTheme.textLightColor),
          ),
        ],
      ),
    );
  }
}

class _DashboardTopProductsCard extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const _DashboardTopProductsCard({required this.products});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    return _SignalCard(
      icon: Icons.local_fire_department_outlined,
      title: 'Terlaris Hari Ini',
      accent: AppTheme.textLightColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in products)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (item['name'] as String?) ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(item['qty_sold'] as int?) ?? 0} terjual',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rp ${formatCurrency.format((item['revenue'] as int?) ?? 0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textLightColor,
                    ),
                  ),
                ],
              ),
            ),
          const Text(
            'Aplikasi ini tidak melacak stok. Pastikan menu di atas masih bisa dijual.',
            style: TextStyle(fontSize: 12, color: AppTheme.textLightColor),
          ),
        ],
      ),
    );
  }
}