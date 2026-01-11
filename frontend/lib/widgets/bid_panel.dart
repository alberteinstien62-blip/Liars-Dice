import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'dice_cup.dart';

/// Bottom sheet panel for making bids with premium gaming aesthetic
class BidPanel extends StatefulWidget {
  final Bid? currentBid;
  final int totalDice;
  final Function(int quantity, int face) onBidSubmit;

  const BidPanel({
    super.key,
    this.currentBid,
    required this.totalDice,
    required this.onBidSubmit,
  });

  @override
  State<BidPanel> createState() => _BidPanelState();
}

class _BidPanelState extends State<BidPanel> {
  late int _selectedQuantity;
  late int _selectedFace;

  @override
  void initState() {
    super.initState();
    // Initialize with minimum valid bid
    if (widget.currentBid != null) {
      // Must be higher than current bid
      _selectedQuantity = widget.currentBid!.quantity;
      _selectedFace = widget.currentBid!.face + 1;
      if (_selectedFace > 6) {
        _selectedFace = 1;
        _selectedQuantity++;
      }
    } else {
      _selectedQuantity = 1;
      _selectedFace = 1;
    }
  }

  bool get _isValidBid {
    // ✅ FIX: Ensure minimum valid bid is 1x1
    if (_selectedQuantity < 1 || _selectedFace < 1 || _selectedFace > 6) {
      return false;
    }
    // ✅ FIX: Ensure quantity doesn't exceed total dice
    if (_selectedQuantity > widget.totalDice && widget.totalDice > 0) {
      return false;
    }
    // First bid - any valid bid is allowed
    if (widget.currentBid == null) return true;
    // Must be higher than current bid
    if (_selectedQuantity > widget.currentBid!.quantity) return true;
    if (_selectedQuantity == widget.currentBid!.quantity &&
        _selectedFace > widget.currentBid!.face) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 2),
          left: BorderSide(color: AppColors.primary.withOpacity(0.2)),
          right: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'MAKE YOUR BID',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.primary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),

          if (widget.currentBid != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Current: ',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                  Text(
                    '${widget.currentBid!.quantity}',
                    style: AppTypography.titleMedium.copyWith(color: AppColors.accent),
                  ),
                  Text(
                    ' x ',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                  DiceCup(value: widget.currentBid!.face, size: 24),
                ],
              ),
            ),
          const SizedBox(height: 28),

          // Quantity Selector
          _buildQuantitySelector(),
          const SizedBox(height: 28),

          // Face Selector
          _buildFaceSelector(),
          const SizedBox(height: 28),

          // Bid Preview
          _buildBidPreview(),
          const SizedBox(height: 28),

          // Submit Button
          Container(
            decoration: BoxDecoration(
              gradient: _isValidBid ? AppColors.accentGradient : null,
              color: _isValidBid ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isValidBid
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: _isValidBid
                  ? () => widget.onBidSubmit(_selectedQuantity, _selectedFace)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                _isValidBid ? 'SUBMIT BID' : 'INVALID BID',
                style: AppTypography.buttonText.copyWith(
                  color: _isValidBid ? AppColors.backgroundDark : AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cancel Button
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: AppTypography.labelMedium.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    final maxQuantity = widget.totalDice > 0 ? widget.totalDice : 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUANTITY',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuantityButton(
              icon: Icons.remove,
              onPressed: _selectedQuantity > 1
                  ? () => setState(() => _selectedQuantity--)
                  : null,
            ),
            const SizedBox(width: 16),
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                '$_selectedQuantity',
                textAlign: TextAlign.center,
                style: AppTypography.bidNumber.copyWith(
                  color: AppColors.primary,
                  fontSize: 36,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _buildQuantityButton(
              icon: Icons.add,
              onPressed: _selectedQuantity < maxQuantity
                  ? () => setState(() => _selectedQuantity++)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: isEnabled ? AppColors.primaryGradient : null,
          color: isEnabled ? null : AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isEnabled ? AppColors.backgroundDark : AppColors.textMuted,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildFaceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DICE FACE',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            final face = index + 1;
            final isSelected = _selectedFace == face;

            return GestureDetector(
              onTap: () => setState(() => _selectedFace = face),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.3),
                            AppColors.secondary.withOpacity(0.2),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: DiceCup(
                  value: face,
                  size: 44,
                  highlighted: isSelected,
                  glowing: isSelected,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBidPreview() {
    final previewColor = _isValidBid ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: previewColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: previewColor.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: previewColor.withOpacity(0.15),
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isValidBid ? Icons.check_circle : Icons.cancel,
            color: previewColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Your bid: ',
            style: AppTypography.bodyMedium.copyWith(color: previewColor),
          ),
          Text(
            '$_selectedQuantity',
            style: AppTypography.headlineLarge.copyWith(color: previewColor),
          ),
          const SizedBox(width: 8),
          Text(
            'x',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          DiceCup(value: _selectedFace, size: 40),
        ],
      ),
    );
  }
}

/// Compact bid display for history with premium styling
class BidChip extends StatelessWidget {
  final int quantity;
  final int face;
  final String? bidder;
  final bool isHighlighted;

  const BidChip({
    super.key,
    required this.quantity,
    required this.face,
    this.bidder,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isHighlighted
            ? LinearGradient(
                colors: [
                  AppColors.accent.withOpacity(0.2),
                  AppColors.secondary.withOpacity(0.1),
                ],
              )
            : AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? AppColors.accent.withOpacity(0.5)
              : AppColors.textMuted.withOpacity(0.2),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.2),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$quantity',
            style: AppTypography.titleMedium.copyWith(
              color: isHighlighted ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'x',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(width: 4),
          DiceCup(value: face, size: 24, highlighted: isHighlighted),
          if (bidder != null) ...[
            const SizedBox(width: 10),
            Text(
              bidder!,
              style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
