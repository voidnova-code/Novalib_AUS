import 'dart:ui' show Offset, ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Add this for hero and animation
class ForestLoginPage extends StatefulWidget {
  final String apiBaseUrl;
  const ForestLoginPage({Key? key, required this.apiBaseUrl}) : super(key: key);

  @override
  State<ForestLoginPage> createState() => _ForestLoginPageState();
}

class _ForestLoginPageState extends State<ForestLoginPage>
    with SingleTickerProviderStateMixin {
  static const Color brandGreen = Color(0xFF19502E);

  double welcomeHeight = 180;
  final double minHeight = 180;
  late double maxHeight;
  bool isExpanded = false;

  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _otpSent = false;
  bool useAltBackground = false;

  // --- Animation for logo ---
  // Removed logo scale animation to prevent zoom effect
  // final ValueNotifier<double> _logoScale = ValueNotifier(1.0);

  // For "It's me" checkbox animation
  final ValueNotifier<bool> _itsMeChecked = ValueNotifier(false);

  // Add state for loading/error/otp
  bool isLoading = false;
  String? errorMsg;
  String? otpSentToEmail;

  // Add state for user details
  String? userName;
  String? userPhone;

  // Helper: safely decode JSON, returns null if not JSON
  dynamic _tryDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  // Use real Django call to send OTP and fetch user details
  Future<void> sendOtpAndCheckUser(String barcode) async {
    setState(() {
      isLoading = true;
      errorMsg = null;
      otpSentToEmail = null;
      userName = null;
      userPhone = null;
    });
    try {
      final res = await http
          .post(
            Uri.parse('${widget.apiBaseUrl}/api/send-otp/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'barcode': barcode}),
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return; // prevent setState after dispose

      if (res.statusCode == 200) {
        final data = _tryDecodeJson(res.body) ?? {};
        setState(() {
          isLoading = false;
          _otpSent = true;
          otpSentToEmail = data['email'];
          userName = data['user']?['name'];
          userPhone = data['user']?['phone'];
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            content: Text('OTP sent to ${data['email'] ?? 'your email'}'),
          ),
        );
      } else {
        setState(() {
          errorMsg = 'User not found or server error';
          isLoading = false;
          _otpSent = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            content: Text('User not found or server error (${res.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = 'Connection error: $e';
        isLoading = false;
        _otpSent = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          content: Text('Connection error: $e'),
        ),
      );
    }
  }

  // Use real Django call to verify OTP
  Future<void> verifyOtp(String barcode, String otp) async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final res = await http
          .post(
            Uri.parse('${widget.apiBaseUrl}/api/verify-otp/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'barcode': barcode, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = _tryDecodeJson(res.body) ?? {};
        final ok = data['message'] == 'OTP verified successfully';
        if (ok) {
          setState(() {
            isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
              content: Text('OTP verified successfully!'),
            ),
          );
          final resolvedName =
              (data['user']?['name'] as String?) ?? userName ?? 'User';

          // Ensure widget is still in tree before navigating
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/home',
            arguments: {
              'username': resolvedName,
              'useAltBackground': useAltBackground,
            },
          );
        } else {
          setState(() {
            errorMsg = 'Unexpected response from server';
            isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
              content: Text('Unexpected response from server'),
            ),
          );
        }
      } else {
        final bodyJson = _tryDecodeJson(res.body) ?? {};
        setState(() {
          errorMsg = (bodyJson['error'] as String?) ?? 'Verification failed';
          isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            content: Text((bodyJson['error'] as String?) ?? 'Invalid OTP'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = 'Connection error: $e';
        isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          content: Text('Connection error: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _otpController.dispose();
    // _logoScale.dispose(); // removed
    _itsMeChecked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    maxHeight = MediaQuery.of(context).size.height * 0.7;
    final double keyboardInset = MediaQuery.of(
      context,
    ).viewInsets.bottom; // added

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              // REPLACED: remove AnimatedSwitcher to avoid implicit fades on layout changes
              child: Image.asset(
                useAltBackground
                    ? 'assets/background2.jpg'
                    : 'assets/background1.jpg',
                key: ValueKey(useAltBackground),
                fit: BoxFit.cover,
              ),
            ),
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
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 380),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.10),
                            Colors.white.withOpacity(0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              // Only toggle background now; no zoom/scale
                              setState(() {
                                useAltBackground = !useAltBackground;
                              });
                            },
                            child: Hero(
                              tag: "nova_logo",
                              child: Icon(
                                Icons.auto_stories_rounded,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Replace AnimatedDefaultTextStyle with plain Text (no animation)
                          const Text(
                            "Novalib",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom frosted sheet (Welcome / Student Login)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  // Remove drag handlers from the outer area to avoid gesture conflicts
                  // onVerticalDragUpdate: (details) { ... } // removed
                  // onVerticalDragEnd: (details) { ... }   // removed
                  child: Container(
                    // was AnimatedContainer
                    // duration: Duration(milliseconds: 280), // removed
                    // curve: Curves.easeOutCubic,             // removed
                    width: MediaQuery.of(context).size.width,
                    height: welcomeHeight,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          padding: EdgeInsets.fromLTRB(
                            0,
                            18,
                            0,
                            // add keyboard inset so content can scroll above the keyboard
                            MediaQuery.of(context).padding.bottom +
                                (isExpanded ? 22 : 12) +
                                keyboardInset, // changed
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.12),
                                Colors.white.withOpacity(0.06),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, -10),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(), // changed
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior
                                    .onDrag, // added
                            child: Column(
                              children: [
                                // Wrap the header/handle area with its own GestureDetector
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() {
                                      if (isExpanded) {
                                        welcomeHeight = minHeight;
                                        isExpanded = false;
                                      } else {
                                        welcomeHeight = maxHeight;
                                        isExpanded = true;
                                      }
                                    });
                                  },
                                  onVerticalDragUpdate: (details) {
                                    setState(() {
                                      welcomeHeight -= details.primaryDelta!;
                                      welcomeHeight = welcomeHeight.clamp(
                                        minHeight,
                                        maxHeight,
                                      );
                                      isExpanded =
                                          welcomeHeight > minHeight + 100;
                                    });
                                  },
                                  onVerticalDragEnd: (details) {
                                    setState(() {
                                      if (welcomeHeight > minHeight + 80) {
                                        welcomeHeight = maxHeight;
                                        isExpanded = true;
                                      } else {
                                        welcomeHeight = minHeight;
                                        isExpanded = false;
                                      }
                                    });
                                  },
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 5,
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.35),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_down_rounded
                                            : Icons.keyboard_arrow_up_rounded,
                                        color: Colors.white70,
                                        size: 30,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isExpanded
                                            ? "STUDENT LOGIN"
                                            : "WELCOME",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 22,
                                          color: Colors.white,
                                          letterSpacing: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isExpanded
                                            ? "Enter your ID or scan the barcode"
                                            : "Swipe up to login",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Add a little space before the ID input when expanded
                                if (isExpanded) ...[
                                  const SizedBox(height: 10),
                                  // ID input
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28.0,
                                    ),
                                    child: TextField(
                                      controller: _barcodeController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      cursorColor: Colors.white70,
                                      scrollPadding: EdgeInsets.only(
                                        bottom: keyboardInset + 100,
                                      ), // added
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(
                                          0.14,
                                        ),
                                        hintText: 'Enter ID number',
                                        hintStyle: TextStyle(
                                          color: Colors.white70,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.badge_rounded,
                                          color: Colors.white70,
                                        ),
                                        suffixIcon:
                                            _barcodeController.text.isNotEmpty
                                            ? IconButton(
                                                icon: Icon(
                                                  Icons.clear,
                                                  color: Colors.white70,
                                                ),
                                                onPressed: () {
                                                  _barcodeController.clear();
                                                  setState(() {});
                                                },
                                              )
                                            : null,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(
                                              0.22,
                                            ),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(
                                              0.38,
                                            ),
                                            width: 1.2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 12,
                                            ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // Scan button (with animated transition)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28.0,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          HapticFeedback.selectionClick();
                                          final scannedValue =
                                              await Navigator.of(context).push(
                                                _NovaLibScanRoute(
                                                  child:
                                                      const _BarcodeScannerScreen(),
                                                ),
                                              );
                                          if (scannedValue != null) {
                                            setState(() {
                                              _barcodeController.text =
                                                  scannedValue;
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                backgroundColor: Colors.black87,
                                                content: Text(
                                                  'Barcode scanned: $scannedValue',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.qr_code_scanner_rounded,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Scan Barcode',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: Colors.white.withOpacity(
                                              0.35,
                                            ),
                                          ),
                                          backgroundColor: Colors.white
                                              .withOpacity(0.06),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ValueListenableBuilder(
                                            valueListenable: _itsMeChecked,
                                            builder: (context, checked, _) =>
                                                _ItsMeCheckbox(
                                                  labelColor: Colors.white,
                                                  activeColor: brandGreen,
                                                  checkColor: Colors.white,
                                                  isChecked: checked,
                                                  onChanged: (val) {
                                                    _itsMeChecked.value =
                                                        val ?? false;
                                                  },
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // REPLACED: AnimatedContainer -> Container (Send OTP)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28.0,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: brandGreen.withOpacity(
                                              _otpSent ? 0.4 : 0.7,
                                            ),
                                            blurRadius: _otpSent ? 13 : 18,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            HapticFeedback.lightImpact();
                                            await sendOtpAndCheckUser(
                                              _barcodeController.text.trim(),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: brandGreen,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: const Text(
                                            'Send OTP',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (userName != null &&
                                      userPhone != null) ...[
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Name: $userName',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Phone: $userPhone',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (_otpSent) ...[
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28.0,
                                      ),
                                      child: TextField(
                                        controller: _otpController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 6,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        cursorColor: Colors.white70,
                                        scrollPadding: EdgeInsets.only(
                                          bottom: keyboardInset + 100,
                                        ), // added
                                        decoration: InputDecoration(
                                          counterText: '',
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(
                                            0.14,
                                          ),
                                          hintText: 'Enter OTP',
                                          hintStyle: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.lock_rounded,
                                            color: Colors.white70,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.white.withOpacity(
                                                0.22,
                                              ),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.white.withOpacity(
                                                0.38,
                                              ),
                                              width: 1.2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                                horizontal: 12,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // REPLACED: AnimatedContainer -> Container (Verify OTP)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28.0,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: brandGreen.withOpacity(
                                                0.5,
                                              ),
                                              blurRadius: 13,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              HapticFeedback.lightImpact();
                                              final otp = _otpController.text
                                                  .trim();
                                              if (otp.isEmpty ||
                                                  otp.length < 6) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    backgroundColor:
                                                        Colors.black87,
                                                    content: Text(
                                                      'Please enter a valid OTP',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              await verifyOtp(
                                                _barcodeController.text.trim(),
                                                otp,
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: brandGreen,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: const Text(
                                              'Verify OTP',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isLoading)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: CircularProgressIndicator(color: brandGreen),
                ),
              ),
            if (errorMsg != null)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    errorMsg!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            if (otpSentToEmail != null)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'OTP sent to: $otpSentToEmail',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Animated "it's me" checkbox
class _ItsMeCheckbox extends StatelessWidget {
  final Color? labelColor;
  final Color? activeColor;
  final Color? checkColor;
  final bool isChecked;
  final ValueChanged<bool?>? onChanged;
  const _ItsMeCheckbox({
    Key? key,
    this.labelColor,
    this.activeColor,
    this.checkColor,
    required this.isChecked,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // REPLACED: AnimatedContainer -> plain Checkbox (no implicit animation)
        Checkbox(
          value: isChecked,
          onChanged: onChanged,
          activeColor: activeColor ?? const Color(0xFF19502E),
          checkColor: checkColor ?? Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        const SizedBox(width: 4),
        Text(
          "It's me",
          style: TextStyle(
            color: labelColor ?? Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Custom PageRoute for barcode scanner (fade transition)
class _NovaLibScanRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  _NovaLibScanRoute({required this.child})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
}

// Barcode scanner with animated overlay
class _BarcodeScannerScreen extends StatefulWidget {
  const _BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  bool _isHandlingCapture = false;

  late AnimationController animController;
  late Animation<double> pulseAnim;

  @override
  void initState() {
    super.initState();
    animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    pulseAnim = Tween<double>(
      begin: 0.17,
      end: 0.35,
    ).animate(CurvedAnimation(parent: animController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    controller.dispose();
    animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF19502E);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.black),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan Barcode'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (_isHandlingCapture) return;
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  String? code = barcodes.first.rawValue;
                  if (code != null) {
                    _isHandlingCapture = true;
                    Navigator.of(context).pop(code);
                  }
                }
              },
            ),
            // Scan frame: pulsing shadow based on animation
            Center(
              child: AnimatedBuilder(
                animation: pulseAnim,
                builder: (ctx, child) => Container(
                  width: MediaQuery.of(context).size.width * 0.72,
                  height: MediaQuery.of(context).size.width * 0.72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: brandGreen.withOpacity(pulseAnim.value),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.72,
                height: MediaQuery.of(context).size.width * 0.72,
                child: CustomPaint(painter: _CornersPainter(color: brandGreen)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  final Color color;
  _CornersPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const double len = 24;
    // Top-left
    canvas.drawLine(Offset(0, 0), Offset(len, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(0, len), paint);
    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - len),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - len, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
