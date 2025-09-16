import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart'; // Add this import

// ========== 1. API SERVICE ==========
// Handles all communication with the Django backend.
class ApiService {
  static Future<User?> fetchUserProfile(String studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/students/$studentId/profile/'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return User.fromJson(data);
    } else {
      return null;
    }
  }

  // IMPORTANT: Replace with your computer's network IP address and Django port
  static const String baseUrl = 'http://10.53.7.19:8000';
  static final http.Client _client = http.Client();

  static Future<Map<String, dynamic>> login(String studentId) async {
    print('Logging in with cardnumber: $studentId'); // Debug print
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/login/'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'cardnumber': studentId,
            }, // <-- FIXED: use 'cardnumber' as key
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to login: \\${response.statusCode}');
      }
    } catch (e) {
      print('Login error: $e');
      throw Exception('Failed to login');
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String studentId,
    String otp,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/verify-otp/'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'cardnumber': studentId, 'otp': otp}, // <-- FIXED
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to verify OTP: \\${response.statusCode}');
      }
    } catch (e) {
      print('OTP verification error: $e');
      throw Exception('Failed to verify OTP');
    }
  }

  static Future<List<Book>> getIssuedBooks(String studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/students/$studentId/issued-books/'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Book.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load issued books');
    }
  }

  static Future<List<Book>> getRecommendedBooks() async {
    final response = await http.get(Uri.parse('$baseUrl/books/recommended/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Book.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load recommended books');
    }
  }

  static Future<List<Book>> searchBooks(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/books/?search=$query'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Book.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search books');
    }
  }

  static Future<bool> issueBook(String studentId, String isbn) async {
    final response = await http.post(
      Uri.parse('$baseUrl/issue-book/'),
      body: {'student_id': studentId, 'isbn': isbn},
    );
    return response.statusCode == 200;
  }

  static Future<bool> returnBook(String studentId, String isbn) async {
    final response = await http.post(
      Uri.parse('$baseUrl/return-book/'),
      body: {'student_id': studentId, 'isbn': isbn},
    );
    return response.statusCode == 200;
  }

  static Future<bool> renewBook(String studentId, String isbn) async {
    final response = await http.post(
      Uri.parse('$baseUrl/renew-book/'),
      body: {'student_id': studentId, 'isbn': isbn},
    );
    return response.statusCode == 200;
  }

  static Future<bool> payFine(String studentId, double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pay-fine/'),
      body: {'student_id': studentId, 'amount': amount.toString()},
    );
    return response.statusCode == 200;
  }

  static Future<List<Book>> getWishlist(String studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/students/$studentId/wishlist/'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Book.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load wishlist');
    }
  }

  static Future<bool> addToWishlist(String studentId, String isbn) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add-to-wishlist/'),
      body: {'student_id': studentId, 'isbn': isbn},
    );
    return response.statusCode == 200;
  }

  static Future<bool> removeFromWishlist(String studentId, String isbn) async {
    final response = await http.post(
      Uri.parse('$baseUrl/remove-from-wishlist/'),
      body: {'student_id': studentId, 'isbn': isbn},
    );
    return response.statusCode == 200;
  }

  static Future<bool> updateProfile(
    String studentId,
    String name,
    String email,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update-profile/'),
      body: {'student_id': studentId, 'name': name, 'email': email},
    );
    return response.statusCode == 200;
  }

  static Future<String?> uploadProfilePicture(
    String studentId,
    File imageFile,
  ) async {
    final uri = Uri.parse('$baseUrl/update-profile-picture/');
    final request = http.MultipartRequest('POST', uri)
      ..fields['cardnumber'] = studentId
      ..files.add(
        await http.MultipartFile.fromPath('profile_picture', imageFile.path),
      );
    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      return data['profile_picture_url'];
    } else {
      return null;
    }
  }
}

// ========== DATA MODELS ==========
class Book {
  final String title;
  final String author;
  final String coverUrl;
  final DateTime? dueDate;
  final double fine;
  final bool isDueSoon;
  final bool isReturned;
  final String isbn;
  final bool isAvailable;
  final int renewals;

