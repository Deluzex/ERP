import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class PaymentCenterScreen extends ConsumerStatefulWidget {
  final PaymentType? initialTab;

  const PaymentCenterScreen({super.key, this.initialTab});

  @override
  ConsumerState<PaymentCenterScreen> createState() => _PaymentCenterScreenState();
}

class _PaymentCenterScreenState extends ConsumerState<PaymentCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialTab != null) {
      _tabController.index = widget.initialTab!.index;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openRecordPaymentDialog(PaymentType type) {
    final db = ref.read(databaseServiceProvider);
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedPartyId;
    PaymentMode selectedMode = PaymentMode.bankTransfer;
    final formKey = GlobalKey<FormState>();

    if (type == PaymentType.customerPayment && db.customers.isNotEmpty) {
      selectedPartyId = db.customers.first.id;
    } else if (type == PaymentType.dealerPayment && db.dealers.isNotEmpty) {
      selectedPartyId = db.dealers.first.id;
    } else if (type == PaymentType.vendorPayment && db.vendors.isNotEmpty) {
      selectedPartyId = db.vendors.first.id;
    } else if (type == PaymentType.commissionPayment && db.architects.isNotEmpty) {
      selectedPartyId = db.architects.first.id;
    }

    String title;
    switch (type) {
      case PaymentType.customerPayment:
        title = 'Record Customer Receipt';
        break;
      case PaymentType.dealerPayment:
        title = 'Record Dealer Receipt';
        break;
      case PaymentType.vendorPayment:
        title = 'Record Vendor Payment';
        break;
      case PaymentType.commissionPayment:
        title = 'Record Commission Payout';
        break;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            double outstanding = 0.0;
            String partyName = '';

            if (type == PaymentType.customerPayment && selectedPartyId != null) {
              final c = db.customers.firstWhere((cust) => cust.id == selectedPartyId, orElse: () => db.customers.first);
              outstanding = c.outstandingAmount;
              partyName = c.name;
            } else if (type == PaymentType.dealerPayment && selectedPartyId != null) {
              final d = db.dealers.firstWhere((dlr) => dlr.id == selectedPartyId, orElse: () => db.dealers.first);
              outstanding = d.outstandingAmount;
              partyName = d.name;
            } else if (type == PaymentType.vendorPayment && selectedPartyId != null) {
              final v = db.vendors.firstWhere((ven) => ven.id == selectedPartyId, orElse: () => db.vendors.first);
              outstanding = v.outstandingBalance;
              partyName = v.name;
            } else if (type == PaymentType.commissionPayment && selectedPartyId != null) {
              final a = db.architects.firstWhere((arc) => arc.id == selectedPartyId, orElse: () => db.architects.first);
              outstanding = a.approvedCommission;
              partyName = a.name;
            }

            return AlertDialog(
              title: Text(title, style: AppTextStyles.h2),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedPartyId,
                          decoration: InputDecoration(
                            labelText: type == PaymentType.customerPayment
                                ? 'Customer *'
                                : type == PaymentType.dealerPayment
                                    ? 'Dealer *'
                                    : type == PaymentType.vendorPayment
                                        ? 'Vendor *'
                                        : 'Architect *',
                          ),
                          items: type == PaymentType.customerPayment
                              ? db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (Due: ₹${c.outstandingAmount})'))).toList()
                              : type == PaymentType.dealerPayment
                                  ? db.dealers.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.name} (Due: ₹${d.outstandingAmount})'))).toList()
                                  : type == PaymentType.vendorPayment
                                      ? db.vendors.where((v) => !v.isDeleted).map((v) => DropdownMenuItem(value: v.id, child: Text('${v.name} (Due: ₹${v.outstandingBalance})'))).toList()
                                      : db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (Due: ₹${a.approvedCommission})'))).toList(),
                          onChanged: (val) => setDlgState(() => selectedPartyId = val),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Current Outstanding Balance:', style: AppTextStyles.bodyMedium),
                              Text(
                                Formatters.formatCurrency(outstanding),
                                style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          validator: Validators.positiveNumber,
                          decoration: const InputDecoration(labelText: 'Payment Amount (₹) *'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<PaymentMode>(
                          value: selectedMode,
                          decoration: const InputDecoration(labelText: 'Payment Mode'),
                          items: PaymentMode.values.map((mode) {
                            return DropdownMenuItem(value: mode, child: Text(mode.toString().split('.').last.toUpperCase()));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => selectedMode = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: refCtrl,
                          decoration: const InputDecoration(labelText: 'Transaction Reference / UTR / Cheque No'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(labelText: 'Notes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: 'Save Payment',
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final amt = double.parse(amountCtrl.text.trim());

                    final payment = ErpPayment(
                      id: IdGenerator.generateId('PAY'),
                      paymentNumber: IdGenerator.generateDocNumber('PAY', db.nextAdjustmentNumber + 100),
                      paymentType: type,
                      partyId: selectedPartyId!,
                      partyName: partyName,
                      amount: amt,
                      paymentMode: selectedMode,
                      paymentDate: DateTime.now(),
                      transactionReference: refCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    db.addManualPayment(payment);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment recorded & balance updated!'), backgroundColor: AppColors.success),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

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
                  Text('Payments & Treasury Center', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Reconcile customer collections, dealer payments, vendor disbursements, and commission payouts', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'Record Payment',
                icon: Icons.add,
                onPressed: () => _openRecordPaymentDialog(PaymentType.values[_tabController.index]),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Customer Collections'),
              Tab(text: 'Dealer Receipts'),
              Tab(text: 'Vendor Disbursements'),
              Tab(text: 'Commission Payouts'),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 540,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentTable(db.payments.where((p) => p.paymentType == PaymentType.customerPayment).toList()),
                _buildPaymentTable(db.payments.where((p) => p.paymentType == PaymentType.dealerPayment).toList()),
                _buildPaymentTable(db.payments.where((p) => p.paymentType == PaymentType.vendorPayment).toList()),
                _buildPaymentTable(db.payments.where((p) => p.paymentType == PaymentType.commissionPayment).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTable(List<ErpPayment> payments) {
    return ErpDataTable(
      columns: const [
        ErpColumn(title: 'Payment No'),
        ErpColumn(title: 'Date'),
        ErpColumn(title: 'Party / Beneficiary'),
        ErpColumn(title: 'Reference Doc'),
        ErpColumn(title: 'Amount (₹)', isNumeric: true),
        ErpColumn(title: 'Payment Mode'),
        ErpColumn(title: 'UTR / Ref No'),
        ErpColumn(title: 'Notes'),
      ],
      rows: payments.map((p) {
        return [
          Text(p.paymentNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
          Text(Formatters.formatDate(p.paymentDate), style: AppTextStyles.bodySmall),
          Text(p.partyName, style: AppTextStyles.bodyMedium),
          Text(p.referenceDocumentNumber ?? '-', style: AppTextStyles.bodySmall),
          Text(
            Formatters.formatCurrency(p.amount),
            style: AppTextStyles.bodyBold.copyWith(
              color: (p.paymentType == PaymentType.customerPayment || p.paymentType == PaymentType.dealerPayment)
                  ? AppColors.successText
                  : AppColors.textPrimary,
            ),
          ),
          ErpStatusBadge.neutral(p.paymentMode.toString().split('.').last.toUpperCase()),
          Text(p.transactionReference ?? '-', style: AppTextStyles.bodySmall),
          Text(p.notes ?? '-', style: AppTextStyles.bodySmall),
        ];
      }).toList(),
    );
  }
}
