import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/project_model.dart';
import 'package:frontend/core/api/projects_api_service.dart';

void main() {
  group('Project Model & API Binding Test Suite (Phase 6)', () {
    test('Project.fromJson correctly parses backend camelCase response envelope', () {
      final json = {
        'id': 'prj-uuid-001',
        'projectCode': 'PRJ-2026-0001',
        'name': 'Skyline Luxury Villas',
        'customerId': 'cust-uuid-1',
        'customerName': 'Mehta Builders',
        'dealerId': 'dlr-uuid-1',
        'dealerName': 'Western Dealers',
        'architectId': 'arch-uuid-1',
        'architectName': 'Hafeez Contractor Studio',
        'startDate': '2026-04-01',
        'expectedCompletionDate': '2026-12-31',
        'actualCompletionDate': null,
        'status': 'active',
        'budgetAmount': '750000.50',
        'totalSalesAmount': '125000.00',
        'totalCommissionAmount': '6250.00',
        'notes': 'High-spec architectural profiles & sliding tracks',
        'isDeleted': false,
        'deleteReason': null,
        'createdAt': '2026-04-01T10:00:00.000Z',
        'updatedAt': '2026-04-02T12:00:00.000Z',
      };

      final project = Project.fromJson(json);

      expect(project.id, 'prj-uuid-001');
      expect(project.projectCode, 'PRJ-2026-0001');
      expect(project.name, 'Skyline Luxury Villas');
      expect(project.customerId, 'cust-uuid-1');
      expect(project.customerName, 'Mehta Builders');
      expect(project.dealerId, 'dlr-uuid-1');
      expect(project.dealerName, 'Western Dealers');
      expect(project.architectId, 'arch-uuid-1');
      expect(project.architectName, 'Hafeez Contractor Studio');
      expect(project.status, ProjectStatus.active);
      expect(project.statusLabel, 'Active');
      expect(project.budgetAmount, 750000.50);
      expect(project.totalSalesAmount, 125000.00);
      expect(project.totalCommissionAmount, 6250.00);
      expect(project.notes, 'High-spec architectural profiles & sliding tracks');
      expect(project.isDeleted, false);
      expect(project.deleteReason, isNull);
      expect(project.expectedCompletionDate, isNotNull);
      expect(project.actualCompletionDate, isNull);
    });

    test('Project.fromJson correctly parses raw database snake_case fields', () {
      final json = {
        'id': 'prj-uuid-002',
        'project_code': 'PRJ-2026-0002',
        'name': 'Oberoi Garden City',
        'customer_id': 'cust-uuid-2',
        'customer_name': 'Oberoi Realty',
        'architect_id': 'arch-uuid-2',
        'architect_name': 'Morphogenesis Design',
        'start_date': '2026-05-15T00:00:00.000Z',
        'expected_completion_date': '2026-11-30T00:00:00.000Z',
        'status': 'planned',
        'budget_amount': 1200000.00,
        'is_deleted': true,
        'delete_reason': 'Cancelled by client due to zoning permits',
        'created_at': '2026-05-01T08:00:00.000Z',
      };

      final project = Project.fromJson(json);

      expect(project.id, 'prj-uuid-002');
      expect(project.projectCode, 'PRJ-2026-0002');
      expect(project.name, 'Oberoi Garden City');
      expect(project.customerId, 'cust-uuid-2');
      expect(project.customerName, 'Oberoi Realty');
      expect(project.architectId, 'arch-uuid-2');
      expect(project.architectName, 'Morphogenesis Design');
      expect(project.status, ProjectStatus.planned);
      expect(project.statusLabel, 'Planned');
      expect(project.budgetAmount, 1200000.00);
      expect(project.isDeleted, true);
      expect(project.deleteReason, 'Cancelled by client due to zoning permits');
    });

    test('Project.toJson formats DTO correctly matching NestJS CreateProjectDto', () {
      final project = Project(
        id: 'temp-id',
        name: 'Lodha Grand Tower',
        customerId: 'cust-101',
        architectId: 'arch-202',
        startDate: DateTime(2026, 6, 1),
        expectedCompletionDate: DateTime(2026, 12, 1),
        status: ProjectStatus.active,
        budgetAmount: 450000.0,
        notes: 'Premium gold finish hardware handles',
        createdAt: DateTime(2026, 5, 20),
      );

      final json = project.toJson();

      expect(json['name'], 'Lodha Grand Tower');
      expect(json['customerId'], 'cust-101');
      expect(json['architectId'], 'arch-202');
      expect(json['dealerId'], isNull);
      expect(json['startDate'], '2026-06-01');
      expect(json['expectedCompletionDate'], '2026-12-01');
      expect(json['actualCompletionDate'], isNull);
      expect(json['status'], 'active');
      expect(json['budgetAmount'], 450000.0);
      expect(json['notes'], 'Premium gold finish hardware handles');
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('projectCode'), isFalse);
    });

    test('Project.copyWith preserves existing fields when none provided', () {
      final original = Project(
        id: 'prj-1',
        projectCode: 'PRJ-2026-0001',
        name: 'Initial Project',
        startDate: DateTime(2026, 1, 1),
        status: ProjectStatus.planned,
        budgetAmount: 100000.0,
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(
        name: 'Updated Project Name',
        status: ProjectStatus.active,
        budgetAmount: 150000.0,
      );

      expect(updated.id, 'prj-1');
      expect(updated.projectCode, 'PRJ-2026-0001');
      expect(updated.name, 'Updated Project Name');
      expect(updated.status, ProjectStatus.active);
      expect(updated.budgetAmount, 150000.0);
      expect(updated.startDate, DateTime(2026, 1, 1));
      expect(updated.createdAt, DateTime(2026, 1, 1));
    });

    test('ProjectsApiService class exists and instantiates with singleton client', () {
      final service = ProjectsApiService();
      expect(service, isNotNull);
    });
  });
}
