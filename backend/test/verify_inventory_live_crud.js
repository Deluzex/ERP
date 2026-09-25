/**
 * verify_inventory_live_crud.js
 * Automated Full-Stack Live Database Verification for Phase 2:
 * Inventory & Warehouse Management Module (Section 6 of BACKEND_API_REQUIREMENTS.md)
 */

const http = require('http');

const BASE_URL = 'http://localhost:3000/api/v1';

function request(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const fullUrl = `${BASE_URL}${path}`;
    const url = new URL(fullUrl);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function run() {
  console.log('================================================================');
  console.log('  DELUZEX ERP - PHASE 2 INVENTORY LIVE API & CRUD VERIFICATION');
  console.log('================================================================\n');

  // Step 1: Admin Login
  console.log('1. Authenticating as Admin (admin@deluzex.com)...');
  const loginRes = await request('POST', '/auth/login', {
    email: 'admin@deluzex.com',
    password: 'Admin@123',
  });

  if (loginRes.status !== 200 || !loginRes.body?.data?.accessToken) {
    console.error('❌ Login failed:', loginRes.body);
    process.exit(1);
  }
  const token = loginRes.body.data.accessToken;
  console.log('✅ Logged in successfully. JWT obtained.\n');

  // Step 2: 6.1 Get Raw Materials Stock
  console.log('2. Testing 6.1 GET /inventory/raw-materials...');
  const rmRes = await request('GET', '/inventory/raw-materials', null, token);
  if (rmRes.status !== 200 || !rmRes.body?.data?.summary) {
    console.error('❌ Failed to get raw materials stock:', rmRes.body);
    process.exit(1);
  }
  const rmSummary = rmRes.body.data.summary;
  let rmItems = rmRes.body.data.items || [];
  console.log(`✅ Raw Materials Summary: ${rmSummary.totalItems} items, ₹${rmSummary.totalValuation} valuation, ${rmSummary.lowStockCount} low-stock alerts.`);

  // Step 3: 6.2 Get Finished Products Stock
  console.log('3. Testing 6.2 GET /inventory/finished-products...');
  const fpRes = await request('GET', '/inventory/finished-products', null, token);
  if (fpRes.status !== 200 || !fpRes.body?.data?.summary) {
    console.error('❌ Failed to get finished products stock:', fpRes.body);
    process.exit(1);
  }
  const fpSummary = fpRes.body.data.summary;
  console.log(`✅ Finished Goods Summary: ${fpSummary.totalSkus} SKUs, ₹${fpSummary.totalStockValuation} valuation, ${fpSummary.totalReservedStock} reserved.\n`);

  let testCreatedRmId = null;
  let targetItem = rmItems[0];

  if (!targetItem) {
    console.log('ℹ️ Seeding a live raw material item to test adjustment...');
    const catRes = await request('GET', '/masters/categories', null, token);
    const unitRes = await request('GET', '/masters/units', null, token);
    const categoryId = catRes.body.data[0].id;
    const unitId = unitRes.body.data.find((u) => u.symbol === 'MTR')?.id || unitRes.body.data[0].id;

    const createRmRes = await request(
      'POST',
      '/masters/raw-materials',
      {
        name: 'Live Test 6063 Aluminum Profile',
        itemCode: `RM-LIVE-${Date.now().toString().slice(-4)}`,
        categoryId,
        unitId,
        openingStock: 100.0,
        minimumStock: 25.0,
        reorderLevel: 40.0,
        defaultPurchasePrice: 450.0,
        gstPercent: 18.0,
      },
      token,
    );

    if (createRmRes.status !== 201) {
      console.error('❌ Failed to create test raw material:', createRmRes.body);
      process.exit(1);
    }
    targetItem = createRmRes.body.data;
    testCreatedRmId = targetItem.id;
    targetItem.currentStock = 100.0;
    console.log(`✅ Created test raw material "${targetItem.name}" (${targetItem.itemCode}).\n`);
  }

  // Step 4: 6.4 Perform Stock Adjustment
  const originalStock = Number(targetItem.currentStock);
  const adjustedStock = originalStock + 15.0;

  console.log(`4. Testing 6.4 POST /inventory/stock-adjustments on "${targetItem.name}" (${targetItem.itemCode})...`);
  console.log(`   Current Stock: ${originalStock} -> Adjusting to: ${adjustedStock}`);

  const adjRes = await request(
    'POST',
    '/inventory/stock-adjustments',
    {
      itemId: targetItem.id,
      itemType: 'rawMaterial',
      adjustedStockAfter: adjustedStock,
      reason: 'physicalCountMismatch',
      remarks: 'Automated live CRUD simulation reconciliation test',
    },
    token,
  );

  if (adjRes.status !== 201 || !adjRes.body?.data?.adjustmentNumber) {
    console.error('❌ Stock adjustment failed:', adjRes.body);
    process.exit(1);
  }
  const adjData = adjRes.body.data;
  console.log(`✅ Adjustment recorded: ${adjData.adjustmentNumber}`);
  console.log(`   Before: ${adjData.currentStockBefore} | After: ${adjData.adjustedStockAfter} | Delta: ${adjData.adjustmentQuantity} ${adjData.unit}\n`);

  // Step 5: 6.3 Verify Immutable Stock Movement Ledger
  console.log('5. Testing 6.3 GET /inventory/stock-movements...');
  const movRes = await request(
    'GET',
    `/inventory/stock-movements?itemId=${targetItem.id}`,
    null,
    token,
  );

  if (movRes.status !== 200 || !Array.isArray(movRes.body?.data?.items)) {
    console.error('❌ Failed to fetch stock movements:', movRes.body);
    process.exit(1);
  }
  const movements = movRes.body.data.items;
  const foundMov = movements.find((m) => m.referenceNumber === adjData.adjustmentNumber);
  if (!foundMov) {
    console.error('❌ Expected adjustment ledger entry was not found in movements!');
    process.exit(1);
  }
  console.log(`✅ Found immutable ledger movement ${foundMov.id}:`);
  console.log(`   Ref: ${foundMov.referenceNumber} | Stock In: ${foundMov.stockIn} | Balance: ${foundMov.currentBalance} ${foundMov.unit}\n`);

  // Step 6: 6.4 Verify Stock Adjustments Listing
  console.log('6. Testing 6.4 GET /inventory/stock-adjustments...');
  const listAdjRes = await request('GET', '/inventory/stock-adjustments', null, token);
  if (listAdjRes.status !== 200 || !Array.isArray(listAdjRes.body?.data?.items)) {
    console.error('❌ Failed to list stock adjustments:', listAdjRes.body);
    process.exit(1);
  }
  console.log(`✅ Historical adjustments retrieved (${listAdjRes.body.data.items.length} total entries).\n`);

  // Step 7: 6.5, 6.6, 6.7 Low Stock Alerts
  console.log('7. Testing 6.5 POST /inventory/trigger-low-stock-alert...');
  const alertRes = await request(
    'POST',
    '/inventory/trigger-low-stock-alert',
    {
      itemId: targetItem.id,
      itemType: 'rawMaterial',
      recipientId: 'REC-001',
      recipientName: 'Main Store Keeper',
      recipientWhatsApp: '+919876543210',
      customMessage: 'Live verification automated low stock alert',
    },
    token,
  );
  if (alertRes.status !== 201 || !alertRes.body?.data?.id) {
    console.error('❌ Failed to trigger low stock alert:', alertRes.body);
    process.exit(1);
  }
  const alertId = alertRes.body.data.id;
  console.log(`✅ Low stock alert triggered: ${alertId} (Status: ${alertRes.body.data.status})\n`);

  console.log('8. Testing 6.6 GET /inventory/low-stock-alerts...');
  const listAlertsRes = await request('GET', '/inventory/low-stock-alerts', null, token);
  if (listAlertsRes.status !== 200 || !Array.isArray(listAlertsRes.body?.data?.items)) {
    console.error('❌ Failed to list low stock alerts:', listAlertsRes.body);
    process.exit(1);
  }
  console.log(`✅ Retrieved ${listAlertsRes.body.data.items.length} low-stock alerts from log.\n`);

  console.log(`9. Testing 6.7 PATCH /inventory/low-stock-alerts/${alertId}/resolve...`);
  const resolveRes = await request('PATCH', `/inventory/low-stock-alerts/${alertId}/resolve`, null, token);
  if (resolveRes.status !== 200 || resolveRes.body?.data?.status !== 'resolved') {
    console.error('❌ Failed to resolve alert:', resolveRes.body);
    process.exit(1);
  }
  console.log(`✅ Alert marked as resolved at: ${resolveRes.body.data.resolvedAt}\n`);

  // Step 10: Clean up test item if created
  if (testCreatedRmId) {
    console.log('10. Cleaning up test raw material...');
    await request('DELETE', `/masters/raw-materials/${testCreatedRmId}`, null, token);
    console.log('✅ Test item cleaned up.\n');
  }

  console.log('================================================================');
  console.log('  🎉 ALL PHASE 2 INVENTORY ENDPOINTS & FLOWS VERIFIED LIVE (100%)!');
  console.log('================================================================');
}

run().catch((err) => {
  console.error('Fatal error running verification:', err);
  process.exit(1);
});
