import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class ReportsAiView extends StatelessWidget {
  final String? initialAnalysis;
  final bool isLoading;
  final VoidCallback? onRetry;
  final String? errorMessage;

  const ReportsAiView({
    super.key,
    this.initialAnalysis,
    this.isLoading = false,
    this.onRetry,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.greyBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.navy),
                    const SizedBox(width: 8),
                    const Text(
                      'Analisa AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.greyText),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.greyBorder),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.navy),
              SizedBox(height: 16),
              Text('Menganalisa data...', style: TextStyle(color: AppTheme.greyText)),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.red, size: 48),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.red),
            ),
            const SizedBox(height: 16),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
                child: const Text('Coba Lagi'),
              ),
          ],
        ),
      );
    }

    if (initialAnalysis != null && initialAnalysis!.isNotEmpty) {
      return SelectableText(
        initialAnalysis!,
        style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.black),
      );
    }

    return const Center(
      child: Text(
        'Belum ada analisa.',
        style: TextStyle(color: AppTheme.greyText),
      ),
    );
  }
}