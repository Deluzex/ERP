import 'package:flutter/foundation.dart';
import '../../core/models/architect_model.dart';
import '../../core/models/category_unit_model.dart';
import '../../core/models/commission_model.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/dealer_model.dart';
import '../../core/models/finished_product_model.dart';
import '../../core/models/payment_model.dart';
import '../../core/models/production_model.dart';
import '../../core/models/project_model.dart';
import '../../core/models/purchase_model.dart';
import '../../core/models/raw_material_model.dart';
import '../../core/models/sale_model.dart';
import '../../core/models/stock_adjustment_model.dart';
import '../../core/models/stock_movement_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/vendor_model.dart';
import '../../core/utils/id_generator.dart';

class MockDatabaseService extends ChangeNotifier {
  // Seed User
  UserModel currentUser = UserModel(
    id: 'USR-001',
    name: 'Alex Sterling',
    email: 'alex.sterling@deluxex.com',
    role: 'Service Manager',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
  );

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

  // Counters for doc numbering
  int _purchaseCounter = 104;
  int _productionCounter = 88;
  int _salesCounter = 215;
  int _paymentCounter = 312;
  int _commissionCounter = 55;
  int _adjCounter = 19;

  MockDatabaseService() {
    _seedInitialData();
  }

  void _seedInitialData() {
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

    // Seed Sales
    sales = [
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
        saleDate: now.subtract(const Duration(hours: 1)),
        items: [
          SaleLineItem(
            finishedProductId: 'FP-001',
            finishedProductName: 'Aarix Axis Wall Light',
            finishedProductCode: 'DLX-WL-001',
            quantity: 20.0,
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
        paidAmount: 50000.0,
        pendingAmount: 58560.0,
        paymentMode: PaymentMode.bankTransfer,
        status: SaleStatus.partialPaid,
        architectCommissionAmount: 4600.0, // 5% of discounted subtotal
        notes: 'Direct site delivery to Penthouse Tower C',
        createdAt: now.subtract(const Duration(hours: 1)),
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
      // 1. Increase Raw Material Stock & record ledger
      for (final line in purchase.items) {
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
            notes: 'Purchase from ${purchase.vendorName} (Inv: ${purchase.vendorInvoiceNumber})',
          );
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
          notes: 'Direct payment at purchase creation',
        );
      }
    }

    notifyListeners();
  }

