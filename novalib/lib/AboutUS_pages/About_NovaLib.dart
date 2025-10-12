import 'package:flutter/material.dart';

// Accept useAltBackground as a parameter
class AboutNovaLibPage extends StatelessWidget {
  final bool useAltBackground;
  const AboutNovaLibPage({Key? key, this.useAltBackground = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fix: safely extract bool from arguments
    bool bg = useAltBackground;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['useAltBackground'] != null) {
      bg = args['useAltBackground'] == true;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'About NovaLib',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(0, 255, 255, 255),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              bg ? 'assets/background2.jpg' : 'assets/background1.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(height: 80),
                Text(
                  'NovaLib',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'NovaLib is your smart library companion. '
                  'Easily manage your issued books, wishlist, and notifications. '
                  'Stay updated with the latest from your library and developers.',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                SizedBox(height: 24),
                Text('Version 1.0.0', style: TextStyle(color: Colors.white70)),
                SizedBox(height: 8),
                Text(
                  '© 2025 NovaLib Team',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
