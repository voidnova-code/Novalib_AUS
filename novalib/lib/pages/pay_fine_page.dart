import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

class PayFinePage extends StatelessWidget with DiagnosticableTreeMixin {
  final String username;

  const PayFinePage({Key? key, required this.username}) : super(key: key);

  // Expose fields to Flutter Inspector to avoid "Lookup failed" errors
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('username', username, defaultValue: ''));
  }

  @override
  Widget build(BuildContext context) {
    const fineAmount = 12.0;
    final displayName = (username).trim().isEmpty ? 'User' : username;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Pay Fine', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBg()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    decoration: AppDecorations.cardPearl(),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Outstanding library fine',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: AppDecorations.cardPearl(),
                    child: ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                        color: AppColors.ink,
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(color: AppColors.ink),
                      ),
                      subtitle: const Text(
                        'Account holder',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: AppDecorations.cardPearl(),
                    child: ListTile(
                      leading: const Icon(
                        Icons.currency_rupee,
                        color: AppColors.ink,
                      ),
                      title: const Text(
                        'Total Due',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      trailing: Text(
                        '₹${fineAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Pay now (coming soon)'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment integration coming soon'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
