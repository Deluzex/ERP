// ============================================================================
// verify_rbac_live_crud.js
// Automated End-to-End Simulation of RBAC Full CRUD against Live Backend Server
// ============================================================================

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { Pool } = require('pg');

const BASE_URL = 'http://localhost:3000/api/v1';

async function run() {
  console.log('=== [RBAC MODULE] Starting Live User & Role CRUD Simulation ===\n');

  // 1. Authenticate as Super Admin
  console.log('1. Authenticating as Super Admin...');
  const loginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@deluzex.com', password: 'Admin@123' }),
  });
  if (!loginRes.ok) throw new Error(`Auth failed: ${loginRes.status} ${await loginRes.text()}`);
  const loginData = (await loginRes.json()).data;
  const token = loginData.accessToken;
  console.log(`   ✅ Admin authenticated! User: ${loginData.user.email}`);

  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  // 2. Fetch Catalogue
  console.log('2. Fetching Permissions Catalogue...');
  const catRes = await fetch(`${BASE_URL}/roles/permissions/catalogue`, { headers: authHeaders });
  const catData = (await catRes.json()).data;
  console.log(`   ✅ Permissions Catalogue retrieved! Total canonical permissions: ${catData.length}`);

  // 3. Create Custom Role
  const timestamp = Date.now();
  const testRoleId = `qa_officer_${timestamp}`;
  console.log(`3. Creating Custom Role: ${testRoleId}...`);
  const createRoleRes = await fetch(`${BASE_URL}/roles`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      id: testRoleId,
      name: 'QA Inspection Officer',
      description: 'Quality checks on production batches',
      defaultDashboardSection: 'production',
      permissions: ['production.view', 'production.edit', 'inventory.view'],
    }),
  });
  if (!createRoleRes.ok) throw new Error(`Role creation failed: ${createRoleRes.status} ${await createRoleRes.text()}`);
  const createdRole = (await createRoleRes.json()).data;
  console.log(`   ✅ Custom Role created: ${createdRole.name} [${createdRole.id}]`);

  // 4. Update Role Metadata
  console.log('4. Updating Custom Role Metadata...');
  const updateRoleRes = await fetch(`${BASE_URL}/roles/${testRoleId}`, {
    method: 'PUT',
    headers: authHeaders,
    body: JSON.stringify({
      name: 'Senior QA Specialist',
      description: 'Advanced oversight of production quality',
      defaultDashboardSection: 'inventory',
    }),
  });
  if (!updateRoleRes.ok) throw new Error(`Role update failed: ${updateRoleRes.status} ${await updateRoleRes.text()}`);
  const updatedRole = (await updateRoleRes.json()).data;
  console.log(`   ✅ Role metadata updated: ${updatedRole.name} (default section: ${updatedRole.defaultDashboardSection})`);

  // 5. Update Permissions Matrix
  console.log('5. Updating Custom Role Permissions Matrix...');
  const updatePermsRes = await fetch(`${BASE_URL}/roles/${testRoleId}/permissions`, {
    method: 'PUT',
    headers: authHeaders,
    body: JSON.stringify({
      permissions: ['production.view', 'production.edit', 'inventory.view', 'inventory.edit', 'masters.view'],
    }),
  });
  if (!updatePermsRes.ok) throw new Error(`Permissions update failed: ${updatePermsRes.status} ${await updatePermsRes.text()}`);
  const updatedPermsData = (await updatePermsRes.json()).data;
  console.log(`   ✅ Permissions matrix updated! Total assigned permissions: ${updatedPermsData.permissions.length}`);

  // 6. Create User with Primary & Secondary Roles
  const testEmail = `qa_officer_${timestamp}@deluzex.test`;
  console.log(`6. Creating User with multi-role assignment: ${testEmail}...`);
  const createUserRes = await fetch(`${BASE_URL}/users`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      name: 'Test Officer Patel',
      email: testEmail,
      mobile: '9876543210',
      password: 'InitialPassword@123',
      roleId: testRoleId,
      assignedRoleIds: [testRoleId, 'data_entry'],
    }),
  });
  if (!createUserRes.ok) throw new Error(`User creation failed: ${createUserRes.status} ${await createUserRes.text()}`);
  const createdUser = (await createUserRes.json()).data;
  console.log(`   ✅ User created! ID: ${createdUser.id}, Primary: ${createdUser.roleId}, Assigned: ${createdUser.assignedRoleIds.join(', ')}`);

  // 7. Admin Password Reset
  console.log('7. Performing Admin Password Reset...');
  const resetRes = await fetch(`${BASE_URL}/users/${createdUser.id}/reset-password`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      newPassword: 'BrandNewSecretPassword@999',
    }),
  });
  if (!resetRes.ok) throw new Error(`Password reset failed: ${resetRes.status} ${await resetRes.text()}`);
  console.log('   ✅ Admin password reset succeeded!');

  // 8. Test Login with New Password
  console.log('8. Verifying User Login with New Password...');
  const userLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: testEmail, password: 'BrandNewSecretPassword@999' }),
  });
  if (!userLoginRes.ok) throw new Error(`New password login failed: ${userLoginRes.status}`);
  console.log('   ✅ User successfully logged in with newly reset password!');

  // 9. Safety Guard: Reject Deleting Role in Use
  console.log('9. Verifying Safety Guard: Delete role assigned to active user...');
  const delRoleFailRes = await fetch(`${BASE_URL}/roles/${testRoleId}`, {
    method: 'DELETE',
    headers: authHeaders,
  });
  if (delRoleFailRes.status === 400) {
    const errBody = await delRoleFailRes.json();
    console.log(`   ✅ Safety guard active! Rejected deletion: "${errBody.error.message}"`);
  } else {
    throw new Error(`Expected 400 for in-use role delete, got: ${delRoleFailRes.status}`);
  }

  // 10. Reassign User Role
  console.log('10. Reassigning User Role to permit role deletion...');
  const reassignRes = await fetch(`${BASE_URL}/users/${createdUser.id}`, {
    method: 'PUT',
    headers: authHeaders,
    body: JSON.stringify({
      roleId: 'data_entry',
      assignedRoleIds: ['data_entry'],
    }),
  });
  if (!reassignRes.ok) throw new Error(`Reassignment failed: ${reassignRes.status}`);
  console.log('   ✅ User reassigned away from custom role.');

  // 11. Delete Custom Role
  console.log('11. Deleting Custom Role...');
  const delRoleRes = await fetch(`${BASE_URL}/roles/${testRoleId}`, {
    method: 'DELETE',
    headers: authHeaders,
  });
  if (!delRoleRes.ok) throw new Error(`Role deletion failed: ${delRoleRes.status}`);
  console.log('   ✅ Custom Role successfully deleted!');

  // 12. Deactivate User
  console.log('12. Deactivating Test User...');
  const delUserRes = await fetch(`${BASE_URL}/users/${createdUser.id}`, {
    method: 'DELETE',
    headers: authHeaders,
  });
  if (!delUserRes.ok) throw new Error(`User deactivation failed: ${delUserRes.status}`);
  console.log('   ✅ User deactivated!');

  // 13. Deterministic DB Cleanup
  console.log('13. Performing Deterministic Database Cleanup...');
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  });
  try {
    await pool.query('DELETE FROM user_roles WHERE user_id = $1', [createdUser.id]);
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [createdUser.id]);
    await pool.query('DELETE FROM users WHERE id = $1', [createdUser.id]);
    await pool.query('DELETE FROM roles WHERE id = $1', [testRoleId]);
    console.log('   ✅ Database 100% clean, zero test pollution remaining.\n');
  } finally {
    await pool.end();
  }

  console.log('🎉 === [PHASE COMPLETE] RBAC Full CRUD Simulation: 100% SUCCESS === 🎉');
}

run().catch((err) => {
  console.error('\n❌ RBAC Simulation Failed:', err.message);
  process.exit(1);
});
