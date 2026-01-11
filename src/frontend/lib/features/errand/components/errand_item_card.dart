import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../models/errand.dart';

/// Card widget to display an errand with status and expiry info
class ErrandItemCard extends StatefulWidget {
  final Errand errand;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const ErrandItemCard({
    super.key,
    required this.errand,
    this.onTap,
    this.onCancel,
  });

  @override
  State<ErrandItemCard> createState() => _ErrandItemCardState();
}

class _ErrandItemCardState extends State<ErrandItemCard> {
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    if (widget.errand.status == ErrandStatus.pending && widget.errand.isOpen) {
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining();
    });
  }

  void _updateTimeRemaining() {
    setState(() {
      _timeRemaining = widget.errand.timeRemaining;
    });
  }

  Color _getStatusColor() {
    switch (widget.errand.status) {
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

  IconData _getStatusIcon() {
    switch (widget.errand.status) {
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

  String _formatTimeRemaining() {
    if (_timeRemaining == Duration.zero) return 'Expired';

    if (_timeRemaining.inHours > 0) {
      return '${_timeRemaining.inHours}h ${_timeRemaining.inMinutes % 60}m';
    } else if (_timeRemaining.inMinutes > 0) {
      return '${_timeRemaining.inMinutes}m ${_timeRemaining.inSeconds % 60}s';
    } else {
      return '${_timeRemaining.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isPending = widget.errand.status == ErrandStatus.pending;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.errand.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (isPending && widget.errand.isOpen) ...[
                    // Countdown timer for pending errands
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _timeRemaining.inMinutes < 5
                            ? AppTheme.error.withValues(alpha: 0.2)
                            : AppTheme.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            IconsaxPlusLinear.timer_1,
                            size: 14,
                            color: _timeRemaining.inMinutes < 5
                                ? AppTheme.error
                                : AppTheme.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeRemaining(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _timeRemaining.inMinutes < 5
                                  ? AppTheme.error
                                  : AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.errand.status == ErrandStatus.accepted) ...[
                    // Runner info for accepted errands
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            IconsaxPlusLinear.user,
                            size: 14,
                            color: AppTheme.primary700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.errand.runnerName ?? 'Runner',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Errand type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.errand.type == 'ROUND_TRIP' ? 'Round Trip' : 'One Way',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location info
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primary500.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          IconsaxPlusLinear.location,
                          color: AppTheme.primary500,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.errand.goTo.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.primary700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.errand.goTo.formattedAddress,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.neutral200,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (widget.errand.returnTo != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.secondary500.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            IconsaxPlusLinear.arrow_circle_left,
                            color: AppTheme.primary700,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.errand.returnTo!.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.primary700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Instructions preview
                  Text(
                    widget.errand.instructions,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.neutral200,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Progress bar for pending errands
                  if (isPending && widget.errand.isOpen) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.errand.expiryProgress,
                        backgroundColor: AppTheme.neutral200.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.errand.expiryProgress > 0.8
                              ? AppTheme.error
                              : AppTheme.warning,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],

                  // Action buttons
                  if (isPending && widget.errand.isOpen && widget.onCancel != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onCancel,
                            icon: const Icon(
                              IconsaxPlusLinear.close_circle,
                              size: 18,
                            ),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: const BorderSide(color: AppTheme.error),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

