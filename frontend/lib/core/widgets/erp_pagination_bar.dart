import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Reusable ERP Pagination Bar
/// Displays "Showing X to Y of Z records", rows per page selector,
/// and page buttons with previous/next controls and smart ellipsis.
class ErpPaginationBar extends StatelessWidget {
  final int currentPage; // 0-indexed
  final int pageSize;
  final int totalRecords;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final List<int> pageSizeOptions;

  const ErpPaginationBar({
    super.key,
    required this.currentPage,
    required this.pageSize,
    required this.totalRecords,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.pageSizeOptions = const [10, 25, 50, 100],
  });

  @override
  Widget build(BuildContext context) {
    final safePageSize = pageSize <= 0 ? 10 : pageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        final infoText = Text(
          'Showing ${totalRecords == 0 ? 0 : startIndex + 1} to $endIndex of $totalRecords records',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        );

        final effectivePageSize = pageSizeOptions.contains(safePageSize) ? safePageSize : pageSizeOptions.first;

        final pageSizeSelector = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rows:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: effectivePageSize,
                  isDense: true,
                  style: AppTextStyles.bodySmall,
                  items: pageSizeOptions.map((size) {
                    return DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && onPageSizeChanged != null) {
                      onPageSizeChanged!(val);
                    }
                  },
                ),
              ),
            ),
          ],
        );

        // Page selector buttons
        final List<Widget> pageButtons = [];

        // Previous button
        pageButtons.add(
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: safeCurrentPage > 0
                ? () => onPageChanged(safeCurrentPage - 1)
                : null,
          ),
        );

        // Visible page numbers calculation
        List<int> pagesToShow = [];
        if (totalPages <= 7) {
          pagesToShow = List.generate(totalPages, (i) => i);
        } else {
          pagesToShow.add(0);
          int start = max<int>(1, safeCurrentPage - 1);
          int end = min<int>(totalPages - 2, safeCurrentPage + 1);
          if (start > 1) pagesToShow.add(-1); // Ellipsis
          for (int i = start; i <= end; i++) {
            pagesToShow.add(i);
          }
          if (end < totalPages - 2) pagesToShow.add(-2); // Ellipsis
          pagesToShow.add(totalPages - 1);
        }

        for (final p in pagesToShow) {
          if (p < 0) {
            pageButtons.add(
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: Colors.grey)),
              ),
            );
          } else {
            final isCurrent = p == safeCurrentPage;
            pageButtons.add(
              InkWell(
                onTap: () => onPageChanged(p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isCurrent ? null : Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '${p + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        // Next button
        pageButtons.add(
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: safeCurrentPage < totalPages - 1
                ? () => onPageChanged(safeCurrentPage + 1)
                : null,
          ),
        );

        final controlsRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: pageButtons,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  infoText,
                  pageSizeSelector,
                ],
              ),
              const SizedBox(height: 12),
              Center(child: controlsRow),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                infoText,
                const SizedBox(width: 16),
                pageSizeSelector,
              ],
            ),
            controlsRow,
          ],
        );
      },
    );
  }
}

