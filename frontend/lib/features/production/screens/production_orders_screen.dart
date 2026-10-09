import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/production_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../shared/providers/app_state_providers.dart';

class ProductionOrdersScreen extends ConsumerStatefulWidget {
  const ProductionOrdersScreen({super.key});

  @override
  ConsumerState<ProductionOrdersScreen> createState() => _ProductionOrdersScreenState();
}

class _ProductionOrdersScreenState extends ConsumerState<ProductionOrdersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadProductionOrders(forceRefresh: true);
    });
  }

  Widget _buildStatusBadge(ProductionStatus status) {
    switch (status) {
      case ProductionStatus.planned:
        return ErpStatusBadge.warning('WAITING APPROVAL');
      case ProductionStatus.inProgress:
        return ErpStatusBadge.info('IN PROGRESS');
      case ProductionStatus.completed:
        return ErpStatusBadge.success('COMPLETED');
      case ProductionStatus.cancelled:
        return ErpStatusBadge.danger('CANCELLED');
    }
  }

  Future<void> _startProduction(ProductionOrder o) async {
    final db = ref.read(databaseServiceProvider);
    try {
      await db.updateProductionOrderStatusAsync(orderId: o.id, newStatus: ProductionStatus.inProgress);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Production Order ${o.productionNumber} started. Status is now In Progress.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start production: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _completeProductionBatch(ProductionOrder o) async {
    final db = ref.read(databaseServiceProvider);

    ProductionOrder targetOrder = o;
    if (targetOrder.rawMaterialsUsed.isEmpty) {
      try {
        targetOrder = await db.getProductionOrderByIdAsync(o.id);
      } catch (_) {
        targetOrder = o;
      }
    }

    // 1. Check for insufficient raw materials
    final missingStock = <Map<String, dynamic>>[];
    for (final usage in targetOrder.rawMaterialsUsed) {
      final rmIndex = db.rawMaterials.indexWhere((m) => m.id == usage.rawMaterialId);
      final availableStock = rmIndex != -1 ? db.rawMaterials[rmIndex].currentStock : 0.0;
      if (availableStock < usage.quantityUsed) {
        missingStock.add({
          'itemCode': usage.rawMaterialCode,
          'name': usage.rawMaterialName,
          'unit': usage.unit,
          'available': availableStock,
          'required': usage.quantityUsed,
          'deficit': usage.quantityUsed - availableStock,
        });
      }
    }

    if (missingStock.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cannot Complete Batch — Insufficient Stock',
                  style: TextStyle(color: AppColors.danger, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The required components are not currently available in warehouse inventory:'),
              const SizedBox(height: 12),
              ...missingStock.map((s) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: AppRadius.smBorderRadius,
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s['itemCode']} - ${s['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        'Available: ${Formatters.formatNumber(s['available'] as double)} ${s['unit']} | Required: ${Formatters.formatNumber(s['required'] as double)} ${s['unit']} (Short by: ${Formatters.formatNumber(s['deficit'] as double)} ${s['unit']})',
                        style: const TextStyle(color: AppColors.dangerText, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              const Text(
                'Please inward components via Purchase Orders or adjust quantities before completing this batch.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            ErpButton(
              text: 'OK, I Understand',
              isOutlined: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
            const SizedBox(width: 10),
            Text('Complete Production Batch', style: AppTextStyles.h2),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to complete batch ${targetOrder.productionNumber}?',
                style: AppTextStyles.bodyBold,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: AppRadius.smBorderRadius,
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This action will execute the following:',
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.successText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Deduct ${targetOrder.rawMaterialsUsed.length} consumed raw materials from inventory\n'
                      '• Add ${Formatters.formatNumber(targetOrder.plannedQuantity)} ${targetOrder.unit} of ${targetOrder.finishedProductName} into Finished Goods stock\n'
                      '• Record immutable stock movement transactions in the ledger',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          ErpButton(
            text: 'Cancel',
            isOutlined: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          const SizedBox(width: 8),
          ErpButton(
            text: 'Complete & Inward Stock',
            icon: Icons.check_circle_outline,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await db.updateProductionOrderStatusAsync(
        orderId: targetOrder.id,
        newStatus: ProductionStatus.completed,
        actualQuantityProduced: targetOrder.plannedQuantity,
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Production Batch ${targetOrder.productionNumber} completed! Stock has been updated.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing batch: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _confirmCancelAndSoftDelete(ProductionOrder o) {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        title: Row(
          children: [
            Icon(
              o.status == ProductionStatus.completed ? Icons.warning_amber_rounded : Icons.cancel_outlined,
              color: AppColors.danger,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                o.status == ProductionStatus.completed ? 'Cancel & Rollback Production Order' : 'Cancel Production Order',
                style: AppTextStyles.h2,
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          width: double.infinity,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (o.status == ProductionStatus.completed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: AppRadius.smBorderRadius,
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.dangerText, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Warning: Completed batch ${o.productionNumber} will be rolled back. Consumed raw materials will be credited back to warehouse inventory, and produced finished goods will be deducted.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'You are cancelling production order ${o.productionNumber}. Please specify the reason below:',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                TextFormField(
                  controller: reasonCtrl,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Cancellation reason is required' : null,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Cancellation Reason *',
                    hintText: 'E.g., Client request, machine breakdown, quality defect...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          ErpButton(
            text: 'Close',
            isOutlined: true,
            onPressed: () {
              FocusScope.of(ctx).unfocus();
              Navigator.of(ctx).pop();
            },
          ),
          const SizedBox(width: 8),
          ErpButton(
            text: o.status == ProductionStatus.completed ? 'Confirm Cancellation & Rollback' : 'Confirm Cancellation',
            isDanger: true,
            icon: Icons.cancel_outlined,
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              FocusScope.of(ctx).unfocus();
              final reason = reasonCtrl.text.trim();
              final db = ref.read(databaseServiceProvider);
              Navigator.of(ctx).pop();
              try {
                await db.updateProductionOrderStatusAsync(orderId: o.id, newStatus: ProductionStatus.cancelled, reason: reason);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Order ${o.productionNumber} cancelled${o.status == ProductionStatus.completed ? ' and stock rolled back' : ''}.'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error cancelling order: $e'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showOrderDetailsDialog(ProductionOrder initialOrder) {
    showDialog(
      context: context,
      builder: (ctx) {
        ProductionOrder o = initialOrder;
        bool isLoadingDetails = o.rawMaterialsUsed.isEmpty;
        bool fetchStarted = false;

        return StatefulBuilder(
          builder: (context, setDlgState) {
            if (isLoadingDetails && !fetchStarted) {
              fetchStarted = true;
              final db = ref.read(databaseServiceProvider);
              db.getProductionOrderByIdAsync(initialOrder.id).then((fetched) {
                if (ctx.mounted) {
                  setDlgState(() {
                    o = fetched;
                    isLoadingDetails = false;
                  });
                }
              }).catchError((e) {
                if (ctx.mounted) {
                  setDlgState(() {
                    isLoadingDetails = false;
                  });
                }
              });
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.precision_manufacturing_outlined, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text('Order Details: ${o.productionNumber}', style: AppTextStyles.h2),
                    ],
                  ),
                  _buildStatusBadge(o.status),
                ],
              ),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 720),
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(),
                      const SizedBox(height: 12),
                      // Header Info Grid
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _buildDetailField('Finished Product', '${o.finishedProductCode} - ${o.finishedProductName}'),
                          _buildDetailField('Production Date', Formatters.formatDate(o.productionDate)),
                          _buildDetailField('Planned Qty', '${Formatters.formatNumber(o.plannedQuantity)} ${o.unit}'),
                          _buildDetailField('Actual Output', '${Formatters.formatNumber(o.actualQuantityProduced)} ${o.unit}'),
                          if (o.salesOrderNumber != null) _buildDetailField('Sales Order', o.salesOrderNumber!),
                          if (o.projectName != null) _buildDetailField('Project', o.projectName!),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Materials Breakdown Table
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bill of Materials & Components Consumed', style: AppTextStyles.h3),
                          if (isLoadingDetails)
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: AppRadius.smBorderRadius,
                        ),
                        child: o.rawMaterialsUsed.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: isLoadingDetails
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                            SizedBox(width: 10),
                                            Text('Loading components from server...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                          ],
                                        )
                                      : const Text('No raw materials recorded for this order.', style: TextStyle(color: AppColors.textMuted)),
                                ),
                              )
                            : Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(4),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(2),
                                  3: FlexColumnWidth(2),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(color: AppColors.surfaceMuted),
                                    children: [
                                      _tableHeaderCell('Raw Material'),
                                      _tableHeaderCell('Qty Used', align: TextAlign.right),
                                      _tableHeaderCell('Unit Cost', align: TextAlign.right),
                                      _tableHeaderCell('Total Cost', align: TextAlign.right),
                                    ],
                                  ),
                                  ...o.rawMaterialsUsed.map((u) {
                                    return TableRow(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(u.rawMaterialName, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                                              Text(u.rawMaterialCode, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Text(
                                            '${Formatters.formatNumber(u.quantityUsed)} ${u.unit}',
                                            textAlign: TextAlign.right,
                                            style: AppTextStyles.bodySmall,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Text(
                                            Formatters.formatCurrency(u.unitCost),
                                            textAlign: TextAlign.right,
                                            style: AppTextStyles.bodySmall,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Text(
                                            Formatters.formatCurrency(u.totalCost),
                                            textAlign: TextAlign.right,
                                            style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),

                      // Financial Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.15),
                          borderRadius: AppRadius.smBorderRadius,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            _buildCostRow('Raw Material Cost:', Formatters.formatCurrency(o.rawMaterialCost)),
                            const SizedBox(height: 6),
                            _buildCostRow('Direct Labour Cost:', Formatters.formatCurrency(o.labourCost)),
                            const SizedBox(height: 6),
                            _buildCostRow('Factory Overheads / Other:', Formatters.formatCurrency(o.otherExpenses)),
                            const Divider(height: 16),
                            _buildCostRow('Total Batch Cost:', Formatters.formatCurrency(o.totalProductionCost), isBold: true),
                            const SizedBox(height: 6),
                            _buildCostRow('Calculated Cost per Unit:', Formatters.formatCurrency(o.costPerUnit), isBold: true, highlight: true),
                          ],
                        ),
                      ),

                      if (o.notes != null && o.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Batch Notes:', style: AppTextStyles.bodyBold),
                        const SizedBox(height: 4),
                        Text(o.notes!, style: AppTextStyles.bodySmall),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actions: [
                ErpButton(
                  text: 'Close',
                  isOutlined: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                if (o.status == ProductionStatus.planned)
                  ErpButton(
                    text: 'Start Production',
                    icon: Icons.play_arrow_outlined,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _startProduction(o);
                    },
                  ),
                if (o.status == ProductionStatus.planned || o.status == ProductionStatus.inProgress)
                  ErpButton(
                    text: 'Complete Batch',
                    icon: Icons.check_circle_outline,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _completeProductionBatch(o);
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
      ],
    );
  }

  Widget _tableHeaderCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(text, textAlign: align, style: AppTextStyles.bodyBold.copyWith(fontSize: 11, color: AppColors.textSecondary)),
    );
  }

  Widget _buildCostRow(String title, String amount, {bool isBold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: isBold
              ? AppTextStyles.bodyBold.copyWith(color: highlight ? AppColors.primaryDark : AppColors.textPrimary)
              : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          amount,
          style: isBold
              ? AppTextStyles.bodyBold.copyWith(
                  color: highlight ? AppColors.primaryDark : AppColors.textPrimary,
                  fontSize: highlight ? 15 : 13,
                )
              : AppTextStyles.bodySmall,
        ),
      ],
    );
  }

  Widget _buildRowActions(ProductionOrder o) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.textSecondary),
          tooltip: 'View Details',
          onPressed: () => _showOrderDetailsDialog(o),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),
          tooltip: 'Manager Actions',
          onSelected: (val) {
            switch (val) {
              case 'view':
                _showOrderDetailsDialog(o);
                break;
              case 'start':
                _startProduction(o);
                break;
              case 'complete':
                _completeProductionBatch(o);
                break;
              case 'cancel':
                _confirmCancelAndSoftDelete(o);
                break;
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            if (o.status == ProductionStatus.planned) ...[
              const PopupMenuItem(
                value: 'start',
                child: Row(
                  children: [
                    Icon(Icons.play_arrow_outlined, size: 16, color: AppColors.info),
                    SizedBox(width: 8),
                    Text('Start Production', style: TextStyle(color: AppColors.info)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Complete Batch', style: TextStyle(color: AppColors.success)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Cancel Order', style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
            if (o.status == ProductionStatus.inProgress) ...[
              const PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Complete Batch', style: TextStyle(color: AppColors.success)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Cancel Order', style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
            if (o.status == ProductionStatus.completed) ...[
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.undo_outlined, size: 16, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Cancel & Rollback', style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final orders = db.productionOrders.where((o) => !o.isDeleted).where((o) {
      if (_statusFilter != 'ALL') {
        switch (_statusFilter) {
          case 'PLANNED':
            if (o.status != ProductionStatus.planned) return false;
            break;
          case 'IN_PROGRESS':
            if (o.status != ProductionStatus.inProgress) return false;
            break;
          case 'COMPLETED':
            if (o.status != ProductionStatus.completed) return false;
            break;
          case 'CANCELLED':
            if (o.status != ProductionStatus.cancelled) return false;
            break;
        }
      }
      if (_startDate != null && o.productionDate.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) {
        return false;
      }
      if (_endDate != null && o.productionDate.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) {
        return false;
      }
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = o.productionNumber.toLowerCase().contains(query) ||
            o.finishedProductName.toLowerCase().contains(query) ||
            o.finishedProductCode.toLowerCase().contains(query) ||
            o.statusLabel.toLowerCase().contains(query) ||
            (o.notes != null && o.notes!.toLowerCase().contains(query)) ||
            o.rawMaterialsUsed.any((rm) => rm.rawMaterialName.toLowerCase().contains(query));
        if (!matches) return false;
      }
      return true;
    }).toList();

    final totalRecords = orders.length;
    final safePageSize = _pageSize <= 0 ? 25 : _pageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedOrders = totalRecords == 0 ? <ProductionOrder>[] : orders.sublist(startIndex, endIndex);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 650;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Production Orders & Batches', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Manufacturing work orders, raw material consumption, and unit costing', style: AppTextStyles.subtitle),
                ],
              );

              final actionBlock = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ErpButton(
                    text: 'Refresh',
                    icon: Icons.refresh,
                    isOutlined: true,
                    onPressed: () => ref.read(databaseServiceProvider).loadProductionOrders(forceRefresh: true),
                  ),
                  ErpButton(
                    text: 'New Production Order',
                    icon: Icons.precision_manufacturing_outlined,
                    onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createProduction,
                  ),
                ],
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 12),
                    actionBlock,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  actionBlock,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Modern Filter Controls Bar
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: ErpSearchInput(
                  hintText: 'Search by batch no, product name or SKU...',
                  initialValue: _searchQuery,
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                  }),
                ),
              ),
              ErpFilterDropdown<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'PLANNED', child: Text('Waiting Approval')),
                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                  DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _statusFilter = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
              ErpDateFilterBox(
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeSelected: (start, end) => setState(() {
                  _startDate = start;
                  _endDate = end;
                  _currentPage = 0;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Order No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Finished Product'),
              ErpColumn(title: 'Planned Qty', isNumeric: true),
              ErpColumn(title: 'Actual Output', isNumeric: true),
              ErpColumn(title: 'RM Cost', isNumeric: true),
              ErpColumn(title: 'Labour & Overheads', isNumeric: true),
              ErpColumn(title: 'Total Batch Cost', isNumeric: true),
              ErpColumn(title: 'Cost Per Unit', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions', width: 90, alignment: Alignment.center),
            ],
            rows: pagedOrders.map((o) {
              return [
                Text(o.productionNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(Formatters.formatDate(o.productionDate), style: AppTextStyles.bodySmall),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(o.finishedProductCode.isNotEmpty ? o.finishedProductCode : '-', style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                    Text(o.finishedProductName.isNotEmpty ? o.finishedProductName : '-', style: AppTextStyles.bodySmall),
                  ],
                ),
                Text('${Formatters.formatNumber(o.plannedQuantity)} ${o.unit}'.trim(), style: AppTextStyles.bodySmall),
                Text(
                  '${Formatters.formatNumber(o.actualQuantityProduced)} ${o.unit}'.trim(),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: o.status == ProductionStatus.completed ? AppColors.successText : AppColors.textSecondary,
                  ),
                ),
                Text(Formatters.formatCurrency(o.rawMaterialCost), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(o.labourCost + o.otherExpenses), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(o.totalProductionCost), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(o.costPerUnit), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                _buildStatusBadge(o.status),
                _buildRowActions(o),
              ];
            }).toList(),
          ),
          const SizedBox(height: 16),
          ErpPaginationBar(
            currentPage: safeCurrentPage,
            pageSize: safePageSize,
            totalRecords: totalRecords,
            onPageChanged: (newPage) => setState(() => _currentPage = newPage),
            onPageSizeChanged: (newSize) => setState(() {
              _pageSize = newSize;
              _currentPage = 0;
            }),
          ),
        ],
      ),
    );
  }
}
