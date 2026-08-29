import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _openCreateProjectDialog() {
    final db = ref.read(databaseServiceProvider);
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedCustomerId = db.customers.isNotEmpty ? db.customers.first.id : null;
    String? selectedArchitectId = db.architects.isNotEmpty ? db.architects.first.id : null;
    ProjectStatus selectedStatus = ProjectStatus.active;
    DateTime startDate = DateTime.now();
    DateTime expDate = DateTime.now().add(const Duration(days: 90));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text('Create Architectural Project', style: AppTextStyles.h2),
              content: SizedBox(
                width: 520,
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
                                decoration: const InputDecoration(labelText: 'Customer'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('None')),
                                  ...db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                                ],
                                onChanged: (val) => setDlgState(() => selectedCustomerId = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: selectedArchitectId,
                                decoration: const InputDecoration(labelText: 'Architect'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('None')),
                                  ...db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                                ],
                                onChanged: (val) => setDlgState(() => selectedArchitectId = val),
                              ),
                            ),
                          ],
                        ),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Project Scope / Notes', hintText: 'Lighting specifications and scope...'),
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
                  text: 'Create Project',
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    String? custName;
                    if (selectedCustomerId != null) {
                      custName = db.customers.firstWhere((c) => c.id == selectedCustomerId).name;
                    }
                    String? archName;
                    if (selectedArchitectId != null) {
                      archName = db.architects.firstWhere((a) => a.id == selectedArchitectId).name;
                    }

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
                    Navigator.of(ctx).pop();
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
    final projects = db.projects.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.customerName != null && p.customerName!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
          (p.architectName != null && p.architectName!.toLowerCase().contains(_searchQuery.toLowerCase()));
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
                  Text('Architectural & Site Projects', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Track luxury residential and commercial fit-outs, linked sales, and architect commissions', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'New Project',
                icon: Icons.add,
                onPressed: _openCreateProjectDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search projects by name, customer or architect...',
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
                Text(p.name, style: AppTextStyles.bodyBold),
                Text(p.customerName ?? 'Direct Client', style: AppTextStyles.bodyMedium),
                Text(p.architectName ?? 'No Architect Linked', style: AppTextStyles.bodySmall.copyWith(color: AppColors.purple)),
                Text(Formatters.formatDate(p.startDate), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.totalSalesAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(Formatters.formatCurrency(p.totalCommissionAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                badge,
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
