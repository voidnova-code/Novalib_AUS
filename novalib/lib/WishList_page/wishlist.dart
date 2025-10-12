import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart'; // reuse djangoBaseUrl and theme helpers if present
import 'package:flutter/services.dart';

class WishListPage extends StatefulWidget {
  final String username;
  final bool useAltBackground; // NEW

  const WishListPage({
    Key? key,
    required this.username,
    required this.useAltBackground, // NEW
  }) : super(key: key);

  // allow navigation via route with arguments Map
  static Route route({
    required String username,
    required bool useAltBackground, // NEW
  }) {
    return MaterialPageRoute(
      builder: (_) => WishListPage(
        username: username,
        useAltBackground: useAltBackground, // NEW
      ),
    );
  }

  @override
  State<WishListPage> createState() => _WishListPageState();
}

class _WishListPageState extends State<WishListPage> {
  bool _isLoading = false;
  List<Map<String, String>> _books = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final baseUrl = djangoBaseUrl.endsWith('/')
          ? djangoBaseUrl.substring(0, djangoBaseUrl.length - 1)
          : djangoBaseUrl;

      // Helper to perform a GET and parse list results (empty list on any failure)
      Future<List<Map<String, String>>> _try(Uri url) async {
        try {
          final resp = await http.get(url).timeout(const Duration(seconds: 8));
          if (resp.statusCode != 200) return [];
          final body = json.decode(resp.body);
          if (body is! List) return [];
          return body.map<Map<String, String>>((item) {
            final m = item as Map<String, dynamic>;
            return {
              'title': (m['book_title'] ?? '').toString(),
              'author': (m['book_author'] ?? m['auther'] ?? '').toString(),
              'issued_date': (m['issued_date'] ?? '').toString(),
              'return_date': (m['return_date'] ?? '').toString(),
              'cover': (m['book_cover'] ?? '').toString(),
              'barcode': (m['book_barcode'] ?? '').toString(),
            };
          }).toList();
        } catch (_) {
          return [];
        }
      }

      // Candidate attempts using User-table resolution, then legacy book-log fallback
      final uname = Uri.encodeComponent(widget.username);
      final attempts = <Uri>[
        // Resolve via User table first (username may be display name or login username)
        Uri.parse('$baseUrl/user-wishlist/?username=$uname'),
        Uri.parse('$baseUrl/user-wishlist/?barcode=$uname'),
        Uri.parse('$baseUrl/user-wishlist/?email=$uname'),
        if (int.tryParse(widget.username) != null)
          Uri.parse('$baseUrl/user-wishlist/?user_id=${widget.username}'),
        // Fallback to existing book-log wishlist filter (if backend supports it)
        Uri.parse('$baseUrl/book-log/?username=$uname&wishlist=1'),
        Uri.parse('$baseUrl/book-log/?barcode=$uname&wishlist=1'),
        Uri.parse('$baseUrl/book-log/?email=$uname&wishlist=1'),
      ];

      List<Map<String, String>> found = [];
      for (final url in attempts) {
        found = await _try(url);
        if (found.isNotEmpty) break;
      }

      if (!mounted) return;

      setState(() {
        _books = found;
        if (_books.isEmpty) {
          _error = null; // No items but not a hard error
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Reuse lightweight glass decoration
  BoxDecoration _glassBoxDecoration() => BoxDecoration(
    color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.35),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Wishlist'),
        backgroundColor: const Color.fromARGB(104, 0, 0, 0),
        elevation: 0,
        shadowColor: const Color.fromARGB(0, 0, 0, 0),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWishlist,
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // background image to match login/home
          Positioned.fill(
            child: Image.asset(
              widget.useAltBackground
                  ? 'assets/background2.jpg'
                  : 'assets/background1.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // gradient overlay
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
          // existing content on top of background
          SafeArea(
            child: _isLoading && _books.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  )
                : _books.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 40),
                      Center(
                        child: Text(
                          'No items in your wishlist.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _books.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final book = _books[i];
                      return Container(
                        decoration: _glassBoxDecoration(),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                color: const Color(0xFF5B6BFF),
                                width: 56,
                                height: 72,
                                child:
                                    book['cover'] != null &&
                                        book['cover']!.isNotEmpty
                                    ? Image.network(
                                        book['cover']!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.book,
                                              color: Colors.white54,
                                            ),
                                      )
                                    : const Icon(
                                        Icons.menu_book_rounded,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book['title'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    book['author'] ?? '',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if ((book['issued_date'] ?? '')
                                          .isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            'Issued: ${book['issued_date']}',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      if ((book['return_date'] ?? '')
                                          .isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            'Return: ${book['return_date']}',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: () {
                                // placeholder: can navigate to book detail later
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
