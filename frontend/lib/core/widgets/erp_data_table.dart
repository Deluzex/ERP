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

class ErpDataTable extends StatelessWidget {
  final List<ErpColumn> columns;
  final List<List<Widget>> rows;
  final Widget? emptyState;

  const ErpDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return emptyState ??
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 300,
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.surfaceMuted),
            headingTextStyle: AppTextStyles.tableHeader,
            dataTextStyle: AppTextStyles.tableCell,
            dividerThickness: 1,
            horizontalMargin: 20,
            columnSpacing: 28,
            columns: columns.map((col) {
              return DataColumn(
                numeric: col.isNumeric,
                label: Text(
                  col.title.toUpperCase(),
                  style: AppTextStyles.tableHeader.copyWith(fontSize: 11),
                ),
              );
            }).toList(),
            rows: rows.map((cells) {
              return DataRow(
                cells: cells.map((cell) => DataCell(cell)).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
