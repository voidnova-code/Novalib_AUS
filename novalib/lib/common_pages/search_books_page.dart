import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/book_item.dart';

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
  // Computed availability aligned with _results
  List<bool> _availabilities = [];
  bool _modeAll = false; // when true, show all books (available + unavailable)

  String get _base => djangoBaseUrl.endsWith('/')
      ? djangoBaseUrl.substring(0, djangoBaseUrl.length - 1)
      : djangoBaseUrl;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Normalize bool-like values from API fields
  bool? _toBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'true' ||
        s == 'yes' ||
        s == 'y' ||
        s == 'available' ||
        s == 'avail')
      return true;
    if (s == 'false' ||
        s == 'no' ||
        s == 'n' ||
        s == 'unavailable' ||
        s == 'na')
      return false;
    final n = int.tryParse(s);
    if (n != null) return n != 0;
    return null;
  }

  // Heuristic availability from raw map
  bool _computeAvailable(Map<String, dynamic> m) {
    // use explicit flags when present
    for (final k in [
      'available',
      'is_available',
      'avalible',
      'available_flag',
    ]) {
      final b = _toBool(m[k]);
      if (b != null) return b;
    }
    // inverse of issued flag
    for (final k in ['issued', 'is_issued', 'issued_flag']) {
      final b = _toBool(m[k]);
      if (b != null) return !b;
    }
    // status text
    final status = (m['status'] ?? m['book_status'] ?? '')
        .toString()
        .toLowerCase();
    if (status.contains('available')) return true;
    if (status.contains('issued') ||
        status.contains('unavailable') ||
        status.contains('not available')) {
      return false;
    }
    // if an issue date is present and no return date, treat as issued
    final hasIssued = (m['issued_date'] ?? '').toString().trim().isNotEmpty;
    final hasReturned = (m['return_date'] ?? '').toString().trim().isNotEmpty;
    if (hasIssued && !hasReturned) return false;
    // copies count
    final ac =
        (m['available_copies'] ?? m['copies_available'] ?? m['free_copies']);
    final tc = (m['total_copies'] ?? m['copies_total']);
    final acNum = ac is num ? ac.toInt() : int.tryParse((ac ?? '').toString());
    final tcNum = tc is num ? tc.toInt() : int.tryParse((tc ?? '').toString());
    if (acNum != null && acNum >= 0) {
      if (tcNum != null && tcNum > 0) return acNum > 0;
      return acNum > 0;
    }
    // default safer: unknown -> not available
    return false;
  }

  void _onQueryChanged(String q) {
    setState(() => _query = q);
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _availabilities = [];
        _modeAll = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(q.trim());
    });
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final ql = q.toLowerCase().trim();
      // "all" => list ALL books (available + unavailable)
      final wantAllBooks =
          ql == 'all' || ql == 'all books' || ql == 'everything';
      // "available" => list only available books
      final wantOnlyAvailable =
          ql == 'available' || ql == 'available books' || ql == 'all available';
      _modeAll = wantAllBooks;
      final rel = wantAllBooks
          ? '/book-log/'
          : (wantOnlyAvailable
                ? '/book-log/?avalible=1'
                : '/book-log/?search=${Uri.encodeComponent(q)}');
      final candidates = <Uri>[
        Uri.parse('$_base$rel'),
        Uri.parse('$_base/api$rel'),
      ];
      List<BookItem> items = [];
      List<bool> avs = [];
      for (final u in candidates) {
        try {
          final r = await http.get(u).timeout(const Duration(seconds: 8));
          debugPrint('GET $u -> ${r.statusCode}');
          if (r.statusCode == 200) {
            final data = json.decode(r.body);
            if (data is List) {
              items = [];
              avs = [];
              for (final e in data) {
                if (e is Map<String, dynamic>) {
                  items.add(BookItem.fromJson(e));
                  avs.add(_computeAvailable(e));
                }
              }
              break;
            } else if (data is Map && data['results'] is List) {
              // Optional: support paginated responses
              final list = (data['results'] as List);
              items = [];
              avs = [];
              for (final e in list) {
                if (e is Map<String, dynamic>) {
                  items.add(BookItem.fromJson(e));
                  avs.add(_computeAvailable(e));
                }
              }
              break;
            } else if (data is Map && data['data'] is List) {
              final list = (data['data'] as List);
              items = [];
              avs = [];
              for (final e in list) {
                if (e is Map<String, dynamic>) {
                  items.add(BookItem.fromJson(e));
                  avs.add(_computeAvailable(e));
                }
              }
              break;
            }
          }
        } catch (e) {
          debugPrint('Search error for $u: $e');
        }
      }
      if (!mounted) return;
      setState(() {
        _results = items;
        _availabilities = avs;
      });
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
                      hintText:
                          'Search by title or author (or try "all" for all books)',
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
                if (_modeAll)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Showing all books (available and issued)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                                  // Push on root navigator using named route
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pushNamed(
                                    '/book_details',
                                    arguments: b, // BookItem
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
                                      _AvailabilityChip(
                                        available: (i < _availabilities.length)
                                            ? _availabilities[i]
                                            : b.available,
                                      ),
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
    final bg = available
        ? Colors.green.withOpacity(0.12)
        : Colors.red.withOpacity(0.12);
    final fg = available ? Colors.green[800]! : Colors.red[800]!;
    final icon = available ? Icons.check_circle : Icons.cancel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 16),
          const SizedBox(width: 6),
          Text(
            available ? 'Available' : 'Unavailable',
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
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