  Book({
    required this.title,
    required this.author,
    required this.coverUrl,
    this.dueDate,
    this.fine = 0.0,
    this.isDueSoon = false,
    this.isReturned = false,
    required this.isbn,
    required this.isAvailable,
    this.renewals = 0,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverUrl:
          json['cover_url'] ??
          'https://placehold.co/150x230/8686AC/ffffff?text=No+Image',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'])
          : null,
      fine: (json['fine'] ?? 0).toDouble(),
      isDueSoon: json['is_due_soon'] ?? false,
      isReturned: json['is_returned'] ?? false,
      isbn: json['isbn'] ?? '',
      isAvailable: json['is_available'] ?? false,
      renewals: json['renewals'] ?? 0,
    );
  }

  bool get canRenew => renewals < 1; // Only one renewal allowed
}

class User {
  final String studentId;
  final String name;
  final String email;
  final String phone;
  final String department; // <-- Add department
  final String? profileImageUrl;

  User({
    required this.studentId,
    required this.name,
    required this.email,
    required this.phone,
    required this.department, // <-- Add department
    this.profileImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      studentId: json['student_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      department: json['department'] ?? '', // <-- Add department
      profileImageUrl: json['profile_image_url'],
    );
  }
}

// ========== DATA MANAGEMENT ==========
class AppData {
  static String? studentId;
  static User? currentUser;
  static List<Book> issuedBooks = [];
  static List<Book> recommendedBooks = [];
  static List<Book> wishlistBooks = [];
  static List<Book> catalogBooks = [];

  static Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    studentId = prefs.getString('student_id');

    // Fetch user profile from backend for sync
    if (studentId != null) {
      final user = await ApiService.fetchUserProfile(studentId!);
      if (user != null) {
        currentUser = user;
        // Optionally, update local storage with backend data
        await prefs.setString('user_name', user.name);
        await prefs.setString('user_email', user.email);
        await prefs.setString('user_phone', user.phone);
        await prefs.setString(
          'user_department',
          user.department,
        ); // <-- Add department
        if (user.profileImageUrl != null) {
          await prefs.setString('profile_image_url', user.profileImageUrl!);
        }
      }
      try {
        issuedBooks = await ApiService.getIssuedBooks(studentId!);
        recommendedBooks = await ApiService.getRecommendedBooks();
        wishlistBooks = await ApiService.getWishlist(studentId!);
        recommendedBooks = recommendedBooks
            .where((book) => book.isAvailable)
            .toList();
        catalogBooks = [...issuedBooks, ...recommendedBooks];
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  static Future<void> saveUserData(User user) async {
    currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_phone', user.phone);
    await prefs.setString(
      'user_department',
      user.department,
    ); // <-- Add department
  }

  static Future<void> saveStudentId(String id) async {
    studentId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_id', id);
  }

  static Future<void> clearUserData() async {
    studentId = null;
    currentUser = null;
    issuedBooks = [];
    recommendedBooks = [];
    wishlistBooks = [];
    catalogBooks = [];

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

void main() {
  runApp(const MyApp());
}

// ========== THEME MANAGEMENT ==========
class AppTheme {
  static final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    textTheme: GoogleFonts.poppinsTextTheme(),
  );
  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
  );
}

// ========== MAIN APP WIDGET ==========
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NovaLib',
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: LoginPage(onThemeToggle: _toggleTheme),
    );
  }
}

