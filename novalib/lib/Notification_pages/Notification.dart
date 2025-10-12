import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart'; // use shared base URL from config

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> libraryNotifications = [];
  bool isLoading = true;
  bool isLibraryLoading = true;
  bool useAltBackground = false; // add this

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      useAltBackground = args['useAltBackground'] ?? false;
      // Trigger rebuild only if needed
      // setState not required here as didChangeDependencies precedes first build
    }
  }

  String get _baseUrl => djangoBaseUrl.endsWith('/')
      ? djangoBaseUrl.substring(0, djangoBaseUrl.length - 1)
      : djangoBaseUrl;

  String _fullImageUrl(String raw) {
    if (raw.startsWith('http')) return raw;
    // ensure exactly one slash between base and path
    if (raw.startsWith('/')) return '$_baseUrl$raw';
    return '$_baseUrl/$raw';
  }

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    fetchLibraryNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/notifications/'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          notifications = data.cast<Map<String, dynamic>>();
        });
      } else {
        debugPrint('Notifications fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> fetchLibraryNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/library-notifications/'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          libraryNotifications = data.cast<Map<String, dynamic>>();
        });
      } else {
        debugPrint(
          'Library notifications fetch failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching library notifications: $e');
    } finally {
      if (mounted) setState(() => isLibraryLoading = false);
    }
  }

  Future<void> refreshAll() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        isLibraryLoading = true;
      });
    }
    await Future.wait([fetchNotifications(), fetchLibraryNotifications()]);
  }

  Widget _buildNotificationBox(
    Map<String, dynamic> notification, {
    String avatarInitial = "D",
  }) {
    final String senderName = notification['uploaded_by'] ?? 'Sender Name';
    final String message = notification['message'] ?? '';
    final String? imageUrl =
        notification['uploaded_image'] ?? notification['image_url'];
    final String timestamp = notification['timestamp'] ?? '';
    final String title = notification['title'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(
          0.6,
        ), // Changed from white to semi-transparent black
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.2,
            ), // Darker shadow for better contrast
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ), // Subtle white border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[700], // Darker avatar background
                child: Text(
                  avatarInitial,
                  style: TextStyle(
                    color: Colors.white, // White text on dark background
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      style: TextStyle(
                        color: Colors.white, // White text
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white, // White text
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white70,
              ), // Light white text
            ),
          ],
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/notification_image',
                  arguments: {'imageUrl': _fullImageUrl(imageUrl)},
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  _fullImageUrl(imageUrl),
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            timestamp,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.35),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Background image same as HomePage
          Positioned.fill(
            child: Image.asset(
              useAltBackground
                  ? 'assets/background2.jpg'
                  : 'assets/background1.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.45),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await refreshAll();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Developer notification section
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'From Developer',
                          style: TextStyle(
                            fontSize: 16,
                            color: const Color.fromARGB(255, 255, 255, 255),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: isLoading
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : notifications.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Text(
                                    'No new notifications',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors
                                          .white, // Changed from Colors.black to Colors.white
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: notifications
                                    .map(
                                      (n) => _buildNotificationBox(
                                        n,
                                        avatarInitial: "D",
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      // Library section label below developer section
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'From library',
                          style: TextStyle(
                            fontSize: 16,
                            color: const Color.fromARGB(255, 255, 255, 255),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: isLibraryLoading
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : libraryNotifications.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Text(
                                    'No library notifications',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors
                                          .white, // Changed from Colors.black54 to Colors.white
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: libraryNotifications
                                    .map(
                                      (n) => _buildNotificationBox(
                                        n,
                                        avatarInitial: "L",
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
