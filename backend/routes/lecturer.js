const express = require('express');
const router = express.Router();
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');

// Get lecturer profile
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT id, staff_id, full_name, email, department, created_at FROM lecturers WHERE id = $1',
      [req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Lecturer not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update lecturer profile
router.put('/profile', authMiddleware, async (req, res) => {
  const { full_name, email, department } = req.body;
  try {
    const { rows } = await db.query(
      `UPDATE lecturers SET full_name = COALESCE($1, full_name), email = COALESCE($2, email), department = COALESCE($3, department)
       WHERE id = $4 RETURNING id, staff_id, full_name, email, department`,
      [full_name, email, department, req.user.id]
    );
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Change lecturer password
router.put('/password', authMiddleware, async (req, res) => {
  const { current_password, new_password } = req.body;
  if (!current_password || !new_password) {
    return res.status(400).json({ error: 'Current and new password are required.' });
  }
  if (new_password.length < 6) {
    return res.status(400).json({ error: 'New password must be at least 6 characters.' });
  }
  try {
    const { rows } = await db.query('SELECT password_hash FROM lecturers WHERE id = $1', [req.user.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Lecturer not found' });

    const bcrypt = require('bcrypt');
    const valid = await bcrypt.compare(current_password, rows[0].password_hash);
    if (!valid) return res.status(401).json({ error: 'Current password is incorrect.' });

    const newHash = await bcrypt.hash(new_password, 10);
    await db.query('UPDATE lecturers SET password_hash = $1 WHERE id = $2', [newHash, req.user.id]);
    res.json({ success: true, message: 'Password updated successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get lecturer timetable (all classes)
router.get('/timetable', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT * FROM classes WHERE lecturer_id = $1 ORDER BY 
        CASE day_of_week 
          WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3 
          WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 WHEN 'Saturday' THEN 6 WHEN 'Sunday' THEN 7 
        END, start_time`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create a timetable entry (class)
router.post('/timetable', authMiddleware, async (req, res) => {
  const { code, title, day_of_week, start_time, end_time, latitude, longitude, radius_m } = req.body;
  if (!code || !title || !day_of_week || !start_time || !end_time) {
    return res.status(400).json({ error: 'code, title, day_of_week, start_time, and end_time are required.' });
  }
  try {
    const { rows } = await db.query(
      `INSERT INTO classes (code, title, day_of_week, start_time, end_time, latitude, longitude, radius_m, lecturer_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [code, title, day_of_week, start_time, end_time, latitude || 0, longitude || 0, radius_m || 200, req.user.id]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update a timetable entry
router.put('/timetable/:id', authMiddleware, async (req, res) => {
  const { title, code, day_of_week, start_time, end_time, latitude, longitude, radius_m } = req.body;
  try {
    const { rows } = await db.query(
      `UPDATE classes SET 
        title = COALESCE($1, title), code = COALESCE($2, code), day_of_week = COALESCE($3, day_of_week),
        start_time = COALESCE($4, start_time), end_time = COALESCE($5, end_time),
        latitude = COALESCE($6, latitude), longitude = COALESCE($7, longitude), radius_m = COALESCE($8, radius_m)
       WHERE id = $9 AND lecturer_id = $10 RETURNING *`,
      [title, code, day_of_week, start_time, end_time, latitude, longitude, radius_m, req.params.id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Class not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete a timetable entry
router.delete('/timetable/:id', authMiddleware, async (req, res) => {
  try {
    const result = await db.query(
      'DELETE FROM classes WHERE id = $1 AND lecturer_id = $2',
      [req.params.id, req.user.id]
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Class not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get all classes for the logged in lecturer
router.get('/classes', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query('SELECT * FROM classes WHERE lecturer_id = $1', [req.user.id]);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Start a session
// Accepts optional session_lat / session_lon to override stored class coordinates for this session
router.post('/session/start', authMiddleware, async (req, res) => {
  const { class_id, session_lat, session_lon } = req.body;
  if (!class_id) {
    return res.status(400).json({ error: 'class_id is required.' });
  }

  const dynamic_code = Math.random().toString(36).substring(2, 8).toUpperCase();

  try {
    // Deactivate any previous active session for this class
    await db.query(
      'UPDATE sessions SET is_active = FALSE WHERE class_id = $1',
      [class_id]
    );

    // Insert new session — session_date gets its DEFAULT (CURRENT_DATE) automatically
    const { rows } = await db.query(
      `INSERT INTO sessions (class_id, dynamic_code, is_active, session_date, session_lat, session_lon)
       VALUES ($1, $2, TRUE, CURRENT_DATE, $3, $4) RETURNING *`,
      [class_id, dynamic_code, session_lat, session_lon]
    );

    const session = rows[0];

    // Fetch class info for the notification payload
    const classRes = await db.query(
      `SELECT c.*, l.full_name as lecturer_name
       FROM classes c
       LEFT JOIN lecturers l ON c.lecturer_id = l.id
       WHERE c.id = $1`,
      [class_id]
    );
    const classInfo = classRes.rows[0] || {};

    // Fetch all enrolled students for this class (for push notification delivery)
    const enrolledRes = await db.query(
      'SELECT student_id FROM enrollments WHERE class_id = $1',
      [class_id]
    );

    res.json({
      ...session,
      class_info: {
        code: classInfo.code,
        title: classInfo.title,
        lecturer_name: classInfo.lecturer_name,
      },
      enrolled_student_ids: enrolledRes.rows.map(r => r.student_id),
    });
  } catch (err) {
    console.error('Session start error:', err);
    res.status(500).json({ error: err.message });
  }
});

// End a session
router.post('/session/end', authMiddleware, async (req, res) => {
  const { session_id } = req.body;
  try {
    const { rows } = await db.query(
      'UPDATE sessions SET is_active = FALSE WHERE id = $1 RETURNING *',
      [session_id]
    );
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get current active session for lecturer
router.get('/current-session', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT s.*, c.code as class_code, c.title as class_title 
       FROM sessions s
       JOIN classes c ON s.class_id = c.id
       WHERE c.lecturer_id = $1 AND s.is_active = TRUE
       LIMIT 1`,
      [req.user.id]
    );
    res.json(rows[0] || null);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get active sessions for enrolled classes (student polling endpoint for push notifications)
router.get('/active-sessions', authMiddleware, async (req, res) => {
  // Works for both roles — returns any active session for enrolled classes
  // (used by students to poll for new sessions)
  try {
    const { rows } = await db.query(
      `SELECT s.id, s.dynamic_code, s.class_id, s.session_date, s.is_active,
              c.code as class_code, c.title as class_title, l.full_name as lecturer_name
       FROM sessions s
       JOIN classes c ON s.class_id = c.id
       LEFT JOIN lecturers l ON c.lecturer_id = l.id
       WHERE s.is_active = TRUE AND s.session_date = CURRENT_DATE
         AND s.class_id IN (
           SELECT class_id FROM enrollments WHERE student_id = $1
         )`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get lecturer dashboard summary analytics
router.get('/dashboard/analytics', authMiddleware, async (req, res) => {
  try {
    // Recent attendance trend (latest session vs previous session)
    const trendRes = await db.query(
      `WITH SessionCounts AS (
         SELECT s.id, s.session_date, COUNT(a.id) as attendance_count
         FROM sessions s
         LEFT JOIN attendance_logs a ON s.id = a.session_id
         JOIN classes c ON s.class_id = c.id
         WHERE c.lecturer_id = $1 AND s.is_active = FALSE
         GROUP BY s.id, s.session_date
         ORDER BY s.session_date DESC
         LIMIT 2
       )
       SELECT * FROM SessionCounts`,
      [req.user.id]
    );

    let trend = 'SAME';
    let currentAttendance = 0;
    if (trendRes.rows.length >= 2) {
      currentAttendance = parseInt(trendRes.rows[0].attendance_count);
      const prevAttendance = parseInt(trendRes.rows[1].attendance_count);
      if (currentAttendance > prevAttendance) trend = 'UP';
      else if (currentAttendance < prevAttendance) trend = 'DOWN';
    } else if (trendRes.rows.length === 1) {
      currentAttendance = parseInt(trendRes.rows[0].attendance_count);
      trend = 'UP'; // First session
    }

    // Quick stats: Total enrolled vs Total attended today (or latest active/recent session)
    const statsRes = await db.query(
      `SELECT 
         (SELECT COUNT(DISTINCT e.student_id) 
          FROM enrollments e 
          JOIN classes c ON e.class_id = c.id 
          WHERE c.lecturer_id = $1) as total_enrolled,
         (SELECT COUNT(DISTINCT a.student_id)
          FROM attendance_logs a
          JOIN sessions s ON a.session_id = s.id
          JOIN classes c ON s.class_id = c.id
          WHERE c.lecturer_id = $1 AND s.session_date = CURRENT_DATE) as attended_today`,
      [req.user.id]
    );

    res.json({
      trend,
      current_attendance: currentAttendance,
      total_enrolled: statsRes.rows[0]?.total_enrolled || 0,
      attended_today: statsRes.rows[0]?.attended_today || 0,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get session attendance analytics
router.get('/session/:session_id/analytics', authMiddleware, async (req, res) => {
  const { session_id } = req.params;
  try {
    const { rows } = await db.query(
      `SELECT a.signed_at, s.full_name, s.university_id 
       FROM attendance_logs a 
       JOIN students s ON a.student_id = s.id 
       WHERE a.session_id = $1
       ORDER BY a.signed_at ASC`,
      [session_id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get class analytics (all sessions)
router.get('/class/:class_id/analytics', authMiddleware, async (req, res) => {
  const { class_id } = req.params;
  try {
    const sessionsRes = await db.query(
      `SELECT id, session_date, dynamic_code, is_active 
       FROM sessions 
       WHERE class_id = $1 
       ORDER BY session_date DESC`,
      [class_id]
    );

    const logsRes = await db.query(
      `SELECT a.session_id, a.signed_at, s.full_name, s.university_id, s.id as student_id
       FROM attendance_logs a 
       JOIN students s ON a.student_id = s.id 
       JOIN sessions ses ON a.session_id = ses.id
       WHERE ses.class_id = $1
       ORDER BY a.signed_at ASC`,
      [class_id]
    );

    const enrolledRes = await db.query(
      `SELECT s.id as student_id, s.full_name, s.university_id 
       FROM enrollments e 
       JOIN students s ON e.student_id = s.id 
       WHERE e.class_id = $1`,
      [class_id]
    );

    res.json({
      sessions: sessionsRes.rows,
      logs: logsRes.rows,
      enrolled: enrolledRes.rows
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
