/**
 * Phase 4 Automated Verification Script: Live Production & BOM CRUD Simulation
 * Verifies:
 *  - Authentication & JWT Token
 *  - Dedicated Test Raw Material & Finished Product setup
 *  - Inventory inward via adjustment
 *  - BOM creation & retrieval (POST & GET /api/v1/production/bom)
 *  - Production order creation with 1-step completion (POST /api/v1/production/orders)
 *  - Atomic raw material stock deduction in database
 *  - Atomic finished product stock addition in database
 *  - Immutable stock movement audit ledger entries
 *  - Production order cancellation/rollback (DELETE /api/v1/production/orders/:id)
 *  - Full inventory stock rollback to original levels
 *  - Deterministic database cleanup leaving zero pollution
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const http = require('http');
const { Pool } = require('pg');

function request(options, postData = null) {
  return new Promise((resolve, reject) => {
    const payload = postData ? (typeof postData === 'string' ? postData : JSON.stringify(postData)) : null;
    const opts = { ...options, headers: { ...options.headers } };
    if (payload) {
      opts.headers['Content-Type'] = opts.headers['Content-Type'] || 'application/json';
      opts.headers['Content-Length'] = Buffer.byteLength(payload);
    }
    const req = http.request(opts, (res) => {
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
    if (payload) {
      req.write(payload);
    }
    req.end();
  });
}

async function runSimulation() {
  console.log('=== [PHASE 4] Starting Live Manufacturing & Production Simulation ===\n');

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
  console.log('   Authenticated successfully. Token acquired.\n');

  // Step 2: Fetch category & unit
  console.log('2. Fetching category and measurement units...');
  const catRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/masters/categories?type=rawMaterial',
    method: 'GET',
    headers: authHeaders,
  });
  const categoryId = catRes.data?.data?.[0]?.id;

  const fpCatRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/masters/categories?type=finishedProduct',
    method: 'GET',
    headers: authHeaders,
  });
  const fpCategoryId = fpCatRes.data?.data?.[0]?.id || categoryId;

  const unitRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/masters/units',
    method: 'GET',
    headers: authHeaders,
  });
  const unitId = unitRes.data?.data?.[0]?.id;

  if (!categoryId || !unitId) {
    throw new Error('Category or unit missing in masters.');
  }

  // Step 3: Create dedicated test Raw Material & Finished Product
  const rand = Date.now().toString().slice(-5);
  console.log('3. Setting up dedicated test raw material and finished product...');

  const rmRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/masters/raw-materials',
      method: 'POST',
      headers: authHeaders,
    },
    {
      itemCode: `RM-PRD-${rand}`,
      name: `Sim Alloy Rod ${rand}`,
      categoryId: categoryId,
      unitId: unitId,
      minimumStock: 10,
      reorderLevel: 20,
      defaultPurchasePrice: 200.0,
      gstPercent: 18.0,
    }
  );

  if (rmRes.status !== 201) {
    throw new Error(`Raw material creation failed: ${JSON.stringify(rmRes.data)}`);
  }
  const testRm = rmRes.data.data;
  console.log(`   -> Created Test Raw Material: ${testRm.name} (ID: ${testRm.id})`);

  const fpRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/masters/finished-products',
      method: 'POST',
      headers: authHeaders,
    },
    {
      itemCode: `FP-PRD-${rand}`,
      name: `Sim Cabinet Handle ${rand}`,
      categoryId: fpCategoryId,
      unitId: unitId,
      minimumStock: 5,
      dealerSellingPrice: 400.0,
      customerSellingPrice: 450.0,
      gstPercent: 18.0,
    }
  );

  if (fpRes.status !== 201) {
    throw new Error(`Finished product creation failed: ${JSON.stringify(fpRes.data)}`);
  }
  const testFp = fpRes.data.data;
  console.log(`   -> Created Test Finished Product: ${testFp.name} (ID: ${testFp.id})`);

  // Step 4: Add Initial Stock to Raw Material via Adjustment
  console.log('\n4. Inwarding initial stock to test raw material...');
  const initialInwardQty = 50.0;
  const adjRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/inventory/stock-adjustments',
      method: 'POST',
      headers: authHeaders,
    },
    {
      itemId: testRm.id,
      itemType: 'rawMaterial',
      adjustedStockAfter: initialInwardQty,
      reason: 'revaluation',
      remarks: 'Initial setup for Phase 4 production simulation',
    }
  );

  if (adjRes.status !== 201) {
    throw new Error(`Stock adjustment failed: ${JSON.stringify(adjRes.data)}`);
  }
  console.log(`   -> Inwarded ${initialInwardQty} units of raw material. Stock ready.`);

  // Step 5: Test BOM creation and retrieval
  console.log('\n5. Testing Bill of Materials (BOM) recipe creation & retrieval...');
  const saveBomRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/production/bom',
      method: 'POST',
      headers: authHeaders,
    },
    {
      finishedProductId: testFp.id,
      name: `Standard BOM Recipe for ${testFp.name}`,
      description: 'BOM recipe for simulation test product',
      items: [
        {
          rawMaterialId: testRm.id,
          rawMaterialName: testRm.name,
          rawMaterialCode: testRm.itemCode,
          quantityPerUnit: 2.5,
          unit: 'kg',
        },
      ],
    }
  );

  if (saveBomRes.status !== 200 && saveBomRes.status !== 201) {
    throw new Error(`BOM save failed: ${JSON.stringify(saveBomRes.data)}`);
  }

  const getBomRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/production/bom/${testFp.id}`,
    method: 'GET',
    headers: authHeaders,
  });

  if (getBomRes.status !== 200 || !getBomRes.data?.data?.items?.length) {
    throw new Error(`BOM retrieval failed: ${JSON.stringify(getBomRes.data)}`);
  }
  console.log(`   -> Verified BOM recipe: ${getBomRes.data.data.items.length} item(s) mapped.`);

  // Step 6: Create Completed Production Order (1-step execution)
  console.log('\n6. Executing 1-step Completed Production Order...');
  const consumeQty = 10.0;
  const produceQty = 4.0;
  const unitCost = 200.0;
  const rawMaterialCost = consumeQty * unitCost; // 2000
  const labourCost = 300.0;
  const otherExpenses = 100.0;
  const totalCost = rawMaterialCost + labourCost + otherExpenses; // 2400
  const costPerUnit = totalCost / produceQty; // 600

  const orderPayload = {
    finishedProductId: testFp.id,
    plannedQuantity: produceQty,
    actualQuantityProduced: produceQty,
    status: 'completed',
    rawMaterialCost: rawMaterialCost,
    labourCost: labourCost,
    otherExpenses: otherExpenses,
    productionDate: new Date().toISOString(),
    notes: 'Live simulation automated production test',
    rawMaterialsUsed: [
      {
        rawMaterialId: testRm.id,
        quantityUsed: consumeQty,
        unitCost: unitCost,
      },
    ],
  };

  const createOrderRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/production/orders',
      method: 'POST',
      headers: authHeaders,
    },
    orderPayload
  );

  if (createOrderRes.status !== 201) {
    throw new Error(`Order creation failed: ${JSON.stringify(createOrderRes.data)}`);
  }

  const createdOrder = createOrderRes.data.data;
  console.log(`   -> Order created: ID ${createdOrder.id}, Number ${createdOrder.productionNumber}`);
  console.log(`   -> Cost per unit: ₹${createdOrder.costPerUnit} (Total: ₹${createdOrder.totalProductionCost})`);

  // Step 7: Verify Stock in Database
  console.log('\n7. Verifying atomic stock adjustments in database...');
  const updatedRmRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/masters/raw-materials/${testRm.id}`,
    method: 'GET',
    headers: authHeaders,
  });
  const updatedFpRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/masters/finished-products/${testFp.id}`,
    method: 'GET',
    headers: authHeaders,
  });

  const curRmStock = Number(updatedRmRes.data.data.currentStock ?? updatedRmRes.data.data.current_stock);
  const curFpStock = Number(updatedFpRes.data.data.currentStock ?? updatedFpRes.data.data.current_stock);

  console.log(`   -> Raw Material Stock: ${initialInwardQty} - ${consumeQty} = ${curRmStock} (Expected: ${initialInwardQty - consumeQty})`);
  console.log(`   -> Finished Good Stock: 0 + ${produceQty} = ${curFpStock} (Expected: ${produceQty})`);

  if (Math.abs(curRmStock - (initialInwardQty - consumeQty)) > 0.01) {
    throw new Error(`Raw material stock deduction mismatch!`);
  }
  if (Math.abs(curFpStock - produceQty) > 0.01) {
    throw new Error(`Finished good stock increment mismatch!`);
  }
  console.log('   -> Atomic stock calculations verified 100% accurate!');

  // Step 8: Verify Ledger Movements
  console.log('\n8. Verifying immutable stock ledger movements...');
  const movementsRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/inventory/stock-movements?search=${encodeURIComponent(createdOrder.productionNumber)}`,
    method: 'GET',
    headers: authHeaders,
  });

  const movements = movementsRes.data?.data?.items || movementsRes.data?.data?.movements || [];
  console.log(`   -> Found ${movements.length} ledger movement(s) matching ${createdOrder.productionNumber}`);

  if (movements.length < 2) {
    throw new Error(`Expected at least 2 stock movements (consumption & output), found ${movements.length}`);
  }
  console.log('   -> Stock ledger movements verified!');

  // Step 9: Cancel Production Order and Rollback Stock
  console.log('\n9. Cancelling production order and verifying inventory rollback...');
  const cancelRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/production/orders/${createdOrder.id}`,
      method: 'DELETE',
      headers: authHeaders,
    },
    { reason: 'Simulation cancellation & stock rollback test' }
  );

  if (cancelRes.status !== 200) {
    throw new Error(`Order cancellation failed: ${JSON.stringify(cancelRes.data)}`);
  }

  const rolledBackRmRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/masters/raw-materials/${testRm.id}`,
    method: 'GET',
    headers: authHeaders,
  });
  const rolledBackFpRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/masters/finished-products/${testFp.id}`,
    method: 'GET',
    headers: authHeaders,
  });

  const rolledBackRmStock = Number(rolledBackRmRes.data.data.currentStock ?? rolledBackRmRes.data.data.current_stock);
  const rolledBackFpStock = Number(rolledBackFpRes.data.data.currentStock ?? rolledBackFpRes.data.data.current_stock);

  console.log(`   -> RM Stock after cancellation: ${rolledBackRmStock} (Expected original: ${initialInwardQty})`);
  console.log(`   -> FP Stock after cancellation: ${rolledBackFpStock} (Expected original: 0)`);

  if (Math.abs(rolledBackRmStock - initialInwardQty) > 0.01) {
    throw new Error(`RM rollback mismatch! Expected ${initialInwardQty}, got ${rolledBackRmStock}`);
  }
  if (Math.abs(rolledBackFpStock - 0) > 0.01) {
    throw new Error(`FP rollback mismatch! Expected 0, got ${rolledBackFpStock}`);
  }
  console.log('   -> Transactional rollback verified 100% accurate!');

  // Step 10: Deterministic Database Cleanup
  console.log('\n10. Executing deterministic cleanup of simulation test records...');
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgresql://postgres.clhyeyeykckjexwghghm:Pks%40%24123456@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres',
    ssl: { rejectUnauthorized: false },
  });

  try {
    await pool.query('DELETE FROM stock_movements WHERE reference_number = $1 OR item_id IN ($2, $3)', [
      createdOrder.productionNumber,
      testRm.id,
      testFp.id,
    ]);
    await pool.query('DELETE FROM stock_adjustments WHERE item_id = $1', [testRm.id]);
    await pool.query('DELETE FROM production_raw_materials WHERE production_order_id = $1', [createdOrder.id]);
    await pool.query('DELETE FROM production_orders WHERE id = $1', [createdOrder.id]);
    await pool.query('DELETE FROM bill_of_materials WHERE finished_product_id = $1', [testFp.id]);
    await pool.query('DELETE FROM finished_products WHERE id = $1', [testFp.id]);
    await pool.query('DELETE FROM raw_materials WHERE id = $1', [testRm.id]);
    console.log('   -> All simulation test entities cleaned up. Zero database pollution.');
  } finally {
    await pool.end();
  }

  console.log('\n================================================================');
  console.log('🎉 [PHASE 4 SUCCESS] ALL MANUFACTURING & PRODUCTION CRUD SIMULATIONS PASSED 100%!');
  console.log('================================================================\n');
}

runSimulation().catch((err) => {
  console.error('\n❌ SIMULATION FAILED:', err);
  process.exit(1);
});
