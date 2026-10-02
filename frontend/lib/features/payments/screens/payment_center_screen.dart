import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/commission_model.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/models/dealer_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/models/vendor_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';

class PaymentCenterScreen extends ConsumerStatefulWidget {
  final PaymentType? initialTab;

  const PaymentCenterScreen({super.key, this.initialTab});

  @override
  ConsumerState<PaymentCenterScreen> createState() => _PaymentCenterScreenState();
}

class _PaymentCenterScreenState extends ConsumerState<PaymentCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  TextEditingController? _customerSearchCtrl;
  TextEditingController get _safeCustomerSearchCtrl => _customerSearchCtrl ??= TextEditingController();
  String _customerSearchQuery = '';
  int _customerPageSize = 10;
  int _customerCurrentPage = 0;
  int get _safeCustomerPageSize => _safeInt(_customerPageSize, 10);
  int get _safeCustomerCurrentPage => _safeInt(_customerCurrentPage, 0);

  TextEditingController? _dealerSearchCtrl;
  TextEditingController get _safeDealerSearchCtrl => _dealerSearchCtrl ??= TextEditingController();
  String _dealerSearchQuery = '';
  int _dealerPageSize = 10;
  int _dealerCurrentPage = 0;
  int get _safeDealerPageSize => _safeInt(_dealerPageSize, 10);
  int get _safeDealerCurrentPage => _safeInt(_dealerCurrentPage, 0);

  TextEditingController? _vendorSearchCtrl;
  TextEditingController get _safeVendorSearchCtrl => _vendorSearchCtrl ??= TextEditingController();
  String _vendorSearchQuery = '';
  int _vendorPageSize = 10;
  int _vendorCurrentPage = 0;
  int get _safeVendorPageSize => _safeInt(_vendorPageSize, 10);
  int get _safeVendorCurrentPage => _safeInt(_vendorCurrentPage, 0);

  @override
  void initState() {
    super.initState();
    _customerSearchCtrl ??= TextEditingController();
    _dealerSearchCtrl ??= TextEditingController();
    _vendorSearchCtrl ??= TextEditingController();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialTab != null) {
      _tabController.index = widget.initialTab!.index;
    }
    _tabController.addListener(_handleTabChange);
    Future.microtask(() {
      final db = ref.read(databaseServiceProvider);
      db.loadPayments();
      db.loadCommissions();
      db.loadCustomers();
      db.loadDealers();
      db.loadSalesInvoices();
      db.loadVendors();
      db.loadPurchases();
    });
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
    _customerSearchCtrl?.dispose();
    _dealerSearchCtrl?.dispose();
    _vendorSearchCtrl?.dispose();
    super.dispose();
  }

  void _openRecordPaymentDialog(PaymentType type, {String? preselectedPartyId}) {
    final db = ref.read(databaseServiceProvider);
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedPartyId;
    String? selectedLinkedDocId;
    bool isFullPayment = true;
    PaymentMode selectedMode = PaymentMode.bankTransfer;
    final formKey = GlobalKey<FormState>();

    if (preselectedPartyId != null) {
      selectedPartyId = preselectedPartyId;
    } else if (type == PaymentType.customerPayment && db.customers.isNotEmpty) {
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
            List<DropdownMenuItem<String>> linkedDocItems = [];
            double selectedDocPending = 0.0;
            double selectedDocTotal = 0.0;
            String? selectedDocNumber;
            String? selectedProjectId;
            String? selectedProjectName;

            if (type == PaymentType.customerPayment && selectedPartyId != null) {
              final c = db.customers.firstWhere((cust) => cust.id == selectedPartyId, orElse: () => db.customers.first);
              outstanding = c.outstandingAmount;
              partyName = c.name;
              final sales = db.sales.where((s) => s.partyId == selectedPartyId && s.pendingAmount > 0);
              linkedDocItems = sales.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.invoiceNumber} (Pending: ₹${s.pendingAmount})'))).toList();

              if (selectedLinkedDocId != null) {
                final sale = db.sales.where((s) => s.id == selectedLinkedDocId).firstOrNull;
                if (sale != null) {
                  selectedDocPending = sale.pendingAmount;
                  selectedDocTotal = sale.totalAmount;
                  selectedDocNumber = sale.invoiceNumber;
                  selectedProjectId = sale.projectId;
                  selectedProjectName = sale.projectName;
                }
              }
            } else if (type == PaymentType.dealerPayment && selectedPartyId != null) {
              final d = db.dealers.firstWhere((dlr) => dlr.id == selectedPartyId, orElse: () => db.dealers.first);
              outstanding = d.outstandingAmount;
              partyName = d.name;
              final sales = db.sales.where((s) => s.partyId == selectedPartyId && s.pendingAmount > 0);
              linkedDocItems = sales.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.invoiceNumber} (Pending: ₹${s.pendingAmount})'))).toList();

              if (selectedLinkedDocId != null) {
                final sale = db.sales.where((s) => s.id == selectedLinkedDocId).firstOrNull;
                if (sale != null) {
                  selectedDocPending = sale.pendingAmount;
                  selectedDocTotal = sale.totalAmount;
                  selectedDocNumber = sale.invoiceNumber;
                  selectedProjectId = sale.projectId;
                  selectedProjectName = sale.projectName;
                }
              }
            } else if (type == PaymentType.vendorPayment && selectedPartyId != null) {
              final v = db.vendors.firstWhere((ven) => ven.id == selectedPartyId, orElse: () => db.vendors.first);
              outstanding = v.outstandingBalance;
              partyName = v.name;
              final purchases = db.purchases.where((p) => p.vendorId == selectedPartyId && p.pendingAmount > 0);
              linkedDocItems = purchases.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.purchaseNumber} (Pending: ₹${p.pendingAmount})'))).toList();

              if (selectedLinkedDocId != null) {
                final pur = db.purchases.where((p) => p.id == selectedLinkedDocId).firstOrNull;
                if (pur != null) {
                  selectedDocPending = pur.pendingAmount;
                  selectedDocTotal = pur.totalAmount;
                  selectedDocNumber = pur.purchaseNumber;
                  selectedProjectId = pur.projectId;
                  selectedProjectName = pur.projectName;
                }
              }
            } else if (type == PaymentType.commissionPayment && selectedPartyId != null) {
              final a = db.architects.firstWhere((arc) => arc.id == selectedPartyId, orElse: () => db.architects.first);
              outstanding = a.pendingCommission;
              partyName = a.name;

              final commissions = db.commissions.where((cm) => cm.architectId == selectedPartyId && cm.status != CommissionStatus.paid);
              linkedDocItems = commissions.map((cm) => DropdownMenuItem(value: cm.id, child: Text('${cm.commissionNumber} (Amt: ₹${cm.commissionAmount})'))).toList();

              if (selectedLinkedDocId != null) {
                final comm = db.commissions.where((c) => c.id == selectedLinkedDocId).firstOrNull;
                if (comm != null) {
                  selectedDocPending = comm.commissionAmount;
                  selectedDocTotal = comm.commissionAmount;
                  selectedDocNumber = comm.commissionNumber;
                  selectedProjectId = comm.projectId;
                  selectedProjectName = comm.projectName;
                }
              }
            }

            // Sync amount when full payment is toggled
            if (isFullPayment && selectedLinkedDocId != null && selectedDocPending > 0) {
              amountCtrl.text = selectedDocPending.toStringAsFixed(0);
            }

            final currentEnteredAmt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
            final calculatedRemaining = selectedLinkedDocId != null
                ? (selectedDocPending - currentEnteredAmt).clamp(0.0, double.infinity)
                : (outstanding - currentEnteredAmt).clamp(0.0, double.infinity);

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(title, style: AppTextStyles.h2),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 540),
                width: double.infinity,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Party Outstanding Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text('Current Total Outstanding:', style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                Formatters.formatCurrency(outstanding),
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: outstanding > 0 ? AppColors.dangerText : AppColors.successText,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Party Selector
                        if (type == PaymentType.customerPayment) ...[
                          DropdownButtonFormField<String>(
                            value: selectedPartyId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Select Customer *'),
                            items: db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              setDlgState(() {
                                selectedPartyId = val;
                                selectedLinkedDocId = null;
                                amountCtrl.clear();
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ] else if (type == PaymentType.dealerPayment) ...[
                          DropdownButtonFormField<String>(
                            value: selectedPartyId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Select Dealer *'),
                            items: db.dealers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              setDlgState(() {
                                selectedPartyId = val;
                                selectedLinkedDocId = null;
                                amountCtrl.clear();
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ] else if (type == PaymentType.vendorPayment) ...[
                          DropdownButtonFormField<String>(
                            value: selectedPartyId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Select Vendor *'),
                            items: db.vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              setDlgState(() {
                                selectedPartyId = val;
                                selectedLinkedDocId = null;
                                amountCtrl.clear();
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ] else if (type == PaymentType.commissionPayment) ...[
                          DropdownButtonFormField<String>(
                            value: selectedPartyId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Select Architect / Partner *'),
                            items: db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              setDlgState(() {
                                selectedPartyId = val;
                                selectedLinkedDocId = null;
                                amountCtrl.clear();
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
                            decoration: const InputDecoration(labelText: 'Link to Unpaid Invoice / Document'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('On Account / Advance Payment (No specific doc)')),
                              ...linkedDocItems,
                            ],
                            onChanged: (val) {
                              setDlgState(() {
                                selectedLinkedDocId = val;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Full vs Partial Payment Selection
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Settlement Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Material(
                                color: Colors.transparent,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isNarrow = constraints.maxWidth < 450;
                                    if (isNarrow) {
                                      return Column(
                                        children: [
                                          RadioListTile<bool>(
                                            title: const Text('Full Payment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            subtitle: selectedDocPending > 0
                                                ? Text('Clear full balance ₹${selectedDocPending.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11))
                                                : null,
                                            value: true,
                                            groupValue: isFullPayment,
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            onChanged: (val) {
                                              if (val != null) {
                                                setDlgState(() {
                                                  isFullPayment = val;
                                                  if (selectedDocPending > 0) {
                                                    amountCtrl.text = selectedDocPending.toStringAsFixed(0);
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                          RadioListTile<bool>(
                                            title: const Text('Partial Payment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            subtitle: const Text('Enter installment amount', style: TextStyle(fontSize: 11)),
                                            value: false,
                                            groupValue: isFullPayment,
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            onChanged: (val) {
                                              if (val != null) {
                                                setDlgState(() {
                                                  isFullPayment = val;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: RadioListTile<bool>(
                                            title: const Text('Full Payment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            subtitle: selectedDocPending > 0
                                                ? Text('Clear full balance ₹${selectedDocPending.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11))
                                                : null,
                                            value: true,
                                            groupValue: isFullPayment,
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            onChanged: (val) {
                                              if (val != null) {
                                                setDlgState(() {
                                                  isFullPayment = val;
                                                  if (selectedDocPending > 0) {
                                                    amountCtrl.text = selectedDocPending.toStringAsFixed(0);
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<bool>(
                                            title: const Text('Partial Payment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            subtitle: const Text('Enter installment amount', style: TextStyle(fontSize: 11)),
                                            value: false,
                                            groupValue: isFullPayment,
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            onChanged: (val) {
                                              if (val != null) {
                                                setDlgState(() {
                                                  isFullPayment = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            final err = Validators.positiveNumber(val);
                            if (err != null) return err;
                            final parsed = double.tryParse(val ?? '0') ?? 0;
                            if (selectedLinkedDocId != null && selectedDocPending > 0 && parsed > (selectedDocPending + 0.01)) {
                              return 'Payment exceeds document pending balance of ₹${selectedDocPending.toStringAsFixed(0)}';
                            }
                            return null;
                          },
                          onChanged: (_) => setDlgState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Payment Amount (₹) *',
                            helperText: selectedLinkedDocId != null
                                ? 'Remaining Balance after this payment: ₹${calculatedRemaining.toStringAsFixed(0)}'
                                : null,
                            helperStyle: TextStyle(
                              color: calculatedRemaining > 0 ? AppColors.warningText : AppColors.successText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<PaymentMode>(
                          isExpanded: true,
                          value: selectedMode,
                          decoration: const InputDecoration(labelText: 'Payment Mode'),
                          items: PaymentMode.values.map((mode) {
                            return DropdownMenuItem(value: mode, child: Text(mode.toString().split('.').last.toUpperCase(), overflow: TextOverflow.ellipsis));
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
                          decoration: const InputDecoration(labelText: 'Notes / Remarks'),
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
                  onPressed: () {
                    FocusScope.of(ctx).unfocus();
                    Navigator.of(ctx).pop();
                  },
                ),
                ErpButton(
                  text: 'Save Payment Entry',
                  icon: Icons.check,
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final amt = double.parse(amountCtrl.text.trim());

                    final payment = ErpPayment(
                      id: IdGenerator.generateId('PAY'),
                      paymentNumber: IdGenerator.generateDocNumber('PAY', db.nextAdjustmentNumber + 100),
                      paymentType: type,
                      partyId: selectedPartyId!,
                      partyName: partyName,
                      referenceDocumentId: selectedLinkedDocId,
                      referenceDocumentNumber: selectedDocNumber,
                      amount: amt,
                      paymentMode: selectedMode,
                      paymentDate: DateTime.now(),
                      transactionReference: refCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      isFullPayment: isFullPayment || (selectedDocPending > 0 && amt >= selectedDocPending),
                      totalDocumentAmount: selectedDocTotal > 0 ? selectedDocTotal : amt,
                      remainingAmount: calculatedRemaining,
                      projectId: selectedProjectId,
                      projectName: selectedProjectName,
                      createdAt: DateTime.now(),
                    );

                    db.addPaymentAsync(payment);
                    FocusScope.of(ctx).unfocus();
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Payment ${payment.paymentNumber} recorded! Invoice & balance updated.'),
                        backgroundColor: AppColors.success,
                      ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isSmall ? double.infinity : constraints.maxWidth - 240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payments & Treasury Center', style: AppTextStyles.h1),
                        const SizedBox(height: 4),
                        Text(
                          'Manual payment entry (Full & Partial), invoice balance auto-reconciliation, and treasury tracking',
                          style: AppTextStyles.subtitle,
                        ),
                      ],
                    ),
                  ),
                  ErpButton(
                    text: buttonLabel,
                    icon: Icons.add,
                    onPressed: () => _openRecordPaymentDialog(currentPaymentType),
                  ),
                ],
              );
            },
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

          if (_tabController.index > 2) ...[
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search payments by payment no, party name, ref doc, UTR, or notes...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            height: 680,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomerCollectionsTab(db),
                _buildDealerReceiptsTab(db),
                _buildVendorDisbursementsTab(db),
                _buildPaymentTable(_filterPayments(db.payments.where((p) => p.paymentType == PaymentType.commissionPayment).toList())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _safeStr(Object? val) => (val == null) ? '' : val.toString().trim();
  static String _safeLower(Object? val) => (val == null) ? '' : val.toString().trim().toLowerCase();
  static int _safeInt(Object? val, int fallback) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? fallback;
  }
  static double _safeDouble(Object? val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? fallback;
  }

  Widget _buildCustomerCollectionsTab(MockDatabaseService db) {
    final allSummaries = _computeCustomerSummaries(db);
    final query = _safeLower(_customerSearchQuery);
    final filtered = query.isEmpty
        ? allSummaries
        : allSummaries.where((s) {
            final c = s.customer;
            return _safeLower(c.name).contains(query) ||
                _safeLower(c.mobile).contains(query) ||
                _safeLower(c.gstNumber).contains(query) ||
                _safeLower(c.address).contains(query);
          }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeCustomerPageSize;
    final currentPage = _safeCustomerCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageSummaries = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <CustomerAccountSummary>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage customer accounts and track balances',
            style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _buildCustomerControlsRow(totalCount, pageSummaries.length),
          const SizedBox(height: 16),
          _buildCustomerAccountsTable(pageSummaries),
        ],
      ),
    );
  }

  Widget _buildCustomerControlsRow(int totalCount, int shownCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final ctrl = _safeCustomerSearchCtrl;
        final pageSize = _safeCustomerPageSize;
        final currentPage = _safeCustomerCurrentPage;

        final searchBox = SizedBox(
          width: isNarrow ? double.infinity : 320,
          height: 42,
          child: TextField(
            controller: ctrl,
            onChanged: (val) {
              setState(() {
                _customerSearchQuery = val;
                _customerCurrentPage = 0;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search customers...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        );

        final paginationControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Show:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: (pageSize == 5 || pageSize == 10 || pageSize == 25 || pageSize == 50) ? pageSize : 10,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _customerPageSize = val;
                        _customerCurrentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Showing $shownCount of $totalCount customers',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (totalCount > pageSize) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage > 0
                    ? () => setState(() => _customerCurrentPage = currentPage - 1)
                    : null,
              ),
              Text(
                '${currentPage + 1}/${max(1, (totalCount / pageSize).ceil())}',
                style: AppTextStyles.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: (currentPage + 1) * pageSize < totalCount
                    ? () => setState(() => _customerCurrentPage = currentPage + 1)
                    : null,
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchBox,
              const SizedBox(height: 10),
              paginationControls,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            searchBox,
            paginationControls,
          ],
        );
      },
    );
  }

  Widget _buildCustomerAccountsTable(List<CustomerAccountSummary> summaries) {
    if (summaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No matching customers found', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 900),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: AppTextStyles.tableHeader,
                dataTextStyle: AppTextStyles.tableCell,
                dividerThickness: 1,
                horizontalMargin: 20,
                columnSpacing: 28,
                headingRowHeight: 46,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                columns: [
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('CUSTOMER NAME', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_rupee, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('SALE TOTAL', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text('PAID AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.percent, size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 4),
                        Text('DISCOUNT GIVEN', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('PENDING AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('ACTIONS', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
                rows: summaries.map((summary) {
                  return DataRow(
                    cells: [
                      // CUSTOMER NAME
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person, color: Color(0xFF0284C7), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  summary.customer.name.isNotEmpty ? summary.customer.name : 'Unnamed Customer',
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.description_outlined, size: 11, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${summary.transactionCount} transactions',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // SALE TOTAL
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.saleTotal),
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                        ),
                      ),
                      // PAID AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.paidAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // DISCOUNT GIVEN
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.discountGiven),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      // PENDING AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.pendingAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // ACTIONS
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note_rounded, size: 16),
                              label: const Text('Transaction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                side: const BorderSide(color: Color(0xFFBAE6FD)),
                                backgroundColor: const Color(0xFFF0F9FF),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openRecordPaymentDialog(
                                PaymentType.customerPayment,
                                preselectedPartyId: summary.customer.id,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.visibility_outlined, size: 15),
                              label: const Text('History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openCustomerHistoryDialog(summary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCustomerHistoryDialog(CustomerAccountSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 960, maxHeight: 680),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.customer.name.isNotEmpty ? summary.customer.name : 'Unnamed Customer',
                              style: AppTextStyles.h2.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Customer Ledger & Transaction Statement (Sheet 2)',
                              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildHistoryStatCard('Sale Total', Formatters.formatCurrency(summary.saleTotal), Colors.black87),
                    _buildHistoryStatCard('Paid Amount', Formatters.formatCurrency(summary.paidAmount), const Color(0xFF16A34A)),
                    _buildHistoryStatCard('Discount Given', Formatters.formatCurrency(summary.discountGiven), const Color(0xFF7C3AED)),
                    _buildHistoryStatCard(
                      'Net Pending',
                      Formatters.formatCurrency(summary.pendingAmount),
                      summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 8-Column Ledger Table (Sheet 2)
                Expanded(
                  child: summary.entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('No transactions recorded yet for this customer.', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        )
                      : ErpDataTable(
                          columns: const [
                            ErpColumn(title: 'Doc / Name'),
                            ErpColumn(title: 'Total Pending', isNumeric: true),
                            ErpColumn(title: 'Type'),
                            ErpColumn(title: 'Date'),
                            ErpColumn(title: 'Mode'),
                            ErpColumn(title: 'Discount', isNumeric: true),
                            ErpColumn(title: 'New Pending', isNumeric: true),
                            ErpColumn(title: 'Remarks'),
                          ],
                          rows: summary.entries.map((entry) {
                            return [
                              Text(entry.docNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary)),
                              Text(Formatters.formatCurrency(entry.openingPending), style: AppTextStyles.bodySmall),
                              entry.type == 'Sale Invoice'
                                  ? ErpStatusBadge.info('SALE')
                                  : ErpStatusBadge.success('RECEIPT'),
                              Text(Formatters.formatDate(entry.date), style: AppTextStyles.bodySmall),
                              ErpStatusBadge.neutral(entry.paymentMode),
                              Text(Formatters.formatCurrency(entry.discount), style: AppTextStyles.bodySmall),
                              Text(
                                Formatters.formatCurrency(entry.closingPending),
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 12,
                                  color: entry.closingPending > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                ),
                              ),
                              Text(entry.remarks, style: AppTextStyles.bodySmall),
                            ];
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),

                // Action buttons footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ErpButton(
                      text: 'Close',
                      isOutlined: true,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Record Transaction',
                      icon: Icons.edit_note_rounded,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                        _openRecordPaymentDialog(PaymentType.customerPayment, preselectedPartyId: summary.customer.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDealerReceiptsTab(MockDatabaseService db) {
    final allSummaries = _computeDealerSummaries(db);
    final query = _safeLower(_dealerSearchQuery);
    final filtered = query.isEmpty
        ? allSummaries
        : allSummaries.where((s) {
            final d = s.dealer;
            return _safeLower(d.name).contains(query) ||
                _safeLower(d.companyName).contains(query) ||
                _safeLower(d.mobile).contains(query) ||
                _safeLower(d.gstNumber).contains(query) ||
                _safeLower(d.address).contains(query);
          }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeDealerPageSize;
    final currentPage = _safeDealerCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageSummaries = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <DealerAccountSummary>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage dealer accounts and track balances (Sheet 2)',
            style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _buildDealerControlsRow(totalCount, pageSummaries.length),
          const SizedBox(height: 16),
          _buildDealerAccountsTable(pageSummaries),
        ],
      ),
    );
  }

  Widget _buildDealerControlsRow(int totalCount, int shownCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final ctrl = _safeDealerSearchCtrl;
        final pageSize = _safeDealerPageSize;
        final currentPage = _safeDealerCurrentPage;

        final searchBox = SizedBox(
          width: isNarrow ? double.infinity : 320,
          height: 42,
          child: TextField(
            controller: ctrl,
            onChanged: (val) {
              setState(() {
                _dealerSearchQuery = val;
                _dealerCurrentPage = 0;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search dealers...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        );

        final paginationControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Show:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: (pageSize == 5 || pageSize == 10 || pageSize == 25 || pageSize == 50) ? pageSize : 10,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _dealerPageSize = val;
                        _dealerCurrentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Showing $shownCount of $totalCount dealers',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (totalCount > pageSize) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage > 0
                    ? () => setState(() => _dealerCurrentPage = currentPage - 1)
                    : null,
              ),
              Text(
                '${currentPage + 1}/${max(1, (totalCount / pageSize).ceil())}',
                style: AppTextStyles.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: (currentPage + 1) * pageSize < totalCount
                    ? () => setState(() => _dealerCurrentPage = currentPage + 1)
                    : null,
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchBox,
              const SizedBox(height: 10),
              paginationControls,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            searchBox,
            paginationControls,
          ],
        );
      },
    );
  }

  Widget _buildDealerAccountsTable(List<DealerAccountSummary> summaries) {
    if (summaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No matching dealers found', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 900),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: AppTextStyles.tableHeader,
                dataTextStyle: AppTextStyles.tableCell,
                dividerThickness: 1,
                horizontalMargin: 20,
                columnSpacing: 28,
                headingRowHeight: 46,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                columns: [
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('DEALER NAME', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_rupee, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('SALE TOTAL', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text('PAID AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.percent, size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 4),
                        Text('DISCOUNT GIVEN', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
                      ],
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('PENDING AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('ACTIONS', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
                rows: summaries.map((summary) {
                  return DataRow(
                    cells: [
                      // DEALER NAME
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.storefront_outlined, color: Color(0xFF16A34A), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  summary.dealer.name.isNotEmpty ? summary.dealer.name : 'Unnamed Dealer',
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.description_outlined, size: 11, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      (summary.dealer.companyName.isNotEmpty)
                                          ? '${summary.dealer.companyName} • ${summary.transactionCount} transactions'
                                          : '${summary.transactionCount} transactions',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // SALE TOTAL
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.saleTotal),
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                        ),
                      ),
                      // PAID AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.paidAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // DISCOUNT GIVEN
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.discountGiven),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      // PENDING AMOUNT
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.pendingAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // ACTIONS
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note_rounded, size: 16),
                              label: const Text('Transaction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                side: const BorderSide(color: Color(0xFFBAE6FD)),
                                backgroundColor: const Color(0xFFF0F9FF),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openRecordPaymentDialog(
                                PaymentType.dealerPayment,
                                preselectedPartyId: summary.dealer.id,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.visibility_outlined, size: 15),
                              label: const Text('History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openDealerHistoryDialog(summary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openDealerHistoryDialog(DealerAccountSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 960, maxHeight: 680),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.storefront_outlined, color: Color(0xFF16A34A)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.dealer.name.isNotEmpty ? summary.dealer.name : 'Unnamed Dealer',
                              style: AppTextStyles.h2.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dealer Ledger & Transaction Statement (Sheet 2)',
                              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildHistoryStatCard('Sale Total', Formatters.formatCurrency(summary.saleTotal), Colors.black87),
                    _buildHistoryStatCard('Paid Amount', Formatters.formatCurrency(summary.paidAmount), const Color(0xFF16A34A)),
                    _buildHistoryStatCard('Discount Given', Formatters.formatCurrency(summary.discountGiven), const Color(0xFF7C3AED)),
                    _buildHistoryStatCard(
                      'Net Pending',
                      Formatters.formatCurrency(summary.pendingAmount),
                      summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 8-Column Ledger Table (Sheet 2)
                Expanded(
                  child: summary.entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('No transactions recorded yet for this dealer.', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        )
                      : ErpDataTable(
                          columns: const [
                            ErpColumn(title: 'Doc / Name'),
                            ErpColumn(title: 'Total Pending', isNumeric: true),
                            ErpColumn(title: 'Type'),
                            ErpColumn(title: 'Date'),
                            ErpColumn(title: 'Mode'),
                            ErpColumn(title: 'Discount', isNumeric: true),
                            ErpColumn(title: 'New Pending', isNumeric: true),
                            ErpColumn(title: 'Remarks'),
                          ],
                          rows: summary.entries.map((entry) {
                            return [
                              Text(entry.docNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary)),
                              Text(Formatters.formatCurrency(entry.openingPending), style: AppTextStyles.bodySmall),
                              entry.type == 'Sale Invoice'
                                  ? ErpStatusBadge.info('SALE')
                                  : ErpStatusBadge.success('RECEIPT'),
                              Text(Formatters.formatDate(entry.date), style: AppTextStyles.bodySmall),
                              ErpStatusBadge.neutral(entry.paymentMode),
                              Text(Formatters.formatCurrency(entry.discount), style: AppTextStyles.bodySmall),
                              Text(
                                Formatters.formatCurrency(entry.closingPending),
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 12,
                                  color: entry.closingPending > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                ),
                              ),
                              Text(entry.remarks, style: AppTextStyles.bodySmall),
                            ];
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),

                // Action buttons footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ErpButton(
                      text: 'Close',
                      isOutlined: true,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Record Transaction',
                      icon: Icons.edit_note_rounded,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                        _openRecordPaymentDialog(PaymentType.dealerPayment, preselectedPartyId: summary.dealer.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DealerAccountSummary> _computeDealerSummaries(MockDatabaseService db) {
    final summaries = <DealerAccountSummary>[];

    for (final dealer in db.dealers) {
      if (dealer.isDeleted) continue;

      final String dId = _safeStr(dealer.id);
      final String dName = _safeLower(dealer.name);
      final String dComp = _safeLower(dealer.companyName);

      final dealerSales = db.sales.where((s) {
        final sPartyId = _safeStr(s.partyId);
        final sPartyName = _safeLower(s.partyName);
        final matchesId = dId.isNotEmpty && sPartyId == dId;
        final matchesName = (dName.isNotEmpty && sPartyName == dName) || (dComp.isNotEmpty && sPartyName == dComp);
        final isRelevantType = s.documentType == SalesDocumentType.invoice || s.documentType == SalesDocumentType.salesOrder;
        return (matchesId || matchesName) && isRelevantType;
      }).toList();

      final dealerPayments = db.payments.where((p) {
        final pPartyId = _safeStr(p.partyId);
        final pPartyName = _safeLower(p.partyName);
        final matchesId = dId.isNotEmpty && pPartyId == dId;
        final matchesName = (dName.isNotEmpty && pPartyName == dName) || (dComp.isNotEmpty && pPartyName == dComp);
        final isDealerPayment = p.paymentType == PaymentType.dealerPayment;
        return (matchesId || matchesName) && isDealerPayment;
      }).toList();

      final events = <_LedgerRawEvent>[];
      for (final s in dealerSales) {
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(s.invoiceNumber).isNotEmpty ? s.invoiceNumber : 'INV-UNTITLED',
          isSale: true,
          date: s.saleDate,
          amount: s.totalAmount,
          discount: s.discountAmount,
          mode: 'INVOICE',
          notes: (s.notes != null && s.notes!.isNotEmpty) ? s.notes! : 'Tax Invoice',
        ));
      }
      for (final p in dealerPayments) {
        final modeLabel = p.paymentMode.name.toUpperCase();
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(p.paymentNumber).isNotEmpty ? p.paymentNumber : 'PAY-UNTITLED',
          isSale: false,
          date: p.paymentDate,
          amount: p.amount,
          discount: 0.0,
          mode: modeLabel,
          notes: (p.transactionReference != null && p.transactionReference!.isNotEmpty)
              ? '${p.notes != null && p.notes!.isNotEmpty ? p.notes : "Payment"} (Ref: ${p.transactionReference})'
              : (p.notes != null && p.notes!.isNotEmpty ? p.notes! : 'Dealer Receipt'),
        ));
      }
      events.sort((a, b) => a.date.compareTo(b.date));

      double runningPending = 0.0;
      final entries = <CustomerLedgerEntry>[];
      for (final ev in events) {
        final opening = runningPending;
        if (ev.isSale) {
          runningPending = opening + ev.amount;
        } else {
          runningPending = (opening - ev.amount).clamp(0.0, double.infinity);
        }
        entries.add(CustomerLedgerEntry(
          docNumber: ev.docNumber,
          openingPending: opening,
          type: ev.isSale ? 'Sale Invoice' : 'Dealer Receipt',
          date: ev.date,
          paymentMode: ev.mode,
          discount: ev.discount,
          closingPending: runningPending,
          remarks: ev.notes,
        ));
      }

      final double saleTotal = dealerSales.fold(0.0, (acc, s) => acc + _safeDouble(s.totalAmount));
      final double paidAmount = dealerPayments.fold(0.0, (acc, p) => acc + _safeDouble(p.amount));
      final double discountGiven = dealerSales.fold(0.0, (acc, s) => acc + _safeDouble(s.discountAmount));
      final double dealerOutstanding = _safeDouble(dealer.outstandingAmount);

      double pendingAmount;
      if (dealerSales.isNotEmpty || dealerPayments.isNotEmpty) {
        pendingAmount = (saleTotal - paidAmount - discountGiven).clamp(0.0, double.infinity);
      } else {
        pendingAmount = dealerOutstanding;
      }

      final double effectiveSaleTotal = (dealerSales.isEmpty && dealerPayments.isEmpty && dealerOutstanding > 0)
          ? dealerOutstanding
          : saleTotal;

      summaries.add(DealerAccountSummary(
        dealer: dealer,
        saleTotal: effectiveSaleTotal,
        paidAmount: paidAmount,
        discountGiven: discountGiven,
        pendingAmount: pendingAmount,
        transactionCount: events.length,
        entries: entries,
      ));
    }

    return summaries;
  }

  Widget _buildVendorDisbursementsTab(MockDatabaseService db) {
    final allSummaries = _computeVendorSummaries(db);
    final query = _safeLower(_vendorSearchQuery);
    final filtered = query.isEmpty
        ? allSummaries
        : allSummaries.where((s) {
            final v = s.vendor;
            return _safeLower(v.name).contains(query) ||
                _safeLower(v.contactPerson).contains(query) ||
                _safeLower(v.mobile).contains(query) ||
                _safeLower(v.email).contains(query) ||
                _safeLower(v.gstNumber).contains(query) ||
                _safeLower(v.panNumber).contains(query) ||
                _safeLower(v.address).contains(query);
          }).toList();

    final totalCount = filtered.length;
    final pageSize = _safeVendorPageSize;
    final currentPage = _safeVendorCurrentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageSummaries = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <VendorAccountSummary>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage vendor accounts and track balances (Sheet 2)',
            style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _buildVendorControlsRow(totalCount, pageSummaries.length),
          const SizedBox(height: 16),
          _buildVendorAccountsTable(pageSummaries),
        ],
      ),
    );
  }

  Widget _buildVendorControlsRow(int totalCount, int shownCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final ctrl = _safeVendorSearchCtrl;
        final pageSize = _safeVendorPageSize;
        final currentPage = _safeVendorCurrentPage;

        final searchBox = SizedBox(
          width: isNarrow ? double.infinity : 320,
          height: 42,
          child: TextField(
            controller: ctrl,
            onChanged: (val) {
              setState(() {
                _vendorSearchQuery = val;
                _vendorCurrentPage = 0;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search vendors...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        );

        final paginationControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Show:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: (pageSize == 10 || pageSize == 25 || pageSize == 50) ? pageSize : 10,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (newSize) {
                    if (newSize != null) {
                      setState(() {
                        _vendorPageSize = newSize;
                        _vendorCurrentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Showing $shownCount of $totalCount',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (totalCount > pageSize) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage > 0
                    ? () => setState(() => _vendorCurrentPage = currentPage - 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: (currentPage + 1) * pageSize < totalCount
                    ? () => setState(() => _vendorCurrentPage = currentPage + 1)
                    : null,
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchBox,
              const SizedBox(height: 10),
              paginationControls,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            searchBox,
            paginationControls,
          ],
        );
      },
    );
  }

  Widget _buildVendorAccountsTable(List<VendorAccountSummary> summaries) {
    if (summaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No matching vendors found', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 900),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: AppTextStyles.tableHeader,
                dataTextStyle: AppTextStyles.tableCell,
                dividerThickness: 1,
                horizontalMargin: 20,
                columnSpacing: 28,
                headingRowHeight: 46,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                columns: [
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('VENDOR NAME', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('PURCHASE TOTAL', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('PAID AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.discount_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('DISCOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_actions_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('PENDING AMOUNT', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('ACTIONS', style: AppTextStyles.tableHeader.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
                rows: summaries.map((summary) {
                  final initial = summary.vendor.name.trim().isNotEmpty
                      ? summary.vendor.name.trim().substring(0, 1).toUpperCase()
                      : 'V';

                  return DataRow(
                    cells: [
                      // Vendor Name + Subtitle
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(
                                initial,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  summary.vendor.name.isNotEmpty ? summary.vendor.name : 'Unnamed Vendor',
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${summary.transactionCount} transactions${summary.vendor.contactPerson.isNotEmpty ? " • ${summary.vendor.contactPerson}" : ""}',
                                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Purchase Total
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.purchaseTotal),
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                        ),
                      ),
                      // Paid Amount
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.paidAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: summary.paidAmount > 0 ? const Color(0xFF16A34A) : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      // Discount
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.discountGiven),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: summary.discountGiven > 0 ? const Color(0xFF7C3AED) : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      // Pending Amount
                      DataCell(
                        Text(
                          Formatters.formatCurrency(summary.pendingAmount),
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      // Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note_rounded, size: 15),
                              label: const Text('Transaction', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () {
                                _openRecordPaymentDialog(
                                  PaymentType.vendorPayment,
                                  preselectedPartyId: summary.vendor.id,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.history_rounded, size: 15),
                              label: const Text('History', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _openVendorHistoryDialog(summary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openVendorHistoryDialog(VendorAccountSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 1000,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.vendor.name.isNotEmpty ? summary.vendor.name : 'Unnamed Vendor',
                              style: AppTextStyles.h2.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vendor Ledger & Transaction Statement (Sheet 2)',
                              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildHistoryStatCard('Purchase Total', Formatters.formatCurrency(summary.purchaseTotal), Colors.black87),
                    _buildHistoryStatCard('Paid Amount', Formatters.formatCurrency(summary.paidAmount), const Color(0xFF16A34A)),
                    _buildHistoryStatCard('Discount Given', Formatters.formatCurrency(summary.discountGiven), const Color(0xFF7C3AED)),
                    _buildHistoryStatCard(
                      'Net Pending',
                      Formatters.formatCurrency(summary.pendingAmount),
                      summary.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 8-Column Ledger Table (Sheet 2)
                Expanded(
                  child: summary.entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text('No ledger entries recorded yet', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        )
                      : ErpDataTable(
                          columns: const [
                            ErpColumn(title: 'Doc / Name'),
                            ErpColumn(title: 'Total Pending (Opening)', isNumeric: true),
                            ErpColumn(title: 'Type'),
                            ErpColumn(title: 'Date'),
                            ErpColumn(title: 'Mode'),
                            ErpColumn(title: 'Discount', isNumeric: true),
                            ErpColumn(title: 'New Pending (Closing)', isNumeric: true),
                            ErpColumn(title: 'Remarks'),
                          ],
                          rows: summary.entries.map((entry) {
                            final isPurchase = entry.type.toLowerCase().contains('purchase') || entry.type.toLowerCase().contains('invoice');
                            return [
                              Text(
                                entry.docNumber,
                                style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.primary),
                              ),
                              Text(Formatters.formatCurrency(entry.openingPending), style: AppTextStyles.bodySmall),
                              isPurchase
                                  ? ErpStatusBadge.neutral(entry.type)
                                  : ErpStatusBadge.success(entry.type),
                              Text(Formatters.formatDate(entry.date), style: AppTextStyles.bodySmall),
                              ErpStatusBadge.neutral(entry.paymentMode),
                              Text(Formatters.formatCurrency(entry.discount), style: AppTextStyles.bodySmall),
                              Text(
                                Formatters.formatCurrency(entry.closingPending),
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 12,
                                  color: entry.closingPending > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                ),
                              ),
                              Text(entry.remarks, style: AppTextStyles.bodySmall),
                            ];
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),

                // Action buttons footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ErpButton(
                      text: 'Close',
                      isOutlined: true,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Record Transaction',
                      icon: Icons.edit_note_rounded,
                      onPressed: () {
                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop();
                        _openRecordPaymentDialog(PaymentType.vendorPayment, preselectedPartyId: summary.vendor.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<VendorAccountSummary> _computeVendorSummaries(MockDatabaseService db) {
    final summaries = <VendorAccountSummary>[];

    for (final vendor in db.vendors) {
      if (vendor.isDeleted) continue;

      final String vId = _safeStr(vendor.id);
      final String vName = _safeLower(vendor.name);

      final vendorPurchases = db.purchases.where((p) {
        final pVendorId = _safeStr(p.vendorId);
        final pVendorName = _safeLower(p.vendorName);
        final matchesId = vId.isNotEmpty && pVendorId == vId;
        final matchesName = vName.isNotEmpty && pVendorName == vName;
        final isNotCancelled = p.status != PurchaseStatus.cancelled;
        return (matchesId || matchesName) && isNotCancelled;
      }).toList();

      final vendorPayments = db.payments.where((p) {
        final pPartyId = _safeStr(p.partyId);
        final pPartyName = _safeLower(p.partyName);
        final matchesId = vId.isNotEmpty && pPartyId == vId;
        final matchesName = vName.isNotEmpty && pPartyName == vName;
        final isVendorPayment = p.paymentType == PaymentType.vendorPayment;
        return (matchesId || matchesName) && isVendorPayment;
      }).toList();

      final events = <_LedgerRawEvent>[];
      for (final p in vendorPurchases) {
        final docNum = _safeStr(p.purchaseNumber).isNotEmpty
            ? p.purchaseNumber
            : (_safeStr(p.vendorInvoiceNumber).isNotEmpty ? p.vendorInvoiceNumber : 'PUR-UNTITLED');
        events.add(_LedgerRawEvent(
          docNumber: docNum,
          isSale: true,
          date: p.purchaseDate,
          amount: p.totalAmount,
          discount: p.discountAmount,
          mode: 'PURCHASE',
          notes: (p.notes != null && p.notes!.isNotEmpty) ? p.notes! : 'Purchase Invoice',
        ));
      }

      for (final p in vendorPayments) {
        final modeLabel = p.paymentMode.name.toUpperCase();
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(p.paymentNumber).isNotEmpty ? p.paymentNumber : 'PAY-UNTITLED',
          isSale: false,
          date: p.paymentDate,
          amount: p.amount,
          discount: 0.0,
          mode: modeLabel,
          notes: (p.transactionReference != null && p.transactionReference!.isNotEmpty)
              ? '${p.notes != null && p.notes!.isNotEmpty ? p.notes : "Payment"} (Ref: ${p.transactionReference})'
              : (p.notes != null && p.notes!.isNotEmpty ? p.notes! : 'Vendor Payment'),
        ));
      }

      events.sort((a, b) => a.date.compareTo(b.date));

      double runningPending = 0.0;
      final entries = <CustomerLedgerEntry>[];
      for (final ev in events) {
        final opening = runningPending;
        if (ev.isSale) {
          runningPending = opening + ev.amount;
        } else {
          runningPending = (opening - ev.amount).clamp(0.0, double.infinity);
        }
        entries.add(CustomerLedgerEntry(
          docNumber: ev.docNumber,
          openingPending: opening,
          type: ev.isSale ? 'Purchase Invoice' : 'Vendor Payment',
          date: ev.date,
          paymentMode: ev.mode,
          discount: ev.discount,
          closingPending: runningPending,
          remarks: ev.notes,
        ));
      }

      final double purchaseTotal = vendorPurchases.fold(0.0, (acc, p) => acc + _safeDouble(p.totalAmount));
      final double paidAmount = vendorPayments.fold(0.0, (acc, p) => acc + _safeDouble(p.amount));
      final double discountGiven = vendorPurchases.fold(0.0, (acc, p) => acc + _safeDouble(p.discountAmount));
      final double vendorOutstanding = _safeDouble(vendor.outstandingBalance);

      double pendingAmount;
      if (vendorPurchases.isNotEmpty || vendorPayments.isNotEmpty) {
        pendingAmount = (purchaseTotal - paidAmount - discountGiven).clamp(0.0, double.infinity);
      } else {
        pendingAmount = vendorOutstanding;
      }

      final double effectivePurchaseTotal = (vendorPurchases.isEmpty && vendorPayments.isEmpty && vendorOutstanding > 0)
          ? vendorOutstanding
          : purchaseTotal;

      summaries.add(VendorAccountSummary(
        vendor: vendor,
        purchaseTotal: effectivePurchaseTotal,
        paidAmount: paidAmount,
        discountGiven: discountGiven,
        pendingAmount: pendingAmount,
        transactionCount: events.length,
        entries: entries,
      ));
    }

    return summaries;
  }

  Widget _buildHistoryStatCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  List<CustomerAccountSummary> _computeCustomerSummaries(MockDatabaseService db) {
    final summaries = <CustomerAccountSummary>[];

    for (final customer in db.customers) {
      if (customer.isDeleted) continue;

      final String cId = _safeStr(customer.id);
      final String cName = _safeLower(customer.name);

      final customerSales = db.sales.where((s) {
        final sPartyId = _safeStr(s.partyId);
        final sPartyName = _safeLower(s.partyName);
        final matchesId = cId.isNotEmpty && sPartyId == cId;
        final matchesName = cName.isNotEmpty && sPartyName == cName;
        final isRelevantType = s.documentType == SalesDocumentType.invoice || s.documentType == SalesDocumentType.salesOrder;
        return (matchesId || matchesName) && isRelevantType;
      }).toList();

      final customerPayments = db.payments.where((p) {
        final pPartyId = _safeStr(p.partyId);
        final pPartyName = _safeLower(p.partyName);
        final matchesId = cId.isNotEmpty && pPartyId == cId;
        final matchesName = cName.isNotEmpty && pPartyName == cName;
        final isCustomerPayment = p.paymentType == PaymentType.customerPayment;
        return (matchesId || matchesName) && isCustomerPayment;
      }).toList();

      final events = <_LedgerRawEvent>[];
      for (final s in customerSales) {
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(s.invoiceNumber).isNotEmpty ? s.invoiceNumber : 'INV-UNTITLED',
          isSale: true,
          date: s.saleDate,
          amount: s.totalAmount,
          discount: s.discountAmount,
          mode: 'INVOICE',
          notes: (s.notes != null && s.notes!.isNotEmpty) ? s.notes! : 'Tax Invoice',
        ));
      }
      for (final p in customerPayments) {
        final modeLabel = p.paymentMode.name.toUpperCase();
        events.add(_LedgerRawEvent(
          docNumber: _safeStr(p.paymentNumber).isNotEmpty ? p.paymentNumber : 'PAY-UNTITLED',
          isSale: false,
          date: p.paymentDate,
          amount: p.amount,
          discount: 0.0,
          mode: modeLabel,
          notes: (p.transactionReference != null && p.transactionReference!.isNotEmpty)
              ? '${p.notes != null && p.notes!.isNotEmpty ? p.notes : "Payment"} (Ref: ${p.transactionReference})'
              : (p.notes != null && p.notes!.isNotEmpty ? p.notes! : 'Customer Receipt'),
        ));
      }
      events.sort((a, b) => a.date.compareTo(b.date));

      double runningPending = 0.0;
      final entries = <CustomerLedgerEntry>[];
      for (final ev in events) {
        final opening = runningPending;
        if (ev.isSale) {
          runningPending = opening + ev.amount;
        } else {
          runningPending = (opening - ev.amount).clamp(0.0, double.infinity);
        }
        entries.add(CustomerLedgerEntry(
          docNumber: ev.docNumber,
          openingPending: opening,
          type: ev.isSale ? 'Sale Invoice' : 'Customer Receipt',
          date: ev.date,
          paymentMode: ev.mode,
          discount: ev.discount,
          closingPending: runningPending,
          remarks: ev.notes,
        ));
      }

      final double saleTotal = customerSales.fold(0.0, (acc, s) => acc + _safeDouble(s.totalAmount));
      final double paidAmount = customerPayments.fold(0.0, (acc, p) => acc + _safeDouble(p.amount));
      final double discountGiven = customerSales.fold(0.0, (acc, s) => acc + _safeDouble(s.discountAmount));
      final double custOutstanding = _safeDouble(customer.outstandingAmount);

      double pendingAmount;
      if (customerSales.isNotEmpty || customerPayments.isNotEmpty) {
        pendingAmount = (saleTotal - paidAmount - discountGiven).clamp(0.0, double.infinity);
      } else {
        pendingAmount = custOutstanding;
      }

      final double effectiveSaleTotal = (customerSales.isEmpty && customerPayments.isEmpty && custOutstanding > 0)
          ? custOutstanding
          : saleTotal;

      summaries.add(CustomerAccountSummary(
        customer: customer,
        saleTotal: effectiveSaleTotal,
        paidAmount: paidAmount,
        discountGiven: discountGiven,
        pendingAmount: pendingAmount,
        transactionCount: events.length,
        entries: entries,
      ));
    }

    return summaries;
  }

  List<ErpPayment> _filterPayments(List<ErpPayment> list) {
    final query = _safeLower(_searchQuery);
    if (query.isEmpty) return list;
    return list.where((p) {
      return _safeLower(p.paymentNumber).contains(query) ||
          _safeLower(p.partyName).contains(query) ||
          _safeLower(p.referenceDocumentNumber).contains(query) ||
          _safeLower(p.transactionReference).contains(query) ||
          _safeLower(p.paymentMode.name).contains(query) ||
          _safeLower(p.notes).contains(query);
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
        ErpColumn(title: 'Settlement'),
        ErpColumn(title: 'Remaining (₹)', isNumeric: true),
        ErpColumn(title: 'Payment Mode'),
        ErpColumn(title: 'UTR / Ref No'),
      ],
      rows: payments.map((p) {
        final parentSection = switch (p.paymentType) {
          PaymentType.customerPayment => ErpNavSection.customerPayments,
          PaymentType.dealerPayment => ErpNavSection.dealerPayments,
          PaymentType.vendorPayment => ErpNavSection.vendorPaymentsSection,
          PaymentType.commissionPayment => ErpNavSection.commissionPayments,
        };

        return [
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
          p.isFullPayment ? ErpStatusBadge.success('FULL') : ErpStatusBadge.warning('PARTIAL'),
          Text(
            p.remainingAmount != null ? Formatters.formatCurrency(p.remainingAmount!) : '-',
            style: AppTextStyles.bodySmall.copyWith(
              color: (p.remainingAmount ?? 0) > 0 ? AppColors.warningText : AppColors.successText,
              fontWeight: FontWeight.w600,
            ),
          ),
          ErpStatusBadge.neutral(p.paymentMode.toString().split('.').last.toUpperCase()),
          Text(p.transactionReference ?? '-', style: AppTextStyles.bodySmall),
        ];
      }).toList(),
    );
  }
}

class CustomerAccountSummary {
  final Customer customer;
  final double saleTotal;
  final double paidAmount;
  final double discountGiven;
  final double pendingAmount;
  final int transactionCount;
  final List<CustomerLedgerEntry> entries;

  CustomerAccountSummary({
    required this.customer,
    required this.saleTotal,
    required this.paidAmount,
    required this.discountGiven,
    required this.pendingAmount,
    required this.transactionCount,
    required this.entries,
  });
}

class DealerAccountSummary {
  final Dealer dealer;
  final double saleTotal;
  final double paidAmount;
  final double discountGiven;
  final double pendingAmount;
  final int transactionCount;
  final List<CustomerLedgerEntry> entries;

  DealerAccountSummary({
    required this.dealer,
    required this.saleTotal,
    required this.paidAmount,
    required this.discountGiven,
    required this.pendingAmount,
    required this.transactionCount,
    required this.entries,
  });
}

class VendorAccountSummary {
  final Vendor vendor;
  final double purchaseTotal;
  final double paidAmount;
  final double discountGiven;
  final double pendingAmount;
  final int transactionCount;
  final List<CustomerLedgerEntry> entries;

  VendorAccountSummary({
    required this.vendor,
    required this.purchaseTotal,
    required this.paidAmount,
    required this.discountGiven,
    required this.pendingAmount,
    required this.transactionCount,
    required this.entries,
  });
}

class CustomerLedgerEntry {
  final String docNumber;
  final double openingPending;
  final String type;
  final DateTime date;
  final String paymentMode;
  final double discount;
  final double closingPending;
  final String remarks;

  CustomerLedgerEntry({
    required this.docNumber,
    required this.openingPending,
    required this.type,
    required this.date,
    required this.paymentMode,
    required this.discount,
    required this.closingPending,
    required this.remarks,
  });
}

class _LedgerRawEvent {
  final String docNumber;
  final bool isSale;
  final DateTime date;
  final double amount;
  final double discount;
  final String mode;
  final String notes;

  _LedgerRawEvent({
    required this.docNumber,
    required this.isSale,
    required this.date,
    required this.amount,
    required this.discount,
    required this.mode,
    required this.notes,
  });
}
