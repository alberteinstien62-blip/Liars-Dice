import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../widgets/how_it_works_modal.dart';
import '../widgets/sync_indicator.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _nameController = TextEditingController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
    _startPolling();

    // Initialize lobby chain connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameService = context.read<GameService>();
      gameService.initialSetup().then((success) {
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to game lobby'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _initializeProfile() {
    final gameService = context.read<GameService>();
    gameService.loadProfile();
    gameService.loadQueueCount();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      // ✅ FIX: Check mounted before accessing context in async callback
      if (!mounted) return;

      final gameService = context.read<GameService>();
      gameService.loadQueueCount();
      gameService.loadGameState();

      // Check if game started
      if (gameService.isInGame && mounted) {
        Navigator.pushReplacementNamed(context, '/game');
      }
    });
  }

  void _showSetProfileDialog() {
    final gameService = context.read<GameService>();
    _nameController.text = gameService.profile?.name ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Your Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Player Name',
            hintText: 'Enter your name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty) {
                await gameService.setProfile(_nameController.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Consumer<GameService>(
            builder: (context, gameService, _) {
              return Column(
                children: [
                  _buildHeader(gameService),
                  Expanded(child: _buildMainContent(gameService)),
                  _buildFooter(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GameService gameService) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ).createShader(bounds),
            child: const Text(
              "LIAR'S DICE",
              style: AppTypography.gameTitle,
            ),
          ),
          Row(
            children: [
              // ✅ FIX: Use actual connection status from GameService
              SyncIndicator(
                isConnected: gameService.isConnected,
                isSyncing: gameService.isSyncing,
                lastSyncTime: gameService.lastSyncTime,
              ),
              const SizedBox(width: 10),
              const HelpButton(compact: true),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.leaderboard, color: AppColors.accent),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/leaderboard'),
                  tooltip: 'Leaderboard',
                ),
              ),
              const SizedBox(width: 10),
              _buildProfileButton(gameService),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(GameService gameService) {
    final profile = gameService.profile;
    final eloColor = profile != null ? AppColors.getEloColor(profile.elo) : AppColors.textMuted;

    return InkWell(
      onTap: _showSetProfileDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: eloColor.withOpacity(0.5)),
          boxShadow: profile != null
              ? [BoxShadow(color: eloColor.withOpacity(0.2), blurRadius: 10)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: eloColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: eloColor, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name ?? 'Set Name',
                  style: AppTypography.playerName,
                ),
                if (profile != null)
                  Row(
                    children: [
                      Icon(Icons.star, color: eloColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.elo} ${AppColors.getEloRank(profile.elo)}',
                        style: AppTypography.labelSmall.copyWith(color: eloColor),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit, color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(GameService gameService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dice Animation/Icon with neon glow
          Container(
            padding: const EdgeInsets.all(50),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.primary.withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
                // Main dice icon
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accent, AppColors.secondary],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.casino,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),

          // Queue Status with animated styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  '${gameService.queueCount}',
                  style: AppTypography.headlineMedium.copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  'players in queue',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),

          // Find Match Button or Searching State
          if (!gameService.inQueue)
            _buildFindMatchButton(gameService)
          else
            _buildSearchingState(gameService),

          // Error Display
          if (gameService.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      gameService.error!,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFindMatchButton(GameService gameService) {
    final hasProfile = gameService.profile != null;

    return GestureDetector(
      onTap: hasProfile && !gameService.isLoading
          ? () => gameService.findMatch()
          : hasProfile ? null : _showSetProfileDialog,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
        decoration: BoxDecoration(
          gradient: hasProfile ? AppColors.accentGradient : null,
          color: hasProfile ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: hasProfile
              ? null
              : Border.all(color: AppColors.primary, width: 2),
          boxShadow: hasProfile
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gameService.isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.backgroundDark),
                ),
              )
            else
              Icon(
                hasProfile ? Icons.play_arrow : Icons.person_add,
                size: 28,
                color: hasProfile ? AppColors.backgroundDark : AppColors.primary,
              ),
            const SizedBox(width: 12),
            Text(
              hasProfile ? 'FIND MATCH' : 'SET NAME TO PLAY',
              style: AppTypography.buttonTextLarge.copyWith(
                color: hasProfile ? AppColors.backgroundDark : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingState(GameService gameService) {
    return Column(
      children: [
        // Animated searching indicator
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withOpacity(0.2),
                Colors.transparent,
              ],
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'SEARCHING FOR OPPONENT',
          style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Matching you with a worthy opponent...',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => gameService.cancelMatch(),
          icon: const Icon(Icons.close, color: AppColors.error, size: 18),
          label: Text(
            'Cancel Search',
            style: AppTypography.labelMedium.copyWith(color: AppColors.error),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: AppColors.error.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProvablyFairBadge(),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Linera Blockchain',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textMuted,
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
