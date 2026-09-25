import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../models/stock_movement_model.dart';
import '../utils/formatters.dart';

class StockMovementTile extends StatelessWidget {
  final StockMovement movement;
  final VoidCallback? onTap;

  const StockMovementTile({
    super.key,
    required this.movement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    String typeLabel;
    String quantityText;
    Color qtyColor;

    switch (movement.transactionType) {
      case StockMovementType.purchase:
      case StockMovementType.productionOutput:
      case StockMovementType.saleReturn:
        icon = Icons.file_download_outlined;
        iconColor = AppColors.success;
        typeLabel = movement.transactionType == StockMovementType.productionOutput ? 'STOCK IN (PRODUCTION)' : 'STOCK IN';
        quantityText = '+${Formatters.formatNumber(movement.stockIn)} ${movement.unit}';
        qtyColor = AppColors.successText;
        break;

      case StockMovementType.sale:
      case StockMovementType.productionConsumption:
      case StockMovementType.purchaseReturn:
      case StockMovementType.damage:
        icon = Icons.file_upload_outlined;
        iconColor = AppColors.danger;
        typeLabel = movement.transactionType == StockMovementType.productionConsumption ? 'STOCK OUT (PRODUCTION)' : 'STOCK OUT';
        quantityText = '-${Formatters.formatNumber(movement.stockOut)} ${movement.unit}';
        qtyColor = AppColors.dangerText;
        break;

      case StockMovementType.adjustment:
        if (movement.stockIn > 0) {
          icon = Icons.tune_rounded;
          iconColor = AppColors.warning;
          typeLabel = 'STOCK ADJUSTMENT';
          quantityText = '+${Formatters.formatNumber(movement.stockIn)} ${movement.unit}';
          qtyColor = AppColors.warningText;
        } else {
          icon = Icons.tune_rounded;
          iconColor = AppColors.warning;
          typeLabel = 'STOCK ADJUSTMENT';
          quantityText = '-${Formatters.formatNumber(movement.stockOut)} ${movement.unit}';
          qtyColor = AppColors.dangerText;
        }
        break;
    }

    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        child: Row(
          children: [
            // Left Action Icon
            Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 14),

            // Item Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: AppTextStyles.bodyBold.copyWith(
                      fontSize: 12,
                      letterSpacing: 0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${movement.itemCode} • ${movement.itemName}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Right Qty & Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  quantityText,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: qtyColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  Formatters.formatTime(movement.date),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
