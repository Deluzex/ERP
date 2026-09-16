import * as dotenv from 'dotenv';
import { Pool } from 'pg';
import { Migrator } from './migrator';

dotenv.config();

async function run(): Promise<void> {
  const command = process.argv[2] || 'up';
  const connectionString =
    process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/deluzex_erp';

  const isSsl =
    connectionString.includes('supabase.com') ||
    connectionString.includes('supabase.co') ||
    connectionString.includes('sslmode=require') ||
    process.env.DATABASE_SSL === 'true';

  const pool = new Pool({
    connectionString,
    ssl: isSsl ? { rejectUnauthorized: false } : undefined,
  });
  const migrator = new Migrator(pool);

  try {
    if (command === 'up') {
      console.log('🚀 Running database migrations...');
      const result = await migrator.up();
      if (result.alreadyUpToDate) {
        console.log('✅ Database is already up to date. No pending migrations.');
      } else {
        console.log(`✅ Successfully applied ${result.applied.length} migration(s):`);
        for (const name of result.applied) {
          console.log(`   - ${name}`);
        }
      }
    } else if (command === 'status') {
      console.log('📋 Checking database migration status...');
      const status = await migrator.status();
      console.table(
        status.map((s) => ({
          Migration: s.file,
          Status: s.applied ? 'APPLIED' : 'PENDING',
          AppliedAt: s.appliedAt ? s.appliedAt.toISOString() : '-',
        })),
      );
    } else {
      console.error(`Unknown command: "${command}". Available commands: "up", "status".`);
      process.exit(1);
    }
  } catch (error: any) {
    const msg = error?.message || (typeof error === 'object' ? JSON.stringify(error) : String(error));
    console.error('❌ Migration failed:', msg);
    if (error?.code === 'ECONNREFUSED') {
      console.error('👉 Tip: Ensure PostgreSQL is running on the configured DATABASE_URL.');
    }
    process.exit(1);
  } finally {
    await pool.end();
  }
}

run();
