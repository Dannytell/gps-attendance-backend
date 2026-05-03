const express = require('express');
const router = express.Router();
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');
const nodemailer = require('nodemailer');

// Configure nodemailer with Gmail SMTP
const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 587,
  secure: false, // true for 465, false for other ports
  auth: {
    user: process.env.SMTP_EMAIL,
    pass: process.env.SMTP_PASSWORD
  },
  tls: {
    rejectUnauthorized: false
  }
});

// Calculate distance between two coordinates in meters using Haversine formula
function getDistanceFromLatLonInM(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Get student profile
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT id, university_id, full_name, email, biometrics_enabled, selfie_required, created_at FROM students WHERE id = $1',
      [req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Student not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update student profile
router.put('/profile', authMiddleware, async (req, res) => {
  const { full_name, email } = req.body;
  try {
    const { rows } = await db.query(
      `UPDATE students SET full_name = COALESCE($1, full_name), email = COALESCE($2, email)
       WHERE id = $3 RETURNING id, university_id, full_name, email, biometrics_enabled, selfie_required`,
      [full_name, email, req.user.id]
    );
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Change student password
router.put('/password', authMiddleware, async (req, res) => {
  const { current_password, new_password } = req.body;
  if (!current_password || !new_password) {
    return res.status(400).json({ error: 'Current and new password are required.' });
  }
  if (new_password.length < 6) {
    return res.status(400).json({ error: 'New password must be at least 6 characters.' });
  }
  try {
    const { rows } = await db.query('SELECT password_hash FROM students WHERE id = $1', [req.user.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Student not found' });

    const bcrypt = require('bcrypt');
    const valid = await bcrypt.compare(current_password, rows[0].password_hash);
    if (!valid) return res.status(401).json({ error: 'Current password is incorrect.' });

    const newHash = await bcrypt.hash(new_password, 10);
    await db.query('UPDATE students SET password_hash = $1 WHERE id = $2', [newHash, req.user.id]);
    res.json({ success: true, message: 'Password updated successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get student timetable (enrolled classes)
router.get('/timetable', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT c.*, l.full_name as lecturer_name
       FROM classes c
       JOIN enrollments e ON c.id = e.class_id
       LEFT JOIN lecturers l ON c.lecturer_id = l.id
       WHERE e.student_id = $1
       ORDER BY 
        CASE c.day_of_week 
          WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3 
          WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 WHEN 'Saturday' THEN 6 WHEN 'Sunday' THEN 7 
        END, c.start_time`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get available classes to enroll in
router.get('/classes/available', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT c.*, l.full_name as lecturer_name 
       FROM classes c
       LEFT JOIN lecturers l ON c.lecturer_id = l.id
       WHERE c.id NOT IN (SELECT class_id FROM enrollments WHERE student_id = $1)`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Enroll in a class
router.post('/classes/enroll', authMiddleware, async (req, res) => {
  const { class_id } = req.body;
  if (!class_id) return res.status(400).json({ error: 'class_id is required' });
  try {
    const { rows } = await db.query(
      'INSERT INTO enrollments (student_id, class_id) VALUES ($1, $2) RETURNING *',
      [req.user.id, class_id]
    );
    res.json({ success: true, enrollment: rows[0] });
  } catch (err) {
    if (err.code === '23505') return res.status(400).json({ error: 'Already enrolled' });
    res.status(500).json({ error: err.message });
  }
});

// Drop a class
router.post('/classes/drop', authMiddleware, async (req, res) => {
  const { class_id } = req.body;
  if (!class_id) return res.status(400).json({ error: 'class_id is required' });
  try {
    await db.query(
      'DELETE FROM enrollments WHERE student_id = $1 AND class_id = $2',
      [req.user.id, class_id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get dashboard data (enrolled classes, recent attendance)
router.get('/dashboard', authMiddleware, async (req, res) => {
  try {
    const classes = await db.query(
      `SELECT c.* FROM classes c 
       JOIN enrollments e ON c.id = e.class_id 
       WHERE e.student_id = $1`,
      [req.user.id]
    );

    const attendances = await db.query(
      `SELECT a.*, c.title, c.day_of_week 
       FROM attendance_logs a 
       JOIN sessions s ON a.session_id = s.id 
       JOIN classes c ON s.class_id = c.id
       WHERE a.student_id = $1 
       ORDER BY a.signed_at DESC LIMIT 10`,
      [req.user.id]
    );

    res.json({ classes: classes.rows, attendances: attendances.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Send OTP to Student Email
router.post('/attendance/send-otp', authMiddleware, async (req, res) => {
  try {
    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    // Expiry: 3 minutes from now
    const expiry = new Date();
    expiry.setMinutes(expiry.getMinutes() + 3);

    // Save to DB
    await db.query(
      'UPDATE students SET otp_code = $1, otp_expiry = $2 WHERE id = $3',
      [otpCode, expiry, req.user.id]
    );

    // Get student email
    const { rows } = await db.query('SELECT email, full_name FROM students WHERE id = $1', [req.user.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Student not found' });
    const student = rows[0];

    // Send Email
    const mailOptions = {
      from: `"GPS Attendance App" <${process.env.SMTP_EMAIL}>`,
      to: student.email,
      subject: 'Your Attendance Verification Code',
      text: `Hello ${student.full_name},\n\nYour verification code for class attendance is: ${otpCode}\n\nThis code is valid for 3 minutes.\n\nThank you.`,
    };

    transporter.sendMail(mailOptions, (error, info) => {
      if (error) {
        console.error('Email send error:', error);
        return res.status(500).json({ error: 'Failed to send verification code email.' });
      } else {
        res.json({ success: true, message: 'Verification code sent to your email.' });
      }
    });

  } catch (err) {
    console.error('OTP Generation Error:', err);
    res.status(500).json({ error: 'An error occurred while generating the code.' });
  }
});

// Sign Attendance
router.post('/attendance/sign', authMiddleware, async (req, res) => {
  const { dynamic_code, latitude, longitude, verified_biometrics, otp_code } = req.body;

  if (!verified_biometrics && !otp_code) {
    return res.status(400).json({ error: 'Biometric verification or OTP code is required.' });
  }

  try {
    // If OTP is provided, verify it first
    if (otp_code) {
      const studentRes = await db.query(
        'SELECT otp_code, otp_expiry FROM students WHERE id = $1',
        [req.user.id]
      );
      const student = studentRes.rows[0];

      if (!student.otp_code || student.otp_code !== otp_code) {
        return res.status(400).json({ error: 'Invalid verification code.' });
      }

      const now = new Date();
      if (now > new Date(student.otp_expiry)) {
        return res.status(400).json({ error: 'Verification code has expired. Request a new one.' });
      }

      // Clear the OTP once used successfully
      await db.query('UPDATE students SET otp_code = NULL, otp_expiry = NULL WHERE id = $1', [req.user.id]);
    }
    // Find the active session by code
    const sessionRes = await db.query(
      `SELECT s.*,
              c.latitude  as class_lat,
              c.longitude as class_lon,
              c.radius_m,
              s.session_lat,
              s.session_lon
       FROM sessions s
       JOIN classes c ON s.class_id = c.id
       WHERE s.dynamic_code = $1 AND s.is_active = TRUE`,
      [dynamic_code]
    );

    if (sessionRes.rows.length === 0) {
      return res.status(404).json({ error: 'Invalid or expired session code.' });
    }

    const session = sessionRes.rows[0];

    // Check enrollment
    const enrollRes = await db.query(
      'SELECT * FROM enrollments WHERE student_id = $1 AND class_id = $2',
      [req.user.id, session.class_id]
    );
    if (enrollRes.rows.length === 0) {
      return res.status(403).json({ error: 'You are not enrolled in this class.' });
    }

    // Determine reference coordinates:
    // Prefer session-level override if set, then fall back to class coordinates
    const refLat = (session.session_lat && session.session_lat !== 0) ? session.session_lat : session.class_lat;
    const refLon = (session.session_lon && session.session_lon !== 0) ? session.session_lon : session.class_lon;

    // Skip geofence check if no real coordinates are configured (still 0,0)
    const hasRealCoords = refLat !== 0 || refLon !== 0;
    if (hasRealCoords) {
      const studentLat = parseFloat(latitude) || 0;
      const studentLon = parseFloat(longitude) || 0;

      // Only check distance if the student also provided real coordinates
      if (studentLat !== 0 || studentLon !== 0) {
        const distance = getDistanceFromLatLonInM(studentLat, studentLon, refLat, refLon);
        if (distance > session.radius_m) {
          return res.status(403).json({
            error: `You are too far from the class. Distance: ${Math.round(distance)}m, Allowed: ${session.radius_m}m`,
          });
        }
      }
    }

    // Record attendance
    const { rows } = await db.query(
      'INSERT INTO attendance_logs (session_id, student_id, latitude, longitude) VALUES ($1, $2, $3, $4) RETURNING *',
      [session.id, req.user.id, latitude || 0, longitude || 0]
    );

    res.json({ success: true, message: 'Attendance signed successfully!', log: rows[0] });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(400).json({ error: 'You have already signed attendance for this session.' });
    }
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
