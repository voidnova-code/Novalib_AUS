import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../theme.dart';

class IssuedBooksPage extends StatefulWidget {
  final String username;
  final String? userBarcode;

  const IssuedBooksPage({Key? key, required this.username, this.userBarcode})
    : super(key: key);

  @override
  State<IssuedBooksPage> createState() => _IssuedBooksPageState();
}

class _IssuedBooksPageState extends State<IssuedBooksPage> {
  bool _loading = true;
  List<Map<String, String>> _books = [];

  @override
  void initState() {
    super.initState();
    _fetchIssuedBooks();
  }

  Future<void> _fetchIssuedBooks() async {
    setState(() => _loading = true);

    List<Map<String, String>> parseList(dynamic body) {
      if (body is! List) return [];
      return body
          .map<Map<String, String>>((item) {
            final m = item as Map<String, dynamic>;
            return {
              'title': (m['book_title'] ?? '').toString(),
              'author': (m['book_author'] ?? m['auther'] ?? '').toString(),
              'issued_date': (m['issued_date'] ?? '').toString(),
              'return_date': (m['return_date'] ?? '').toString(),
            };
          })
          .where((m) => (m['title'] ?? '').isNotEmpty)
          .toList();
    }

    Future<List<Map<String, String>>> tryUrl(Uri url) async {
      try {
        final r = await http.get(url).timeout(const Duration(seconds: 8));
        if (r.statusCode != 200) return [];
        return parseList(json.decode(r.body));
      } catch (_) {
        return [];
      }
    }

    try {
      final base = djangoBaseUrl.endsWith('/')
          ? djangoBaseUrl.substring(0, djangoBaseUrl.length - 1)
          : djangoBaseUrl;
      final uname = Uri.encodeComponent(widget.username);
      final barcode = widget.userBarcode != null
          ? Uri.encodeComponent(widget.userBarcode!)
          : '';

      final attempts = <Uri>[
        if (barcode.isNotEmpty)
          Uri.parse('$base/book-log/?barcode=$barcode&avalible=0'),
        if (barcode.isNotEmpty) Uri.parse('$base/book-log/?barcode=$barcode'),
        Uri.parse('$base/book-log/?username=$uname&avalible=0'),
        Uri.parse('$base/book-log/?username=$uname'),
        Uri.parse('$base/book-log/?email=$uname&avalible=0'),
        if (int.tryParse(widget.username) != null)
          Uri.parse('$base/book-log/?user_id=${widget.username}&avalible=0'),
        Uri.parse('$base/book-log/?avalible=0'),
        Uri.parse('$base/book-log/'),
      ];

      List<Map<String, String>> found = [];
      for (final u in attempts) {
        found = await tryUrl(u);
        if (found.isNotEmpty) break;
      }

      if (!mounted) return;
      setState(() {
        _books = found;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _books = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Issued Books',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _fetchIssuedBooks,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBg()),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _books.isEmpty
                ? const Center(
                    child: Text(
                      'No books found.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _books.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Container(
                          decoration: AppDecorations.itemBlush(),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          child: Text(
                            'Total: ${_books.length}',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }
                      final b = _books[i - 1];
                      return Container(
                        decoration: AppDecorations.rowMint(),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), AppColors.accent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                          title: Text(
                            b['title'] ?? '',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            b['author'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.muted,
                          ),
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