  // -------------------------------------------------------------
  // PRODUCTION WORKFLOW (Direct Raw Material Consumption & Finished Goods Addition)
  // -------------------------------------------------------------
  void completeProductionOrder(ProductionOrder order) {
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
      final newStock = fp.currentStock + order.actualQuantityProduced;
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
        stockIn: order.actualQuantityProduced,
        stockOut: 0.0,
        newBalance: newStock,
        unit: fp.unit,
        notes: 'Produced batch of ${order.actualQuantityProduced} units',
      );
    }

    productionOrders.insert(0, order);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // SALES WORKFLOW
  // -------------------------------------------------------------
  void createSale(Sale sale) {
    sales.insert(0, sale);

    if (sale.status != SaleStatus.draft && sale.status != SaleStatus.cancelled) {
      // 1. Deduct finished product stock
      for (final line in sale.items) {
        final fpIndex = finishedProducts.indexWhere((fp) => fp.id == line.finishedProductId);
        if (fpIndex != -1) {
          final fp = finishedProducts[fpIndex];
          final newStock = (fp.currentStock - line.quantity).clamp(0.0, double.infinity);
          finishedProducts[fpIndex] = fp.copyWith(
            currentStock: newStock,
            updatedAt: DateTime.now(),
          );

          _recordStockTransaction(
            itemId: fp.id,
            itemName: fp.name,
            itemCode: fp.itemCode,
            itemType: ItemType.finishedProduct,
            transactionType: StockMovementType.sale,
            referenceNumber: sale.invoiceNumber,
            stockIn: 0.0,
            stockOut: line.quantity,
            newBalance: newStock,
            unit: fp.unit,
            notes: 'Sale to ${sale.partyName} (${sale.partyType == PartyType.customer ? "Customer" : "Dealer"})',
          );
        }
      }

      // 2. Update Customer / Dealer Outstanding
      if (sale.partyType == PartyType.customer) {
        final cIndex = customers.indexWhere((c) => c.id == sale.partyId);
        if (cIndex != -1) {
          final c = customers[cIndex];
          customers[cIndex] = c.copyWith(outstandingAmount: c.outstandingAmount + sale.pendingAmount);
        }
      } else {
        final dIndex = dealers.indexWhere((d) => d.id == sale.partyId);
        if (dIndex != -1) {
          final d = dealers[dIndex];
          dealers[dIndex] = d.copyWith(outstandingAmount: d.outstandingAmount + sale.pendingAmount);
        }
      }

      // 3. Update Project if linked
      if (sale.projectId != null) {
        final pIndex = projects.indexWhere((p) => p.id == sale.projectId);
        if (pIndex != -1) {
          final p = projects[pIndex];
          projects[pIndex] = p.copyWith(
            totalSalesAmount: p.totalSalesAmount + sale.totalAmount,
            totalCommissionAmount: p.totalCommissionAmount + sale.architectCommissionAmount,
          );
        }
      }

      // 4. Generate Architect Commission if architect linked & commission > 0
      if (sale.architectId != null && sale.architectCommissionAmount > 0) {
        final architect = architects.firstWhere((a) => a.id == sale.architectId, orElse: () => architects.first);
        final commission = ArchitectCommission(
          id: IdGenerator.generateId('COM'),
          commissionNumber: IdGenerator.generateDocNumber('COM', ++_commissionCounter),
          architectId: architect.id,
          architectName: architect.name,
          saleInvoiceId: sale.id,
          saleInvoiceNumber: sale.invoiceNumber,
          projectId: sale.projectId,
          projectName: sale.projectName,
          saleAmount: sale.subtotalAmount - sale.discountAmount,
          commissionRate: architect.defaultCommissionRate,
          commissionAmount: sale.architectCommissionAmount,
          status: CommissionStatus.generated,
          generatedDate: DateTime.now(),
        );
        commissions.insert(0, commission);

        final archIndex = architects.indexWhere((a) => a.id == architect.id);
        if (archIndex != -1) {
          final a = architects[archIndex];
          architects[archIndex] = a.copyWith(
            totalCommissionEarned: a.totalCommissionEarned + sale.architectCommissionAmount,
            pendingCommission: a.pendingCommission + sale.architectCommissionAmount,
          );
        }
      }

      // 5. Record Payment if paidAmount > 0
      if (sale.paidAmount > 0) {
        _recordPayment(
          paymentType: sale.partyType == PartyType.customer ? PaymentType.customerPayment : PaymentType.dealerPayment,
          partyId: sale.partyId,
          partyName: sale.partyName,
          referenceDocumentId: sale.id,
          referenceDocumentNumber: sale.invoiceNumber,
          amount: sale.paidAmount,
          paymentMode: sale.paymentMode,
          notes: 'Receipt against invoice ${sale.invoiceNumber}',
        );
      }
    }

    notifyListeners();
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

    switch (payment.paymentType) {
      case PaymentType.customerPayment:
        final cIndex = customers.indexWhere((c) => c.id == payment.partyId);
        if (cIndex != -1) {
          final c = customers[cIndex];
          customers[cIndex] = c.copyWith(
            outstandingAmount: (c.outstandingAmount - payment.amount).clamp(0.0, double.infinity),
          );
        }
        break;
      case PaymentType.dealerPayment:
        final dIndex = dealers.indexWhere((d) => d.id == payment.partyId);
        if (dIndex != -1) {
          final d = dealers[dIndex];
          dealers[dIndex] = d.copyWith(
            outstandingAmount: (d.outstandingAmount - payment.amount).clamp(0.0, double.infinity),
          );
        }
        break;
      case PaymentType.vendorPayment:
        final vIndex = vendors.indexWhere((v) => v.id == payment.partyId);
        if (vIndex != -1) {
          final v = vendors[vIndex];
          vendors[vIndex] = v.copyWith(
            outstandingBalance: (v.outstandingBalance - payment.amount).clamp(0.0, double.infinity),
          );
        }
        break;
      case PaymentType.commissionPayment:
        // Handled via approve/pay commission method
        break;
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
        notes: 'Commission payout for invoice ${comm.saleInvoiceNumber}',
      );

      notifyListeners();
    }
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
    notifyListeners();
  }

  void updateCustomer(Customer customer) {
    final index = customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      customers[index] = customer;
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
    notifyListeners();
  }

  void updateArchitect(Architect architect) {
    final index = architects.indexWhere((a) => a.id == architect.id);
    if (index != -1) {
      architects[index] = architect;
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
  double get totalSalesAmount => sales.fold(0.0, (sum, s) => sum + s.totalAmount);
  double get totalPurchaseAmount => purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
  double get rawMaterialStockValue => rawMaterials.fold(0.0, (sum, rm) => sum + rm.totalValuation);
  double get finishedProductStockValue => finishedProducts.fold(0.0, (sum, fp) => sum + fp.totalValuation);
  double get totalStockValue => rawMaterialStockValue + finishedProductStockValue;

  double get todaySalesAmount {
    final today = DateTime.now();
    return sales
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
  int get nextAdjustmentNumber => ++_adjCounter;
}
