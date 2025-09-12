-- 1. Analyze the initial query performance:
EXPLAIN ANALYZE SELECT * FROM customers WHERE email = 'customer50000@example.com';

-- 2. Create the index:
CREATE INDEX idx_customers_email ON customers(email);

-- 3. Re-run the query:
EXPLAIN ANALYZE SELECT * FROM customers WHERE email = 'customer50000@example.com';
