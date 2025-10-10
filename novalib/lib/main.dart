import 'package:flutter/material.dart';
import 'home.dart';
import 'login.dart';
import 'pages/Notification.dart';
import 'package:http/http.dart' as http;

const String djangoBaseUrl = 'http://192.168.182.28:8000'; // Global API base URL

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
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => ForestLoginPage(apiBaseUrl: djangoBaseUrl),
        '/home': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String username = 'User';
          bool useAltBackground = false;

          if (args is Map<String, dynamic>) {
            username = args['username'] ?? 'User';
            useAltBackground = args['useAltBackground'] ?? false;
          } else if (args is String && args.isNotEmpty) {
            username = args;
          }
          return HomePage(
            useAltBackground: useAltBackground,
            username: username,
          );
        },
        '/notifications': (context) => NotificationPage(),
      },
    );
  }
}