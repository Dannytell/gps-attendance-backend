require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000,
});

async function migrateV4() {
  const client = await pool.connect();
  try {
    console.log('Starting Migration V4...');

    // Add OTP columns to lecturers table
    console.log('Checking for otp_code in lecturers table...');
    const otpCheck = await client.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_name = 'lecturers' AND column_name = 'otp_code'
    `);
    
    if (otpCheck.rows.length === 0) {
      await client.query(`ALTER TABLE lecturers ADD COLUMN otp_code VARCHAR(10)`);
      await client.query(`ALTER TABLE lecturers ADD COLUMN otp_expiry TIMESTAMPTZ`);
      console.log('  ✓ OTP columns added to lecturers');
    } else {
      console.log('  - OTP columns already exist in lecturers');
    }

    console.log('Migration V4 Completed Successfully!');
  } catch (err) {
    console.error('Migration V4 Failed:', err);
  } finally {
    client.release();
    pool.end();
  }
}

migrateV4();
