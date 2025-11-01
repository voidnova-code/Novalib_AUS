import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'book_details_page.dart'; // added

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
  bool _loading = false;
  List<BookItem> _results = [];
  List<bool> _availabilities = [];
  List<int> _availableCounts = []; // added

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  String get _base => djangoBaseUrl.endsWith('/')
      ? djangoBaseUrl.substring(0, djangoBaseUrl.length - 1)
      : djangoBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadAllBooks();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Small helper: safe bool parsing (fallback if server 'available' arrives without count)
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

  void _onQueryChanged(String q) {
    setState(() => _query = q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final term = q.trim();
      _loadAllBooks(search: term.isEmpty ? null : term);
    });
  }

  Future<void> _loadAllBooks({String? search}) async {
    setState(() => _loading = true);
    try {
      // Always hit Books Log
      final rel = (search != null && search.trim().isNotEmpty)
          ? '/book-log/?search=${Uri.encodeComponent(search)}'
          : '/book-log/';
      final uri = Uri.parse('$_base$rel');

      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _results = [];
          _availabilities = [];
          _availableCounts = [];
        });
        return;
      }

      final data = json.decode(r.body);
      Iterable list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['results'] is List) {
        list = data['results'];
      } else if (data is Map && data['data'] is List) {
        list = data['data'];
      } else {
        list = const [];
      }

      final items = <BookItem>[];
      final avs = <bool>[];
      final counts = <int>[];

      for (final e in list) {
        if (e is! Map<String, dynamic>) continue;

        // Normalize Books Log JSON to BookItem fields before parsing
        final normalized = <String, dynamic>{
          // BookItem friendly keys
          'title': e['book_title'] ?? e['title'] ?? '',
          'author': e['book_author'] ?? e['auther'] ?? '',
          'isbn': e['book_barcode'] ?? e['isbn'] ?? '',
          // Preserve any existing fields (cover, etc.)
          ...e,
        };

        // Build BookItem
        items.add(BookItem.fromJson(normalized));

        // Count and availability
        final rawCount = e['available_count'];
        final hasCount = rawCount != null;
        final count = rawCount is num
            ? rawCount.toInt()
            : int.tryParse((rawCount ?? '').toString()) ?? 0;

        // If available_count exists, it is authoritative
        final avail = hasCount
            ? (count > 0)
            : (_toBool(e['available']) ?? false);

        counts.add(count);
        avs.add(avail);
      }

      if (!mounted) return;
      setState(() {
        _results = items;
        _availabilities = avs;
        _availableCounts = counts;
      });
    } catch (e) {
      debugPrint('Load books error: $e');
      if (!mounted) return;
      setState(() {
        _results = [];
        _availabilities = [];
        _availableCounts = [];
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
        title: const Text('Books', style: TextStyle(color: Colors.white)),
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
                // Search bar (by title or author)
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
                      hintText: 'Search by book name or author',
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
                      suffixIcon: (_query.isNotEmpty)
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: _muted),
                              onPressed: () {
                                _controller.clear();
                                _onQueryChanged('');
                              },
                            )
                          : null,
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
                Expanded(
                  child: _loading && _results.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'No books found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadAllBooks(
                            search: _query.trim().isEmpty
                                ? null
                                : _query.trim(),
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final b = _results[i];
                              final dpr = MediaQuery.of(
                                context,
                              ).devicePixelRatio;
                              final cacheW = (56 * dpr).round();
                              final cacheH = (72 * dpr).round();
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).push(
                                      MaterialPageRoute(
                                        builder: (_) => BookDetailsPage(
                                          book: b,
                                          username: widget.username,
                                          userBarcode: widget.userBarcode,
                                        ),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: (b.cover ?? '').isNotEmpty
                                                ? Image.network(
                                                    b.cover!,
                                                    fit: BoxFit.cover,
                                                    filterQuality:
                                                        FilterQuality.low,
                                                    cacheWidth: cacheW,
                                                    cacheHeight: cacheH,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => const Icon(
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
                                          available:
                                              (i < _availabilities.length)
                                              ? _availabilities[i]
                                              : false,
                                          count: (i < _availableCounts.length)
                                              ? _availableCounts[i]
                                              : 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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

// Update chip to show count if provided
class _AvailabilityChip extends StatelessWidget {
  final bool available;
  final int? count; // added
  const _AvailabilityChip({Key? key, required this.available, this.count})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = available
        ? Colors.green.withOpacity(0.12)
        : Colors.red.withOpacity(0.12);
    final fg = available ? Colors.green[800]! : Colors.red[800]!;
    final icon = available ? Icons.check_circle : Icons.cancel;
    final label = count == null
        ? (available ? 'Available' : 'Unavailable')
        : (available ? 'Available ($count)' : 'Unavailable ($count)');
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
            label,
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
