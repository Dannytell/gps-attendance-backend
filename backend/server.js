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

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
