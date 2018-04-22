-- 1 up
CREATE TABLE IF NOT EXISTS lstu (
    short     TEXT PRIMARY KEY,
    url       TEXT,
    counter   INTEGER,
    timestamp INTEGER
);
CREATE TABLE IF NOT EXISTS sessions (
    token TEXT PRIMARY KEY,
    until INTEGER
);
CREATE TABLE IF NOT EXISTS ban (
    ip     TEXT PRIMARY KEY,
    until  INTEGER,
    strike INTEGER
);
CREATE INDEX IF NOT EXISTS empty_short_idx ON lstu (short) WHERE url IS NULL;
-- 1 down
DROP TABLE lstu;
DROP TABLE sessions;
DROP TABLE ban;
DROP INDEX empty_short_idx;
