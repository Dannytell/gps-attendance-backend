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
    return await response.json();
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

// Get student profile
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query('SELECT id, university_id, full_name, email FROM students WHERE id = $1', [req.user.id]);
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Update student profile
router.put('/profile', authMiddleware, async (req, res) => {
  const { full_name, email } = req.body;
  try {
    const { rows } = await db.query(
      'UPDATE students SET full_name = COALESCE($1, full_name), email = COALESCE($2, email) WHERE id = $3 RETURNING *',
      [full_name, email, req.user.id]
    );
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Change Password
router.put('/password', authMiddleware, async (req, res) => {
  const { current_password, new_password } = req.body;
  try {
    const { rows } = await db.query('SELECT password_hash FROM students WHERE id = $1', [req.user.id]);
    const bcrypt = require('bcrypt');
    const valid = await bcrypt.compare(current_password, rows[0].password_hash);
    if (!valid) return res.status(401).json({ error: 'Incorrect current password' });
    const newHash = await bcrypt.hash(new_password, 10);
    await db.query('UPDATE students SET password_hash = $1 WHERE id = $2', [newHash, req.user.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Timetable and Classes
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

// Send OTP
router.post('/attendance/send-otp', authMiddleware, async (req, res) => {
  try {
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiry = new Date(Date.now() + 3 * 60000);
    await db.query('UPDATE students SET otp_code = $1, otp_expiry = $2 WHERE id = $3', [otpCode, expiry, req.user.id]);
    const { rows } = await db.query('SELECT email, full_name FROM students WHERE id = $1', [req.user.id]);
    const student = rows[0];
    console.log(`ATTENDANCE OTP FOR ${student.full_name}: ${otpCode}`);
    sendEmail(student.email, 'Your Verification Code', `<p>Code: <strong>${otpCode}</strong></p>`);
    res.json({ success: true, message: 'OTP sent' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Sign Attendance (SMART GEOFENCING)
router.post('/attendance/sign', authMiddleware, async (req, res) => {
  const { dynamic_code, latitude, longitude, verified_biometrics, otp_code } = req.body;
  try {
    if (otp_code) {
      const studentRes = await db.query('SELECT otp_code, otp_expiry FROM students WHERE id = $1', [req.user.id]);
      const student = studentRes.rows[0];
      if (!student.otp_code || student.otp_code !== otp_code || new Date() > new Date(student.otp_expiry)) {
        return res.status(400).json({ error: 'Invalid or expired code.' });
      }
      await db.query('UPDATE students SET otp_code = NULL, otp_expiry = NULL WHERE id = $1', [req.user.id]);
    }

    const sessionRes = await db.query(
      `SELECT s.*, c.latitude as class_lat, c.longitude as class_lon, c.radius_m 
       FROM sessions s JOIN classes c ON s.class_id = c.id 
       WHERE s.dynamic_code = $1 AND s.is_active = TRUE`, [dynamic_code]);

    if (sessionRes.rows.length === 0) return res.status(404).json({ error: 'Invalid session code.' });
    const session = sessionRes.rows[0];

    // DECIDE WHICH COORDINATES TO USE (Priority: Session > Class)
    let refLat = (session.session_lat && Math.abs(session.session_lat) > 0.001) ? session.session_lat : session.class_lat;
    let refLon = (session.session_lon && Math.abs(session.session_lon) > 0.001) ? session.session_lon : session.class_lon;

    // ONLY CHECK IF COORDINATES ARE REAL (Not 0,0)
    if (Math.abs(refLat) > 0.001 || Math.abs(refLon) > 0.001) {
      const studentLat = parseFloat(latitude) || 0;
      const studentLon = parseFloat(longitude) || 0;
      
      const distance = getDistanceFromLatLonInM(studentLat, studentLon, refLat, refLon);
      const allowedRadius = (session.radius_m || 50) + 50; // 50m radius + 50m GPS buffer

      if (distance > allowedRadius) {
        return res.status(403).json({ 
          error: `Too far from class. Distance: ${Math.round(distance)}m. Allowed: ${Math.round(allowedRadius)}m` 
        });
      }
    }

    await db.query('INSERT INTO attendance_logs (session_id, student_id, latitude, longitude) VALUES ($1, $2, $3, $4)', 
      [session.id, req.user.id, latitude || 0, longitude || 0]);

    res.json({ success: true, message: 'Attendance signed!' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
