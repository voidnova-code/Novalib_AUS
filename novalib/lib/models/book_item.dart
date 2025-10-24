import 'package:flutter/foundation.dart';

class BookItem {
  final String title;
  final String author;
  final String isbn;
  final String publisher;
  final String? cover;
  final bool available;
  final Map<String, dynamic> raw;

  BookItem({
    required this.title,
    required this.author,
    required this.isbn,
    required this.publisher,
    required this.cover,
    required this.available,
    required this.raw,
  });

  static bool _toBool(dynamic v) {
    if (v == null) return false;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  factory BookItem.fromJson(Map<String, dynamic> m) {
    final title = (m['book_title'] ?? '').toString();
    final author = (m['book_author'] ?? m['auther'] ?? '').toString();
    final isbn = (m['book_isbn'] ?? '').toString();
    final publisher = (m['book_publisher'] ?? '').toString();
    final cover = (m['book_cover'] ?? '').toString();
    final available = _toBool(m['avalible'] ?? m['available']);
    return BookItem(
      title: title,
      author: author,
      isbn: isbn,
      publisher: publisher,
      cover: cover.isEmpty ? null : cover,
      available: available,
      raw: m,
    );
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) =>
      'BookItem(title: $title, author: $author, isbn: $isbn, available: $available)';
}
