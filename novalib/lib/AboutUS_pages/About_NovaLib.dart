import 'package:flutter/material.dart';
import '../theme.dart';

class AboutNovaLibPage extends StatelessWidget {
  // Kept for route compatibility; not used now that we have AnimatedBg
  final bool useAltBackground;
  const AboutNovaLibPage({Key? key, this.useAltBackground = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'About NovaLib',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBg()),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
              child: Container(
                decoration: AppDecorations.cardPearl(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'NovaLib',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'NovaLib is your smart library companion. Easily manage your issued books, wishlist, and notifications. '
                      'Stay updated with the latest from your library and developers.',
                      style: TextStyle(fontSize: 16, color: AppColors.muted),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '© 2025 NovaLib Team',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
