-- Users source (MDM master data — messy records for future ETL)
CREATE TABLE users (
    user_id               SERIAL PRIMARY KEY,
    username              VARCHAR(100),
    email                 VARCHAR(255),
    age                   INTEGER,
    gender                CHAR(1),
    occupation            VARCHAR(100),
    created_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_update_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (username, email, age, gender, occupation, created_at, last_update_timestamp) VALUES
    ('alice', 'alice@movielens.local', 25, 'F', 'student', '2024-01-10 08:00:00', '2024-01-10 08:00:00'),
    ('bob', 'bob@movielens.local', 32, 'M', 'engineer', '2024-01-11 09:00:00', '2024-01-11 09:00:00'),
    ('carol', 'carol.movielens.local', 28, 'F', 'artist', '2024-01-12 10:00:00', '2024-01-12 10:00:00'),
    ('dave', 'dave@movielens.local', NULL, 'M', 'teacher', '2024-01-13 11:00:00', '2024-01-13 11:00:00'),
    ('eve', 'eve@movielens.local', 41, 'F', NULL, '2024-01-14 12:00:00', '2024-01-14 12:00:00'),
    ('frank', 'frank@movielens.local', 35, 'M', 'engineer', '2024-01-15 13:00:00', '2024-06-01 09:00:00'),
    ('grace', 'grace@movielens.local', 29, 'F', 'doctor', '2024-01-16 14:00:00', '2024-06-02 10:00:00'),
    ('alice', 'alice.dup@movielens.local', 25, 'F', 'student', '2024-02-01 08:00:00', '2024-06-03 11:00:00');
