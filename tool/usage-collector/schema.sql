-- جدول واحد: صف لكل (يوم، معرّف عشوائي). لا أسماء ولا بريد ولا IP.
CREATE TABLE IF NOT EXISTS pings (
  day TEXT NOT NULL,
  id  TEXT NOT NULL,
  v   TEXT NOT NULL,
  p   TEXT NOT NULL,
  l   TEXT NOT NULL,
  PRIMARY KEY (day, id)
);
CREATE INDEX IF NOT EXISTS pings_id ON pings (id);
