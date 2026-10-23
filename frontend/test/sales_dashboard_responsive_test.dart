import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/sales/screens/sales_dashboard_screen.dart';

void main() {
  group('SalesDashboardScreen No-Render-Box-With-No-Size Test Suite', () {
    testWidgets('Positive: Desktop 1920px mouse hover and hit-testing works with no layout error', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SalesDashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Perform multiple mouse movement hit-tests across the screen
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(const Offset(300, 100));
      await tester.pump();
      await gesture.moveTo(const Offset(600, 260));
      await tester.pump();
      await gesture.moveTo(const Offset(900, 360));
      await tester.pumpAndSettle();
    });

    testWidgets('Positive: Tablet 768px layout and hit-testing operates cleanly', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(768, 1024);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SalesDashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(const Offset(400, 300));
      await tester.pumpAndSettle();
    });

    testWidgets('Positive: Mobile 375px narrow layout operates without overflow or missing sizes', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(375, 812);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SalesDashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sales Workflow Stages'));
      await tester.pumpAndSettle();
    });
  });
}
