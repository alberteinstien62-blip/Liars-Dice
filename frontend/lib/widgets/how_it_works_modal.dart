import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Modal explaining how the game works and why blockchain matters
/// Shows the commit-reveal cryptography visually
class HowItWorksModal extends StatefulWidget {
  const HowItWorksModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const HowItWorksModal(),
    );
  }

  @override
  State<HowItWorksModal> createState() => _HowItWorksModalState();
}

class _HowItWorksModalState extends State<HowItWorksModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentPage = 0;

  final List<HowItWorksPage> _pages = [
    HowItWorksPage(
      icon: Icons.casino,
      title: 'HOW TO PLAY',
      subtitle: 'The Classic Bluffing Game',
      content: [
        HowItWorksStep(
          number: '1',
          title: 'Roll Your Dice',
          description: 'Each player starts with 5 dice. Roll them secretly - only you can see your hand.',
          icon: Icons.visibility_off,
        ),
        HowItWorksStep(
          number: '2',
          title: 'Make a Bid',
          description: 'Guess how many dice of a certain face are on the table (across ALL players).',
          icon: Icons.trending_up,
        ),
        HowItWorksStep(
          number: '3',
          title: 'Raise or Call Liar',
          description: 'Each bid must be higher than the last. If you think they\'re bluffing, call "LIAR!"',
          icon: Icons.gavel,
        ),
        HowItWorksStep(
          number: '4',
          title: 'Reveal & Resolve',
          description: 'All dice are revealed. If the bid was valid, caller loses a die. If not, bidder loses.',
          icon: Icons.casino,
        ),
      ],
      gradientColors: [AppColors.primary, AppColors.secondary],
    ),
    HowItWorksPage(
      icon: Icons.lock,
      title: 'PROVABLY FAIR',
      subtitle: 'Blockchain-Secured Dice',
      content: [
        HowItWorksStep(
          number: '1',
          title: 'Your Dice Stay Private',
          description: 'Your dice exist ONLY on your personal blockchain - impossible to peek or hack.',
          icon: Icons.shield,
        ),
        HowItWorksStep(
          number: '2',
          title: 'Cryptographic Commitment',
          description: 'When you roll, a SHA-256 hash locks your dice. You can\'t change them later.',
          icon: Icons.fingerprint,
        ),
        HowItWorksStep(
          number: '3',
          title: 'Verified Reveals',
          description: 'When called, the blockchain verifies your reveal matches your commitment.',
          icon: Icons.verified,
        ),
        HowItWorksStep(
          number: '4',
          title: 'No Cheating Possible',
          description: 'Unlike online casinos, the server can\'t see OR manipulate your dice. Truly fair.',
          icon: Icons.security,
        ),
      ],
      gradientColors: [AppColors.accent, AppColors.success],
    ),
    HowItWorksPage(
      icon: Icons.emoji_events,
      title: 'ELO RANKINGS',
      subtitle: 'Compete for Glory',
      content: [
        HowItWorksStep(
          number: '',
          title: 'Bronze (1000-1199)',
          description: 'Starting rank. Learn the game and develop your bluffing skills.',
          icon: Icons.star_border,
          color: AppColors.bronze,
        ),
        HowItWorksStep(
          number: '',
          title: 'Silver (1200-1399)',
          description: 'You\'ve got the basics. Time to master probability and tells.',
          icon: Icons.star_half,
          color: AppColors.silver,
        ),
        HowItWorksStep(
          number: '',
          title: 'Gold (1400-1599)',
          description: 'Skilled player. Your bluffs and reads are getting sharp.',
          icon: Icons.star,
          color: AppColors.gold,
        ),
        HowItWorksStep(
          number: '',
          title: 'Platinum/Diamond (1600+)',
          description: 'Elite tier. You\'ve mastered the art of deception.',
          icon: Icons.diamond,
          color: AppColors.diamond,
        ),
      ],
      gradientColors: [AppColors.gold, AppColors.accent],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _pages.length, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentPage = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 2),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Tab indicators
          _buildTabIndicators(),

          // Page content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _pages.map((page) => _buildPage(page)).toList(),
            ),
          ),

          // Navigation
          _buildNavigation(),
        ],
      ),
    );
  }

  Widget _buildTabIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          final isActive = _currentPage == index;
          return GestureDetector(
            onTap: () => _tabController.animateTo(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: isActive ? 32 : 10,
              height: 10,
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        colors: _pages[index].gradientColors,
                      )
                    : null,
                color: isActive ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isActive
                      ? _pages[index].gradientColors.first
                      : AppColors.textMuted.withOpacity(0.3),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPage(HowItWorksPage page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  page.gradientColors.first.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: page.gradientColors,
              ).createShader(bounds),
              child: Icon(
                page.icon,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: page.gradientColors,
            ).createShader(bounds),
            child: Text(
              page.title,
              style: AppTypography.headlineMedium.copyWith(
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            page.subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 32),

          // Steps
          ...page.content.map((step) => _buildStep(step, page.gradientColors)),
        ],
      ),
    );
  }

  Widget _buildStep(HowItWorksStep step, List<Color> gradientColors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (step.color ?? gradientColors.first).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Number/Icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: step.color != null
                    ? [step.color!, step.color!.withOpacity(0.7)]
                    : gradientColors,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (step.color ?? gradientColors.first).withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: step.number.isNotEmpty
                  ? Text(
                      step.number,
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.backgroundDark,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Icon(
                      step.icon,
                      color: AppColors.backgroundDark,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (step.number.isNotEmpty) ...[
                      Icon(
                        step.icon,
                        color: step.color ?? gradientColors.first,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        step.title,
                        style: AppTypography.titleMedium.copyWith(
                          color: step.color ?? AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  step.description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Back button
          if (_currentPage > 0)
            GestureDetector(
              onTap: () => _tabController.animateTo(_currentPage - 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.textMuted.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Back',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 100),

          const Spacer(),

          // Next/Close button
          GestureDetector(
            onTap: () {
              if (_currentPage < _pages.length - 1) {
                _tabController.animateTo(_currentPage + 1);
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _pages[_currentPage].gradientColors,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _pages[_currentPage].gradientColors.first.withOpacity(0.4),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    _currentPage < _pages.length - 1 ? 'Next' : 'Got it!',
                    style: AppTypography.buttonText.copyWith(
                      color: AppColors.backgroundDark,
                    ),
                  ),
                  if (_currentPage < _pages.length - 1) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: AppColors.backgroundDark, size: 18),
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

class HowItWorksPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<HowItWorksStep> content;
  final List<Color> gradientColors;

  HowItWorksPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.gradientColors,
  });
}

class HowItWorksStep {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final Color? color;

  HowItWorksStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    this.color,
  });
}

/// Compact help button to open the How It Works modal
class HelpButton extends StatelessWidget {
  final bool compact;

  const HelpButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HowItWorksModal.show(context),
      child: Container(
        padding: EdgeInsets.all(compact ? 8 : 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              color: AppColors.primary,
              size: compact ? 18 : 22,
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(
                'How to Play',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Provably Fair badge with tooltip
class ProvablyFairBadge extends StatelessWidget {
  final bool showLabel;

  const ProvablyFairBadge({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showExplanation(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.success.withOpacity(0.15),
              AppColors.primary.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified,
                color: AppColors.success,
                size: 14,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                'Provably Fair',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.info_outline,
                color: AppColors.success.withOpacity(0.7),
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withOpacity(0.5)),
            boxShadow: AppColors.glowEffect(AppColors.success, intensity: 0.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.success.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.security,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.success, AppColors.primary],
                ).createShader(bounds),
                child: Text(
                  'PROVABLY FAIR',
                  style: AppTypography.headlineSmall.copyWith(
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your dice are secured by SHA-256 cryptography on the Linera blockchain.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(Icons.visibility_off, 'Your dice stay hidden until revealed'),
                    const SizedBox(height: 8),
                    _buildFeatureRow(Icons.lock, 'Cryptographic commitment prevents changes'),
                    const SizedBox(height: 8),
                    _buildFeatureRow(Icons.verified_user, 'Server cannot see or manipulate dice'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.success, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Got it',
                    style: AppTypography.buttonText.copyWith(
                      color: AppColors.backgroundDark,
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

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.success, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