// ========== 1. LOGIN PAGE ==========
class LoginPage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  const LoginPage({super.key, required this.onThemeToggle});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _studentIdController = TextEditingController();
  String? _errorText;
  bool _isLoading = false;

  void _sendOtp() async {
    final studentId = _studentIdController.text;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final response = await ApiService.login(studentId);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationPage(
              studentId: studentId,
              phoneNumber: response['phone'],
              onThemeToggle: widget.onThemeToggle,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = "Connection failed. Please check your network.";
        });
      }
    }
  }

  Future<void> _scanBarcode() async {
    final String? barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );
    if (barcode != null && mounted) {
      setState(() {
        _studentIdController.text = barcode;
        _errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_library_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  "Welcome to NovaLib",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Enter your Student ID to begin",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _studentIdController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: "Student ID",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: _errorText,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text("Scan Student ID"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Send OTP",
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========== 2. OTP VERIFICATION PAGE ==========
class OTPVerificationPage extends StatefulWidget {
  final String studentId;
  final String phoneNumber;
  final VoidCallback onThemeToggle;

  const OTPVerificationPage({
    super.key,
    required this.studentId,
    required this.phoneNumber,
    required this.onThemeToggle,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final _otpController = TextEditingController();
  String? _errorText;
  bool _isLoading = false;

  void _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final response = await ApiService.verifyOtp(
        widget.studentId,
        _otpController.text,
      );

      if (response['success']) {
        if (response['user'] != null) {
          AppData.currentUser = User.fromJson(response['user']);
          await AppData.saveUserData(AppData.currentUser!);
        }

        await AppData.saveStudentId(widget.studentId);
        await AppData.loadUserData();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  MainScreen(onThemeToggle: widget.onThemeToggle),
            ),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorText = "Invalid OTP. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = "Verification failed. Please try again.";
      });
    }
  }

  void _resendOtp() async {
    try {
      await ApiService.login(widget.studentId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("New OTP Sent!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to resend OTP: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Enter the OTP sent to",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.phoneNumber,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, letterSpacing: 12),
                decoration: InputDecoration(
                  counterText: "",
                  labelText: "6-Digit OTP",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _errorText,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Verify & Login",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _resendOtp,
                child: const Text("Didn't receive code? Resend OTP"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== MAIN SCREEN (WITH BOTTOM NAV) ==========
class MainScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  const MainScreen({super.key, required this.onThemeToggle});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomePage(onNavigate: _onItemTapped, onThemeToggle: widget.onThemeToggle),
      const IssuedBooksPage(),
      const PayFinePage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const <Widget>[
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.book_rounded),
            label: 'Issued',
          ),
          NavigationDestination(
            icon: Icon(Icons.payment_rounded),
            label: 'Fines',
          ),
        ],
      ),
    );
  }
}

// ========== 1. HOME PAGE ==========
class HomePage extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback onThemeToggle;
  const HomePage({
    super.key,
    required this.onNavigate,
    required this.onThemeToggle,
  });
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Book> _filteredBooks;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await AppData.loadUserData();
      setState(() {
        _filteredBooks = AppData.catalogBooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
    }
  }

  // Removed unused _onSearchChanged method

  Future<void> _issueBook() async {
    String? isbn = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );

    if (isbn == null || isbn.isEmpty) {
      final ctrl = TextEditingController();
      isbn = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Enter Book Barcode'),
          content: TextField(controller: ctrl),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Issue'),
            ),
          ],
        ),
      );
    }
    if (isbn != null && isbn.isNotEmpty && AppData.studentId != null) {
      final success = await ApiService.issueBook(AppData.studentId!, isbn);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Issued successfully (30 days)' : 'Issue failed',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        await _loadData();
      }
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notifications"),
        content: const Text("No new notifications."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final borrowedCount = AppData.issuedBooks
        .where((b) => !b.isReturned)
        .length;
    final dueSoonCount = AppData.issuedBooks
        .where((b) => b.isDueSoon && !b.isReturned)
        .length;
    final totalFine = AppData.issuedBooks
        .where((b) => !b.isReturned)
        .fold<double>(0, (sum, book) => sum + book.fine);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: AppDrawer(onThemeToggle: widget.onThemeToggle),
      appBar: AppBar(
        title: const Text("NovaLib"),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: "Notifications",
            onPressed: _showNotifications,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome, " + (AppData.currentUser?.name ?? "User") + " 😁",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                readOnly: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchPage()),
                  );
                },
                decoration: InputDecoration(
                  hintText: "Search books...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onNavigate(2),
                      child: _buildStatCard(
                        "Borrowed",
                        borrowedCount.toString(),
                        Colors.blue,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onNavigate(2),
                      child: _buildStatCard(
                        "Due Soon",
                        dueSoonCount.toString(),
                        Colors.orange,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onNavigate(3),
                      child: _buildStatCard(
                        "Fine",
                        "₹${totalFine.toStringAsFixed(0)}",
                        Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "Issued Books",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_filteredBooks.isNotEmpty)
                ..._filteredBooks.map(
                  (book) =>
                      _buildBookCard(book: book, onNavigate: widget.onNavigate),
                )
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      "No issued books match your search.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                "Recommended for You",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppData.recommendedBooks.length >= 5
                      ? 5
                      : AppData.recommendedBooks.length,
                  itemBuilder: (context, index) {
                    final book = (AppData.recommendedBooks.toList()
                      ..shuffle())[index];
                    return _buildRecommendedCardWithImage(book);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Issue Book'),
        onPressed: _issueBook,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildBookCard({
    required Book book,
    required Function(int) onNavigate,
  }) {
    if (book.dueDate == null) return const SizedBox.shrink();
    final daysLeft = book.dueDate!.difference(DateTime.now()).inDays;
    Color statusColor;
    String statusText;
    if (daysLeft < 0) {
      statusColor = Colors.red;
      statusText = "Overdue";
    } else if (daysLeft <= 3) {
      statusColor = Colors.orange;
      statusText = "$daysLeft days left";
    } else {
      statusColor = Colors.green;
      statusText = "$daysLeft days left";
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(book.author, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    book.fine > 0
                        ? "Fine: ₹${book.fine.toStringAsFixed(0)}"
                        : statusText,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: book.fine > 0 ? Colors.red : statusColor,
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => onNavigate(2),
                      child: const Text("Renew"),
                    ),
                    TextButton(
                      onPressed: () => onNavigate(2),
                      child: const Text("Return"),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedCardWithImage(Book book) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              book.coverUrl,
              height: 90,
              width: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 90,
                width: 120,
                color: Colors.grey[300],
                child: const Icon(Icons.book, size: 40, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            book.author,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ========== 2. SEARCH PAGE WITH BARCODE ==========
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late List<Book> _filteredCatalog;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredCatalog = AppData.catalogBooks;
  }

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredCatalog = AppData.catalogBooks;
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final results = await ApiService.searchBooks(query);
      setState(() {
        _filteredCatalog = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Search failed: $e")));
    }
  }

  Future<void> _scanForBook(Book book) async {
    final String? barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );
    if (barcode != null && barcode.isNotEmpty) {
      if (barcode == book.isbn) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookDetailsPage(book: book)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Scanned barcode doesn't match this book"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search Books")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search by title or author...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filteredCatalog.length,
                itemBuilder: (context, index) {
                  final book = _filteredCatalog[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      title: Text(
                        book.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(book.author),
                      trailing: book.isAvailable
                          ? IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: () => _scanForBook(book),
                            )
                          : const Icon(Icons.block, color: Colors.red),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookDetailsPage(book: book),
                          ),
                        );
                      },
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

// ========== BOOK DETAILS PAGE ==========
class BookDetailsPage extends StatefulWidget {
  final Book book;
  const BookDetailsPage({super.key, required this.book});
  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  bool _isIssuing = false;

  void _addToWishlist(Book book) async {
    try {
      final success = await ApiService.addToWishlist(
        AppData.studentId!,
        book.isbn,
      );
      if (success) {
        await AppData.loadUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'${book.title}' added to your wishlist!"),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to add '${book.title}' to wishlist."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _issueBook(BuildContext context) async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Issuance"),
        content: Text(
          "Are you sure you want to issue '${widget.book.title}' for 30 days?",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            child: const Text("Issue"),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (didConfirm == true) {
      setState(() {
        _isIssuing = true;
      });

      try {
        final success = await ApiService.issueBook(
          AppData.studentId!,
          widget.book.isbn,
        );

        if (success && mounted) {
          await AppData.loadUserData();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "'${widget.book.title}' has been issued for 30 days!",
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        } else {
          setState(() {
            _isIssuing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to issue '${widget.book.title}'."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isIssuing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  widget.book.coverUrl,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.book.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "by ${widget.book.author}",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Availability: ", style: TextStyle(fontSize: 16)),
                Chip(
                  label: Text(
                    widget.book.isAvailable ? "Available" : "Not Available",
                  ),
                  backgroundColor: widget.book.isAvailable
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: widget.book.isAvailable
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "ISBN: ${widget.book.isbn}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (widget.book.isAvailable)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _isIssuing
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_outline),
                  label: _isIssuing
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Issue Book (30 days)"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _isIssuing ? null : () => _issueBook(context),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.favorite_outline),
                label: const Text("Add to Wishlist"),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () => _addToWishlist(widget.book),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 3. ISSUED BOOKS PAGE WITH RENEW ONCE ==========
class IssuedBooksPage extends StatefulWidget {
  const IssuedBooksPage({super.key});
  @override
  State<IssuedBooksPage> createState() => _IssuedBooksPageState();
}

class _IssuedBooksPageState extends State<IssuedBooksPage>
    with SingleTickerProviderStateMixin {
  late List<Book> _issuedBooks;
  bool _isLoading = true;
  late TabController _tabController;

  // Track selected books for return/renew
  final Set<String> _selectedReturnBooks = {};
  final Set<String> _selectedRenewBooks = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadIssuedBooks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadIssuedBooks() async {
    try {
      await AppData.loadUserData();
      setState(() {
        _issuedBooks = AppData.issuedBooks.where((b) => !b.isReturned).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading issued books: $e")));
    }
  }

  void _renewBook(Book book) async {
    if (!book.canRenew) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "'${book.title}' has already been renewed once. No more renewals allowed.",
          ),
        ),
      );
      return;
    }
    try {
      final success = await ApiService.renewBook(AppData.studentId!, book.isbn);

      if (success) {
        await _loadIssuedBooks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'${book.title}' has been renewed for 30 more days."),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to renew '${book.title}'.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _returnBook(Book book) async {
    try {
      final success = await ApiService.returnBook(
        AppData.studentId!,
        book.isbn,
      );
      if (success) {
        await _loadIssuedBooks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'${book.title}' has been returned."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to return '${book.title}'.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildReturnTab() {
    final books = _issuedBooks;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              if (book.dueDate == null) return const SizedBox.shrink();
              final daysLeft = book.dueDate!.difference(DateTime.now()).inDays;
              Color statusColor;
              String statusText;
              if (daysLeft < 0) {
                statusColor = Colors.red;
                statusText = "Overdue";
              } else if (daysLeft <= 3) {
                statusColor = Colors.orange;
                statusText = "$daysLeft days left";
              } else {
                statusColor = Colors.green;
                statusText = "$daysLeft days left";
              }
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Checkbox(
                    value: _selectedReturnBooks.contains(book.isbn),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedReturnBooks.add(book.isbn);
                        } else {
                          _selectedReturnBooks.remove(book.isbn);
                        }
                      });
                    },
                  ),
                  title: Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.author,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          book.fine > 0
                              ? "Fine: ₹${book.fine.toStringAsFixed(0)}"
                              : statusText,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: book.fine > 0
                            ? Colors.red
                            : statusColor,
                      ),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () => _returnBook(book),
                    child: const Text("Return"),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReturnBooks.isEmpty
                  ? null
                  : () async {
                      for (final isbn in _selectedReturnBooks) {
                        final book = books.firstWhere((b) => b.isbn == isbn);
                        _returnBook(book);
                      }
                      _selectedReturnBooks.clear();
                      await _loadIssuedBooks();
                    },
              child: const Text("Apply Changes"),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRenewTab() {
    final books = _issuedBooks.where((b) => b.canRenew).toList();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              if (book.dueDate == null) return const SizedBox.shrink();
              final daysLeft = book.dueDate!.difference(DateTime.now()).inDays;
              Color statusColor;
              String statusText;
              if (daysLeft < 0) {
                statusColor = Colors.red;
                statusText = "Overdue";
              } else if (daysLeft <= 3) {
                statusColor = Colors.orange;
                statusText = "$daysLeft days left";
              } else {
                statusColor = Colors.green;
                statusText = "$daysLeft days left";
              }
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Checkbox(
                    value: _selectedRenewBooks.contains(book.isbn),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedRenewBooks.add(book.isbn);
                        } else {
                          _selectedRenewBooks.remove(book.isbn);
                        }
                      });
                    },
                  ),
                  title: Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.author,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          book.fine > 0
                              ? "Fine: ₹${book.fine.toStringAsFixed(0)}"
                              : statusText,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: book.fine > 0
                            ? Colors.red
                            : statusColor,
                      ),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () => _renewBook(book),
                    child: const Text("Renew"),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedRenewBooks.isEmpty
                  ? null
                  : () async {
                      for (final isbn in _selectedRenewBooks) {
                        final book = books.firstWhere((b) => b.isbn == isbn);
                        _renewBook(book);
                      }
                      _selectedRenewBooks.clear();
                      await _loadIssuedBooks();
                    },
              child: const Text("Apply Changes"),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Issued Books"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Return Book"),
            Tab(text: "Renew Book"),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadIssuedBooks,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TabBarView(
            controller: _tabController,
            children: [_buildReturnTab(), _buildRenewTab()],
          ),
        ),
      ),
    );
  }
}

// ========== 4. PAY FINE PAGE WITH DISABLED PAY BUTTON ==========
class PayFinePage extends StatefulWidget {
  const PayFinePage({super.key});
  @override
  State<PayFinePage> createState() => _PayFinePageState();
}

class _PayFinePageState extends State<PayFinePage> {
  List<Book> overdueBooks = [];
  double totalFine = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFineData();
  }

  Future<void> _loadFineData() async {
    try {
      await AppData.loadUserData();
      setState(() {
        overdueBooks = AppData.issuedBooks.where((b) => b.fine > 0).toList();
        totalFine = overdueBooks.fold(0.0, (prev, book) => prev + book.fine);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading fine data: $e")));
    }
  }

  // Fix: _showPaymentDialog should launch SBI Collect link
  void _showPaymentDialog(BuildContext context, double totalFine) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Confirm Payment"),
          content: Text(
            "Are you sure you want to pay a total fine of ₹${totalFine.toStringAsFixed(2)}?",
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: const Text("Pay Now"),
              onPressed: () async {
                Navigator.of(context).pop();
                const url = 'https://www.onlinesbi.sbi/sbicollect';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Could not open payment link"),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Pay Fines"),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: RefreshIndicator(
        onRefresh: _loadFineData,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              SizedBox(height: 200, child: FineHistoryChart()),
              const SizedBox(height: 20),
              // Add the payment instruction image here
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        "Steps for Library Payment through SBI Collect",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Add the image from your assets folder
                      Image.asset(
                        'assets/sbi_collect_steps.jpg', // Save the provided image as sbi_collect_steps.jpg in assets
                        fit: BoxFit.contain,
                        height: 320,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: overdueBooks.isEmpty
                    ? const Center(
                        child: Text(
                          "No outstanding fines!",
                          style: TextStyle(fontSize: 18, color: Colors.green),
                        ),
                      )
                    : ListView.builder(
                        itemCount: overdueBooks.length,
                        itemBuilder: (context, index) {
                          final book = overdueBooks[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              title: Text(book.title),
                              subtitle: book.dueDate != null
                                  ? Text(
                                      "Overdue by ${-book.dueDate!.difference(DateTime.now()).inDays} days",
                                    )
                                  : const Text("Overdue"),
                              trailing: Text(
                                "₹${book.fine.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: totalFine > 0
                      ? () => _showPaymentDialog(context, totalFine)
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: totalFine > 0
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    totalFine > 0
                        ? "Pay Now (₹${totalFine.toStringAsFixed(2)})"
                        : "No Fines to Pay",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FineHistoryChart extends StatelessWidget {
  const FineHistoryChart({super.key});
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 3),
              FlSpot(2.6, 2),
              FlSpot(4.9, 5),
              FlSpot(6.8, 3.1),
              FlSpot(8, 4),
              FlSpot(9.5, 3),
              FlSpot(11, 4),
            ],
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 5. EDITABLE PROFILE PAGE ==========
class ProfilePage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  const ProfilePage({super.key, required this.onThemeToggle});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;

  String? getProfileImageUrl() {
    final url = AppData.currentUser?.profileImageUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // Prepend baseUrl if relative path
    return ApiService.baseUrl + '/' + url.replaceAll('\\', '/');
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && AppData.studentId != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      final imageUrl = await ApiService.uploadProfilePicture(
        AppData.studentId!,
        _profileImage!,
      );
      if (imageUrl != null) {
        setState(() {
          AppData.currentUser = User(
            studentId: AppData.currentUser!.studentId,
            name: AppData.currentUser!.name,
            email: AppData.currentUser!.email,
            phone: AppData.currentUser!.phone,
            department: AppData.currentUser!.department,
            profileImageUrl: imageUrl,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload profile picture")),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(
      text: AppData.currentUser?.name ?? '',
    );
    final emailController = TextEditingController(
      text: AppData.currentUser?.email ?? '',
    );
    final departmentController = TextEditingController(
      text: AppData.currentUser?.department ?? '',
    ); // <-- Add department
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: departmentController,
              decoration: const InputDecoration(labelText: "Department"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'name': nameController.text,
              'email': emailController.text,
              'department': departmentController.text,
            }),
            child: const Text("Save"),
          ),
        ],
      ),
    );
    if (result != null && AppData.studentId != null) {
      try {
        final success = await ApiService.updateProfile(
          AppData.studentId!,
          result['name']!,
          result['email']!,
          // You may need to update your backend to accept department
        );

        if (success) {
          final updatedUser = User(
            studentId: AppData.currentUser!.studentId,
            name: result['name']!,
            email: result['email']!,
            phone: AppData.currentUser!.phone,
            department: result['department']!, // <-- Add department
            profileImageUrl: AppData.currentUser!.profileImageUrl,
          );

          await AppData.saveUserData(updatedUser);
          setState(() {});

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile updated successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update profile")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 20, bottom: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _updateProfilePicture,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (getProfileImageUrl() != null
                                      ? NetworkImage(getProfileImageUrl()!)
                                      : const NetworkImage(
                                          "https://placehold.co/100x100/ffffff/154360?text=U",
                                        ))
                                  as ImageProvider,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  AppData.currentUser?.name ?? "User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "ID: ${AppData.studentId ?? 'N/A'}",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ListTile(
                  leading: const Icon(Icons.email_rounded),
                  title: const Text("Email"),
                  subtitle: Text(AppData.currentUser?.email ?? "N/A"),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.phone_rounded),
                  title: const Text("Phone"),
                  subtitle: Text(AppData.currentUser?.phone ?? "N/A"),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.school_rounded),
                  title: const Text("Department"),
                  subtitle: Text(AppData.currentUser?.department ?? "N/A"),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text("Dark Mode"),
                  value: isDarkMode,
                  onChanged: (value) => widget.onThemeToggle(),
                  secondary: Icon(
                    isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text("Edit Profile"),
                  onTap: _editProfile,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Icon(
                    Icons.logout_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    "Logout",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () async {
                    await AppData.clearUserData();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) =>
                            LoginPage(onThemeToggle: widget.onThemeToggle),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
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

// ========== SCANNER PAGE ==========
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isDone = false;

  @override
  dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && !_isDone) {
            final String? code = barcodes.first.rawValue;
            if (code != null) {
              setState(() {
                _isDone = true;
              });
              Navigator.of(context).pop(code);
            }
          }
        },
      ),
    );
  }
}

// ========== APP DRAWER WITH ABOUT ==========
class AppDrawer extends StatelessWidget {
  final VoidCallback onThemeToggle;
  const AppDrawer({super.key, required this.onThemeToggle});
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(
                    "https://placehold.co/100x100/ffffff/154360?text=U",
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppData.currentUser?.name ?? "User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfilePage(onThemeToggle: onThemeToggle),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Wishlist'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WishlistPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ========== WISHLIST PAGE WITH INSTANT UPDATES ==========
class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});
  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    try {
      await AppData.loadUserData();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading wishlist: $e")));
    }
  }

  void _removeFromWishlist(Book book) async {
    try {
      final success = await ApiService.removeFromWishlist(
        AppData.studentId!,
        book.isbn,
      );
      if (success) {
        // Update local data immediately
        setState(() {
          AppData.wishlistBooks.removeWhere((b) => b.isbn == book.isbn);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'${book.title}' removed from wishlist."),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to remove '${book.title}' from wishlist."),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text("My Wishlist")),
      body: RefreshIndicator(
        onRefresh: _loadWishlist,
        child: AppData.wishlistBooks.isEmpty
            ? const Center(
                child: Text(
                  "Your wishlist is empty. Add books from the search page!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: AppData.wishlistBooks.length,

                itemBuilder: (context, index) {
                  final book = AppData.wishlistBooks[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          book.coverUrl,
                          width: 50,
                          fit: BoxFit.cover,
                        ),
                      ),

                      title: Text(
                        book.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(book.author),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeFromWishlist(book),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ========== ABOUT PAGE ==========
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About NovaLib")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_library_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                "NovaLib",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Your Digital Library Companion",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              Text(
                "NovaLib makes library management simple and efficient. Issue books for 30 days, renew once, manage fines, scan barcodes, and keep track of your reading journey.",
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        "Features",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        Icons.qr_code_scanner,
                        "Barcode Scanning",
                      ),
                      _buildFeatureItem(Icons.schedule, "30-Day Issue Period"),
                      _buildFeatureItem(Icons.refresh, "One Renewal Per Book"),
                      _buildFeatureItem(Icons.favorite, "Personal Wishlist"),
                      _buildFeatureItem(Icons.payment, "Fine Management"),
                      _buildFeatureItem(Icons.person, "Editable Profile"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
}
