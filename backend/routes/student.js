const express = require('express');
const router = express.Router();
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');

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
        from: 'Attendance System <onboarding@resend.dev>',
        to: to,
        subject: subject,
        html: html
      })
    });
    const data = await response.json();
    console.log('Resend Attendance Email Response:', data);
    return data;
  } catch (err) {
    console.error('Resend API Error:', err);
  }
};

// Calculate distance between two coordinates in meters
function getDistanceFromLatLonInM(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// ... Profile Routes ...
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query('SELECT id, university_id, full_name, email FROM students WHERE id = $1', [req.user.id]);
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.get('/timetable', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT c.*, l.full_name as lecturer_name FROM classes c 
       JOIN enrollments e ON c.id = e.class_id 
       LEFT JOIN lecturers l ON c.lecturer_id = l.id WHERE e.student_id = $1`, [req.user.id]);
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/classes/enroll', authMiddleware, async (req, res) => {
  const { class_id } = req.body;
  try {
    await db.query('INSERT INTO enrollments (student_id, class_id) VALUES ($1, $2)', [req.user.id, class_id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Send OTP to Student Email
router.post('/attendance/send-otp', authMiddleware, async (req, res) => {
  try {
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiry = new Date(Date.now() + 3 * 60000);

    await db.query('UPDATE students SET otp_code = $1, otp_expiry = $2 WHERE id = $3', [otpCode, expiry, req.user.id]);
    const { rows } = await db.query('SELECT email, full_name FROM students WHERE id = $1', [req.user.id]);
    const student = rows[0];

    // Log the code so user can see it in Render logs if email fails
    console.log(`ATTENDANCE OTP FOR ${student.full_name}: ${otpCode}`);

    // Send via Resend (Non-blocking)
    sendEmail(
      student.email,
      'Your Attendance Verification Code',
      `<p>Hello ${student.full_name},</p><p>Your verification code is: <strong>${otpCode}</strong></p>`
    );

    res.json({ success: true, message: 'Verification code sent to your email.' });
  } catch (err) {
    res.status(500).json({ error: 'An error occurred while generating the code.' });
  }
});

// Sign Attendance
router.post('/attendance/sign', authMiddleware, async (req, res) => {
  const { dynamic_code, latitude, longitude, verified_biometrics, otp_code } = req.body;
  try {
    if (otp_code) {
      const studentRes = await db.query('SELECT otp_code, otp_expiry FROM students WHERE id = $1', [req.user.id]);
      const student = studentRes.rows[0];
      if (!student.otp_code || student.otp_code !== otp_code || new Date() > new Date(student.otp_expiry)) {
        return res.status(400).json({ error: 'Invalid or expired verification code.' });
      }
      await db.query('UPDATE students SET otp_code = NULL, otp_expiry = NULL WHERE id = $1', [req.user.id]);
    }

    const sessionRes = await db.query(
      `SELECT s.*, c.latitude as class_lat, c.longitude as class_lon, c.radius_m 
       FROM sessions s JOIN classes c ON s.class_id = c.id 
       WHERE s.dynamic_code = $1 AND s.is_active = TRUE`, [dynamic_code]);

    if (sessionRes.rows.length === 0) return res.status(404).json({ error: 'Invalid or expired session code.' });
    const session = sessionRes.rows[0];

    const distance = getDistanceFromLatLonInM(latitude, longitude, session.class_lat, session.class_lon);
    if (distance > session.radius_m) {
      return res.status(403).json({ error: `Too far from class. Distance: ${Math.round(distance)}m` });
    }

    await db.query('INSERT INTO attendance_logs (session_id, student_id, latitude, longitude) VALUES ($1, $2, $3, $4)', 
      [session.id, req.user.id, latitude, longitude]);

    res.json({ success: true, message: 'Attendance signed successfully!' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
