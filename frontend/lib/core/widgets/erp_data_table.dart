import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';

class ErpColumn {
  final String title;
  final double? width;
  final bool isNumeric;

  const ErpColumn({
    required this.title,
    this.width,
    this.isNumeric = false,
  });
}

class ErpDataTable extends StatefulWidget {
  final List<ErpColumn> columns;
  final List<List<Widget>> rows;
  final Widget? emptyState;
  final double? columnSpacing;
  final double? horizontalMargin;
  final bool enableVerticalScroll;
  final bool fixedHeader;

  const ErpDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyState,
    this.columnSpacing,
    this.horizontalMargin,
    this.enableVerticalScroll = false,
    this.fixedHeader = false,
  });

  @override
  State<ErpDataTable> createState() => _ErpDataTableState();
}

class _ErpDataTableState extends State<ErpDataTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  double _getColWidth(int i, double extraWidth) {
    final base = widget.columns[i].width ?? 120.0;
    if (i == widget.columns.length - 1 && extraWidth > 0) {
      return base + extraWidth;
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return widget.emptyState ??
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            child: Text(
              'No records found',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
            ),
          );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorderRadius,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = widget.columnSpacing ?? 16.0;
          final hMargin = widget.horizontalMargin ?? 20.0;

          if (widget.fixedHeader) {
            double totalColsWidth = 0.0;
            for (final col in widget.columns) {
              totalColsWidth += col.width ?? 120.0;
            }
            final totalFixedContentWidth = totalColsWidth + (widget.columns.length - 1) * spacing + 2 * hMargin;
            final hasBoundedWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0;
            final extraWidth = hasBoundedWidth && constraints.maxWidth > totalFixedContentWidth
                ? (constraints.maxWidth - totalFixedContentWidth)
                : 0.0;
            final effectiveTableWidth = totalFixedContentWidth + extraWidth;
            final hasBoundedHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0;

            final tableContent = SizedBox(
              width: effectiveTableWidth,
              height: hasBoundedHeight ? constraints.maxHeight : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  // Pinned Header (Stays still when scrolling vertically)
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: hMargin),
                    child: Row(
                      children: [
                        for (int i = 0; i < widget.columns.length; i++) ...[
                          SizedBox(
                            width: _getColWidth(i, extraWidth),
                            child: Align(
                              alignment: widget.columns[i].isNumeric ? Alignment.centerRight : Alignment.centerLeft,
                              child: Text(
                                widget.columns[i].title.toUpperCase(),
                                style: AppTextStyles.tableHeader.copyWith(fontSize: 11),
                              ),
                            ),
                          ),
                          if (i < widget.columns.length - 1) SizedBox(width: spacing),
                        ],
                      ],
                    ),
                  ),
                  // Scrollable Info Rows
                  if (hasBoundedHeight)
                    Expanded(
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          scrollDirection: Axis.vertical,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int r = 0; r < widget.rows.length; r++)
                                Container(
                                  constraints: const BoxConstraints(minHeight: 46),
                                  decoration: BoxDecoration(
                                    color: r.isOdd ? AppColors.surfaceMuted.withValues(alpha: 0.25) : AppColors.surface,
                                    border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1)),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: hMargin, vertical: 8),
                                  child: Row(
                                    children: [
                                      for (int i = 0; i < widget.columns.length; i++) ...[
                                        SizedBox(
                                          width: _getColWidth(i, extraWidth),
                                          child: Align(
                                            alignment: widget.columns[i].isNumeric ? Alignment.centerRight : Alignment.centerLeft,
                                            child: i < widget.rows[r].length ? widget.rows[r][i] : const SizedBox.shrink(),
                                          ),
                                        ),
                                        if (i < widget.columns.length - 1) SizedBox(width: spacing),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int r = 0; r < widget.rows.length; r++)
                          Container(
                            constraints: const BoxConstraints(minHeight: 46),
                            decoration: BoxDecoration(
                              color: r.isOdd ? AppColors.surfaceMuted.withValues(alpha: 0.25) : AppColors.surface,
                              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1)),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: hMargin, vertical: 8),
                            child: Row(
                              children: [
                                for (int i = 0; i < widget.columns.length; i++) ...[
                                  SizedBox(
                                    width: _getColWidth(i, extraWidth),
                                    child: Align(
                                      alignment: widget.columns[i].isNumeric ? Alignment.centerRight : Alignment.centerLeft,
                                      child: i < widget.rows[r].length ? widget.rows[r][i] : const SizedBox.shrink(),
                                    ),
                                  ),
                                  if (i < widget.columns.length - 1) SizedBox(width: spacing),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );

            return Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: tableContent,
              ),
            );
          }

          final table = ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : MediaQuery.of(context).size.width,
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceMuted),
              headingTextStyle: AppTextStyles.tableHeader,
              dataTextStyle: AppTextStyles.tableCell,
              dividerThickness: 1,
              horizontalMargin: widget.horizontalMargin ?? 20,
              columnSpacing: widget.columnSpacing ?? 28,
              columns: widget.columns.map((col) {
                return DataColumn(
                  numeric: col.isNumeric,
                  label: Text(
                    col.title.toUpperCase(),
                    style: AppTextStyles.tableHeader.copyWith(fontSize: 11),
                  ),
                );
              }).toList(),
              rows: widget.rows.map((cells) {
                return DataRow(
                  cells: cells.map((cell) => DataCell(cell)).toList(),
                );
              }).toList(),
            ),
          );

          if (widget.enableVerticalScroll) {
            return Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalController,
                scrollDirection: Axis.vertical,
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  notificationPredicate: (notification) => notification.depth == 0,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: table,
                  ),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table,
          );
        },
      ),
    );
  }
}
