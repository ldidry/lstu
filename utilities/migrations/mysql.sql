-- 1 up
CREATE TABLE IF NOT EXISTS lstu (
    short varchar(255) PRIMARY KEY,
    url text,
    counter integer default 0,
    timestamp integer
);
CREATE TABLE IF NOT EXISTS sessions (
    token varchar(255) PRIMARY KEY,
    until integer
);
CREATE TABLE IF NOT EXISTS ban (
    ip varbinary(16) PRIMARY KEY,
    until integer,
    strike integer
);
-- 1 down
DROP TABLE ban;
DROP TABLE sessions;
DROP TABLE lstu;
