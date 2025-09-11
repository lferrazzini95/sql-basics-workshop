-- workshop_setup.sql
-- This script sets up the 'workshop' database schema and populates it with sample data.
\c workshop

BEGIN;
-- Create a table for customers if it does not already exist.
CREATE TABLE IF NOT EXISTS customers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  registration_date DATE NOT NULL
);

-- Create an index on the email column to speed up queries,
-- especially for lookups or JOINs on the email address.
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);

-- Use a PL/pgSQL block to conditionally insert data.
-- This makes the script idempotent for data population. It checks if the
-- table is empty before generating the 100,000 customer records.
DO $$
  DECLARE
    i INT;
    BEGIN
      -- Check if the table is empty before inserting data
      IF NOT EXISTS (SELECT 1 FROM customers LIMIT 1) THEN
      FOR i IN 1..100000 LOOP
        INSERT INTO customers (name, email, registration_date)
        VALUES (
        'Customer ' || i,
        'customer' || i || '@example.com',
        CURRENT_DATE - (i % 365)
        );
      END LOOP;
    END IF;
END $$;
COMMIT;
