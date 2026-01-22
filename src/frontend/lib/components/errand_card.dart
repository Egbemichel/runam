import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../app/theme.dart';
import 'package:get/get.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../controllers/auth_controller.dart';
import '../features/errand/models/errand.dart';
import '../../services/graphql_client.dart';


Future<Map<String, dynamic>?> fetchBuyerInfo(String userId) async {
  final client = GraphQLClientInstance.client;
  const String query = r'''
    query GetUser($id: ID!) {
      user(id: $id) {
        id
        name
        trustScore
      }
    }
  ''';
  final options = QueryOptions(
    document: gql(query),
    variables: {'id': userId},
    fetchPolicy: FetchPolicy.networkOnly,
  );
  final result = await client.query(options);
  if (result.hasException || result.data == null) return null;
  return result.data!['user'] as Map<String, dynamic>?;
}

class ErrandCard extends StatelessWidget {
  final Errand errand; // Strict typing to your Errand model

  const ErrandCard({super.key, required this.errand});

  @override
  Widget build(BuildContext context) {
    // Safe extraction using your model's getters
    final String fromLocation = errand.goTo.name;
    final String toLocation = errand.returnTo?.name ?? 'Unknown';
    final String dateTime = errand.createdAtFormatted;
    final AuthController authController = Get.find<AuthController>();
    final bool isRunnerActive = authController.isRunnerActive;

    if (isRunnerActive) {
      final String? currentUserId = errand.userId;
      return FutureBuilder<Map<String, dynamic>?>(
        future: currentUserId != null ? fetchBuyerInfo(currentUserId) : Future.value(null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a loader while fetching buyer info
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Show fallback if error
            return _buildCardLayout(
              context: context,
              from: fromLocation,
              to: toLocation,
              date: dateTime,
              label: 'Buyer',
              name: errand.userName ?? 'Client',
              score: (errand.userTrustScore ?? 0.0).toStringAsFixed(0),
              speed: errand.speed,
              amount: "XAF ${errand.price?.toInt() ?? 0}",
              method: errand.paymentMethod,
            );
          }
          final buyer = snapshot.data;
          final String displayName = buyer != null && buyer['name'] != null
              ? buyer['name']
              : (errand.userName ?? 'Client');
          final String displayScore = buyer != null && buyer['trustScore'] != null
              ? buyer['trustScore'].toStringAsFixed(0)
              : (errand.userTrustScore ?? 0.0).toStringAsFixed(0);
          return _buildCardLayout(
            context: context,
            from: fromLocation,
            to: toLocation,
            date: dateTime,
            label: 'Buyer',
            name: displayName,
            score: displayScore,
            speed: errand.speed,
            amount: "XAF ${errand.price?.toInt() ?? 0}",
            method: errand.paymentMethod,
          );
        },
      );
    } else {
      return _buildCardLayout(
        context: context,
        from: fromLocation,
        to: toLocation,
        date: dateTime,
        label: 'Runner',
        name: errand.runnerName ?? 'Searching...',
        score: errand.runnerScoreValue.toStringAsFixed(0),
        speed: errand.speed,
        amount: "XAF ${errand.price?.toInt() ?? 0}",
        method: errand.paymentMethod,
      );
    }
  }

  Widget _buildCardLayout({
    required BuildContext context,
    required String from,
    required String to,
    required String date,
    required String label,
    required String name,
    required String score,
    required String speed,
    required String amount,
    required String method,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FDFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/images/Map.png', width: 90, height: 90, fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    LabelValue(icon: IconsaxPlusLinear.send_2, text: from),
                    if (to != "Unknown") ...[
                      const SizedBox(height: 12),
                      LabelValue(icon: IconsaxPlusLinear.location, text: to),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Date & time', date),
          _buildRunnerRow(label, name, score),
          _buildInfoRow('Time suggested', speed),
          _buildAmountRow('Amount', amount, method),
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
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700))),
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
          Row(
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text("|", style: TextStyle(color: AppTheme.primary700))),
              Image.asset('assets/images/shield-tick.png', height: 20),
              const SizedBox(width: 4),
              Text("$score/100", style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700)),
            ],
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
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text("|", style: TextStyle(color: AppTheme.primary700))),
              Image.asset(method.toUpperCase() == 'CASH' ? 'assets/images/cash.png' : 'assets/images/online.png', height: 20),
              const SizedBox(width: 4),
              Text(method.toLowerCase(), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700)),
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
        Icon(icon, size: 24, color: AppTheme.primary700),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.primary700, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}