import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/project_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
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

  void _openAddEditProjectDialog([Project? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String? selectedCustomerId = existing?.customerId ?? (db.customers.isNotEmpty ? db.customers.first.id : null);
    String? selectedArchitectId = existing?.architectId ?? (db.architects.isNotEmpty ? db.architects.first.id : null);
    ProjectStatus selectedStatus = existing?.status ?? ProjectStatus.active;
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime expDate = existing?.expectedCompletionDate ?? DateTime.now().add(const Duration(days: 90));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Architectural Project' : 'Create Architectural Project', style: AppTextStyles.h2),
              content: SizedBox(
                width: 540,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          validator: (v) => Validators.requiredField(v, 'Project name required'),
                          decoration: const InputDecoration(labelText: 'Project Name *', hintText: 'E.g., Oberoi Sky City Tower D'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: selectedCustomerId,
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
                                      final c = db.customers.firstWhere((cust) => cust.id == val);
                                      if (c.linkedArchitectId != null && selectedArchitectId == null) {
                                        selectedArchitectId = c.linkedArchitectId;
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: selectedArchitectId,
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
                                      final a = db.architects.firstWhere((arch) => arch.id == val);
                                      if (a.linkedCustomerId != null && selectedCustomerId == null) {
                                        selectedCustomerId = a.linkedCustomerId;
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
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
                                  Text(
                                    'Dual Entity: Architect "${a?.name}" is linked as Customer "${c?.name}"',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.purple, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<ProjectStatus>(
                                value: selectedStatus,
                                decoration: const InputDecoration(labelText: 'Status'),
                                items: ProjectStatus.values.map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s.toString().split('.').last.toUpperCase()));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDlgState(() => selectedStatus = val);
                                },
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
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: isEdit ? 'Update Project' : 'Create Project',
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    String? custName;
                    if (selectedCustomerId != null) {
                      custName = db.customers.where((c) => c.id == selectedCustomerId).firstOrNull?.name;
                    }
                    String? archName;
                    if (selectedArchitectId != null) {
                      archName = db.architects.where((a) => a.id == selectedArchitectId).firstOrNull?.name;
                    }

                    if (isEdit) {
                      final updatedProject = existing.copyWith(
                        name: nameCtrl.text.trim(),
                        customerId: selectedCustomerId,
                        customerName: custName,
                        architectId: selectedArchitectId,
                        architectName: archName,
                        status: selectedStatus,
                        notes: notesCtrl.text.trim(),
                      );
                      db.updateProject(updatedProject);
                    } else {
                      final project = Project(
                        id: IdGenerator.generateId('PRJ'),
                        name: nameCtrl.text.trim(),
                        customerId: selectedCustomerId,
                        customerName: custName,
                        architectId: selectedArchitectId,
                        architectName: archName,
                        startDate: startDate,
                        expectedCompletionDate: expDate,
                        status: selectedStatus,
                        notes: notesCtrl.text.trim(),
                        createdAt: DateTime.now(),
                      );
                      db.addProject(project);
                    }
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Project updated successfully!' : 'Project created successfully!'),
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

  void _confirmDeleteProject(Project project) {
    final db = ref.read(databaseServiceProvider);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete Project', style: AppTextStyles.h2.copyWith(color: AppColors.danger)),
          content: Text(
            'Are you sure you want to delete project "${project.name}"? This action will remove it from the master catalog.',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            ErpButton(
              text: 'Cancel',
              isOutlined: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ErpButton(
              text: 'Delete Project',
              isDanger: true,
              onPressed: () {
                db.deleteProject(project.id);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Project "${project.name}" deleted successfully!'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final projects = db.projects.where((p) {
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Project Master', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Manage architectural projects, client assignments, lead architects, and lifecycle status', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'New Project',
                icon: Icons.add,
                onPressed: () => _openAddEditProjectDialog(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search projects by name, customer, architect, status, or notes...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Project Name'),
              ErpColumn(title: 'Customer / Client'),
              ErpColumn(title: 'Lead Architect'),
              ErpColumn(title: 'Start Date'),
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
              }

              return [
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
                Text(Formatters.formatCurrency(p.totalSalesAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(Formatters.formatCurrency(p.totalCommissionAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                badge,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
