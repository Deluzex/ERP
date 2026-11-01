import { PartiesService } from './parties.service';
import { VendorsService } from './vendors.service';
import { FinishedProductsService } from './finished-products.service';
import { RawMaterialsService } from './raw-materials.service';
import { NotFoundError } from '../../../core/errors/not-found.error';

describe('Master Status Lifecycle & Governance Service Tests', () => {
  let mockDb: any;
  let mockAudit: any;
  let mockUow: any;

  beforeEach(() => {
    mockDb = {
      query: jest.fn(),
    };
    mockAudit = {
      log: jest.fn().mockResolvedValue(undefined),
    };
    mockUow = {
      withTransaction: jest.fn(),
    };
  });

  describe('PartiesService - Customer Status Lifecycle', () => {
    let service: PartiesService;

    beforeEach(() => {
      service = new PartiesService(mockDb, mockUow, mockAudit);
    });

    it('toggles customer status from active to inactive and logs MASTER_STATUS_CHANGE audit entry', async () => {
      const mockCustomer = {
        id: 'c1a2b3c4-0001-4000-8000-111122223333',
        name: 'Oberoi Sky City Residences',
        mobile: '9876543210',
        email: 'oberoi@example.com',
        gst_number: '24AAAAA0000A1Z5',
        address: 'Mumbai',
        state_code: '27',
        state: 'Maharashtra',
        pincode: '400001',
        outstanding_amount: '264320.00',
        credit_balance: '0.00',
        linked_architect_id: null,
        is_also_architect: false,
        is_deleted: false,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      // 1. Initial query to check existing
      mockDb.query
        .mockResolvedValueOnce({ rows: [mockCustomer] }) // findCustomerById check
        .mockResolvedValueOnce({ rows: [] }) // UPDATE query
        .mockResolvedValueOnce({ rows: [{ ...mockCustomer, is_active: false }] }); // findCustomerById after update

      const res = await (service as any).toggleCustomerStatus(mockCustomer.id, false, 'user-1', 'cid-1');

      expect(res.success).toBe(true);
      expect(res.message).toContain('inactive');
      expect(res.data.id).toBe(mockCustomer.id);
      expect(res.data.isActive).toBe(false);

      expect(mockAudit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'MASTER_STATUS_CHANGE',
          entityType: 'CUSTOMER',
          entityId: mockCustomer.id,
          userId: 'user-1',
          correlationId: 'cid-1',
        }),
      );
    });

    it('returns idempotently without duplicate audit log if status is already matching', async () => {
      const mockCustomer = {
        id: 'c1a2b3c4-0001-4000-8000-111122223333',
        name: 'Oberoi Sky City Residences',
        mobile: '9876543210',
        email: 'oberoi@example.com',
        gst_number: null,
        address: 'Mumbai',
        state_code: '27',
        outstanding_amount: '0.00',
        credit_balance: '0.00',
        linked_architect_id: null,
        is_also_architect: false,
        is_deleted: false,
        is_active: false,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockCustomer] });

      const res = await (service as any).toggleCustomerStatus(mockCustomer.id, false, 'user-1', 'cid-1');

      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(false);
      expect(mockAudit.log).not.toHaveBeenCalled();
    });

    it('throws NotFoundError when toggling non-existent customer', async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      await expect((service as any).toggleCustomerStatus('non-existent-id', false)).rejects.toThrow(NotFoundError);
    });

    it('filters active customers only when isActive = true query parameter is passed', async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      await (service as any).findAllCustomers(undefined, undefined, false, true);

      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringMatching(/is_active = \$1/),
        expect.arrayContaining([true]),
      );
    });

    it('filters inactive customers only when isActive = false query parameter is passed', async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      await (service as any).findAllCustomers(undefined, undefined, false, false);

      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringMatching(/is_active = \$1/),
        expect.arrayContaining([false]),
      );
    });

    it('returns all customers when isActive parameter is omitted', async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      await (service as any).findAllCustomers(undefined, undefined, false, undefined);

      expect(mockDb.query).toHaveBeenCalledWith(
        expect.not.stringMatching(/is_active =/),
        [],
      );
    });
  });

  describe('PartiesService - Dealer & Architect Status Lifecycle', () => {
    let service: PartiesService;

    beforeEach(() => {
      service = new PartiesService(mockDb, mockUow, mockAudit);
    });

    it('toggles dealer status and logs MASTER_STATUS_CHANGE', async () => {
      const mockDealer = {
        id: 'd1a2b3c4-0001-4000-8000-111122223333',
        name: 'Apex Showroom',
        contact_person: 'John Doe',
        company_name: 'Apex Ltd',
        mobile: '9876543210',
        email: 'apex@example.com',
        gst_number: '24AAAAA0000A1Z5',
        address: 'Surat',
        state_code: '24',
        outstanding_amount: '0.00',
        is_deleted: false,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query
        .mockResolvedValueOnce({ rows: [mockDealer] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ ...mockDealer, is_active: false }] });

      const res = await (service as any).toggleDealerStatus(mockDealer.id, false, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(false);
      expect(mockAudit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'MASTER_STATUS_CHANGE',
          entityType: 'DEALER',
        }),
      );
    });

    it('toggles architect status and logs MASTER_STATUS_CHANGE', async () => {
      const mockArchitect = {
        id: 'a1a2b3c4-0001-4000-8000-111122223333',
        name: 'Ar. Sharma',
        company_name: 'Sharma Designs',
        mobile: '9876543210',
        email: 'sharma@example.com',
        gst_number: null,
        address: 'Ahmedabad',
        default_commission_rate: 5.0,
        total_commission_earned: '0.00',
        pending_commission: '0.00',
        approved_commission: '0.00',
        paid_commission: '0.00',
        linked_customer_id: null,
        is_also_customer: false,
        is_deleted: false,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query
        .mockResolvedValueOnce({ rows: [mockArchitect] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ ...mockArchitect, is_active: false }] });

      const res = await (service as any).toggleArchitectStatus(mockArchitect.id, false, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(false);
      expect(mockAudit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'MASTER_STATUS_CHANGE',
          entityType: 'ARCHITECT',
        }),
      );
    });

    it('filters active dealers when isActive = true is passed', async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      await (service as any).findAllDealers(undefined, false, true);

      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringMatching(/is_active = \$1/),
        expect.arrayContaining([true]),
      );
    });

    it('filters active architects when isActive = true is passed', async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      await (service as any).findAllArchitects(undefined, false, true);

      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringMatching(/a\.is_active = \$1/),
        expect.arrayContaining([true]),
      );
    });
  });

  describe('VendorsService - Status Lifecycle', () => {
    let service: VendorsService;

    beforeEach(() => {
      service = new VendorsService(mockDb, mockAudit);
    });

    it('toggles vendor status and logs MASTER_STATUS_CHANGE', async () => {
      const mockVendor = {
        id: 'v1a2b3c4-0001-4000-8000-111122223333',
        name: 'Brass World Corp',
        contact_person: 'Vendor Contact',
        mobile: '9876543210',
        email: 'brass@example.com',
        gst_number: '24AAAAA0000A1Z5',
        pan_number: 'AAAAA0000A',
        address: 'Jamnagar',
        payment_terms: 'Net 30 Days',
        credit_limit: '500000.00',
        outstanding_balance: '12000.00',
        is_deleted: false,
        is_active: true,
        delete_reason: null,
        deleted_at: null,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query
        .mockResolvedValueOnce({ rows: [mockVendor] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ ...mockVendor, is_active: false }] });

      const res = await (service as any).toggleStatus(mockVendor.id, false, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(false);
      expect(mockAudit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'MASTER_STATUS_CHANGE',
          entityType: 'VENDOR',
        }),
      );
    });
  });

  describe('FinishedProductsService - Status Lifecycle', () => {
    let service: FinishedProductsService;

    beforeEach(() => {
      service = new FinishedProductsService(mockDb, mockAudit, mockUow);
    });

    it('toggles finished product status and logs MASTER_STATUS_CHANGE', async () => {
      const mockProduct = {
        id: 'fp1a2b3c-0001-4000-8000-111122223333',
        name: 'Crystal Chandelier 12-Light',
        item_code: 'FP-CH-001',
        category_id: 'cat-1',
        category_name: 'Chandeliers',
        unit_id: 'u-1',
        unit_symbol: 'PCS',
        hsn_sac_code: '9405',
        current_stock: '10.0000',
        opening_stock: '10.0000',
        minimum_stock: '2.0000',
        cost_price: '5000.00',
        transportation_charge: '0.00',
        dealer_selling_price: '7500.00',
        customer_selling_price: '9500.00',
        gst_percent: '18.00',
        is_deleted: false,
        is_active: true,
        deleted_at: null,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query
        .mockResolvedValueOnce({ rows: [mockProduct] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ ...mockProduct, is_active: false }] });

      const res = await (service as any).toggleStatus(mockProduct.id, false, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(false);
      expect(mockAudit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'MASTER_STATUS_CHANGE',
          entityType: 'FINISHED_PRODUCT',
        }),
      );
    });
  });

  describe('RawMaterialsService - Status Lifecycle', () => {
    let service: RawMaterialsService;

    beforeEach(() => {
      service = new RawMaterialsService(mockDb, mockAudit, mockUow);
    });

    it('toggles raw material status and logs MASTER_STATUS_CHANGE', async () => {
      const mockMaterial = {
        id: 'rm1a2b3c-0001-4000-8000-111122223333',
        name: 'Brass Sheet 2mm',
        item_code: 'RM-BR-001',
        category_id: 'cat-1',
        category_name: 'Metals',
        unit_id: 'u-1',
        unit_symbol: 'KG',
        hsn_sac_code: '7409',
        current_stock: '100.0000',
        opening_stock: '100.0000',
        minimum_stock: '20.0000',
        reorder_level: '30.0000',
        default_purchase_price: '450.00',
        transportation_charge: '0.00',
        gst_percent: '18.00',
        preferred_vendor_ids: [],
        is_deleted: false,
        is_active: true,
        deleted_at: null,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query
        .mockResolvedValueOnce({ rows: [mockMaterial] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ ...mockMaterial, is_active: false }] });

      const res = await (service as any).toggleStatus(mockMaterial.id, false, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(false);
      expect(mockAudit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'MASTER_STATUS_CHANGE',
          entityType: 'RAW_MATERIAL',
        }),
      );
    });
  });
});

