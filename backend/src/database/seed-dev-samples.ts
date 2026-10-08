import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import dataSource from './data-source';

/**
 * Loads a dev/test sample script from database/seeds/: fake vendors (M12,
 * default) or, with SEED_FILE=dev-sample-quotes.sql, sample quotes (M15).
 * The SQL itself refuses any database whose name does not end in _dev or
 * _test, so it can never fill production.
 */
const ALLOWED = ['dev-sample-vendors.sql', 'dev-sample-quotes.sql'];

function seedFile(): string {
  const file = process.env.SEED_FILE ?? 'dev-sample-vendors.sql';
  if (!ALLOWED.includes(file)) throw new Error(`Unknown seed file ${file}`);
  return file;
}

async function main(): Promise<void> {
  const sql = readFileSync(
    join(__dirname, '..', '..', '..', 'database', 'seeds', seedFile()),
    'utf8',
  );
  await dataSource.initialize();
  try {
    await dataSource.query(sql);
    const [{ listings, quotes }] = await dataSource.query<
      { listings: number; quotes: number }[]
    >(
      `SELECT (SELECT count(*)::int FROM vendor_listings WHERE id::text LIKE '5c000000-%') AS listings,
              (SELECT count(*)::int FROM quotations WHERE status = 'SENT') AS quotes`,
    );
    console.log(`Sample listings: ${listings}; quotes waiting: ${quotes}`);
  } finally {
    await dataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
