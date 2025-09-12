# Exercise 3: Security

## Topics

* [User Creation and Roles](#user-creation-and-roles)
* [Permissions](#permissions)
* [Column permissions](#column-permissions)
* [Views](#views)
* [Row Level Security](#row-level-security)

## Introduction

In production environments, security means adhering to the principle of **Least Privilege**. No application user should ever connect to the database as a superuser or possess more permissions than strictly necessary. This minimizes the blast radius of any application vulnerability or SQL injection attack.

In this exercise, we will create a dedicated application user, restrict their access to the bare minimum, and use PostgreSQL features like Views and Row Level Security (RLS) to precisely control what data they can see.

#### User Creation and Roles

In PostgreSQL `Users` and `Roles` are both enities to group permissions, where `Users` just Roles that possess the `LOGIN` attribute.  Now try to create a user named `app_user` with a passord and the LOGIN attribute.

<details>
    <summary>Solution</summary>

```sql
CREATE ROLE app_user WITH LOGIN PASSWORD 'strongpassword';
```

</details>

> :warning: Setting minimal permissions is one layer of security but not everything. For example, the correct secret management is a crucial part to secure your environments but this is out of scope for this workshop.

For maintainability and control, it's best practice to separate permissions into Group Roles (roles with NOLOGIN) and then grant membership in that group to the individual application user. This approach scales much better than granting permissions directly to users.

Try to create a role `app_reader_group` and grant the membership to it to the above created `app_user`. (Further below we will learn how to grant required permissions to `roles`.

<details>
    <summary>Solution</summary>

```sql
CREATE ROLE app_reader_group NOLOGIN;
GRANT app_reader_group TO app_user;
```
</details>

Now `app_user` inherits all permissions granted to the `app_reader_group`.

#### Permissions

Grants are the core of PostgreSQL security. You use the GRANT command to explicitly give privileges (like SELECT, INSERT, UPDATE) to roles. By default, PostgreSQL grants no permissions to a new role, forcing you to define access based on the Least Privilege principle. `GRANTS` can be assigned in a fine grained manner meaning that a user can get granted a `SELECT` only on specific columns of a table or to entire databases.

Let's try to grant our newly created role `app_reader_group` read (`SELECT`) permissions on the `production.product` table. 

<details>
    <summary>Solution</summary>

```sql
    GRANT USAGE ON SCHEMA production TO app_reader_group;
    GRANT SELECT ON production.product TO app_reader_group;
```
</details>

To test the granted permissions we can set the role that should be used to execute the queries to the `app_user` as follows and run a select query:

```sql
-- execute the follow up queries with this user
SET ROLE app_user;

SELECT * from production.product;

-- reset to the original role
RESET ROLE;
```

#### Column permissions
Assume the `app_user` is responsible to check if users do want to get email promotions or not. Therefore, the role requires to read the `person.person.emailpromotion` and `person.person.businessentityid` columns from the `person.person` table. Try to grant the minimum required `SELECT` permissions on the existing tables and include the `USAGE` on the `person` schema.

<details>
    <summary>Solution</summary>

```sql
GRANT USAGE ON SCHEMA person TO app_reader_group;
GRANT SELECT (businessentityid, emailpromotion) ON person.person TO app_reader_group;
```

</details>

Like before we can set the role to test if the permissions work:

```sql
-- execute the follow up queries with this user
SET ROLE app_user;

-- this should work
SELECT
	p.businessentityid,
    p.emailpromotion
FROM person.person p;

-- this should fail
SELECT *
FROM person.person p;

-- reset to the original role
RESET ROLE;
```

#### Views

In case a role should not get access to a full table but only to a specific computation/transformation of the data. We can create a **View** that includes these transformations and grant permissions to it without allowing a role to read the underlying tables.

Lets assume we want to grant our `app_user` access to view the number of orders per customer, without giving the user access to neither all order information nor customer information. We could either give the user explicit access to the corresponding columns of the table or even simpler create a view and grant `SELECT` privileges to this specific view.

Try to create a view that contains the `customers.name`, the `total_orders` (count all orders) and the `total_sales` (summing all `orders.amount`) per customer. 

<details>
    <summary>Solution</summary>

```sql
CREATE VIEW sales.v_customer_order_counts AS
SELECT
    c.customerid,
    COUNT(soh.salesorderid) AS total_orders
FROM
    sales.customer c
JOIN
    sales.salesorderheader soh ON c.customerid = soh.customerid
GROUP BY
    c.customerid;
```
</details>

Now all we need to do is to grant the `app_reader_group` `SELECT` permissions on the created view and `USAGE` permissions to the underlying schemas.

<details>
    <summary>Solution</summary>

```sql
GRANT USAGE ON SCHEMA sales TO app_reader_group;
GRANT SELECT ON sales.v_customer_order_counts TO app_reader_group;
```

</details>

To test the granted permissions we can again set the role that executes the queries to the `app_user` test the access to the view.

```sql
SET ROLE app_user;

SELECT * FROM sales.v_customer_order_counts;
RESET ROLE;
```

#### Row Level Security

Sometimes it is not enough to restrict access to a database object. Maybe it is required to restrict data visibility based on the content of the data. For example, a customer service agent should only see orders related to their assigned region. This is called row level security (RLS) and is a powerful feature that filters rows **before** any query executes.

Postgres provides the concept of `POLICIES` to enable such functionality. Let's try to implement a `POLICY` that allows the `app_user` to only see sales that are part of a specific territoryId a `territoryId` equal to `5`.

<details>
    <summary>Solution</summary>

```sql
GRANT USAGE ON SCHEMA sales TO app_reader_group;
GRANT SELECT ON TABLE sales.salesorderheader TO app_reader_group;

ALTER TABLE  sales.salesorderheader ENABLE ROW LEVEL SECURITY;

CREATE POLICY only_territory ON sales.salesorderheader
FOR SELECT
TO app_reader_group
USING (territoryId = 5);
```

</details>

When running commands as the user `app_user` and selecting all data from the table we should only be able to see entries with `territoryId` of 5.

<details>
    <summary>Solution</summary>

```sql
SET ROLE app_reader_group;

select * from sales.salesorderheader;
```

</details>

**Note:** Row Level Security is complex to set up but provides the highest level of security assurance, as the filtering logic is enforced by the database engine itself, regardless of the application's code.
