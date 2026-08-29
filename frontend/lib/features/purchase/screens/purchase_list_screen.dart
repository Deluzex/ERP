import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final purchases = db.purchases.where((p) {
      return p.purchaseNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.vendorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.vendorInvoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Purchase Orders', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Vendor purchase orders, incoming invoices, and payment statuses', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'Create Purchase',
                icon: Icons.add,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createPurchase,
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search purchase by PO number, vendor name or invoice number...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'PO Number'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Vendor Name'),
              ErpColumn(title: 'Vendor Invoice'),
              ErpColumn(title: 'Items Count', isNumeric: true),
              ErpColumn(title: 'Total Amount', isNumeric: true),
              ErpColumn(title: 'Paid Amount', isNumeric: true),
              ErpColumn(title: 'Pending Amount', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: purchases.map((p) {
              ErpStatusBadge badge;
              switch (p.status) {
                case PurchaseStatus.paid:
                  badge = ErpStatusBadge.success('PAID');
                  break;
                case PurchaseStatus.partialPaid:
                  badge = ErpStatusBadge.warning('PARTIAL');
                  break;
                case PurchaseStatus.saved:
                  badge = ErpStatusBadge.info('SAVED');
                  break;
                case PurchaseStatus.draft:
                  badge = ErpStatusBadge.neutral('DRAFT');
                  break;
                case PurchaseStatus.cancelled:
                  badge = ErpStatusBadge.danger('CANCELLED');
                  break;
              }

              return [
                Text(p.purchaseNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
                Text(p.vendorName, style: AppTextStyles.bodyMedium),
                Text(p.vendorInvoiceNumber, style: AppTextStyles.bodySmall),
                Text('${p.items.length} items', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(p.paidAmount), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
                Text(
                  Formatters.formatCurrency(p.pendingAmount),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted,
                  ),
                ),
                badge,
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
