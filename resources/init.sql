-- workshop_setup.sql
-- This script sets up the 'workshop' database schema and populates it with sample data.
\c workshop

BEGIN;

CREATE TABLE IF NOT EXISTS customers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  registration_date DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS orders jkjj(
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    order_date DATE NOT NULL,
    amount DECIMAL(10, 2) NOT NULL
);

DO $$
  DECLARE
    i INT;
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM customers LIMIT 1) THEN
      FOR i IN 1..100000 LOOP
        INSERT INTO customers (name, email, registration_date)
        VALUES (
        'Customer ' || i,
        'customer' || i || '@example.com',
        DATE '2025-01-01' + (i-1) % 365
        );
        FOR j IN 1..((i % 5) + 1) LOOP
            INSERT INTO orders (customer_id, order_date, amount)
            VALUES (i, DATE '2025-01-01' - (i % 30), RANDOM() * 100);
        END LOOP;
      END LOOP;
    END IF;
END $$;
COMMIT;
