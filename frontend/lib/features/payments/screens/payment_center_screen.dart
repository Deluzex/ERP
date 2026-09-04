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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialTab != null) {
      _tabController.index = widget.initialTab!.index;
    }
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    setState(() {});
    if (!_tabController.indexIsChanging) {
      final targetSection = _getSectionForIndex(_tabController.index);
      if (ref.read(currentNavSectionProvider) != targetSection) {
        ref.read(currentNavSectionProvider.notifier).state = targetSection;
      }
    }
  }

  ErpNavSection _getSectionForIndex(int index) {
    switch (index) {
      case 0:
        return ErpNavSection.customerPayments;
      case 1:
        return ErpNavSection.dealerPayments;
      case 2:
        return ErpNavSection.vendorPaymentsSection;
      case 3:
        return ErpNavSection.commissionPayments;
      default:
        return ErpNavSection.customerPayments;
    }
  }

  @override
  void didUpdateWidget(PaymentCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null && widget.initialTab != oldWidget.initialTab) {
      if (_tabController.index != widget.initialTab!.index) {
        _tabController.animateTo(widget.initialTab!.index);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
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
              outstanding = a.pendingCommission;
              partyName = a.name;
<<<<<<< Updated upstream
=======

              // Unpaid commissions
              final commissions = db.commissions.where((cm) => cm.architectId == selectedPartyId && cm.status != CommissionStatus.paid);
              linkedDocItems = commissions.map((cm) => DropdownMenuItem(value: cm.id, child: Text('${cm.commissionNumber} (Amt: ₹${cm.commissionAmount})'))).toList();
>>>>>>> Stashed changes
            }

            return AlertDialog(
              title: Text(title, style: AppTextStyles.h2),
              content: SizedBox(
<<<<<<< Updated upstream
                width: 480,
=======
                width: 540,
>>>>>>> Stashed changes
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
<<<<<<< Updated upstream
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
=======
                        // Party Outstanding Badge
>>>>>>> Stashed changes
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
<<<<<<< Updated upstream
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
=======
                            color: AppColors.primarySoft,
                            borderRadius: AppRadius.smBorderRadius,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
>>>>>>> Stashed changes
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
<<<<<<< Updated upstream
                              Text('Current Outstanding Balance:', style: AppTextStyles.bodyMedium),
                              Text(
                                Formatters.formatCurrency(outstanding),
                                style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText),
=======
                              Text('Current Outstanding / Balance:', style: AppTextStyles.bodyMedium),
                              Text(
                                Formatters.formatCurrency(outstanding),
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: outstanding > 0 ? AppColors.dangerText : AppColors.successText,
                                  fontSize: 16,
                                ),
>>>>>>> Stashed changes
                              ),
                            ],
                          ),
                        ),
<<<<<<< Updated upstream
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          validator: Validators.positiveNumber,
                          decoration: const InputDecoration(labelText: 'Payment Amount (₹) *'),
