require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000,
});

async function migrateV2() {
  const client = await pool.connect();
  try {
    console.log('=== GPS App Migration V2 ===\n');

    // 1. Ensure session_date has a DEFAULT so it is never null
    console.log('[1] Fixing sessions.session_date default...');
    await client.query(`
      ALTER TABLE sessions
        ALTER COLUMN session_date SET DEFAULT CURRENT_DATE;
    `).catch(() => {
      // Column may not exist yet — create it with a default
    });

    // Also add session_date column if it does not exist at all
    const sdCheck = await client.query(`
      SELECT column_name FROM information_schema.columns
      WHERE table_name = 'sessions' AND column_name = 'session_date'
    `);
    if (sdCheck.rows.length === 0) {
      await client.query(`ALTER TABLE sessions ADD COLUMN session_date DATE NOT NULL DEFAULT CURRENT_DATE`);
      console.log('  ✓ sessions.session_date added with default');
    } else {
      // Set default on existing column (idempotent)
      await client.query(`ALTER TABLE sessions ALTER COLUMN session_date SET DEFAULT CURRENT_DATE`);
      // Also backfill any NULLs that crept in
      await client.query(`UPDATE sessions SET session_date = CURRENT_DATE WHERE session_date IS NULL`);
      console.log('  ✓ sessions.session_date default set + NULLs backfilled');
    }

    // 2. Add session_lat / session_lon to sessions for per-session location override
    console.log('[2] Adding session_lat / session_lon to sessions...');
    const latCheck = await client.query(`
      SELECT column_name FROM information_schema.columns
      WHERE table_name = 'sessions' AND column_name = 'session_lat'
    `);
    if (latCheck.rows.length === 0) {
      await client.query(`ALTER TABLE sessions ADD COLUMN session_lat DOUBLE PRECISION DEFAULT 0`);
      await client.query(`ALTER TABLE sessions ADD COLUMN session_lon DOUBLE PRECISION DEFAULT 0`);
      console.log('  ✓ sessions.session_lat / session_lon added');
    } else {
      console.log('  - sessions.session_lat already exists');
    }

    // 3. Add file_url to announcements
    console.log('[3] Adding file_url to announcements...');
    const fuCheck = await client.query(`
      SELECT column_name FROM information_schema.columns
      WHERE table_name = 'announcements' AND column_name = 'file_url'
    `);
    if (fuCheck.rows.length === 0) {
      await client.query(`ALTER TABLE announcements ADD COLUMN file_url TEXT`);
      console.log('  ✓ announcements.file_url added');
    } else {
      console.log('  - announcements.file_url already exists');
    }

    // 4. Create enrollments table if missing (students need to be enrolled for notifications)
    console.log('[4] Ensuring enrollments table exists...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS enrollments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        student_id UUID REFERENCES students(id) ON DELETE CASCADE,
        class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
        enrolled_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(student_id, class_id)
      );
    `);
    console.log('  ✓ enrollments table ensured');

    // 5. Auto-enroll test student STU001 in all classes (dev convenience)
    console.log('[5] Auto-enrolling test student in all classes...');
    const stuRes = await client.query(`SELECT id FROM students WHERE university_id = 'STU001'`);
    const classRes = await client.query(`SELECT id FROM classes`);
    if (stuRes.rows.length > 0 && classRes.rows.length > 0) {
      for (const cls of classRes.rows) {
        await client.query(`
          INSERT INTO enrollments (student_id, class_id)
          VALUES ($1, $2) ON CONFLICT DO NOTHING
        `, [stuRes.rows[0].id, cls.id]);
      }
      console.log(`  ✓ STU001 enrolled in ${classRes.rows.length} class(es)`);
    } else {
      console.log('  - No test student or classes found, skipping');
    }

    console.log('\n✅ Migration V2 complete!');
  } catch (err) {
    console.error('Migration V2 failed:', err.message);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

migrateV2();
