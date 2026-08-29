import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../core/models/stock_movement_model.dart';
import '../services/mock_database_service.dart';

// Database Singleton Provider
final databaseServiceProvider = ChangeNotifierProvider<MockDatabaseService>((ref) {
  return MockDatabaseService();
});

// Navigation State Provider
final currentNavSectionProvider = StateProvider<ErpNavSection>((ref) {
  return ErpNavSection.inventoryDashboard;
});

// Global Search Query
final globalSearchQueryProvider = StateProvider<String>((ref) => '');

// Filter states
final stockMovementFilterTypeProvider = StateProvider<StockMovementType?>((ref) => null);
final stockMovementSearchProvider = StateProvider<String>((ref) => '');

// Sidebar collapsed/expanded state
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);
