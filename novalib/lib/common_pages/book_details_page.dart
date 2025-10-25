import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

import '../theme.dart';
import '../models/book_item.dart';

class BookDetailsPage extends StatefulWidget {
  final BookItem book;
  // added: identity to check wishlist server-side
  final String? username;
  final String? userBarcode;

  const BookDetailsPage({
    Key? key,
    required this.book,
    this.username, // added
    this.userBarcode, // added
  }) : super(key: key);

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  String? _scannedCode;
  // Wishlist state
  bool _inWishlist = false;
  bool _wishLoading = false;

  late final String _base; // added
  bool _initChecked = false; // added

  @override
  void initState() {
    super.initState();
    _base = djangoBaseUrl.endsWith('/')
        ? djangoBaseUrl.substring(0, djangoBaseUrl.length - 1)
        : djangoBaseUrl;
    // kick off server check
    _checkWishlistStatus(); // added
  }

  Future<void> _checkWishlistStatus() async {
    // Require some user identifier to check wishlist
    final userBarcode = (widget.userBarcode ?? '').trim();
    final username = (widget.username ?? '').trim();
    if (userBarcode.isEmpty && username.isEmpty) {
      setState(() => _initChecked = true);
      return;
    }

    final b = widget.book;
    final title = b.title.trim();
    final author = b.author.trim();

    final candidates = <Uri>[
      if (userBarcode.isNotEmpty)
        Uri.parse(
          '$_base/wishlist/?barcode=${Uri.encodeComponent(userBarcode)}'
          '${title.isNotEmpty ? '&search=${Uri.encodeComponent(title)}' : ''}',
        ),
      if (username.isNotEmpty)
        Uri.parse(
          '$_base/wishlist/?username=${Uri.encodeComponent(username)}'
          '${title.isNotEmpty ? '&search=${Uri.encodeComponent(title)}' : ''}',
        ),
      if (userBarcode.isNotEmpty)
        Uri.parse(
          '$_base/api/wishlist/?barcode=${Uri.encodeComponent(userBarcode)}'
          '${title.isNotEmpty ? '&search=${Uri.encodeComponent(title)}' : ''}',
        ),
      if (username.isNotEmpty)
        Uri.parse(
          '$_base/api/wishlist/?username=${Uri.encodeComponent(username)}'
          '${title.isNotEmpty ? '&search=${Uri.encodeComponent(title)}' : ''}',
        ),
    ];

    bool found = false;
    for (final u in candidates) {
      try {
        final r = await http.get(u).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final data = json.decode(r.body);
          if (data is List) {
            final tNorm = title.toLowerCase();
            final aNorm = author.toLowerCase();
            for (final e in data) {
              if (e is Map) {
                final et = ((e['book_title'] ?? '') as String)
                    .trim()
                    .toLowerCase();
                final ea = ((e['book_author'] ?? '') as String)
                    .trim()
                    .toLowerCase();
                if (et == tNorm && (aNorm.isEmpty || ea == aNorm)) {
                  found = true;
                  break;
                }
              }
            }
            if (found) break;
          }
        }
      } catch (_) {
        // try next candidate
      }
    }
    if (!mounted) return;
    setState(() {
      _inWishlist = found;
      _initChecked = true;
    });
  }

  Future<void> _openScanner() async {
    _scannedCode = null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _ScannerView(
          onCode: (code) {
            Navigator.of(context).pop();
            setState(() => _scannedCode = code);
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Scanned: $code (copied)')));
          },
        ),
      ),
    );
  }

  // Replace the old toggle to only "add" and persist
  Future<void> _toggleWishlist() async {
    if (_wishLoading || _inWishlist) return;
    setState(() => _wishLoading = true);
    try {
      final b = widget.book;
      final payload = <String, dynamic>{
        // user identity (one of these should be present)
        if ((widget.userBarcode ?? '').isNotEmpty)
          'user_barcode': widget.userBarcode,
        if ((widget.username ?? '').isNotEmpty) 'username': widget.username,
        // book identifiers
        if (b.isbn.isNotEmpty) 'isbn': b.isbn,
        if (b.title.isNotEmpty) 'title': b.title,
        if (b.author.isNotEmpty) 'author': b.author,
        if (b.publisher.isNotEmpty) 'publisher': b.publisher,
        if (b.cover != null && b.cover!.isNotEmpty) 'cover': b.cover,
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final endpoints = <Uri>[
        Uri.parse('$_base/wishlist/'),
        Uri.parse('$_base/api/wishlist/'),
      ];

      Exception? lastErr;
      for (final u in endpoints) {
        try {
          final resp = await http
              .post(u, headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 10));
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            if (!mounted) return;
            setState(() => _inWishlist = true);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Added to wishlist')));
            setState(() => _wishLoading = false);
            return;
          } else {
            lastErr = Exception('POST $u -> ${resp.statusCode}: ${resp.body}');
          }
        } catch (e) {
          lastErr = Exception('POST failed: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add to wishlist${lastErr != null ? ': $lastErr' : ''}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _wishLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Book details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBg()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card with cover + info
                  Container(
                    decoration: AppDecorations.cardPearl(),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 92,
                            height: 120,
                            color: AppColors.accent.withOpacity(0.12),
                            child: b.cover != null
                                ? Image.network(
                                    b.cover!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.menu_book_rounded,
                                      color: AppColors.muted,
                                      size: 32,
                                    ),
                                  )
                                : const Icon(
                                    Icons.menu_book_rounded,
                                    color: AppColors.muted,
                                    size: 32,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.title.isEmpty ? '(Untitled)' : b.title,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                b.author,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              if (b.publisher.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Publisher: ${b.publisher}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                              if (b.isbn.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'ISBN: ${b.isbn}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Availability
                  Container(
                    decoration: AppDecorations.cardPearl(),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _AvailabilityChip(available: b.available),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            b.available
                                ? 'This book appears to be available.'
                                : 'This book is currently issued.',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Wishlist button (shows red heart if already in wishlist)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: _wishLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : Icon(
                              _inWishlist
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _inWishlist
                                  ? Colors.red
                                  : AppColors.accent,
                            ),
                      label: Text(
                        _inWishlist ? 'Added to wishlist' : 'Add to wishlist',
                        style: const TextStyle(color: AppColors.accent),
                      ),
                      onPressed: (_wishLoading || _inWishlist || !_initChecked)
                          ? null
                          : _toggleWishlist,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.accent,
                          width: 1.2,
                        ),
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (b.available)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan book barcode'),
                        onPressed: _openScanner,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (_scannedCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: AppDecorations.cardPearl(),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Scanned barcode: $_scannedCode',
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _scannedCode!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied')),
                              );
                            },
                            child: const Text('Copy'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerView extends StatefulWidget {
  final void Function(String code) onCode;
  const _ScannerView({Key? key, required this.onCode}) : super(key: key);

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_done) return;
    final codes = cap.barcodes;
    if (codes.isEmpty) return;
    final raw = codes.first.rawValue ?? '';
    if (raw.isEmpty) return;
    _done = true;
    widget.onCode(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        // Simple overlay
        Positioned(
          left: 20,
          right: 20,
          top: 24,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _controller.toggleTorch(),
                icon: const Icon(Icons.flashlight_on, color: Colors.white),
              ),
              IconButton(
                onPressed: () => _controller.switchCamera(),
                icon: const Icon(Icons.cameraswitch, color: Colors.white),
              ),
            ],
          ),
        ),
        // Framing guide
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  final bool available;
  const _AvailabilityChip({Key? key, required this.available})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color bg = available ? Colors.green : Colors.red;
    final String text = available ? 'Available' : 'Unavailable';
    final IconData icon = available ? Icons.check_circle : Icons.cancel;

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: bg,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
