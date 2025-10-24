import 'package:flutter/material.dart';

class AppColors {
  static const bgA1 = Color.fromARGB(255, 180, 210, 154);
  static const bgA2 = Color.fromARGB(255, 191, 237, 192);
  static const bgB1 = Color.fromARGB(255, 228, 185, 204);
  static const bgB2 = Color(0xFFF472B6);

  static const ink = Color(0xFF1F2544);
  static const muted = Color(0xFF6B7280);
  static const accent = Color(0xFF5B6BFF);

  static const blushHi = Color(0xFFFFF3F7);
  static const blushLo = Color(0xFFFFE9F2);
  static const blushBd = Color(0xFFFFD6E4);

  static const mintHi = Color(0xFFF1FBF5);
  static const mintLo = Color(0xFFE8F7EE);
  static const mintBd = Color(0xFFD1EFDD);

  static const pearlHi = Color(0xFFF9F6FF);
  static const pearlLo = Color(0xFFF3EEFF);
  static const pearlBd = Color(0xFFE3D9FF);
}

class AppDecorations {
  static BoxDecoration statPearl() => BoxDecoration(
    gradient: const LinearGradient(
      colors: [AppColors.pearlHi, AppColors.pearlLo],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.pearlBd, width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x16000000), blurRadius: 14, offset: Offset(0, 8)),
    ],
  );

  static BoxDecoration itemBlush() => BoxDecoration(
    gradient: const LinearGradient(
      colors: [AppColors.blushHi, AppColors.blushLo],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.blushBd, width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );

  static BoxDecoration rowMint() => BoxDecoration(
    gradient: const LinearGradient(
      colors: [AppColors.mintHi, AppColors.mintLo],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.mintBd, width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 5)),
    ],
  );

  static BoxDecoration cardPearl() => BoxDecoration(
    gradient: const LinearGradient(
      colors: [AppColors.pearlHi, AppColors.pearlLo],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.pearlBd, width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
    ],
  );
}

class AnimatedBg extends StatefulWidget {
  const AnimatedBg({Key? key}) : super(key: key);

  @override
  State<AnimatedBg> createState() => _AnimatedBgState();
}

class _AnimatedBgState extends State<AnimatedBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat(reverse: true);
    _t = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) {
        final c1 = Color.lerp(AppColors.bgA1, AppColors.bgB1, _t.value)!;
        final c2 = Color.lerp(AppColors.bgA2, AppColors.bgB2, _t.value)!;
        final aBegin = Alignment.lerp(
          Alignment.topLeft,
          Alignment.topRight,
          _t.value,
        )!;
        final aEnd = Alignment.lerp(
          Alignment.bottomRight,
          Alignment.bottomLeft,
          _t.value,
        )!;

        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c1, c2],
                    begin: aBegin,
                    end: aEnd,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -60,
              top: -40,
              child: _orb(Colors.white.withOpacity(0.20), 220),
            ),
            Positioned(
              left: -80,
              bottom: -60,
              child: _orb(Colors.white.withOpacity(0.14), 260),
            ),
          ],
        );
      },
    );
  }

  Widget _orb(Color color, double size) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}
