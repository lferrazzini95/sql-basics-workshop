# Exercise 2: Performance and Indexing

## Topics

* [Query Analyzer](#query-analyzer)
* [Indexing](#index)
* [Materialized Views](#materialized-views)

### Query Analyzer

The **Query Analyzer** is your most essential tool for performance tuning. It allows you to peak into the database engine and see exactly how a query is being executed. In PostgreSQL, the primary command for this is **`EXPLAIN ANALYZE`** which actually contains two parts:

* **`EXPLAIN`**: Shows the **query plan**—the sequence of steps the database planner intends to take.
* **`ANALYZE`**: Executes the query and records the **actual runtime statistics**, including actual execution time, rows processed, and time spent on each step.

Understanding the output is key to identifying bottlenecks, such as slow **Sequential Scans** (reading the entire table), expensive **Hash Joins**, or redundant computation. This is the first step in analyzing slow running queries.

#### Analyze the Query Plan

Use the `EXPLAIN ANALYZE` command to inspect the plan and execution time of a specific query this way we can get familiar with it. For example, try to find the number of orders the Customer with the FirstName 'Emilio', and LastName 'Alvaro' completed. And check the EXPLAIN
```sql
EXPLAIN ANALYZE WITH CustomerOrderCounts AS (
    SELECT
        CustomerID,
        COUNT(SalesOrderID) AS TotalOrders
    FROM
        Sales.SalesOrderHeader
    GROUP BY
        CustomerID
)
SELECT p.FirstName, p.LastName, o.TotalOrders
FROM Sales.Customer cust
LEFT JOIN Person.Person p ON cust.PersonID = p.BusinessEntityID
LEFT JOIN CustomerOrderCounts o ON o.CustomerID = cust.CustomerID
WHERE p.FirstName = 'Emilio' AND p.LastName = 'Alvaro';
```

The output contains several pieces of information structured in three parts: the `Operation Type` planner's estimated attributes (in the first parentheses) and the actual execution statistics (in the second parentheses). We will focus on the `Operation Type` and the execution findings.

Think about the following parts of the result:
1.  **Operation Type:** What kind of operation is performed in each step (e.g., `Sequential Scan`, `Index Scan`, `Hash Join`)?
2.  **Actual Time**: The real-world time the operation took (in milliseconds). This is what you are trying to optimize for inefficient steps.
3.  **Rows Removed by Filter**: How many rows were read from the table but discarded because they didn't match the `WHERE` clause. A high number here indicates inefficient data access.
4.  **Planning Time**: The time PostgreSQL spends deciding the best way to run your query before it starts reading data. High values usually points to an overly complex query or too many indexes to choose from.
5.  **Execution Time:**:The total time the database spent running the entire query and getting the results after the plan was finalized. This is the final number the user waits for completion.

### Index

A database index is a specialized data structure. The most common indexes are `clustered` and `non-clustered` indexes. `Clustered` indices contain the data itself and sorts it according to certain attributes, therefore a table can only have **one** `clustered` index. On the other hand, there are `non-clustered` indices that contain pointers to the original rows. Usually if there is no matching index found the database performs a `sequential scan`, meaning going through all `n` rows of the table to find matches for the query. If there is an index defined the database performs an `index scan` which uses the matching index to sometimes drastically improve performance. In this exercise we will focus on `non-clustered` indices.

#### Instructions

If you want to see a clearer representation on the efficiency of indices set the parallelism on your system to 0 using the following command:
```sql
SET max_parallel_workers_per_gather = 0;
``` 

#### Analyze the initial query performance

Lets assume we want to get all transactions (with the attributes `TransactionDate`, `Quantity` and `ActualCost`) of the product `HL Mountain Handlebars` (`ProductID` 810). Come up with a query to extract the desired informations and use the `EXPLAIN ANALYZE` feature to inspect the query plan and execution time.
<details>
  <summary>Solution</summary>

```sql
EXPLAIN ANALYZE
SELECT
    TransactionDate,
    Quantity,
    ActualCost,
FROM
    Production.TransactionHistory
WHERE
    ProductID = 810;
```

</details>

Write down the total `Execution Time` of the query and think about where you could use an index to improve performance.
> Hint: Check for `sequential scans` (which indicates the database is performing a full table scan).

#### Create the index

Try to create a `non-clustered` index on the `TransactionHistory` table on the correct attribute to speed up our query from above:

<details>
  <summary>Solution</summary>

```sql
CREATE INDEX idx_transactionhistory_productid ON Production.TransactionHistory (ProductID);
```

</details>

#### Re-run the query
Execute the same `SELECT` query as before and analyze its performance.

```sql
EXPLAIN ANALYZE
SELECT
    TransactionDate,
    Quantity,
    ActualCost
FROM
    Production.TransactionHistory
WHERE
    ProductID = 810;
```
Compare the execution times and query plans from steps 1 and 3. You should see a significant difference in performance as the query now uses an `index scan`.

In order to drop the `index` you can run the following query:
```sql
DROP INDEX Production.idx_transactionhistory_productid;
```

### Materialized Views

A Materialized View (MV) is a database object that contains the results of a query and stores them as a pre-computed table. Unlike a regular view, which runs its query every time you access it, a Materialized View gives you the instant result of a complex or expensive query, essentially trading disk space and data freshness for significantly faster read performance.

A common use case is when you have a large table with slow, resource-intensive operations, such as aggregations or joins, that are frequently queried. By creating a Materialized View, you move the computational cost from read time to write time.

#### Introduction

In this exercise, we will calculate the total sales and order counts for each customer the tables of interest would be `Sales.Customer` and `Sales.SalesOrderHeader` tables. With this example query we can showcase the benefits a `Materialized View` can provide.

#### Analyze the initial query performance

Use the `Sales.Customer` and `Sales.SalesOrderHeader` table to calculate the total sales and order count per customer. Also use the `EXPLAIN ANALYZE` feature to inspec the performance of the query such that we can later compare it to the `Materialized View`.

<details>
    <summary>Solution</summary>

```sql
EXPLAIN ANALYZE
SELECT
    c.CustomerID,
    p.FirstName,
    p.LastName,
    COUNT(soh.SalesOrderID) AS OrderCount,
    SUM(soh.SubTotal) AS TotalSales
FROM
    Sales.Customer c
JOIN
    Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
LEFT JOIN
    Person.Person p ON c.PersonID = p.BusinessEntityID
GROUP BY
    c.CustomerID, p.FirstName, p.LastName
ORDER BY
    TotalSales DESC;
```
</details>

#### Create Materialized View

Now, let's create a Materialized View from the exact same query as above. This command will execute the query and save the results into a new database object.

```sql
CREATE MATERIALIZED VIEW customer_sales_mv AS
SELECT
    c.CustomerID,
    p.FirstName,
    p.LastName,
    COUNT(soh.SalesOrderID) AS OrderCount,
    SUM(soh.SubTotal) AS TotalSales
FROM
    Sales.Customer c
JOIN
    Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
LEFT JOIN
    Person.Person p ON c.PersonID = p.BusinessEntityID
GROUP BY
    c.CustomerID, p.FirstName, p.LastName
ORDER BY
    TotalSales DESC;
```

#### Compare performance
Now, run a simple SELECT query on the materialized view. You will notice the execution time is dramatically faster because the database is simply reading from a pre-computed table, not re-calculating the join and aggregation.

```sql
EXPLAIN ANALYZE SELECT * FROM customer_sales_mv;
```

#### Downside: Refreshing the View
The data in the Materialized View is static. If new orders are added, the view will be outdated. To update it, you must run a REFRESH command. Note that this command re-runs the original query and can be time-consuming.

Once new orders arrived the materialized view can be refreshed with the command below.

```sql
REFRESH MATERIALIZED VIEW customer_sales_mv;
```

As with many things performance optimization is a trade off. Indices increase the read speed but when inserting data into the table it introduces additional costs as the index needs to be updated as well. The same is true with materialized views, usually read heavy operation benefit most from these kind of optimizations, accepting slower writes in exchange for faster data retrieval.

### Sargability

Next, we want to demonstrate the difference in performance between sargable operations and such that are not. Remember that **sargable expressions** are filters that can use existing indices. On the contrary, especially convenience functions on indexed attributes can lead to bad performance because they gain nothing whatsoever from the index.

We want to observe this behaviour on `production.transactionhistory` while filtering for a specific date range.

Start by creating an index on `transactiondate`.

<details>
  <summary>Solution</summary>

```sql
CREATE INDEX IDX_TRANSACTIONHISTORY_TRANSACTIONDATE
    ON PRODUCTION.TRANSACTIONHISTORY (TRANSACTIONDATE);
```

</details>
<p></p>

Now for a baseline, we want to compute the sum of `actualcost` over the first quarter of 2024. To do so run the following query.

```sql
SELECT
	SUM(ACTUALCOST)
FROM
	PRODUCTION.TRANSACTIONHISTORY
WHERE
	DATE_PART('year', TRANSACTIONDATE) = 2024
	AND DATE_PART('quarter', TRANSACTIONDATE) = 1;
```
As you notice, DATE_PART makes it easy to filter on specific date ranges by using a self-explaining syntax. However, if you use `EXPLAIN ANALYZE` to inspect the execution of the query you will notice that the resulting operation cannot use the index we just created. For comparison, try to rewrite the query above using only standard filters.

<details>
  <summary>Solution</summary>

```sql
SELECT
	SUM(ACTUALCOST)
FROM
	PRODUCTION.TRANSACTIONHISTORY
WHERE
	TRANSACTIONDATE BETWEEN '2024-01-01' AND '2024-03-31';
```

</details>
<p></p>

You should be able to see a clear difference in the execution time of the two queries and when using `EXPLAIN ANALYZE` see the usage of the before created index.

### Table Partitions

As a final method of performance optimization we will have a look at table partitions. Especially for large tables with clear access patterns, partitions can speed up queries considerably. At the same time setting them up is not quite straight-forward and requires regular maintenance.

As we know, there are three different types of partitions in PostgreSQL:
- `Ranges`
- `Lists`
- `Hashes`

Can you think of a use case for each of the three different types? Feel free to reference data structures from our sample database in your examples.

<details>
  <summary>Solution</summary>

#### Ranges
Ranges are perfectly suitable to partition by date. Imagine having partitions for each year of transactions. You will speed up lookups of recent data while keeping old data in implicit archive partitions.

#### Lists
Categorical data can profit from list partitions. In our database, we could think of partitioning product-related data into categories for analytics in the purchasing department.

#### Hashes
Hashing data gives you the least control over how you partition the data. You can only determine how many partitions you would like. This approach is most suitable for data where you filter by exact attributes. For example, you could partition your customer table by hashes over their respective id because it is reasonable that you will often look for a specific customer using her id.

</details>
<p></p>

#### Partitioning Transactions

In this exercise, we intend to partition `transactionhistory` table on transaction dates. This will help us with queries because we will be able to ignore old historical data quite easily.

As you know, we cannot simply partition an existing table. Instead we will create a new partitioned table, create sensible partitions attached to it and finally insert data from the unpartitioned table.

As a first step create a `production.transactions_by_year` table that partitions by range over `transactiondate`.
It should have exactly the same column structure as `production.transactionhistory`. (Hint: You can find the DDL statements of tables in pgadmin)

<details>
  <summary>Solution</summary>

```sql
CREATE TABLE IF NOT EXISTS PRODUCTION.TRANSACTIONS_BY_YEAR
(
	TRANSACTIONID INTEGER NOT NULL,
	PRODUCTID INTEGER NOT NULL,
	REFERENCEORDERID INTEGER NOT NULL,
	REFERENCEORDERLINEID INTEGER NOT NULL DEFAULT 0,
	TRANSACTIONDATE TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
	TRANSACTIONTYPE CHARACTER(1) COLLATE PG_CATALOG."default" NOT NULL,
	QUANTITY INTEGER NOT NULL,
	ACTUALCOST NUMERIC NOT NULL,
	MODIFIEDDATE TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
)
PARTITION BY
	RANGE (TRANSACTIONDATE);
```

</details>
<p></p>

Next, create at least two partitions for the current year and last year.

<details>
  <summary>Solution</summary>

```sql
CREATE TABLE IF NOT EXISTS PRODUCTION.TRANSACTIONS_2025 PARTITION OF PRODUCTION.TRANSACTIONS_BY_YEAR FOR
VALUES
FROM
	('2025-01-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS PRODUCTION.TRANSACTIONS_2024 PARTITION OF PRODUCTION.TRANSACTIONS_BY_YEAR FOR
VALUES
FROM
	('2024-01-01') TO ('2025-01-01');
```

</details>
<p></p>

We have set up the master table and corresponding partitions. All that is left to do, is inserting data into it. Please copy all transactions into the partitioned table as follows:

```sql
INSERT INTO
	PRODUCTION.TRANSACTIONS_BY_YEAR
SELECT
	*
FROM
	PRODUCTION.TRANSACTIONHISTORY;
```

Oops! There seems to be an issue - can you figure out what's wrong and fix it?

<details>
  <summary>Solution</summary>

  There were not enough partitions for all the data. Data from 2023, for example, does neither fit into the `TRANSACTIONS_2025` nor the `TRANSACTIONS_2024` partition. We could either create partitions for all years, manually create a larger partition for the remaining date range or use a so called default partition.

```sql
CREATE TABLE IF NOT EXISTS PRODUCTION.TRANSACTIONS_DEFAULT
    PARTITION OF PRODUCTION.TRANSACTIONS_BY_YEAR DEFAULT;
```

</details>
<p></p>

Now try again our query from further up on the partitioned table and compare its execution time with the non-partitioned table. Recall that we created an index on the `production.transactionhistory` table. You might also want to try and compare differences after dropping the index.

```sql
SELECT
	SUM(ACTUALCOST)
FROM
	PRODUCTION.TRANSACTIONHISTORY
WHERE
	TRANSACTIONDATE BETWEEN '2024-01-01' AND '2024-03-31';
```

Finally, partitions can also be used for efficient data maintenance.
Try and drop all data from 2024.

<details>
  <summary>Solution</summary>

  There were not enough partitions for all the data. Data from 2023, for example, does neither fit into the `TRANSACTIONS_2025` nor the `TRANSACTIONS_2024` partition. We could either create partitions for all years, manually create a larger partition for the remaining date range or use a so called default partition.

```sql
DROP TABLE PRODUCTION.TRANSACTIONS_2024;
```

</details>
<p></p>
