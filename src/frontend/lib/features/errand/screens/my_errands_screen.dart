import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../components/errand_item_card.dart';
import '../components/errand_status_filter.dart';
import '../controllers/my_errands_controller.dart';
import '../models/errand.dart';

class MyErrandsScreen extends StatelessWidget {
  static const String routeName = 'my-errands';
  static const String path = '/my-errands';

  const MyErrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller if not already registered
    if (!Get.isRegistered<MyErrandsController>()) {
      Get.put(MyErrandsController());
    }
    final controller = Get.find<MyErrandsController>();

    return Scaffold(
      backgroundColor: AppTheme.neutral100,
      appBar: AppBar(
        backgroundColor: AppTheme.neutral100,
        title: const Text(
          'My Errands',
          style: TextStyle(
            color: AppTheme.primary700,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => controller.refreshErrands(),
            icon: const Icon(
              IconsaxPlusLinear.refresh,
              color: AppTheme.primary700,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Obx(() {
              return ErrandStatusFilter(
                selectedStatus: controller.selectedFilter.value,
                onStatusChanged: controller.setFilter,
                counts: {
                  null: controller.getCountByStatus(null),
                  ErrandStatus.pending: controller.getCountByStatus(ErrandStatus.pending),
                  ErrandStatus.accepted: controller.getCountByStatus(ErrandStatus.accepted),
                  ErrandStatus.completed: controller.getCountByStatus(ErrandStatus.completed),
                  ErrandStatus.expired: controller.getCountByStatus(ErrandStatus.expired),
                  ErrandStatus.cancelled: controller.getCountByStatus(ErrandStatus.cancelled),
                },
              );
            }),
          ),

          // Errands list
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary500,
                  ),
                );
              }

              if (controller.errorMessage.value != null) {
                return _buildErrorState(
                  controller.errorMessage.value!,
                  onRetry: () => controller.fetchErrands(),
                );
              }

              final errands = controller.filteredErrands;

              if (errands.isEmpty) {
                return _buildEmptyState(controller.selectedFilter.value);
              }

              return RefreshIndicator(
                onRefresh: () => controller.refreshErrands(),
                color: AppTheme.primary500,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: errands.length,
                  itemBuilder: (context, index) {
                    final errand = errands[index];
                    return ErrandItemCard(
                      errand: errand,
                      onTap: () => _showErrandDetails(context, errand),
                      onCancel: errand.status == ErrandStatus.pending && errand.isOpen
                          ? () => _confirmCancel(context, controller, errand)
                          : null,
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ErrandStatus? filter) {
    String message;
    String subtitle;

    if (filter == null) {
      message = 'No errands yet';
      subtitle = 'Create your first errand and let runners help you out!';
    } else {
      message = 'No ${filter.label.toLowerCase()} errands';
      subtitle = 'You don\'t have any ${filter.label.toLowerCase()} errands at the moment.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/empty-box.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.neutral200,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/ghost.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.neutral200,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(IconsaxPlusLinear.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrandDetails(BuildContext context, Errand errand) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ErrandDetailsSheet(errand: errand),
    );
  }

  void _confirmCancel(
    BuildContext context,
    MyErrandsController controller,
    Errand errand,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Cancel Errand?'),
        content: const Text(
          'Are you sure you want to cancel this errand? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep',
              style: TextStyle(color: AppTheme.neutral200),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await controller.cancelErrand(errand.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Your errand has been cancelled'),
                    backgroundColor: AppTheme.neutral200,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancel Errand'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing errand details
class _ErrandDetailsSheet extends StatelessWidget {
  final Errand errand;

  const _ErrandDetailsSheet({required this.errand});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.neutral200.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Status header
                    _buildStatusHeader(),
                    const SizedBox(height: 24),

                    // Image if available
                    if (errand.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          errand.imageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: AppTheme.secondary300,
                            child: const Icon(
                              IconsaxPlusLinear.image,
                              size: 48,
                              color: AppTheme.neutral200,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Locations
                    _buildSection(
                      'Destination',
                      IconsaxPlusLinear.location,
                      errand.goTo.name,
                      subtitle: errand.goTo.formattedAddress,
                    ),
                    if (errand.returnTo != null) ...[
                      const SizedBox(height: 16),
                      _buildSection(
                        'Return To',
                        IconsaxPlusLinear.arrow_circle_left,
                        errand.returnTo!.name,
                        subtitle: errand.returnTo!.formattedAddress,
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // Instructions
                    _buildSection(
                      'Instructions',
                      IconsaxPlusLinear.document_text,
                      // Convert tasks list into a single displayable string
                      errand.tasks.isNotEmpty
                          ? errand.tasks
                              .map((t) => t.price > 0
                                  ? '${t.description.trim()} — ₦${t.price}'
                                  : t.description.trim())
                              .join('\n')
                          : 'No Tasks provided',
                    ),

                    const SizedBox(height: 24),

                    // Details grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Speed',
                            errand.speed,
                            IconsaxPlusLinear.flash,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDetailItem(
                            'Payment',
                            errand.paymentMethod,
                            IconsaxPlusLinear.wallet,
                          ),
                        ),
                      ],
                    ),

                    if (errand.price != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailItem(
                        'Price',
                        '₦${errand.price!.toStringAsFixed(0)}',
                        IconsaxPlusLinear.money,
                      ),
                    ],

                    if (errand.runnerName != null) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      _buildSection(
                        'Runner',
                        IconsaxPlusLinear.user,
                        errand.runnerName!,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Timestamps
                    Text(
                      'Created: ${_formatDateTime(errand.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.neutral200,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expires: ${_formatDateTime(errand.expiresAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: errand.hasExpired ? AppTheme.error : AppTheme.neutral200,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader() {
    final color = _getStatusColor(errand.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(errand.status),
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errand.status.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  errand.status.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.neutral200,
                  ),
                ),
              ],
            ),
          ),
          if (errand.status == ErrandStatus.pending && errand.isOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: errand.timeRemaining.inMinutes < 5
                    ? AppTheme.error.withValues(alpha: 0.2)
                    : AppTheme.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                errand.timeRemainingFormatted,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: errand.timeRemaining.inMinutes < 5
                      ? AppTheme.error
                      : AppTheme.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, String content, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary500),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutral200,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.primary700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.neutral200,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondary300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary500),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutral200,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ErrandStatus status) {
    switch (status) {
      case ErrandStatus.pending:
        return AppTheme.warning;
      case ErrandStatus.accepted:
        return AppTheme.primary500;
      case ErrandStatus.completed:
        return AppTheme.success;
      case ErrandStatus.expired:
        return AppTheme.neutral200;
      case ErrandStatus.cancelled:
        return AppTheme.error;
    }
  }

  IconData _getStatusIcon(ErrandStatus status) {
    switch (status) {
      case ErrandStatus.pending:
        return IconsaxPlusLinear.clock;
      case ErrandStatus.accepted:
        return IconsaxPlusLinear.truck_fast;
      case ErrandStatus.completed:
        return IconsaxPlusLinear.tick_circle;
      case ErrandStatus.expired:
        return IconsaxPlusLinear.timer;
      case ErrandStatus.cancelled:
        return IconsaxPlusLinear.close_circle;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

