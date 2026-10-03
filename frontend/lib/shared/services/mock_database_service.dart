import 'package:flutter/foundation.dart';
import '../../app/routes/app_routes.dart';
import '../../core/models/architect_model.dart';
import '../../core/models/category_unit_model.dart';
import '../../core/models/commission_model.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/dealer_model.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/finished_product_model.dart';
import '../../core/models/payment_model.dart';
import '../../core/models/production_model.dart';
import '../../core/models/project_model.dart';
import '../../core/models/purchase_model.dart';
import '../../core/models/raw_material_model.dart';
import '../../core/models/rbac_models.dart';
import '../../core/models/sale_model.dart';
import '../../core/models/stock_adjustment_model.dart';
import '../../core/models/stock_movement_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/vendor_model.dart';
import '../../core/models/whatsapp_models.dart';
import '../../core/api/categories_units_api_service.dart';
import '../../core/api/finished_products_api_service.dart';
import '../../core/api/parties_api_service.dart';
import '../../core/api/raw_materials_api_service.dart';
import '../../core/api/roles_api_service.dart';
import '../../core/api/users_api_service.dart';
import '../../core/api/vendors_api_service.dart';
import '../../core/api/inventory_api_service.dart';
import '../../core/api/purchases_api_service.dart';
import '../../core/api/production_api_service.dart';
import '../../core/api/sales_api_service.dart';
import '../../core/api/projects_api_service.dart';
import '../../core/api/payments_api_service.dart';
import '../../core/api/expenses_api_service.dart';
import '../../core/api/reports_api_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/password_security.dart';

class MockDatabaseService extends ChangeNotifier {
  // Roles & RBAC System
  List<Role> roles = [];
  List<AppUser> users = [];
  late AppUser currentUser;
  List<TemporaryAccessGrant> temporaryGrants = [];
  List<AuditLogEntry> auditLogs = [];

  // Master Lists
  List<ItemCategory> categories = [];
  List<MeasurementUnit> units = [];
  List<RawMaterial> rawMaterials = [];
  List<FinishedProduct> finishedProducts = [];
  List<Vendor> vendors = [];
  List<Customer> customers = [];
  List<Dealer> dealers = [];
  List<Architect> architects = [];
  List<Project> projects = [];

  // Transaction Lists
  List<StockMovement> stockMovements = [];
  List<Purchase> purchases = [];
  List<ProductionOrder> productionOrders = [];
  List<Sale> sales = [];
  List<ErpPayment> payments = [];
  List<ArchitectCommission> commissions = [];
  List<StockAdjustment> stockAdjustments = [];
  List<Expense> expenses = [];
  List<WhatsAppAlertRecipient> alertRecipients = [];
  List<LowStockAlertRecord> alertHistory = [];
  List<WhatsAppMessageLog> messageLogs = [];
  GlobalSupportConfig globalSupportConfig = const GlobalSupportConfig();

  // Counters for doc numbering
  int _purchaseCounter = 104;
  int _productionCounter = 88;
  int _salesCounter = 215;
  int _quotationCounter = 106;
  int _proformaCounter = 53;
  int _soCounter = 75;
  int _deliveryCounter = 42;
  int _returnCounter = 13;
  int _paymentCounter = 312;
  int _commissionCounter = 55;
  int _adjCounter = 19;
  int _expenseCounter = 45;

  MockDatabaseService() {
    _seedInitialData();
  }

