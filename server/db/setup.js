/** npm run db:setup          create DB if missing, apply schema, seed demo data (only if empty)
 *  npm run db:reset          drop all tables first, then the same */
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
const env = require('../src/config/env');
const { pool } = require('../src/config/db');

const reset = process.argv.includes('--reset');
const noSeed = process.argv.includes('--no-seed');

async function ensureDatabase() {
  const probe = new Client({ connectionString: env.databaseUrl, ssl: env.dbSsl ? { rejectUnauthorized: false } : undefined });
  try {
    await probe.connect();
    await probe.end();
  } catch (e) {
    if (e.code !== '3D000') throw e; // 3D000 = database does not exist
    const url = new URL(env.databaseUrl);
    const dbName = decodeURIComponent(url.pathname.slice(1));
    url.pathname = '/postgres';
    const admin = new Client({ connectionString: url.toString(), ssl: env.dbSsl ? { rejectUnauthorized: false } : undefined });
    await admin.connect();
    await admin.query(`CREATE DATABASE "${dbName.replace(/"/g, '""')}"`);
    await admin.end();
    console.log(`Created database "${dbName}"`);
  }
}

(async () => {
  try {
    await ensureDatabase();
    if (reset) {
      await pool.query('DROP TABLE IF EXISTS transactions, bids, gigs, users CASCADE');
      console.log('Dropped existing tables');
    }
    await pool.query(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8'));
    console.log('Schema ready (users, gigs, bids, transactions)');

    const { rows } = await pool.query('SELECT count(*)::int AS n FROM users');
    if (!noSeed && rows[0].n === 0) {
      await require('./seed')();
      console.log('Demo data added.  Login: aarav@ves.ac.in / demo1234  (also meera, rohan, sana @ves.ac.in)');
    } else {
      console.log('Skipped demo data (users already exist or --no-seed)');
    }

    // Ensure all demo users and gigs have media populated
    await pool.query(`
      UPDATE users SET avatar = '/api/media/avatars/aarav-sharma.svg' WHERE email = 'aarav@ves.ac.in' AND (avatar IS NULL OR avatar = '');
      UPDATE users SET avatar = '/api/media/avatars/meera-iyer.svg' WHERE email = 'meera@ves.ac.in' AND (avatar IS NULL OR avatar = '');
      UPDATE users SET avatar = '/api/media/avatars/rohan-patil.svg' WHERE email = 'rohan@ves.ac.in' AND (avatar IS NULL OR avatar = '');
      UPDATE users SET avatar = '/api/media/avatars/sana-khan.svg' WHERE email = 'sana@ves.ac.in' AND (avatar IS NULL OR avatar = '');
      UPDATE gigs SET image_url = '/api/media/gigs/fest-logo-design.svg' WHERE title ILIKE '%logo%' AND (image_url IS NULL OR image_url = '');
      UPDATE gigs SET image_url = '/api/media/gigs/react-landing-page.svg' WHERE title ILIKE '%landing page%' AND (image_url IS NULL OR image_url = '');
      UPDATE gigs SET image_url = '/api/media/gigs/resume-cleanup.svg' WHERE title ILIKE '%resume%' AND (image_url IS NULL OR image_url = '');
      UPDATE gigs SET image_url = '/api/media/gigs/hostel-reel-edit.svg' WHERE title ILIKE '%reel%' AND (image_url IS NULL OR image_url = '');
      UPDATE gigs SET image_url = '/api/media/gigs/research-paper-proofread.svg' WHERE title ILIKE '%paper%' AND (image_url IS NULL OR image_url = '');
      UPDATE gigs SET image_url = '/api/media/gigs/dsa-tutoring.svg' WHERE title ILIKE '%dsa%' AND (image_url IS NULL OR image_url = '');
      UPDATE gigs SET image_url = '/api/media/gigs/hackathon-poster.svg' WHERE title ILIKE '%poster%' AND (image_url IS NULL OR image_url = '');
      UPDATE gigs SET image_url = '/api/media/gigs/fest-logo-design.svg' WHERE image_url IS NULL OR image_url = '';
    `);
    console.log('Media synchronized for all seed users and marketplace gigs.');
  } catch (e) {
    console.error('\nSetup failed:', e.message);
    if (e.code === 'ECONNREFUSED') console.error('Postgres is not running or DATABASE_URL has the wrong host/port.');
    if (e.code === '28P01') console.error('Wrong Postgres username or password in DATABASE_URL.');
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
