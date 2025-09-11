<div align="center">

<img src="./assets/img/postgres-logo.png" alt="Sql Basics" width="25%">

# SQL Basics Workshop @ IPT

![GitHub last commit](https://img.shields.io/github/last-commit/f4z3r/vault-workshop)
![GitHub Release](https://img.shields.io/github/v/release/f4z3r/vault-workshop)
![GitHub License](https://img.shields.io/github/license/f4z3r/vault-workshop)
</div>

Welcome to the **SQL Basics Workshop** at IPT!  
SQL (Structured Query Language) is the standard language for working with relational databases—the backbone of modern apps, from social networks to inventory systems.

In this hands-on workshop, you'll learn how to query, filter, and manipulate data using SQL. Whether you're a developer, analyst, or administrator, these skills are essential for working with data effectively.

---

## 🚀 Getting Started

You can set up the workshop environment in two ways. We recommend using **Devbox** for the cleanest and most reproducible experience.

---

### ✅ Option 1: Devbox (Recommended)

1. **Install Devbox**  
   → [https://www.jetpack.io/devbox/docs/install](https://www.jetpack.io/devbox/docs/install)

2. **Start the Devbox shell** in the project directory:

   ```bash
   devbox shell
   ```

3. **Launch the environment**:

   ```bash
   docker-compose up -d
   ```

---

### 🐳 Option 2: Docker + Docker Compose

If you already have **Docker** and **Docker Compose** installed, you can skip Devbox.

1. Make sure Docker is running.
2. Start the environment:

   ```bash
   docker-compose up -d
   ```

---
### 🌐 Accessing the Database

Once the containers are running, navigate to:

👉 [http://localhost:8080](http://localhost:8080)

Use the following credentials for **pgAdmin**:

* **Email**: `admin@sqlbasics.ch`
* **Password**: `relational`

In pgAdmin, right-click on **Servers** and choose **Register** -> **Server...**. Then, enter the following details:

* **General Tab**
    * **Name:** `workshop-cluster`
* **Connection Tab**
    * **Hostname/address:** `db`
    * **Database:** `workshop`
    * **Username:** `postgres`
    * **Password:** `relational`

Now you are ready for action!

---

## 📝 Workshop Structure

All exercises are in the `exercises/` folder, organized into three sections:

1. **Basics** – Create tables, insert data, and write basic queries.
2. **Performance** – Optimize queries and explore indexing.
3. **Permission Management** – Control access with users and roles.

Each section includes:

- A `README.md` with instructions
- A `solution.sql` to check your work or get unstuck

---

## 🙋 Need Help?

This is a collaborative, beginner-friendly workshop. Ask questions any time—no question is too small!

---

Let’s dive into SQL! 🧠💻
