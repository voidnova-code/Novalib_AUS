import 'package:flutter/material.dart';

class NotificationImagePage extends StatelessWidget {
  const NotificationImagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final imageUrl = args != null ? args['imageUrl'] as String? : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: imageUrl == null
            ? const Text(
                'No image found',
                style: TextStyle(color: Colors.white),
              )
            : InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
      ),
    );
  }
}
