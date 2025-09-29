# Exercise 2: Performance and Indexing

## Topics

Draft:
* Query Analyzer (LFE)
* Indexing (LFE)
* Materialized Views (LFE)
* Join Optimization (MFE)
* Statistics (MFE)
* Partitioning (MFE)

### Query Analyzer

The **Query Analyzer** is your most essential tool for performance tuning. It allows you to peak into the database engine and see exactly how a query is being executed. In PostgreSQL, the primary command for this is **`EXPLAIN ANALYZE`**.

* **`EXPLAIN`**: Shows the **query plan**—the sequence of steps the database planner intends to take.
* **`ANALYZE`**: Executes the query and records the **actual runtime statistics**, including actual execution time, rows processed, and time spent on each step.

Understanding the output is key to identifying bottlenecks, such as slow **Sequential Scans** (reading the entire table), expensive **Hash Joins**, or redundant computation. This is the first step in diagnosing slow application features.

#### Analyze the Query Plan

Use the `EXPLAIN ANALYZE` command to inspect the plan and execution time of a specific query. For example find the customer with the email adress `customer1@exampl.com`:

```sql
EXPLAIN ANALYZE SELECT * FROM customers WHERE email = 'customer1@example.com';
```

Take note of the following lines in the output:
1.  **Operation Type:** What kind of operation is performed (e.g., `Sequential Scan`, `Index Scan`, `Hash Join`)?
2.  **Actual Time**: The real-world time the operation took (in milliseconds). This is what you are trying to optimize.
3.  **Rows Removed by Filter**: How many rows were read from the table but discarded because they didn't match the `WHERE` clause. A high number here indicates inefficient data access.
4.  **Planning Time**: The time PostgreSQL spends deciding the best way to run your query before it starts reading data. High time here usually points to an overly complex query or too many indexes to choose from.
5.  **Execution Time:**:The total time the database spent running the query and getting the results after the plan was finalized. This is the final number the user waits for

#### Improve Visibility (should we keep this?)

To get an even richer view of the query's cost, especially to see the true time spent on planning and execution, use the **`BUFFERS`** option. This shows the block-level I/O activity, which is a key performance indicator (KPI).

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM customers WHERE email = 'customer1@example.com';
```

Examine the **`Buffers`** section in the output, which details the amount of disk I/O and cache usage. Look for high numbers of **`shared hit`** (data found in cache - fast) versus **`shared read`** (data read from disk - slow).

### Index

A database index is a specialized data structure, often a B-Tree. The most common indexes are `clustered` and `non-clustered` indexes. `Clustered` indices contains the data itself and sorts it according to certain attributes, therefore a table can only have **one** `clustered` index. On the other hand there are `non-clustered` indices that contain pointer to the original row. Usually if there is no matchin index found the database performs a `sequential scan`, meaning going through all `n` rows of the table to find matches for the query. If there is an index defined the database performs an `index scan` which uses the matching index to sometimes drastically improve performance. In this exercise we will focus on `non-clustered` indices.

#### Instructions

If you want to see a clearer representation on the efficiency of indices set the paralellism on your system to 0 using the following command:
```sql
SET max_parallel_workers_per_gather = 0;
``` 

#### Analyze the initial query performance
Run the following query to find a customer by their registration date. In PostgreSQL we can use `EXPLAIN ANALYZE` to view the query plan and execution time.
<details>
  <summary>Solution</summary>

```sql
EXPLAIN ANALYZE SELECT * FROM customers WHERE registration_date = '2025-07-26';
```

</details>

Take note of the `Execution Time` and you should see a `sequential scan` in the query plan which should hint you to a potential index opportunity.

Take note of the `Execution Time`. In the query plan, you should see the line `Sequential Scan`, which indicates the database is performing a full table scan. This is your first clue that a potential index could improve performance.

#### Create the index

Now, let's create a `non-clustered` index on the `registration_date` column to speed up data retrieval.

<details>
  <summary>Solution</summary>

```sql
CREATE INDEX idx_customers_registration_date ON customers(registration_date);
```

</details>

#### Re-run the query
Execute the same `SELECT` query as before and analyze its performance.

```sql
EXPLAIN ANALYZE SELECT * FROM customers WHERE registration_date = '2025-07-26';
```
Compare the execution times and query plans from steps 1 and 3. You should see a significant difference in performance as the query now uses an `index scan`.

### Materialized Views

A Materialized View (MV) is a database object that contains the results of a query and stores them as a pre-computed table. Unlike a regular view, which runs its query every time you access it, a Materialized View gives you the instant result of a complex or expensive query, essentially trading disk space and data freshness for significantly faster read performance.

A common use case is when you have a large table with slow, resource-intensive operations, such as aggregations or joins, that are frequently queried. By creating a Materialized View, you move the computational cost from read time to write time.

#### Introduction

In this exercise, we will create a customers and orders table. We'll then demonstrate the performance improvement of a Materialized View by running a complex join and aggregation query.

#### Analyze the initial query performance

Try to come up with a query that calculates the total sales for each customer. On large tables, this query can be slow due to the JOIN and GROUP BY operations. Use EXPLAIN ANALYZE to see the cost.

<details>
    <summary>Solution</summary>

```sql
EXPLAIN ANALYZE
SELECT c.name, COUNT(o.id), SUM(o.amount)
FROM customers c
JOIN orders o ON c.id = o.customer_id
GROUP BY c.name
ORDER BY SUM(o.amount) DESC;
```
<<<<<<< HEAD
=======
</details>

#### Create Materialized View

Now, let's create a Materialized View from the exact same query. This command will execute the query and save the results into a new database object.

```sql
CREATE MATERIALIZED VIEW customer_sales_mv AS
SELECT c.name, COUNT(o.id) as order_count, SUM(o.amount) as total_sales
FROM customers c
JOIN orders o ON c.id = o.customer_id
GROUP BY c.name
ORDER BY SUM(o.amount) DESC;
```

#### Compare performance
Now, run a simple SELECT query on the materialized view. You will notice the execution time is dramatically lower because the database is simply reading from a pre-computed table, not re-calculating the join and aggregation.

```sql
EXPLAIN ANALYZE SELECT * FROM customer_sales_mv;
```

#### Downside: Refreshing the View
The data in the Materialized View is static. If new orders are added, the view will be outdated. To update it, you must run a REFRESH command. Note that this command re-runs the original query and can be time-consuming.

Add some records to the order table:
```sql
INSERT INTO orders (id, customer_id, amount) VALUES (1000000, 1, 50.00); 
```

Refresh the materialized view and check the additional time it takes to better get a feeling for the tradeoff materialized views introduce:

```sql
REFRESH MATERIALIZED VIEW customer_sales_mv;
```
