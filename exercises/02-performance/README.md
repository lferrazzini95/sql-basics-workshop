# Exercise 2: Performance and Indexing

In this exercise, we will explore the impact of database indexes on query performance. We will use the `customers` table, which has been populated with a large number of records.

## Instructions

1.  **Analyze the initial query performance:**
    -   Run the following query to find a customer by their email address.
    -   Use `EXPLAIN ANALYZE` to view the query plan and execution time.

    ```sql
    EXPLAIN ANALYZE SELECT * FROM customers WHERE email = 'customer50000@example.com';
    ```

2.  **Drop the index:**
    -   The `email` column has an index on it. Let's drop it to see what happens.

    ```sql
    DROP INDEX idx_customers_email;
    ```

3.  **Re-run the query:**
    -   Execute the same `SELECT` query as before and analyze its performance.

    ```sql
    EXPLAIN ANALYZE SELECT * FROM customers WHERE email = 'customer50000@example.com';
    ```

4.  **Compare the results:**
    -   Compare the execution times and query plans from steps 1 and 3. You should see a significant difference in performance.

5.  **Recreate the index:**
    -   To restore the performance, let's recreate the index.

    ```sql
    CREATE INDEX idx_customers_email ON customers(email);
    ```
