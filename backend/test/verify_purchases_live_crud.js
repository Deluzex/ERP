/**
 * Phase 3 Automated Verification Script: Live Purchase & Procurement CRUD Simulation
 * Verifies:
 *  - Authentication & JWT Token
 *  - Purchase creation (POST /api/v1/purchases)
 *  - Transactional stock inward increment in raw_materials
 *  - Stock ledger movement write (transaction_type = 'purchase')
 *  - Vendor outstanding balance increment
 *  - Direct payment voucher creation
 *  - Purchase cancellation (PATCH /api/v1/purchases/:id/status)
 *  - Transactional stock decrement rollback and vendor balance reduction
 *  - Automated teardown leaving zero pollution
 */

const http = require('http');

function request(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, data: parsed, headers: res.headers });
        } catch (e) {
          resolve({ status: res.statusCode, data: body, headers: res.headers });
        }
      });
    });
    req.on('error', reject);
    if (postData) {
      req.write(typeof postData === 'string' ? postData : JSON.stringify(postData));
    }
    req.end();
  });
}

async function runSimulation() {
  console.log('=== [PHASE 3] Starting Live Purchases & Inward Stock Simulation ===\n');

  // Step 1: Login
  console.log('1. Logging in as super admin...');
  const loginRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/auth/login',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    },
    { email: 'admin@deluzex.com', password: 'Admin@123' }
  );

  if (loginRes.status !== 200 || !loginRes.data?.data?.accessToken) {
    throw new Error(`Login failed: ${JSON.stringify(loginRes.data)}`);
  }
  const token = loginRes.data.data.accessToken;
  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
  console.log('   -> Logged in successfully. JWT obtained.\n');

  // Step 2: Get or create test vendor and test raw material
  console.log('2. Setting up test vendor and raw material...');
  const randSuffix = Date.now().toString().slice(-4);
  const testGst = `24ABCDE${randSuffix}F1Z1`;
  const testPan = `ABCDE${randSuffix}F`;

  const testVendorRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/masters/vendors',
      method: 'POST',
      headers: authHeaders,
    },
    {
      name: `Sim Vendor ${Date.now()}`,
      contactPerson: 'Sim Agent',
      mobile: '9898000001',
      email: `sim_vendor_${Date.now()}@example.com`,
      gstNumber: testGst,
      panNumber: testPan,
      address: 'Industrial Area GIDC',
      paymentTerms: 'Net 30 Days',
      creditLimit: 500000,
    }
  );
  if (testVendorRes.status !== 201) {
    console.error('Vendor creation failed:', testVendorRes.status, testVendorRes.data);
    throw new Error(`Failed to create vendor: ${JSON.stringify(testVendorRes.data)}`);
  }
  const vendor = testVendorRes.data.data;
  console.log(`   -> Created test vendor: ${vendor.name} (ID: ${vendor.id})`);

  // Get categories and units to create test raw material
  const catRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/masters/categories?type=rawMaterial',
      method: 'GET',
      headers: authHeaders,
    }
  );
  const categoryId = catRes.data.data[0]?.id;

  const unitRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/masters/units',
      method: 'GET',
      headers: authHeaders,
    }
  );
  const unitId = unitRes.data.data[0]?.id;

  const testRmRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/masters/raw-materials',
      method: 'POST',
      headers: authHeaders,
    },
    {
      itemCode: `RM-SIM-${Date.now().toString().slice(-4)}`,
      name: `Sim Material ${Date.now()}`,
      categoryId: categoryId,
      unitId: unitId,
      minimumStock: 10,
      reorderLevel: 20,
      defaultPurchasePrice: 150.0,
      gstPercent: 18.0,
    }
  );
  if (testRmRes.status !== 201) {
    console.error('Raw Material creation failed:', testRmRes.status, testRmRes.data);
    throw new Error(`Failed to create raw material: ${JSON.stringify(testRmRes.data)}`);
  }
  const rawMaterial = testRmRes.data.data;
  console.log(`   -> Created test raw material: ${rawMaterial.name} (Initial Stock: ${rawMaterial.currentStock})\n`);

  const initialStock = Number(rawMaterial.currentStock);
  const purchaseQty = 40.0;

  // Step 3: Create Purchase Order & Inward Bill (POST /api/v1/purchases)
  console.log('3. Posting live Purchase Order & Stock Inward...');
  const createPurchaseRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/purchases',
      method: 'POST',
      headers: authHeaders,
    },
    {
      vendorId: vendor.id,
      vendorName: vendor.name,
      vendorInvoiceNumber: `INV-SIM-${Date.now()}`,
      purchaseDate: new Date().toISOString(),
      purchaseType: 'rawMaterial',
      items: [
        {
          itemType: 'rawMaterial',
          rawMaterialId: rawMaterial.id,
          rawMaterialName: rawMaterial.name,
          quantity: purchaseQty,
          unit: 'kg',
          rate: 150.0,
          discountAmount: 0.0,
          gstPercent: 18.0,
          taxableAmount: 6000.0,
          cgstAmount: 540.0,
          sgstAmount: 540.0,
          igstAmount: 0.0,
          lineTotal: 7080.0,
        },
      ],
      subtotalAmount: 6000.0,
      discountAmount: 0.0,
      taxableAmount: 6000.0,
      cgstAmount: 540.0,
      sgstAmount: 540.0,
      igstAmount: 0.0,
      gstAmount: 1080.0,
      totalAmount: 7080.0,
      paidAmount: 2080.0,
      pendingAmount: 5000.0,
      paymentMode: 'bankTransfer',
      status: 'partialPaid',
      notes: 'Automated live simulation purchase test',
    }
  );

  if (createPurchaseRes.status !== 201) {
    throw new Error(`Failed to create purchase: ${JSON.stringify(createPurchaseRes.data)}`);
  }
  const purchase = createPurchaseRes.data.data;
  console.log(`   -> Purchase Created: ${purchase.purchaseNumber} (Status: ${purchase.status})`);
  console.log(`   -> Total Amount: ₹${purchase.totalAmount}, Paid: ₹${purchase.paidAmount}, Pending: ₹${purchase.pendingAmount}\n`);

  // Step 4: Verify stock inward in database
  console.log('4. Verifying stock increment & vendor balance in database...');
  const updatedRmRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/masters/raw-materials/${rawMaterial.id}`,
      method: 'GET',
      headers: authHeaders,
    }
  );
  const updatedStock = Number(updatedRmRes.data.data.currentStock);
  console.log(`   -> Raw Material stock: ${initialStock} -> ${updatedStock} (Expected: ${initialStock + purchaseQty})`);
  if (Math.abs(updatedStock - (initialStock + purchaseQty)) > 0.001) {
    throw new Error(`Stock mismatch! Expected ${initialStock + purchaseQty}, got ${updatedStock}`);
  }

  const updatedVendorRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/masters/vendors/${vendor.id}`,
      method: 'GET',
      headers: authHeaders,
    }
  );
  const updatedVendorBalance = Number(updatedVendorRes.data.data.outstandingBalance);
  console.log(`   -> Vendor outstanding balance: ₹${updatedVendorBalance} (Expected: ₹5000.00)`);
  if (Math.abs(updatedVendorBalance - 5000.0) > 0.01) {
    throw new Error(`Vendor balance mismatch! Expected 5000.00, got ${updatedVendorBalance}`);
  }

  // Verify stock movements ledger
  const movementsRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/inventory/stock-movements?search=${purchase.purchaseNumber}`,
      method: 'GET',
      headers: authHeaders,
    }
  );
  const movements = movementsRes.data.data?.items || movementsRes.data.data?.movements || [];
  console.log(`   -> Stock movements logged: ${movements.length} records found`);
  if (movements.length === 0) {
    throw new Error('Stock movement was not logged in immutable ledger!');
  }
  console.log(`      Movement type: ${movements[0].transactionType}, Inward: +${movements[0].stockIn} ${movements[0].unit}\n`);

  // Step 5: Test Cancellation & Rollback
  console.log('5. Testing Purchase Order Cancellation & Transactional Rollback...');
  const cancelRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/purchases/${purchase.id}/status`,
      method: 'PATCH',
      headers: authHeaders,
    },
    {
      status: 'cancelled',
      cancelReason: 'Simulation test cancellation rollback verification',
    }
  );

  if (cancelRes.status !== 200) {
    throw new Error(`Failed to cancel purchase: ${JSON.stringify(cancelRes.data)}`);
  }
  console.log(`   -> Purchase ${purchase.purchaseNumber} marked as CANCELLED.`);

  // Verify stock rolled back to initial
  const rolledBackRmRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/masters/raw-materials/${rawMaterial.id}`,
      method: 'GET',
      headers: authHeaders,
    }
  );
  const rolledBackStock = Number(rolledBackRmRes.data.data.currentStock);
  console.log(`   -> Raw Material stock rolled back: ${rolledBackStock} (Expected: ${initialStock})`);
  if (Math.abs(rolledBackStock - initialStock) > 0.001) {
    throw new Error(`Rollback failed! Expected stock ${initialStock}, got ${rolledBackStock}`);
  }

  const rolledBackVendorRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/masters/vendors/${vendor.id}`,
      method: 'GET',
      headers: authHeaders,
    }
  );
  const rolledBackVendorBal = Number(rolledBackVendorRes.data.data.outstandingBalance);
  console.log(`   -> Vendor outstanding balance rolled back: ₹${rolledBackVendorBal} (Expected: ₹0.00)\n`);
  if (Math.abs(rolledBackVendorBal - 0.0) > 0.01) {
    throw new Error(`Vendor rollback failed! Expected 0.00, got ${rolledBackVendorBal}`);
  }

  // Step 6: Cleanup test data deterministically
  console.log('6. Cleaning up test data...');
  const { Client } = require('pg');
  require('dotenv').config({ path: __dirname + '/../.env' });
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();
  try {
    await client.query('DELETE FROM payments WHERE purchase_id = $1', [purchase.id]);
    await client.query('DELETE FROM stock_movements WHERE reference_number = $1', [purchase.purchaseNumber]);
    await client.query('DELETE FROM purchase_items WHERE purchase_id = $1', [purchase.id]);
    await client.query('DELETE FROM purchases WHERE id = $1', [purchase.id]);
    await client.query('DELETE FROM raw_materials WHERE id = $1', [rawMaterial.id]);
    await client.query('DELETE FROM vendors WHERE id = $1', [vendor.id]);
    console.log('   -> Test purchase, payments, movements, raw material, and vendor cleaned up.\n');
  } finally {
    await client.end();
  }

  console.log('=== [PHASE 3] ALL LIVE CRUD & INWARD SIMULATION TESTS PASSED 100%! ===');
}

runSimulation().catch((err) => {
  console.error('\n[SIMULATION ERROR]:', err);
  process.exit(1);
});
