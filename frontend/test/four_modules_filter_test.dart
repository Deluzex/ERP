import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/erp_filter_controls.dart';
import 'package:frontend/core/widgets/erp_pagination_bar.dart';

void main() {
  group('Four Modules Filter & Date Range Logic Tests', () {
    test('Positive: Inclusive date filtering matches full day from 00:00:00 to 23:59:59', () {
      final startDate = DateTime(2026, 3, 1);
      final endDate = DateTime(2026, 3, 15);

      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      // Boundaries
      final eventOnStartDayMorning = DateTime(2026, 3, 1, 0, 0, 1);
      final eventOnEndDayNight = DateTime(2026, 3, 15, 23, 59, 58);
      final eventMidRange = DateTime(2026, 3, 8, 12, 0, 0);
      final eventBefore = DateTime(2026, 2, 28, 23, 59, 59);
      final eventAfter = DateTime(2026, 3, 16, 0, 0, 1);

      bool isIncluded(DateTime date) {
        if (date.isBefore(startOfDay)) return false;
        if (date.isAfter(endOfDay)) return false;
        return true;
      }

      expect(isIncluded(eventOnStartDayMorning), isTrue);
      expect(isIncluded(eventOnEndDayNight), isTrue);
      expect(isIncluded(eventMidRange), isTrue);
      expect(isIncluded(eventBefore), isFalse);
      expect(isIncluded(eventAfter), isFalse);
    });

    test('Edge case: Same-day start and end date inclusive range', () {
      final selectedDate = DateTime(2026, 5, 10);
      final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

      bool isIncluded(DateTime date) {
        if (date.isBefore(startOfDay)) return false;
        if (date.isAfter(endOfDay)) return false;
        return true;
      }

      expect(isIncluded(DateTime(2026, 5, 10, 0, 0, 0)), isTrue);
      expect(isIncluded(DateTime(2026, 5, 10, 14, 30, 0)), isTrue);
      expect(isIncluded(DateTime(2026, 5, 10, 23, 59, 59)), isTrue);
      expect(isIncluded(DateTime(2026, 5, 9, 23, 59, 59)), isFalse);
      expect(isIncluded(DateTime(2026, 5, 11, 0, 0, 0)), isFalse);
    });

    test('Pagination slicing logic slices lists accurately', () {
      final items = List.generate(45, (i) => 'Item $i');
      int pageSize = 10;
      int currentPage = 0;

      List<String> getPagedItems(int page, int size) {
        final start = page * size;
        if (start >= items.length) return [];
        final end = (start + size) > items.length ? items.length : (start + size);
        return items.sublist(start, end);
      }

      // Page 0: items 0..9 (10 items)
      expect(getPagedItems(0, pageSize).length, 10);
      expect(getPagedItems(0, pageSize).first, 'Item 0');
      expect(getPagedItems(0, pageSize).last, 'Item 9');

      // Page 4: items 40..44 (5 items)
      expect(getPagedItems(4, pageSize).length, 5);
      expect(getPagedItems(4, pageSize).first, 'Item 40');
      expect(getPagedItems(4, pageSize).last, 'Item 44');

      // Page 5: out of range -> empty list
      expect(getPagedItems(5, pageSize).isEmpty, isTrue);
    });

    testWidgets('ErpDateFilterBox widget renders and clears correctly', (WidgetTester tester) async {
      DateTime? currentStart = DateTime(2026, 1, 1);
      DateTime? currentEnd = DateTime(2026, 1, 31);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ErpDateFilterBox(
                  startDate: currentStart,
                  endDate: currentEnd,
                  onDateRangeSelected: (start, end) {
                    setState(() {
                      currentStart = start;
                      currentEnd = end;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify date text is rendered
      expect(find.byType(ErpDateFilterBox), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap clear icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(currentStart, isNull);
      expect(currentEnd, isNull);
    });

    testWidgets('ErpPaginationBar renders correct controls and calls callback', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      int activePage = 0;
      int activePageSize = 10;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1024,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ErpPaginationBar(
                    currentPage: activePage,
                    pageSize: activePageSize,
                    totalRecords: 50,
                    onPageChanged: (newPage) {
                      setState(() {
                        activePage = newPage;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ErpPaginationBar), findsOneWidget);
      expect(find.text('Showing 1 to 10 of 50 records'), findsOneWidget);

      // Tap next page button
      final nextButton = find.byIcon(Icons.chevron_right);
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(activePage, 1);
      expect(find.text('Showing 11 to 20 of 50 records'), findsOneWidget);
    });

    test('Dashboard activity stock movements date filter logic filters correctly', () {
      final now = DateTime.now();
      final movements = [
        DateTime(now.year, now.month, now.day, 10, 0), // Today
        now.subtract(const Duration(days: 2)), // 2 days ago
        now.subtract(const Duration(days: 10)), // 10 days ago
      ];

      // Filter for last 3 days
      final startDate = now.subtract(const Duration(days: 3));
      final endDate = now;

      final filtered = movements.where((date) {
        if (date.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) return false;
        if (date.isAfter(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59))) return false;
        return true;
      }).toList();

      expect(filtered.length, 2);
    });

    test('Accounts dashboard payment transaction history date filter matches correctly', () {
      final dates = [
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 22),
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 28),
      ];

      final filterStart = DateTime(2026, 10, 21);
      final filterEnd = DateTime(2026, 10, 25);

      final matches = dates.where((d) {
        if (d.isBefore(DateTime(filterStart.year, filterStart.month, filterStart.day))) return false;
        if (d.isAfter(DateTime(filterEnd.year, filterEnd.month, filterEnd.day, 23, 59, 59))) return false;
        return true;
      }).toList();

      expect(matches.length, 2);
      expect(matches.contains(DateTime(2026, 10, 22)), isTrue);
      expect(matches.contains(DateTime(2026, 10, 25)), isTrue);
    });
  });
}

