import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../app/theme.dart';

class ErrandCard extends StatelessWidget {
  final dynamic errand; // Replace with your actual Errand model type

  const ErrandCard({super.key, required this.errand});

  @override
  Widget build(BuildContext context) {
    // Safe extraction of fields (null-aware)
    final String fromLocation = errand?.goTo?.formattedAddress ?? '';
    final String toLocation = errand?.returnTo?.formattedAddress ?? 'Unknown';
    final dateTime = errand?.createdAtFormatted ?? '---';
    final runnerName = errand?.runnerName ?? 'runnerName';
    // Safely extract runner score from multiple possible shapes (model field, nested runner map, string/num)
    double _parseScore(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      final s = v.toString();
      return double.tryParse(s) ?? 0.0;
    }

    dynamic rawScore;
    try {
      rawScore = errand?.runnerScore ?? errand?.runnerScoreValue ?? (errand?.runner is Map ? errand?.runner['trustScore'] : null);
    } catch (e) {
      rawScore = null;
      debugPrint('[ErrandCard] rawScore extraction error: $e');
    }
    // Debug: log rawScore and its runtimeType to diagnose type issues
    debugPrint('[ErrandCard] rawScore=$rawScore runtimeType=${rawScore?.runtimeType} runnerScoreField=${errand?.runnerScore} runnerScoreValue=${errand?.runnerScoreValue}');
    final scoreVal = _parseScore(rawScore);
    final runnerScore = scoreVal.toStringAsFixed(0);
    final timeTaken = "${errand?.speed }";
    final amount = "XAF ${errand?.price ?? 0}";
    final paymentMethod = errand?.paymentMethod ?? 'CASH';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FDFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Section: Map + Locations
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/Map.png',
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabelValue(icon: IconsaxPlusLinear.send_2, text: fromLocation),
                    if (toLocation != "Unknown") ...[
                      const SizedBox(height: 12),
                      LabelValue(icon: IconsaxPlusLinear.location, text: toLocation),
                    ],
                  ],
                ),
              ),

            ],
          ),
          const SizedBox(height: 16),

          // Details Section
          _buildInfoRow('Date & time', dateTime),
          _buildRunnerRow('Runner', runnerName, runnerScore),
          _buildInfoRow('Time suggested', timeTaken),
          _buildAmountRow('Amount', amount, paymentMethod),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.primary700, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunnerRow(String label, String name, String score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.primary700, fontSize: 14)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700, fontSize: 14), overflow: TextOverflow.ellipsis),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text("|", style: TextStyle(color: AppTheme.primary700, fontSize: 18)),
                ),
                Image.asset('assets/images/shield-tick.png', height: 20),
                const SizedBox(width: 4),
                Text("$score/100", style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, String method) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.primary700, fontSize: 14)),
          Row(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700, fontSize: 14)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text("|", style: TextStyle(color: AppTheme.primary700, fontSize: 18)),
              ),
              Image.asset(
                method.toUpperCase() == 'CASH' ? 'assets/images/cash.png' : 'assets/images/online.png',
                height: 20,
              ),
              const SizedBox(width: 4),
              Text(method.toLowerCase(), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

class LabelValue extends StatelessWidget {
  final IconData icon;
  final String text;
  const LabelValue({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28, color: AppTheme.primary700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: AppTheme.primary700, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
