# Lyla

### 🚧 Status: Early development — usable but evolving.

Lyla is a lightweight D library for interacting with relational databases.
It provides a minimal ORM-like abstraction to handle tables as objects without relying on deprecated drivers or full ORM frameworks.

Currently, Lyla supports SQLite and PostgreSQL (via the C API).

```
Lyla/
│
├─ source/
│  ├─ psql/
│  │  ├─ psql.d
│  │  ├─ psqlGenerator.d
│  │  ├─ column.d
│  │  └─ model.d
│  ├─ sqlite/
│  │  ├─ sqlite.d
│  │  ├─ sqliteGenerator.d
│  │  ├─ implementModel.d
│  │  ├─ column.d
│  │  └─ model.d
```

## ✨ Features
- 🎯 Lightweight abstraction for interacting with relational tables
- 📦 Minimal dependencies (directly uses C API)
- 🪶 Handles table creation with columns, primary keys, uniqueness, nullable, and auto-increment properties
- ⚙️ CRUD operations

## 🚀 Installation & Usage
Lyla is currently not distributed via a package manager.

Lyla SQLite is ready!

To use it:

1. Copy the ```lyla/``` folder into your D project.
2. Import the relevant modules (```sqlite```, ```model```, ```column```) in your code.
3. Add ```"libs": ["sqlite3"]``` to your dub.json or the equivalent in sdl.
5. Compile your project normally.

### Minimal Example
```d
import sqlite.sqlite;
import sqlite.repository;
import sqlite.implementModel;
import sqlite.column : SqliteColumnTypes;

void main()
{
  auto User = new SqliteImplementModel("users_table")
    .column("id", SqliteColumnTypes.INTEGER).primaryKey().autoIncrement()
    .column("username", SqliteColumnTypes.TEXT).notNull().unique()
    .column("password", SqliteColumnTypes.TEXT).notNull()
    .build();

  auto Post = new SqliteImplementModel("posts_table")
    .column("id", SqliteColumnTypes.INTEGER).primaryKey().autoIncrement();
    .column("content", SqliteColumnTypes.TEXT).notNull()
    .column("userId", SqliteColumnTypes.INTEGER, User, User.column("id"))
    .build();
  
  auto db = initSQLiteDatabase("example-database.db", [User, Post]);

  auto userRepository = new SqliteRepository(User, db);
  auto postRepository = new SqliteRepository(Post, db);

  userRepository.insert(
    [User.column("username"), User.column("password")],
    [toVariant("testName"), toVariant("testPass")]
  );

  string userId = userRepository
    .select([User.column("id")])
    .where(User.column("username"), Operators.equal, "testName")
    .execute()[0]["id"];

  foreach (i; i..5)
  {
    postRepository.insert(
      [Post.column("content"), Post.column("userId")],
      [toVariant(to!string(i) ~ ". Test content here"), toVariant(to!int(userId))]
    );
  }

  string[string][] res = postRepository
    .select()
    .where(Post.column("userId"), Operators.equal, 1)
    .orderBy([Post.column("id")], SortMethod.ASC)
    .limit(3)
    .execute();
  
  writeln(res);
  /* output:
   * [
   *   ["id": "1", "content": "1. Test content here", "userId": "1"]
   *   ["id": "2", "content": "2. Test content here", "userId": "1"]
   *   ["id": "3", "content": "3. Test content here", "userId": "1"]
   * ]
   */
}
```

This minimal example shows how to define and use SQLite models with Lyla. It creates two tables — users_table and posts_table — using SqliteImplementModel, with a one-to-many relationship between users and posts. The database is initialized with initSQLiteDatabase, and repositories (SqliteRepository) are used to insert and query data without writing raw SQL. The code inserts one user, adds several posts linked to that user, and retrieves the first three posts ordered by their ID.

## 🛣️ Roadmap
- ✅ SQLite support
- ✅ Extra abstraction layer for SQLite
- ✅ CRUD operations for SQLite
- ❌ Pool management for SQLite
- ✅ PostgreSQL support
- ❌ Extra abstraction layer for PostgreSQL
- ❌ CRUD operations for PostgreSQL
- ❌ Pool management for PostgreSQL
- ❌ Starter template for easier project integration

## 🧪 Testing
- Unit tests are included in each module (```unittest``` blocks).
- Example: ```sqlite/column.d``` includes tests for ```SqliteColumn``` getters/setters.
- Tests can be run with the D compiler using dub test if configured.

## 📜 License

Lyla is open source, released under the LGPLv3 license.
You can redistribute and/or modify it under the terms of the GNU Lesser General Public License v3.
