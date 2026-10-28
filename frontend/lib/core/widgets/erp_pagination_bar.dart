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
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        );

        final effectivePageSize = pageSizeOptions.contains(safePageSize) ? safePageSize : pageSizeOptions.first;

        final pageSizeSelector = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rows:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.white,
                  highlightColor: AppColors.primarySoft,
                  hoverColor: AppColors.primarySoft.withValues(alpha: 0.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: effectivePageSize,
                    isDense: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 4,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.primary),
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                    items: pageSizeOptions.map((size) {
                      final isSelected = size == effectivePageSize;
                      return DropdownMenuItem<int>(
                        value: size,
                        child: Text(
                          '$size',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppColors.primaryDark : const Color(0xFF334155),
                          ),
                        ),
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
            ),
          ],
        );

        // Page selector buttons
        final List<Widget> pageButtons = [];

        Widget buildSquareButton({
          required Widget child,
          VoidCallback? onTap,
          bool isActive = false,
        }) {
          final isEnabled = onTap != null;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : (isEnabled ? Colors.white : const Color(0xFFF9FAFB)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive ? AppColors.primary : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: child,
              ),
            ),
          );
        }

        // First page button «
        pageButtons.add(
          buildSquareButton(
            child: Icon(
              Icons.first_page,
              size: 16,
              color: safeCurrentPage > 0 ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            onTap: safeCurrentPage > 0 ? () => onPageChanged(0) : null,
          ),
        );

        // Previous button ‹
        pageButtons.add(
          buildSquareButton(
            child: Icon(
              Icons.chevron_left,
              size: 16,
              color: safeCurrentPage > 0 ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            onTap: safeCurrentPage > 0 ? () => onPageChanged(safeCurrentPage - 1) : null,
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
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: const Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              ),
            );
          } else {
            final isCurrent = p == safeCurrentPage;
            pageButtons.add(
              buildSquareButton(
                isActive: isCurrent,
                child: Text(
                  '${p + 1}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                onTap: () => onPageChanged(p),
              ),
            );
          }
        }

        // Next button ›
        pageButtons.add(
          buildSquareButton(
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: safeCurrentPage < totalPages - 1 ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            onTap: safeCurrentPage < totalPages - 1 ? () => onPageChanged(safeCurrentPage + 1) : null,
          ),
        );

        // Last page button »
        pageButtons.add(
          buildSquareButton(
            child: Icon(
              Icons.last_page,
              size: 16,
              color: safeCurrentPage < totalPages - 1 ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            onTap: safeCurrentPage < totalPages - 1 ? () => onPageChanged(totalPages - 1) : null,
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

