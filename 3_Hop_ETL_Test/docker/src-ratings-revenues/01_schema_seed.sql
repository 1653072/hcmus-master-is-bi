-- Ratings & Revenues source (messy OLTP — intentional DQ issues for ETL)
CREATE TABLE ratings (
    rating_id            SERIAL PRIMARY KEY,
    user_id              INTEGER,
    movie_id             VARCHAR(50),
    rating               NUMERIC(3, 1),
    rated_at             TIMESTAMP,
    last_update_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE revenues (
    revenue_id           SERIAL PRIMARY KEY,
    movie_id             VARCHAR(50),
    region               VARCHAR(100),
    revenue_amount       NUMERIC(15, 2),
    currency             VARCHAR(10),
    revenue_date         DATE,
    last_update_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO ratings (user_id, movie_id, rating, rated_at, last_update_timestamp) VALUES
    (1, '1', 4.0, '2024-06-01 10:00:00', '2024-06-01 10:00:00'),
    (1, '0001', 4.0, '2024-06-01 10:05:00', '2024-06-02 08:00:00'),
    (2, '2', 3.5, '2024-06-02 11:00:00', '2024-06-02 11:00:00'),
    (3, '3', NULL, '2024-06-03 09:00:00', '2024-06-03 09:00:00'),
    (4, '4', 5.0, NULL, '2024-06-04 14:00:00'),
    (5, '5', 2.0, '2024-06-05 16:00:00', '2024-06-05 16:00:00'),
    (6, '1', 4.5, '2024-06-06 08:30:00', '2024-06-06 08:30:00'),
    (NULL, '6', 3.0, '2024-06-07 12:00:00', '2024-06-07 12:00:00');

INSERT INTO revenues (movie_id, region, revenue_amount, currency, revenue_date, last_update_timestamp) VALUES
    ('1', 'North America', 191800000.00, 'USD', '1995-11-22', '2024-06-01 00:00:00'),
    ('1', 'NA', 191800000.00, 'USD', '1995-11-22', '2024-06-02 00:00:00'),
    ('2', 'Europe', 45000000.00, 'EUR', '1995-12-01', '2024-06-02 00:00:00'),
    ('3', 'Asia', NULL, 'USD', '1996-01-10', '2024-06-03 00:00:00'),
    ('4', 'Vietnam', 1200000000.00, 'VND', '1996-02-14', '2024-06-04 00:00:00'),
    ('5', 'North America', 83000000.00, 'US DOLLAR', '1996-03-01', '2024-06-05 00:00:00'),
    ('6', 'Europe', 22000000.00, 'EUR', NULL, '2024-06-06 00:00:00'),
    ('2', 'Europe', 45100000.00, 'EUR', '1995-12-02', '2024-06-07 00:00:00');
