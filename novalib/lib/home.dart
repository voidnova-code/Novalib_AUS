import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  final bool useAltBackground;
  final String username;

  const HomePage({
    Key? key,
    required this.useAltBackground,
    required this.username,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Open drawer safely
  void _openDrawer() {
    try {
      _scaffoldKey.currentState?.openDrawer();
    } catch (e) {
      debugPrint('Error opening drawer: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open menu')));
    }
  }

  // Launch website robustly
  Future<void> _launchWebsite(Uri url) async {
    try {
      // Try default mode
      bool launched = await launchUrl(url, mode: LaunchMode.platformDefault);
      if (!launched) {
        // Fallback to external browser
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open the website. Please check your internet connection.',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Launch error: ${e.toString()}')));
    }
  }

  // Profile bottom sheet
  void _openProfile(BuildContext context) {
    Navigator.pop(context);
    final ctx = _scaffoldKey.currentContext ?? context;
    final String initial = widget.username.trim().isEmpty
        ? '?'
        : widget.username.trim()[0].toUpperCase();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFF5B6BFF),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Profile', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profile (coming soon)'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Edit profile not implemented'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String initial = widget.username.trim().isEmpty
        ? '?'
        : widget.username.trim()[0].toUpperCase();

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,

      // Drawer
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF5B6BFF),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.username,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Hello! I'm using NovaLib",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Menu list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Profile'),
                      onTap: () => _openProfile(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Notifications'),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/notifications',
                          arguments: {
                            'useAltBackground': widget.useAltBackground,
                          },
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.bookmark_border),
                      title: const Text('Wishlist'),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Contacts us'),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About NovaLib'),
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.black),
                title: const Text(
                  'Log out',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
      ),

      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              widget.useAltBackground
                  ? 'assets/background2.jpg'
                  : 'assets/background1.jpg',
              key: ValueKey(widget.useAltBackground),
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay
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
          // Content
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Header bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(
                            255,
                            0,
                            0,
                            0,
                          ).withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.20),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: _openDrawer,
                                ),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.language,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: const Text('Visit Website'),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(
                                      0.15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 60,
                                      vertical: 4,
                                    ),
                                  ),
                                  onPressed: () => _launchWebsite(
                                    Uri.parse('https://www.wikipedia.org/'),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.notifications,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/notifications',
                                      arguments: {
                                        'useAltBackground':
                                            widget.useAltBackground,
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 10,
                                  ),
                                  icon: const Icon(
                                    Icons.logout,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/login',
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Greeting row
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF5B6BFF),
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Hello, ${widget.username}! 😄',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Search
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white70,
                        decoration: InputDecoration(
                          hintText: 'Search books...',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color.fromARGB(
                            255,
                            0,
                            0,
                            0,
                          ).withOpacity(0.35),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white70,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.22),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.22),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.38),
                              width: 1.2,
                            ),
                          ),
                        ),
                        onSubmitted: (q) {
                          if (q.trim().isEmpty) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Searching for: $q')),
                          );
                        },
                      ),
                    ),
                    // For you
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'For you',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Three boxes
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Container(
                              height: 90,
                              decoration: _glassBoxDecoration(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    '3',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Issued Books',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(left: 10),
                              height: 90,
                              decoration: _glassBoxDecoration(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    '5',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Wishlist',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(left: 10),
                              height: 90,
                              decoration: _glassBoxDecoration(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    '₹12',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Due Fine',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Issued Books section
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Issued Books',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: List.generate(
                          3,
                          (i) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            height: 60,
                            decoration: _glassItemDecoration(),
                            child: ListTile(
                              leading: Icon(
                                Icons.menu_book_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 32,
                              ),
                              title: Text(
                                'Book Title ${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                'Author Name',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white.withOpacity(0.5),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Recommendations
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Book recommended for you',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 200,
                              decoration: _glassCardDecoration(),
                              child: _bookIcon(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Container(
                              height: 200,
                              decoration: _glassCardDecoration(),
                              child: _bookIcon(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 200,
                              decoration: _glassCardDecoration(),
                              child: _bookIcon(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Container(
                              height: 200,
                              decoration: _glassCardDecoration(),
                              child: _bookIcon(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
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

// Reusable decorations
BoxDecoration _glassBoxDecoration() => BoxDecoration(
  color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.35),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
);

BoxDecoration _glassItemDecoration() => BoxDecoration(
  color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.35),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
);

BoxDecoration _glassCardDecoration() => BoxDecoration(
  color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.35),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
);

Widget _bookIcon() => Center(
  child: Icon(
    Icons.book_outlined,
    color: Colors.white.withOpacity(0.7),
    size: 36,
  ),
);