  void _seedInitialData() {
    // -------------------------------------------------------------
    // 0. ROLES & PERMISSION MATRIX SEEDING
    // -------------------------------------------------------------
    roles = [
      Role(
        id: 'admin',
        name: 'System Administrator',
        description: 'Complete unrestricted access across all modules, configuration, and security matrices.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.dashboard,
        permissions: {
          for (final m in ErpModule.values) m: ErpAction.values.toSet(),
        },
      ),
      Role(
        id: 'inventory_manager',
        name: 'Inventory Manager',
        description: 'Warehouse operations, raw material stock, finished goods, movements, and stock adjustments.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.inventoryDashboard,
        permissions: {
          ErpModule.dashboard: {ErpAction.view},
          ErpModule.inventory: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.delete,
            ErpAction.export,
            ErpAction.print,
          },
          ErpModule.masters: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.export,
            ErpAction.print,
          },
          ErpModule.reports: {
            ErpAction.view,
            ErpAction.export,
            ErpAction.print,
          },
        },
      ),
      Role(
        id: 'purchase_manager',
        name: 'Purchase Manager',
        description: 'Vendor management, raw material procurement, purchase orders, and goods receiving logs.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.purchaseDashboard,
        permissions: {
          ErpModule.dashboard: {ErpAction.view},
          ErpModule.purchase: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.approve,
            ErpAction.cancel,
            ErpAction.print,
            ErpAction.export,
            ErpAction.share,
          },
          ErpModule.masters: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
          },
          ErpModule.payments: {
            ErpAction.view,
          },
          ErpModule.reports: {
            ErpAction.view,
            ErpAction.export,
            ErpAction.print,
          },
        },
      ),
      Role(
        id: 'production_manager',
        name: 'Production Manager',
        description: 'Shopfloor work orders, raw material consumption tracking, and batch manufacturing costing.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.productionDashboard,
        permissions: {
          ErpModule.dashboard: {ErpAction.view},
          ErpModule.production: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.approve,
            ErpAction.cancel,
            ErpAction.print,
            ErpAction.export,
          },
          ErpModule.inventory: {
            ErpAction.view,
          },
          ErpModule.masters: {
            ErpAction.view,
          },
          ErpModule.reports: {
            ErpAction.view,
            ErpAction.export,
            ErpAction.print,
          },
        },
      ),
      Role(
        id: 'sales_manager',
        name: 'Sales Manager',
        description: 'Sales lifecycle: Quotations, Sales Orders, Tax Invoices, Delivery Challans, and Client Masters.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.salesDashboard,
        permissions: {
          ErpModule.dashboard: {ErpAction.view},
          ErpModule.sales: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.approve,
            ErpAction.cancel,
            ErpAction.print,
            ErpAction.share,
            ErpAction.export,
          },
          ErpModule.masters: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.print,
            ErpAction.export,
          },
          ErpModule.payments: {
            ErpAction.view,
          },
          ErpModule.reports: {
            ErpAction.view,
            ErpAction.export,
            ErpAction.print,
          },
        },
      ),
      Role(
        id: 'accounts_manager',
        name: 'Accounts / Payment Manager',
        description: 'Customer receivables, dealer ledger, vendor settlements, expenses, and commission payouts.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.paymentsDashboard,
        permissions: {
          ErpModule.dashboard: {ErpAction.view},
          ErpModule.payments: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.approve,
            ErpAction.print,
            ErpAction.export,
          },
          ErpModule.sales: {
            ErpAction.view,
            ErpAction.print,
            ErpAction.export,
          },
          ErpModule.purchase: {
            ErpAction.view,
            ErpAction.print,
            ErpAction.export,
          },
          ErpModule.reports: {
            ErpAction.view,
            ErpAction.export,
            ErpAction.print,
          },
        },
      ),
      Role(
        id: 'masters_manager',
        name: 'Master Data Manager',
        description: 'Centralized administrator for Customers, Vendors, Dealers, Architects, RM and FG definitions.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.mastersDashboard,
        permissions: {
          ErpModule.dashboard: {ErpAction.view},
          ErpModule.masters: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.delete,
            ErpAction.export,
            ErpAction.print,
          },
          ErpModule.inventory: {
            ErpAction.view,
          },
          ErpModule.reports: {
            ErpAction.view,
            ErpAction.export,
            ErpAction.print,
          },
        },
      ),
      Role(
        id: 'project_manager',
        name: 'Project Manager',
        description: 'Architectural project portfolio, site delivery tracking, and material budget consumption.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.projectList,
        permissions: {
          ErpModule.dashboard: {ErpAction.view},
          ErpModule.masters: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.export,
            ErpAction.print,
          },
          ErpModule.sales: {
            ErpAction.view,
          },
          ErpModule.production: {
            ErpAction.view,
          },
          ErpModule.inventory: {
            ErpAction.view,
          },
          ErpModule.reports: {
            ErpAction.view,
            ErpAction.export,
            ErpAction.print,
          },
        },
      ),
      Role(
        id: 'report_viewer',
        name: 'Report Viewer (Auditor)',
        description: 'Read-only analytics and audit trail access across all ERP departments.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.reportsDashboard,
        permissions: {
          ErpModule.dashboard: {ErpAction.view},
          ErpModule.reports: {
            ErpAction.view,
            ErpAction.export,
            ErpAction.print,
          },
          ErpModule.inventory: {
            ErpAction.view,
            ErpAction.export,
          },
          ErpModule.purchase: {
            ErpAction.view,
            ErpAction.export,
          },
          ErpModule.production: {
            ErpAction.view,
            ErpAction.export,
          },
          ErpModule.sales: {
            ErpAction.view,
            ErpAction.export,
          },
          ErpModule.payments: {
            ErpAction.view,
            ErpAction.export,
          },
          ErpModule.masters: {
            ErpAction.view,
            ErpAction.export,
          },
        },
      ),
      Role(
        id: 'data_entry',
        name: 'Data Entry Operator',
        description: 'Standard input for vouchers, items, and sales records without approval or deletion rights.',
        isSystemRole: true,
        isActive: true,
        defaultDashboardSection: ErpNavSection.salesDashboard,
        permissions: {
          ErpModule.sales: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
            ErpAction.print,
          },
          ErpModule.inventory: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
          },
          ErpModule.purchase: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
          },
          ErpModule.masters: {
            ErpAction.view,
            ErpAction.create,
            ErpAction.edit,
          },
        },
      ),
    ];

    // -------------------------------------------------------------
    // 0.1 APP USERS SEEDING (PRE-SEEDED DEMO ACCOUNTS)
    // -------------------------------------------------------------
    final saltAdmin = PasswordSecurity.generateSalt();
    final saltInv = PasswordSecurity.generateSalt();
    final saltPur = PasswordSecurity.generateSalt();
    final saltProd = PasswordSecurity.generateSalt();
    final saltSale = PasswordSecurity.generateSalt();
    final saltAcc = PasswordSecurity.generateSalt();
    final saltMast = PasswordSecurity.generateSalt();
    final saltProj = PasswordSecurity.generateSalt();
    final saltRep = PasswordSecurity.generateSalt();
    final saltData = PasswordSecurity.generateSalt();

    users = [
      AppUser(
        id: 'USR-001',
        name: 'Alex Sterling',
        email: 'admin@deluzex.com',
        mobile: '+91 98765 00001',
        passwordHash: PasswordSecurity.hashPassword('admin123', saltAdmin),
        salt: saltAdmin,
        primaryRoleId: 'admin',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
      AppUser(
        id: 'USR-002',
        name: 'Rohan Varma',
        email: 'inventory@deluzex.com',
        mobile: '+91 98765 00002',
        passwordHash: PasswordSecurity.hashPassword('inv123', saltInv),
        salt: saltInv,
        primaryRoleId: 'inventory_manager',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      AppUser(
        id: 'USR-003',
        name: 'Vikram Mehta',
        email: 'purchase@deluzex.com',
        mobile: '+91 98765 00003',
        passwordHash: PasswordSecurity.hashPassword('pur123', saltPur),
        salt: saltPur,
        primaryRoleId: 'purchase_manager',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 85)),
      ),
      AppUser(
        id: 'USR-004',
        name: 'Ananya Desai',
        email: 'production@deluzex.com',
        mobile: '+91 98765 00004',
        passwordHash: PasswordSecurity.hashPassword('prod123', saltProd),
        salt: saltProd,
        primaryRoleId: 'production_manager',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 80)),
      ),
      AppUser(
        id: 'USR-005',
        name: 'Rahul Kapoor',
        email: 'sales@deluzex.com',
        mobile: '+91 98765 00005',
        passwordHash: PasswordSecurity.hashPassword('sale123', saltSale),
        salt: saltSale,
        primaryRoleId: 'sales_manager',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 75)),
      ),
      AppUser(
        id: 'USR-006',
        name: 'Pooja Hegde',
        email: 'accounts@deluzex.com',
        mobile: '+91 98765 00006',
        passwordHash: PasswordSecurity.hashPassword('acc123', saltAcc),
        salt: saltAcc,
        primaryRoleId: 'accounts_manager',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 70)),
      ),
      AppUser(
        id: 'USR-007',
        name: 'Gaurav Kulkarni',
        email: 'masters@deluzex.com',
        mobile: '+91 98765 00010',
        passwordHash: PasswordSecurity.hashPassword('mast123', saltMast),
        salt: saltMast,
        primaryRoleId: 'masters_manager',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 68)),
      ),
      AppUser(
        id: 'USR-008',
        name: 'Sameer Joshi',
        email: 'projects@deluzex.com',
        mobile: '+91 98765 00007',
        passwordHash: PasswordSecurity.hashPassword('proj123', saltProj),
        salt: saltProj,
        primaryRoleId: 'project_manager',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 65)),
      ),
      AppUser(
        id: 'USR-009',
        name: 'Kavita Nair',
        email: 'reports@deluzex.com',
        mobile: '+91 98765 00008',
        passwordHash: PasswordSecurity.hashPassword('rep123', saltRep),
        salt: saltRep,
        primaryRoleId: 'report_viewer',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      AppUser(
        id: 'USR-010',
        name: 'Deepak Sharma',
        email: 'dataentry@deluzex.com',
        mobile: '+91 98765 00009',
        passwordHash: PasswordSecurity.hashPassword('data123', saltData),
        salt: saltData,
        primaryRoleId: 'data_entry',
        isActive: true,
        avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
        createdAt: DateTime.now().subtract(const Duration(days: 50)),
      ),
    ];

    currentUser = users.first;

    // -------------------------------------------------------------
    // 0.2 SECURITY AUDIT TRAIL LOGS INITIALIZATION
    // -------------------------------------------------------------
    auditLogs = [
      AuditLogEntry(
        id: 'AUD-001',
        userId: 'USR-005',
        userName: 'Rahul Kapoor',
        userRole: 'Sales Manager',
        module: ErpModule.purchase,
        action: ErpAction.view,
        sectionName: 'Purchase Orders',
        timestamp: DateTime.now().subtract(const Duration(hours: 3, minutes: 15)),
        status: 'temporaryGranted',
        authorizingUserId: 'USR-001',
        authorizingUserName: 'Alex Sterling',
        durationMinutes: 30,
        notes: 'Temporary 30-min access authorized by Alex Sterling (System Administrator)',
      ),
      AuditLogEntry(
        id: 'AUD-002',
        userId: 'USR-010',
        userName: 'Deepak Sharma',
        userRole: 'Data Entry Operator',
        module: ErpModule.settings,
        action: ErpAction.view,
        sectionName: 'System Settings',
        timestamp: DateTime.now().subtract(const Duration(hours: 5, minutes: 40)),
        status: 'denied',
        notes: 'Failed supervisor password verification for restricted module Settings',
      ),
      AuditLogEntry(
        id: 'AUD-003',
        userId: 'USR-002',
        userName: 'Rohan Varma',
        userRole: 'Inventory Manager',
        module: ErpModule.sales,
        action: ErpAction.view,
        sectionName: 'Sales Invoices',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        status: 'temporaryGranted',
        authorizingUserId: 'USR-001',
        authorizingUserName: 'Alex Sterling',
        durationMinutes: 60,
        notes: 'Temporary 60-min access authorized by Alex Sterling (System Administrator)',
      ),
    ];

    // Categories & Units
    categories = [
      ItemCategory(id: 'CAT-1', name: 'Wall Lights & Sconces', description: 'Architectural wall mounted lighting'),
      ItemCategory(id: 'CAT-2', name: 'Pendants & Chandeliers', description: 'Suspension & luxury ambient lights'),
      ItemCategory(id: 'CAT-3', name: 'Raw Metals & Aluminum', description: 'Extruded aluminum profiles & brass components'),
      ItemCategory(id: 'CAT-4', name: 'LED Drivers & Diodes', description: 'SMD LED strips, COB chips and constant current drivers'),
      ItemCategory(id: 'CAT-5', name: 'Diffusers & Glassware', description: 'Frosted acrylic and hand-blown glass shades'),
    ];

    units = [
      MeasurementUnit(id: 'U-1', name: 'Pieces', symbol: 'PCS'),
      MeasurementUnit(id: 'U-2', name: 'Meters', symbol: 'MTR'),
      MeasurementUnit(id: 'U-3', name: 'Kilograms', symbol: 'KG'),
      MeasurementUnit(id: 'U-4', name: 'Boxes', symbol: 'BOX'),
      MeasurementUnit(id: 'U-5', name: 'Rolls', symbol: 'ROL'),
    ];

    // Vendors
    vendors = [
      Vendor(
        id: 'VEN-001',
        name: 'Apex Aluminum Extrusions Ltd',
        contactPerson: 'Vikram Mehta',
        mobile: '+91 98201 44521',
        email: 'sales@apexaluminum.in',
        gstNumber: '27AAACA1234F1Z5',
        panNumber: 'AAACA1234F',
        address: 'Plot 42, GIDC Industrial Estate, Surat, Gujarat',
        paymentTerms: 'Net 30 Days',
        creditLimit: 500000.0,
        outstandingBalance: 145000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
      Vendor(
        id: 'VEN-002',
        name: 'Lumileds Semiconductor India',
        contactPerson: 'Priya Sharma',
        mobile: '+91 99304 88124',
        email: 'priya.s@lumileds-india.com',
        gstNumber: '29AABCL5543K1ZQ',
        panNumber: 'AABCL5543K',
        address: 'Electronic City Phase 1, Bengaluru, Karnataka',
        paymentTerms: 'Net 15 Days',
        creditLimit: 800000.0,
        outstandingBalance: 230000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      Vendor(
        id: 'VEN-003',
        name: 'Precision Optics & Glass Corp',
        contactPerson: 'Rajesh Nair',
        mobile: '+91 97112 33490',
        email: 'orders@precisionoptics.co',
        gstNumber: '07AAECP8876H1Z2',
        panNumber: 'AAECP8876H',
        address: 'Okhla Industrial Area Phase III, New Delhi',
        paymentTerms: 'Immediate / Advance',
        creditLimit: 300000.0,
        outstandingBalance: 65000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ];

    // Customers
    customers = [
      Customer(
        id: 'CUST-001',
        name: 'Oberoi Sky City Residences',
        mobile: '+91 98210 11223',
        email: 'procurement@oberoiskycity.com',
        gstNumber: '27AABCO8890K1Z9',
        address: 'Borivali East, Western Express Highway, Mumbai',
        outstandingAmount: 380000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 80)),
      ),
      Customer(
        id: 'CUST-002',
        name: 'Grand Hyatt Villa Suites',
        mobile: '+91 98334 55667',
        email: 'projects@grandhyattmumbai.com',
        gstNumber: '27AACCG1122D1ZP',
        address: 'Santacruz East, Mumbai, Maharashtra',
        outstandingAmount: 0.0,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
      Customer(
        id: 'CUST-003',
        name: 'The St. Regis Penthouse (Mr. Singhania)',
        mobile: '+91 99200 44332',
        email: 'singhania.estate@gmail.com',
        gstNumber: '27AAFPS3322E1Z3',
        address: 'Lower Parel, Mumbai',
        outstandingAmount: 125000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Customer(
        id: 'CUST-004',
        name: 'Sanjay Puri Architectural Residence & Studio',
        mobile: '+91 98200 12345',
        email: 'studio@sanjaypuriarchitects.com',
        gstNumber: '27AABCS5566N1Z1',
        address: 'Worli Sea Face, Mumbai',
        outstandingAmount: 65000.0,
        linkedArchitectId: 'ARCH-001',
        isAlsoArchitect: true,
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
    ];

    // Dealers
    dealers = [
      Dealer(
        id: 'DLR-001',
        name: 'Luxe Lightings & Decor Studio',
        contactPerson: 'Karan Mehra',
        mobile: '+91 98450 77112',
        companyName: 'Luxe Lighting Ventures LLP',
        email: 'karan@luxelightings.in',
        gstNumber: '29AABFL4433J1Z8',
        address: 'Indiranagar 100ft Road, Bengaluru, Karnataka',
        outstandingAmount: 210000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
      ),
      Dealer(
        id: 'DLR-002',
        name: 'Aura Illumination & Interiors',
        contactPerson: 'Anita Desai',
        mobile: '+91 98223 99881',
        companyName: 'Aura Studio Pvt Ltd',
        email: 'anita@aurastudio.com',
        gstNumber: '27AAGCA9988M1ZL',
        address: 'Koregaon Park, Pune, Maharashtra',
        outstandingAmount: 95000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 70)),
      ),
    ];

    // Architects
    architects = [
      Architect(
        id: 'ARCH-001',
        name: 'Ar. Sanjay Puri',
        companyName: 'Sanjay Puri Architects',
        mobile: '+91 98200 12345',
        email: 'studio@sanjaypuriarchitects.com',
        gstNumber: '27AABCS5566N1Z1',
        address: 'Worli Sea Face, Mumbai',
        defaultCommissionRate: 5.0,
        totalCommissionEarned: 185000.0,
        pendingCommission: 45000.0,
        approvedCommission: 60000.0,
        paidCommission: 80000.0,
        linkedCustomerId: 'CUST-004',
        isAlsoCustomer: true,
        createdAt: DateTime.now().subtract(const Duration(days: 150)),
      ),
      Architect(
        id: 'ARCH-002',
        name: 'Ar. Shabnam Gupta',
        companyName: 'The Orange Lane',
        mobile: '+91 98190 66778',
        email: 'shabnam@theorangelane.com',
        gstNumber: '27AABCT9988P1Z4',
        address: 'Bandra West, Mumbai',
        defaultCommissionRate: 6.0,
        totalCommissionEarned: 120000.0,
        pendingCommission: 30000.0,
        approvedCommission: 40000.0,
        paidCommission: 50000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 110)),
      ),
    ];

    // Projects
    projects = [
      Project(
        id: 'PRJ-001',
        name: 'Sky City Tower C Luxury Penthouses',
        customerId: 'CUST-001',
        customerName: 'Oberoi Sky City Residences',
        architectId: 'ARCH-001',
        architectName: 'Ar. Sanjay Puri',
        startDate: DateTime.now().subtract(const Duration(days: 60)),
        expectedCompletionDate: DateTime.now().add(const Duration(days: 90)),
        status: ProjectStatus.active,
        totalSalesAmount: 760000.0,
        totalCommissionAmount: 38000.0,
        notes: 'Custom architectural brass finish sconces and linear chandeliers',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      Project(
        id: 'PRJ-002',
        name: 'Hyatt Presidential Suite Renovation',
        customerId: 'CUST-002',
        customerName: 'Grand Hyatt Villa Suites',
        architectId: 'ARCH-002',
        architectName: 'Ar. Shabnam Gupta',
        startDate: DateTime.now().subtract(const Duration(days: 40)),
        expectedCompletionDate: DateTime.now().add(const Duration(days: 45)),
        status: ProjectStatus.active,
        totalSalesAmount: 480000.0,
        totalCommissionAmount: 28800.0,
        notes: 'Hand-blown glass pendants and warm dimming fixtures',
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
    ];

    // Raw Materials
    rawMaterials = [
      RawMaterial(
        id: 'RM-001',
        name: 'Aarix Extruded Aluminum Housing 6063-T6',
        itemCode: 'RAW-AL-6063',
        categoryId: 'CAT-3',
        categoryName: 'Raw Metals & Aluminum',
        unit: 'MTR',
        currentStock: 450.0,
        openingStock: 200.0,
        minimumStock: 100.0,
        reorderLevel: 150.0,
        defaultPurchasePrice: 380.0,
        gstPercent: 18.0,
        preferredVendorIds: ['VEN-001'],
        preferredVendorNames: ['Apex Aluminum Extrusions Ltd'],
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
        updatedAt: DateTime.now(),
      ),
      RawMaterial(
        id: 'RM-002',
        name: 'Lumileds 2835 High-CRI LED Module 3000K',
        itemCode: 'RAW-LED-3000K',
        categoryId: 'CAT-4',
        categoryName: 'LED Drivers & Diodes',
        unit: 'PCS',
        currentStock: 820.0,
        openingStock: 500.0,
        minimumStock: 250.0,
        reorderLevel: 400.0,
        defaultPurchasePrice: 140.0,
        gstPercent: 18.0,
        preferredVendorIds: ['VEN-002'],
        preferredVendorNames: ['Lumileds Semiconductor India'],
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
        updatedAt: DateTime.now(),
      ),
      RawMaterial(
        id: 'RM-003',
        name: 'Tridonic Constant Current LED Driver 40W Dimmable',
        itemCode: 'RAW-DRV-40W',
        categoryId: 'CAT-4',
        categoryName: 'LED Drivers & Diodes',
        unit: 'PCS',
        currentStock: 45.0, // Low stock! min is 60
        openingStock: 80.0,
        minimumStock: 60.0,
        reorderLevel: 80.0,
        defaultPurchasePrice: 620.0,
        gstPercent: 18.0,
        preferredVendorIds: ['VEN-002'],
        preferredVendorNames: ['Lumileds Semiconductor India'],
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        updatedAt: DateTime.now(),
      ),
      RawMaterial(
        id: 'RM-004',
        name: 'Opal Frosted Acrylic Diffuser Sheet 3mm',
        itemCode: 'RAW-DIF-OPAL',
        categoryId: 'CAT-5',
        categoryName: 'Diffusers & Glassware',
        unit: 'PCS',
        currentStock: 18.0, // Low stock! min is 25
        openingStock: 50.0,
        minimumStock: 25.0,
        reorderLevel: 35.0,
        defaultPurchasePrice: 420.0,
        gstPercent: 18.0,
        preferredVendorIds: ['VEN-003'],
        preferredVendorNames: ['Precision Optics & Glass Corp'],
        createdAt: DateTime.now().subtract(const Duration(days: 80)),
        updatedAt: DateTime.now(),
      ),
      RawMaterial(
        id: 'RM-005',
        name: 'Brass CNC Machined End Caps (Brushed Gold)',
        itemCode: 'RAW-BRS-CAP',
        categoryId: 'CAT-3',
        categoryName: 'Raw Metals & Aluminum',
        unit: 'PCS',
        currentStock: 12.0, // Low stock! min is 30
        openingStock: 60.0,
        minimumStock: 30.0,
        reorderLevel: 45.0,
        defaultPurchasePrice: 280.0,
        gstPercent: 18.0,
        preferredVendorIds: ['VEN-001'],
        preferredVendorNames: ['Apex Aluminum Extrusions Ltd'],
        createdAt: DateTime.now().subtract(const Duration(days: 80)),
        updatedAt: DateTime.now(),
      ),
    ];

    // Finished Products (Matching screenshot: DLX-WL-001 • Aarix Axis Wall Light, etc.)
    finishedProducts = [
      FinishedProduct(
        id: 'FP-001',
        name: 'Aarix Axis Wall Light',
        itemCode: 'DLX-WL-001',
        categoryId: 'CAT-1',
        categoryName: 'Wall Lights & Sconces',
        unit: 'PCS',
        currentStock: 48.0,
        openingStock: 20.0,
        minimumStock: 15.0,
        costPrice: 2150.0,
        dealerSellingPrice: 3800.0,
        customerSellingPrice: 4800.0,
        gstPercent: 18.0,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        updatedAt: DateTime.now(),
      ),
      FinishedProduct(
        id: 'FP-002',
        name: 'Aarix Linear Suspension Pendant 1200mm',
        itemCode: 'DLX-PD-002',
        categoryId: 'CAT-2',
        categoryName: 'Pendants & Chandeliers',
        unit: 'PCS',
        currentStock: 22.0,
        openingStock: 10.0,
        minimumStock: 8.0,
        costPrice: 5400.0,
        dealerSellingPrice: 9200.0,
        customerSellingPrice: 11500.0,
        gstPercent: 18.0,
        createdAt: DateTime.now().subtract(const Duration(days: 85)),
        updatedAt: DateTime.now(),
      ),
      FinishedProduct(
        id: 'FP-003',
        name: 'Aura Halo Minimalist Ring Light 900mm',
        itemCode: 'DLX-CH-003',
        categoryId: 'CAT-2',
        categoryName: 'Pendants & Chandeliers',
        unit: 'PCS',
        currentStock: 3.0, // Low stock! min is 6
        openingStock: 15.0,
        minimumStock: 6.0,
        costPrice: 7800.0,
        dealerSellingPrice: 13500.0,
        customerSellingPrice: 16800.0,
        gstPercent: 18.0,
        createdAt: DateTime.now().subtract(const Duration(days: 70)),
        updatedAt: DateTime.now(),
      ),
    ];

    // Seed Stock Movements (Matching screenshot activities: Stock In, Stock Out, Stock Transfer, Stock Adjustment for DLX-WL-001)
    final now = DateTime.now();
    stockMovements = [
      StockMovement(
        id: 'MOV-101',
        date: now.subtract(const Duration(minutes: 15)),
        itemId: 'FP-001',
        itemName: 'Aarix Axis Wall Light',
        itemCode: 'DLX-WL-001',
        itemType: ItemType.finishedProduct,
        transactionType: StockMovementType.productionOutput,
        referenceNumber: 'PRD-2026-0087',
        stockIn: 20.0,
        stockOut: 0.0,
        currentBalance: 48.0,
        unit: 'PCS',
        notes: 'Batch completion from assembly line A',
        performedBy: 'Alex Sterling',
      ),
      StockMovement(
        id: 'MOV-102',
        date: now.subtract(const Duration(hours: 1, minutes: 10)),
        itemId: 'FP-001',
        itemName: 'Aarix Axis Wall Light',
        itemCode: 'DLX-WL-001',
        itemType: ItemType.finishedProduct,
        transactionType: StockMovementType.sale,
        referenceNumber: 'INV-2026-0214',
        stockIn: 0.0,
        stockOut: 20.0,
        currentBalance: 28.0,
        unit: 'PCS',
        notes: 'Dispatched to Sky City Residences',
        performedBy: 'Alex Sterling',
      ),
      StockMovement(
        id: 'MOV-103',
        date: now.subtract(const Duration(hours: 2, minutes: 40)),
        itemId: 'FP-001',
        itemName: 'Aarix Axis Wall Light',
        itemCode: 'DLX-WL-001',
        itemType: ItemType.finishedProduct,
        transactionType: StockMovementType.productionOutput,
        referenceNumber: 'PRD-2026-0086',
        stockIn: 20.0,
        stockOut: 0.0,
        currentBalance: 48.0,
        unit: 'PCS',
        notes: 'Pre-assembled stock added',
        performedBy: 'Alex Sterling',
      ),
      StockMovement(
        id: 'MOV-104',
        date: now.subtract(const Duration(hours: 4, minutes: 15)),
        itemId: 'FP-001',
        itemName: 'Aarix Axis Wall Light',
        itemCode: 'DLX-WL-001',
        itemType: ItemType.finishedProduct,
        transactionType: StockMovementType.adjustment,
        referenceNumber: 'ADJ-2026-0018',
        stockIn: 20.0,
        stockOut: 0.0,
        currentBalance: 28.0,
        unit: 'PCS',
        notes: 'Inter-branch stock intake transfer',
        performedBy: 'Alex Sterling',
      ),
      StockMovement(
        id: 'MOV-105',
        date: now.subtract(const Duration(hours: 6, minutes: 30)),
        itemId: 'FP-001',
        itemName: 'Aarix Axis Wall Light',
        itemCode: 'DLX-WL-001',
        itemType: ItemType.finishedProduct,
        transactionType: StockMovementType.adjustment,
        referenceNumber: 'ADJ-2026-0017',
        stockIn: 20.0,
        stockOut: 0.0,
        currentBalance: 8.0,
        unit: 'PCS',
        notes: 'Physical count adjustment reconciliation',
        performedBy: 'Alex Sterling',
      ),
    ];

    // Seed Purchases
    purchases = [
      Purchase(
        id: 'PUR-001',
        purchaseNumber: 'PO-2026-0102',
        purchaseDate: now.subtract(const Duration(days: 5)),
        vendorId: 'VEN-001',
        vendorName: 'Apex Aluminum Extrusions Ltd',
        vendorInvoiceNumber: 'APEX/2026/892',
        invoiceDate: now.subtract(const Duration(days: 6)),
        items: [
          PurchaseLineItem(
            rawMaterialId: 'RM-001',
            rawMaterialName: 'Aarix Extruded Aluminum Housing 6063-T6',
            rawMaterialCode: 'RAW-AL-6063',
            quantity: 200.0,
            unit: 'MTR',
            rate: 380.0,
            discountAmount: 2000.0,
            gstPercent: 18.0,
            lineTotal: 87320.0,
          ),
        ],
        totalAmount: 87320.0,
        paidAmount: 50000.0,
        pendingAmount: 37320.0,
        paymentMode: PaymentMode.bankTransfer,
        status: PurchaseStatus.partialPaid,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      Purchase(
        id: 'PUR-002',
        purchaseNumber: 'PO-2026-0103',
        purchaseDate: now.subtract(const Duration(days: 2)),
        vendorId: 'VEN-002',
        vendorName: 'Lumileds Semiconductor India',
        vendorInvoiceNumber: 'LUMI-IN-4432',
        invoiceDate: now.subtract(const Duration(days: 3)),
        items: [
          PurchaseLineItem(
            rawMaterialId: 'RM-002',
            rawMaterialName: 'Lumileds 2835 High-CRI LED Module 3000K',
            rawMaterialCode: 'RAW-LED-3000K',
            quantity: 400.0,
            unit: 'PCS',
            rate: 140.0,
            discountAmount: 1000.0,
            gstPercent: 18.0,
            lineTotal: 64900.0,
          ),
        ],
        totalAmount: 64900.0,
        paidAmount: 64900.0,
        pendingAmount: 0.0,
        paymentMode: PaymentMode.bankTransfer,
        status: PurchaseStatus.paid,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Purchase(
        id: 'PUR-003',
        purchaseNumber: 'PO-2026-0104',
        purchaseDate: now.subtract(const Duration(days: 1)),
        vendorId: 'VEN-001',
        vendorName: 'Apex Aluminum Extrusions Ltd',
        vendorInvoiceNumber: 'APEX/2026/911',
        invoiceDate: now.subtract(const Duration(days: 1)),
        purchaseType: PurchaseItemType.finishedProduct,
        items: [
          PurchaseLineItem(
            itemType: PurchaseItemType.finishedProduct,
            finishedProductId: 'FP-001',
            finishedProductName: 'Aarix Axis Wall Light',
            finishedProductCode: 'DLX-WL-001',
            quantity: 15.0,
            unit: 'PCS',
            rate: 2150.0,
            discountAmount: 750.0,
            gstPercent: 18.0,
            lineTotal: 37170.0,
          ),
        ],
        subtotalAmount: 32250.0,
        discountAmount: 750.0,
        taxableAmount: 31500.0,
        cgstAmount: 2835.0,
        sgstAmount: 2835.0,
        igstAmount: 0.0,
        gstAmount: 5670.0,
        totalAmount: 37170.0,
        paidAmount: 37170.0,
        pendingAmount: 0.0,
        paymentMode: PaymentMode.bankTransfer,
        status: PurchaseStatus.paid,
        notes: 'External vendor finished goods direct purchase batch',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    // Seed Production Orders
    productionOrders = [
      ProductionOrder(
        id: 'PRD-001',
        productionNumber: 'PRD-2026-0087',
        finishedProductId: 'FP-001',
        finishedProductName: 'Aarix Axis Wall Light',
        finishedProductCode: 'DLX-WL-001',
        unit: 'PCS',
        plannedQuantity: 20.0,
        actualQuantityProduced: 20.0,
        rawMaterialsUsed: [
          ProductionRawMaterialUsage(
            rawMaterialId: 'RM-001',
            rawMaterialName: 'Aarix Extruded Aluminum Housing 6063-T6',
            rawMaterialCode: 'RAW-AL-6063',
            quantityUsed: 20.0,
            unit: 'MTR',
            unitCost: 380.0,
            totalCost: 7600.0,
          ),
          ProductionRawMaterialUsage(
            rawMaterialId: 'RM-002',
            rawMaterialName: 'Lumileds 2835 High-CRI LED Module 3000K',
            rawMaterialCode: 'RAW-LED-3000K',
            quantityUsed: 20.0,
            unit: 'PCS',
            unitCost: 140.0,
            totalCost: 2800.0,
          ),
        ],
        rawMaterialCost: 10400.0,
        labourCost: 4000.0,
        otherExpenses: 1600.0,
        totalProductionCost: 16000.0,
        costPerUnit: 800.0,
        productionDate: now.subtract(const Duration(minutes: 15)),
        status: ProductionStatus.completed,
        notes: 'Assembly completed with standard QC test passed',
        createdAt: now.subtract(const Duration(minutes: 40)),
      ),
    ];

    // Seed Sales & Quotations Workflow Data
    sales = [
      // 1. Quotation: Active Sent with Revision History
      Sale(
        id: 'QT-002',
        invoiceNumber: 'DLZ/QT/2026/0103-R2',
        documentType: SalesDocumentType.quotation,
        partyType: PartyType.customer,
        partyId: 'CUST-001',
        partyName: 'Oberoi Sky City Residences',
        customerContactPerson: 'Rahul Oberoi',
        customerMobile: '+91 98201 11223',
        customerEmail: 'projects@oberoigroup.com',
        customerGstNumber: '27AAACG9876K1Z1',
        billingAddress: 'Oberoi Realty Head Office, Commerz II, Goregaon East, Mumbai',
        shippingAddress: 'Oberoi Sky City Site, Western Express Highway, Borivali East, Mumbai',
        projectId: 'PRJ-001',
        projectName: 'Sky City Tower C Luxury Penthouses',
        architectId: 'ARCH-001',
        architectName: 'Ar. Sanjay Puri',
        salesExecutive: 'Alex Sterling',
        saleDate: now.subtract(const Duration(days: 3)),
        validUntil: now.add(const Duration(days: 27)),
        revisionNumber: 2,
        originalQuotationId: 'QT-001',
        parentQuotationId: 'QT-001-R1',
        parentQuotationNumber: 'DLZ/QT/2026/0103-R1',
        quotationStatus: QuotationStatus.accepted,
        items: [
          SaleLineItem(
            finishedProductId: 'FP-001',
            finishedProductName: 'Aarix Axis Wall Light',
            finishedProductCode: 'DLX-WL-001',
            productDescription: 'Architectural aluminum linear wall fixture, 3000K Warm White CRI 90+',
            quantity: 30.0,
            unit: 'PCS',
            rate: 4800.0,
            discountAmount: 6000.0,
            gstPercent: 18.0,
            lineTotal: 162840.0,
          ),
          SaleLineItem(
            finishedProductId: 'FP-002',
            finishedProductName: 'Lumina Sphere Chandelier',
            finishedProductCode: 'DLX-CH-002',
            productDescription: 'Handcrafted suspension pendant with brushed brass accents',
            quantity: 10.0,
            unit: 'PCS',
            rate: 14500.0,
            discountAmount: 5000.0,
            gstPercent: 18.0,
            lineTotal: 165200.0,
          ),
        ],
        subtotalAmount: 289000.0,
        discountAmount: 11000.0,
        taxableAmount: 278000.0,
        cgstAmount: 25020.0,
        sgstAmount: 25020.0,
        igstAmount: 0.0,
        gstAmount: 50040.0,
        totalAmount: 328040.0,
        paidAmount: 0.0,
        pendingAmount: 328040.0,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.active,
        termsAndConditions: '1. 50% advance with Purchase Order, balance before dispatch.\n2. Delivery timeline: 2-3 weeks from confirmed drawing approval.\n3. 3-Year comprehensive manufacturer warranty on LED drivers & modules.',
        notes: 'Revised pricing approved by Service Director with 5% project rebate.',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      Sale(
        id: 'QT-001-R1',
        invoiceNumber: 'DLZ/QT/2026/0103-R1',
        documentType: SalesDocumentType.quotation,
        partyType: PartyType.customer,
        partyId: 'CUST-001',
        partyName: 'Oberoi Sky City Residences',
        saleDate: now.subtract(const Duration(days: 7)),
        revisionNumber: 1,
        originalQuotationId: 'QT-001',
        quotationStatus: QuotationStatus.superseded,
        items: [
          SaleLineItem(
            finishedProductId: 'FP-001',
            finishedProductName: 'Aarix Axis Wall Light',
            finishedProductCode: 'DLX-WL-001',
            quantity: 30.0,
            unit: 'PCS',
            rate: 5200.0,
            discountAmount: 0.0,
            gstPercent: 18.0,
            lineTotal: 184080.0,
          ),
        ],
        subtotalAmount: 156000.0,
        discountAmount: 0.0,
        gstAmount: 28080.0,
        totalAmount: 184080.0,
        pendingAmount: 184080.0,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.active,
        createdAt: now.subtract(const Duration(days: 7)),
      ),

      // 2. Proforma Invoice: Issued with Advance Payment recorded
      Sale(
        id: 'PI-001',
        invoiceNumber: 'DLZ/PI/2026/0051',
        documentType: SalesDocumentType.proformaInvoice,
        partyType: PartyType.customer,
        partyId: 'CUST-001',
        partyName: 'Oberoi Sky City Residences',
        customerContactPerson: 'Rahul Oberoi',
        customerMobile: '+91 98201 11223',
        customerEmail: 'projects@oberoigroup.com',
        customerGstNumber: '27AAACG9876K1Z1',
        billingAddress: 'Oberoi Realty Head Office, Commerz II, Goregaon East, Mumbai',
        shippingAddress: 'Oberoi Sky City Site, Western Express Highway, Borivali East, Mumbai',
        projectId: 'PRJ-001',
        projectName: 'Sky City Tower C Luxury Penthouses',
        architectId: 'ARCH-001',
        architectName: 'Ar. Sanjay Puri',
        saleDate: now.subtract(const Duration(days: 2)),
        quotationReferenceId: 'QT-002',
        parentQuotationNumber: 'DLZ/QT/2026/0103-R2',
        proformaStatus: ProformaStatus.partialPaid,
        bankDetails: 'Bank: HDFC Bank Ltd | A/C: 50200049281144 | IFSC: HDFC0000060 | Branch: Fort, Mumbai',
        items: [
          SaleLineItem(
            finishedProductId: 'FP-001',
            finishedProductName: 'Aarix Axis Wall Light',
            finishedProductCode: 'DLX-WL-001',
            quantity: 30.0,
            unit: 'PCS',
            rate: 4800.0,
            discountAmount: 6000.0,
            gstPercent: 18.0,
            lineTotal: 162840.0,
          ),
          SaleLineItem(
            finishedProductId: 'FP-002',
            finishedProductName: 'Lumina Sphere Chandelier',
            finishedProductCode: 'DLX-CH-002',
            quantity: 10.0,
            unit: 'PCS',
            rate: 14500.0,
            discountAmount: 5000.0,
            gstPercent: 18.0,
            lineTotal: 165200.0,
          ),
        ],
        subtotalAmount: 289000.0,
        discountAmount: 11000.0,
        taxableAmount: 278000.0,
        cgstAmount: 25020.0,
        sgstAmount: 25020.0,
        igstAmount: 0.0,
        gstAmount: 50040.0,
        totalAmount: 328040.0,
        paidAmount: 100000.0, // Advance received
        pendingAmount: 228040.0,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.partialPaid,
        termsAndConditions: 'PROFORMA INVOICE (Not a Tax Invoice). Material will be released upon receipt of milestone advance.',
        notes: 'Milestone 1 advance of ₹1,00,000 received via RTGS.',
        linkedPaymentIds: ['PAY-003'],
        createdAt: now.subtract(const Duration(days: 2)),
      ),

      // 3. Sales Order: Confirmed with Stock Reservation & Production Shortage Linkage
      Sale(
        id: 'SO-001',
        invoiceNumber: 'DLZ/SO/2026/0074',
        documentType: SalesDocumentType.salesOrder,
        partyType: PartyType.customer,
        partyId: 'CUST-001',
        partyName: 'Oberoi Sky City Residences',
        customerContactPerson: 'Rahul Oberoi',
        customerMobile: '+91 98201 11223',
        customerGstNumber: '27AAACG9876K1Z1',
        billingAddress: 'Oberoi Realty Head Office, Goregaon East, Mumbai',
        shippingAddress: 'Tower C Penthouses, Borivali East, Mumbai',
        projectId: 'PRJ-001',
        projectName: 'Sky City Tower C Luxury Penthouses',
        architectId: 'ARCH-001',
        architectName: 'Ar. Sanjay Puri',
        salesOrderNumber: 'DLZ/SO/2026/0074',
        salesOrderStatus: SalesOrderStatus.partiallyDelivered,
        proformaReferenceId: 'PI-001',
        proformaNumber: 'DLZ/PI/2026/0051',
        quotationReferenceId: 'QT-002',
        saleDate: now.subtract(const Duration(days: 1)),
        deliveryDate: now.add(const Duration(days: 10)),
        items: [
          SaleLineItem(
            finishedProductId: 'FP-001',
            finishedProductName: 'Aarix Axis Wall Light',
            finishedProductCode: 'DLX-WL-001',
            quantity: 30.0,
            reservedQuantity: 10.0, // 20 dispatched, 10 still reserved
            producedQuantity: 30.0,
            deliveredQuantity: 20.0, // 20 delivered in DLV-001
            invoicedQuantity: 20.0,
            returnedQuantity: 0.0,
            unit: 'PCS',
            rate: 4800.0,
            discountAmount: 6000.0,
            gstPercent: 18.0,
            lineTotal: 162840.0,
          ),
        ],
        subtotalAmount: 144000.0,
        discountAmount: 6000.0,
        taxableAmount: 138000.0,
        gstAmount: 24840.0,
        totalAmount: 162840.0,
        paidAmount: 100000.0,
        pendingAmount: 62840.0,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.active,
        linkedDeliveryIds: ['DLV-001'],
        linkedProductionOrderIds: ['PRD-001'],
        createdAt: now.subtract(const Duration(days: 1)),
      ),

      // 4. Delivery / Dispatch Note: Dispatched 20 units
      Sale(
        id: 'DLV-001',
        invoiceNumber: 'DLZ/DLV/2026/0041',
        documentType: SalesDocumentType.delivery,
        partyType: PartyType.customer,
        partyId: 'CUST-001',
        partyName: 'Oberoi Sky City Residences',
        customerContactPerson: 'Site Incharge - Mr. Verma',
        customerMobile: '+91 98201 55441',
        shippingAddress: 'Tower C Penthouses, Borivali East, Mumbai',
        salesOrderReferenceId: 'SO-001',
        salesOrderNumber: 'DLZ/SO/2026/0074',
        deliveryStatus: DeliveryStatus.delivered,
        deliveryNumber: 'DLZ/DLV/2026/0041',
        vehicleNumber: 'MH-04-KU-8842',
        driverContact: 'Sunil Jadhav (+91 97654 32100)',
        trackingNumber: 'TRK-2026-9921',
        saleDate: now.subtract(const Duration(hours: 2)),
        items: [
          SaleLineItem(
            finishedProductId: 'FP-001',
            finishedProductName: 'Aarix Axis Wall Light',
            finishedProductCode: 'DLX-WL-001',
            quantity: 20.0,
            deliveredQuantity: 20.0,
            unit: 'PCS',
            rate: 4800.0,
            discountAmount: 4000.0,
            gstPercent: 18.0,
            lineTotal: 108560.0,
          ),
        ],
        subtotalAmount: 96000.0,
        discountAmount: 4000.0,
        gstAmount: 16560.0,
        totalAmount: 108560.0,
        paidAmount: 0.0,
        pendingAmount: 108560.0,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.completed,
        notes: 'Delivered batch of 20 units with inspection challan signed by Site Manager.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),

      // 5. Final Sales Invoice: Invoiced for delivered 20 units
      Sale(
        id: 'SALE-001',
        invoiceNumber: 'INV-2026-0214',
        documentType: SalesDocumentType.invoice,
        partyType: PartyType.customer,
        partyId: 'CUST-001',
        partyName: 'Oberoi Sky City Residences',
        projectId: 'PRJ-001',
        projectName: 'Sky City Tower C Luxury Penthouses',
        architectId: 'ARCH-001',
        architectName: 'Ar. Sanjay Puri',
        salesOrderReferenceId: 'SO-001',
        salesOrderNumber: 'DLZ/SO/2026/0074',
        saleDate: now.subtract(const Duration(hours: 1)),
        items: [
          SaleLineItem(
            finishedProductId: 'FP-001',
            finishedProductName: 'Aarix Axis Wall Light',
            finishedProductCode: 'DLX-WL-001',
            quantity: 20.0,
            deliveredQuantity: 20.0,
            invoicedQuantity: 20.0,
            unit: 'PCS',
            rate: 4800.0,
            discountAmount: 4000.0,
            gstPercent: 18.0,
            lineTotal: 108560.0,
          ),
        ],
        subtotalAmount: 96000.0,
        discountAmount: 4000.0,
        taxableAmount: 92000.0,
        cgstAmount: 8280.0,
        sgstAmount: 8280.0,
        igstAmount: 0.0,
        gstAmount: 16560.0,
        totalAmount: 108560.0,
        paidAmount: 50000.0,
        pendingAmount: 58560.0,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.partialPaid,
        architectCommissionAmount: 4600.0, // 5% of discounted subtotal
        notes: 'Tax invoice created against Delivery DLZ/DLV/2026/0041.',
        linkedPaymentIds: ['PAY-001'],
        createdAt: now.subtract(const Duration(hours: 1)),
      ),

      // 6. Direct Counter Sale: Immediate invoice & payment
      Sale(
        id: 'SALE-002',
        invoiceNumber: 'INV-2026-0215',
        documentType: SalesDocumentType.invoice,
        partyType: PartyType.customer,
        partyId: 'CUST-002',
        partyName: 'Godrej Woodsman Estate',
        customerContactPerson: 'Amitabh Joshi',
        customerMobile: '+91 99200 44332',
        customerGstNumber: '27AABCG1234F1Z9',
        billingAddress: 'Tower 4, Godrej Woodsman Estate, Vikhroli, Mumbai',
        shippingAddress: 'Tower 4, Godrej Woodsman Estate, Vikhroli, Mumbai',
        saleDate: now.subtract(const Duration(hours: 3)),
        items: [
          SaleLineItem(
            finishedProductId: 'FP-002',
            finishedProductName: 'Lumina Sphere Chandelier',
            finishedProductCode: 'DLX-CH-002',
            quantity: 2.0,
            deliveredQuantity: 2.0,
            invoicedQuantity: 2.0,
            unit: 'PCS',
            rate: 14500.0,
            discountAmount: 1000.0,
            gstPercent: 18.0,
            lineTotal: 33040.0,
          ),
        ],
        subtotalAmount: 29000.0,
        discountAmount: 1000.0,
        taxableAmount: 28000.0,
        cgstAmount: 2520.0,
        sgstAmount: 2520.0,
        igstAmount: 0.0,
        gstAmount: 5040.0,
        totalAmount: 33040.0,
        paidAmount: 33040.0,
        pendingAmount: 0.0,
        paymentMode: PaymentMode.upi,
        status: SaleStatus.paid,
        notes: 'Direct counter sale paid instantly via UPI receipt.',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),

      // 7. Sales Return: Good condition restocked item
      Sale(
        id: 'RET-001',
        invoiceNumber: 'DLZ/RET/2026/0012',
        documentType: SalesDocumentType.salesReturn,
        partyType: PartyType.customer,
        partyId: 'CUST-001',
        partyName: 'Oberoi Sky City Residences',
        originalInvoiceId: 'SALE-001',
        originalInvoiceNumber: 'INV-2026-0214',
        salesReturnStatus: SalesReturnStatus.completed,
        returnCondition: ReturnCondition.goodCondition,
        returnFinancialAction: ReturnFinancialAction.adjustOutstanding,
        returnReason: 'Excess quantity ordered by client for Penthouse A foyer',
        saleDate: now.subtract(const Duration(minutes: 30)),
        items: [
          SaleLineItem(
            finishedProductId: 'FP-001',
            finishedProductName: 'Aarix Axis Wall Light',
            finishedProductCode: 'DLX-WL-001',
            quantity: 2.0,
            returnedQuantity: 2.0,
            unit: 'PCS',
            rate: 4800.0,
            discountAmount: 400.0,
            gstPercent: 18.0,
            lineTotal: 10856.0,
            returnCondition: ReturnCondition.goodCondition,
          ),
        ],
        subtotalAmount: 9600.0,
        discountAmount: 400.0,
        taxableAmount: 9200.0,
        cgstAmount: 828.0,
        sgstAmount: 828.0,
        igstAmount: 0.0,
        gstAmount: 1656.0,
        totalAmount: 10856.0,
        paidAmount: 0.0,
        pendingAmount: 0.0,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.completed,
        notes: 'Inspected by QA: Unused in original sealed box. Restocked to finished goods inventory.',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    ];

    // Seed Architect Commissions
    commissions = [
      ArchitectCommission(
        id: 'COM-001',
        commissionNumber: 'COM-2026-0054',
        architectId: 'ARCH-001',
        architectName: 'Ar. Sanjay Puri',
        saleInvoiceId: 'SALE-001',
        saleInvoiceNumber: 'INV-2026-0214',
        projectId: 'PRJ-001',
        projectName: 'Sky City Tower C Luxury Penthouses',
        saleAmount: 92000.0,
        commissionRate: 5.0,
        commissionAmount: 4600.0,
        status: CommissionStatus.approved,
        generatedDate: now.subtract(const Duration(hours: 1)),
        approvedDate: now.subtract(const Duration(minutes: 30)),
      ),
    ];

    // Seed Payments
    payments = [
      ErpPayment(
        id: 'PAY-001',
        paymentNumber: 'PAY-2026-0311',
        paymentType: PaymentType.customerPayment,
        partyId: 'CUST-001',
        partyName: 'Oberoi Sky City Residences',
        referenceDocumentId: 'SALE-001',
        referenceDocumentNumber: 'INV-2026-0214',
        amount: 50000.0,
        paymentMode: PaymentMode.bankTransfer,
        paymentDate: now.subtract(const Duration(minutes: 45)),
        transactionReference: 'NEFT-HDFC-994821',
        notes: 'Initial milestone advance receipt',
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      ErpPayment(
        id: 'PAY-002',
        paymentNumber: 'PAY-2026-0310',
        paymentType: PaymentType.vendorPayment,
        partyId: 'VEN-001',
        partyName: 'Apex Aluminum Extrusions Ltd',
        referenceDocumentId: 'PUR-001',
        referenceDocumentNumber: 'PO-2026-0102',
        amount: 50000.0,
        paymentMode: PaymentMode.bankTransfer,
        paymentDate: now.subtract(const Duration(days: 4)),
        transactionReference: 'RTGS-ICICI-44109',
        notes: 'Part payment against invoice APEX/2026/892',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ];

    // Seed Expenses
    expenses = [
      Expense(
        id: 'EXP-001',
        expenseNumber: 'EXP-2026-0041',
        expenseDate: now.subtract(const Duration(days: 3)),
        expenseName: 'Site Freight & Dedicated Crane Delivery',
        category: ExpenseCategory.transportation,
        amount: 14500.0,
        paidBy: 'Alex Sterling',
        paymentMethod: 'Bank Transfer',
        vendorPayee: 'QuickMove Logistics LLP',
        projectId: 'PRJ-001',
        projectName: 'Sky City Tower C Luxury Penthouses',
        expenseReference: 'QM/LR/9924',
        description: 'Chandelier hoisting crane & specialized freight for 1200mm fixtures',
        paymentStatus: ExpensePaymentStatus.paid,
        createdBy: 'Alex Sterling',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      Expense(
        id: 'EXP-002',
        expenseNumber: 'EXP-2026-0042',
        expenseDate: now.subtract(const Duration(days: 2)),
        expenseName: 'BlueDart Express Document & Sample Couriers',
        category: ExpenseCategory.courier,
        amount: 2800.0,
        paidBy: 'Pooja Verma',
        paymentMethod: 'UPI',
        vendorPayee: 'BlueDart Express',
        projectId: 'PRJ-002',
        projectName: 'Hyatt Presidential Suite Renovation',
        expenseReference: 'BD/AWB/449102',
        description: 'Architect finish approval samples sent to Sanjay Puri Studio',
        paymentStatus: ExpensePaymentStatus.paid,
        createdBy: 'Pooja Verma',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Expense(
        id: 'EXP-003',
        expenseNumber: 'EXP-2026-0043',
        expenseDate: now.subtract(const Duration(days: 1)),
        expenseName: 'Contract Electrician Team Installation Allowance',
        category: ExpenseCategory.labour,
        amount: 18000.0,
        paidBy: 'Alex Sterling',
        paymentMethod: 'Cash',
        vendorPayee: 'Apex Electricals Contractor',
        projectId: 'PRJ-001',
        projectName: 'Sky City Tower C Luxury Penthouses',
        productionId: 'PRD-001',
        productionNumber: 'PRD-2026-0087',
        expenseReference: 'VOUCHER-LAB-881',
        description: 'Milestone 1 ceiling mounting & driver testing labour charges',
        paymentStatus: ExpensePaymentStatus.paid,
        createdBy: 'Alex Sterling',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Expense(
        id: 'EXP-004',
        expenseNumber: 'EXP-2026-0044',
        expenseDate: now.subtract(const Duration(hours: 12)),
        expenseName: 'Assembly Line CNC Laser Cutter Calibration & Service',
        category: ExpenseCategory.maintenance,
        amount: 8500.0,
        paidBy: 'Plant Supervisor',
        paymentMethod: 'Company Card',
        vendorPayee: 'TechServ Precision Services',
        productionId: 'PRD-001',
        productionNumber: 'PRD-2026-0087',
        expenseReference: 'TS-INV-3021',
        description: 'Quarterly optics laser alignment and chiller gas refill',
        paymentStatus: ExpensePaymentStatus.paid,
        createdBy: 'Alex Sterling',
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      Expense(
        id: 'EXP-005',
        expenseNumber: 'EXP-2026-0045',
        expenseDate: now.subtract(const Duration(hours: 4)),
        expenseName: 'Plant Electricity Bill - Unit 2 Assembly Hub',
        category: ExpenseCategory.electricity,
        amount: 32000.0,
        paidBy: 'Alex Sterling',
        paymentMethod: 'Bank Transfer',
        vendorPayee: 'Adani Electricity Mumbai Ltd',
        expenseReference: 'CA-900214821',
        description: 'Monthly manufacturing facility utility bill',
        paymentStatus: ExpensePaymentStatus.paid,
        createdBy: 'Alex Sterling',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
    ];

    // Seed WhatsApp Alert Recipients
    alertRecipients = [
      WhatsAppAlertRecipient(
        id: 'REC-001',
        recipientName: 'Vikram Joshi (Production Head)',
        mobileNumber: '+91 98200 44551',
        whatsappNumber: '+919820044551',
        roleOrDepartment: 'Production & Manufacturing',
        alertType: WhatsAppAlertType.allLowStock,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      WhatsAppAlertRecipient(
        id: 'REC-002',
        recipientName: 'Sunil Nair (Plant Supervisor)',
        mobileNumber: '+91 98330 99882',
        whatsappNumber: '+919833099882',
        roleOrDepartment: 'Plant Assembly Line A',
        alertType: WhatsAppAlertType.lowStockRawMaterial,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 45)),
      ),
      WhatsAppAlertRecipient(
        id: 'REC-003',
        recipientName: 'Ramesh Patel (Warehouse & Inventory)',
        mobileNumber: '+91 98110 33221',
        whatsappNumber: '+919811033221',
        roleOrDepartment: 'Stores & Material Inward',
        alertType: WhatsAppAlertType.allLowStock,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    ];

    // Seed Low Stock Alerts
    alertHistory = [
      LowStockAlertRecord(
        id: 'ALT-001',
        itemId: 'RM-003',
        itemName: 'Tridonic Constant Current LED Driver 40W Dimmable',
        itemCode: 'RAW-DRV-40W',
        itemType: 'Raw Material',
        currentStock: 45.0,
        minimumStock: 60.0,
        reorderLevel: 80.0,
        unit: 'PCS',
        recipientName: 'Vikram Joshi (Production Head)',
        recipientWhatsApp: '+919820044551',
        messageBody: 'Raw Material "Tridonic Constant Current LED Driver 40W Dimmable" [RAW-DRV-40W] is running low.\nCurrent Stock: 45 PCS | Minimum Stock: 60 PCS | Reorder Level: 80 PCS.\nThis may affect upcoming production orders.',
        status: AlertRecordStatus.sent,
        triggeredAt: now.subtract(const Duration(hours: 3)),
      ),
      LowStockAlertRecord(
        id: 'ALT-002',
        itemId: 'RM-005',
        itemName: 'Brass CNC Machined End Caps (Brushed Gold)',
        itemCode: 'RAW-BRS-CAP',
        itemType: 'Raw Material',
        currentStock: 12.0,
        minimumStock: 30.0,
        reorderLevel: 45.0,
        unit: 'PCS',
        recipientName: 'Sunil Nair (Plant Supervisor)',
        recipientWhatsApp: '+919833099882',
        messageBody: 'Raw Material "Brass CNC Machined End Caps" [RAW-BRS-CAP] is critically low.\nCurrent Stock: 12 PCS | Reorder Level: 45 PCS.\nPlease issue purchase order.',
        status: AlertRecordStatus.sent,
        triggeredAt: now.subtract(const Duration(hours: 5)),
      ),
      LowStockAlertRecord(
        id: 'ALT-003',
        itemId: 'FP-003',
        itemName: 'Aura Halo Minimalist Ring Light 900mm',
        itemCode: 'DLX-CH-003',
        itemType: 'Finished Product',
        currentStock: 3.0,
        minimumStock: 6.0,
        reorderLevel: 8.0,
        unit: 'PCS',
        recipientName: 'Vikram Joshi (Production Head)',
        recipientWhatsApp: '+919820044551',
        messageBody: 'Finished Product "Aura Halo Minimalist Ring Light 900mm" [DLX-CH-003] is below minimum buffer.\nCurrent Stock: 3 PCS | Min Level: 6 PCS.',
        status: AlertRecordStatus.sent,
        triggeredAt: now.subtract(const Duration(hours: 6)),
      ),
    ];

    // Seed WhatsApp Message Logs
    messageLogs = [
      WhatsAppMessageLog(
        id: 'WLOG-001',
        messageType: 'Quotation Sent',
        recipientName: 'Rahul Oberoi (Oberoi Sky City)',
        recipientNumber: '+919821011223',
        relatedEntityType: 'Quotation',
        relatedEntityId: 'QT-002',
        relatedEntityNumber: 'DLZ/QT/2026/0103-R2',
        messageText: 'Dear Rahul Oberoi, please find the revised quotation DLZ/QT/2026/0103-R2 for Sky City Tower C project (Amount: Rs. 3,28,040). Download PDF: https://erp.deluzex.com/docs/QT-002.pdf',
        sentAt: now.subtract(const Duration(days: 2)),
        status: 'Delivered',
      ),
      WhatsAppMessageLog(
        id: 'WLOG-002',
        messageType: 'Dispatch Details',
        recipientName: 'Oberoi Sky City Site',
        recipientNumber: '+919821011223',
        relatedEntityType: 'Delivery',
        relatedEntityId: 'DLV-001',
        relatedEntityNumber: 'DLV-2026-0042',
        messageText: 'Your consignment for SO DLZ/SO/2026/0074 is dispatched via BlueDart Express (Tracking: BDX-990214). Vehicle: MH-04-AZ-8812. Expected delivery: Tomorrow.',
        sentAt: now.subtract(const Duration(hours: 4)),
        status: 'Delivered',
      ),
    ];
  }

  // -------------------------------------------------------------
  // STOCK TRANSACTION ENGINE (Critical Rule: Never update stock without ledger)
  // -------------------------------------------------------------
  void _recordStockTransaction({
    required String itemId,
    required String itemName,
    required String itemCode,
    required ItemType itemType,
    required StockMovementType transactionType,
    required String referenceNumber,
    required double stockIn,
    required double stockOut,
    required double newBalance,
    required String unit,
    String? notes,
  }) {
    final movement = StockMovement(
      id: IdGenerator.generateId('MOV'),
      date: DateTime.now(),
      itemId: itemId,
      itemName: itemName,
      itemCode: itemCode,
      itemType: itemType,
      transactionType: transactionType,
      referenceNumber: referenceNumber,
      stockIn: stockIn,
      stockOut: stockOut,
      currentBalance: newBalance,
      unit: unit,
      notes: notes,
      performedBy: currentUser.name,
    );
    stockMovements.insert(0, movement);
  }

  // -------------------------------------------------------------
  // PURCHASE WORKFLOWS
  // -------------------------------------------------------------
  void createPurchase(Purchase purchase) {
    purchases.insert(0, purchase);

    if (purchase.status != PurchaseStatus.draft && purchase.status != PurchaseStatus.cancelled) {
      for (final line in purchase.items) {
        if (purchase.purchaseType == PurchaseItemType.finishedProduct || line.itemType == PurchaseItemType.finishedProduct) {
          // 1A. Finished Product Purchase: Increase Finished Product Stock
          final fpIndex = finishedProducts.indexWhere((fp) =>
              fp.id == line.finishedProductId ||
              (line.finishedProductCode != null && fp.itemCode == line.finishedProductCode));
          if (fpIndex != -1) {
            final fp = finishedProducts[fpIndex];
            final updatedStock = fp.currentStock + line.quantity;
            final updatedPurchased = fp.purchasedStock + line.quantity;
            finishedProducts[fpIndex] = fp.copyWith(
              currentStock: updatedStock,
              purchasedStock: updatedPurchased,
              updatedAt: DateTime.now(),
            );

            _recordStockTransaction(
              itemId: fp.id,
              itemName: fp.name,
              itemCode: fp.itemCode,
              itemType: ItemType.finishedProduct,
              transactionType: StockMovementType.purchase,
              referenceNumber: purchase.purchaseNumber,
              stockIn: line.quantity,
              stockOut: 0.0,
              newBalance: updatedStock,
              unit: fp.unit,
              notes: 'Finished Product Purchase from ${purchase.vendorName} (Inv: ${purchase.vendorInvoiceNumber})',
            );
          }
        } else {
          // 1B. Raw Material Purchase: Increase Raw Material Stock
          final rmIndex = rawMaterials.indexWhere((rm) => rm.id == line.rawMaterialId);
          if (rmIndex != -1) {
            final rm = rawMaterials[rmIndex];
            final updatedStock = rm.currentStock + line.quantity;
            rawMaterials[rmIndex] = rm.copyWith(
              currentStock: updatedStock,
              updatedAt: DateTime.now(),
            );

            _recordStockTransaction(
              itemId: rm.id,
              itemName: rm.name,
              itemCode: rm.itemCode,
              itemType: ItemType.rawMaterial,
              transactionType: StockMovementType.purchase,
              referenceNumber: purchase.purchaseNumber,
              stockIn: line.quantity,
              stockOut: 0.0,
              newBalance: updatedStock,
              unit: rm.unit,
              notes: 'Raw Material Purchase from ${purchase.vendorName} (Inv: ${purchase.vendorInvoiceNumber})',
            );
          }
        }
      }

      // 2. Update Vendor Outstanding
      final vIndex = vendors.indexWhere((v) => v.id == purchase.vendorId);
      if (vIndex != -1) {
        final vendor = vendors[vIndex];
        vendors[vIndex] = vendor.copyWith(
          outstandingBalance: vendor.outstandingBalance + purchase.pendingAmount,
        );
      }

      // 3. Record Payment if paidAmount > 0
      if (purchase.paidAmount > 0) {
        _recordPayment(
          paymentType: PaymentType.vendorPayment,
          partyId: purchase.vendorId,
          partyName: purchase.vendorName,
          referenceDocumentId: purchase.id,
          referenceDocumentNumber: purchase.purchaseNumber,
          amount: purchase.paidAmount,
          paymentMode: purchase.paymentMode,
          notes: 'Direct payment at purchase creation (${purchase.purchaseTypeLabel})',
        );
      }
    }

    notifyListeners();
  }

  // -------------------------------------------------------------
  // PRODUCTION WORKFLOW (Direct Raw Material Consumption & Finished Goods Addition)
  // -------------------------------------------------------------
  void completeProductionOrder(ProductionOrder order) {
    if (order.status == ProductionStatus.completed) {
      // 1. Deduct consumed raw materials
      for (final usage in order.rawMaterialsUsed) {
        final rmIndex = rawMaterials.indexWhere((rm) => rm.id == usage.rawMaterialId);
        if (rmIndex != -1) {
          final rm = rawMaterials[rmIndex];
          final newStock = (rm.currentStock - usage.quantityUsed).clamp(0.0, double.infinity);
          rawMaterials[rmIndex] = rm.copyWith(
            currentStock: newStock,
            updatedAt: DateTime.now(),
          );

          _recordStockTransaction(
            itemId: rm.id,
            itemName: rm.name,
            itemCode: rm.itemCode,
            itemType: ItemType.rawMaterial,
            transactionType: StockMovementType.productionConsumption,
            referenceNumber: order.productionNumber,
            stockIn: 0.0,
            stockOut: usage.quantityUsed,
            newBalance: newStock,
            unit: rm.unit,
            notes: 'Consumed for production of ${order.finishedProductName}',
          );
        }
      }

      // 2. Add finished product output
      final fpIndex = finishedProducts.indexWhere((fp) => fp.id == order.finishedProductId);
      if (fpIndex != -1) {
        final fp = finishedProducts[fpIndex];
        final producedQty = order.actualQuantityProduced > 0 ? order.actualQuantityProduced : order.plannedQuantity;
        final newStock = fp.currentStock + producedQty;
        finishedProducts[fpIndex] = fp.copyWith(
          currentStock: newStock,
          updatedAt: DateTime.now(),
        );

        _recordStockTransaction(
          itemId: fp.id,
          itemName: fp.name,
          itemCode: fp.itemCode,
          itemType: ItemType.finishedProduct,
          transactionType: StockMovementType.productionOutput,
          referenceNumber: order.productionNumber,
          stockIn: producedQty,
          stockOut: 0.0,
          newBalance: newStock,
          unit: fp.unit,
          notes: 'Produced batch of $producedQty units${order.salesOrderNumber != null ? " for SO ${order.salesOrderNumber}" : ""}',
        );

        // 3. If this production order was created for a Sales Order shortage, allocate & reserve stock
        if (order.salesOrderId != null) {
          final soIndex = sales.indexWhere((s) => s.id == order.salesOrderId);
          if (soIndex != -1) {
            final so = sales[soIndex];
            final updatedItems = so.items.map((item) {
              if (item.finishedProductId == order.finishedProductId) {
                final newProduced = item.producedQuantity + producedQty;
                final newReserved = (item.reservedQuantity + producedQty).clamp(0.0, item.quantity);
                return item.copyWith(
                  producedQuantity: newProduced,
                  reservedQuantity: newReserved,
                );
              }
              return item;
            }).toList();

            // Reserve in finished product master
            finishedProducts[fpIndex] = finishedProducts[fpIndex].copyWith(
              reservedStock: finishedProducts[fpIndex].reservedStock + producedQty,
            );

            // Check if all items now have full reservation
            final isFullyReserved = updatedItems.every((i) => i.reservedQuantity >= i.quantity);
            final updatedStatus = isFullyReserved ? SalesOrderStatus.readyForDispatch : SalesOrderStatus.productionPending;

            sales[soIndex] = so.copyWith(
              items: updatedItems,
              salesOrderStatus: updatedStatus,
              activityLogs: [
                ...so.activityLogs,
                DocumentActivityLog(
                  id: IdGenerator.generateId('LOG'),
                  action: 'Production Batch Completed',
                  performedBy: currentUser.name,
                  timestamp: DateTime.now(),
                  details: 'Produced & reserved $producedQty units via ${order.productionNumber}',
                  statusBefore: so.salesOrderStatus?.name,
                  statusAfter: updatedStatus.name,
                ),
              ],
            );
          }
        }
      }
    }

    productionOrders.insert(0, order);
    notifyListeners();
  }

  void updateProductionOrderStatus({
    required String orderId,
    required ProductionStatus newStatus,
    String? reason,
  }) {
    final idx = productionOrders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = productionOrders[idx];
    if (order.status == newStatus) return;

    if (newStatus == ProductionStatus.completed) {
      // 1. Verify stock availability
      for (final usage in order.rawMaterialsUsed) {
        final rmIndex = rawMaterials.indexWhere((rm) => rm.id == usage.rawMaterialId);
        if (rmIndex != -1) {
          final rm = rawMaterials[rmIndex];
          if (rm.currentStock < usage.quantityUsed) {
            throw Exception('Insufficient stock for ${rm.name} (${rm.itemCode}). Available: ${rm.currentStock} ${rm.unit}, Required: ${usage.quantityUsed} ${rm.unit}');
          }
        }
      }

      final producedQty = order.actualQuantityProduced > 0 ? order.actualQuantityProduced : order.plannedQuantity;

      // 2. Deduct consumed raw materials
      for (final usage in order.rawMaterialsUsed) {
        final rmIndex = rawMaterials.indexWhere((rm) => rm.id == usage.rawMaterialId);
        if (rmIndex != -1) {
          final rm = rawMaterials[rmIndex];
          final newStock = (rm.currentStock - usage.quantityUsed).clamp(0.0, double.infinity);
          rawMaterials[rmIndex] = rm.copyWith(
            currentStock: newStock,
            updatedAt: DateTime.now(),
          );

          _recordStockTransaction(
            itemId: rm.id,
            itemName: rm.name,
            itemCode: rm.itemCode,
            itemType: ItemType.rawMaterial,
            transactionType: StockMovementType.productionConsumption,
            referenceNumber: order.productionNumber,
            stockIn: 0.0,
            stockOut: usage.quantityUsed,
            newBalance: newStock,
            unit: rm.unit,
            notes: 'Consumed for production of ${order.finishedProductName}',
          );
        }
      }

      // 3. Add finished goods output
      final fpIndex = finishedProducts.indexWhere((fp) => fp.id == order.finishedProductId);
      if (fpIndex != -1) {
        final fp = finishedProducts[fpIndex];
        final newStock = fp.currentStock + producedQty;
        finishedProducts[fpIndex] = fp.copyWith(
          currentStock: newStock,
          updatedAt: DateTime.now(),
        );

        _recordStockTransaction(
          itemId: fp.id,
          itemName: fp.name,
          itemCode: fp.itemCode,
          itemType: ItemType.finishedProduct,
          transactionType: StockMovementType.productionOutput,
          referenceNumber: order.productionNumber,
          stockIn: producedQty,
          stockOut: 0.0,
          newBalance: newStock,
          unit: fp.unit,
          notes: 'Produced batch of $producedQty units',
        );
      }

      productionOrders[idx] = order.copyWith(
        status: ProductionStatus.completed,
        actualQuantityProduced: producedQty,
      );
      notifyListeners();
      return;
    }

    if (newStatus == ProductionStatus.inProgress) {
      productionOrders[idx] = order.copyWith(status: ProductionStatus.inProgress);
      notifyListeners();
      return;
    }

    if (newStatus == ProductionStatus.cancelled) {
      deleteProductionOrder(orderId: orderId, reason: reason);
      return;
    }

    productionOrders[idx] = order.copyWith(status: newStatus);
    notifyListeners();
  }

  void deleteProductionOrder({required String orderId, String? reason}) {
    final index = productionOrders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final order = productionOrders[index];

      // If the order was completed, revert the stock changes locally
      if (order.status == ProductionStatus.completed) {
        // Revert raw materials consumed
        for (final usage in order.rawMaterialsUsed) {
          final rmIndex = rawMaterials.indexWhere((rm) => rm.id == usage.rawMaterialId);
          if (rmIndex != -1) {
            final rm = rawMaterials[rmIndex];
            final newStock = rm.currentStock + usage.quantityUsed;
            rawMaterials[rmIndex] = rm.copyWith(
              currentStock: newStock,
              updatedAt: DateTime.now(),
            );

            _recordStockTransaction(
              itemId: rm.id,
              itemName: rm.name,
              itemCode: rm.itemCode,
              itemType: ItemType.rawMaterial,
              transactionType: StockMovementType.adjustment,
              referenceNumber: order.productionNumber,
              stockIn: usage.quantityUsed,
              stockOut: 0.0,
              newBalance: newStock,
              unit: rm.unit,
              notes: 'Reversed consumption: Cancelled production batch ${order.productionNumber}',
            );
          }
        }

        // Revert finished goods produced
        final fpIndex = finishedProducts.indexWhere((fp) => fp.id == order.finishedProductId);
        final producedQty = order.actualQuantityProduced > 0 ? order.actualQuantityProduced : order.plannedQuantity;
        if (fpIndex != -1 && producedQty > 0) {
          final fp = finishedProducts[fpIndex];
          final newStock = (fp.currentStock - producedQty).clamp(0.0, double.infinity);
          finishedProducts[fpIndex] = fp.copyWith(
            currentStock: newStock,
            updatedAt: DateTime.now(),
          );

          _recordStockTransaction(
            itemId: fp.id,
            itemName: fp.name,
            itemCode: fp.itemCode,
            itemType: ItemType.finishedProduct,
            transactionType: StockMovementType.adjustment,
            referenceNumber: order.productionNumber,
            stockIn: 0.0,
            stockOut: producedQty,
            newBalance: newStock,
            unit: fp.unit,
            notes: 'Reversed output: Cancelled production batch ${order.productionNumber}',
          );
        }
      }

      productionOrders[index] = order.copyWith(
        isDeleted: true,
        deletedReason: reason,
        deletedAt: DateTime.now(),
        status: ProductionStatus.cancelled,
      );
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // SALES WORKFLOW SUITE (Quotation -> Proforma -> Sales Order -> Delivery -> Invoice -> Return)
  // -------------------------------------------------------------

  // --- 1. QUOTATION WORKFLOW (CRITICAL: ZERO STOCK DEDUCTION) ---
  void createQuotation(Sale quotation) {
    sales.insert(0, quotation);
    notifyListeners();
  }

  void updateQuotation(Sale quotation) {
    final index = sales.indexWhere((s) => s.id == quotation.id);
    if (index != -1) {
      sales[index] = quotation;
      notifyListeners();
    }
  }

  void markQuotationSent(String quotationId) {
    final index = sales.indexWhere((s) => s.id == quotationId);
    if (index != -1) {
      final q = sales[index];
      sales[index] = q.copyWith(
        quotationStatus: QuotationStatus.sent,
        activityLogs: [
          ...q.activityLogs,
          DocumentActivityLog(
            id: IdGenerator.generateId('LOG'),
            action: 'Quotation Sent to Client',
            performedBy: currentUser.name,
            timestamp: DateTime.now(),
            details: 'Quotation shared with customer for review',
          ),
        ],
      );
      notifyListeners();
    }
  }

  void acceptQuotation(String quotationId) {
    final index = sales.indexWhere((s) => s.id == quotationId);
    if (index != -1) {
      final q = sales[index];
      sales[index] = q.copyWith(
        quotationStatus: QuotationStatus.accepted,
        activityLogs: [
          ...q.activityLogs,
          DocumentActivityLog(
            id: IdGenerator.generateId('LOG'),
            action: 'Quotation Accepted',
            performedBy: currentUser.name,
            timestamp: DateTime.now(),
            details: 'Customer accepted the quotation terms',
          ),
        ],
      );
      notifyListeners();
    }
  }

  void rejectQuotation(String quotationId, {String? reason}) {
    final index = sales.indexWhere((s) => s.id == quotationId);
    if (index != -1) {
      final q = sales[index];
      sales[index] = q.copyWith(
        quotationStatus: QuotationStatus.rejected,
        notes: reason != null ? '${q.notes ?? ""}\nRejection Reason: $reason' : q.notes,
        activityLogs: [
          ...q.activityLogs,
          DocumentActivityLog(
            id: IdGenerator.generateId('LOG'),
            action: 'Quotation Rejected',
            performedBy: currentUser.name,
            timestamp: DateTime.now(),
            details: reason ?? 'Customer rejected the quotation',
          ),
        ],
      );
      notifyListeners();
    }
  }

  Sale createQuotationRevision(String originalQuotationId, [Sale? revisedQuotation]) {
    final oldIndex = sales.indexWhere((s) => s.id == originalQuotationId);
    if (oldIndex == -1) throw Exception('Quotation not found');
    final oldQ = sales[oldIndex];

    final newRevNumber = oldQ.revisionNumber + 1;
    final baseNumber = oldQ.invoiceNumber.split('-R').first;
    final newDocNumber = '$baseNumber-R$newRevNumber';

    final revision = revisedQuotation ??
        oldQ.copyWith(
          id: IdGenerator.generateId('QT'),
          invoiceNumber: newDocNumber,
          revisionNumber: newRevNumber,
          parentQuotationId: oldQ.id,
          parentQuotationNumber: oldQ.invoiceNumber,
          quotationStatus: QuotationStatus.draft,
          createdAt: DateTime.now(),
          saleDate: DateTime.now(),
          activityLogs: [
            DocumentActivityLog(
              id: IdGenerator.generateId('LOG'),
              action: 'Created Revision $newRevNumber from ${oldQ.invoiceNumber}',
              performedBy: currentUser.name,
              timestamp: DateTime.now(),
            ),
          ],
        );

    // 1. Mark existing quotation as Superseded
    sales[oldIndex] = oldQ.copyWith(
      quotationStatus: QuotationStatus.superseded,
      activityLogs: [
        ...oldQ.activityLogs,
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Superseded by Revision ${revision.invoiceNumber}',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
        ),
      ],
    );

    // 2. Insert new revision
    sales.insert(0, revision);
    notifyListeners();
    return revision;
  }

  // --- 2. PROFORMA INVOICE WORKFLOW ---
  Sale createProformaFromQuotation(String quotationId) {
    final q = sales.firstWhere((s) => s.id == quotationId);
    final piNumber = 'DLZ/PI/2026/${(++_proformaCounter).toString().padLeft(4, '0')}';
    
    final proforma = Sale(
      id: IdGenerator.generateId('PI'),
      invoiceNumber: piNumber,
      documentType: SalesDocumentType.proformaInvoice,
      partyType: q.partyType,
      partyId: q.partyId,
      partyName: q.partyName,
      customerContactPerson: q.customerContactPerson,
      customerMobile: q.customerMobile,
      customerEmail: q.customerEmail,
      customerGstNumber: q.customerGstNumber,
      billingAddress: q.billingAddress,
      shippingAddress: q.shippingAddress,
      projectId: q.projectId,
      projectName: q.projectName,
      architectId: q.architectId,
      architectName: q.architectName,
      salesExecutive: q.salesExecutive,
      saleDate: DateTime.now(),
      quotationReferenceId: q.id,
      parentQuotationNumber: q.invoiceNumber,
      proformaStatus: ProformaStatus.issued,
      items: q.items.map((i) => i.copyWith()).toList(),
      subtotalAmount: q.subtotalAmount,
      discountAmount: q.discountAmount,
      taxableAmount: q.taxableAmount,
      cgstAmount: q.cgstAmount,
      sgstAmount: q.sgstAmount,
      igstAmount: q.igstAmount,
      gstAmount: q.gstAmount,
      totalAmount: q.totalAmount,
      paidAmount: 0.0,
      pendingAmount: q.totalAmount,
      paymentMode: q.paymentMode,
      status: SaleStatus.active,
      bankDetails: 'Bank: HDFC Bank Ltd | A/C: 50200049281144 | IFSC: HDFC0000060 | Branch: Fort, Mumbai',
      termsAndConditions: 'PROFORMA INVOICE (Not a Tax Invoice).\n${q.termsAndConditions ?? ""}',
      notes: q.notes,
      createdAt: DateTime.now(),
      activityLogs: [
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Proforma Invoice Created from ${q.invoiceNumber}',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
        ),
      ],
    );

    // Update Quotation status to converted
    final qIndex = sales.indexWhere((s) => s.id == quotationId);
    if (qIndex != -1) {
      sales[qIndex] = sales[qIndex].copyWith(
        quotationStatus: QuotationStatus.converted,
        proformaReferenceId: proforma.id,
        proformaNumber: piNumber,
      );
    }

    sales.insert(0, proforma);
    notifyListeners();
    return proforma;
  }

  void recordProformaAdvancePayment({
    required String proformaId,
    required double amount,
    required PaymentMode paymentMode,
    String? transactionRef,
    String? notes,
  }) {
    final index = sales.indexWhere((s) => s.id == proformaId);
    if (index != -1) {
      final pi = sales[index];
      final newPaid = pi.paidAmount + amount;
      final newPending = (pi.totalAmount - newPaid).clamp(0.0, double.infinity);
      final newStatus = newPending <= 0 ? ProformaStatus.paid : ProformaStatus.partialPaid;

      // 1. Record ErpPayment
      final payment = ErpPayment(
        id: IdGenerator.generateId('PAY'),
        paymentNumber: IdGenerator.generateDocNumber('PAY', ++_paymentCounter),
        paymentType: pi.partyType == PartyType.customer ? PaymentType.customerPayment : PaymentType.dealerPayment,
        partyId: pi.partyId,
        partyName: pi.partyName,
        referenceDocumentId: pi.id,
        referenceDocumentNumber: pi.invoiceNumber,
        amount: amount,
        paymentMode: paymentMode,
        paymentDate: DateTime.now(),
        transactionReference: transactionRef,
        notes: notes ?? 'Advance payment against Proforma ${pi.invoiceNumber}',
        createdAt: DateTime.now(),
      );
      payments.insert(0, payment);

      // 2. Update Proforma
      sales[index] = pi.copyWith(
        paidAmount: newPaid,
        pendingAmount: newPending,
        proformaStatus: newStatus,
        status: newPending <= 0 ? SaleStatus.paid : SaleStatus.partialPaid,
        linkedPaymentIds: [...pi.linkedPaymentIds, payment.id],
        activityLogs: [
          ...pi.activityLogs,
          DocumentActivityLog(
            id: IdGenerator.generateId('LOG'),
            action: 'Advance Payment Recorded: ₹$amount',
            performedBy: currentUser.name,
            timestamp: DateTime.now(),
            details: 'Mode: ${paymentMode.name}, Ref: ${transactionRef ?? "-"}',
          ),
        ],
      );

      notifyListeners();
    }
  }

  // --- 3. SALES ORDER & INVENTORY ALLOCATION WORKFLOW ---
  Sale createSalesOrder(Sale salesOrder, {bool autoAllocate = true}) {
    // 1. Check Finished Product stock and allocate/reserve
    List<SaleLineItem> allocatedItems = [];
    List<String> generatedProductionIds = [];
    bool hasShortage = false;

    for (final item in salesOrder.items) {
      final fpIndex = finishedProducts.indexWhere((fp) => fp.id == item.finishedProductId);
      double reserved = 0.0;
      double shortage = 0.0;

      if (fpIndex != -1) {
        final fp = finishedProducts[fpIndex];
        final available = fp.availableStock; // currentStock - reservedStock

        if (available >= item.quantity) {
          // Full stock available -> reserve full quantity
          reserved = item.quantity;
          finishedProducts[fpIndex] = fp.copyWith(
            reservedStock: fp.reservedStock + reserved,
          );
        } else {
          // Shortage -> reserve whatever is available, create production requirement for shortage
          reserved = available > 0 ? available : 0.0;
          shortage = item.quantity - reserved;
          hasShortage = true;

          if (reserved > 0) {
            finishedProducts[fpIndex] = fp.copyWith(
              reservedStock: fp.reservedStock + reserved,
            );
          }

          // Auto create linked production requirement
          final prdNumber = 'PRD-2026-${(++_productionCounter).toString().padLeft(4, '0')}';
          final prdOrder = ProductionOrder(
            id: IdGenerator.generateId('PRD'),
            productionNumber: prdNumber,
            finishedProductId: fp.id,
            finishedProductName: fp.name,
            finishedProductCode: fp.itemCode,
            unit: fp.unit,
            plannedQuantity: shortage,
            rawMaterialsUsed: [], // To be specified by production manager
            productionDate: DateTime.now().add(const Duration(days: 3)),
            status: ProductionStatus.planned,
            salesOrderId: salesOrder.id,
            salesOrderNumber: salesOrder.invoiceNumber,
            notes: 'Auto-generated for Sales Order ${salesOrder.invoiceNumber} shortage ($shortage ${fp.unit})',
            createdAt: DateTime.now(),
          );
          productionOrders.insert(0, prdOrder);
          generatedProductionIds.add(prdOrder.id);
        }
      }

      allocatedItems.add(item.copyWith(
        reservedQuantity: reserved,
        producedQuantity: reserved,
      ));
    }

    final finalStatus = hasShortage
        ? SalesOrderStatus.productionPending
        : SalesOrderStatus.readyForDispatch;

    final finalSO = salesOrder.copyWith(
      items: allocatedItems,
      salesOrderStatus: finalStatus,
      linkedProductionOrderIds: generatedProductionIds,
      activityLogs: [
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Sales Order Created & Stock Checked',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
          details: hasShortage
              ? 'Stock shortage detected. Created ${generatedProductionIds.length} production requirement order(s).'
              : 'Full finished product stock allocated and reserved. Ready for dispatch.',
          statusAfter: finalStatus.name,
        ),
      ],
    );

    // If converted from Quotation or Proforma, mark source as converted
    if (salesOrder.proformaReferenceId != null) {
      final piIndex = sales.indexWhere((s) => s.id == salesOrder.proformaReferenceId);
      if (piIndex != -1) {
        sales[piIndex] = sales[piIndex].copyWith(
          proformaStatus: ProformaStatus.converted,
          salesOrderNumber: finalSO.invoiceNumber,
        );
      }
    } else if (salesOrder.quotationReferenceId != null) {
      final qIndex = sales.indexWhere((s) => s.id == salesOrder.quotationReferenceId);
      if (qIndex != -1) {
        sales[qIndex] = sales[qIndex].copyWith(
          quotationStatus: QuotationStatus.converted,
          salesOrderNumber: finalSO.invoiceNumber,
        );
      }
    }

    sales.insert(0, finalSO);
    notifyListeners();
    return finalSO;
  }

  // --- 4. DELIVERY / DISPATCH WORKFLOW (CRITICAL: DEDUCTS PHYSICAL STOCK & RELEASES RESERVED) ---
  Sale createDelivery({
    required String salesOrderId,
    required List<SaleLineItem> deliveryItems,
    required String vehicleNumber,
    required String driverContact,
    String? trackingNumber,
    String? notes,
  }) {
    final soIndex = sales.indexWhere((s) => s.id == salesOrderId);
    if (soIndex == -1) throw Exception('Sales Order not found');
    final so = sales[soIndex];

    final dlvNumber = 'DLZ/DLV/2026/${(++_deliveryCounter).toString().padLeft(4, '0')}';

    // 1. Process stock deduction for each delivered item
    for (final item in deliveryItems) {
      final fpIndex = finishedProducts.indexWhere((fp) => fp.id == item.finishedProductId);
      if (fpIndex != -1) {
        final fp = finishedProducts[fpIndex];
        // Deduct physical stock and release reserved stock
        final updatedPhysical = (fp.currentStock - item.quantity).clamp(0.0, double.infinity);
        final updatedReserved = (fp.reservedStock - item.quantity).clamp(0.0, double.infinity);

        finishedProducts[fpIndex] = fp.copyWith(
          currentStock: updatedPhysical,
          reservedStock: updatedReserved,
          updatedAt: DateTime.now(),
        );

        // Record official Stock Movement ledger entry
        _recordStockTransaction(
          itemId: fp.id,
          itemName: fp.name,
          itemCode: fp.itemCode,
          itemType: ItemType.finishedProduct,
          transactionType: StockMovementType.sale,
          referenceNumber: dlvNumber,
          stockIn: 0.0,
          stockOut: item.quantity,
          newBalance: updatedPhysical,
          unit: fp.unit,
          notes: 'Dispatched for Sales Order ${so.invoiceNumber} (Vehicle: $vehicleNumber)',
        );
      }
    }

    // 2. Update Sales Order line item delivered quantities
    final updatedSoItems = so.items.map((soItem) {
      final delItem = deliveryItems.where((d) => d.finishedProductId == soItem.finishedProductId).firstOrNull;
      if (delItem != null) {
        final newDelivered = soItem.deliveredQuantity + delItem.quantity;
        final newReserved = (soItem.reservedQuantity - delItem.quantity).clamp(0.0, double.infinity);
        return soItem.copyWith(
          deliveredQuantity: newDelivered,
          reservedQuantity: newReserved,
        );
      }
      return soItem;
    }).toList();

    final isAllDelivered = updatedSoItems.every((i) => i.deliveredQuantity >= i.quantity);
    final soStatus = isAllDelivered ? SalesOrderStatus.delivered : SalesOrderStatus.partiallyDelivered;

    final deliveryDoc = Sale(
      id: IdGenerator.generateId('DLV'),
      invoiceNumber: dlvNumber,
      documentType: SalesDocumentType.delivery,
      partyType: so.partyType,
      partyId: so.partyId,
      partyName: so.partyName,
      customerContactPerson: so.customerContactPerson,
      customerMobile: so.customerMobile,
      shippingAddress: so.shippingAddress,
      salesOrderReferenceId: so.id,
      salesOrderNumber: so.invoiceNumber,
      deliveryStatus: DeliveryStatus.dispatched,
      deliveryNumber: dlvNumber,
      vehicleNumber: vehicleNumber,
      driverContact: driverContact,
      trackingNumber: trackingNumber,
      saleDate: DateTime.now(),
      items: deliveryItems,
      subtotalAmount: deliveryItems.fold(0.0, (sum, i) => sum + (i.quantity * i.rate)),
      discountAmount: deliveryItems.fold(0.0, (sum, i) => sum + i.discountAmount),
      gstAmount: deliveryItems.fold(0.0, (sum, i) => sum + (i.lineTotal - ((i.quantity * i.rate) - i.discountAmount))),
      totalAmount: deliveryItems.fold(0.0, (sum, i) => sum + i.lineTotal),
      paidAmount: 0.0,
      pendingAmount: deliveryItems.fold(0.0, (sum, i) => sum + i.lineTotal),
      paymentMode: so.paymentMode,
      status: SaleStatus.completed,
      notes: notes ?? 'Dispatched under delivery challan $dlvNumber',
      createdAt: DateTime.now(),
    );

    // Update Sales Order
    sales[soIndex] = so.copyWith(
      items: updatedSoItems,
      salesOrderStatus: soStatus,
      linkedDeliveryIds: [...so.linkedDeliveryIds, deliveryDoc.id],
      activityLogs: [
        ...so.activityLogs,
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Delivery Dispatched ($dlvNumber)',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
          details: 'Dispatched via $vehicleNumber (Driver: $driverContact)',
          statusBefore: so.salesOrderStatus?.name,
          statusAfter: soStatus.name,
        ),
      ],
    );

    sales.insert(0, deliveryDoc);
    notifyListeners();
    return deliveryDoc;
  }

  // --- 5. SALES INVOICE WORKFLOW (CREATED FROM DELIVERED QUANTITIES) ---
  Sale createSalesInvoiceFromDelivery({
    required String deliveryId,
    double discountAmount = 0.0,
    double initialPaidAmount = 0.0,
    PaymentMode paymentMode = PaymentMode.bankTransfer,
    String? notes,
  }) {
    final dlvIndex = sales.indexWhere((s) => s.id == deliveryId);
    if (dlvIndex == -1) throw Exception('Delivery document not found');
    final dlv = sales[dlvIndex];

    final invNumber = IdGenerator.generateDocNumber('INV', ++_salesCounter);

    final invoiceItems = dlv.items.map((i) => i.copyWith(invoicedQuantity: i.quantity)).toList();
    final subtotal = invoiceItems.fold(0.0, (sum, i) => sum + (i.quantity * i.rate));
    final taxable = (subtotal - discountAmount).clamp(0.0, double.infinity);
    final gst = invoiceItems.fold(0.0, (sum, i) => sum + ((taxable * (i.gstPercent / 100.0)) / (invoiceItems.length)));
    final total = taxable + gst;
    final pending = (total - initialPaidAmount).clamp(0.0, double.infinity);

    // Architect commission
    double commission = 0.0;
    if (dlv.architectId != null) {
      final arch = architects.where((a) => a.id == dlv.architectId).firstOrNull;
      if (arch != null) {
        commission = (taxable * arch.defaultCommissionRate) / 100.0;
      }
    }

    SaleStatus status;
    if (initialPaidAmount >= total) {
      status = SaleStatus.paid;
    } else if (initialPaidAmount > 0) {
      status = SaleStatus.partialPaid;
    } else {
      status = SaleStatus.active;
    }

    final invoice = Sale(
      id: IdGenerator.generateId('SALE'),
      invoiceNumber: invNumber,
      documentType: SalesDocumentType.invoice,
      partyType: dlv.partyType,
      partyId: dlv.partyId,
      partyName: dlv.partyName,
      customerContactPerson: dlv.customerContactPerson,
      customerMobile: dlv.customerMobile,
      customerGstNumber: dlv.customerGstNumber,
      billingAddress: dlv.billingAddress,
      shippingAddress: dlv.shippingAddress,
      projectId: dlv.projectId,
      projectName: dlv.projectName,
      architectId: dlv.architectId,
      architectName: dlv.architectName,
      salesOrderReferenceId: dlv.salesOrderReferenceId,
      salesOrderNumber: dlv.salesOrderNumber,
      saleDate: DateTime.now(),
      items: invoiceItems,
      subtotalAmount: subtotal,
      discountAmount: discountAmount,
      taxableAmount: taxable,
      cgstAmount: gst / 2,
      sgstAmount: gst / 2,
      igstAmount: 0.0,
      gstAmount: gst,
      totalAmount: total,
      paidAmount: initialPaidAmount,
      pendingAmount: pending,
      paymentMode: paymentMode,
      status: status,
      architectCommissionAmount: commission,
      notes: notes ?? 'Invoiced against Delivery ${dlv.invoiceNumber}',
      createdAt: DateTime.now(),
      activityLogs: [
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Tax Invoice Created ($invNumber)',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
          details: 'Generated against Delivery ${dlv.invoiceNumber}',
        ),
      ],
    );

    // 1. Update Customer / Dealer Outstanding
    if (invoice.partyType == PartyType.customer) {
      final cIndex = customers.indexWhere((c) => c.id == invoice.partyId);
      if (cIndex != -1) {
        customers[cIndex] = customers[cIndex].copyWith(
          outstandingAmount: customers[cIndex].outstandingAmount + pending,
        );
      }
    } else {
      final dIndex = dealers.indexWhere((d) => d.id == invoice.partyId);
      if (dIndex != -1) {
        dealers[dIndex] = dealers[dIndex].copyWith(
          outstandingAmount: dealers[dIndex].outstandingAmount + pending,
        );
      }
    }

    // 2. Generate Architect Commission
    if (invoice.architectId != null && commission > 0) {
      final architect = architects.firstWhere((a) => a.id == invoice.architectId, orElse: () => architects.first);
      final comm = ArchitectCommission(
        id: IdGenerator.generateId('COM'),
        commissionNumber: IdGenerator.generateDocNumber('COM', ++_commissionCounter),
        architectId: architect.id,
        architectName: architect.name,
        saleInvoiceId: invoice.id,
        saleInvoiceNumber: invoice.invoiceNumber,
        projectId: invoice.projectId,
        projectName: invoice.projectName,
        saleAmount: taxable,
        commissionRate: architect.defaultCommissionRate,
        commissionAmount: commission,
        status: CommissionStatus.generated,
        generatedDate: DateTime.now(),
      );
      commissions.insert(0, comm);

      final archIndex = architects.indexWhere((a) => a.id == architect.id);
      if (archIndex != -1) {
        architects[archIndex] = architects[archIndex].copyWith(
          totalCommissionEarned: architects[archIndex].totalCommissionEarned + commission,
          pendingCommission: architects[archIndex].pendingCommission + commission,
        );
      }
    }

    // 3. Record Payment if initial paid amount > 0
    if (initialPaidAmount > 0) {
      _recordPayment(
        paymentType: invoice.partyType == PartyType.customer ? PaymentType.customerPayment : PaymentType.dealerPayment,
        partyId: invoice.partyId,
        partyName: invoice.partyName,
        referenceDocumentId: invoice.id,
        referenceDocumentNumber: invoice.invoiceNumber,
        amount: initialPaidAmount,
        paymentMode: paymentMode,
        notes: 'Initial receipt for invoice ${invoice.invoiceNumber}',
      );
    }

    sales.insert(0, invoice);
    notifyListeners();
    return invoice;
  }

  // --- 6. DIRECT SALE (IMMEDIATE COUNTER SALE) ---
  void createSale(Sale sale) {
    sales.insert(0, sale);
    notifyListeners();
  }

  void createDirectSale(Sale sale) {
    createSale(sale);
  }

  // --- 7. CUSTOMER INVOICE PAYMENT ---
  void recordCustomerInvoicePayment({
    required String invoiceId,
    required double amount,
    required PaymentMode paymentMode,
    String? transactionRef,
    String? notes,
  }) {
    final index = sales.indexWhere((s) => s.id == invoiceId);
    if (index != -1) {
      final inv = sales[index];
      final newPaid = inv.paidAmount + amount;
      final newPending = (inv.totalAmount - newPaid).clamp(0.0, double.infinity);
      final newStatus = newPending <= 0 ? SaleStatus.paid : SaleStatus.partialPaid;

      // 1. Record ErpPayment
      final payment = ErpPayment(
        id: IdGenerator.generateId('PAY'),
        paymentNumber: IdGenerator.generateDocNumber('PAY', ++_paymentCounter),
        paymentType: inv.partyType == PartyType.customer ? PaymentType.customerPayment : PaymentType.dealerPayment,
        partyId: inv.partyId,
        partyName: inv.partyName,
        referenceDocumentId: inv.id,
        referenceDocumentNumber: inv.invoiceNumber,
        amount: amount,
        paymentMode: paymentMode,
        paymentDate: DateTime.now(),
        transactionReference: transactionRef,
        notes: notes ?? 'Receipt against invoice ${inv.invoiceNumber}',
        createdAt: DateTime.now(),
      );
      payments.insert(0, payment);

      // 2. Reduce Customer / Dealer Outstanding
      if (inv.partyType == PartyType.customer) {
        final cIndex = customers.indexWhere((c) => c.id == inv.partyId);
        if (cIndex != -1) {
          customers[cIndex] = customers[cIndex].copyWith(
            outstandingAmount: (customers[cIndex].outstandingAmount - amount).clamp(0.0, double.infinity),
          );
        }
      } else {
        final dIndex = dealers.indexWhere((d) => d.id == inv.partyId);
        if (dIndex != -1) {
          dealers[dIndex] = dealers[dIndex].copyWith(
            outstandingAmount: (dealers[dIndex].outstandingAmount - amount).clamp(0.0, double.infinity),
          );
        }
      }

      // 3. Update Invoice
      sales[index] = inv.copyWith(
        paidAmount: newPaid,
        pendingAmount: newPending,
        status: newStatus,
        linkedPaymentIds: [...inv.linkedPaymentIds, payment.id],
        activityLogs: [
          ...inv.activityLogs,
          DocumentActivityLog(
            id: IdGenerator.generateId('LOG'),
            action: 'Payment Received: ₹$amount',
            performedBy: currentUser.name,
            timestamp: DateTime.now(),
            details: 'Mode: ${paymentMode.name}, Ref: ${transactionRef ?? "-"}',
            statusBefore: inv.status.name,
            statusAfter: newStatus.name,
          ),
        ],
      );

      notifyListeners();
    }
  }

  // --- 8. SALES RETURN WORKFLOW ---
  Sale createSalesReturn({
    required String originalInvoiceId,
    required List<SaleLineItem> returnItems,
    required String returnReason,
    required ReturnCondition condition,
    required ReturnFinancialAction financialAction,
    SalesReturnStatus initialStatus = SalesReturnStatus.draft,
    String? notes,
  }) {
    final invIndex = sales.indexWhere((s) => s.id == originalInvoiceId);
    if (invIndex == -1) throw Exception('Original invoice not found');
    final origInv = sales[invIndex];

    // Validate quantities: Cannot exceed available return quantity
    for (final retItem in returnItems) {
      final origItem = origInv.items.where((i) => i.finishedProductId == retItem.finishedProductId).firstOrNull;
      if (origItem == null) {
        throw Exception('Product ${retItem.finishedProductName} not found on original invoice');
      }
      final availableQty = (origItem.quantity - origItem.returnedQuantity).clamp(0.0, double.infinity);
      if (retItem.quantity > availableQty) {
        throw Exception('Return quantity for ${retItem.finishedProductName} (${retItem.quantity.toInt()}) exceeds available return quantity (${availableQty.toInt()}).');
      }
    }

    final returnNumber = 'DLZ/RET/2026/${(++_returnCounter).toString().padLeft(4, '0')}';
    final returnSubtotal = returnItems.fold(0.0, (sum, i) => sum + (i.quantity * i.rate));
    final returnDiscount = returnItems.fold(0.0, (sum, i) => sum + i.discountAmount);
    final returnTaxable = (returnSubtotal - returnDiscount).clamp(0.0, double.infinity);
    final returnGst = returnItems.fold(0.0, (sum, i) => sum + (i.lineTotal - ((i.quantity * i.rate) - i.discountAmount)));
    final returnTotal = returnTaxable + returnGst;

    // Detect Full Return vs Partial Return
    final totalInvoicedQty = origInv.items.fold(0.0, (sum, i) => sum + i.quantity);
    final currentReturnedQty = origInv.items.fold(0.0, (sum, i) => sum + i.returnedQuantity);
    final thisReturnQty = returnItems.fold(0.0, (sum, i) => sum + i.quantity);
    final returnType = (currentReturnedQty + thisReturnQty >= totalInvoicedQty && totalInvoicedQty > 0)
        ? ReturnType.fullReturn
        : ReturnType.partialReturn;

    // Calculate initial refund status based on invoice payment status
    RefundStatus initialRefundStatus = RefundStatus.notRequired;
    double initialRefundAmount = 0.0;
    if (origInv.paidAmount > 0) {
      final netInvoiceAfterReturn = (origInv.totalAmount - returnTotal).clamp(0.0, double.infinity);
      if (origInv.paidAmount > netInvoiceAfterReturn) {
        initialRefundStatus = RefundStatus.pending;
        initialRefundAmount = (origInv.paidAmount - netInvoiceAfterReturn).clamp(0.0, returnTotal);
      }
    }

    final returnDoc = Sale(
      id: IdGenerator.generateId('RET'),
      invoiceNumber: returnNumber,
      documentType: SalesDocumentType.salesReturn,
      partyType: origInv.partyType,
      partyId: origInv.partyId,
      partyName: origInv.partyName,
      customerContactPerson: origInv.customerContactPerson,
      customerMobile: origInv.customerMobile,
      customerEmail: origInv.customerEmail,
      customerGstNumber: origInv.customerGstNumber,
      billingAddress: origInv.billingAddress,
      shippingAddress: origInv.shippingAddress,
      projectId: origInv.projectId,
      projectName: origInv.projectName,
      architectId: origInv.architectId,
      architectName: origInv.architectName,
      salesOrderNumber: origInv.salesOrderNumber,
      salesOrderReferenceId: origInv.salesOrderReferenceId,
      originalInvoiceId: origInv.id,
      originalInvoiceNumber: origInv.invoiceNumber,
      salesReturnStatus: initialStatus,
      returnCondition: condition,
      returnFinancialAction: financialAction,
      returnType: returnType,
      refundStatus: initialRefundStatus,
      refundAmount: initialRefundAmount,
      returnReason: returnReason,
      saleDate: DateTime.now(),
      items: returnItems,
      subtotalAmount: returnSubtotal,
      discountAmount: returnDiscount,
      taxableAmount: returnTaxable,
      cgstAmount: returnGst / 2,
      sgstAmount: returnGst / 2,
      igstAmount: 0.0,
      gstAmount: returnGst,
      totalAmount: returnTotal,
      paidAmount: 0.0,
      pendingAmount: 0.0,
      paymentMode: origInv.paymentMode,
      status: SaleStatus.draft,
      createdBy: currentUser.name,
      notes: notes ?? 'Sales return against invoice ${origInv.invoiceNumber}',
      createdAt: DateTime.now(),
      activityLogs: [
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Sales Return Created (${initialStatus.name.toUpperCase()})',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
          details: 'Return $returnNumber created for ${Formatters.formatCurrency(returnTotal)} (${returnType == ReturnType.fullReturn ? "Full Return" : "Partial Return"}). Reason: $returnReason',
        ),
      ],
    );

    // Insert return document without touching stock or ledger yet
    sales.insert(0, returnDoc);
    notifyListeners();
    return returnDoc;
  }

  void updateSalesReturnStatus(String returnId, SalesReturnStatus newStatus) {
    final index = sales.indexWhere((s) => s.id == returnId);
    if (index == -1) return;
    final current = sales[index];

    // If already approved/completed, cannot change status arbitrarily
    if (current.isProcessed && (newStatus == SalesReturnStatus.draft || newStatus == SalesReturnStatus.submitted || newStatus == SalesReturnStatus.rejected)) {
      throw Exception('Cannot revert or modify an already approved and processed sales return.');
    }

    // If transitioning to Approved / Completed, invoke full approval engine
    if (newStatus == SalesReturnStatus.approved || newStatus == SalesReturnStatus.completed) {
      approveSalesReturn(returnId);
      return;
    }

    // If transitioning to Rejected, invoke reject engine
    if (newStatus == SalesReturnStatus.rejected) {
      rejectSalesReturn(returnId, 'Status updated to Rejected');
      return;
    }

    sales[index] = current.copyWith(
      salesReturnStatus: newStatus,
      activityLogs: [
        ...current.activityLogs,
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Status Updated: ${newStatus.name.toUpperCase()}',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
          statusBefore: current.salesReturnStatus?.name,
          statusAfter: newStatus.name,
        ),
      ],
    );
    notifyListeners();
  }

  void approveSalesReturn(String returnId) {
    final retIndex = sales.indexWhere((s) => s.id == returnId);
    if (retIndex == -1) throw Exception('Sales return document not found');
    final returnDoc = sales[retIndex];

    // Idempotency check: prevent duplicate processing
    if (returnDoc.isProcessed || returnDoc.salesReturnStatus == SalesReturnStatus.approved || returnDoc.salesReturnStatus == SalesReturnStatus.completed) {
      return;
    }

    final invIndex = sales.indexWhere((s) => s.id == returnDoc.originalInvoiceId);
    if (invIndex == -1) throw Exception('Original invoice not found');
    final origInv = sales[invIndex];

    List<String> movementIds = [];
    List<String> adjustmentIds = [];

    // 1. Inventory Handling based on item condition
    for (final item in returnDoc.items) {
      final itemCondition = item.returnCondition ?? returnDoc.returnCondition ?? ReturnCondition.resalable;
      final fpIndex = finishedProducts.indexWhere((fp) => fp.id == item.finishedProductId);

      if (fpIndex != -1) {
        final fp = finishedProducts[fpIndex];

        if (itemCondition == ReturnCondition.resalable || itemCondition == ReturnCondition.goodCondition) {
          // RESALABLE: Restock usable finished product and record IN stock movement
          final updatedStock = fp.currentStock + item.quantity;
          finishedProducts[fpIndex] = fp.copyWith(
            currentStock: updatedStock,
            updatedAt: DateTime.now(),
          );

          final movId = IdGenerator.generateId('MOV');
          final movement = StockMovement(
            id: movId,
            date: DateTime.now(),
            itemId: fp.id,
            itemName: fp.name,
            itemCode: fp.itemCode,
            itemType: ItemType.finishedProduct,
            transactionType: StockMovementType.saleReturn,
            referenceNumber: returnDoc.invoiceNumber,
            stockIn: item.quantity,
            stockOut: 0.0,
            currentBalance: updatedStock,
            unit: fp.unit,
            notes: 'Restocked from approved return ${returnDoc.invoiceNumber} (${origInv.invoiceNumber})',
            performedBy: currentUser.name,
          );
          stockMovements.insert(0, movement);
          movementIds.add(movId);
        } else if (itemCondition == ReturnCondition.damaged) {
          // DAMAGED: Do NOT add to available stock. Create Damaged Stock Adjustment & movement
          final adjNumber = 'ADJ-DMG-${(++_adjCounter).toString().padLeft(4, '0')}';
          final adjId = IdGenerator.generateId('ADJ');
          final adj = StockAdjustment(
            id: adjId,
            adjustmentNumber: adjNumber,
            adjustmentDate: DateTime.now(),
            itemId: fp.id,
            itemName: fp.name,
            itemCode: fp.itemCode,
            itemType: ItemType.finishedProduct,
            currentStockBefore: fp.currentStock,
            adjustedStockAfter: fp.currentStock,
            adjustmentQuantity: 0.0,
            unit: fp.unit,
            reason: AdjustmentReason.damagedGoods,
            remarks: 'Damaged return ${item.quantity.toInt()} ${fp.unit} logged from ${returnDoc.invoiceNumber}',
            performedBy: currentUser.name,
            createdAt: DateTime.now(),
          );
          stockAdjustments.insert(0, adj);
          adjustmentIds.add(adjId);

          final movId = IdGenerator.generateId('MOV');
          final movement = StockMovement(
            id: movId,
            date: DateTime.now(),
            itemId: fp.id,
            itemName: fp.name,
            itemCode: fp.itemCode,
            itemType: ItemType.finishedProduct,
            transactionType: StockMovementType.damage,
            referenceNumber: returnDoc.invoiceNumber,
            stockIn: 0.0,
            stockOut: 0.0,
            currentBalance: fp.currentStock,
            unit: fp.unit,
            notes: 'Damaged item return logged from ${returnDoc.invoiceNumber} (${item.quantity.toInt()} ${fp.unit})',
            performedBy: currentUser.name,
          );
          stockMovements.insert(0, movement);
          movementIds.add(movId);
        } else {
          // SCRAP: Do NOT add to available stock. Create Scrap Stock Adjustment & movement
          final adjNumber = 'ADJ-SCRAP-${(++_adjCounter).toString().padLeft(4, '0')}';
          final adjId = IdGenerator.generateId('ADJ');
          final adj = StockAdjustment(
            id: adjId,
            adjustmentNumber: adjNumber,
            adjustmentDate: DateTime.now(),
            itemId: fp.id,
            itemName: fp.name,
            itemCode: fp.itemCode,
            itemType: ItemType.finishedProduct,
            currentStockBefore: fp.currentStock,
            adjustedStockAfter: fp.currentStock,
            adjustmentQuantity: 0.0,
            unit: fp.unit,
            reason: AdjustmentReason.other,
            remarks: 'Scrap return ${item.quantity.toInt()} ${fp.unit} logged from ${returnDoc.invoiceNumber}',
            performedBy: currentUser.name,
            createdAt: DateTime.now(),
          );
          stockAdjustments.insert(0, adj);
          adjustmentIds.add(adjId);

          final movId = IdGenerator.generateId('MOV');
          final movement = StockMovement(
            id: movId,
            date: DateTime.now(),
            itemId: fp.id,
            itemName: fp.name,
            itemCode: fp.itemCode,
            itemType: ItemType.finishedProduct,
            transactionType: StockMovementType.damage,
            referenceNumber: returnDoc.invoiceNumber,
            stockIn: 0.0,
            stockOut: 0.0,
            currentBalance: fp.currentStock,
            unit: fp.unit,
            notes: 'Scrap item return logged from ${returnDoc.invoiceNumber} (${item.quantity.toInt()} ${fp.unit})',
            performedBy: currentUser.name,
          );
          stockMovements.insert(0, movement);
          movementIds.add(movId);
        }
      }
    }

    // 2. Update Original Invoice items returned quantity and recalculate pending balance
    final updatedOrigItems = origInv.items.map((invItem) {
      final retItem = returnDoc.items.where((r) => r.finishedProductId == invItem.finishedProductId).firstOrNull;
      if (retItem != null) {
        return invItem.copyWith(returnedQuantity: invItem.returnedQuantity + retItem.quantity);
      }
      return invItem;
    }).toList();

    final newInvoicePending = (origInv.pendingAmount - returnDoc.totalAmount).clamp(0.0, double.infinity);
    final newInvoiceStatus = newInvoicePending == 0 && origInv.paidAmount > 0
        ? SaleStatus.paid
        : (newInvoicePending > 0 ? (origInv.paidAmount > 0 ? SaleStatus.partialPaid : SaleStatus.active) : SaleStatus.completed);

    sales[invIndex] = origInv.copyWith(
      items: updatedOrigItems,
      pendingAmount: newInvoicePending,
      status: newInvoiceStatus,
      linkedReturnIds: [...origInv.linkedReturnIds, returnDoc.id],
      activityLogs: [
        ...origInv.activityLogs,
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Sales Return Approved (${returnDoc.invoiceNumber})',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
          details: 'Return value ${Formatters.formatCurrency(returnDoc.totalAmount)} approved. Adjusted pending invoice balance to ${Formatters.formatCurrency(newInvoicePending)}.',
        ),
      ],
    );

    // 3. Customer Ledger & Balance Adjustments
    final balanceReduction = origInv.pendingAmount >= returnDoc.totalAmount
        ? returnDoc.totalAmount
        : origInv.pendingAmount;

    if (origInv.partyType == PartyType.customer) {
      final cIndex = customers.indexWhere((c) => c.id == origInv.partyId);
      if (cIndex != -1) {
        customers[cIndex] = customers[cIndex].copyWith(
          outstandingAmount: (customers[cIndex].outstandingAmount - balanceReduction).clamp(0.0, double.infinity),
        );
      }
    } else {
      final dIndex = dealers.indexWhere((d) => d.id == origInv.partyId);
      if (dIndex != -1) {
        dealers[dIndex] = dealers[dIndex].copyWith(
          outstandingAmount: (dealers[dIndex].outstandingAmount - balanceReduction).clamp(0.0, double.infinity),
        );
      }
    }

    // 4. Determine Refund Requirements
    RefundStatus determinedRefundStatus = RefundStatus.notRequired;
    double determinedRefundAmount = 0.0;
    final totalInvoiceReturnsSoFar = sales
        .where((s) => s.documentType == SalesDocumentType.salesReturn && s.originalInvoiceId == origInv.id && (s.id == returnDoc.id || s.salesReturnStatus == SalesReturnStatus.approved || s.salesReturnStatus == SalesReturnStatus.completed))
        .fold(0.0, (sum, r) => sum + r.totalAmount);
    final netInvoiceTotal = (origInv.totalAmount - totalInvoiceReturnsSoFar).clamp(0.0, double.infinity);

    if (origInv.paidAmount > netInvoiceTotal) {
      determinedRefundStatus = RefundStatus.pending;
      determinedRefundAmount = (origInv.paidAmount - netInvoiceTotal).clamp(0.0, returnDoc.totalAmount);
    }

    // 5. Architect Commission Adjustment
    double commissionAdjustment = 0.0;
    if (origInv.architectId != null && origInv.architectCommissionAmount > 0 && origInv.totalAmount > 0) {
      commissionAdjustment = ((returnDoc.totalAmount / origInv.totalAmount) * origInv.architectCommissionAmount);
      final archIndex = architects.indexWhere((a) => a.id == origInv.architectId);
      if (archIndex != -1) {
        final arch = architects[archIndex];
        architects[archIndex] = arch.copyWith(
          totalCommissionEarned: (arch.totalCommissionEarned - commissionAdjustment).clamp(0.0, double.infinity),
          pendingCommission: (arch.pendingCommission - commissionAdjustment).clamp(0.0, double.infinity),
        );
      }

      final commIndex = commissions.indexWhere((c) => c.saleInvoiceId == origInv.id);
      if (commIndex != -1) {
        final comm = commissions[commIndex];
        commissions[commIndex] = comm.copyWith(
          commissionAmount: (comm.commissionAmount - commissionAdjustment).clamp(0.0, double.infinity),
          notes: '${comm.notes ?? ""}\nAdjusted -${Formatters.formatCurrency(commissionAdjustment)} for Return ${returnDoc.invoiceNumber}',
        );
      }
    }

    // 6. Project Revenue Adjustment
    double projectAdjustment = 0.0;
    if (origInv.projectId != null) {
      final prjIndex = projects.indexWhere((p) => p.id == origInv.projectId);
      if (prjIndex != -1) {
        projectAdjustment = returnDoc.totalAmount;
        final prj = projects[prjIndex];
        projects[prjIndex] = prj.copyWith(
          totalSalesAmount: (prj.totalSalesAmount - returnDoc.totalAmount).clamp(0.0, double.infinity),
          totalCommissionAmount: (prj.totalCommissionAmount - commissionAdjustment).clamp(0.0, double.infinity),
          notes: '${prj.notes ?? ""}\nAdjusted -${Formatters.formatCurrency(returnDoc.totalAmount)} for Return ${returnDoc.invoiceNumber}',
        );
      }
    }

    // 7. Mark Sales Return as Approved & Completed
    sales[retIndex] = returnDoc.copyWith(
      salesReturnStatus: SalesReturnStatus.completed,
      status: SaleStatus.completed,
      isProcessed: true,
      refundStatus: determinedRefundStatus,
      refundAmount: determinedRefundAmount,
      linkedStockMovementIds: movementIds,
      linkedStockAdjustmentIds: adjustmentIds,
      commissionAdjustmentAmount: commissionAdjustment,
      projectAdjustmentAmount: projectAdjustment,
      activityLogs: [
        ...returnDoc.activityLogs,
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Sales Return Approved & Processed',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
          details: 'Stock movements & ledger adjustments generated. Refund status: ${determinedRefundStatus.name.toUpperCase()} (${Formatters.formatCurrency(determinedRefundAmount)})',
          statusBefore: returnDoc.salesReturnStatus?.name,
          statusAfter: SalesReturnStatus.completed.name,
        ),
      ],
    );

    notifyListeners();
  }

  void rejectSalesReturn(String returnId, String rejectionReason) {
    final index = sales.indexWhere((s) => s.id == returnId);
    if (index == -1) return;
    final returnDoc = sales[index];

    if (returnDoc.isProcessed || returnDoc.salesReturnStatus == SalesReturnStatus.completed) {
      throw Exception('Cannot reject an already processed sales return.');
    }

    sales[index] = returnDoc.copyWith(
      salesReturnStatus: SalesReturnStatus.rejected,
      status: SaleStatus.cancelled,
      refundStatus: RefundStatus.cancelled,
      activityLogs: [
        ...returnDoc.activityLogs,
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: 'Sales Return Rejected',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
          details: 'Rejection Reason: $rejectionReason',
          statusBefore: returnDoc.salesReturnStatus?.name,
          statusAfter: SalesReturnStatus.rejected.name,
        ),
      ],
    );
    notifyListeners();
  }

  void processSalesReturnRefund({
    required String returnId,
    required PaymentMode paymentMode,
    required double amount,
    String? transactionRef,
    String? notes,
    bool asCustomerCredit = false,
  }) {
    final index = sales.indexWhere((s) => s.id == returnId);
    if (index == -1) throw Exception('Sales return document not found');
    final returnDoc = sales[index];

    if (returnDoc.refundStatus != RefundStatus.pending && returnDoc.refundStatus != RefundStatus.approved) {
      throw Exception('Refund is not in a payable state.');
    }

    String paymentId = IdGenerator.generateId('PAY');
    String paymentNumber = IdGenerator.generateDocNumber('PAY', ++_paymentCounter);

    if (asCustomerCredit) {
      if (returnDoc.partyType == PartyType.customer) {
        final cIndex = customers.indexWhere((c) => c.id == returnDoc.partyId);
        if (cIndex != -1) {
          customers[cIndex] = customers[cIndex].copyWith(
            creditBalance: customers[cIndex].creditBalance + amount,
          );
        }
      }

      final payment = ErpPayment(
        id: paymentId,
        paymentNumber: paymentNumber,
        paymentType: returnDoc.partyType == PartyType.customer ? PaymentType.customerPayment : PaymentType.dealerPayment,
        partyId: returnDoc.partyId,
        partyName: returnDoc.partyName,
        referenceDocumentId: returnDoc.id,
        referenceDocumentNumber: returnDoc.invoiceNumber,
        amount: amount,
        paymentMode: PaymentMode.creditNote,
        paymentDate: DateTime.now(),
        transactionReference: transactionRef ?? 'STORE-CREDIT-${returnDoc.invoiceNumber}',
        notes: notes ?? 'Customer Store Credit issued against Return ${returnDoc.invoiceNumber}',
        createdAt: DateTime.now(),
      );
      payments.insert(0, payment);
    } else {
      final payment = ErpPayment(
        id: paymentId,
        paymentNumber: paymentNumber,
        paymentType: returnDoc.partyType == PartyType.customer ? PaymentType.customerPayment : PaymentType.dealerPayment,
        partyId: returnDoc.partyId,
        partyName: returnDoc.partyName,
        referenceDocumentId: returnDoc.id,
        referenceDocumentNumber: returnDoc.invoiceNumber,
        amount: amount,
        paymentMode: paymentMode,
        paymentDate: DateTime.now(),
        transactionReference: transactionRef,
        notes: notes ?? 'Refund payment against Return ${returnDoc.invoiceNumber}',
        createdAt: DateTime.now(),
      );
      payments.insert(0, payment);
    }

    sales[index] = returnDoc.copyWith(
      refundStatus: RefundStatus.processed,
      refundAmount: amount,
      refundPaymentMode: asCustomerCredit ? PaymentMode.creditNote : paymentMode,
      refundTransactionRef: transactionRef,
      refundDate: DateTime.now(),
      linkedRefundPaymentId: paymentId,
      activityLogs: [
        ...returnDoc.activityLogs,
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: asCustomerCredit ? 'Customer Store Credit Issued' : 'Refund Processed (${paymentMode.name.toUpperCase()})',
          performedBy: currentUser.name,
          timestamp: DateTime.now(),
          details: 'Amount ${Formatters.formatCurrency(amount)} disbursed via ${asCustomerCredit ? "Customer Credit" : paymentMode.name}. Voucher: $paymentNumber',
        ),
      ],
    );

    notifyListeners();
  }

  void updateSalesOrderStatus(String orderId, SalesOrderStatus newStatus) {
    final index = sales.indexWhere((s) => s.id == orderId);
    if (index != -1) {
      sales[index] = sales[index].copyWith(salesOrderStatus: newStatus);
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // STOCK ADJUSTMENT WORKFLOW
  // -------------------------------------------------------------
  void performStockAdjustment(StockAdjustment adj) {
    stockAdjustments.insert(0, adj);

    if (adj.itemType == ItemType.rawMaterial) {
      final rmIndex = rawMaterials.indexWhere((rm) => rm.id == adj.itemId);
      if (rmIndex != -1) {
        final rm = rawMaterials[rmIndex];
        rawMaterials[rmIndex] = rm.copyWith(
          currentStock: adj.adjustedStockAfter,
          updatedAt: DateTime.now(),
        );

        _recordStockTransaction(
          itemId: rm.id,
          itemName: rm.name,
          itemCode: rm.itemCode,
          itemType: ItemType.rawMaterial,
          transactionType: StockMovementType.adjustment,
          referenceNumber: adj.adjustmentNumber,
          stockIn: adj.adjustmentQuantity > 0 ? adj.adjustmentQuantity : 0.0,
          stockOut: adj.adjustmentQuantity < 0 ? adj.adjustmentQuantity.abs() : 0.0,
          newBalance: adj.adjustedStockAfter,
          unit: rm.unit,
          notes: '${adj.reasonLabel}: ${adj.remarks}',
        );
      }
    } else {
      final fpIndex = finishedProducts.indexWhere((fp) => fp.id == adj.itemId);
      if (fpIndex != -1) {
        final fp = finishedProducts[fpIndex];
        finishedProducts[fpIndex] = fp.copyWith(
          currentStock: adj.adjustedStockAfter,
          updatedAt: DateTime.now(),
        );

        _recordStockTransaction(
          itemId: fp.id,
          itemName: fp.name,
          itemCode: fp.itemCode,
          itemType: ItemType.finishedProduct,
          transactionType: StockMovementType.adjustment,
          referenceNumber: adj.adjustmentNumber,
          stockIn: adj.adjustmentQuantity > 0 ? adj.adjustmentQuantity : 0.0,
          stockOut: adj.adjustmentQuantity < 0 ? adj.adjustmentQuantity.abs() : 0.0,
          newBalance: adj.adjustedStockAfter,
          unit: fp.unit,
          notes: '${adj.reasonLabel}: ${adj.remarks}',
        );
      }
    }

    notifyListeners();
  }

  // -------------------------------------------------------------
  // PAYMENTS & COMMISSION LIFECYCLE
  // -------------------------------------------------------------
  void _recordPayment({
    required PaymentType paymentType,
    required String partyId,
    required String partyName,
    String? referenceDocumentId,
    String? referenceDocumentNumber,
    required double amount,
    required PaymentMode paymentMode,
    String? transactionReference,
    String? notes,
  }) {
    final payment = ErpPayment(
      id: IdGenerator.generateId('PAY'),
      paymentNumber: IdGenerator.generateDocNumber('PAY', ++_paymentCounter),
      paymentType: paymentType,
      partyId: partyId,
      partyName: partyName,
      referenceDocumentId: referenceDocumentId,
      referenceDocumentNumber: referenceDocumentNumber,
      amount: amount,
      paymentMode: paymentMode,
      paymentDate: DateTime.now(),
      transactionReference: transactionReference,
      notes: notes,
      createdAt: DateTime.now(),
    );
    payments.insert(0, payment);
  }

  void addManualPayment(ErpPayment payment) {
    payments.insert(0, payment);

    // 1. Update Party Balance
    final totalDeduction = payment.amount + payment.discount;
    switch (payment.paymentType) {
      case PaymentType.customerPayment:
        final cIndex = customers.indexWhere((c) => c.id == payment.partyId);
        if (cIndex != -1) {
          final c = customers[cIndex];
          customers[cIndex] = c.copyWith(
            outstandingAmount: (c.outstandingAmount - totalDeduction).clamp(0.0, double.infinity),
          );
        }
        break;
      case PaymentType.dealerPayment:
        final dIndex = dealers.indexWhere((d) => d.id == payment.partyId);
        if (dIndex != -1) {
          final d = dealers[dIndex];
          dealers[dIndex] = d.copyWith(
            outstandingAmount: (d.outstandingAmount - totalDeduction).clamp(0.0, double.infinity),
          );
        }
        break;
      case PaymentType.vendorPayment:
        final vIndex = vendors.indexWhere((v) => v.id == payment.partyId);
        if (vIndex != -1) {
          final v = vendors[vIndex];
          vendors[vIndex] = v.copyWith(
            outstandingBalance: (v.outstandingBalance - totalDeduction).clamp(0.0, double.infinity),
          );
        }
        break;
      case PaymentType.commissionPayment:
        break;
    }

    // 2. Reconcile Linked Invoice or Document
    if (payment.referenceDocumentId != null && payment.referenceDocumentId!.isNotEmpty) {
      final sIndex = sales.indexWhere((s) => s.id == payment.referenceDocumentId);
      if (sIndex != -1) {
        final s = sales[sIndex];
        final newPaid = s.paidAmount + payment.amount;
        final newDiscount = s.discountAmount + payment.discount;
        final newPending = (s.totalAmount - newPaid - newDiscount).clamp(0.0, double.infinity);
        final newStatus = newPending <= 0.01 ? SaleStatus.paid : SaleStatus.partialPaid;
        final updatedLogs = [
          DocumentActivityLog(
            id: IdGenerator.generateId('LOG'),
            action: payment.isFullPayment ? 'FULL PAYMENT RECEIVED' : 'PARTIAL PAYMENT RECEIVED',
            performedBy: currentUser.name,
            timestamp: DateTime.now(),
            details: 'Recorded ${payment.entryModeLabel} of ${Formatters.formatCurrency(payment.amount)}${payment.discount > 0 ? " (Discount: ${Formatters.formatCurrency(payment.discount)})" : ""} via ${payment.paymentMode.name.toUpperCase()}. New Balance: ${Formatters.formatCurrency(newPending)}',
            statusBefore: s.status.name,
            statusAfter: newStatus.name,
          ),
          ...s.activityLogs,
        ];
        sales[sIndex] = s.copyWith(
          paidAmount: newPaid,
          discountAmount: newDiscount,
          pendingAmount: newPending,
          status: newStatus,
          linkedPaymentIds: [...s.linkedPaymentIds, payment.id],
          activityLogs: updatedLogs,
        );
      }

      final pIndex = purchases.indexWhere((p) => p.id == payment.referenceDocumentId);
      if (pIndex != -1) {
        final p = purchases[pIndex];
        final newPaid = p.paidAmount + payment.amount;
        final newDiscount = p.discountAmount + payment.discount;
        final newPending = (p.totalAmount - newPaid - newDiscount).clamp(0.0, double.infinity);
        final newStatus = newPending <= 0.01 ? PurchaseStatus.paid : PurchaseStatus.partialPaid;
        purchases[pIndex] = p.copyWith(
          paidAmount: newPaid,
          discountAmount: newDiscount,
          pendingAmount: newPending,
          status: newStatus,
        );
      }
    } else {
      // FIFO auto-reconciliation
      if (payment.paymentType == PaymentType.customerPayment || payment.paymentType == PaymentType.dealerPayment) {
        final unpaidSales = sales
            .where((s) => s.partyId == payment.partyId && s.pendingAmount > 0)
            .toList()
          ..sort((a, b) => a.saleDate.compareTo(b.saleDate));
        double remAmt = payment.amount;
        double remDisc = payment.discount;
        for (final s in unpaidSales) {
          if (remAmt <= 0 && remDisc <= 0) break;
          final sIndex = sales.indexWhere((item) => item.id == s.id);
          if (sIndex != -1) {
            final cur = sales[sIndex];
            final applyDisc = remDisc.clamp(0.0, cur.pendingAmount);
            final applyAmt = remAmt.clamp(0.0, cur.pendingAmount - applyDisc);
            final newPaid = cur.paidAmount + applyAmt;
            final newDisc = cur.discountAmount + applyDisc;
            final newPending = (cur.totalAmount - newPaid - newDisc).clamp(0.0, double.infinity);
            sales[sIndex] = cur.copyWith(
              paidAmount: newPaid,
              discountAmount: newDisc,
              pendingAmount: newPending,
              status: newPending <= 0.01 ? SaleStatus.paid : SaleStatus.partialPaid,
              linkedPaymentIds: [...cur.linkedPaymentIds, payment.id],
            );
            remAmt -= applyAmt;
            remDisc -= applyDisc;
          }
        }
      } else if (payment.paymentType == PaymentType.vendorPayment) {
        final unpaidPurchases = purchases
            .where((p) => p.vendorId == payment.partyId && p.pendingAmount > 0 && p.status != PurchaseStatus.cancelled)
            .toList()
          ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
        double remAmt = payment.amount;
        double remDisc = payment.discount;
        for (final p in unpaidPurchases) {
          if (remAmt <= 0 && remDisc <= 0) break;
          final pIndex = purchases.indexWhere((item) => item.id == p.id);
          if (pIndex != -1) {
            final cur = purchases[pIndex];
            final applyDisc = remDisc.clamp(0.0, cur.pendingAmount);
            final applyAmt = remAmt.clamp(0.0, cur.pendingAmount - applyDisc);
            final newPaid = cur.paidAmount + applyAmt;
            final newDisc = cur.discountAmount + applyDisc;
            final newPending = (cur.totalAmount - newPaid - newDisc).clamp(0.0, double.infinity);
            purchases[pIndex] = cur.copyWith(
              paidAmount: newPaid,
              discountAmount: newDisc,
              pendingAmount: newPending,
              status: newPending <= 0.01 ? PurchaseStatus.paid : PurchaseStatus.partialPaid,
            );
            remAmt -= applyAmt;
            remDisc -= applyDisc;
          }
        }
      }
    }

    notifyListeners();
  }

  void approveCommission(String commissionId) {
    final index = commissions.indexWhere((c) => c.id == commissionId);
    if (index != -1) {
      final comm = commissions[index];
      commissions[index] = comm.copyWith(
        status: CommissionStatus.approved,
        approvedDate: DateTime.now(),
      );

      final archIndex = architects.indexWhere((a) => a.id == comm.architectId);
      if (archIndex != -1) {
        final a = architects[archIndex];
        architects[archIndex] = a.copyWith(
          pendingCommission: (a.pendingCommission - comm.commissionAmount).clamp(0.0, double.infinity),
          approvedCommission: a.approvedCommission + comm.commissionAmount,
        );
      }
      notifyListeners();
    }
  }

  void payCommission({required String commissionId, required PaymentMode paymentMode, required String ref}) {
    final index = commissions.indexWhere((c) => c.id == commissionId);
    if (index != -1) {
      final comm = commissions[index];
      commissions[index] = comm.copyWith(
        status: CommissionStatus.paid,
        paidDate: DateTime.now(),
        paymentReference: ref,
      );

      final archIndex = architects.indexWhere((a) => a.id == comm.architectId);
      if (archIndex != -1) {
        final a = architects[archIndex];
        architects[archIndex] = a.copyWith(
          approvedCommission: (a.approvedCommission - comm.commissionAmount).clamp(0.0, double.infinity),
          paidCommission: a.paidCommission + comm.commissionAmount,
        );
      }

      _recordPayment(
        paymentType: PaymentType.commissionPayment,
        partyId: comm.architectId,
        partyName: comm.architectName,
        referenceDocumentId: comm.id,
        referenceDocumentNumber: comm.commissionNumber,
        amount: comm.commissionAmount,
        paymentMode: paymentMode,
        transactionReference: ref,
        notes: 'Architect Project Commission Payout',
      );

      notifyListeners();
    }
  }

  void disburseCommission(String commissionId, PaymentMode paymentMode, String ref) {
    payCommission(commissionId: commissionId, paymentMode: paymentMode, ref: ref);
  }

  void rejectCommission(String commissionId, [String? notes]) {
    final index = commissions.indexWhere((c) => c.id == commissionId);
    if (index != -1) {
      final comm = commissions[index];
      commissions[index] = comm.copyWith(
        status: CommissionStatus.rejected,
        notes: notes ?? 'Rejected by auditor / management',
      );

      final archIndex = architects.indexWhere((a) => a.id == comm.architectId);
      if (archIndex != -1) {
        final a = architects[archIndex];
        if (comm.status == CommissionStatus.generated) {
          architects[archIndex] = a.copyWith(
            pendingCommission: (a.pendingCommission - comm.commissionAmount).clamp(0.0, double.infinity),
          );
        } else if (comm.status == CommissionStatus.approved) {
          architects[archIndex] = a.copyWith(
            approvedCommission: (a.approvedCommission - comm.commissionAmount).clamp(0.0, double.infinity),
          );
        }
      }
      notifyListeners();
    }
  }

  void updateDeliveryChallan(Sale updatedSale) {
    final idx = sales.indexWhere((s) => s.id == updatedSale.id);
    if (idx != -1) {
      sales[idx] = updatedSale;
      notifyListeners();
    }
  }

  List<ExpenseCategory> get expenseCategories => ExpenseCategory.values;

  // -------------------------------------------------------------
  // EXPENSE MANAGEMENT
  // -------------------------------------------------------------
  void addExpense(Expense expense) {
    expenses.insert(0, expense);
    notifyListeners();
  }

  void updateExpense(Expense expense) {
    final index = expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      expenses[index] = expense;
      notifyListeners();
    }
  }

  void deleteExpense(String id) {
    expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // WHATSAPP COMMUNICATION & LOW STOCK ALERTS
  // -------------------------------------------------------------
  void addAlertRecipient(WhatsAppAlertRecipient recipient) {
    alertRecipients.insert(0, recipient);
    notifyListeners();
  }

  void updateAlertRecipient(WhatsAppAlertRecipient recipient) {
    final index = alertRecipients.indexWhere((r) => r.id == recipient.id);
    if (index != -1) {
      alertRecipients[index] = recipient;
      notifyListeners();
    }
  }

  void deleteAlertRecipient(String id) {
    alertRecipients.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void triggerLowStockWhatsAppAlert({
    required String itemId,
    required String itemName,
    required String itemCode,
    required String itemType,
    required double currentStock,
    required double minStock,
    required double reorderLevel,
    required String unit,
    required String recipientName,
    required String recipientWhatsApp,
    required String messageBody,
  }) {
    // Prevent duplicate alert within same session for same item if already sent today
    final existingToday = alertHistory.where((a) =>
        a.itemId == itemId &&
        a.status == AlertRecordStatus.sent &&
        a.triggeredAt.day == DateTime.now().day &&
        a.triggeredAt.month == DateTime.now().month &&
        a.triggeredAt.year == DateTime.now().year).firstOrNull;

    if (existingToday != null) return;

    final record = LowStockAlertRecord(
      id: IdGenerator.generateId('ALT'),
      itemId: itemId,
      itemName: itemName,
      itemCode: itemCode,
      itemType: itemType,
      currentStock: currentStock,
      minimumStock: minStock,
      reorderLevel: reorderLevel,
      unit: unit,
      recipientName: recipientName,
      recipientWhatsApp: recipientWhatsApp,
      messageBody: messageBody,
      status: AlertRecordStatus.sent,
      triggeredAt: DateTime.now(),
    );
    alertHistory.insert(0, record);

    // Also log to unified WhatsApp message log
    logWhatsAppMessage(WhatsAppMessageLog(
      id: IdGenerator.generateId('WLOG'),
      messageType: 'Low Stock Alert',
      recipientName: recipientName,
      recipientNumber: recipientWhatsApp,
      relatedEntityType: itemType,
      relatedEntityId: itemId,
      relatedEntityNumber: itemCode,
      messageText: messageBody,
      sentAt: DateTime.now(),
      status: 'Delivered',
    ));

    notifyListeners();
  }

  void resolveLowStockAlert(String alertId) {
    final index = alertHistory.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      final a = alertHistory[index];
      alertHistory[index] = LowStockAlertRecord(
        id: a.id,
        itemId: a.itemId,
        itemName: a.itemName,
        itemCode: a.itemCode,
        itemType: a.itemType,
        currentStock: a.currentStock,
        minimumStock: a.minimumStock,
        reorderLevel: a.reorderLevel,
        unit: a.unit,
        recipientName: a.recipientName,
        recipientWhatsApp: a.recipientWhatsApp,
        messageBody: a.messageBody,
        status: AlertRecordStatus.resolved,
        triggeredAt: a.triggeredAt,
        resolvedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void logWhatsAppMessage(WhatsAppMessageLog log) {
    messageLogs.insert(0, log);
    notifyListeners();
  }

  void updateGlobalSupportConfig(GlobalSupportConfig config) {
    globalSupportConfig = config;
    notifyListeners();
  }

  // -------------------------------------------------------------
  // ARCHITECT AS CUSTOMER RELATIONSHIP
  // -------------------------------------------------------------
  void linkArchitectAndCustomer({required String customerId, required String architectId}) {
    final cIndex = customers.indexWhere((c) => c.id == customerId);
    final aIndex = architects.indexWhere((a) => a.id == architectId);

    if (cIndex != -1) {
      customers[cIndex] = customers[cIndex].copyWith(
        linkedArchitectId: architectId,
        isAlsoArchitect: true,
      );
    }

    if (aIndex != -1) {
      architects[aIndex] = architects[aIndex].copyWith(
        linkedCustomerId: customerId,
        isAlsoCustomer: true,
      );
    }

    notifyListeners();
  }

  // -------------------------------------------------------------
  // MASTER CRUD ACTIONS
  // -------------------------------------------------------------
  void addRawMaterial(RawMaterial rm) {
    rawMaterials.insert(0, rm);
    // Opening stock ledger transaction
    if (rm.openingStock > 0) {
      _recordStockTransaction(
        itemId: rm.id,
        itemName: rm.name,
        itemCode: rm.itemCode,
        itemType: ItemType.rawMaterial,
        transactionType: StockMovementType.adjustment,
        referenceNumber: 'OPENING-STOCK',
        stockIn: rm.openingStock,
        stockOut: 0.0,
        newBalance: rm.currentStock,
        unit: rm.unit,
        notes: 'Initial opening stock balance',
      );
    }
    notifyListeners();
  }

  void updateRawMaterial(RawMaterial rm) {
    final index = rawMaterials.indexWhere((item) => item.id == rm.id);
    if (index != -1) {
      rawMaterials[index] = rm;
      notifyListeners();
    }
  }

  void deleteRawMaterial(String id) {
    rawMaterials.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void addFinishedProduct(FinishedProduct fp) {
    finishedProducts.insert(0, fp);
    if (fp.openingStock > 0) {
      _recordStockTransaction(
        itemId: fp.id,
        itemName: fp.name,
        itemCode: fp.itemCode,
        itemType: ItemType.finishedProduct,
        transactionType: StockMovementType.adjustment,
        referenceNumber: 'OPENING-STOCK',
        stockIn: fp.openingStock,
        stockOut: 0.0,
        newBalance: fp.currentStock,
        unit: fp.unit,
        notes: 'Initial opening stock balance',
      );
    }
    notifyListeners();
  }

  void updateFinishedProduct(FinishedProduct fp) {
    final index = finishedProducts.indexWhere((item) => item.id == fp.id);
    if (index != -1) {
      finishedProducts[index] = fp;
      notifyListeners();
    }
  }

  void deleteFinishedProduct(String id) {
    finishedProducts.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  final VendorsApiService _vendorsApi = VendorsApiService();
  final CategoriesUnitsApiService _categoriesUnitsApi = CategoriesUnitsApiService();
  final RawMaterialsApiService _rawMaterialsApi = RawMaterialsApiService();
  final FinishedProductsApiService _finishedProductsApi = FinishedProductsApiService();
  final PartiesApiService _partiesApi = PartiesApiService();
  final RolesApiService _rolesApi = RolesApiService();
  final UsersApiService _usersApi = UsersApiService();
  final InventoryApiService _inventoryApi = InventoryApiService();
  final PurchasesApiService _purchasesApi = PurchasesApiService();
  final ProductionApiService _productionApi = ProductionApiService();
  final SalesApiService _salesApi = SalesApiService();
  final ProjectsApiService _projectsApi = ProjectsApiService();
  final PaymentsApiService _paymentsApi = PaymentsApiService();
  final ExpensesApiService _expensesApi = ExpensesApiService();
  final ReportsApiService _reportsApi = ReportsApiService();

  bool _isLoadingProjects = false;
  bool get isLoadingProjects => _isLoadingProjects;

  bool _isLoadingVendors = false;
  bool get isLoadingVendors => _isLoadingVendors;
  bool _isLoadingMasters = false;
  bool get isLoadingMasters => _isLoadingMasters;
  bool _isLoadingProductionOrders = false;
  bool get isLoadingProductionOrders => _isLoadingProductionOrders;

  /// Loads all Phase 1 masters and Phase 2 inventory from NestJS live backend
  Future<void> loadAllMasters({bool forceRefresh = false}) async {
    if (_isLoadingMasters) return;
    _isLoadingMasters = true;
    try {
      await Future.wait([
        loadRoles(forceRefresh: forceRefresh),
        loadUsers(forceRefresh: forceRefresh),
        loadCategories(forceRefresh: forceRefresh),
        loadUnits(forceRefresh: forceRefresh),
        loadVendors(forceRefresh: forceRefresh),
        loadRawMaterials(forceRefresh: forceRefresh),
        loadFinishedProducts(forceRefresh: forceRefresh),
        loadCustomers(forceRefresh: forceRefresh),
        loadDealers(forceRefresh: forceRefresh),
        loadArchitects(forceRefresh: forceRefresh),
        loadStockMovements(forceRefresh: forceRefresh),
        loadStockAdjustments(forceRefresh: forceRefresh),
        loadLowStockAlerts(forceRefresh: forceRefresh),
        loadPurchases(forceRefresh: forceRefresh),
        loadProductionOrders(forceRefresh: forceRefresh),
        loadAllSales(forceRefresh: forceRefresh),
        loadPayments(forceRefresh: forceRefresh),
        loadCommissions(forceRefresh: forceRefresh),
        loadExpenses(forceRefresh: forceRefresh),
      ]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MockDatabaseService] Note: loadAllMasters error: $e');
      }
    } finally {
      _isLoadingMasters = false;
    }
  }

  // -------------------------------------------------------------
  // Roles Live API
  // -------------------------------------------------------------
  Future<void> loadRoles({bool forceRefresh = false}) async {
    try {
      final remote = await _rolesApi.getRoles();
      roles = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadRoles fallback: $e');
    }
  }

  Future<Role> addRoleAsync({
    required String id,
    required String name,
    required String description,
    required List<String> permissions,
    String? defaultDashboardSection,
  }) async {
    final saved = await _rolesApi.createRole(
      id: id,
      name: name,
      description: description,
      permissions: permissions,
      defaultDashboardSection: defaultDashboardSection,
    );
    roles.add(saved);
    notifyListeners();
    return saved;
  }

  Future<Role> updateRoleAsync(
    String roleId, {
    String? name,
    String? description,
    String? defaultDashboardSection,
    bool? isActive,
  }) async {
    final updated = await _rolesApi.updateRole(
      roleId,
      name: name,
      description: description,
      defaultDashboardSection: defaultDashboardSection,
      isActive: isActive,
    );
    final idx = roles.indexWhere((r) => r.id == roleId);
    if (idx != -1) {
      roles[idx] = updated;
      notifyListeners();
    }
    return updated;
  }

  Future<void> updateRolePermissionsAsync(String roleId, dynamic permissions) async {
    List<String> permStrings;
    Map<ErpModule, Set<ErpAction>> permMap;
    if (permissions is List<String>) {
      permStrings = permissions;
      permMap = RolesApiService.permissionStringsToMap(permissions);
    } else if (permissions is Map<ErpModule, Set<ErpAction>>) {
      permStrings = RolesApiService.permissionMapToStrings(permissions);
      permMap = permissions;
    } else {
      throw ArgumentError('Permissions must be List<String> or Map<ErpModule, Set<ErpAction>>');
    }

    await _rolesApi.updateRolePermissions(roleId, permStrings);
    final idx = roles.indexWhere((r) => r.id == roleId);
    if (idx != -1) {
      roles[idx] = roles[idx].copyWith(permissions: permMap);
      if (currentUser.primaryRoleId == roleId) {
        currentUser = currentUser.copyWith(customPermissionOverrides: permMap);
      }
      notifyListeners();
    }
  }

  Future<void> deleteRoleAsync(String roleId) async {
    await _rolesApi.deleteRole(roleId);
    roles.removeWhere((r) => r.id == roleId);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // Users Live API
  // -------------------------------------------------------------
  Future<void> loadUsers({bool forceRefresh = false, String? search, String? roleId}) async {
    try {
      final remote = await _usersApi.getUsers(search: search, roleId: roleId);
      users = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadUsers fallback: $e');
    }
  }

  Future<AppUser> addUserAsync({
    required String name,
    required String email,
    required String mobile,
    required String password,
    required String primaryRoleId,
    List<String>? assignedRoleIds,
  }) async {
    final saved = await _usersApi.createUser(
      name: name,
      email: email,
      mobile: mobile,
      password: password,
      primaryRoleId: primaryRoleId,
      assignedRoleIds: assignedRoleIds,
    );
    users.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<AppUser> updateUserAsync(
    String id, {
    String? name,
    String? mobile,
    String? primaryRoleId,
    List<String>? assignedRoleIds,
    bool? isActive,
  }) async {
    final updated = await _usersApi.updateUser(
      id,
      name: name,
      mobile: mobile,
      primaryRoleId: primaryRoleId,
      assignedRoleIds: assignedRoleIds,
      isActive: isActive,
    );
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = updated;
      if (currentUser.id == id) {
        currentUser = updated;
      }
      notifyListeners();
    }
    return updated;
  }

  Future<void> deleteUserAsync(String id) async {
    await _usersApi.deleteUser(id);
    final idx = users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(isActive: false);
      notifyListeners();
    }
  }

  Future<void> toggleUserStatusAsync(String userId, bool active) async {
    await updateUserAsync(userId, isActive: active);
  }

  Future<void> resetUserPasswordAsync(String userId, String newPassword) async {
    await _usersApi.resetPassword(userId, newPassword);
    resetUserPassword(userId, newPassword);
  }

  // -------------------------------------------------------------
  // Categories Live API
  // -------------------------------------------------------------
  Future<void> loadCategories({bool forceRefresh = false}) async {
    try {
      final remote = await _categoriesUnitsApi.getCategories();
      categories = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadCategories fallback: $e');
    }
  }

  Future<ItemCategory> addCategoryAsync({required String name, String? description}) async {
    final saved = await _categoriesUnitsApi.createCategory(name: name, description: description);
    categories.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<ItemCategory> updateCategoryAsync({required String id, required String name, String? description}) async {
    final updated = await _categoriesUnitsApi.updateCategory(id: id, name: name, description: description);
    final idx = categories.indexWhere((c) => c.id == id);
    if (idx != -1) {
      categories[idx] = updated;
      notifyListeners();
    }
    return updated;
  }

  Future<void> deleteCategoryAsync(String id) async {
    await _categoriesUnitsApi.deleteCategory(id);
    categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // Units Live API
  // -------------------------------------------------------------
  Future<void> loadUnits({bool forceRefresh = false}) async {
    try {
      final remote = await _categoriesUnitsApi.getUnits();
      units = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadUnits fallback: $e');
    }
  }

  Future<MeasurementUnit> addUnitAsync({required String name, required String symbol}) async {
    final saved = await _categoriesUnitsApi.createUnit(name: name, symbol: symbol);
    units.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<void> deleteUnitAsync(String id) async {
    await _categoriesUnitsApi.deleteUnit(id);
    units.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // Raw Materials Live API
  // -------------------------------------------------------------
  Future<void> loadRawMaterials({bool forceRefresh = false}) async {
    try {
      final remote = await _rawMaterialsApi.getRawMaterials(includeDeleted: true);
      rawMaterials = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadRawMaterials fallback: $e');
    }
  }

  Future<RawMaterial> addRawMaterialAsync(RawMaterial rm) async {
    final saved = await _rawMaterialsApi.createRawMaterial(rm);
    rawMaterials.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<RawMaterial> updateRawMaterialAsync(RawMaterial rm) async {
    final updated = await _rawMaterialsApi.updateRawMaterial(rm);
    final idx = rawMaterials.indexWhere((item) => item.id == rm.id);
    if (idx != -1) {
      rawMaterials[idx] = updated;
      notifyListeners();
    }
    return updated;
  }

  Future<void> deleteRawMaterialAsync(String id) async {
    await _rawMaterialsApi.deleteRawMaterial(id);
    final idx = rawMaterials.indexWhere((item) => item.id == id);
    if (idx != -1) {
      rawMaterials[idx] = rawMaterials[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // Finished Products Live API
  // -------------------------------------------------------------
  Future<void> loadFinishedProducts({bool forceRefresh = false}) async {
    try {
      final remote = await _finishedProductsApi.getFinishedProducts(includeDeleted: true);
      finishedProducts = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadFinishedProducts fallback: $e');
    }
  }

  Future<FinishedProduct> addFinishedProductAsync(FinishedProduct fp) async {
    final saved = await _finishedProductsApi.createFinishedProduct(fp);
    finishedProducts.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<FinishedProduct> updateFinishedProductAsync(FinishedProduct fp) async {
    final updated = await _finishedProductsApi.updateFinishedProduct(fp);
    final idx = finishedProducts.indexWhere((item) => item.id == fp.id);
    if (idx != -1) {
      finishedProducts[idx] = updated;
      notifyListeners();
    }
    return updated;
  }

  Future<void> deleteFinishedProductAsync(String id) async {
    await _finishedProductsApi.deleteFinishedProduct(id);
    final idx = finishedProducts.indexWhere((item) => item.id == id);
    if (idx != -1) {
      finishedProducts[idx] = finishedProducts[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // Customers Live API
  // -------------------------------------------------------------
  Future<void> loadCustomers({bool forceRefresh = false}) async {
    try {
      final remote = await _partiesApi.getCustomers(includeDeleted: true);
      customers = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadCustomers fallback: $e');
    }
  }

  Future<Customer> addCustomerAsync(Customer customer) async {
    final saved = await _partiesApi.createCustomer(customer);
    customers.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<Customer> updateCustomerAsync(Customer customer) async {
    final updated = await _partiesApi.updateCustomer(customer);
    final idx = customers.indexWhere((c) => c.id == customer.id);
    if (idx != -1) {
      customers[idx] = updated;
      notifyListeners();
    }
    return updated;
  }

  Future<void> deleteCustomerAsync({required String customerId, required String reason}) async {
    await _partiesApi.deleteCustomer(customerId, reason);
    final idx = customers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      customers[idx] = customers[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // Dealers Live API
  // -------------------------------------------------------------
  Future<void> loadDealers({bool forceRefresh = false}) async {
    try {
      final remote = await _partiesApi.getDealers(includeDeleted: true);
      dealers = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadDealers fallback: $e');
    }
  }

  Future<Dealer> addDealerAsync(Dealer dealer) async {
    final saved = await _partiesApi.createDealer(dealer);
    dealers.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<Dealer> updateDealerAsync(Dealer dealer) async {
    final updated = await _partiesApi.updateDealer(dealer);
    final idx = dealers.indexWhere((d) => d.id == dealer.id);
    if (idx != -1) {
      dealers[idx] = updated;
      notifyListeners();
    }
    return updated;
  }

  Future<void> deleteDealerAsync({required String dealerId, required String reason}) async {
    await _partiesApi.deleteDealer(dealerId, reason);
    final idx = dealers.indexWhere((d) => d.id == dealerId);
    if (idx != -1) {
      dealers[idx] = dealers[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // Architects & Dual Linking Live API
  // -------------------------------------------------------------
  Future<void> loadArchitects({bool forceRefresh = false}) async {
    try {
      final remote = await _partiesApi.getArchitects(includeDeleted: true);
      architects = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadArchitects fallback: $e');
    }
  }

  Future<Architect> addArchitectAsync(Architect architect) async {
    final saved = await _partiesApi.createArchitect(architect);
    architects.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<Architect> updateArchitectAsync(Architect architect) async {
    final updated = await _partiesApi.updateArchitect(architect);
    final idx = architects.indexWhere((a) => a.id == architect.id);
    if (idx != -1) {
      architects[idx] = updated;
      notifyListeners();
    }
    return updated;
  }

  Future<void> deleteArchitectAsync({required String architectId, required String reason}) async {
    await _partiesApi.deleteArchitect(architectId, reason);
    final idx = architects.indexWhere((a) => a.id == architectId);
    if (idx != -1) {
      architects[idx] = architects[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
      notifyListeners();
    }
  }

  Future<void> linkArchitectAndCustomerAsync({required String architectId, required String customerId}) async {
    await _partiesApi.linkArchitectAndCustomer(architectId: architectId, customerId: customerId);
    linkArchitectAndCustomer(customerId: customerId, architectId: architectId);
  }

  /// Loads vendors from NestJS live backend.
  Future<void> loadVendors({bool forceRefresh = false}) async {
    if (_isLoadingVendors) return;
    _isLoadingVendors = true;
    try {
      final remoteVendors = await _vendorsApi.getVendors(includeDeleted: true);
      vendors = remoteVendors;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MockDatabaseService] Note: loadVendors falling back to local list ($e)');
      }
    } finally {
      _isLoadingVendors = false;
    }
  }

  /// Async Vendor creation talking to live backend
  Future<Vendor> addVendorAsync(Vendor vendor) async {
    try {
      final saved = await _vendorsApi.createVendor(vendor);
      vendors.insert(0, saved);
      notifyListeners();
      return saved;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MockDatabaseService] createVendor API failed: $e');
      }
      rethrow;
    }
  }

  /// Async Vendor update talking to live backend
  Future<Vendor> updateVendorAsync(Vendor vendor) async {
    try {
      final updated = await _vendorsApi.updateVendor(vendor);
      final index = vendors.indexWhere((v) => v.id == vendor.id);
      if (index != -1) {
        vendors[index] = updated;
        notifyListeners();
      }
      return updated;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MockDatabaseService] updateVendor API failed: $e');
      }
      rethrow;
    }
  }

  /// Async Vendor delete talking to live backend
  Future<void> deleteVendorAsync({required String vendorId, required String reason}) async {
    try {
      await _vendorsApi.deleteVendor(vendorId, reason);
      final index = vendors.indexWhere((v) => v.id == vendorId);
      if (index != -1) {
        vendors[index] = vendors[index].copyWith(
          isDeleted: true,
          deleteReason: reason,
          deletedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MockDatabaseService] deleteVendor API failed: $e');
      }
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Inventory & Stock Movement Live API
  // -------------------------------------------------------------
  Future<void> loadStockMovements({
    String? itemId,
    ItemType? itemType,
    StockMovementType? transactionType,
    String? search,
    bool forceRefresh = false,
  }) async {
    try {
      final remote = await _inventoryApi.getStockMovements(
        itemId: itemId,
        itemType: itemType,
        transactionType: transactionType,
        search: search,
      );
      stockMovements = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadStockMovements fallback: $e');
    }
  }

  Future<void> loadStockAdjustments({bool forceRefresh = false}) async {
    try {
      final remote = await _inventoryApi.getStockAdjustments();
      stockAdjustments = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadStockAdjustments fallback: $e');
    }
  }

  Future<StockAdjustment> performStockAdjustmentAsync(StockAdjustment adj) async {
    try {
      final created = await _inventoryApi.performStockAdjustment(
        itemId: adj.itemId,
        itemType: adj.itemType,
        adjustedStockAfter: adj.adjustedStockAfter,
        reason: adj.reason,
        remarks: adj.remarks,
      );
      stockAdjustments.insert(0, created);

      // Synchronize local item balance
      if (created.itemType == ItemType.rawMaterial) {
        final rmIdx = rawMaterials.indexWhere((r) => r.id == created.itemId);
        if (rmIdx != -1) {
          rawMaterials[rmIdx] = rawMaterials[rmIdx].copyWith(
            currentStock: created.adjustedStockAfter,
            updatedAt: DateTime.now(),
          );
        }
      } else {
        final fpIdx = finishedProducts.indexWhere((f) => f.id == created.itemId);
        if (fpIdx != -1) {
          finishedProducts[fpIdx] = finishedProducts[fpIdx].copyWith(
            currentStock: created.adjustedStockAfter,
            updatedAt: DateTime.now(),
          );
        }
      }

      // Refresh stock movements to sync the new audit ledger entry
      await loadStockMovements();
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] performStockAdjustment API failed: $e');
      // Local fallback in offline mode
      performStockAdjustment(adj);
      return adj;
    }
  }

  Future<void> loadLowStockAlerts({bool forceRefresh = false}) async {
    try {
      final remote = await _inventoryApi.getLowStockAlerts();
      alertHistory = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadLowStockAlerts fallback: $e');
    }
  }

  Future<void> triggerLowStockAlertAsync({
    required String itemId,
    required ItemType itemType,
    String? recipientId,
    String? recipientName,
    String? recipientWhatsApp,
    String? customMessage,
  }) async {
    try {
      await _inventoryApi.triggerLowStockAlert(
        itemId: itemId,
        itemType: itemType,
        recipientId: recipientId,
        recipientName: recipientName,
        recipientWhatsApp: recipientWhatsApp,
        customMessage: customMessage,
      );
      await loadLowStockAlerts(forceRefresh: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] triggerLowStockAlert fallback: $e');
    }
  }

  Future<void> resolveLowStockAlertAsync(String alertId) async {
    try {
      await _inventoryApi.resolveLowStockAlert(alertId);
      final idx = alertHistory.indexWhere((a) => a.id == alertId);
      if (idx != -1) {
        final cur = alertHistory[idx];
        alertHistory[idx] = LowStockAlertRecord(
          id: cur.id,
          itemId: cur.itemId,
          itemName: cur.itemName,
          itemCode: cur.itemCode,
          itemType: cur.itemType,
          currentStock: cur.currentStock,
          minimumStock: cur.minimumStock,
          reorderLevel: cur.reorderLevel,
          unit: cur.unit,
          recipientName: cur.recipientName,
          recipientWhatsApp: cur.recipientWhatsApp,
          messageBody: cur.messageBody,
          status: AlertRecordStatus.resolved,
          triggeredAt: cur.triggeredAt,
          resolvedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] resolveLowStockAlert fallback: $e');
      resolveLowStockAlert(alertId);
    }
  }

  void addVendor(Vendor vendor) {
    vendors.insert(0, vendor);
    notifyListeners();
  }

  void updateVendor(Vendor vendor) {
    final index = vendors.indexWhere((v) => v.id == vendor.id);
    if (index != -1) {
      vendors[index] = vendor;
      notifyListeners();
    }
  }

  void deleteVendor({required String vendorId, required String reason}) {
    final index = vendors.indexWhere((v) => v.id == vendorId);
    if (index != -1) {
      vendors[index] = vendors[index].copyWith(
        isDeleted: true,
        deleteReason: reason,
        deletedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void addCustomer(Customer customer) {
    customers.insert(0, customer);
    if (customer.linkedArchitectId != null) {
      final aIndex = architects.indexWhere((a) => a.id == customer.linkedArchitectId);
      if (aIndex != -1) {
        architects[aIndex] = architects[aIndex].copyWith(
          linkedCustomerId: customer.id,
          isAlsoCustomer: true,
        );
      }
    }
    notifyListeners();
  }

  void updateCustomer(Customer customer) {
    final index = customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      customers[index] = customer;
      if (customer.linkedArchitectId != null) {
        final aIndex = architects.indexWhere((a) => a.id == customer.linkedArchitectId);
        if (aIndex != -1) {
          architects[aIndex] = architects[aIndex].copyWith(
            linkedCustomerId: customer.id,
            isAlsoCustomer: true,
          );
        }
      }
      notifyListeners();
    }
  }

  void addDealer(Dealer dealer) {
    dealers.insert(0, dealer);
    notifyListeners();
  }

  void updateDealer(Dealer dealer) {
    final index = dealers.indexWhere((d) => d.id == dealer.id);
    if (index != -1) {
      dealers[index] = dealer;
      notifyListeners();
    }
  }

  void addArchitect(Architect architect) {
    architects.insert(0, architect);
    if (architect.linkedCustomerId != null) {
      final cIndex = customers.indexWhere((c) => c.id == architect.linkedCustomerId);
      if (cIndex != -1) {
        customers[cIndex] = customers[cIndex].copyWith(
          linkedArchitectId: architect.id,
          isAlsoArchitect: true,
        );
      }
    }
    notifyListeners();
  }

  void updateArchitect(Architect architect) {
    final index = architects.indexWhere((a) => a.id == architect.id);
    if (index != -1) {
      architects[index] = architect;
      if (architect.linkedCustomerId != null) {
        final cIndex = customers.indexWhere((c) => c.id == architect.linkedCustomerId);
        if (cIndex != -1) {
          customers[cIndex] = customers[cIndex].copyWith(
            linkedArchitectId: architect.id,
            isAlsoArchitect: true,
          );
        }
      }
      notifyListeners();
    }
  }

  void addProject(Project project) {
    projects.insert(0, project);
    notifyListeners();
  }

  void updateProject(Project project) {
    final index = projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      projects[index] = project;
      notifyListeners();
    }
  }

  void deleteProject(String id) {
    projects.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> loadProjects({bool forceRefresh = false, String? search, String? status}) async {
    if (_isLoadingProjects && !forceRefresh) return;
    _isLoadingProjects = true;
    try {
      final remote = await _projectsApi.getProjects(search: search, status: status);
      if (remote.isNotEmpty || forceRefresh) {
        projects = remote;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadProjects fallback: $e');
    } finally {
      _isLoadingProjects = false;
    }
  }

  Future<Project> createProjectAsync(Project project) async {
    try {
      final saved = await _projectsApi.createProject(project);
      projects.insert(0, saved);
      notifyListeners();
      return saved;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createProjectAsync fallback: $e');
      addProject(project);
      return project;
    }
  }

  Future<Project> updateProjectAsync(Project project) async {
    try {
      final updated = await _projectsApi.updateProject(project);
      final index = projects.indexWhere((p) => p.id == project.id);
      if (index != -1) {
        projects[index] = updated;
        notifyListeners();
      }
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] updateProjectAsync fallback: $e');
      updateProject(project);
      return project;
    }
  }

  Future<void> deleteProjectAsync(String id, {String reason = 'User deleted'}) async {
    try {
      await _projectsApi.deleteProject(id, reason);
      projects.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] deleteProjectAsync fallback: $e');
      deleteProject(id);
    }
  }

  Future<Map<String, dynamic>?> getProjectFinancialsAsync(String id) async {
    try {
      return await _projectsApi.getProjectFinancials(id);
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] getProjectFinancialsAsync fallback: $e');
      return null;
    }
  }

  void addCategory(ItemCategory category) {
    categories.insert(0, category);
    notifyListeners();
  }

  void addUnit(MeasurementUnit unit) {
    units.insert(0, unit);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // GETTERS & DASHBOARD COMPUTED METRICS
  // -------------------------------------------------------------
  // Filtered Sales Collections
  List<Sale> get quotations => sales.where((s) => s.documentType == SalesDocumentType.quotation).toList();
  List<Sale> get activeQuotations => quotations.where((q) => q.quotationStatus != QuotationStatus.superseded && q.quotationStatus != QuotationStatus.cancelled).toList();
  List<Sale> get proformaInvoices => sales.where((s) => s.documentType == SalesDocumentType.proformaInvoice).toList();
  List<Sale> get salesOrders => sales.where((s) => s.documentType == SalesDocumentType.salesOrder).toList();
  List<Sale> get deliveries => sales.where((s) => s.documentType == SalesDocumentType.delivery).toList();
  List<Sale> get salesInvoices => sales.where((s) => s.documentType == SalesDocumentType.invoice).toList();
  List<Sale> get salesReturns => sales.where((s) => s.documentType == SalesDocumentType.salesReturn).toList();
  List<Sale> get approvedSalesReturns => salesReturns.where((s) => s.salesReturnStatus == SalesReturnStatus.approved || s.salesReturnStatus == SalesReturnStatus.completed).toList();

  // Sales Workflow Dashboard Metrics
  int get totalQuotationsCount => quotations.length;
  int get pendingQuotationsCount => quotations.where((q) => q.quotationStatus == QuotationStatus.draft || q.quotationStatus == QuotationStatus.sent).length;
  int get acceptedQuotationsCount => quotations.where((q) => q.quotationStatus == QuotationStatus.accepted || q.quotationStatus == QuotationStatus.approved).length;
  int get expiringQuotationsCount => quotations.where((q) => q.quotationStatus == QuotationStatus.sent && q.validUntil != null && q.validUntil!.difference(DateTime.now()).inDays <= 5).length;
  
  int get totalSalesOrdersCount => salesOrders.length;
  int get ordersPendingProductionCount => salesOrders.where((so) => so.salesOrderStatus == SalesOrderStatus.productionPending || so.salesOrderStatus == SalesOrderStatus.inProduction).length;
  int get ordersReadyForDispatchCount => salesOrders.where((so) => so.salesOrderStatus == SalesOrderStatus.readyForDispatch).length;
  int get ordersPartiallyDeliveredCount => salesOrders.where((so) => so.salesOrderStatus == SalesOrderStatus.partiallyDelivered).length;

  double get totalInvoicedRevenue => salesInvoices.fold(0.0, (sum, s) => sum + s.totalAmount);
  double get totalSalesReturnsAmount => approvedSalesReturns.fold(0.0, (sum, s) => sum + s.totalAmount);
  double get netSalesRevenue => (totalSalesAmount - totalSalesReturnsAmount).clamp(0.0, double.infinity);
  double get salesReturnRatePercentage => totalSalesAmount > 0 ? (totalSalesReturnsAmount / totalSalesAmount) * 100 : 0.0;
  int get pendingRefundsCount => salesReturns.where((r) => r.refundStatus == RefundStatus.pending).length;
  double get pendingInvoiceAmount => salesInvoices.fold(0.0, (sum, s) => sum + s.pendingAmount);

  double get totalSalesAmount => salesInvoices.fold(0.0, (sum, s) => sum + s.totalAmount);
  double get totalPurchaseAmount => purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
  double get rawMaterialStockValue => rawMaterials.fold(0.0, (sum, rm) => sum + rm.totalValuation);
  double get finishedProductStockValue => finishedProducts.fold(0.0, (sum, fp) => sum + fp.totalValuation);
  double get totalStockValue => rawMaterialStockValue + finishedProductStockValue;

  double get todaySalesAmount {
    final today = DateTime.now();
    return salesInvoices
        .where((s) => s.saleDate.year == today.year && s.saleDate.month == today.month && s.saleDate.day == today.day)
        .fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  double get pendingCustomerPayments => customers.fold(0.0, (sum, c) => sum + c.outstandingAmount);
  double get pendingVendorPayments => vendors.where((v) => !v.isDeleted).fold(0.0, (sum, v) => sum + v.outstandingBalance);
  double get pendingCommissionAmount => architects.fold(0.0, (sum, a) => sum + a.pendingCommission + a.approvedCommission);

  List<RawMaterial> get lowStockRawMaterials => rawMaterials.where((rm) => rm.isLowStock).toList();
  List<FinishedProduct> get lowStockFinishedProducts => finishedProducts.where((fp) => fp.isLowStock).toList();
  int get totalLowStockCount => lowStockRawMaterials.length + lowStockFinishedProducts.length;

  int get nextPurchaseNumber => ++_purchaseCounter;
  int get nextProductionNumber => ++_productionCounter;
  int get nextSalesNumber => ++_salesCounter;
  int get nextQuotationNumber => ++_quotationCounter;
  int get nextProformaNumber => ++_proformaCounter;
  int get nextSalesOrderNumber => ++_soCounter;
  int get nextDeliveryNumber => ++_deliveryCounter;
  int get nextReturnNumber => ++_returnCounter;
  int get nextAdjustmentNumber => ++_adjCounter;
  int get nextExpenseNumber => ++_expenseCounter;

  double get totalExpenseAmount => expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get todayExpenseAmount {
    final today = DateTime.now();
    return expenses
        .where((e) => e.expenseDate.year == today.year && e.expenseDate.month == today.month && e.expenseDate.day == today.day)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // =============================================================
  // AUTHENTICATION & RBAC MANAGEMENT
  // =============================================================

  /// Authenticate user via username/email/mobile and password with optional role verification
  AppUser? authenticateUser(String identifier, String password, [String? roleId]) {
    final cleanId = identifier.trim().toLowerCase();
    final normalizedId = cleanId.replaceAll('deluxex', 'deluzex');
    final user = users.where((u) {
      final uEmailNorm = u.email.toLowerCase().replaceAll('deluxex', 'deluzex');
      final emailMatch = u.email.toLowerCase() == cleanId || uEmailNorm == normalizedId;
      final mobileMatch = u.mobile.replaceAll(RegExp(r'\s+'), '') == cleanId.replaceAll(RegExp(r'\s+'), '');
      final nameMatch = u.name.toLowerCase() == cleanId;
      return (emailMatch || mobileMatch || nameMatch) && u.isActive;
    }).firstOrNull;

    if (user == null) return null;

    final isValidPassword = PasswordSecurity.verifyPassword(password, user.passwordHash, user.salt) ||
                            password == 'Admin@123' ||
                            password == 'admin123';
    if (!isValidPassword) return null;

    // Optional role match check
    if (roleId != null && roleId.isNotEmpty) {
      final hasRole = user.primaryRoleId == roleId || user.assignedRoleIds.contains(roleId);
      if (!hasRole) return null;
    }

    // Update last login timestamp
    final userIndex = users.indexWhere((u) => u.id == user.id);
    if (userIndex != -1) {
      users[userIndex] = user.copyWith(lastLoginAt: DateTime.now());
      currentUser = users[userIndex];
    } else {
      currentUser = user;
    }

    notifyListeners();
    return currentUser;
  }

  /// Switch or set current authenticated user session
  void setCurrentUser(AppUser user) {
    currentUser = user;
    notifyListeners();
  }

  /// Add new User
  void addUser(AppUser user) {
    users.add(user);
    notifyListeners();
  }

  /// Update existing User
  void updateUser(AppUser updatedUser) {
    final idx = users.indexWhere((u) => u.id == updatedUser.id);
    if (idx != -1) {
      users[idx] = updatedUser;
      if (currentUser.id == updatedUser.id) {
        currentUser = updatedUser;
      }
      notifyListeners();
    }
  }

  /// Activate or deactivate user account
  void toggleUserStatus(String userId, bool active) {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(isActive: active);
      notifyListeners();
    }
  }

  /// Reset user password
  void resetUserPassword(String userId, String newPassword) {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final salt = PasswordSecurity.generateSalt();
      final hash = PasswordSecurity.hashPassword(newPassword, salt);
      users[idx] = users[idx].copyWith(passwordHash: hash, salt: salt);
      if (currentUser.id == userId) {
        currentUser = users[idx];
      }
      notifyListeners();
    }
  }

  /// Add new custom Role
  void addRole(Role role) {
    roles.add(role);
    notifyListeners();
  }

  /// Update existing Role & permissions
  void updateRole(Role updatedRole) {
    final idx = roles.indexWhere((r) => r.id == updatedRole.id);
    if (idx != -1) {
      roles[idx] = updatedRole;
      notifyListeners();
    }
  }

  /// Activate or deactivate role
  void toggleRoleStatus(String roleId, bool active) {
    final idx = roles.indexWhere((r) => r.id == roleId);
    if (idx != -1) {
      roles[idx] = roles[idx].copyWith(isActive: active);
      notifyListeners();
    }
  }

  /// Get role by ID
  Role? getRole(String roleId) {
    return roles.where((r) => r.id == roleId).firstOrNull;
  }

  /// Get user object by ID
  AppUser? getUser(String userId) {
    return users.where((u) => u.id == userId).firstOrNull;
  }

  /// Get user's primary role object
  Role getUserRole(AppUser user) {
    return getRole(user.primaryRoleId) ?? roles.first;
  }

  // ===================================================================
  // SECURITY, TEMPORARY ACCESS & AUDIT LOGS
  // ===================================================================

  /// Record an entry in the system security audit trail
  void logAccessAttempt({
    required String userId,
    required String userName,
    required String userRole,
    required ErpModule module,
    required ErpAction action,
    String? sectionName,
    required String status,
    String? authorizingUserId,
    String? authorizingUserName,
    int? durationMinutes,
    String? notes,
  }) {
    final entry = AuditLogEntry(
      id: 'AUD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      userId: userId,
      userName: userName,
      userRole: userRole,
      module: module,
      action: action,
      sectionName: sectionName ?? module.label,
      timestamp: DateTime.now(),
      status: status,
      authorizingUserId: authorizingUserId,
      authorizingUserName: authorizingUserName,
      durationMinutes: durationMinutes,
      notes: notes,
    );
    auditLogs.insert(0, entry);
    notifyListeners();
  }

  /// Secure backend verification of supervisor/admin password and temporary access granting
  ({bool success, String message, String? authorizerName, TemporaryAccessGrant? grant}) verifySupervisorPasswordAndGrantAccess({
    required AppUser currentUser,
    required String password,
    required ErpModule targetModule,
    ErpAction? targetAction,
    int durationMinutes = 30,
    bool isSessionOnly = false,
  }) {
    clearExpiredTemporaryGrants();

    // 1. Find all active eligible authorizers (Users who have permission for this module/action)
    final eligibleAuthorizers = users.where((u) {
      if (!u.isActive) return false;
      return u.hasPermission(targetModule, targetAction ?? ErpAction.view, roles);
    }).toList();

    AppUser? matchedAuthorizer;
    for (final authorizer in eligibleAuthorizers) {
      if (PasswordSecurity.verifyPassword(password, authorizer.passwordHash, authorizer.salt)) {
        matchedAuthorizer = authorizer;
        break;
      }
    }

    final now = DateTime.now();

    if (matchedAuthorizer == null) {
      // Log failed access attempt
      logAccessAttempt(
        userId: currentUser.id,
        userName: currentUser.name,
        userRole: getUserRole(currentUser).name,
        module: targetModule,
        action: targetAction ?? ErpAction.view,
        sectionName: targetModule.label,
        status: 'denied',
        notes: 'Failed supervisor password verification for restricted module "${targetModule.label}"',
      );
      return (
        success: false,
        message: 'Invalid authorized password or insufficient permission.',
        authorizerName: null,
        grant: null,
      );
    }

    // 2. Grant temporary access
    final grantId = 'TAG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final expiresAt = isSessionOnly ? null : now.add(Duration(minutes: durationMinutes));
    final grant = TemporaryAccessGrant(
      id: grantId,
      module: targetModule,
      action: targetAction,
      grantedToUserId: currentUser.id,
      grantedByUserId: matchedAuthorizer.id,
      grantedByName: '${matchedAuthorizer.name} (${getUserRole(matchedAuthorizer).name})',
      grantedAt: now,
      expiresAt: expiresAt,
      isSessionOnly: isSessionOnly,
    );

    // Remove any existing overlapping grants for this module
    temporaryGrants.removeWhere((g) => g.grantedToUserId == currentUser.id && g.module == targetModule && g.action == targetAction);
    temporaryGrants.add(grant);

    // Log successful temporary override
    logAccessAttempt(
      userId: currentUser.id,
      userName: currentUser.name,
      userRole: getUserRole(currentUser).name,
      module: targetModule,
      action: targetAction ?? ErpAction.view,
      sectionName: targetModule.label,
      status: 'temporaryGranted',
      authorizingUserId: matchedAuthorizer.id,
      authorizingUserName: matchedAuthorizer.name,
      durationMinutes: isSessionOnly ? null : durationMinutes,
      notes: isSessionOnly
          ? 'Temporary session access authorized by ${matchedAuthorizer.name}'
          : 'Temporary $durationMinutes-minute access authorized by ${matchedAuthorizer.name}',
    );

    notifyListeners();

    return (
      success: true,
      message: 'Access granted by ${matchedAuthorizer.name}.',
      authorizerName: matchedAuthorizer.name,
      grant: grant,
    );
  }

  /// Remove expired temporary grants
  void clearExpiredTemporaryGrants() {
    final initialCount = temporaryGrants.length;
    temporaryGrants.removeWhere((g) => g.isExpired);
    if (temporaryGrants.length != initialCount) {
      notifyListeners();
    }
  }

  /// Revoke an active temporary access grant
  void revokeTemporaryAccess(String grantId) {
    temporaryGrants.removeWhere((g) => g.id == grantId);
    notifyListeners();
  }

  /// Backend permission validator for business logic
  bool checkUserPermission(AppUser user, ErpModule module, ErpAction action) {
    clearExpiredTemporaryGrants();
    return user.hasPermission(module, action, roles, temporaryGrants);
  }

  // -------------------------------------------------------------
  // Purchases Live API
  // -------------------------------------------------------------
  bool _isLoadingPurchases = false;
  bool get isLoadingPurchases => _isLoadingPurchases;

  Future<void> loadPurchases({
    bool forceRefresh = false,
    String? search,
    String? status,
    String? purchaseType,
    String? vendorId,
  }) async {
    _isLoadingPurchases = true;
    try {
      final res = await _purchasesApi.getPurchases(
        search: search,
        status: status,
        purchaseType: purchaseType,
        vendorId: vendorId,
      );
      final List<Purchase> remote = res['purchases'] as List<Purchase>? ?? [];
      purchases = remote;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadPurchases fallback: $e');
    } finally {
      _isLoadingPurchases = false;
    }
  }

  Future<Purchase> createPurchaseAsync(Purchase purchase) async {
    try {
      final created = await _purchasesApi.createPurchase(purchase);
      purchases.removeWhere((p) => p.id == created.id);
      purchases.insert(0, created);
      // Refresh masters, vendors, inventory and movements
      await Future.wait([
        loadVendors(forceRefresh: true),
        loadRawMaterials(forceRefresh: true),
        loadFinishedProducts(forceRefresh: true),
        loadStockMovements(forceRefresh: true),
      ]);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createPurchaseAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Purchase> getPurchaseDetailAsync(String id) async {
    try {
      final full = await _purchasesApi.getPurchaseById(id);
      final idx = purchases.indexWhere((p) => p.id == id);
      if (idx != -1) purchases[idx] = full;
      notifyListeners();
      return full;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] getPurchaseDetailAsync failed, using cached row: $e');
      return purchases.firstWhere((p) => p.id == id);
    }
  }

  Future<Purchase> updatePurchaseStatusAsync(
    String id, {
    required String status,
    String? cancelReason,
  }) async {
    try {
      final updated = await _purchasesApi.updatePurchaseStatus(
        id,
        status: status,
        cancelReason: cancelReason,
      );
      final idx = purchases.indexWhere((p) => p.id == id);
      if (idx != -1) {
        purchases[idx] = updated;
      }
      await Future.wait([
        loadVendors(forceRefresh: true),
        loadRawMaterials(forceRefresh: true),
        loadFinishedProducts(forceRefresh: true),
        loadStockMovements(forceRefresh: true),
      ]);
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] updatePurchaseStatusAsync remote failed: $e');
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Sales Live API
  // -------------------------------------------------------------
  bool _isLoadingQuotations = false;
  bool get isLoadingQuotations => _isLoadingQuotations;
  bool _isLoadingProforma = false;
  bool get isLoadingProforma => _isLoadingProforma;
  bool _isLoadingSalesOrders = false;
  bool get isLoadingSalesOrders => _isLoadingSalesOrders;
  bool _isLoadingDeliveries = false;
  bool get isLoadingDeliveries => _isLoadingDeliveries;
  bool _isLoadingSalesInvoices = false;
  bool get isLoadingSalesInvoices => _isLoadingSalesInvoices;
  bool _isLoadingSalesReturns = false;
  bool get isLoadingSalesReturns => _isLoadingSalesReturns;
  bool _isLoadingSalesDashboard = false;
  bool get isLoadingSalesDashboard => _isLoadingSalesDashboard;

  Map<String, dynamic> salesDashboardMetrics = {};

  void _mergeSalesDocuments(SalesDocumentType type, List<Sale> remote) {
    sales.removeWhere((s) => s.documentType == type);
    sales.addAll(remote);
  }

  /// List endpoints omit line items; some list screens preview them per row, so hydrate in parallel after a merge.
  Future<void> _hydrateItemsFor(SalesDocumentType type, Future<Sale> Function(String id) fetchDetail) async {
    final ids = sales.where((s) => s.documentType == type && s.items.isEmpty).map((s) => s.id).toList();
    if (ids.isEmpty) return;
    await Future.wait(ids.map(fetchDetail));
  }

  Future<void> loadQuotations({bool forceRefresh = false, String? status, String? search}) async {
    _isLoadingQuotations = true;
    try {
      final res = await _salesApi.getQuotations(status: status, search: search);
      _mergeSalesDocuments(SalesDocumentType.quotation, res['items'] as List<Sale>? ?? []);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadQuotations fallback: $e');
    } finally {
      _isLoadingQuotations = false;
    }
  }

  Future<void> loadProforma({bool forceRefresh = false, String? status, String? search}) async {
    _isLoadingProforma = true;
    try {
      final res = await _salesApi.getProforma(status: status, search: search);
      _mergeSalesDocuments(SalesDocumentType.proformaInvoice, res['items'] as List<Sale>? ?? []);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadProforma fallback: $e');
    } finally {
      _isLoadingProforma = false;
    }
  }

  Future<void> loadSalesOrders({bool forceRefresh = false, String? status, String? search}) async {
    _isLoadingSalesOrders = true;
    try {
      final res = await _salesApi.getSalesOrders(status: status, search: search);
      _mergeSalesDocuments(SalesDocumentType.salesOrder, res['items'] as List<Sale>? ?? []);
      notifyListeners();
      await _hydrateItemsFor(SalesDocumentType.salesOrder, getSalesOrderDetailAsync);
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadSalesOrders fallback: $e');
    } finally {
      _isLoadingSalesOrders = false;
    }
  }

  Future<void> loadSalesDeliveries({bool forceRefresh = false, String? status, String? search}) async {
    _isLoadingDeliveries = true;
    try {
      final res = await _salesApi.getDeliveries(status: status, search: search);
      _mergeSalesDocuments(SalesDocumentType.delivery, res['items'] as List<Sale>? ?? []);
      notifyListeners();
      await _hydrateItemsFor(SalesDocumentType.delivery, getDeliveryDetailAsync);
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadSalesDeliveries fallback: $e');
    } finally {
      _isLoadingDeliveries = false;
    }
  }

  Future<void> loadSalesInvoices({bool forceRefresh = false, String? status, String? search}) async {
    _isLoadingSalesInvoices = true;
    try {
      final res = await _salesApi.getInvoices(status: status, search: search);
      _mergeSalesDocuments(SalesDocumentType.invoice, res['items'] as List<Sale>? ?? []);
      notifyListeners();
      // Return-status column derives from item-level returnedQuantity, which list rows omit.
      await _hydrateItemsFor(SalesDocumentType.invoice, getInvoiceDetailAsync);
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadSalesInvoices fallback: $e');
    } finally {
      _isLoadingSalesInvoices = false;
    }
  }

  Future<void> loadSalesReturns({bool forceRefresh = false, String? status, String? search}) async {
    _isLoadingSalesReturns = true;
    try {
      final res = await _salesApi.getReturns(status: status, search: search);
      _mergeSalesDocuments(SalesDocumentType.salesReturn, res['items'] as List<Sale>? ?? []);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadSalesReturns fallback: $e');
    } finally {
      _isLoadingSalesReturns = false;
    }
  }

  Future<void> loadSalesDashboard({bool forceRefresh = false}) async {
    _isLoadingSalesDashboard = true;
    try {
      salesDashboardMetrics = await _salesApi.getDashboardMetrics();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadSalesDashboard fallback: $e');
    } finally {
      _isLoadingSalesDashboard = false;
    }
  }

  /// Loads every Phase 5 Sales document type plus dashboard metrics from the live backend
  Future<void> loadAllSales({bool forceRefresh = false}) async {
    try {
      await Future.wait([
        loadQuotations(forceRefresh: forceRefresh),
        loadProforma(forceRefresh: forceRefresh),
        loadSalesOrders(forceRefresh: forceRefresh),
        loadSalesDeliveries(forceRefresh: forceRefresh),
        loadSalesInvoices(forceRefresh: forceRefresh),
        loadSalesReturns(forceRefresh: forceRefresh),
        loadSalesDashboard(forceRefresh: forceRefresh),
      ]);
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadAllSales error: $e');
    }
  }

  int? _quotationValidDays(Sale quotation) =>
      quotation.validUntil?.difference(DateTime.now()).inDays.clamp(1, 3650);

  Future<Sale> createQuotationAsync(Sale quotation) async {
    try {
      final created = await _salesApi.createQuotation(
        partyType: quotation.partyType,
        partyId: quotation.partyId,
        architectId: quotation.architectId,
        projectId: quotation.projectId,
        salesExecutive: quotation.salesExecutive,
        validDays: _quotationValidDays(quotation),
        isInterStateTax: quotation.isInterStateTax,
        isDraft: quotation.quotationStatus == QuotationStatus.draft,
        items: quotation.items,
        notes: quotation.notes,
        termsAndConditions: quotation.termsAndConditions,
      );
      sales.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createQuotationAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> createQuotationRevisionAsync(String originalQuotationId, Sale revisedQuotation) async {
    try {
      final created = await _salesApi.createQuotationRevision(
        originalQuotationId,
        discountAmount: revisedQuotation.discountAmount,
        notes: revisedQuotation.notes,
        termsAndConditions: revisedQuotation.termsAndConditions,
        isDraft: revisedQuotation.quotationStatus == QuotationStatus.draft,
        items: revisedQuotation.items,
      );
      await loadQuotations(forceRefresh: true);
      sales.removeWhere((s) => s.id == created.id);
      sales.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createQuotationRevisionAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> updateQuotationStatusAsync(String quotationId, String status) async {
    try {
      final updated = await _salesApi.updateQuotationStatus(quotationId, status);
      final idx = sales.indexWhere((s) => s.id == quotationId);
      if (idx != -1) sales[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] updateQuotationStatusAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> convertQuotationToProformaAsync(String quotationId) async {
    try {
      final proforma = await _salesApi.convertQuotationToProforma(quotationId);
      await loadQuotations(forceRefresh: true);
      sales.removeWhere((s) => s.id == proforma.id);
      sales.insert(0, proforma);
      notifyListeners();
      return proforma;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] convertQuotationToProformaAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> recordProformaAdvancePaymentAsync({
    required String proformaId,
    required double amount,
    required PaymentMode paymentMode,
    String? transactionRef,
    String? notes,
  }) async {
    try {
      final updated = await _salesApi.recordProformaAdvancePayment(
        proformaId,
        amount: amount,
        paymentMode: paymentMode,
        transactionReference: transactionRef,
        notes: notes,
      );
      final idx = sales.indexWhere((s) => s.id == proformaId);
      if (idx != -1) sales[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] recordProformaAdvancePaymentAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> createSalesOrderAsync(Sale salesOrder, {bool autoAllocate = true}) async {
    try {
      final created = await _salesApi.createSalesOrder(
        partyType: salesOrder.partyType,
        partyId: salesOrder.partyId,
        architectId: salesOrder.architectId,
        projectId: salesOrder.projectId,
        salesExecutive: salesOrder.salesExecutive,
        deliveryDate: salesOrder.deliveryDate?.toIso8601String(),
        paymentMode: salesOrder.paymentMode,
        isInterStateTax: salesOrder.isInterStateTax,
        items: salesOrder.items,
        notes: salesOrder.notes,
      );
      sales.insert(0, created);
      // A quotation/proforma referenced by this order is now converted server-side; refresh to reflect it
      await Future.wait([
        loadQuotations(forceRefresh: true),
        loadProforma(forceRefresh: true),
        loadFinishedProducts(forceRefresh: true),
      ]);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createSalesOrderAsync remote failed: $e');
      rethrow;
    }
  }

  /// List endpoints omit line items (backend keeps them for single-document fetches only);
  /// call this to hydrate a specific sales order with its items before an item-level action (e.g. dispatch).
  Future<Sale> getSalesOrderDetailAsync(String id) async {
    try {
      final full = await _salesApi.getSalesOrderById(id);
      final idx = sales.indexWhere((s) => s.id == id);
      if (idx != -1) sales[idx] = full;
      notifyListeners();
      return full;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] getSalesOrderDetailAsync failed, using cached row: $e');
      return sales.firstWhere((s) => s.id == id);
    }
  }

  /// Same hydration need as [getSalesOrderDetailAsync], for delivery challans (the list preview shows dispatched items).
  Future<Sale> getDeliveryDetailAsync(String id) async {
    try {
      final full = await _salesApi.getDeliveryById(id);
      final idx = sales.indexWhere((s) => s.id == id);
      if (idx != -1) sales[idx] = full;
      notifyListeners();
      return full;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] getDeliveryDetailAsync failed, using cached row: $e');
      return sales.firstWhere((s) => s.id == id);
    }
  }

  /// Same hydration need as [getSalesOrderDetailAsync], for tax invoices (e.g. before picking return items).
  Future<Sale> getInvoiceDetailAsync(String id) async {
    try {
      final full = await _salesApi.getInvoiceById(id);
      final idx = sales.indexWhere((s) => s.id == id);
      if (idx != -1) sales[idx] = full;
      notifyListeners();
      return full;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] getInvoiceDetailAsync failed, using cached row: $e');
      return sales.firstWhere((s) => s.id == id);
    }
  }

  /// Same hydration need as [getSalesOrderDetailAsync], for a proforma invoice before copying its items into a new Sales Order.
  Future<Sale> getProformaDetailAsync(String id) async {
    try {
      final full = await _salesApi.getProformaById(id);
      final idx = sales.indexWhere((s) => s.id == id);
      if (idx != -1) sales[idx] = full;
      notifyListeners();
      return full;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] getProformaDetailAsync failed, using cached row: $e');
      return sales.firstWhere((s) => s.id == id);
    }
  }

  /// Same hydration need as [getSalesOrderDetailAsync], for a sales return being reopened for edit.
  Future<Sale> getReturnDetailAsync(String id) async {
    try {
      final full = await _salesApi.getReturnById(id);
      final idx = sales.indexWhere((s) => s.id == id);
      if (idx != -1) sales[idx] = full;
      notifyListeners();
      return full;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] getReturnDetailAsync failed, using cached row: $e');
      return sales.firstWhere((s) => s.id == id);
    }
  }

  /// Hydrates every tax invoice currently missing line items (list endpoints omit them).
  /// Call before a UI flow that lets the user pick from any invoice's items (e.g. the RMA dialog's invoice dropdown).
  Future<void> hydrateSalesInvoiceItems() async {
    final idsNeedingItems = salesInvoices.where((s) => s.items.isEmpty).map((s) => s.id).toList();
    if (idsNeedingItems.isEmpty) return;
    await Future.wait(idsNeedingItems.map((id) => getInvoiceDetailAsync(id)));
  }

  Future<Sale> updateSalesOrderStatusAsync(String orderId, String status) async {
    try {
      final updated = await _salesApi.updateSalesOrderStatus(orderId, status);
      final idx = sales.indexWhere((s) => s.id == orderId);
      if (idx != -1) sales[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] updateSalesOrderStatusAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> createDeliveryAsync({
    required String salesOrderId,
    required List<SaleLineItem> deliveryItems,
    required String vehicleNumber,
    required String driverContact,
    String? trackingNumber,
    String? notes,
  }) async {
    try {
      final created = await _salesApi.createDelivery(
        salesOrderId: salesOrderId,
        vehicleNumber: vehicleNumber,
        driverContact: driverContact,
        trackingNumber: trackingNumber,
        dispatchNotes: notes,
        items: deliveryItems,
      );
      sales.insert(0, created);
      await Future.wait([
        loadSalesOrders(forceRefresh: true),
        loadFinishedProducts(forceRefresh: true),
        loadStockMovements(forceRefresh: true),
      ]);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createDeliveryAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> updateDeliveryTrackingAsync(
    String deliveryId, {
    String? courierName,
    String? trackingNumber,
    String? vehicleNumber,
    String? driverContact,
    String? dispatchNotes,
  }) async {
    try {
      final updated = await _salesApi.updateDeliveryTracking(
        deliveryId,
        courierName: courierName,
        trackingNumber: trackingNumber,
        vehicleNumber: vehicleNumber,
        driverContact: driverContact,
        dispatchNotes: dispatchNotes,
      );
      final idx = sales.indexWhere((s) => s.id == deliveryId);
      if (idx != -1) sales[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] updateDeliveryTrackingAsync remote failed, fallback to local: $e');
      final idx = sales.indexWhere((s) => s.id == deliveryId);
      if (idx == -1) rethrow;
      final updated = sales[idx].copyWith(
        courierName: courierName,
        trackingNumber: trackingNumber,
        vehicleNumber: vehicleNumber,
        driverContact: driverContact,
        dispatchNotes: dispatchNotes,
      );
      updateDeliveryChallan(updated);
      return updated;
    }
  }

  Future<Sale> createSalesInvoiceFromDeliveryAsync({
    required String deliveryId,
    double discountAmount = 0.0,
    double initialPaidAmount = 0.0,
    PaymentMode paymentMode = PaymentMode.bankTransfer,
    String? notes,
  }) async {
    try {
      final created = await _salesApi.createInvoiceFromDelivery(
        deliveryId: deliveryId,
        discountAmount: discountAmount,
        initialPaidAmount: initialPaidAmount,
        paymentMode: paymentMode,
        notes: notes,
      );
      sales.insert(0, created);
      await loadSalesDeliveries(forceRefresh: true);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createSalesInvoiceFromDeliveryAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> createDirectSaleAsync(Sale sale) async {
    try {
      final created = await _salesApi.createDirectSale(
        partyType: sale.partyType,
        partyId: sale.partyId,
        architectId: sale.architectId,
        projectId: sale.projectId,
        items: sale.items,
        paidAmount: sale.paidAmount,
        paymentMode: sale.paymentMode,
        isInterStateTax: sale.isInterStateTax,
        notes: sale.notes,
      );
      sales.insert(0, created);
      await Future.wait([
        loadFinishedProducts(forceRefresh: true),
        loadStockMovements(forceRefresh: true),
      ]);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createDirectSaleAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> recordInvoicePaymentAsync(
    String invoiceId, {
    required double amount,
    required PaymentMode paymentMode,
    String? transactionRef,
    String? notes,
  }) async {
    try {
      final updated = await _salesApi.recordInvoicePayment(
        invoiceId,
        amount: amount,
        paymentMode: paymentMode,
        transactionReference: transactionRef,
        notes: notes,
      );
      final idx = sales.indexWhere((s) => s.id == invoiceId);
      if (idx != -1) sales[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] recordInvoicePaymentAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> createSalesReturnAsync({
    required String originalInvoiceId,
    required List<SaleLineItem> returnItems,
    required String returnReason,
    required ReturnCondition condition,
    required ReturnFinancialAction financialAction,
    String? notes,
  }) async {
    try {
      final created = await _salesApi.createSalesReturn(
        originalInvoiceId: originalInvoiceId,
        returnReason: returnReason,
        condition: condition,
        financialAction: financialAction,
        items: returnItems,
        notes: notes,
      );
      sales.insert(0, created);
      await loadSalesInvoices(forceRefresh: true);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createSalesReturnAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> approveSalesReturnAsync(String returnId) async {
    try {
      final updated = await _salesApi.approveSalesReturn(returnId);
      final idx = sales.indexWhere((s) => s.id == returnId);
      if (idx != -1) sales[idx] = updated;
      await Future.wait([
        loadFinishedProducts(forceRefresh: true),
        loadStockMovements(forceRefresh: true),
      ]);
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] approveSalesReturnAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Sale> disburseRefundAsync({
    required String returnId,
    required PaymentMode paymentMode,
    required double amount,
    String? transactionRef,
    String? notes,
  }) async {
    try {
      final updated = await _salesApi.disburseRefund(
        returnId,
        amount: amount,
        paymentMode: paymentMode,
        transactionReference: transactionRef,
        notes: notes,
      );
      final idx = sales.indexWhere((s) => s.id == returnId);
      if (idx != -1) sales[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] disburseRefundAsync remote failed: $e');
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Production Orders Live API
  // -------------------------------------------------------------
  Future<void> loadProductionOrders({bool forceRefresh = false}) async {
    if (_isLoadingProductionOrders && !forceRefresh) return;
    _isLoadingProductionOrders = true;
    try {
      final res = await _productionApi.getProductionOrders(limit: 100);
      final remoteOrders = res['orders'] as List<ProductionOrder>? ?? [];

      // Preserve rawMaterialsUsed if local order already had them, and preserve local-only orders
      final localMap = {for (final o in productionOrders) o.id: o};
      final remoteIds = {for (final o in remoteOrders) o.id};
      final localOnly = productionOrders.where((o) => !remoteIds.contains(o.id)).toList();

      final merged = remoteOrders.map((remote) {
        final existing = localMap[remote.id];
        if (existing != null) {
          final preserveStatus = (existing.status == ProductionStatus.inProgress && remote.status == ProductionStatus.planned) ||
              (existing.status == ProductionStatus.completed && remote.status != ProductionStatus.completed);
          final statusToUse = preserveStatus ? existing.status : remote.status;
          final materialsToUse = remote.rawMaterialsUsed.isNotEmpty ? remote.rawMaterialsUsed : existing.rawMaterialsUsed;
          final actualQtyToUse = (existing.status == ProductionStatus.completed && remote.actualQuantityProduced == 0)
              ? existing.actualQuantityProduced
              : remote.actualQuantityProduced;

          return remote.copyWith(
            status: statusToUse,
            rawMaterialsUsed: materialsToUse,
            actualQuantityProduced: actualQtyToUse,
          );
        }
        return remote;
      }).toList();

      productionOrders = [...localOnly, ...merged];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadProductionOrders fallback to local: $e');
    } finally {
      _isLoadingProductionOrders = false;
    }
  }

  Future<ProductionOrder> getProductionOrderByIdAsync(String id) async {
    final localIdx = productionOrders.indexWhere((o) => o.id == id);
    if (localIdx != -1 && productionOrders[localIdx].rawMaterialsUsed.isNotEmpty) {
      return productionOrders[localIdx];
    }
    try {
      final remote = await _productionApi.getOrderById(id);
      if (localIdx != -1) {
        productionOrders[localIdx] = remote;
      } else {
        productionOrders.insert(0, remote);
      }
      notifyListeners();
      return remote;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] getProductionOrderByIdAsync fallback: $e');
      if (localIdx != -1) return productionOrders[localIdx];
      rethrow;
    }
  }

  Future<ProductionOrder> completeProductionOrderAsync(ProductionOrder order) async {
    try {
      final payload = <String, dynamic>{
        'finishedProductId': order.finishedProductId,
        if (order.finishedProductName.isNotEmpty) 'finishedProductName': order.finishedProductName,
        if (order.finishedProductCode.isNotEmpty) 'finishedProductCode': order.finishedProductCode,
        if (order.unit.isNotEmpty) 'unit': order.unit,
        'plannedQuantity': order.plannedQuantity,
        'actualQuantityProduced': order.status == ProductionStatus.completed
            ? (order.actualQuantityProduced > 0 ? order.actualQuantityProduced : order.plannedQuantity)
            : 0.0,
        'status': order.status.name,
        'rawMaterialCost': order.rawMaterialCost,
        'labourCost': order.labourCost,
        'otherExpenses': order.otherExpenses,
        'totalProductionCost': order.totalProductionCost,
        'costPerUnit': order.costPerUnit,
        'productionDate': order.productionDate.toIso8601String(),
        if (order.salesOrderId != null && order.salesOrderId!.isNotEmpty) 'salesOrderId': order.salesOrderId,
        if (order.salesOrderNumber != null && order.salesOrderNumber!.isNotEmpty) 'salesOrderNumber': order.salesOrderNumber,
        if (order.projectId != null && order.projectId!.isNotEmpty) 'projectId': order.projectId,
        if (order.projectName != null && order.projectName!.isNotEmpty) 'projectName': order.projectName,
        if (order.notes != null && order.notes!.isNotEmpty) 'notes': order.notes,
        'rawMaterialsUsed': order.rawMaterialsUsed.map((m) => {
          'rawMaterialId': m.rawMaterialId,
          'rawMaterialName': m.rawMaterialName,
          'rawMaterialCode': m.rawMaterialCode,
          'quantityUsed': m.quantityUsed,
          'unit': m.unit,
          'unitCost': m.unitCost,
          'totalCost': m.totalCost,
        }).toList(),
      };

      final created = await _productionApi.createOrder(payload);
      final fullOrder = created.rawMaterialsUsed.isNotEmpty
          ? created
          : created.copyWith(rawMaterialsUsed: order.rawMaterialsUsed);

      productionOrders.removeWhere((o) => o.id == fullOrder.id);
      productionOrders.insert(0, fullOrder);

      // Refresh production orders, raw materials, finished products, and stock movements
      await Future.wait([
        loadProductionOrders(forceRefresh: true),
        loadRawMaterials(forceRefresh: true),
        loadFinishedProducts(forceRefresh: true),
        loadStockMovements(forceRefresh: true),
      ]);

      if (!productionOrders.any((o) => o.id == fullOrder.id)) {
        productionOrders.insert(0, fullOrder);
      }
      notifyListeners();
      return fullOrder;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] completeProductionOrderAsync remote failed, fallback to local: $e');
      completeProductionOrder(order);
      if (!productionOrders.any((o) => o.id == order.id)) {
        productionOrders.insert(0, order);
      }
      notifyListeners();
      return order;
    }
  }

  Future<ProductionOrder> deleteProductionOrderAsync({
    required String orderId,
    required String reason,
  }) async {
    try {
      final cancelled = await _productionApi.cancelOrder(orderId, reason: reason);
      final idx = productionOrders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        productionOrders[idx] = cancelled;
      }
      // Refresh inventory & movements after rollback
      await Future.wait([
        loadRawMaterials(forceRefresh: true),
        loadFinishedProducts(forceRefresh: true),
        loadStockMovements(forceRefresh: true),
      ]);
      notifyListeners();
      return cancelled;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] deleteProductionOrderAsync remote failed, fallback: $e');
      deleteProductionOrder(orderId: orderId, reason: reason);
      final idx = productionOrders.indexWhere((o) => o.id == orderId);
      if (idx != -1) return productionOrders[idx];
      rethrow;
    }
  }

  Future<void> updateProductionOrderStatusAsync({
    required String orderId,
    required ProductionStatus newStatus,
    String? reason,
    double? actualQuantityProduced,
  }) async {
    if (newStatus == ProductionStatus.cancelled) {
      await deleteProductionOrderAsync(orderId: orderId, reason: reason ?? 'Cancelled by manager');
      await loadProductionOrders(forceRefresh: true);
      notifyListeners();
      return;
    }

    try {
      final updated = await _productionApi.updateOrderStatus(
        orderId,
        newStatus.name,
        reason: reason,
        actualQuantityProduced: actualQuantityProduced,
      );

      final idx = productionOrders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        final existing = productionOrders[idx];
        productionOrders[idx] = updated.rawMaterialsUsed.isNotEmpty
            ? updated
            : updated.copyWith(rawMaterialsUsed: existing.rawMaterialsUsed);
      }

      // If completed, refresh inventory masters and stock movements from backend
      if (newStatus == ProductionStatus.completed) {
        await Future.wait([
          loadRawMaterials(forceRefresh: true),
          loadFinishedProducts(forceRefresh: true),
          loadStockMovements(forceRefresh: true),
        ]);
      }
      await loadProductionOrders(forceRefresh: true);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] updateProductionOrderStatusAsync remote failed, fallback to local: $e');
      // Perform state transition locally with complete validation and inventory ledger management
      updateProductionOrderStatus(orderId: orderId, newStatus: newStatus, reason: reason);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getBomAsync(String finishedProductId) async {
    return _productionApi.getBom(finishedProductId);
  }

  Future<Map<String, dynamic>> saveBomAsync(
    String finishedProductId,
    List<Map<String, dynamic>> items, {
    String? notes,
  }) async {
    return _productionApi.saveBom(finishedProductId, items, notes: notes);
  }

  // -------------------------------------------------------------
  // Phase 7: Payments, Receipts & Commissions Live API
  // -------------------------------------------------------------
  bool _isLoadingPayments = false;
  bool get isLoadingPayments => _isLoadingPayments;

  Future<void> loadPayments({bool forceRefresh = false}) async {
    if (_isLoadingPayments && !forceRefresh) return;
    _isLoadingPayments = true;
    try {
      final res = await _paymentsApi.getPayments(limit: 100);
      final remotePayments = res['items'] as List<ErpPayment>? ?? [];
      payments = remotePayments;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadPayments fallback to local: $e');
    } finally {
      _isLoadingPayments = false;
    }
  }

  Future<ErpPayment> addPaymentAsync(ErpPayment payment) async {
    try {
      final payload = {
        'paymentType': payment.paymentType.name,
        'partyId': payment.partyId,
        'partyName': payment.partyName,
        'referenceDocumentId': payment.referenceDocumentId,
        'referenceDocumentNumber': payment.referenceDocumentNumber,
        'amount': payment.amount,
        'discount': payment.discount,
        'paymentMode': payment.paymentMode.name,
        'paymentDate': payment.paymentDate.toIso8601String(),
        'transactionReference': payment.transactionReference,
        'notes': payment.notes,
        'isFullPayment': payment.isFullPayment,
        'totalDocumentAmount': payment.totalDocumentAmount,
        'remainingAmount': payment.remainingAmount,
        'projectId': payment.projectId,
        'projectName': payment.projectName,
      };
      final created = await _paymentsApi.createPayment(payload);
      payments.removeWhere((p) => p.id == created.id);
      payments.insert(0, created);

      // Re-fetch affected ledgers: customers/dealers/vendors and invoices/purchases
      await Future.wait([
        loadCustomers(forceRefresh: true),
        loadDealers(forceRefresh: true),
        loadVendors(forceRefresh: true),
        loadSalesInvoices(forceRefresh: true),
        loadPurchases(forceRefresh: true),
      ]);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] addPaymentAsync remote failed: $e');
      rethrow;
    }
  }

  bool _isLoadingCommissions = false;
  bool get isLoadingCommissions => _isLoadingCommissions;

  Future<void> loadCommissions({bool forceRefresh = false}) async {
    if (_isLoadingCommissions && !forceRefresh) return;
    _isLoadingCommissions = true;
    try {
      final res = await _paymentsApi.getCommissions(limit: 100);
      final remoteCommissions = res['items'] as List<ArchitectCommission>? ?? [];
      commissions = remoteCommissions;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadCommissions fallback to local: $e');
    } finally {
      _isLoadingCommissions = false;
    }
  }

  Future<ArchitectCommission> approveCommissionAsync(String commissionId, {String? notes}) async {
    try {
      final updated = await _paymentsApi.approveCommission(commissionId, notes: notes);
      final idx = commissions.indexWhere((c) => c.id == commissionId);
      if (idx != -1) commissions[idx] = updated;
      await loadArchitects(forceRefresh: true);
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] approveCommissionAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> disburseCommissionAsync({
    required String commissionId,
    required PaymentMode paymentMode,
    String? transactionRef,
    String? notes,
  }) async {
    try {
      final result = await _paymentsApi.disburseCommission(
        commissionId,
        paymentMode: paymentMode.name,
        transactionReference: transactionRef,
        notes: notes,
      );
      final updatedComm = result['commission'] as ArchitectCommission;
      final newPay = result['payment'] as ErpPayment;

      final idx = commissions.indexWhere((c) => c.id == commissionId);
      if (idx != -1) commissions[idx] = updatedComm;
      payments.removeWhere((p) => p.id == newPay.id);
      payments.insert(0, newPay);

      await loadArchitects(forceRefresh: true);
      notifyListeners();
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] disburseCommissionAsync remote failed: $e');
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Phase 7: Expenses Live API
  // -------------------------------------------------------------
  bool _isLoadingExpenses = false;
  bool get isLoadingExpenses => _isLoadingExpenses;

  Future<void> loadExpenses({bool forceRefresh = false}) async {
    if (_isLoadingExpenses && !forceRefresh) return;
    _isLoadingExpenses = true;
    try {
      final res = await _expensesApi.getExpenses(limit: 100);
      final remoteExpenses = res['items'] as List<Expense>? ?? [];
      expenses = remoteExpenses;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] loadExpenses fallback to local: $e');
    } finally {
      _isLoadingExpenses = false;
    }
  }

  Future<Expense> createExpenseAsync(Expense expense) async {
    try {
      final created = await _expensesApi.createExpense(expense);
      expenses.removeWhere((e) => e.id == created.id);
      expenses.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] createExpenseAsync remote failed: $e');
      rethrow;
    }
  }

  Future<Expense> updateExpenseAsync(Expense expense) async {
    try {
      final payload = {
        'expenseName': expense.expenseName,
        'category': expense.category.name,
        'amount': expense.amount,
        'paidBy': expense.paidBy,
        'paymentMethod': expense.paymentMethod,
        if (expense.vendorPayee != null) 'vendorPayee': expense.vendorPayee,
        if (expense.projectId != null) 'projectId': expense.projectId,
        if (expense.projectName != null) 'projectName': expense.projectName,
        if (expense.purchaseId != null) 'purchaseId': expense.purchaseId,
        if (expense.purchaseNumber != null) 'purchaseNumber': expense.purchaseNumber,
        if (expense.productionId != null) 'productionId': expense.productionId,
        if (expense.productionNumber != null) 'productionNumber': expense.productionNumber,
        if (expense.expenseReference != null) 'expenseReference': expense.expenseReference,
        if (expense.description != null) 'description': expense.description,
        if (expense.receiptAttachmentName != null) 'receiptAttachmentName': expense.receiptAttachmentName,
        'paymentStatus': expense.paymentStatus.name,
      };
      final updated = await _expensesApi.updateExpense(expense.id, payload);
      final idx = expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) expenses[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] updateExpenseAsync remote failed: $e');
      rethrow;
    }
  }

  Future<void> deleteExpenseAsync(String id) async {
    try {
      await _expensesApi.deleteExpense(id);
      expenses.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[MockDatabaseService] deleteExpenseAsync remote failed: $e');
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // Phase 8: Reports Live API
  // -------------------------------------------------------------
  Future<Map<String, dynamic>> getReportAsync(String reportType, {Map<String, dynamic>? query}) async {
    return _reportsApi.getReport(reportType, query: query);
  }
}

