import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Widget to display a single die with premium gaming aesthetic
/// If value is null, shows a hidden die (question mark)
class DiceCup extends StatelessWidget {
  final int? value;
  final double size;
  final bool highlighted;
  final bool glowing;

  const DiceCup({
    super.key,
    this.value,
    this.size = 48,
    this.highlighted = false,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isHidden = value == null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isHidden
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.diceHidden,
                  AppColors.diceHidden.withOpacity(0.8),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.diceWhite,
                  AppColors.diceWhite.withOpacity(0.95),
                ],
              ),
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(
          color: highlighted
              ? AppColors.accent
              : isHidden
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.primary.withOpacity(0.5),
          width: highlighted ? 3 : 2,
        ),
        boxShadow: [
          // Inner highlight
          BoxShadow(
            color: Colors.white.withOpacity(isHidden ? 0.05 : 0.3),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
          // Drop shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
          // Glow effect
          if (glowing || highlighted)
            BoxShadow(
              color: (highlighted ? AppColors.accent : AppColors.diceGlow)
                  .withOpacity(0.6),
              blurRadius: 15,
              spreadRadius: 2,
            ),
        ],
      ),
      child: isHidden ? _buildHiddenDie() : _buildDieFace(value!),
    );
  }

  Widget _buildHiddenDie() {
    return Center(
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.7),
            AppColors.primaryLight.withOpacity(0.5),
          ],
        ).createShader(bounds),
        child: Icon(
          Icons.help_outline,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDieFace(int value) {
    return CustomPaint(
      painter: DieFacePainter(value: value),
    );
  }
}

class DieFacePainter extends CustomPainter {
  final int value;

  DieFacePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.diceDot
      ..style = PaintingStyle.fill;

    // Add subtle shadow to dots
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    final dotRadius = size.width * 0.1;
    final center = Offset(size.width / 2, size.height / 2);
    final offset = size.width * 0.25;

    // Define dot positions based on die face value
    final positions = _getDotsForValue(value, center, offset);

    for (final pos in positions) {
      // Draw shadow
      canvas.drawCircle(pos + const Offset(0.5, 0.5), dotRadius, shadowPaint);
      // Draw dot
      canvas.drawCircle(pos, dotRadius, paint);
    }
  }

  List<Offset> _getDotsForValue(int value, Offset center, double offset) {
    switch (value) {
      case 1:
        return [center];
      case 2:
        return [
          Offset(center.dx - offset, center.dy - offset),
          Offset(center.dx + offset, center.dy + offset),
        ];
      case 3:
        return [
          Offset(center.dx - offset, center.dy - offset),
          center,
          Offset(center.dx + offset, center.dy + offset),
        ];
      case 4:
        return [
          Offset(center.dx - offset, center.dy - offset),
          Offset(center.dx + offset, center.dy - offset),
          Offset(center.dx - offset, center.dy + offset),
          Offset(center.dx + offset, center.dy + offset),
        ];
      case 5:
        return [
          Offset(center.dx - offset, center.dy - offset),
          Offset(center.dx + offset, center.dy - offset),
          center,
          Offset(center.dx - offset, center.dy + offset),
          Offset(center.dx + offset, center.dy + offset),
        ];
      case 6:
        return [
          Offset(center.dx - offset, center.dy - offset),
          Offset(center.dx + offset, center.dy - offset),
          Offset(center.dx - offset, center.dy),
          Offset(center.dx + offset, center.dy),
          Offset(center.dx - offset, center.dy + offset),
          Offset(center.dx + offset, center.dy + offset),
        ];
      default:
        return [center];
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Row of dice for displaying multiple dice
class DiceRow extends StatelessWidget {
  final List<int> dice;
  final double dieSize;
  final bool hidden;
  final List<int>? highlightedIndices;

  const DiceRow({
    super.key,
    required this.dice,
    this.dieSize = 48,
    this.hidden = false,
    this.highlightedIndices,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dice.length, (index) {
        final isHighlighted = highlightedIndices?.contains(index) ?? false;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: DiceCup(
            value: hidden ? null : dice[index],
            size: dieSize,
            highlighted: isHighlighted,
            glowing: isHighlighted,
          ),
        );
      }),
    );
  }
}

/// Animated dice roll widget with improved animation
class AnimatedDice extends StatefulWidget {
  final int finalValue;
  final double size;
  final Duration duration;
  final VoidCallback? onRollComplete;

  const AnimatedDice({
    super.key,
    required this.finalValue,
    this.size = 48,
    this.duration = const Duration(milliseconds: 600),
    this.onRollComplete,
  });

  @override
  State<AnimatedDice> createState() => _AnimatedDiceState();
}

class _AnimatedDiceState extends State<AnimatedDice>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  int _currentValue = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 4 * 3.14159).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addListener(() {
      final progress = _controller.value;
      if (progress < 0.8) {
        // Randomize during roll
        final randomValue = (DateTime.now().millisecondsSinceEpoch % 6) + 1;
        if (_currentValue != randomValue) {
          setState(() => _currentValue = randomValue);
        }
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _currentValue = widget.finalValue);
        widget.onRollComplete?.call();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: DiceCup(
              value: _currentValue,
              size: widget.size,
              glowing: _controller.isAnimating,
            ),
          ),
        );
      },
    );
  }
}
