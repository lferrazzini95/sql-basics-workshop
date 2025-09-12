# Exercise 2: Performance and Indexing

## Topics

* [Query Analyzer](#query-analyzer)
* [Indexing](#index)
* [Materialized Views](#materialized-views)

### Query Analyzer

The **Query Analyzer** is your most essential tool for performance tuning. It allows you to peak into the database engine and see exactly how a query is being executed. In PostgreSQL, the primary command for this is **`EXPLAIN ANALYZE`** which actually contains two parts:

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
