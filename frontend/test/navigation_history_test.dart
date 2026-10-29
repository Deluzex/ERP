import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/core/utils/navigation_history_stub.dart';

// Standalone fake ref for test isolation
class FakeWidgetRef implements WidgetRef {
  final ProviderContainer container;
  FakeWidgetRef(this.container);

  @override
  BuildContext get context => throw UnimplementedError();

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  T watch<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  bool exists(ProviderBase<Object?> provider) => container.exists(provider);

  @override
  void invalidate(ProviderOrFamily provider) => container.invalidate(provider);

  @override
  void listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) => container.listen(provider, listener, onError: onError);

  @override
  ProviderSubscription<T> listenManual<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) => container.listen(provider, listener, onError: onError, fireImmediately: fireImmediately);

  @override
  T refresh<T>(Refreshable<T> provider) => container.refresh(provider);
}

void main() {
  group('Navigation History & Browser Back Arrow Integration Tests (AI-TDD)', () {
    late ProviderContainer container;
    late FakeWidgetRef fakeRef;

    setUp(() {
      container = ProviderContainer();
      fakeRef = FakeWidgetRef(container);
      NavigationHistory.dispose();
    });

    tearDown(() {
      NavigationHistory.dispose();
      container.dispose();
    });

    test('Initializes with current section and canGoBack is initially false', () {
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.dashboard;
      NavigationHistory.initialize(fakeRef);

      expect(NavigationHistory.canGoBack, isFalse);
      expect(container.read(currentNavSectionProvider), ErpNavSection.dashboard);
    });

    test('Navigating across sections builds history stack and enables back arrow', () {
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.dashboard;
      NavigationHistory.initialize(fakeRef);

      // User navigates: Dashboard -> Purchase Invoices
      NavigationHistory.onSectionChanged(ErpNavSection.purchaseList);
      expect(NavigationHistory.canGoBack, isTrue);

      // User navigates: Purchase Invoices -> Production Invoices
      NavigationHistory.onSectionChanged(ErpNavSection.productionOrders);
      expect(NavigationHistory.canGoBack, isTrue);

      // User clicks browser back arrow: should return to Purchase Invoices
      final poppedFirst = NavigationHistory.goBack();
      expect(poppedFirst, isTrue);
      expect(container.read(currentNavSectionProvider), ErpNavSection.purchaseList);

      // User clicks browser back arrow again: should return to Dashboard
      final poppedSecond = NavigationHistory.goBack();
      expect(poppedSecond, isTrue);
      expect(container.read(currentNavSectionProvider), ErpNavSection.dashboard);

      // History stack exhausted at root: canGoBack is false
      expect(NavigationHistory.canGoBack, isFalse);
      final poppedThird = NavigationHistory.goBack();
      expect(poppedThird, isFalse);
    });

    test('De-duplicates consecutive identical section visits', () {
      container.read(currentNavSectionProvider.notifier).state = ErpNavSection.dashboard;
      NavigationHistory.initialize(fakeRef);

      NavigationHistory.onSectionChanged(ErpNavSection.purchaseList);
      NavigationHistory.onSectionChanged(ErpNavSection.purchaseList); // Duplicate click

      // One back press should take user directly back to Dashboard, not the duplicate
      expect(NavigationHistory.goBack(), isTrue);
      expect(container.read(currentNavSectionProvider), ErpNavSection.dashboard);
      expect(NavigationHistory.canGoBack, isFalse);
    });

    test('URL slug bidirectional mapping correctly matches key ERP sections', () {
      expect(NavigationHistory.pathToSection(ErpNavSection.dashboard), 'dashboard');
      expect(NavigationHistory.pathToSection(ErpNavSection.purchaseList), 'purchase-invoices');
      expect(NavigationHistory.pathToSection(ErpNavSection.productionOrders), 'production-invoices');
      expect(NavigationHistory.pathToSection(ErpNavSection.salesInvoiceList), 'sales-invoices');
      expect(NavigationHistory.pathToSection(ErpNavSection.rawMaterialStock), 'raw-material-stock');

      expect(NavigationHistory.sectionFromPath('#/purchase-invoices'), ErpNavSection.purchaseList);
      expect(NavigationHistory.sectionFromPath('#/production-invoices'), ErpNavSection.productionOrders);
      expect(NavigationHistory.sectionFromPath('#/dashboard'), ErpNavSection.dashboard);
      expect(NavigationHistory.sectionFromPath(''), ErpNavSection.dashboard);
    });
  });
}
