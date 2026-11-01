import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/theme/app_text_styles.dart';
import 'package:frontend/core/widgets/erp_data_table.dart';
import 'package:frontend/core/widgets/figma_metric_card.dart';
import 'package:frontend/core/widgets/stat_card.dart';

void main() {
  group('Table Header Typography & Boldness Verification', () {
    testWidgets('ErpDataTable standard header renders with FontWeight.w700 (bold)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErpDataTable(
              columns: const [
                ErpColumn(title: 'Customer Name'),
                ErpColumn(title: 'Phone Number'),
                ErpColumn(title: 'Balance', isNumeric: true),
              ],
              rows: const [
                [
                  Text('Acme Corp'),
                  Text('+91 9876543210'),
                  Text('₹25,000.00'),
                ],
              ],
            ),
          ),
        ),
      );

      // Verify column header texts are rendered in uppercase
      expect(find.text('CUSTOMER NAME'), findsOneWidget);
      expect(find.text('PHONE NUMBER'), findsOneWidget);
      expect(find.text('BALANCE'), findsOneWidget);

      // Verify that every column header has bold font weight (w700)
      final headerTextWidgets = tester.widgetList<Text>(find.byType(Text)).where((t) {
        return t.data == 'CUSTOMER NAME' || t.data == 'PHONE NUMBER' || t.data == 'BALANCE';
      });

      for (final textWidget in headerTextWidgets) {
        expect(textWidget.style?.fontWeight, equals(FontWeight.w700),
            reason: 'Header "${textWidget.data}" must be bold (FontWeight.w700)');
      }

      // Verify DataTable headingTextStyle is also bold
      final dataTable = tester.widget<DataTable>(find.byType(DataTable));
      expect(dataTable.headingTextStyle?.fontWeight, equals(FontWeight.w700));

      // Verify row data text is NOT bold (remains standard weight)
      final rowDataAcme = tester.widget<Text>(find.text('Acme Corp'));
      expect(rowDataAcme.style?.fontWeight == FontWeight.w700, isFalse,
          reason: 'Row cell data should not be bold');
    });

    testWidgets('ErpDataTable with fixedHeader: true renders pinned headers with FontWeight.w700', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: ErpDataTable(
                fixedHeader: true,
                columns: const [
                  ErpColumn(title: 'Material Name', width: 200),
                  ErpColumn(title: 'SKU Code', width: 150),
                  ErpColumn(title: 'Stock Qty', width: 120, isNumeric: true),
                ],
                rows: const [
                  [
                    Text('Sim Alloy Rod 76177'),
                    Text('RM-PRD-76177'),
                    Text('150 BOX'),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('MATERIAL NAME'), findsOneWidget);
      expect(find.text('SKU CODE'), findsOneWidget);
      expect(find.text('STOCK QTY'), findsOneWidget);

      final headerWidgets = tester.widgetList<Text>(find.byType(Text)).where((t) {
        return t.data == 'MATERIAL NAME' || t.data == 'SKU CODE' || t.data == 'STOCK QTY';
      });

      for (final textWidget in headerWidgets) {
        expect(textWidget.style?.fontWeight, equals(FontWeight.w700),
            reason: 'Pinned header "${textWidget.data}" must be bold (FontWeight.w700)');
      }

      // Verify row data is NOT bold
      final rowCell = tester.widget<Text>(find.text('Sim Alloy Rod 76177'));
      expect(rowCell.style?.fontWeight == FontWeight.w700, isFalse);
    });

    test('AppTextStyles.tableHeader has bold weight (FontWeight.w700)', () {
      expect(AppTextStyles.tableHeader.fontWeight, equals(FontWeight.w700));
      expect(AppTextStyles.tableHeader.fontSize, equals(11.5));
    });
  });

  group('Dashboard Metric Card Improvements & Sizing Verification', () {
    testWidgets('FigmaMetricCard displays value with larger font size (26) and FittedBox', (tester) async {
      const card = FigmaMetricCard(
        icon: Icons.inventory_2_outlined,
        title: 'Raw Material Valuation',
        value: '₹28,08,486.54',
        subtext: '19 Unique items',
      );
      expect(card.titleValueSpacing, equals(6.0));
      expect(card.valueSubtextSpacing, equals(4.0));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: card,
          ),
        ),
      );

      expect(find.text('Raw Material Valuation'), findsOneWidget);
      expect(find.text('₹28,08,486.54'), findsOneWidget);
      expect(find.text('19 Unique items'), findsOneWidget);

      // Verify FittedBox scales and prevents clipping
      expect(find.byType(FittedBox), findsOneWidget);

      // Verify value text style is bold w700 with fontSize 26
      final valueText = tester.widget<Text>(find.text('₹28,08,486.54'));
      expect(valueText.style?.fontSize, equals(26));
      expect(valueText.style?.fontWeight, equals(FontWeight.w700));
    });

    testWidgets('FigmaMetricCard completely displays long currency without text overflow in tight layout', (tester) async {
      // Test in a narrow card container (160px width)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                child: FigmaMetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Total Stock Valuation',
                  value: '₹43,39,946.54',
                  subtext: 'Combined Warehouse Assets',
                ),
              ),
            ),
          ),
        ),
      );

      // Pumping should not trigger any overflow error or throw exceptions
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('₹43,39,946.54'), findsOneWidget);
    });

    testWidgets('StatCard displays value with larger font size (26) and FittedBox', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Total Revenue',
              value: '₹1,50,00,000.00',
              trendText: '+12% from last month',
              isPositiveTrend: true,
            ),
          ),
        ),
      );

      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('₹1,50,00,000.00'), findsOneWidget);

      final valueText = tester.widget<Text>(find.text('₹1,50,00,000.00'));
      expect(valueText.style?.fontSize, equals(26));
      expect(valueText.style?.fontWeight, equals(FontWeight.w700));
    });

    test('AppTextStyles.metricValue has bold weight (FontWeight.w700) and fontSize 26', () {
      expect(AppTextStyles.metricValue.fontWeight, equals(FontWeight.w700));
      expect(AppTextStyles.metricValue.fontSize, equals(26));
    });
  });
}
