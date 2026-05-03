require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000,
});

async function migrateV3() {
  const client = await pool.connect();
  try {
    console.log('Starting Migration V3...');

    // Add OTP columns to students table
    console.log('Checking for otp_code in students table...');
    const otpCheck = await client.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_name = 'students' AND column_name = 'otp_code'
    `);
    
    if (otpCheck.rows.length === 0) {
      await client.query(`
        ALTER TABLE students 
        ADD COLUMN otp_code VARCHAR(10),
        ADD COLUMN otp_expiry TIMESTAMPTZ
      `);
      console.log('  ✓ students.otp_code and students.otp_expiry added');
    } else {
      console.log('  - students.otp_code already exists');
    }

    console.log('\n✅ Migration V3 complete!');
  } catch (err) {
    console.error('Migration failed:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

migrateV3();
