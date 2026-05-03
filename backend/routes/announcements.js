const express = require('express');
const router = express.Router();
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Multer config: store files locally with original extension preserved
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
  filename: (_req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname);
    cb(null, `attachment-${uniqueSuffix}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024 }, // 20 MB max
  fileFilter: (_req, file, cb) => {
    const allowed = /pdf|png|jpg|jpeg|gif|doc|docx|ppt|pptx|xls|xlsx/;
    const ext = path.extname(file.originalname).toLowerCase().replace('.', '');
    if (allowed.test(ext)) {
      cb(null, true);
    } else {
      cb(new Error('File type not allowed. Use PDF, images, or Office documents.'));
    }
  },
});

// Upload a file attachment — returns the public URL
router.post('/upload', authMiddleware, upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded.' });
  }
  const fileUrl = `/uploads/${req.file.filename}`;
  res.json({ success: true, file_url: fileUrl, original_name: req.file.originalname });
});

// Lecturer creates an announcement for a class
router.post('/', authMiddleware, async (req, res) => {
  const { class_id, title, body, file_url } = req.body;
  if (!title || !body) {
    return res.status(400).json({ error: 'Title and body are required.' });
  }
  try {
    const { rows } = await db.query(
      `INSERT INTO announcements (lecturer_id, class_id, title, body, file_url)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [req.user.id, class_id || null, title, body, file_url || null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get announcements for a specific class
router.get('/class/:class_id', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT a.*, l.full_name as lecturer_name 
       FROM announcements a
       LEFT JOIN lecturers l ON a.lecturer_id = l.id
       WHERE a.class_id = $1
       ORDER BY a.created_at DESC`,
      [req.params.class_id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Student gets all announcements for enrolled classes + general announcements
router.get('/student/all', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT a.*, l.full_name as lecturer_name, c.title as class_title, c.code as class_code
       FROM announcements a
       LEFT JOIN lecturers l ON a.lecturer_id = l.id
       LEFT JOIN classes c ON a.class_id = c.id
       WHERE a.class_id IS NULL 
          OR a.class_id IN (SELECT class_id FROM enrollments WHERE student_id = $1)
       ORDER BY a.created_at DESC`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Lecturer gets their own announcements
router.get('/lecturer/all', authMiddleware, async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT a.*, c.title as class_title, c.code as class_code
       FROM announcements a
       LEFT JOIN classes c ON a.class_id = c.id
       WHERE a.lecturer_id = $1
       ORDER BY a.created_at DESC`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete announcement
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    // Also delete the file from disk if one was attached
    const existing = await db.query(
      'SELECT file_url FROM announcements WHERE id = $1 AND lecturer_id = $2',
      [req.params.id, req.user.id]
    );
    if (existing.rows.length > 0 && existing.rows[0].file_url) {
      const filePath = path.join(__dirname, '..', existing.rows[0].file_url);
      if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    }
    await db.query('DELETE FROM announcements WHERE id = $1 AND lecturer_id = $2', [req.params.id, req.user.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
