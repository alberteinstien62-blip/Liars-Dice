import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'dice_cup.dart';

/// Widget to display the history of bids with premium gaming aesthetic
class BidHistory extends StatelessWidget {
  final List<Bid> bids;
  final int maxVisible;

  const BidHistory({
    super.key,
    required this.bids,
    this.maxVisible = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history,
                    color: AppColors.primary.withOpacity(0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BID HISTORY',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${bids.length} bids',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bids.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No bids yet',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...bids.reversed.take(maxVisible).toList().asMap().entries.map(
              (entry) => _buildBidEntry(entry.value, entry.key == 0),
            ),
          if (bids.length > maxVisible)
            Center(
              child: TextButton.icon(
                onPressed: () => _showFullHistory(context),
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text('View all ${bids.length} bids'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBidEntry(Bid bid, bool isLatest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: isLatest
            ? LinearGradient(
                colors: [
                  AppColors.accent.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.05),
                ],
              )
            : null,
        color: isLatest ? null : AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLatest ? AppColors.accent.withOpacity(0.3) : AppColors.textMuted.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Bidder name
          Expanded(
            child: Text(
              bid.bidder ?? 'Unknown',
              style: AppTypography.bodyMedium.copyWith(
                color: isLatest ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isLatest ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          // Bid details
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${bid.quantity}',
                style: AppTypography.titleLarge.copyWith(
                  color: isLatest ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'x',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(width: 6),
              DiceCup(value: bid.face, size: 28, highlighted: isLatest),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FullBidHistorySheet(bids: bids),
    );
  }
}

class _FullBidHistorySheet extends StatelessWidget {
  final List<Bid> bids;

  const _FullBidHistorySheet({required this.bids});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 2),
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
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'FULL BID HISTORY',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.primary,
                letterSpacing: 3,
              ),
            ),
          ),
          Divider(color: AppColors.textMuted.withOpacity(0.2)),
          // Bids list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: bids.length,
              itemBuilder: (context, index) {
                final bid = bids[bids.length - 1 - index];
                final bidNumber = bids.length - index;
                return _buildFullBidEntry(bid, bidNumber, index == 0);
              },
            ),
          ),
          // Close button
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBidEntry(Bid bid, int number, bool isLatest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isLatest
            ? LinearGradient(
                colors: [
                  AppColors.accent.withOpacity(0.15),
                  AppColors.secondary.withOpacity(0.08),
                ],
              )
            : AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest ? AppColors.accent.withOpacity(0.5) : AppColors.textMuted.withOpacity(0.15),
          width: isLatest ? 2 : 1,
        ),
        boxShadow: isLatest
            ? [BoxShadow(color: AppColors.accent.withOpacity(0.15), blurRadius: 10)]
            : null,
      ),
      child: Row(
        children: [
          // Bid number
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: isLatest ? AppColors.accentGradient : null,
              color: isLatest ? null : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isLatest ? Colors.transparent : AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Center(
              child: Text(
                '#$number',
                style: AppTypography.labelSmall.copyWith(
                  color: isLatest ? AppColors.backgroundDark : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Bidder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid.bidder ?? 'Unknown',
                  style: AppTypography.playerName.copyWith(
                    color: isLatest ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                if (bid.timestamp != null)
                  Text(
                    _formatTime(bid.timestamp!),
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          // Bid value
          Row(
            children: [
              Text(
                '${bid.quantity}',
                style: AppTypography.headlineLarge.copyWith(
                  color: isLatest ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'x',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              DiceCup(value: bid.face, size: 40, highlighted: isLatest, glowing: isLatest),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Horizontal scrollable bid history for compact display
class HorizontalBidHistory extends StatelessWidget {
  final List<Bid> bids;

  const HorizontalBidHistory({super.key, required this.bids});

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: bids.length,
        itemBuilder: (context, index) {
          final bid = bids[bids.length - 1 - index];
          final isLatest = index == 0;

          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isLatest
                  ? LinearGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.2),
                        AppColors.secondary.withOpacity(0.1),
                      ],
                    )
                  : AppColors.cardGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLatest ? AppColors.accent.withOpacity(0.5) : AppColors.textMuted.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${bid.quantity}',
                  style: AppTypography.titleMedium.copyWith(
                    color: isLatest ? AppColors.accent : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'x',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(width: 4),
                DiceCup(value: bid.face, size: 24, highlighted: isLatest),
              ],
            ),
          );
        },
      ),
    );
  }
}
