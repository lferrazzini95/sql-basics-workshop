# Exercise 3: Security

## Topics

Draft (LFE):
* User Creation
* Permissions/Grants
* Views as a Security Tool
* Row Level Security/ Column Priviledges

## Security 

In production environments, security means adhering to the principle of **Least Privilege**. No application user should ever connect to the database as a superuser or possess more permissions than strictly necessary. This minimizes the blast radius of any application vulnerability or SQL injection attack.

In this exercise, we will create a dedicated application user, restrict their access to the bare minimum, and use advanced PostgreSQL features like Views and Row Level Security (RLS) to precisely control what data they can see.

#### User Creation and Roles

In PostgreSQL, users are defined as Roles that possess the `LOGIN` attribute. Try to create a user named `app_user` with a passord and the LOGIN attribute.
```sql
CREATE ROLE app_user WITH LOGIN PASSWORD 'strongpassword';
```

> :warning: Setting minimal permissions is one layer of security but not everything. For example the correct secret management is a crucial part to secure your environments but this is out of scope for this workshop.

For maintainability and control, it's best practice to separate permissions into Group Roles (roles with NOLOGIN) and then grant membership in that group to the individual application user. This approach scales much better than granting permissions directly to users.

Try to create a role `app_reader_group` grant the membership to the above created `app_user`. (Further below we will learn how to grant required permissions ot `roles`.

```sql
CREATE ROLE app_reader_group NOLOGIN;
--GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_reader_group;
GRANT app_reader_group TO app_user;
```


#### Permissions/Grants

Grants are the core of PostgreSQL security. You use the GRANT command to explicitly give privileges (like SELECT, INSERT, UPDATE) to roles. By default, PostgreSQL grants no permissions to a new role, forcing you to define access based on the Least Privilege principle. `GRANTS` can be assigned in a fine grained manner meaning that a user can get granted a `SELECT` only on specific columns of a table.

Assume the `app_user` only requires to read the `orders.amount` and the `customer_id` from the `orders` table and the `customers` table. Try to grant the minimum required `SELECT` permissions on the existing tables.

```sql
-- Grant SELECT on the orders table
GRANT SELECT (customer_id, amount) ON orders TO app_user;

-- Grant SELECT on the customers table
GRANT SELECT ON customers TO app_user;

```

To test the granted `GRANTS` we can set the role that executes the queries to the `app_user` as follows and run a select query:

```sql
SET ROLE app_user;
SELECT customer_id, amount FROM orders LIMIT 1;
SELECT * FROM customers LIMIT 1;

```

#### Views

In case a  role should not get access to a full table but only to a specific computation of the data we can use a **View** to abstract the computation and grant the role only access to the specific **View**.

Try to create a view that contains the `customers.name` and the `total_orders` (count all orders of this customer) and the `total_sales` summing all `orders.amount` for the specific customer. Then grant a `SELECT` on it to the created `app_user`. Finally also remove the permissions to read the `customers` and `orders` table to be sure that the user has minimal permissions.

```sql
CREATE VIEW customer_sales_info AS
SELECT
    c.name,
    COUNT(o.id) AS total_orders,
    SUM(o.amount) AS total_sales
FROM
    customers c
JOIN
    orders o ON c.id = o.customer_id
GROUP BY
    c.name;

REVOKE SELECT ON customers FROM app_user;

GRANT SELECT ON customer_sales_info TO app_user;
```

To test the granted `GRANTS` we can set the role that executes the queries to the `app_user` as follows and run a select query:

```sql
SET ROLE app_user;
SELECT * FROM orders LIMIT 1;
SELECT * FROM customers LIMIT 1;
SELECT * FROM customer_contact_info LIMIT 1;
```

#### Fine-Grained Control: Row Level Security (RLS)/ Column Priviledges

Sometimes, you need to restrict data visibility based on the content of the data. For example, a customer service agent should only see orders related to their assigned region. RLS is a powerful feature that filters rows *before* any query executes.

Let's try to implement a `POLICY` such that the `app_user` is only able to see orders with an `amount` bigger than 100.

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY only_large_orders ON orders
FOR SELECT
TO app_user
USING (amount > 100);

```

**Note:** Row Level Security is complex to set up but provides the highest level of security assurance, as the filtering logic is enforced by the database engine itself, regardless of the application's code.
