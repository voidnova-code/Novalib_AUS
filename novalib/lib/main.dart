import 'package:flutter/material.dart';
import 'home.dart';
import 'login.dart';
import 'Notification_pages/Notification.dart';
import 'Notification_pages/Notification_Image.dart';
import 'AboutUS_pages/About_NovaLib.dart';
import 'config.dart'; // import shared base URL
import 'package:http/http.dart' as http;
import 'app_shell.dart';

Future<void> connectToDjangoServer() async {
  final candidates = <String>[
    '$djangoBaseUrl/api/health/',
    '$djangoBaseUrl/health/',
    '$djangoBaseUrl/api/',
    '$djangoBaseUrl/',
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
  debugPrint('Django not reachable at $djangoBaseUrl');
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
      initialRoute: '/home',
      routes: {
        '/login': (context) => ForestLoginPage(apiBaseUrl: djangoBaseUrl),

        // NEW: /home now loads the bottom-nav shell that hosts Home, Issued, Pay Fine tabs
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

        // Keep your other routes unchanged
        '/notifications': (context) => const NotificationPage(),
        '/notification_image': (context) => const NotificationImagePage(),
        '/about_novalib': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          bool useAltBackground = false;
          if (args is Map && args['useAltBackground'] != null) {
            useAltBackground = args['useAltBackground'] == true;
          }
          return AboutNovaLibPage(useAltBackground: useAltBackground);
        },
      },
    );
  }
}
