import * as fs from 'fs';
import * as path from 'path';
import { Pool } from 'pg';

export interface MigrationRecord {
  id: number;
  name: string;
  applied_at: Date;
}

export class Migrator {
  private readonly pool: Pool;
  private readonly migrationsDir: string;

  constructor(pool: Pool, migrationsDir?: string) {
    this.pool = pool;
    this.migrationsDir = migrationsDir || path.resolve(process.cwd(), 'migrations');
  }

  async ensureMigrationsTable(): Promise<void> {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS _migrations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);
  }

  async getAppliedMigrations(): Promise<MigrationRecord[]> {
    await this.ensureMigrationsTable();
    const result = await this.pool.query<MigrationRecord>(
      'SELECT id, name, applied_at FROM _migrations ORDER BY id ASC;',
    );
    return result.rows;
  }

  getMigrationFiles(): string[] {
    if (!fs.existsSync(this.migrationsDir)) {
      return [];
    }
    return fs
      .readdirSync(this.migrationsDir)
      .filter((file) => file.endsWith('.sql'))
      .sort();
  }

  async up(): Promise<{ applied: string[]; alreadyUpToDate: boolean }> {
    await this.ensureMigrationsTable();
    const applied = await this.getAppliedMigrations();
    const appliedNames = new Set(applied.map((m) => m.name));

    const files = this.getMigrationFiles();
    const pendingFiles = files.filter((file) => !appliedNames.has(file));

    if (pendingFiles.length === 0) {
      return { applied: [], alreadyUpToDate: true };
    }

    const appliedThisRun: string[] = [];

    for (const file of pendingFiles) {
      const filePath = path.join(this.migrationsDir, file);
      const sql = fs.readFileSync(filePath, 'utf-8');

      const client = await this.pool.connect();
      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('INSERT INTO _migrations (name) VALUES ($1)', [file]);
        await client.query('COMMIT');
        appliedThisRun.push(file);
      } catch (err) {
        await client.query('ROLLBACK');
        throw new Error(`Migration ${file} failed: ${(err as Error).message}`);
      } finally {
        client.release();
      }
    }

    return { applied: appliedThisRun, alreadyUpToDate: false };
  }

  async status(): Promise<Array<{ file: string; applied: boolean; appliedAt?: Date }>> {
    await this.ensureMigrationsTable();
    const applied = await this.getAppliedMigrations();
    const appliedMap = new Map(applied.map((m) => [m.name, m.applied_at]));

    const files = this.getMigrationFiles();
    return files.map((file) => ({
      file,
      applied: appliedMap.has(file),
      appliedAt: appliedMap.get(file),
    }));
  }
}
