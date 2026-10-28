import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/providers/app_state_providers.dart';
import '../models/bulk_upload_history_model.dart';
import '../utils/formatters.dart';
import 'erp_button.dart';
import 'erp_filter_controls.dart';
import 'erp_status_badge.dart';

class BulkUploadHistoryDialog extends ConsumerStatefulWidget {
  final String? initialMasterFilter; // Optional filter: 'Raw Materials' or 'Finished Products'

  const BulkUploadHistoryDialog({
    super.key,
    this.initialMasterFilter,
  });

  static Future<void> show(BuildContext context, {String? masterFilter}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BulkUploadHistoryDialog(initialMasterFilter: masterFilter),
    );
  }

  @override
  ConsumerState<BulkUploadHistoryDialog> createState() => _BulkUploadHistoryDialogState();
}

class _BulkUploadHistoryDialogState extends ConsumerState<BulkUploadHistoryDialog> {
  String _searchQuery = '';
  String _selectedMaster = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialMasterFilter != null) {
      _selectedMaster = widget.initialMasterFilter!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final history = db.bulkUploadHistory;

    // Filter history records
    final filtered = history.where((item) {
      if (_selectedMaster != 'ALL' && !item.masterType.toLowerCase().contains(_selectedMaster.toLowerCase())) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchFile = item.fileName.toLowerCase().contains(query);
        final matchUser = item.uploadedBy.toLowerCase().contains(query);
        final matchMaster = item.masterType.toLowerCase().contains(query);
        if (!matchFile && !matchUser && !matchMaster) return false;
      }
      if (_startDate != null) {
        final dayStart = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, 0, 0, 0);
        if (item.uploadedAt.isBefore(dayStart)) return false;
      }
      if (_endDate != null) {
        final dayEnd = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (item.uploadedAt.isAfter(dayEnd)) return false;
      }
      return true;
    }).toList();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bulk Upload Audit & History Logs', style: AppTextStyles.h2),
                  const SizedBox(height: 2),
                  Text(
                    'Audit records of batch uploads, user tracking, row validation stats & audit notes',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: Container(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.76,
        ),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Toolbar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Search Input
                  SizedBox(
                    width: 250,
                    height: 38,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search file or user...',
                        hintStyle: AppTextStyles.caption,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),

                  // Master Type Selector
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Master: ', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: _selectedMaster,
                        isDense: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Masters')),
                          DropdownMenuItem(value: 'Raw Materials', child: Text('Raw Materials')),
                          DropdownMenuItem(value: 'Finished Products', child: Text('Finished Products')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMaster = val);
                        },
                      ),
                    ],
                  ),

                  // Date Filter Box
                  ErpDateFilterBox(
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateRangeSelected: (start, end) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // History List / Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_open_outlined, size: 48, color: Color(0xFF9CA3AF)),
                            const SizedBox(height: 10),
                            Text(
                              'No upload history records found matching your filters.',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, idx) {
                          final item = filtered[idx];
                          return _buildHistoryCard(item);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        ErpButton(
          text: 'Close',
          isOutlined: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(BulkUploadHistoryRecord item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // File Name and Master Badge
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.fileName,
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.masterType,
                        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              ErpStatusBadge(
                label: item.statusLabel,
                backgroundColor: item.statusColor.withValues(alpha: 0.12),
                textColor: item.statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // User and Timestamp Details
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                'Uploaded by: ${item.uploadedBy}',
                style: AppTextStyles.caption.copyWith(color: const Color(0xFF4B5563), fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                Formatters.formatDateTime(item.uploadedAt),
                style: AppTextStyles.caption.copyWith(color: const Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Audit Breakdown Badges: Total, Imported, Errors, Duplicates
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _metricPill('Total Rows', '${item.totalRows}', const Color(0xFF334155), const Color(0xFFF8FAFC)),
              _metricPill('Imported', '${item.importedRows}', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
              if (item.errorRows > 0)
                _metricPill('Errors', '${item.errorRows}', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
              if (item.duplicateRows > 0)
                _metricPill('Duplicates (Skipped)', '${item.duplicateRows}', const Color(0xFFEA580C), const Color(0xFFFFEDD5)),
            ],
          ),

          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.notes!,
              style: AppTextStyles.caption.copyWith(color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricPill(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
