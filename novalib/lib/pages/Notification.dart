import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';

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

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    fetchLibraryNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$djangoBaseUrl/notifications/'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          notifications = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchLibraryNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$djangoBaseUrl/library-notifications/'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          libraryNotifications = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error fetching library notifications: $e');
    } finally {
      setState(() => isLibraryLoading = false);
    }
  }

  Future<void> refreshAll() async {
    setState(() {
      isLoading = true;
      isLibraryLoading = true;
    });
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
    final String timestamp =
        notification['timestamp'] ?? 'Yesterday at 10:00 AM';
    final String title = notification['title'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                child: Text(
                  avatarInitial,
                  style: TextStyle(
                    color: Colors.black87,
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
                        color: Colors.black87,
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
                        color: Colors.black87,
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
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ],
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl.startsWith('http')
                    ? imageUrl
                    : '$djangoBaseUrl$imageUrl',
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            timestamp,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,  // remove solid background
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
                setState(() {
                  isLoading = true;
                });
                await fetchNotifications();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: const Color.fromARGB(255, 255, 255, 255)),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  color: const Color.fromARGB(255, 255, 255, 255),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                    color: Colors.black,
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
                                    fontSize: 20,
                                    color: Colors.black54,
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
        ],
      ),
    );
  }
}
