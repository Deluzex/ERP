import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Standard search field for ERP modules (Masters & Reports)
class ErpSearchInput extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final String? initialValue;
  final String? value;
  final TextEditingController? controller;

  const ErpSearchInput({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialValue,
    this.value,
    this.controller,
  });

  @override
  State<ErpSearchInput> createState() => _ErpSearchInputState();
}

class _ErpSearchInputState extends State<ErpSearchInput> {
  late final TextEditingController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.value ?? widget.initialValue ?? '');
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(covariant ErpSearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && widget.initialValue != null && widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          return TextField(
            controller: _controller,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged('');
                      },
                    )
                  : const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
            onChanged: widget.onChanged,
          );
        },
      ),
    );
  }
}

/// Standard filter dropdown for ERP modules
class ErpFilterDropdown<T> extends StatelessWidget {
  final String? label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double? width;
  final bool isExpanded;

  const ErpFilterDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((i) => i.value == value) ? value : (items.isNotEmpty ? items.first.value : null);
    final valStr = safeValue?.toString().toUpperCase() ?? '';
    final isFilterActive = valStr.isNotEmpty && valStr != 'ALL' && valStr != 'NONE';

    final styledItems = items.map<DropdownMenuItem<T>>((item) {
      final isSelected = item.value == safeValue;
      Widget content = item.child;

      if (content is Text) {
        final textData = content.data ?? content.textSpan?.toPlainText() ?? '';
        content = Text(
          textData,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.primaryDark : const Color(0xFF334155),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        );
      }

      return DropdownMenuItem<T>(
        value: item.value,
        enabled: item.enabled,
        onTap: item.onTap,
        alignment: item.alignment,
        child: content,
      );
    }).toList();

    return Container(
      height: 40,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isFilterActive ? AppColors.primarySoft.withValues(alpha: 0.45) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFilterActive ? AppColors.primary : const Color(0xFFE2E8F0),
          width: isFilterActive ? 1.2 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.white,
          highlightColor: AppColors.primarySoft,
          hoverColor: AppColors.primarySoft.withValues(alpha: 0.5),
          splashColor: AppColors.primaryLight.withValues(alpha: 0.25),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: safeValue,
            isDense: true,
            isExpanded: isExpanded || width != null,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
            elevation: 4,
            menuMaxHeight: 360,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isFilterActive ? AppColors.primaryDark : AppColors.primary,
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
            selectedItemBuilder: (BuildContext context) {
              return items.map<Widget>((DropdownMenuItem<T> item) {
                if (item.child is Text) {
                  final text = item.child as Text;
                  final textData = text.data ?? text.textSpan?.toPlainText() ?? '';
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      textData,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isFilterActive ? FontWeight.w600 : FontWeight.w500,
                        color: isFilterActive ? AppColors.primaryDark : const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: item.child,
                );
              }).toList();
            },
            items: styledItems,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// Material Date Picker button for ERP filters
class ErpDatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const ErpDatePickerButton({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null;

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? now,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime(2035),
          builder: (dialogCtx, child) {
            return Theme(
              data: Theme.of(dialogCtx).copyWith(
                colorScheme: Theme.of(dialogCtx).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasDate ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: hasDate ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              hasDate ? DateFormat('dd MMM yyyy').format(selectedDate!) : label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 12.5,
                color: hasDate ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (hasDate) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => onDateSelected(null),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 14, color: AppColors.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Single unified date filter box supporting both Single Date and Date Range selection
class ErpDateFilterBox extends StatelessWidget {
  final String label;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(DateTime? start, DateTime? end) onDateRangeSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final double? width;

  const ErpDateFilterBox({
    super.key,
    this.label = 'Filter by Date',
    required this.startDate,
    required this.endDate,
    required this.onDateRangeSelected,
    this.firstDate,
    this.lastDate,
    this.width,
  });

  bool get hasFilter => startDate != null || endDate != null;

  bool get isSingleDate {
    if (startDate == null) return false;
    if (endDate == null) return true;
    return startDate!.year == endDate!.year &&
        startDate!.month == endDate!.month &&
        startDate!.day == endDate!.day;
  }

  String get displayText {
    if (!hasFilter) return label;
    final fmt = DateFormat('dd MMM yyyy');
    if (isSingleDate) {
      return fmt.format(startDate!);
    }
    if (startDate != null && endDate != null) {
      final shortFmt = DateFormat('dd MMM');
      if (startDate!.year == endDate!.year) {
        return '${shortFmt.format(startDate!)} - ${fmt.format(endDate!)}';
      }
      return '${fmt.format(startDate!)} - ${fmt.format(endDate!)}';
    }
    if (startDate != null) {
      return 'From ${fmt.format(startDate!)}';
    }
    return 'Until ${fmt.format(endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDateFilterDialog(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hasFilter ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFilter ? AppColors.primary : AppColors.border,
            width: hasFilter ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: width != null ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: width != null ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasFilter
                      ? (isSingleDate ? Icons.event : Icons.date_range)
                      : Icons.calendar_today_outlined,
                  size: 15,
                  color: hasFilter ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  displayText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12.5,
                    color: hasFilter ? AppColors.primaryDark : AppColors.textPrimary,
                    fontWeight: hasFilter ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (hasFilter) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => onDateRangeSelected(null, null),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 14, color: AppColors.textMuted),
                ),
              ),
            ] else ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }

  void _openDateFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _ErpDateFilterDialog(
        initialStart: startDate,
        initialEnd: endDate,
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime(2035),
        onApply: (start, end) {
          onDateRangeSelected(start, end);
        },
      ),
    );
  }
}

class _ErpDateFilterDialog extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  final void Function(DateTime? start, DateTime? end) onApply;

