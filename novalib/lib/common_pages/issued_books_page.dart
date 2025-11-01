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
  dynamic _rawApiData; // <-- Add this line

  @override
  void initState() {
    super.initState();
    _fetchIssuedBooks();
  }

  Future<void> _fetchIssuedBooks() async {
    setState(() {
      _loading = true;
      _rawApiData = null;
    });

    // Resilient list fetcher (supports wrappers)
    Future<List<Map<String, dynamic>>> _getJsonList(Uri url) async {
      try {
        final r = await http.get(url).timeout(const Duration(seconds: 12));
        if (r.statusCode != 200) return [];
        final decoded = json.decode(r.body);

        List items;
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map) {
          if (decoded['results'] is List) {
            items = decoded['results'];
          } else if (decoded['data'] is List) {
            items = decoded['data'];
          } else if (decoded['items'] is List) {
            items = decoded['items'];
          } else if (decoded['rows'] is List) {
            items = decoded['rows'];
          } else {
            return [];
          }
        } else {
          return [];
        }

        final out = <Map<String, dynamic>>[];
        for (final e in items) {
          if (e is Map) out.add(e.map((k, v) => MapEntry(k.toString(), v)));
        }
        return out;
      } catch (_) {
        return [];
      }
    }

    // Match against books-detail "username" primarily (fallbacks kept)
    bool _matchesUserFromDetails(Map<String, dynamic> m) {
      String _norm(String s) => s.trim().toLowerCase();
      final userStr = (m['username'] ?? m['user'] ?? m['issued_to'] ?? '')
          .toString()
          .toLowerCase();
      if (userStr.isEmpty) return false;
      final uname = _norm(widget.username);
      final ucode = _norm(widget.userBarcode ?? '');
      if (uname.isNotEmpty && userStr.contains(uname)) return true;
      if (ucode.isNotEmpty && userStr.contains(ucode)) return true;
      if (uname.isNotEmpty && int.tryParse(uname) != null)
        return userStr.contains(uname);
      return false;
    }

    try {
      final base = djangoBaseUrl.endsWith('/')
          ? djangoBaseUrl.substring(0, djangoBaseUrl.length - 1)
          : djangoBaseUrl;

      // Try server-side availability filtering first (available=false)
      final attempts = <Uri>[
        Uri.parse('$base/books-detail/?available=0'),
        Uri.parse('$base/books-detail/?available=false'),
        Uri.parse(
          '$base/books-detail/?avalible=0',
        ), // fallback if typo on backend
        Uri.parse('$base/books-detail/'),
      ];

      List<Map<String, dynamic>> rows = [];
      for (final u in attempts) {
        rows = await _getJsonList(u);
        if (rows.isNotEmpty) break;
      }
      _rawApiData = rows;

      // Only books held by this user => rows where username matches
      final heldForUser = rows.where(_matchesUserFromDetails).toList();

      // Map using table fields
      String _pickS(Map<String, dynamic> m, List<String> keys) {
        for (final k in keys) {
          final v = m[k];
          if (v == null) continue;
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
        return '';
      }

      final result = heldForUser
          .map<Map<String, String>>((m) {
            return {
              'title': _pickS(m, ['book_title', 'title']),
              'author': _pickS(m, ['book_author', 'author']),
              'issued_date': _pickS(m, ['issued_date']),
              'return_date': _pickS(m, ['return_date']),
            };
          })
          .where((m) => (m['title'] ?? '').isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _books = result;
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
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 100),
                        const Text(
                          'No books found.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_rawApiData != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.black12,
                            child: Text(
                              'API Response:\n${_rawApiData.toString()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
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
