import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/book_item.dart';
import 'book_details_page.dart';

// Local tokens and row decoration (kept here)
const _ink = Color(0xFF1F2544);
const _muted = Color(0xFF6B7280);
const _accent = Color(0xFF5B6BFF);

class SearchBooksPage extends StatefulWidget {
  final String username;
  final String? userBarcode;

  const SearchBooksPage({Key? key, required this.username, this.userBarcode})
    : super(key: key);

  @override
  State<SearchBooksPage> createState() => _SearchBooksPageState();
}

class _SearchBooksPageState extends State<SearchBooksPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String _query = '';
  List<BookItem> _results = [];

  String get _base => djangoBaseUrl.endsWith('/')
      ? djangoBaseUrl.substring(0, djangoBaseUrl.length - 1)
      : djangoBaseUrl;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    setState(() => _query = q);
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(q.trim());
    });
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final rel = '/book-log/?search=${Uri.encodeComponent(q)}';
      final candidates = <Uri>[
        Uri.parse('$_base$rel'),
        Uri.parse('$_base/api$rel'),
      ];
      List<BookItem> items = [];
      for (final u in candidates) {
        try {
          final r = await http.get(u).timeout(const Duration(seconds: 8));
          debugPrint('GET $u -> ${r.statusCode}');
          if (r.statusCode == 200) {
            final data = json.decode(r.body);
            if (data is List) {
              items = data.map<BookItem>((m) => BookItem.fromJson(m)).toList();
              break;
            }
          }
        } catch (e) {
          debugPrint('Search error for $u: $e');
        }
      }
      if (!mounted) return;
      setState(() => _results = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Search Books',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Static gradient background (lighter on buffers than animated bg)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8D5BFF), Color(0xFFC46BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _controller,
                    onChanged: _onQueryChanged,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                    ),
                    cursorColor: _accent,
                    decoration: InputDecoration(
                      hintText: 'Search by title, author, or ISBN…',
                      hintStyle: const TextStyle(color: _muted),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.96),
                      prefixIcon: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _accent,
                                ),
                              ),
                            )
                          : const Icon(Icons.search, color: _muted),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(
                          color: _accent,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Results
                Expanded(
                  child: _query.isEmpty
                      ? const Center(
                          child: Text(
                            'Start typing to search…',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : _loading && _results.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'No books found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final b = _results[i];
                            final dpr = MediaQuery.of(context).devicePixelRatio;
                            final cacheW = (56 * dpr).round();
                            final cacheH = (72 * dpr).round();
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  debugPrint('Tapped book: ${b.title}');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BookDetailsPage(book: b),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: _rowMint(),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 10,
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
                                                _accent,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: (b.cover ?? '').isNotEmpty
                                              ? Image.network(
                                                  b.cover!,
                                                  fit: BoxFit.cover,
                                                  filterQuality:
                                                      FilterQuality.low,
                                                  cacheWidth: cacheW,
                                                  cacheHeight: cacheH,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              b.title.isEmpty
                                                  ? '(Untitled)'
                                                  : b.title,
                                              style: const TextStyle(
                                                color: _ink,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              b.author,
                                              style: const TextStyle(
                                                color: _muted,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (b.isbn.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'ISBN: ${b.isbn}',
                                                style: const TextStyle(
                                                  color: _muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _AvailabilityChip(available: b.available),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  final bool available;

  const _AvailabilityChip({Key? key, required this.available})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color fg = available
        ? const Color(0xFF166534)
        : const Color(0xFF991B1B);
    final Color bg = available
        ? const Color(0xFFE7F6EC)
        : const Color(0xFFFDE8E8);
    final String label = available ? 'Available' : 'Unavailable';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withOpacity(0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

BoxDecoration _rowMint() => BoxDecoration(
  gradient: const LinearGradient(
    colors: [Color(0xFFF1FBF5), Color(0xFFE8F7EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: const Color(0xFFD1EFDD), width: 1),
  boxShadow: const [
    BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 5)),
  ],
);
