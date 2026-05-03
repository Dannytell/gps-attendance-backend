import express from "express";
import cors from "cors";
import jwt from "jsonwebtoken";
import bcrypt from "bcrypt";
import pkg from "pg";
import dotenv from "dotenv";
import multer from "multer";
import multerS3 from "multer-s3";
import AWS from "aws-sdk";

dotenv.config();
const { Pool } = pkg;
const app = express();
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
app.use(cors());
app.use(express.json());

// Optional selfie upload config
AWS.config.update({ region: "us-east-1" });
const s3 = new AWS.S3();
const upload = process.env.AWS_S3_BUCKET ? multer({
  storage: multerS3({
    s3,
    bucket: process.env.AWS_S3_BUCKET,
    acl: "private",
    key: (req, file, cb) => cb(null, `selfies/${Date.now()}-${file.originalname}`)
  })
}) : multer({ dest: 'uploads/' });

// Helper to calculate GPS distance
const haversine = (lat1, lon1, lat2, lon2) => {
  const R = 6371000;
  const toRad = x => (x * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
};

const authMiddleware = async (req, res, next) => {
  const token = (req.headers.authorization || "").replace("Bearer ", "");
  if (!token) return res.status(401).json({ error: "Missing token" });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    return next();
  } catch {
    return res.status(401).json({ error: "Invalid token" });
  }
};

app.post("/auth/login", async (req, res) => {
  const { universityId, password } = req.body;
  const { rows } = await pool.query(
    "SELECT id, password_hash FROM students WHERE university_id=$1",
    [universityId]
  );
  if (!rows.length) return res.status(401).json({ error: "Invalid login" });
  const match = await bcrypt.compare(password, rows[0].password_hash);
  if (!match) return res.status(401).json({ error: "Invalid login" });
  const token = jwt.sign({ studentId: rows[0].id }, process.env.JWT_SECRET, {
    expiresIn: "8h"
  });
  res.json({ token });
});

app.post("/attendance", authMiddleware, upload.single("selfie"), async (req, res) => {
    const { classCode, latitude, longitude } = req.body;
    if (!latitude || !longitude || !classCode) {
      return res.status(400).json({ error: "Missing fields" });
    }

    const { rows } = await pool.query(
      `SELECT c.id, c.latitude, c.longitude, c.radius_m, s.id AS session_id
       FROM classes c
       JOIN sessions s ON s.class_id = c.id
       WHERE c.code=$1 AND s.session_date=CURRENT_DATE`,
      [classCode]
    );
    if (!rows.length) return res.status(404).json({ error: "Session not found for today" });

    const session = rows[0];
    const distance = haversine(session.latitude, session.longitude, Number(latitude), Number(longitude));
    const tolerance = session.radius_m || Number(process.env.GEOFENCE_TOLERANCE);

    if (distance > tolerance) {
      return res.status(403).json({ error: `Outside classroom geofence. Distance: ${Math.round(distance)}m` });
    }

    const selfieUrl = req.file && req.file.location ? req.file.location : null;

    try {
      await pool.query(
        `INSERT INTO attendance_logs (session_id, student_id, latitude, longitude, selfie_url)
         VALUES ($1, $2, $3, $4, $5)`,
        [session.session_id, req.user.studentId, latitude, longitude, selfieUrl]
      );
      return res.json({ status: "Attendance recorded successfully!" });
    } catch (err) {
      if (err.code === "23505") return res.status(409).json({ error: "Already signed in" });
      console.error(err);
      return res.status(500).json({ error: "Internal error" });
    }
  }
);

app.get("/reports", authMiddleware, async (req, res) => {
  const { classCode } = req.query;
  const { rows } = await pool.query(
    `SELECT * FROM attendance_reports WHERE class_code=$1 AND session_date=CURRENT_DATE ORDER BY full_name`,
    [classCode]
  );
  res.json(rows);
});

app.listen(process.env.PORT, () => console.log(`API running on port ${process.env.PORT}`));
