import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/player.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/sync_indicator.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = true;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);

    final gameService = context.read<GameService>();
    final entries = await gameService.loadLeaderboard();

    setState(() {
      _leaderboard = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          // ✅ FIX: Use Consumer to access GameService for connection status
          child: Consumer<GameService>(
            builder: (context, gameService, _) {
              return Column(
                children: [
                  _buildHeader(gameService),
                  Expanded(
                    child: _isLoading ? _buildLoadingState() : _buildLeaderboard(),
                  ),
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
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.accent, AppColors.secondary],
            ).createShader(bounds),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  'LEADERBOARD',
                  style: AppTypography.headlineMedium.copyWith(
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // ✅ FIX: Use actual connection status from GameService
          SyncIndicator(
            isConnected: gameService.isConnected,
            isSyncing: gameService.isSyncing,
            lastSyncTime: gameService.lastSyncTime,
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppColors.glowEffect(AppColors.primary, intensity: 0.3),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.backgroundDark),
              onPressed: _loadLeaderboard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
            child: SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                backgroundColor: AppColors.accent.withOpacity(0.2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const ThinkingIndicator(text: 'Loading rankings'),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    if (_leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.5),
                    AppColors.secondary.withOpacity(0.3),
                  ],
                ).createShader(bounds),
                child: const Icon(
                  Icons.leaderboard,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No rankings yet',
              style: AppTypography.titleLarge.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to claim glory!',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: AppColors.glowEffect(AppColors.accent, intensity: 0.4),
                ),
                child: Text(
                  'PLAY NOW',
                  style: AppTypography.buttonText.copyWith(color: AppColors.backgroundDark),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaderboard.length,
        itemBuilder: (context, index) {
          return _buildLeaderboardEntry(_leaderboard[index], index);
        },
      ),
    );
  }

  Widget _buildLeaderboardEntry(LeaderboardEntry entry, int index) {
    final isTopThree = index < 3;
    final myChainId = context.read<GameService>().profile?.chainId;
    final isMe = entry.chainId == myChainId;
    final rankColor = _getRankColor(index);
    final eloColor = AppColors.getEloColor(entry.elo);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.15),
                    AppColors.secondary.withOpacity(0.08),
                  ],
                )
              : isTopThree
                  ? LinearGradient(
                      colors: [
                        rankColor.withOpacity(0.1),
                        AppColors.surface.withOpacity(0.5),
                      ],
                    )
                  : AppColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe
                ? AppColors.accent.withOpacity(0.5)
                : isTopThree
                    ? rankColor.withOpacity(0.5)
                    : AppColors.textMuted.withOpacity(0.15),
            width: isMe || isTopThree ? 2 : 1,
          ),
          boxShadow: isMe || isTopThree
              ? [
                  BoxShadow(
                    color: (isMe ? AppColors.accent : rankColor).withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: _buildRankBadge(index, rankColor),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  entry.name,
                  style: AppTypography.playerName.copyWith(
                    color: isMe ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: isTopThree ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (isMe)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'YOU',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.backgroundDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                _buildStat(Icons.trending_up, '${entry.wins}W', AppColors.success),
                const SizedBox(width: 16),
                _buildStat(Icons.trending_down, '${entry.losses}L', AppColors.error),
                const SizedBox(width: 16),
                _buildStat(Icons.percent, _getWinRate(entry), AppColors.primary),
              ],
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  eloColor.withOpacity(0.2),
                  eloColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: eloColor.withOpacity(0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${entry.elo}',
                  style: AppTypography.eloRating.copyWith(
                    color: eloColor,
                  ),
                ),
                Text(
                  AppColors.getEloRank(entry.elo),
                  style: AppTypography.labelSmall.copyWith(
                    color: eloColor.withOpacity(0.8),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int index, Color rankColor) {
    final isTopThree = index < 3;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: isTopThree
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  rankColor,
                  rankColor.withOpacity(0.7),
                ],
              )
            : null,
        color: isTopThree ? null : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: isTopThree ? rankColor : AppColors.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: isTopThree
            ? [BoxShadow(color: rankColor.withOpacity(0.4), blurRadius: 10)]
            : null,
      ),
      child: Center(
        child: isTopThree
            ? Icon(
                _getRankIcon(index),
                color: AppColors.backgroundDark,
                size: 26,
              )
            : Text(
                '${index + 1}',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.8)),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppTypography.labelSmall.copyWith(
            color: color.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return AppColors.gold;
      case 1:
        return AppColors.silver;
      case 2:
        return AppColors.bronze;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getRankIcon(int index) {
    switch (index) {
      case 0:
        return Icons.emoji_events;
      case 1:
        return Icons.military_tech;
      case 2:
        return Icons.workspace_premium;
      default:
        return Icons.numbers;
    }
  }

  String _getWinRate(LeaderboardEntry entry) {
    final total = entry.wins + entry.losses;
    if (total == 0) return '0%';
    final rate = (entry.wins / total * 100).toStringAsFixed(0);
    return '$rate%';
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BlockchainBadge(),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: AppColors.accent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'ELO Rankings',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.accent,
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
