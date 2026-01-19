// File: lib/features/runner/screens/runner_dashboard.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../app/theme.dart';
import '../../../graphql/errand_queries.dart';
import '../../services/runner_polling_service.dart';

class RunnerDashboard extends StatefulWidget {
  const RunnerDashboard({super.key});

  static const String routeName = 'runner-dashboard';
  static const String path = '/runner-dashboard';

  @override
  State<RunnerDashboard> createState() => _RunnerDashboardState();
}

class _RunnerDashboardState extends State<RunnerDashboard> {
  late RunnerPollingService _pollingService;
  StreamSubscription? _sub;
  List<Map<String, dynamic>> _pendingOffers = [];
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();

    final client = GraphQLProvider.of(context).value;

    _pollingService = RunnerPollingService(client: client);
    _pollingService.startPolling(
      query: runnerPendingOffersQuery,
      interval: const Duration(seconds: 5),
    );

    _sub = _pollingService.events.listen((offers) {
      if (mounted) {
        setState(() {
          _pendingOffers = offers;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pollingService.dispose();
    super.dispose();
  }

  Future<void> _acceptOffer(String offerId) async {
    if (_isAccepting) return;

    setState(() {
      _isAccepting = true;
    });

    try {
      final client = GraphQLProvider.of(context).value;

      final MutationOptions options = MutationOptions(
        document: gql(acceptOfferMutation),
        variables: {'offerId': offerId},
      );

      final QueryResult result = await client.mutate(options);

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final bool? success = result.data?['acceptErrandOffer']?['ok'] as bool?;

      if (success == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offer accepted!'),
              backgroundColor: Colors.green,
            ),
          );

          // Remove from local list
          setState(() {
            _pendingOffers.removeWhere((o) => o['id'] == offerId);
          });

          // Navigate to errand in progress
          // TODO: Navigate to runner errand screen
        }
      }
    } catch (e) {
      debugPrint('[RunnerDashboard] Accept error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  void _declineOffer(String offerId) {
    setState(() {
      _pendingOffers.removeWhere((o) => o['id'] == offerId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offer declined')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Runner Dashboard'),
        backgroundColor: AppTheme.primary700,
      ),
      backgroundColor: AppTheme.neutral100,
      body: _pendingOffers.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingOffers.length,
        itemBuilder: (context, index) {
          return _buildOfferCard(_pendingOffers[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: AppTheme.primary700.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for errands...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.primary700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll be notified when someone needs your help',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.primary700.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final errand = offer['errand'] as Map<String, dynamic>?;
    final tasks = errand?['tasks'] as List<dynamic>? ?? [];
    final goTo = errand?['goTo'] as Map<String, dynamic>?;
    final price = offer['price'] ?? 0;
    final expiresIn = offer['expiresIn'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Errand Request',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'XAF $price',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tasks
            if (tasks.isNotEmpty) ...[
              Text(
                'Tasks:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary700,
                ),
              ),
              const SizedBox(height: 8),
              ...tasks.map((task) {
                final desc = task['description'] ?? '';
                final taskPrice = task['price'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                        size: 16,
                        color: AppTheme.secondary500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(desc)),
                      Text(
                        'XAF $taskPrice',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Location
            if (goTo != null) ...[
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                    size: 20,
                    color: AppTheme.primary700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goTo['address'] ?? 'Location provided',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Expires in
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                  size: 20,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Expires in: $expiresIn',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isAccepting
                        ? null
                        : () => _declineOffer(offer['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAccepting
                        ? null
                        : () => _acceptOffer(offer['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isAccepting
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}