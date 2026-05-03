const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const db = require('../db');

const transporter = nodemailer.createTransport({
  host: '142.250.110.109',
  port: 465,
  secure: true,
  auth: {
    user: process.env.SMTP_EMAIL,
    pass: process.env.SMTP_PASSWORD
  },
  tls: {
    rejectUnauthorized: false
  }
});

// Register Lecturer
router.post('/register/lecturer', async (req, res) => {
  const { staff_id, full_name, email, password } = req.body;
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const result = await db.query(
      'INSERT INTO lecturers (staff_id, full_name, email, password_hash) VALUES ($1, $2, $3, $4) RETURNING id, staff_id, full_name',
      [staff_id, full_name, email, hashedPassword]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Register Student
router.post('/register/student', async (req, res) => {
  const { university_id, full_name, email, password } = req.body;
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const result = await db.query(
      'INSERT INTO students (university_id, full_name, email, password_hash) VALUES ($1, $2, $3, $4) RETURNING id, university_id, full_name',
      [university_id, full_name, email, hashedPassword]
    );

    const newStudentId = result.rows[0].id;

    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  if (!req.body) return res.status(400).json({ error: 'Missing request body' });
  const { id_number, password, role } = req.body; // role: 'lecturer' or 'student'
  try {
    let userQuery = '';
    if (role === 'lecturer') {
      userQuery = 'SELECT * FROM lecturers WHERE UPPER(staff_id) = UPPER($1)';
    } else {
      userQuery = 'SELECT * FROM students WHERE UPPER(university_id) = UPPER($1)';
    }

    const { rows } = await db.query(userQuery, [id_number]);
    if (rows.length === 0) return res.status(401).json({ error: 'Invalid credentials' });

    const user = rows[0];
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) return res.status(401).json({ error: 'Invalid credentials' });

    const token = jwt.sign({ id: user.id, role }, process.env.JWT_SECRET, { expiresIn: '1d' });
    res.json({ token, user: { id: user.id, name: user.full_name, role } });
  } catch (err) {
    console.error('LOGIN ERROR:', err);
    res.status(500).json({ error: err.message });
  }
});

// Forgot Password
router.post('/forgot-password', async (req, res) => {
  const { id_number, role } = req.body;
  try {
    let userQuery = '';
    if (role === 'lecturer') {
      userQuery = 'SELECT * FROM lecturers WHERE UPPER(staff_id) = UPPER($1)';
    } else {
      userQuery = 'SELECT * FROM students WHERE UPPER(university_id) = UPPER($1)';
    }

    const { rows } = await db.query(userQuery, [id_number]);
    if (rows.length === 0) return res.status(404).json({ error: 'User not found' });

    const user = rows[0];
    if (!user.email) return res.status(400).json({ error: 'No email associated with this account' });

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiry = new Date(Date.now() + 3 * 60000); // 3 mins

    let updateQuery = '';
    if (role === 'lecturer') {
      updateQuery = 'UPDATE lecturers SET otp_code = $1, otp_expiry = $2 WHERE id = $3';
    } else {
      updateQuery = 'UPDATE students SET otp_code = $1, otp_expiry = $2 WHERE id = $3';
    }
    await db.query(updateQuery, [otp, expiry, user.id]);

    // Send Email in background (do not await)
    transporter.sendMail({
      from: `"NEO-EDU Support" <${process.env.SMTP_EMAIL}>`,
      to: user.email,
      subject: 'NEO-EDU Password Reset OTP',
      text: `Your password reset code is: ${otp}. It will expire in 3 minutes.`,
      html: `
        <div style="font-family: sans-serif; background-color: #1A1C29; color: white; padding: 30px; border-radius: 10px;">
          <h2 style="color: #00F0FF; margin-top: 0;">PASSWORD RESET</h2>
          <p>We received a request to reset your NEO-EDU password.</p>
          <div style="background-color: rgba(255, 0, 60, 0.1); border: 1px solid #FF003C; padding: 15px; text-align: center; font-size: 24px; letter-spacing: 5px; margin: 20px 0;">
            <strong>${otp}</strong>
          </div>
          <p>This code expires in 3 minutes. Do not share it with anyone.</p>
        </div>
      `
    }).catch(err => console.error('Background Email Error:', err));

    res.json({ success: true, message: 'OTP sent to your email' });
  } catch (err) {
    console.error('FORGOT PWD ERROR:', err);
    res.status(500).json({ error: 'Failed to process request' });
  }
});

// Reset Password
router.post('/reset-password', async (req, res) => {
  const { id_number, role, otp, new_password } = req.body;
  try {
    let userQuery = '';
    if (role === 'lecturer') {
      userQuery = 'SELECT * FROM lecturers WHERE UPPER(staff_id) = UPPER($1)';
    } else {
      userQuery = 'SELECT * FROM students WHERE UPPER(university_id) = UPPER($1)';
    }

    const { rows } = await db.query(userQuery, [id_number]);
    if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
    const user = rows[0];

    if (!user.otp_code || user.otp_code !== otp || new Date() > new Date(user.otp_expiry)) {
      return res.status(400).json({ error: 'Invalid or expired OTP' });
    }

    const hashedPassword = await bcrypt.hash(new_password, 10);
    let updateQuery = '';
    if (role === 'lecturer') {
      updateQuery = 'UPDATE lecturers SET password_hash = $1, otp_code = NULL, otp_expiry = NULL WHERE id = $2';
    } else {
      updateQuery = 'UPDATE students SET password_hash = $1, otp_code = NULL, otp_expiry = NULL WHERE id = $2';
    }
    await db.query(updateQuery, [hashedPassword, user.id]);

    res.json({ success: true, message: 'Password reset successful' });
  } catch (err) {
    console.error('RESET PWD ERROR:', err);
    res.status(500).json({ error: 'Failed to reset password' });
  }
});

module.exports = router;
