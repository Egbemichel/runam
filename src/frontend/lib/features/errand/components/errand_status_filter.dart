import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/errand.dart';

/// Filter chip widget for filtering errands by status
class ErrandStatusFilter extends StatelessWidget {
  final ErrandStatus? selectedStatus;
  final Function(ErrandStatus?) onStatusChanged;
  final Map<ErrandStatus?, int> counts;

  const ErrandStatusFilter({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip(null, 'All', counts[null] ?? 0),
          const SizedBox(width: 8),
          _buildFilterChip(ErrandStatus.pending, 'Pending', counts[ErrandStatus.pending] ?? 0),
          const SizedBox(width: 8),
          _buildFilterChip(ErrandStatus.accepted, 'In Progress', counts[ErrandStatus.accepted] ?? 0),
          const SizedBox(width: 8),
          _buildFilterChip(ErrandStatus.completed, 'Completed', counts[ErrandStatus.completed] ?? 0),
          const SizedBox(width: 8),
          _buildFilterChip(ErrandStatus.expired, 'Expired', counts[ErrandStatus.expired] ?? 0),
          const SizedBox(width: 8),
          _buildFilterChip(ErrandStatus.cancelled, 'Cancelled', counts[ErrandStatus.cancelled] ?? 0),
        ],
      ),
    );
  }

  Widget _buildFilterChip(ErrandStatus? status, String label, int count) {
    final isSelected = selectedStatus == status;
    final color = _getStatusColor(status);

    return GestureDetector(
      onTap: () => onStatusChanged(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? color : AppTheme.neutral200.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.primary700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ErrandStatus? status) {
    if (status == null) return AppTheme.primary700;
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
}