=======

                        // Party Selector
                        if (type == PaymentType.customerPayment) ...[
                          DropdownButtonFormField<String>(
                            value: selectedPartyId,
                            decoration: const InputDecoration(labelText: 'Select Customer *'),
                            items: db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                            onChanged: (val) {
                              setDlgState(() {
                                selectedPartyId = val;
                                selectedLinkedDocId = null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ] else if (type == PaymentType.dealerPayment) ...[
                          DropdownButtonFormField<String>(
                            value: selectedPartyId,
                            decoration: const InputDecoration(labelText: 'Select Dealer *'),
                            items: db.dealers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                            onChanged: (val) {
                              setDlgState(() {
                                selectedPartyId = val;
                                selectedLinkedDocId = null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ] else if (type == PaymentType.vendorPayment) ...[
                          DropdownButtonFormField<String>(
                            value: selectedPartyId,
                            decoration: const InputDecoration(labelText: 'Select Vendor *'),
                            items: db.vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))).toList(),
                            onChanged: (val) {
                              setDlgState(() {
                                selectedPartyId = val;
                                selectedLinkedDocId = null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ] else if (type == PaymentType.commissionPayment) ...[
                          DropdownButtonFormField<String>(
                            value: selectedPartyId,
                            decoration: const InputDecoration(labelText: 'Select Architect / Partner *'),
                            items: db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                            onChanged: (val) {
                              setDlgState(() {
                                selectedPartyId = val;
                                selectedLinkedDocId = null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Linked Document Selection
                        if (linkedDocItems.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            value: selectedLinkedDocId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Link to Unpaid Document (Optional)'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('On Account / Advance Payment (No specific doc)')),
                              ...linkedDocItems,
                            ],
                            onChanged: (val) => setDlgState(() => selectedLinkedDocId = val),
                          ),
                          const SizedBox(height: 14),
                        ],

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: amountCtrl,
                                keyboardType: TextInputType.number,
                                validator: Validators.positiveNumber,
                                decoration: const InputDecoration(labelText: 'Payment Amount (₹) *'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<PaymentStatus>(
                                value: selectedStatus,
                                decoration: const InputDecoration(labelText: 'Payment Status'),
                                items: PaymentStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))).toList(),
                                onChanged: (val) {
                                  if (val != null) setDlgState(() => selectedStatus = val);
                                },
                              ),
                            ),
                          ],
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(labelText: 'Notes'),
=======
                        const SizedBox(height: 16),

                        // Attachment Uploader Component
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.smBorderRadius,
                            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                          ),
                          child: attachmentFileName != null
                              ? Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf, color: AppColors.danger, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(attachmentFileName!, style: AppTextStyles.bodyMedium)),
                                    IconButton(
                                      icon: const Icon(Icons.cancel, color: AppColors.textMuted),
                                      onPressed: () => setDlgState(() => attachmentFileName = null),
                                    ),
                                  ],
                                )
                              : InkWell(
                                  onTap: () {
                                    setDlgState(() {
                                      attachmentFileName = 'Voucher_Receipt_PAY_${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}.pdf';
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text('Upload Payment Receipt / Proof', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                                    ],
                                  ),
                                ),
>>>>>>> Stashed changes
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

    // Synchronize tab index if currentNavSectionProvider changes from outside (e.g. sidebar click)
    ref.listen<ErpNavSection>(currentNavSectionProvider, (previous, next) {
      int? targetIndex;
      if (next == ErpNavSection.customerPayments) {
        targetIndex = 0;
      } else if (next == ErpNavSection.dealerPayments) {
        targetIndex = 1;
      } else if (next == ErpNavSection.vendorPayments || next == ErpNavSection.vendorPaymentsSection) {
        targetIndex = 2;
      } else if (next == ErpNavSection.commissionPayments) {
        targetIndex = 3;
      }

      if (targetIndex != null && _tabController.index != targetIndex) {
        _tabController.animateTo(targetIndex);
      }
    });

    final (buttonLabel, currentPaymentType) = switch (_tabController.index) {
      0 => ('Record Customer Receipt', PaymentType.customerPayment),
      1 => ('Record Dealer Receipt', PaymentType.dealerPayment),
      2 => ('Record Vendor Payment', PaymentType.vendorPayment),
      3 => ('Record Commission Payout', PaymentType.commissionPayment),
      _ => ('Record Payment', PaymentType.customerPayment),
    };

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
                text: buttonLabel,
                icon: Icons.add,
                onPressed: () => _openRecordPaymentDialog(currentPaymentType),
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
            onTap: (index) {
              final targetSection = _getSectionForIndex(index);
              if (ref.read(currentNavSectionProvider) != targetSection) {
                ref.read(currentNavSectionProvider.notifier).state = targetSection;
              }
            },
            tabs: const [
              Tab(text: 'Customer Collections'),
              Tab(text: 'Dealer Receipts'),
              Tab(text: 'Vendor Disbursements'),
              Tab(text: 'Commission Payouts'),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search payments by payment no, party name, ref doc, UTR, or notes...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 540,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentTable(_filterPayments(db.payments.where((p) => p.paymentType == PaymentType.customerPayment).toList())),
                _buildPaymentTable(_filterPayments(db.payments.where((p) => p.paymentType == PaymentType.dealerPayment).toList())),
                _buildPaymentTable(_filterPayments(db.payments.where((p) => p.paymentType == PaymentType.vendorPayment).toList())),
                _buildPaymentTable(_filterPayments(db.payments.where((p) => p.paymentType == PaymentType.commissionPayment).toList())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<ErpPayment> _filterPayments(List<ErpPayment> list) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return list;
    return list.where((p) {
      return p.paymentNumber.toLowerCase().contains(query) ||
          p.partyName.toLowerCase().contains(query) ||
          (p.referenceDocumentNumber != null && p.referenceDocumentNumber!.toLowerCase().contains(query)) ||
          (p.transactionReference != null && p.transactionReference!.toLowerCase().contains(query)) ||
          (p.paymentStatus != null && p.paymentStatus!.toLowerCase().contains(query)) ||
          p.paymentMode.name.toLowerCase().contains(query) ||
          (p.notes != null && p.notes!.toLowerCase().contains(query));
    }).toList();
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
        final parentSection = switch (p.paymentType) {
          PaymentType.customerPayment => ErpNavSection.customerPayments,
          PaymentType.dealerPayment => ErpNavSection.dealerPayments,
          PaymentType.vendorPayment => ErpNavSection.vendorPaymentsSection,
          PaymentType.commissionPayment => ErpNavSection.commissionPayments,
        };

        return [
<<<<<<< Updated upstream
          Text(p.paymentNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
=======
          InkWell(
            onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'payment', parentSection),
            child: Text(
              p.paymentNumber,
              style: AppTextStyles.bodyBold.copyWith(
                fontSize: 12,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
>>>>>>> Stashed changes
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
