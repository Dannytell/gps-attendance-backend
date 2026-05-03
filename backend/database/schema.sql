-- Users tables
CREATE TABLE lecturers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id VARCHAR(20) UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  password_hash TEXT NOT NULL
);

CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  university_id VARCHAR(20) UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  password_hash TEXT NOT NULL
);

-- Classes now act as a "Timetable" template owned by a Lecturer
CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lecturer_id UUID REFERENCES lecturers(id),
  title TEXT NOT NULL,
  day_of_week VARCHAR(10) NOT NULL, -- e.g., 'Monday'
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  latitude NUMERIC(9,6) NOT NULL,
  longitude NUMERIC(9,6) NOT NULL,
  radius_m INTEGER DEFAULT 40
);

CREATE TABLE enrollments (
  student_id UUID REFERENCES students(id),
  class_id UUID REFERENCES classes(id),
  PRIMARY KEY(student_id, class_id)
);

-- Sessions are dynamic. A lecturer generates a code when the class starts.
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID REFERENCES classes(id),
  session_date DATE DEFAULT CURRENT_DATE,
  dynamic_code VARCHAR(10) UNIQUE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  UNIQUE (class_id, session_date)
);

CREATE TABLE attendance_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES sessions(id),
  student_id UUID REFERENCES students(id),
  signed_at TIMESTAMPTZ DEFAULT NOW(),
  latitude NUMERIC(9,6) NOT NULL,
  longitude NUMERIC(9,6) NOT NULL,
  UNIQUE (session_id, student_id)
);