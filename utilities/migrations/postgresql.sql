-- 1 up
CREATE TABLE IF NOT EXISTS lstu (
    short text PRIMARY KEY,
    url text,
    counter integer default 0,
    timestamp integer
);
CREATE TABLE IF NOT EXISTS sessions (
    token text PRIMARY KEY,
    until integer
);
CREATE TABLE IF NOT EXISTS ban (
    ip text PRIMARY KEY,
    until integer,
    strike integer
);
-- 1 down
DROP TABLE ban;
DROP TABLE sessions;
DROP TABLE lstu;
-- 2 up
CREATE INDEX IF NOT EXISTS empty_short_idx ON lstu (short) WHERE url IS NULL;
-- 2 down
DROP INDEX empty_short_idx;
