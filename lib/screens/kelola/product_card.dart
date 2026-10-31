// lib/screens/kelola/product_card.dart
part of '../kelola_screen.dart';

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isInactive;
  final VoidCallback onEdit;
  final VoidCallback onDeleteRestore;

  const _ProductCard({
    required this.product,
    required this.isInactive,
    required this.onEdit,
    required this.onDeleteRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: isInactive ? Colors.grey.shade100 : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: _buildImage())),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(product.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isInactive
                                    ? AppTheme.textLightColor
                                    : AppTheme.textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    if (!product.isSynced && !isInactive)
                      const Icon(Icons.cloud_off,
                          size: 14, color: AppTheme.dangerColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'Rp ${NumberFormat.decimalPattern('id').format(product.price)}',
                    style: TextStyle(
                        fontSize: 13,
                        color: isInactive
                            ? AppTheme.textLightColor
                            : AppTheme.primaryColor,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isInactive) ...[
                        InkWell(
                            onTap: onEdit,
                            child: const Icon(Icons.edit_outlined,
                                color: AppTheme.primaryColor, size: 20)),
                        const SizedBox(width: 12),
                      ],
                      InkWell(
                          onTap: onDeleteRestore,
                          child: Icon(
                              isInactive
                                  ? Icons.restore
                                  : Icons.delete_outline,
                              color:
                                  isInactive ? Colors.green : AppTheme.dangerColor,
                              size: 20)),
                    ])
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (product.localImagePath != null &&
        File(product.localImagePath!).existsSync()) {
      return Image.file(File(product.localImagePath!), fit: BoxFit.cover);
    }
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(product.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
          child: Icon(Icons.image_outlined,
              color: AppTheme.textLightColor, size: 40)));
}