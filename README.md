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

## 🚀 Installation & Usage
Lyla is currently not distributed via a package manager.

To use it:

1. Copy the ```lyla/``` folder into your D project.
2. Import the relevant modules (```sqlite```, ```model```, ```column```) in your code.
3. Add ```"libs": ["sqlite3"]``` to your dub.json or the equivalent in sdl.
5. Compile your project normally.

### Minimal Example
```d
import sqlite.sqlite;
import sqlite.column : SqliteColumnTypes;
import sqlite.implementModel;

void main()
{
  auto User = new SqliteImplementModel("users_table")
      .column("id", SqliteColumnTypes.INTEGER).primaryKey().autoIncrement()
      .column("username", SqliteColumnTypes.TEXT).notNull().unique()
      .finalize()
      .build();

  auto Post = new SqliteImplementModel("posts_table")
      .column("id", SqliteColumnTypes.INTEGER).primaryKey().autoIncrement()
      .column("userId", SqliteColumnTypes.INTEGER, User, User.getColumnByName("id")) // FK column REF user.id
      .finalize()
      .build();

  initSQLiteDatabase("database.db", [User, Post]);
}
```

This will create a SQLite database example.db with a users table containing id and username columns.

## 🛣️ Roadmap
- ✅ SQLite support
- ✅ PostgreSQL support
- ✅ Extra abstraction layer for SQLite
- ❌ Extra abstraction layer for PostgreSQL
- ❌ Starter template for easier project integration
- ❌ CRUD operations

## 🧪 Testing
- Unit tests are included in each module (```unittest``` blocks).
- Example: ```sqlite/column.d``` includes tests for ```SqliteColumn``` getters/setters.
- Tests can be run with the D compiler using dub test if configured.

## 📜 License

Lyla is open source, released under the LGPLv3 license.
You can redistribute and/or modify it under the terms of the GNU Lesser General Public License v3.
