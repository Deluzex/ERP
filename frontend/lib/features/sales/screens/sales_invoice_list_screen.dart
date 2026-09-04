import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class SalesInvoiceListScreen extends ConsumerStatefulWidget {
  const SalesInvoiceListScreen({super.key});

  @override
  ConsumerState<SalesInvoiceListScreen> createState() => _SalesInvoiceListScreenState();
}

class _SalesInvoiceListScreenState extends ConsumerState<SalesInvoiceListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final sales = db.sales.where((s) {
      return s.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.partyName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s.projectName != null && s.projectName!.toLowerCase().contains(_searchQuery.toLowerCase()));
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
                  Text('Sales Invoices', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Customer and dealer invoices, project links, and architect commissions', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'Create Invoice',
                icon: Icons.add,
                onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale,
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search sales invoice by number, customer/dealer or project...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Invoice No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Party Name'),
              ErpColumn(title: 'Channel'),
              ErpColumn(title: 'Linked Project'),
              ErpColumn(title: 'Total Amount', isNumeric: true),
              ErpColumn(title: 'Paid', isNumeric: true),
              ErpColumn(title: 'Pending', isNumeric: true),
              ErpColumn(title: 'Commission', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: sales.map((s) {
              ErpStatusBadge badge;
              switch (s.status) {
                case SaleStatus.paid:
                case SaleStatus.completed:
                  badge = ErpStatusBadge.success('PAID');
                  break;
                case SaleStatus.partialPaid:
                  badge = ErpStatusBadge.warning('PARTIAL');
                  break;
                case SaleStatus.active:
                  badge = ErpStatusBadge.info('ACTIVE');
                  break;
                case SaleStatus.draft:
                  badge = ErpStatusBadge.neutral('DRAFT');
                  break;
                case SaleStatus.cancelled:
                  badge = ErpStatusBadge.danger('CANCELLED');
                  break;
              }

              return [
                Text(s.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
                Text(s.partyName, style: AppTextStyles.bodyMedium),
                Text(s.partyType == PartyType.customer ? 'Customer' : 'Dealer', style: AppTextStyles.bodySmall),
                Text(s.projectName ?? '-', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(s.paidAmount), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
                Text(
                  Formatters.formatCurrency(s.pendingAmount),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted,
                  ),
                ),
                Text(
                  s.architectCommissionAmount > 0 ? Formatters.formatCurrency(s.architectCommissionAmount) : '-',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.purple),
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
