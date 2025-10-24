import 'package:flutter/material.dart';
import 'home.dart';
import 'login.dart';
import 'Notification_pages/Notification.dart';
import 'AboutUS_pages/About_NovaLib.dart';
import 'config.dart'; // import shared base URL
import 'package:http/http.dart' as http;
import 'app_shell.dart';

// Details route imports
import 'models/book_item.dart';
import 'common_pages/book_details_page.dart';

// Replace only the connectToDjangoServer function with this safer version.
Future<void> connectToDjangoServer() async {
  String base = djangoBaseUrl.trim();
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);

  final candidates = <String>[
    '$base/api/health/',
    '$base/health/',
    '$base/api/',
    '$base/',
  ];

  for (final url in candidates) {
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode >= 200 && res.statusCode < 500) {
        debugPrint('Django reachable at $url (status: ${res.statusCode})');
        return;
      } else {
        debugPrint('Tried $url -> ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error contacting $url: $e');
    }
  }
  debugPrint('Django not reachable at $base');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await connectToDjangoServer();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NovaLib',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // Keep initial route as /home but now it opens the AppShell (with bottom nav)
      initialRoute: '/login',
      routes: {
        '/login': (context) => ForestLoginPage(apiBaseUrl: djangoBaseUrl),

        // /home loads the bottom-nav shell that hosts Home, Issued, Pay Fine tabs
        '/home': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String username = 'User';
          bool useAltBackground = false;
          String? userBarcode;

          if (args is Map<String, dynamic>) {
            username =
                (args['username'] is String &&
                    (args['username'] as String).isNotEmpty)
                ? args['username']
                : 'User';
            useAltBackground = args['useAltBackground'] ?? false;
            userBarcode = args['userBarcode'] as String?;
          } else if (args is String && args.isNotEmpty) {
            username = args;
          }
          if (username.isEmpty) username = 'User';

          return AppShell(
            username: username,
            useAltBackground: useAltBackground,
            userBarcode: userBarcode,
          );
        },

        '/notifications': (context) => const NotificationPage(),

        '/about_novalib': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          bool useAltBackground = false;
          if (args is Map && args['useAltBackground'] != null) {
            useAltBackground = args['useAltBackground'] == true;
          }
          return AboutNovaLibPage(useAltBackground: useAltBackground);
        },

        // Named route for book details (pass a BookItem via arguments)
        '/book_details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is! BookItem) {
            return const Scaffold(
              body: Center(child: Text('Invalid book data')),
            );
          }
          return BookDetailsPage(book: args);
        },

        // Fullscreen image viewer for notifications
        '/notification_image': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String? imageUrl;
          if (args is String) {
            imageUrl = args;
          } else if (args is Map) {
            final v = args['imageUrl'] ?? args['image_url'] ?? args['url'];
            if (v is String) imageUrl = v;
          }
          return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? const Text(
                      'No image URL provided',
                      style: TextStyle(color: Colors.white70),
                    )
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
            ),
          );
        },
      },
    );
  }
}
