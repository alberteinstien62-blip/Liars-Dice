import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../widgets/dice_cup.dart';
import '../widgets/bid_panel.dart';
import '../widgets/bid_history.dart';
import '../widgets/how_it_works_modal.dart';
import '../widgets/sync_indicator.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? _pollTimer;
  Timer? _loadingTimeoutTimer;
  bool _loadingTimedOut = false;

  // ✅ FIX: Timeout for loading state to prevent infinite skeleton
  static const Duration _loadingTimeout = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _startPolling();
    _startLoadingTimeout();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _loadingTimeoutTimer?.cancel();
    super.dispose();
  }

  void _startLoadingTimeout() {
    _loadingTimeoutTimer = Timer(_loadingTimeout, () {
      if (mounted && context.read<GameService>().gameState == null) {
        setState(() {
          _loadingTimedOut = true;
        });
      }
    });
  }

  void _cancelLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;
  }

  void _initializeGame() {
    final gameService = context.read<GameService>();
    gameService.loadGameState();

    // Roll dice if not already rolled
    if (gameService.myDice == null) {
      gameService.rollDice();
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      // ✅ FIX: Check mounted before accessing context in async callback
      if (!mounted) return;

      final gameService = context.read<GameService>();
      gameService.loadGameState();

      // Check if game ended
      if (gameService.gameState?.phase == GamePhase.gameOver) {
        _pollTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Add confirmation before leaving game to prevent accidental disconnection
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _showLeaveConfirmation(context);
        if (shouldLeave == true && context.mounted) {
          context.read<GameService>().clearGame();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Consumer<GameService>(
              builder: (context, gameService, _) {
                final gameState = gameService.gameState;

                if (gameState == null) {
                  // ✅ FIX: Show error state if loading times out
                  if (_loadingTimedOut) {
                    return _buildLoadingError(gameService);
                  }
                  return _buildLoadingSkeleton();
                }

                // Cancel timeout once game state loaded
                _cancelLoadingTimeout();

                return Column(
                  children: [
                    _buildHeader(gameService, gameState),
                    Expanded(
                      child: _buildGameContent(gameService, gameState),
                    ),
                    _buildActionBar(gameService, gameState),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Show confirmation dialog before leaving game
  Future<bool?> _showLeaveConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Leave Game?',
          style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to leave? You will forfeit the current game.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Stay',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Leave',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(GameService gameService, GameState gameState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ).createShader(bounds),
                child: Text(
                  "LIAR'S DICE",
                  style: AppTypography.headlineMedium.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Round ${gameState.round}',
                    style: AppTypography.labelMedium.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // ✅ FIX: Use actual connection status from GameService
              SyncIndicator(
                isConnected: gameService.isConnected,
                isSyncing: gameService.isSyncing,
                lastSyncTime: gameService.lastSyncTime,
              ),
              const SizedBox(width: 12),
              const HelpButton(compact: true),
              const SizedBox(width: 12),
              _buildPhaseIndicator(gameState.phase),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator(GamePhase phase) {
    String text;
    Color color;

    switch (phase) {
      case GamePhase.waitingForPlayers:
        text = 'WAITING';
        color = AppColors.waiting;
        break;
      case GamePhase.committing:
        text = 'COMMITTING';
        color = AppColors.committing;
        break;
      case GamePhase.bidding:
        text = 'BIDDING';
        color = AppColors.bidding;
        break;
      case GamePhase.revealing:
        text = 'REVEALING';
        color = AppColors.revealing;
        break;
      case GamePhase.roundEnd:
        text = 'ROUND END';
        color = AppColors.roundEnd;
        break;
      case GamePhase.gameOver:
        text = 'GAME OVER';
        color = AppColors.gameOver;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color,
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTypography.phaseLabel.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent(GameService gameService, GameState gameState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Opponents Section
          _buildOpponentsSection(gameService, gameState),
          const SizedBox(height: 24),

          // Current Bid Display
          if (gameState.currentBid != null)
            _buildCurrentBid(gameState.currentBid!),
          const SizedBox(height: 24),

          // My Dice Section
          _buildMyDiceSection(gameService, gameState),
          const SizedBox(height: 24),

          // Bid History
          if (gameState.bidHistory.isNotEmpty)
            BidHistory(bids: gameState.bidHistory),

          // Game Over Display
          if (gameState.phase == GamePhase.gameOver)
            _buildGameOverSection(gameState),

          // Error Display
          if (gameService.error != null) _buildErrorDisplay(gameService.error!),
        ],
      ),
    );
  }

  Widget _buildOpponentsSection(
      GameService gameService, GameState gameState) {
    final myChainId = gameService.profile?.chainId;
    final opponents =
        gameState.players.where((p) => p.chainId != myChainId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPPONENTS',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ...opponents.map((player) => _buildOpponentCard(player, gameState)),
      ],
    );
  }

  Widget _buildOpponentCard(GamePlayer player, GameState gameState) {
    final isCurrentTurn = player.isTurn;
    final isEliminated = player.eliminated;
    final turnColor = AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isCurrentTurn ? null : AppColors.cardGradient,
        color: isCurrentTurn ? turnColor.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn ? turnColor : AppColors.textMuted.withOpacity(0.2),
          width: isCurrentTurn ? 2 : 1,
        ),
        boxShadow: isCurrentTurn
            ? [BoxShadow(color: turnColor.withOpacity(0.2), blurRadius: 15)]
            : null,
      ),
      child: Row(
        children: [
          // Player Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isEliminated
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.backgroundLight, AppColors.surface],
                    ),
              color: isEliminated ? AppColors.error.withOpacity(0.3) : null,
              shape: BoxShape.circle,
              border: Border.all(
                color: isEliminated ? AppColors.error : AppColors.primary.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Icon(
              isEliminated ? Icons.close : Icons.person,
              color: isEliminated ? AppColors.error : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: AppTypography.playerName.copyWith(
                    color: isEliminated ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (isEliminated)
                  Text(
                    'ELIMINATED',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.error),
                  )
                else
                  Text(
                    '${player.diceCount} dice remaining',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          // Dice Icons (hidden)
          if (!isEliminated)
            Row(
              children: List.generate(
                player.diceCount,
                (index) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: DiceCup(value: null, size: 28),
                ),
              ),
            ),
          // Turn Indicator
          if (isCurrentTurn)
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: turnColor.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                'TURN',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentBid(Bid bid) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withOpacity(0.15),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'CURRENT BID',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${bid.quantity}',
                style: AppTypography.bidNumber.copyWith(
                  color: AppColors.accent,
                  shadows: [
                    Shadow(
                      color: AppColors.accent.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'x',
                style: AppTypography.headlineLarge.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(width: 16),
              DiceCup(value: bid.face, size: 60),
            ],
          ),
          if (bid.bidder != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'by ${bid.bidder}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyDiceSection(GameService gameService, GameState gameState) {
    final myDice = gameService.myDice ?? [];
    final myChainId = gameService.profile?.chainId;
    final myPlayer = gameState.players.firstWhere(
      (p) => p.chainId == myChainId,
      orElse: () => GamePlayer(name: 'You', diceCount: 5),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: myPlayer.isTurn ? AppColors.success : AppColors.primary.withOpacity(0.3),
          width: myPlayer.isTurn ? 2 : 1,
        ),
        boxShadow: myPlayer.isTurn
            ? [BoxShadow(color: AppColors.success.withOpacity(0.3), blurRadius: 20)]
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR DICE',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 2,
                ),
              ),
              if (myPlayer.isTurn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.successGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'YOUR TURN',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: myDice
                .map((die) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DiceCup(value: die, size: 60),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${myPlayer.diceCount} dice remaining',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverSection(GameState gameState) {
    final isWinner =
        gameState.winner == context.read<GameService>().profile?.chainId;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        gradient: isWinner ? AppColors.successGradient : AppColors.dangerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isWinner ? AppColors.success : AppColors.error).withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              size: 70,
              color: isWinner ? AppColors.accent : Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isWinner ? 'VICTORY!' : 'DEFEAT',
            style: AppTypography.displayMedium.copyWith(
              color: Colors.white,
              letterSpacing: 6,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isWinner ? 'You outplayed your opponent!' : 'Better luck next time!',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () {
              context.read<GameService>().clearGame();
              Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: isWinner ? AppColors.success : AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'BACK TO LOBBY',
              style: AppTypography.buttonText.copyWith(
                color: isWinner ? AppColors.success : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(String error) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.error, size: 18),
            onPressed: () => context.read<GameService>().clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(GameService gameService, GameState gameState) {
    final myChainId = gameService.profile?.chainId;
    final myPlayer = gameState.players.firstWhere(
      (p) => p.chainId == myChainId,
      orElse: () => GamePlayer(name: 'You', diceCount: 5),
    );
    final isMyTurn = myPlayer.isTurn;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButtons(gameService, gameState, isMyTurn),
          const SizedBox(height: 12),
          const BlockchainBadge(),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      GameService gameService, GameState gameState, bool isMyTurn) {
    switch (gameState.phase) {
      case GamePhase.committing:
        return _buildCommitButton(gameService);
      case GamePhase.bidding:
        return _buildBiddingActions(gameService, gameState, isMyTurn);
      case GamePhase.revealing:
        return _buildRevealButton(gameService);
      case GamePhase.gameOver:
        return const SizedBox.shrink();
      default:
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Waiting...',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildCommitButton(GameService gameService) {
    // ✅ FIX: Backend now auto-commits dice in GameStarted/RoundResult handlers
    // Show informational status instead of action button
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.revealing.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            gameService.myDice != null
                ? 'Dice committed! Waiting for opponent...'
                : 'Auto-committing dice...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (gameService.myDice != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildBiddingActions(
      GameService gameService, GameState gameState, bool isMyTurn) {
    if (!isMyTurn) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent.withOpacity(0.5),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Waiting for opponent's move...",
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Call Liar Button (only if there's a current bid)
        if (gameState.currentBid != null)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.dangerGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed:
                    gameService.isLoading ? null : () => gameService.callLiar(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'LIAR!',
                  style: AppTypography.buttonText.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        if (gameState.currentBid != null) const SizedBox(width: 16),
        // Make Bid Button
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: gameService.isLoading
                  ? null
                  : () => _showBidDialog(gameService, gameState),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                gameState.currentBid == null ? 'FIRST BID' : 'RAISE BID',
                style: AppTypography.buttonText.copyWith(color: AppColors.backgroundDark),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRevealButton(GameService gameService) {
    // ✅ FIX: Backend now auto-reveals dice in LiarCalled handler
    // Show informational status instead of action button
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.success.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Auto-revealing dice...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.visibility, color: AppColors.success, size: 18),
        ],
      ),
    );

  }

  void _showBidDialog(GameService gameService, GameState gameState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BidPanel(
        currentBid: gameState.currentBid,
        totalDice: gameState.totalDice,
        onBidSubmit: (quantity, face) async {
          Navigator.pop(context);
          await gameService.makeBid(quantity, face);
        },
      ),
    );
  }

  // ✅ FIX: Error state when loading times out
  Widget _buildLoadingError(GameService gameService) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.wifi_off,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Timeout',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load game state. Please check your connection and try again.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (gameService.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(
                    gameService.error!,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loadingTimedOut = false;
                    });
                    _startLoadingTimeout();
                    gameService.loadGameState();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('RETRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    gameService.clearGame();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('BACK TO LOBBY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: AppColors.textMuted.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        // Skeleton Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            border: Border(
              bottom: BorderSide(color: AppColors.primary.withOpacity(0.2)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(width: 120, height: 24, borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 8),
                  ShimmerLoading(width: 80, height: 16, borderRadius: BorderRadius.circular(4)),
                ],
              ),
              ShimmerLoading(width: 100, height: 36, borderRadius: BorderRadius.circular(20)),
            ],
          ),
        ),
        // Skeleton Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Opponents section skeleton
                ShimmerLoading(width: 100, height: 14, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 16),
                _buildOpponentCardSkeleton(),
                const SizedBox(height: 12),
                _buildOpponentCardSkeleton(),
                const SizedBox(height: 32),
                // Current bid skeleton
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppColors.cardGradient,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        ShimmerLoading(width: 80, height: 14, borderRadius: BorderRadius.circular(4)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShimmerLoading(width: 50, height: 50, borderRadius: BorderRadius.circular(12)),
                            const SizedBox(width: 20),
                            ShimmerLoading(width: 50, height: 50, borderRadius: BorderRadius.circular(12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Your dice section skeleton
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ShimmerLoading(width: 80, height: 14, borderRadius: BorderRadius.circular(4)),
                          ShimmerLoading(width: 90, height: 28, borderRadius: BorderRadius.circular(16)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ShimmerLoading(width: 50, height: 50, borderRadius: BorderRadius.circular(10)),
                        )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Skeleton Action Bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            border: Border(
              top: BorderSide(color: AppColors.primary.withOpacity(0.2)),
            ),
          ),
          child: Column(
            children: [
              ShimmerLoading(
                width: double.infinity,
                height: 56,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(height: 12),
              const ThinkingIndicator(text: 'Loading game'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpponentCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          ShimmerLoading(width: 48, height: 48, borderRadius: BorderRadius.circular(24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(width: 100, height: 16, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                ShimmerLoading(width: 70, height: 12, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          Row(
            children: List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ShimmerLoading(width: 28, height: 28, borderRadius: BorderRadius.circular(6)),
            )),
          ),
        ],
      ),
    );
  }
}
