import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class WishListPage extends StatefulWidget {
  final String username;
  final bool useAltBackground;
  final String? userBarcode;

  const WishListPage({
    Key? key,
    required this.username,
    required this.useAltBackground,
    this.userBarcode,
  }) : super(key: key);

  static Route route({
    required String username,
    required bool useAltBackground,
    String? userBarcode,
  }) {
    return MaterialPageRoute(
      builder: (_) => WishListPage(
        username: username,
        useAltBackground: useAltBackground,
        userBarcode: userBarcode,
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

      final uname = widget.username.trim();
      final barcode = (widget.userBarcode ?? '').trim();
      final unameEnc = Uri.encodeComponent(uname);
      final barcodeEnc = Uri.encodeComponent(barcode);

      final attempts = <Uri>[
        if (barcode.isNotEmpty)
          Uri.parse('$baseUrl/user-wishlist/?barcode=$barcodeEnc'),
        Uri.parse('$baseUrl/user-wishlist/?username=$unameEnc'),
        Uri.parse('$baseUrl/user-wishlist/?email=$unameEnc'),
        if (int.tryParse(uname) != null)
          Uri.parse('$baseUrl/user-wishlist/?user_id=$uname'),
        if (barcode.isNotEmpty)
          Uri.parse('$baseUrl/book-log/?barcode=$barcodeEnc&wishlist=1'),
        Uri.parse('$baseUrl/book-log/?username=$unameEnc&wishlist=1'),
        Uri.parse('$baseUrl/book-log/?email=$unameEnc&wishlist=1'),
      ];

      List<Map<String, String>> found = [];
      for (final url in attempts) {
        found = await _try(url);
        if (found.isNotEmpty) break;
      }

      if (!mounted) return;

      setState(() {
        _books = found;
        if (_books.isEmpty) _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Network error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Wishlist'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          const Positioned.fill(child: AnimatedBg()),
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
                        decoration: AppDecorations.rowMint(),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 56,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C3AED),
                                      AppColors.accent,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: (book['cover'] ?? '').isNotEmpty
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
                                        size: 28,
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
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    book['author'] ?? '',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppColors.muted,
                              size: 18,
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
