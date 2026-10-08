import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import dataSource from './data-source';

/**
 * Loads database/seeds/dev-sample-vendors.sql (M12): fake vendors for
 * trying discovery locally. The SQL itself refuses any database whose name
 * does not end in _dev or _test, so it can never fill production.
 */
async function main(): Promise<void> {
  const sql = readFileSync(
    join(
      __dirname,
      '..',
      '..',
      '..',
      'database',
      'seeds',
      'dev-sample-vendors.sql',
    ),
    'utf8',
  );
  await dataSource.initialize();
  try {
    await dataSource.query(sql);
    const [{ count }] = await dataSource.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM vendor_listings WHERE id::text LIKE '5c000000-%'`,
    );
    console.log(`Sample listings present: ${count}`);
  } finally {
    await dataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
