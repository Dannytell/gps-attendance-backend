const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// Serve uploaded files as static assets
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/lecturer', require('./routes/lecturer'));
app.use('/api/student', require('./routes/student'));
app.use('/api/announcements', require('./routes/announcements'));

app.get('/', (req, res) => {
  res.send('GPS_APP API is running');
});

app.get('/debug-db', async (req, res) => {
  const db = require('./db');
  try {
    const result = await db.query('SELECT NOW()');
    res.json({ success: true, time: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message, stack: err.stack });
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