  const _ErpDateFilterDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    required this.onApply,
  });

  @override
  State<_ErpDateFilterDialog> createState() => _ErpDateFilterDialogState();
}

class _ErpDateFilterDialogState extends State<_ErpDateFilterDialog> {
  late bool _isRangeMode;
  late DateTime _singleDate;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = widget.initialStart;
    final end = widget.initialEnd;

    final isSame = start != null && end != null &&
        start.year == end.year && start.month == end.month && start.day == end.day;

    if (start != null && end != null && !isSame) {
      _isRangeMode = true;
      _singleDate = start;
      _rangeStart = start;
      _rangeEnd = end;
    } else if (start != null) {
      _isRangeMode = false;
      _singleDate = start;
      _rangeStart = start;
      _rangeEnd = end ?? start;
    } else {
      _isRangeMode = false;
      _singleDate = now;
      _rangeStart = now;
      _rangeEnd = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isRangeMode ? Icons.date_range : Icons.event,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filter by Date',
                          style: AppTextStyles.h2.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mode Selector Toggle (Single Date vs Date Range)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeTab(
                          label: 'Single Date',
                          icon: Icons.event,
                          isSelected: !_isRangeMode,
                          onTap: () => setState(() => _isRangeMode = false),
                        ),
                      ),
                      Expanded(
                        child: _buildModeTab(
                          label: 'Date Range',
                          icon: Icons.date_range,
                          isSelected: _isRangeMode,
                          onTap: () => setState(() => _isRangeMode = true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tab Content
                if (!_isRangeMode) ...[
                  // Quick presets for Single Date
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildPresetChip('Today', () {
                        setState(() => _singleDate = DateTime.now());
                      }),
                      _buildPresetChip('Yesterday', () {
                        setState(() => _singleDate = DateTime.now().subtract(const Duration(days: 1)));
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Calendar Picker for Single Date
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                        ),
                      ),
                      child: CalendarDatePicker(
                        initialDate: _singleDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        onDateChanged: (val) {
                          setState(() => _singleDate = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Apply Single Date Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      widget.onApply(_singleDate, _singleDate);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Apply Date (${fmt.format(_singleDate)})',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else ...[
                  // Quick Presets for Date Range
                  Text(
                    'Quick Ranges',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPresetChip('Today', () {
                        final now = DateTime.now();
                        setState(() {
                          _rangeStart = now;
                          _rangeEnd = now;
                        });
                      }),
                      _buildPresetChip('Yesterday', () {
                        final yest = DateTime.now().subtract(const Duration(days: 1));
                        setState(() {
                          _rangeStart = yest;
                          _rangeEnd = yest;
                        });
                      }),
                      _buildPresetChip('This Week', () {
                        final now = DateTime.now();
                        final weekStart = now.subtract(Duration(days: now.weekday - 1));
                        setState(() {
                          _rangeStart = weekStart;
                          _rangeEnd = now;
                        });
                      }),
                      _buildPresetChip('This Month', () {
                        final now = DateTime.now();
                        setState(() {
                          _rangeStart = DateTime(now.year, now.month, 1);
                          _rangeEnd = now;
                        });
                      }),
                      _buildPresetChip('Last 30 Days', () {
                        final now = DateTime.now();
                        setState(() {
                          _rangeStart = now.subtract(const Duration(days: 30));
                          _rangeEnd = now;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // From & To Date Selectors
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateBox(
                          title: 'From Date',
                          date: _rangeStart,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _rangeStart ?? DateTime.now(),
                              firstDate: widget.firstDate,
                              lastDate: widget.lastDate,
                            );
                            if (picked != null) {
                              setState(() {
                                _rangeStart = picked;
                                if (_rangeEnd != null && _rangeEnd!.isBefore(picked)) {
                                  _rangeEnd = picked;
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
                      ),
                      Expanded(
                        child: _buildDateBox(
                          title: 'To Date',
                          date: _rangeEnd,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _rangeEnd ?? _rangeStart ?? DateTime.now(),
                              firstDate: _rangeStart ?? widget.firstDate,
                              lastDate: widget.lastDate,
                            );
                            if (picked != null) {
                              setState(() => _rangeEnd = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Apply Range Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final start = _rangeStart ?? _rangeEnd ?? DateTime.now();
                      final end = _rangeEnd ?? _rangeStart ?? DateTime.now();
                      widget.onApply(start, end);
                      Navigator.pop(context);
                    },
                    child: Text(
                      _rangeStart != null && _rangeEnd != null
                          ? 'Apply Range (${DateFormat('dd MMM').format(_rangeStart!)} - ${DateFormat('dd MMM').format(_rangeEnd!)})'
                          : 'Apply Range',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Bottom row: Clear and Cancel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear Filter', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        widget.onApply(null, null);
                        Navigator.pop(context);
                      },
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  Widget _buildDateBox({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final fmt = DateFormat('dd MMM yyyy');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    date != null ? fmt.format(date) : 'Select date',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: date != null ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

