import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/vendor_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_confirm_dialog.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/widgets/whatsapp_quick_chat_dialog.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  String _searchQuery = '';
  String _duesFilter = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadVendors();
    });
  }

  void _openAddEditVendorDialog([Vendor? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contactCtrl = TextEditingController(text: existing?.contactPerson ?? '');
    final mobileCtrl = TextEditingController(text: existing?.mobile ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final gstCtrl = TextEditingController(text: existing?.gstNumber ?? '');
    final panCtrl = TextEditingController(text: existing?.panNumber ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final stateCtrl = TextEditingController(text: existing?.state ?? '');
    final pincodeCtrl = TextEditingController(text: existing?.pincode ?? '');
    final termsCtrl = TextEditingController(text: existing?.paymentTerms ?? 'Net 30 Days');
    final creditCtrl = TextEditingController(text: existing?.creditLimit.toString() ?? '500000');
    final transportCtrl = TextEditingController(text: existing?.defaultTransportationCharges.toString() ?? '0');
    final formKey = GlobalKey<FormState>();

    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDlgState) {
            return AlertDialog(
              title: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(isEdit ? 'Edit Vendor' : 'Add Vendor Master', style: AppTextStyles.h2),
                  ErpButton(
                    text: 'Scan & Upload (OCR)',
                    icon: Icons.document_scanner_outlined,
                    isOutlined: true,
                    onPressed: isSubmitting ? null : () {
                      showDialog(
                        context: context,
                        builder: (ocrCtx) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.88,
                            child: DocumentOcrUploader(
                              docType: OcrDocType.vendorDoc,
                              onCancel: () => Navigator.of(ocrCtx).pop(),
                              onConfirm: (data) {
                                nameCtrl.text = data['Vendor Name'] ?? data['Company Name'] ?? nameCtrl.text;
                                contactCtrl.text = data['Contact Person'] ?? contactCtrl.text;
                                mobileCtrl.text = data['Mobile'] ?? mobileCtrl.text;
                                emailCtrl.text = data['Email'] ?? emailCtrl.text;
                                addressCtrl.text = data['Address'] ?? addressCtrl.text;
                                if (data.containsKey('State')) stateCtrl.text = data['State']!;
                                if (data.containsKey('Pincode')) pincodeCtrl.text = data['Pincode']!;
                                if (data.containsKey('Payment Terms')) {
                                  termsCtrl.text = data['Payment Terms']!;
                                }
                                Navigator.of(ocrCtx).pop();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                width: double.infinity,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (serverError != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    serverError!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: nameCtrl,
                          validator: (v) => Validators.requiredField(v, 'Vendor company name required'),
                          decoration: const InputDecoration(labelText: 'Vendor Name *', hintText: 'E.g., Apex Aluminum Extrusions Ltd'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: contactCtrl,
                                validator: (v) => Validators.requiredField(v, 'Contact person required'),
                                decoration: const InputDecoration(labelText: 'Contact Person *'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: mobileCtrl,
                                validator: Validators.requiredMobile,
                                decoration: const InputDecoration(labelText: 'Mobile Number *', hintText: '9876543210'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                validator: Validators.requiredEmail,
                                decoration: const InputDecoration(labelText: 'Email Address *', hintText: 'vendor@domain.com'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: gstCtrl,
                                validator: (v) => Validators.gst(v, false),
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(labelText: 'GST Number (Optional)', hintText: '24AAATE1234F1Z5'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: panCtrl,
                                validator: (v) => Validators.pan(v, false),
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(labelText: 'PAN Number (Optional)', hintText: 'AAATE1234F'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: termsCtrl,
                                decoration: const InputDecoration(labelText: 'Payment Terms'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: creditCtrl,
                                keyboardType: TextInputType.number,
                                validator: Validators.nonNegativeNumber,
                                decoration: const InputDecoration(labelText: 'Credit Limit (₹) *'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: transportCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Default Transportation / Freight (₹)',
                            prefixIcon: Icon(Icons.local_shipping_outlined, size: 20),
                            hintText: 'E.g., 500',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressCtrl,
                          validator: (v) => Validators.requiredField(v, 'Registered factory address required'),
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Factory / Registered Address *'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
  controller: stateCtrl,
  validator: (v) {
    if (v == null || v.trim().isEmpty) {
      return 'State is required';
    }
    return null;
  },
  decoration: const InputDecoration(
    labelText: 'State *',
    hintText: 'E.g., Gujarat',
  ),
),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
  controller: pincodeCtrl,
  keyboardType: TextInputType.number,
  validator: (v) {
    if (v == null || v.trim().isEmpty) {
      return 'PIN Code is required';
    }
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(v.trim())) {
      return 'Enter a valid 6-digit PIN Code';
    }
    return null;
  },
  decoration: const InputDecoration(
    labelText: 'PIN Code *',
    hintText: 'E.g., 382481',
  ),
),
                            ),
                          ],
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
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: isEdit ? 'Update Vendor' : 'Save Vendor',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });

                          final creditVal = double.tryParse(creditCtrl.text.trim()) ?? 0.0;
                          final transportVal = double.tryParse(transportCtrl.text.trim()) ?? 0.0;
                          try {
                            if (isEdit) {
                              await db.updateVendorAsync(existing.copyWith(
                                name: nameCtrl.text.trim(),
                                contactPerson: contactCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                gstNumber: gstCtrl.text.trim().toUpperCase(),
                                panNumber: panCtrl.text.trim().toUpperCase(),
                                address: addressCtrl.text.trim(),
                                state: stateCtrl.text.trim(),
                                pincode: pincodeCtrl.text.trim(),
                                paymentTerms: termsCtrl.text.trim(),
                                creditLimit: creditVal,
                                defaultTransportationCharges: transportVal,
                              ));
                            } else {
                              final newVendor = Vendor(
                                id: IdGenerator.generateId('VEN'),
                                name: nameCtrl.text.trim(),
                                contactPerson: contactCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                gstNumber: gstCtrl.text.trim().toUpperCase(),
                                panNumber: panCtrl.text.trim().toUpperCase(),
                                address: addressCtrl.text.trim(),
                                state: stateCtrl.text.trim(),
                                pincode: pincodeCtrl.text.trim(),
                                paymentTerms: termsCtrl.text.trim(),
                                creditLimit: creditVal,
                                defaultTransportationCharges: transportVal,
                                outstandingBalance: 0.0,
                                createdAt: DateTime.now(),
                              );
                              await db.addVendorAsync(newVendor);
                            }

                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Vendor "${nameCtrl.text.trim()}" ${isEdit ? "updated" : "saved"} successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } on ApiException catch (e) {
                            setDlgState(() {
                              serverError = e.message;
                              isSubmitting = false;
                            });
                          } catch (e) {
                            setDlgState(() {
                              serverError = e.toString().replaceFirst('Exception: ', '');
                              isSubmitting = false;
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteVendor(Vendor vendor) {
    showDialog(
      context: context,
      builder: (ctx) {
        return ErpConfirmDeleteDialog(
          title: 'Delete Vendor Record',
          message: 'Are you sure you want to deactivate and archive this vendor? A mandatory audit reason is required.',
          itemName: '${vendor.name} (${vendor.id})',
          requireReason: true,
          onConfirm: (reason) async {
            final db = ref.read(databaseServiceProvider);
            try {
              await db.deleteVendorAsync(vendorId: vendor.id, reason: reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Vendor "${vendor.name}" archived with audit reason: $reason'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Delete failed: ${e.toString().replaceFirst("Exception: ", "")}'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final vendors = db.vendors.where((v) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = v.name.toLowerCase().contains(query) ||
            v.contactPerson.toLowerCase().contains(query) ||
            v.mobile.toLowerCase().contains(query) ||
            v.email.toLowerCase().contains(query) ||
            v.gstNumber.toLowerCase().contains(query) ||
            v.panNumber.toLowerCase().contains(query) ||
            v.address.toLowerCase().contains(query) ||
            v.state.toLowerCase().contains(query) ||
            v.pincode.toLowerCase().contains(query) ||
            v.paymentTerms.toLowerCase().contains(query);
        if (!matches) return false;
      }
      if (_duesFilter == 'HAS_DUES' && v.outstandingBalance <= 0) return false;
      if (_duesFilter == 'ZERO_DUES' && v.outstandingBalance > 0) return false;
      if (_startDate != null && v.createdAt.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) return false;
      if (_endDate != null && v.createdAt.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) return false;
      return true;
    }).toList();

    final totalRecords = vendors.length;
    final safePageSize = _pageSize <= 0 ? 25 : _pageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedVendors = totalRecords == 0 ? <Vendor>[] : vendors.sublist(startIndex, endIndex);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final subtitleWidget = Text(
                'Raw material suppliers, payment terms, credit limits, and outstanding balances',
                style: AppTextStyles.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
              final actionButton = ErpButton(
                text: 'Add Vendor',
                icon: Icons.add,
                onPressed: () => _openAddEditVendorDialog(),
              );

              if (constraints.maxWidth < 550) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    subtitleWidget,
                    const SizedBox(height: 12),
                    actionButton,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: subtitleWidget),
                  const SizedBox(width: 12),
                  actionButton,
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
                width: 280,
                child: ErpSearchInput(
                  hintText: 'Search vendors by name, contact, GST...',
                  initialValue: _searchQuery,
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                  }),
                ),
              ),
              ErpFilterDropdown<String>(
                value: _duesFilter,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Vendors')),
                  DropdownMenuItem(value: 'HAS_DUES', child: Text('Has Dues / Payable')),
                  DropdownMenuItem(value: 'ZERO_DUES', child: Text('Zero Balance / Settled')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() {
                    _duesFilter = val;
                    _currentPage = 0;
                  });
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
              ErpColumn(title: 'Vendor Name'),
              ErpColumn(title: 'Contact Person'),
              ErpColumn(title: 'Mobile / Email'),
              ErpColumn(title: 'State'),
              ErpColumn(title: 'GST Number'),
              ErpColumn(title: 'Outstanding Balance', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: pagedVendors.map((v) {
              return [
                InkWell(
                  onTap: () {
                    ref.read(activeRecordDetailsStackProvider.notifier).push(v.id, 'vendor', ErpNavSection.vendors);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(v.name, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                      if (v.address.isNotEmpty || v.state.isNotEmpty || v.pincode.isNotEmpty)
                        Text(
                          [
                            if (v.address.isNotEmpty) v.address,
                            if (v.state.isNotEmpty) v.state,
                            if (v.pincode.isNotEmpty) v.pincode,
                          ].join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Text(v.contactPerson, style: AppTextStyles.bodyMedium),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.mobile, style: AppTextStyles.bodySmall),
                    Text(v.email, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                  ],
                ),
                Text(v.state.isNotEmpty ? v.state : '-', style: AppTextStyles.bodyMedium),
                Text(v.gstNumber.trim().isNotEmpty ? v.gstNumber : '-', style: AppTextStyles.bodySmall),
                Text(
                  Formatters.formatCurrency(v.outstandingBalance),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: v.outstandingBalance > 0 ? AppColors.dangerText : AppColors.textMuted,
                  ),
                ),
                v.isDeleted
                    ? Tooltip(
                        message: v.deleteReason != null ? 'Deleted: ${v.deleteReason}' : 'Deleted vendor',
                        child: ErpStatusBadge.danger('DELETED'),
                      )
                    : ErpStatusBadge.success('ACTIVE'),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (action) {
                    switch (action) {
                      case 'view':
                        ref.read(activeRecordDetailsStackProvider.notifier).push(v.id, 'vendor', ErpNavSection.vendors);
                        break;
                      case 'whatsapp':
                        WhatsAppQuickChatDialog.showCustomerQuickChat(
                          context,
                          customerName: v.name,
                          customerPhone: v.mobile,
                        );
                        break;
                      case 'edit':
                        if (!v.isDeleted) _openAddEditVendorDialog(v);
                        break;
                      case 'delete':
                        if (!v.isDeleted) _confirmDeleteVendor(v);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'whatsapp',
                      child: Row(
                        children: [
                          Icon(Icons.chat, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('WhatsApp Chat'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      enabled: !v.isDeleted,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: v.isDeleted ? Colors.grey : AppColors.textPrimary),
                          const SizedBox(width: 8),
                          Text('Edit Vendor', style: TextStyle(color: v.isDeleted ? Colors.grey : null)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: !v.isDeleted,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: v.isDeleted ? Colors.grey : AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Text('Delete with Reason', style: TextStyle(color: v.isDeleted ? Colors.grey : AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
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
