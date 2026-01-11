import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../app/theme.dart';

class ErrandCard extends StatelessWidget {
  const ErrandCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Getting groceries',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                child: Image.asset('assets/images/Map.png', width: 79, height: 90, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabelValue(icon: IconsaxPlusLinear.send_2, text: 'Zoatupsi, Messasi'),
                  const SizedBox(height: 8),
                  LabelValue(icon: IconsaxPlusLinear.location, text: 'Marche Messasi'),
                ],
              )
            ],
          ),
          const Divider(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date & time', style: TextStyle(color: AppTheme.primary700)),
              Text('9 Dec 2025, 10:52 AM', style: TextStyle(fontWeight: FontWeight.w500,color: AppTheme.primary700)),
            ],
          ),
          // ... Add other rows for Runner, Time taken, Amount similarly
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
        Icon(icon, size: 18, color: AppTheme.primary700),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
