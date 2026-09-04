import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../core/models/sale_model.dart';
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

// Sales creation navigation helper state
final salesCreateDocTypeProvider = StateProvider<SalesDocumentType?>((ref) => null);
final salesCreateSourceDocIdProvider = StateProvider<String?>((ref) => null);

// Global Search Query
final globalSearchQueryProvider = StateProvider<String>((ref) => '');

// Filter states
final stockMovementFilterTypeProvider = StateProvider<StockMovementType?>((ref) => null);
final stockMovementSearchProvider = StateProvider<String>((ref) => '');

// Sidebar collapsed/expanded state
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

// Active Record Details Stack for Drilldown Navigation
class ActiveRecordDetails {
  final String recordId;
  final String recordType;
  final ErpNavSection parentSection;

  const ActiveRecordDetails({
    required this.recordId,
    required this.recordType,
    required this.parentSection,
  });
}

class RecordDetailsStackNotifier extends StateNotifier<List<ActiveRecordDetails>> {
  RecordDetailsStackNotifier() : super([]);

  void push(String recordId, String recordType, ErpNavSection parentSection) {
    state = [
      ...state,
      ActiveRecordDetails(recordId: recordId, recordType: recordType, parentSection: parentSection),
    ];
  }

  void pop() {
    if (state.isNotEmpty) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void clear() {
    state = [];
  }
}

final activeRecordDetailsStackProvider = StateNotifierProvider<RecordDetailsStackNotifier, List<ActiveRecordDetails>>((ref) {
  return RecordDetailsStackNotifier();
});
