import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../widgets/dice_cup.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Theatrical screen shown after "Liar!" is called - dramatic dice reveal
class RevealScreen extends StatefulWidget {
  final GameState gameState;
  final Bid calledBid;
  final String liarCaller;
  final bool bidWasValid;
  final String loser;

  const RevealScreen({
    super.key,
    required this.gameState,
    required this.calledBid,
    required this.liarCaller,
    required this.bidWasValid,
    required this.loser,
  });

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _countController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  int _currentPlayerIndex = -1;
  int _currentDiceIndex = -1;
  int _runningCount = 0;
  bool _showResult = false;
  bool _revealComplete = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _countController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    // Start dramatic reveal sequence
    Future.delayed(const Duration(milliseconds: 1000), _startRevealSequence);
  }

  void _startRevealSequence() async {
    final players = widget.gameState.players;

    for (int playerIdx = 0; playerIdx < players.length; playerIdx++) {
      final dice = players[playerIdx].revealedDice ?? [];

      setState(() => _currentPlayerIndex = playerIdx);
      await Future.delayed(const Duration(milliseconds: 400));

      for (int diceIdx = 0; diceIdx < dice.length; diceIdx++) {
        setState(() => _currentDiceIndex = diceIdx);

        // Check if this die matches the bid
        if (dice[diceIdx] == widget.calledBid.face) {
          await Future.delayed(const Duration(milliseconds: 150));
          setState(() => _runningCount++);
        }

        await Future.delayed(const Duration(milliseconds: 250));
      }

      setState(() => _currentDiceIndex = -1);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Reveal complete - show result
    setState(() {
      _revealComplete = true;
      _currentPlayerIndex = -1;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _showResult = true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundDark,
              const Color(0xFF1A0A2E),
              AppColors.backgroundDark,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                // Confetti overlay for winner
                if (_showResult && !widget.bidWasValid)
                  const ConfettiOverlay(),

                // Main content
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildCalledBid(),
                      const SizedBox(height: 28),
                      _buildRevealedDice(),
                      const SizedBox(height: 28),
                      _buildDiceCount(),
                      if (_showResult) ...[
                        const SizedBox(height: 28),
                        _buildResult(),
                      ],
                      const SizedBox(height: 28),
                      if (_revealComplete) _buildContinueButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Animated icon
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withOpacity(0.3),
                  AppColors.accent.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              boxShadow: AppColors.glowEffect(AppColors.accent, intensity: 0.5),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.accent, AppColors.secondary],
              ).createShader(bounds),
              child: const Icon(
                Icons.visibility,
                size: 56,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
          ).createShader(bounds),
          child: Text(
            'DICE REVEALED!',
            style: AppTypography.gameTitle.copyWith(
              fontSize: 28,
              letterSpacing: 4,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.error.withOpacity(0.2),
                AppColors.secondary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.error.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gavel, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Text(
                '${widget.liarCaller} called LIAR!',
                style: AppTypography.labelLarge.copyWith(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalledBid() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: AppColors.glowEffect(AppColors.primary, intensity: 0.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.format_quote, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                'THE BID WAS',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.format_quote, color: AppColors.textMuted, size: 16),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.calledBid.quantity}',
                style: AppTypography.bidNumber.copyWith(
                  color: AppColors.accent,
                  shadows: [
                    Shadow(
                      color: AppColors.accent.withOpacity(0.5),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Text(
                'x',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 20),
              DiceCup(
                value: widget.calledBid.face,
                size: 64,
                highlighted: true,
                glowing: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevealedDice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.casino, color: AppColors.primary.withOpacity(0.7), size: 18),
            const SizedBox(width: 8),
            Text(
              'ALL DICE',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...widget.gameState.players.asMap().entries.map(
              (entry) => _buildPlayerDice(entry.value, entry.key),
            ),
      ],
    );
  }

  Widget _buildPlayerDice(GamePlayer player, int playerIndex) {
    final dice = player.revealedDice ?? [];
    final isCurrentPlayer = _currentPlayerIndex == playerIndex;
    final isRevealed = _currentPlayerIndex > playerIndex || _revealComplete;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isCurrentPlayer
            ? LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.secondary.withOpacity(0.08),
                ],
              )
            : AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlayer
              ? AppColors.primary.withOpacity(0.6)
              : AppColors.textMuted.withOpacity(0.15),
          width: isCurrentPlayer ? 2 : 1,
        ),
        boxShadow: isCurrentPlayer
            ? AppColors.glowEffect(AppColors.primary, intensity: 0.3)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCurrentPlayer
                      ? AppColors.primary.withOpacity(0.2)
                      : AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: isCurrentPlayer ? AppColors.primary : AppColors.textMuted,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                player.name,
                style: AppTypography.playerName.copyWith(
                  color: isCurrentPlayer ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isCurrentPlayer && !_revealComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'REVEALING',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (dice.isEmpty)
            Text(
              'No dice revealed',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: dice.asMap().entries.map((entry) {
                final diceIndex = entry.key;
                final dieValue = entry.value;
                final isMatching = dieValue == widget.calledBid.face;
                final isRevealing = isCurrentPlayer && _currentDiceIndex == diceIndex;
                final isRevealedDice =
                    isRevealed || (_currentPlayerIndex == playerIndex && _currentDiceIndex >= diceIndex);

                return AnimatedScale(
                  scale: isRevealing ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedOpacity(
                    opacity: isRevealedDice || _revealComplete ? 1.0 : 0.3,
                    duration: const Duration(milliseconds: 200),
                    child: DiceCup(
                      value: isRevealedDice || _revealComplete ? dieValue : null,
                      size: 48,
                      highlighted: isMatching && _revealComplete,
                      glowing: isMatching && _revealComplete,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDiceCount() {
    final bidQuantity = widget.calledBid.quantity;
    final isEnough = _runningCount >= bidQuantity;
    final color = _revealComplete
        ? (isEnough ? AppColors.success : AppColors.error)
        : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DiceCup(
            value: widget.calledBid.face,
            size: 48,
            highlighted: true,
            glowing: true,
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'FOUND: ',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: _runningCount),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      return Text(
                        '$value',
                        style: AppTypography.headlineLarge.copyWith(
                          color: color,
                          shadows: [
                            Shadow(color: color.withOpacity(0.5), blurRadius: 10),
                          ],
                        ),
                      );
                    },
                  ),
                  Text(
                    ' dice',
                    style: AppTypography.titleMedium.copyWith(color: color),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Bid required: ${widget.calledBid.quantity}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: 24),
          if (_revealComplete)
            AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEnough ? Icons.check_circle : Icons.cancel,
                  color: color,
                  size: 36,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final isWinner = !widget.bidWasValid;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.bidWasValid
                ? [
                    AppColors.success.withOpacity(0.3),
                    AppColors.success.withOpacity(0.15),
                  ]
                : [
                    AppColors.error.withOpacity(0.3),
                    AppColors.error.withOpacity(0.15),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.bidWasValid
                ? AppColors.success.withOpacity(0.6)
                : AppColors.error.withOpacity(0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (widget.bidWasValid ? AppColors.success : AppColors.error)
                  .withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              widget.bidWasValid ? Icons.gavel : Icons.celebration,
              size: 56,
              color: widget.bidWasValid ? AppColors.success : AppColors.error,
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: widget.bidWasValid
                    ? [AppColors.success, AppColors.primary]
                    : [AppColors.error, AppColors.secondary],
              ).createShader(bounds),
              child: Text(
                widget.bidWasValid ? 'BID WAS VALID!' : 'CAUGHT THE LIAR!',
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_circle_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${widget.loser} loses a die!',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.glowEffect(AppColors.accent, intensity: 0.5),
          ),
          child: Center(
            child: Text(
              'CONTINUE',
              style: AppTypography.buttonTextLarge.copyWith(
                color: AppColors.backgroundDark,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Confetti overlay for celebrations
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiPiece> _pieces = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Generate confetti pieces
    for (int i = 0; i < 50; i++) {
      _pieces.add(ConfettiPiece(
        x: _random.nextDouble(),
        delay: _random.nextDouble() * 0.5,
        speed: 0.5 + _random.nextDouble() * 0.5,
        color: [
          AppColors.accent,
          AppColors.secondary,
          AppColors.primary,
          AppColors.success,
          AppColors.gold,
        ][_random.nextInt(5)],
      ));
    }

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
        return CustomPaint(
          painter: ConfettiPainter(
            pieces: _pieces,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class ConfettiPiece {
  final double x;
  final double delay;
  final double speed;
  final Color color;

  ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.color,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiPiece> pieces;
  final double progress;

  ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final adjustedProgress = ((progress - piece.delay) / piece.speed).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      final paint = Paint()
        ..color = piece.color.withOpacity((1 - adjustedProgress) * 0.8)
        ..style = PaintingStyle.fill;

      final x = piece.x * size.width;
      final y = adjustedProgress * size.height * 1.2;

      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => true;
}

/// Dialog showing round results summary
class RoundResultDialog extends StatelessWidget {
  final String winner;
  final String loser;
  final int diceRemaining;
  final VoidCallback onContinue;

  const RoundResultDialog({
    super.key,
    required this.winner,
    required this.loser,
    required this.diceRemaining,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2),
          boxShadow: AppColors.glowEffect(AppColors.accent, intensity: 0.3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.accent, AppColors.secondary],
              ).createShader(bounds),
              child: Text(
                'ROUND OVER',
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.gold, AppColors.accent],
                ).createShader(bounds),
                child: const Icon(
                  Icons.emoji_events,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$winner wins the round!',
              style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$loser loses a die',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$diceRemaining dice remaining',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onContinue,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.glowEffect(AppColors.accent, intensity: 0.4),
                ),
                child: Text(
                  'NEXT ROUND',
                  style: AppTypography.buttonText.copyWith(
                    color: AppColors.backgroundDark,
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

/// Final game result screen with dramatic reveal
class GameResultScreen extends StatefulWidget {
  final String winner;
  final bool isWinner;
  final int eloChange;

  const GameResultScreen({
    super.key,
    required this.winner,
    required this.isWinner,
    required this.eloChange,
  });

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultColor = widget.isWinner ? AppColors.gold : AppColors.error;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isWinner
                ? [
                    const Color(0xFF2A1A00),
                    AppColors.backgroundDark,
                    const Color(0xFF1A0A2E),
                  ]
                : [
                    const Color(0xFF2A0A0A),
                    AppColors.backgroundDark,
                    const Color(0xFF1A0A2E),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Confetti for winners
              if (widget.isWinner) const ConfettiOverlay(),

              // Main content
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Trophy/Icon
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                resultColor.withOpacity(0.3),
                                resultColor.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: widget.isWinner
                                ? AppColors.glowEffect(AppColors.gold, intensity: 0.5)
                                : null,
                          ),
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: widget.isWinner
                                  ? [AppColors.gold, AppColors.accent]
                                  : [AppColors.error, AppColors.secondary],
                            ).createShader(bounds),
                            child: Icon(
                              widget.isWinner
                                  ? Icons.emoji_events
                                  : Icons.sentiment_dissatisfied,
                              size: 100,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Result text
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: widget.isWinner
                                ? [AppColors.gold, AppColors.accent]
                                : [AppColors.error, AppColors.textMuted],
                          ).createShader(bounds),
                          child: Text(
                            widget.isWinner ? 'VICTORY!' : 'DEFEAT',
                            style: AppTypography.gameTitle.copyWith(
                              fontSize: 42,
                              color: Colors.white,
                              letterSpacing: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          widget.isWinner
                              ? 'You outplayed your opponent!'
                              : '${widget.winner} wins!',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ELO change
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.cardGradient,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.eloChange >= 0
                                  ? AppColors.success.withOpacity(0.5)
                                  : AppColors.error.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.eloChange >= 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: widget.eloChange >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'ELO: ',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                widget.eloChange >= 0
                                    ? '+${widget.eloChange}'
                                    : '${widget.eloChange}',
                                style: AppTypography.headlineLarge.copyWith(
                                  color: widget.eloChange >= 0
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 60),

                        // Buttons
                        GestureDetector(
                          onTap: () {
                            context.read<GameService>().clearGame();
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/',
                              (route) => false,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow:
                                  AppColors.glowEffect(AppColors.accent, intensity: 0.5),
                            ),
                            child: Text(
                              'BACK TO LOBBY',
                              style: AppTypography.buttonTextLarge.copyWith(
                                color: AppColors.backgroundDark,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/leaderboard');
                          },
                          child: Text(
                            'View Leaderboard',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
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
