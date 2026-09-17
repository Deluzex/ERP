import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../core/models/rbac_models.dart';
import '../../core/models/sale_model.dart';
import '../../core/models/stock_movement_model.dart';
import '../../core/api/auth_api_service.dart';
import '../services/mock_database_service.dart';

// Database Singleton Provider
final databaseServiceProvider = ChangeNotifierProvider<MockDatabaseService>((ref) {
  return MockDatabaseService();
});

// Authentication Session State Provider
class AuthStateNotifier extends StateNotifier<AppUser?> {
  final Ref ref;
  AuthStateNotifier(this.ref) : super(null);

  final AuthApiService _authApi = AuthApiService();

  Future<bool> loginAsync(String identifier, String password, [String? roleId]) async {
    try {
      final authRes = await _authApi.login(identifier, password);
      final user = authRes.user;
      final db = ref.read(databaseServiceProvider);
      db.setCurrentUser(user);
      state = user;
      await db.loadRoles(forceRefresh: true);
      db.loadAllMasters(forceRefresh: true);

      final landingSection = user.getAccessibleLandingSection(db.roles);
      ref.read(currentNavSectionProvider.notifier).state = landingSection;
      ref.read(activeRecordDetailsStackProvider.notifier).clear();
      return true;
    } catch (e) {
      // Fallback to local mock database if backend network is unreachable or for demo users
      final db = ref.read(databaseServiceProvider);
      final user = db.authenticateUser(identifier, password, roleId);
      if (user != null) {
        state = user;
        final landingSection = user.getAccessibleLandingSection(db.roles);
        ref.read(currentNavSectionProvider.notifier).state = landingSection;
        ref.read(activeRecordDetailsStackProvider.notifier).clear();
        return true;
      }
      rethrow;
    }
  }

  bool login(String identifier, String password, [String? roleId]) {
    final db = ref.read(databaseServiceProvider);
    final user = db.authenticateUser(identifier, password, roleId);
    if (user != null) {
      state = user;
      // Set default landing dashboard based on the user's accessible sections
      final landingSection = user.getAccessibleLandingSection(db.roles);
      ref.read(currentNavSectionProvider.notifier).state = landingSection;
      ref.read(activeRecordDetailsStackProvider.notifier).clear();
      return true;
    }
    return false;
  }

  void switchUser(AppUser user) {
    final db = ref.read(databaseServiceProvider);
    db.setCurrentUser(user);
    state = user;
    final landingSection = user.getAccessibleLandingSection(db.roles);
    ref.read(currentNavSectionProvider.notifier).state = landingSection;
    ref.read(activeRecordDetailsStackProvider.notifier).clear();
  }

  void refreshUserPermissions(String roleId, Map<ErpModule, Set<ErpAction>> permissions) {
    if (state != null && state!.primaryRoleId == roleId) {
      state = state!.copyWith(customPermissionOverrides: permissions);
    }
  }

  void logout() {
    _authApi.logout();
    state = null;
    ref.read(activeRecordDetailsStackProvider.notifier).clear();
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AppUser?>((ref) {
  return AuthStateNotifier(ref);
});

// Authentication status boolean provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider) != null;
});

// Current Authenticated User provider
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider);
});

// Current User's Primary Role Provider
final currentUserRoleProvider = Provider<Role?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final db = ref.watch(databaseServiceProvider);
  return db.getUserRole(user);
});

// Navigation State Provider
final currentNavSectionProvider = StateProvider<ErpNavSection>((ref) {
  return ErpNavSection.dashboard;
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

// Temporary Access Grants Provider
final temporaryGrantsProvider = Provider<List<TemporaryAccessGrant>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.temporaryGrants;
});

// Security Audit Logs Provider
final auditLogsProvider = Provider<List<AuditLogEntry>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.auditLogs;
});

