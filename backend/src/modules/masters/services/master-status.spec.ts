import { PartiesService } from './parties.service';
import { VendorsService } from './vendors.service';
import { FinishedProductsService } from './finished-products.service';
import { RawMaterialsService } from './raw-materials.service';
import { ProjectsService } from '../../projects/services/projects.service';
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
    it('rejects update on inactive customer with 400 validation error', async () => {
      const inactiveCustomer = {
        id: 'c-inactive-1',
        name: 'Inactive Customer Corp',
        is_active: false,
        is_deleted: false,
      };
      mockDb.query.mockResolvedValueOnce({ rows: [inactiveCustomer] });

      await expect(
        service.updateCustomer('c-inactive-1', { name: 'Attempted Name Change' })
      ).rejects.toThrow('Inactive records cannot be edited. Please activate the record first.');
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
    it('rejects update on inactive dealer and architect with 400 validation error', async () => {
      const inactiveDealer = { id: 'd-inactive-1', name: 'Inactive Dealer', is_active: false, is_deleted: false };
      const inactiveArch = { id: 'a-inactive-1', name: 'Inactive Architect', is_active: false, is_deleted: false };

      mockDb.query.mockResolvedValueOnce({ rows: [inactiveDealer] });
      await expect(
        service.updateDealer('d-inactive-1', { name: 'New Dealer Name' })
      ).rejects.toThrow('Inactive records cannot be edited. Please activate the record first.');

      mockDb.query.mockResolvedValueOnce({ rows: [inactiveArch] });
      await expect(
        service.updateArchitect('a-inactive-1', { name: 'New Architect Name' })
      ).rejects.toThrow('Inactive records cannot be edited. Please activate the record first.');
    });
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
    it('rejects update on inactive vendor with 400 validation error', async () => {
      const inactiveVendor = { id: 'v-inactive-1', name: 'Inactive Vendor', is_active: false, is_deleted: false };
      mockDb.query.mockResolvedValueOnce({ rows: [inactiveVendor] });

      await expect(
        service.update('v-inactive-1', { name: 'Attempted Vendor Rename' })
      ).rejects.toThrow('Inactive records cannot be edited. Please activate the record first.');
    });
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

    it('reactivates inactive vendor back to active and preserves balance and historical flags', async () => {
      const inactiveVendor = {
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
        is_active: false,
        delete_reason: null,
        deleted_at: null,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query
        .mockResolvedValueOnce({ rows: [inactiveVendor] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ ...inactiveVendor, is_active: true }] });

      const res = await (service as any).toggleStatus(inactiveVendor.id, true, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(true);
      expect(res.message).toContain('active');

      // Ensure UPDATE query specifically sets is_active = true
      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringMatching(/UPDATE vendors SET is_active = \$1/),
        [true, inactiveVendor.id],
      );

      expect(mockAudit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'MASTER_STATUS_CHANGE',
          entityType: 'VENDOR',
          entityId: inactiveVendor.id,
          afterSnapshot: expect.objectContaining({
            newStatus: true,
            previousStatus: false,
          }),
        }),
      );
    });

    it('returns idempotently without redundant update if vendor status already matches target', async () => {
      const activeVendor = {
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

      mockDb.query.mockResolvedValueOnce({ rows: [activeVendor] });

      const res = await (service as any).toggleStatus(activeVendor.id, true, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(true);
      expect(mockDb.query).toHaveBeenCalledTimes(1); // Only findById query, no UPDATE
      expect(mockAudit.log).not.toHaveBeenCalled();
    });

    it('updates is_active correctly via general update() method', async () => {
      const existingVendor = {
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
        .mockResolvedValueOnce({ rows: [existingVendor] }) // initial findById
        .mockResolvedValueOnce({ rows: [] }) // UPDATE vendors
        .mockResolvedValueOnce({ rows: [{ ...existingVendor, is_active: false }] }); // findById after update

      const res = await service.update(existingVendor.id, { isActive: false }, 'user-1', 'cid-1');
      expect(res.isActive).toBe(false);
      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringMatching(/is_active = \$1/),
        expect.arrayContaining([false, existingVendor.id]),
      );
    });
  });

  describe('FinishedProductsService - Status Lifecycle', () => {
    it('rejects update on inactive finished product with 400 validation error', async () => {
      const inactiveProduct = { id: 'fp-inactive-1', name: 'Inactive Product', is_active: false, is_deleted: false };
      mockDb.query.mockResolvedValueOnce({ rows: [inactiveProduct] });

      await expect(
        service.update('fp-inactive-1', { name: 'Attempted Product Rename' })
      ).rejects.toThrow('Inactive records cannot be edited. Please activate the record first.');
    });
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
    it('rejects update on inactive raw material with 400 validation error', async () => {
      const inactiveMaterial = { id: 'rm-inactive-1', name: 'Inactive Material', is_active: false, is_deleted: false };
      mockDb.query.mockResolvedValueOnce({ rows: [inactiveMaterial] });

      await expect(
        service.update('rm-inactive-1', { name: 'Attempted Material Rename' })
      ).rejects.toThrow('Inactive records cannot be edited. Please activate the record first.');
    });
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
  describe('ProjectsService - Status Lifecycle', () => {
    it('rejects update on inactive project with 400 validation error', async () => {
      const inactiveProject = { id: 'prj-inactive-1', name: 'Inactive Project', is_active: false, is_deleted: false };
      mockDb.query.mockResolvedValueOnce({ rows: [inactiveProject] });

      await expect(
        service.update('prj-inactive-1', { name: 'Attempted Project Rename' })
      ).rejects.toThrow('Inactive records cannot be edited. Please activate the record first.');
    });
    let service: ProjectsService;

    beforeEach(() => {
      mockAudit.record = jest.fn().mockResolvedValue(undefined);
      service = new ProjectsService(mockDb, mockAudit);
    });

    it('toggles project status from active to inactive and logs MASTER_STATUS_CHANGE audit entry', async () => {
      const mockProject = {
        id: 'p1a2b3c4-0001-4000-8000-111122223333',
        project_code: 'PRJ-2026-0001',
        name: 'The Grand Hyatt Tower Project',
        customer_id: 'c1a2b3c4-0001-4000-8000-111122223333',
        customer_name: 'Hyatt Hotels',
        dealer_id: null,
        dealer_name: null,
        architect_id: null,
        architect_name: null,
        start_date: new Date(),
        expected_completion_date: null,
        actual_completion_date: null,
        status: 'active',
        budget_amount: '5000000.00',
        total_sales_amount: '0.00',
        total_commission_amount: '0.00',
        site_state: 'Gujarat',
        site_state_code: '24',
        site_address: 'Ahmedabad',
        site_pincode: '380015',
        pos_verified: true,
        notes: null,
        is_deleted: false,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query
        .mockResolvedValueOnce({ rows: [mockProject] }) // findById
        .mockResolvedValueOnce({ rows: [] }) // UPDATE projects SET is_active = false
        .mockResolvedValueOnce({ rows: [{ ...mockProject, is_active: false }] }); // findById after update

      const res = await service.toggleStatus(mockProject.id, false, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(false);
      expect(res.message).toContain('inactive');

      expect(mockDb.query).toHaveBeenNthCalledWith(
        2,
        expect.stringMatching(/UPDATE projects SET is_active = \$1/),
        [false, mockProject.id],
      );

      expect(mockAudit.record).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'MASTER_STATUS_CHANGE',
          entityType: 'PROJECT',
          entityId: mockProject.id,
          afterSnapshot: expect.objectContaining({
            newStatus: false,
            previousStatus: true,
          }),
        }),
      );
    });

    it('reactivates inactive project back to active and preserves budget and status', async () => {
      const inactiveProject = {
        id: 'p1a2b3c4-0001-4000-8000-111122223333',
        project_code: 'PRJ-2026-0001',
        name: 'The Grand Hyatt Tower Project',
        customer_id: null,
        customer_name: null,
        dealer_id: null,
        dealer_name: null,
        architect_id: null,
        architect_name: null,
        start_date: new Date(),
        expected_completion_date: null,
        actual_completion_date: null,
        status: 'active',
        budget_amount: '5000000.00',
        total_sales_amount: '0.00',
        total_commission_amount: '0.00',
        site_state: null,
        site_state_code: null,
        site_address: null,
        site_pincode: null,
        pos_verified: false,
        notes: null,
        is_deleted: false,
        is_active: false,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query
        .mockResolvedValueOnce({ rows: [inactiveProject] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ ...inactiveProject, is_active: true }] });

      const res = await service.toggleStatus(inactiveProject.id, true, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(true);
      expect(res.message).toContain('active');

      expect(mockDb.query).toHaveBeenNthCalledWith(
        2,
        expect.stringMatching(/UPDATE projects SET is_active = \$1/),
        [true, inactiveProject.id],
      );
    });

    it('returns idempotently without redundant update if project status already matches target', async () => {
      const activeProject = {
        id: 'p1a2b3c4-0001-4000-8000-111122223333',
        project_code: 'PRJ-2026-0001',
        name: 'The Grand Hyatt Tower Project',
        customer_id: null,
        customer_name: null,
        dealer_id: null,
        dealer_name: null,
        architect_id: null,
        architect_name: null,
        start_date: new Date(),
        expected_completion_date: null,
        actual_completion_date: null,
        status: 'active',
        budget_amount: '5000000.00',
        total_sales_amount: '0.00',
        total_commission_amount: '0.00',
        site_state: null,
        site_state_code: null,
        site_address: null,
        site_pincode: null,
        pos_verified: false,
        notes: null,
        is_deleted: false,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [activeProject] });

      const res = await service.toggleStatus(activeProject.id, true, 'user-1', 'cid-1');
      expect(res.success).toBe(true);
      expect(res.data.isActive).toBe(true);
      expect(mockDb.query).toHaveBeenCalledTimes(1); // Only findById
      expect(mockAudit.record).not.toHaveBeenCalled();
    });

    it('filters active projects when isActive = true is passed in findAll query', async () => {
      mockDb.query
        .mockResolvedValueOnce({ rows: [{ total_count: '1', active_count: '1', completed_count: '0', total_budget: '5000000' }] })
        .mockResolvedValueOnce({ rows: [] });

      await service.findAll({ isActive: true });
      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringMatching(/p\.is_active = \$1/),
        expect.arrayContaining([true]),
      );
    });
  });
});
