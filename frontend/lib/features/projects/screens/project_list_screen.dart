import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/project_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_confirm_dialog.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadProjects();
      ref.read(databaseServiceProvider).loadSalesInvoices();
      ref.read(databaseServiceProvider).loadCustomers();
      ref.read(databaseServiceProvider).loadArchitects();
    });
  }

  void _openAddEditProjectDialog([Project? existing]) {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final budgetCtrl = TextEditingController(
      text: (existing != null && existing.budgetAmount > 0)
          ? existing.budgetAmount.toStringAsFixed(2)
          : '',
    );
    String? selectedCustomerId = existing?.customerId ?? (db.customers.isNotEmpty ? db.customers.first.id : null);
    String? selectedArchitectId = existing?.architectId ?? (db.architects.isNotEmpty ? db.architects.first.id : null);
    ProjectStatus selectedStatus = existing?.status ?? ProjectStatus.active;
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime expDate = existing?.expectedCompletionDate ?? DateTime.now().add(const Duration(days: 90));
    final formKey = GlobalKey<FormState>();

    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(
                isEdit ? 'Edit Architectural Project' : 'Create Architectural Project',
                style: AppTextStyles.h2,
              ),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                width: double.infinity,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (serverError != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(serverError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (isEdit && existing.projectCode.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Project Code: ${existing.projectCode}',
                              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: nameCtrl,
                          validator: (v) => Validators.requiredField(v, 'Project name required'),
                          decoration: const InputDecoration(labelText: 'Project Name *', hintText: 'E.g., Oberoi Sky City Tower D'),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 500;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  DropdownButtonFormField<String?>(
                                    initialValue: selectedCustomerId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Customer Account'),
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('(No Customer Linked)')),
                                      ...db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                                    ],
                                    onChanged: (val) {
                                      setDlgState(() {
                                        selectedCustomerId = val;
                                        if (val != null) {
                                          final c = db.customers.where((cust) => cust.id == val).firstOrNull;
                                          if (c?.linkedArchitectId != null && selectedArchitectId == null) {
                                            selectedArchitectId = c!.linkedArchitectId;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String?>(
                                    initialValue: selectedArchitectId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Architect Partner'),
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('(No Architect Linked)')),
                                      ...db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                                    ],
                                    onChanged: (val) {
                                      setDlgState(() {
                                        selectedArchitectId = val;
                                        if (val != null) {
                                          final a = db.architects.where((arch) => arch.id == val).firstOrNull;
                                          if (a?.linkedCustomerId != null && selectedCustomerId == null) {
                                            selectedCustomerId = a!.linkedCustomerId;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: budgetCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Budget (₹)',
                                      hintText: 'e.g. 500000.00',
                                      prefixText: '₹ ',
                                    ),
                                    validator: (val) {
                                      if (val != null && val.trim().isNotEmpty) {
                                        final num = double.tryParse(val.trim());
                                        if (num == null || num < 0) {
                                          return 'Enter valid positive amount';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<ProjectStatus>(
                                    initialValue: selectedStatus,
                                    decoration: const InputDecoration(labelText: 'Status'),
                                    items: ProjectStatus.values.map((s) {
                                      return DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setDlgState(() => selectedStatus = val);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: startDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setDlgState(() => startDate = picked);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Start Date',
                                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                                      ),
                                      child: Text(Formatters.formatDate(startDate), style: AppTextStyles.bodyMedium),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: expDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setDlgState(() => expDate = picked);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Expected Completion',
                                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                                      ),
                                      child: Text(Formatters.formatDate(expDate), style: AppTextStyles.bodyMedium),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String?>(
                                        initialValue: selectedCustomerId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(labelText: 'Customer Account'),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('(No Customer Linked)')),
                                          ...db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                                        ],
                                        onChanged: (val) {
                                          setDlgState(() {
                                            selectedCustomerId = val;
                                            if (val != null) {
                                              final c = db.customers.where((cust) => cust.id == val).firstOrNull;
                                              if (c?.linkedArchitectId != null && selectedArchitectId == null) {
                                                selectedArchitectId = c!.linkedArchitectId;
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<String?>(
                                        initialValue: selectedArchitectId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(labelText: 'Architect Partner'),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('(No Architect Linked)')),
                                          ...db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                                        ],
                                        onChanged: (val) {
                                          setDlgState(() {
                                            selectedArchitectId = val;
                                            if (val != null) {
                                              final a = db.architects.where((arch) => arch.id == val).firstOrNull;
                                              if (a?.linkedCustomerId != null && selectedCustomerId == null) {
                                                selectedCustomerId = a!.linkedCustomerId;
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: budgetCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Budget (₹)',
                                          hintText: 'e.g. 500000.00',
                                          prefixText: '₹ ',
                                        ),
                                        validator: (val) {
                                          if (val != null && val.trim().isNotEmpty) {
                                            final num = double.tryParse(val.trim());
                                            if (num == null || num < 0) {
                                              return 'Enter valid positive amount';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<ProjectStatus>(
                                        initialValue: selectedStatus,
                                        decoration: const InputDecoration(labelText: 'Status'),
                                        items: ProjectStatus.values.map((s) {
                                          return DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setDlgState(() => selectedStatus = val);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: startDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2035),
                                          );
                                          if (picked != null) {
                                            setDlgState(() => startDate = picked);
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Start Date',
                                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                                          ),
                                          child: Text(Formatters.formatDate(startDate), style: AppTextStyles.bodyMedium),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: expDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2035),
                                          );
                                          if (picked != null) {
                                            setDlgState(() => expDate = picked);
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Expected Completion',
                                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                                          ),
                                          child: Text(Formatters.formatDate(expDate), style: AppTextStyles.bodyMedium),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        if (selectedCustomerId != null && selectedArchitectId != null) ...[
                          Builder(builder: (_) {
                            final c = db.customers.where((cust) => cust.id == selectedCustomerId).firstOrNull;
                            final a = db.architects.where((arch) => arch.id == selectedArchitectId).firstOrNull;
                            final isLinked = (c?.linkedArchitectId == a?.id) || (a?.linkedCustomerId == c?.id);
                            if (!isLinked) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.link, size: 14, color: Colors.purple),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Dual Entity: Architect "${a?.name}" is linked as Customer "${c?.name}"',
                                      style: const TextStyle(fontSize: 11.5, color: Colors.purple, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes / Scope Details',
                            hintText: 'Optional project details or scope specifications',
                          ),
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
                  text: isEdit ? 'Update Project' : 'Create Project',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });

                          String? custName;
                          if (selectedCustomerId != null) {
                            custName = db.customers.where((c) => c.id == selectedCustomerId).firstOrNull?.name;
                          }
                          String? archName;
                          if (selectedArchitectId != null) {
                            archName = db.architects.where((a) => a.id == selectedArchitectId).firstOrNull?.name;
                          }

                          final budgetVal = budgetCtrl.text.trim().isNotEmpty
                              ? double.tryParse(budgetCtrl.text.trim())
                              : null;

                          try {
                            if (isEdit) {
                              final updatedProject = existing.copyWith(
                                name: nameCtrl.text.trim(),
                                customerId: selectedCustomerId,
                                customerName: custName,
                                architectId: selectedArchitectId,
                                architectName: archName,
                                budgetAmount: budgetVal ?? 0.0,
                                startDate: startDate,
                                expectedCompletionDate: expDate,
                                status: selectedStatus,
                                notes: notesCtrl.text.trim(),
                              );
                              await db.updateProjectAsync(updatedProject);
                            } else {
                              final project = Project(
                                id: IdGenerator.generateId('PRJ'),
                                name: nameCtrl.text.trim(),
                                customerId: selectedCustomerId,
                                customerName: custName,
                                architectId: selectedArchitectId,
                                architectName: archName,
                                budgetAmount: budgetVal ?? 0.0,
                                startDate: startDate,
                                expectedCompletionDate: expDate,
                                status: selectedStatus,
                                notes: notesCtrl.text.trim(),
                                createdAt: DateTime.now(),
                              );
                              await db.createProjectAsync(project);
                            }

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(isEdit ? 'Project updated successfully!' : 'Project created successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
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

  void _confirmDeleteProject(Project project) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        return ErpConfirmDeleteDialog(
          title: 'Delete Architectural Project',
          message: 'Are you sure you want to deactivate and archive this project? An audit reason is required.',
          itemName: '${project.name} (${project.projectCode.isNotEmpty ? project.projectCode : project.id})',
          requireReason: true,
          onConfirm: (reason) async {
            final db = ref.read(databaseServiceProvider);
            try {
              await db.deleteProjectAsync(project.id, reason: reason);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Project "${project.name}" archived successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Error deleting project: ${e.toString().replaceFirst("Exception: ", "")}'),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          },
        );
      },
    );
  }

  void _openUpdateProjectStatusDialog(Project project) {
    ProjectStatus newStatus = project.status;
    final notesCtrl = TextEditingController(text: project.notes ?? '');
    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.published_with_changes, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update Project Status', style: AppTextStyles.h3),
                        Text(
                          project.name,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (serverError != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(serverError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text('Select New Status:', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 10),
                    ...ProjectStatus.values.map((s) {
                      final isSelected = s == newStatus;
                      Color badgeColor;
                      switch (s) {
                        case ProjectStatus.active:
                          badgeColor = AppColors.success;
                          break;
                        case ProjectStatus.completed:
                          badgeColor = AppColors.info;
                          break;
                        case ProjectStatus.planned:
                          badgeColor = AppColors.warning;
                          break;
                        case ProjectStatus.closed:
                          badgeColor = AppColors.textMuted;
                          break;
                        case ProjectStatus.cancelled:
                          badgeColor = AppColors.danger;
                          break;
                      }

                      return InkWell(
                        onTap: () => setDlgState(() => newStatus = s),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? badgeColor.withValues(alpha: 0.1) : AppColors.surfaceMuted.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? badgeColor : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Radio<ProjectStatus>(
                                value: s,
                                groupValue: newStatus,
                                activeColor: badgeColor,
                                onChanged: (val) {
                                  if (val != null) setDlgState(() => newStatus = val);
                                },
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name.toUpperCase(),
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: isSelected ? badgeColor : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      _getStatusDescription(s),
                                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Milestone Notes (Optional)',
                        hintText: 'Add context regarding this status update...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: 'Update Status',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (newStatus == project.status && notesCtrl.text.trim() == (project.notes ?? '')) {
                            Navigator.of(ctx).pop();
                            return;
                          }
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });
                          final db = ref.read(databaseServiceProvider);
                          try {
                            final updated = project.copyWith(
                              status: newStatus,
                              notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : project.notes,
                              actualCompletionDate: newStatus == ProjectStatus.completed
                                  ? (project.actualCompletionDate ?? DateTime.now())
                                  : project.actualCompletionDate,
                            );
                            await db.updateProjectAsync(updated);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Project status updated to ${newStatus.name.toUpperCase()} successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
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

  String _getStatusDescription(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planned:
        return 'Project created, scope drafted, waiting to start';
      case ProjectStatus.active:
        return 'In progress, manufacturing & procurement underway';
      case ProjectStatus.completed:
        return 'All deliverables manufactured, installed & completed';
      case ProjectStatus.closed:
        return 'Project delivered, invoiced & accounts finalized';
      case ProjectStatus.cancelled:
        return 'Project halted or cancelled by client';
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final projects = db.projects.where((p) {
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          (p.projectCode.isNotEmpty && p.projectCode.toLowerCase().contains(query)) ||
          (p.customerName != null && p.customerName!.toLowerCase().contains(query)) ||
          (p.architectName != null && p.architectName!.toLowerCase().contains(query)) ||
          (p.notes != null && p.notes!.toLowerCase().contains(query)) ||
          p.status.toString().toLowerCase().contains(query);
    }).toList();

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
                    constraints: BoxConstraints(maxWidth: isSmall ? double.infinity : constraints.maxWidth - 180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Project Master', style: AppTextStyles.h1),
                        const SizedBox(height: 4),
                        Text('Manage architectural projects, client assignments, lead architects, and lifecycle status', style: AppTextStyles.subtitle),
                      ],
                    ),
                  ),
                  ErpButton(
                    text: 'New Project',
                    icon: Icons.add,
                    onPressed: () => _openAddEditProjectDialog(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search projects by code, name, customer, architect, status, or notes...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Code'),
              ErpColumn(title: 'Project Name'),
              ErpColumn(title: 'Customer / Client'),
              ErpColumn(title: 'Lead Architect'),
              ErpColumn(title: 'Start Date'),
              ErpColumn(title: 'Budget', isNumeric: true),
              ErpColumn(title: 'Total Sales Invoiced', isNumeric: true),
              ErpColumn(title: 'Generated Commission', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: projects.map((p) {
              ErpStatusBadge badge;
              switch (p.status) {
                case ProjectStatus.active:
                  badge = ErpStatusBadge.success('ACTIVE');
                  break;
                case ProjectStatus.completed:
                  badge = ErpStatusBadge.info('COMPLETED');
                  break;
                case ProjectStatus.planned:
                  badge = ErpStatusBadge.warning('PLANNED');
                  break;
                case ProjectStatus.closed:
                  badge = ErpStatusBadge.neutral('CLOSED');
                  break;
                case ProjectStatus.cancelled:
                  badge = ErpStatusBadge.danger('CANCELLED');
                  break;
              }

              final prjInvoices = db.sales.where((s) =>
                  s.projectId == p.id &&
                  s.documentType == SalesDocumentType.invoice &&
                  s.status != SaleStatus.cancelled).toList();
              final invoicedSum = prjInvoices.fold<double>(0.0, (acc, s) => acc + s.totalAmount);
              final commissionSum = prjInvoices.fold<double>(0.0, (acc, s) => acc + s.architectCommissionAmount);
              final displaySalesAmount = invoicedSum > 0 ? invoicedSum : p.totalSalesAmount;
              final displayCommissionAmount = commissionSum > 0 ? commissionSum : p.totalCommissionAmount;

              return [
                Text(
                  p.projectCode.isNotEmpty ? p.projectCode : '—',
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                InkWell(
                  onTap: () {
                    ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'project', ErpNavSection.projectList);
                  },
                  child: Text(
                    p.name,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(p.customerName ?? 'Direct Client', style: AppTextStyles.bodyMedium),
                Text(p.architectName ?? 'No Architect Linked', style: AppTextStyles.bodySmall.copyWith(color: AppColors.purple)),
                Text(Formatters.formatDate(p.startDate), style: AppTextStyles.bodySmall),
                Text(
                  p.budgetAmount > 0 ? Formatters.formatCurrency(p.budgetAmount) : '—',
                  style: AppTextStyles.bodyMedium,
                ),
                Text(Formatters.formatCurrency(displaySalesAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(Formatters.formatCurrency(displayCommissionAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                Tooltip(
                  message: 'Click to update status',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _openUpdateProjectStatusDialog(p),
                    child: badge,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.published_with_changes, color: AppColors.primary, size: 18),
                      tooltip: 'Update Project Status',
                      onPressed: () => _openUpdateProjectStatusDialog(p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
                      tooltip: 'View 10-Section Project Breakdown',
                      onPressed: () {
                        ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'project', ErpNavSection.projectList);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Project',
                      onPressed: () => _openAddEditProjectDialog(p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                      tooltip: 'Delete Project',
                      onPressed: () => _confirmDeleteProject(p),
                    ),
                  ],
                ),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
