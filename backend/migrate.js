require('dotenv').config();
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000,
});

async function migrate() {
  const client = await pool.connect();
  try {
    // 1. Create lecturers table
    console.log('Creating lecturers table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS lecturers (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        staff_id VARCHAR(20) UNIQUE NOT NULL,
        full_name TEXT NOT NULL,
        email TEXT,
        password_hash TEXT NOT NULL,
        department TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ lecturers table created');

    // 2. Add lecturer_id to classes if missing
    console.log('Adding columns to classes...');
    const colCheck1 = await client.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_name = 'classes' AND column_name = 'lecturer_id'
    `);
    if (colCheck1.rows.length === 0) {
      await client.query(`ALTER TABLE classes ADD COLUMN lecturer_id UUID REFERENCES lecturers(id)`);
      console.log('  ✓ classes.lecturer_id added');
    } else {
      console.log('  - classes.lecturer_id already exists');
    }

    // 3. Add day_of_week to classes if missing
    const colCheck2 = await client.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_name = 'classes' AND column_name = 'day_of_week'
    `);
    if (colCheck2.rows.length === 0) {
      await client.query(`ALTER TABLE classes ADD COLUMN day_of_week VARCHAR(10)`);
      console.log('  ✓ classes.day_of_week added');
    } else {
      console.log('  - classes.day_of_week already exists');
    }

    // 4. Add dynamic_code to sessions if missing
    console.log('Adding columns to sessions...');
    const colCheck3 = await client.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_name = 'sessions' AND column_name = 'dynamic_code'
    `);
    if (colCheck3.rows.length === 0) {
      await client.query(`ALTER TABLE sessions ADD COLUMN dynamic_code VARCHAR(10)`);
      console.log('  ✓ sessions.dynamic_code added');
    } else {
      console.log('  - sessions.dynamic_code already exists');
    }

    // 5. Add is_active to sessions if missing
    const colCheck4 = await client.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_name = 'sessions' AND column_name = 'is_active'
    `);
    if (colCheck4.rows.length === 0) {
      await client.query(`ALTER TABLE sessions ADD COLUMN is_active BOOLEAN DEFAULT TRUE`);
      console.log('  ✓ sessions.is_active added');
    } else {
      console.log('  - sessions.is_active already exists');
    }

    // 6. Create announcements table
    console.log('Creating announcements table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS announcements (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        lecturer_id UUID REFERENCES lecturers(id),
        class_id UUID REFERENCES classes(id),
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ announcements table created');

    // 7. Insert test lecturer
    console.log('Inserting test lecturer...');
    const existing = await client.query(`SELECT id FROM lecturers WHERE staff_id = 'LEC001'`);
    if (existing.rows.length === 0) {
      const hash = await bcrypt.hash('test123', 10);
      await client.query(
        `INSERT INTO lecturers (staff_id, full_name, email, password_hash, department) 
         VALUES ('LEC001', 'Dr. Jane Smith', 'jane.smith@university.ac.ke', $1, 'Computer Science')`,
        [hash]
      );
      console.log('  ✓ Test lecturer inserted (LEC001 / test123)');
    } else {
      console.log('  - Test lecturer LEC001 already exists');
    }

    // 8. Ensure test student exists
    console.log('Checking test student...');
    const existingStudent = await client.query(`SELECT id FROM students WHERE university_id = 'STU001'`);
    if (existingStudent.rows.length === 0) {
      const hash = await bcrypt.hash('test123', 10);
      await client.query(
        `INSERT INTO students (university_id, full_name, email, password_hash) 
         VALUES ('STU001', 'John Doe', 'john.doe@university.ac.ke', $1)`,
        [hash]
      );
      console.log('  ✓ Test student inserted (STU001 / test123)');
    } else {
      console.log('  - Test student STU001 already exists');
    }

    console.log('\n✅ All migrations complete!');
  } catch (err) {
    console.error('Migration failed:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
