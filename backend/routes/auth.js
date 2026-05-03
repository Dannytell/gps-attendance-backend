const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../db');

// Resend Email Helper
const sendEmail = async (to, subject, html) => {
  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: 'NEO-EDU <onboarding@resend.dev>',
        to: to,
        subject: subject,
        html: html
      })
    });
    const data = await response.json();
    console.log('Resend API Response:', data);
    return data;
  } catch (err) {
    console.error('Resend API Error:', err);
  }
};

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
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  if (!req.body) return res.status(400).json({ error: 'Missing request body' });
  const { id_number, password, role } = req.body;
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
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiry = new Date(Date.now() + 3 * 60000);

    let updateQuery = '';
    if (role === 'lecturer') {
      updateQuery = 'UPDATE lecturers SET otp_code = $1, otp_expiry = $2 WHERE id = $3';
    } else {
      updateQuery = 'UPDATE students SET otp_code = $1, otp_expiry = $2 WHERE id = $3';
    }
    await db.query(updateQuery, [otp, expiry, user.id]);

    // Send via Resend (No port needed, works on port 443)
    sendEmail(
      user.email,
      'NEO-EDU Password Reset OTP',
      `<div style="font-family: sans-serif; background-color: #1A1C29; color: white; padding: 30px; border-radius: 10px;">
        <h2 style="color: #00F0FF; margin-top: 0;">PASSWORD RESET</h2>
        <p>Your password reset code is: <strong>${otp}</strong></p>
      </div>`
    );

    res.json({ success: true, message: 'OTP sent to your email' });
  } catch (err) {
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
    let updateQuery = role === 'lecturer' ? 
      'UPDATE lecturers SET password_hash = $1, otp_code = NULL, otp_expiry = NULL WHERE id = $2' :
      'UPDATE students SET password_hash = $1, otp_code = NULL, otp_expiry = NULL WHERE id = $2';
    
    await db.query(updateQuery, [hashedPassword, user.id]);
    res.json({ success: true, message: 'Password reset successful' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to reset password' });
  }
});

module.exports = router;
