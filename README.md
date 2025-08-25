# Lyla

### 🚧 Status: Early development — usable but evolving.

Lyla is a lightweight D library for interacting with relational databases.
It provides a minimal ORM-like abstraction to handle tables as objects without relying on deprecated drivers or full ORM frameworks.

Currently, Lyla supports SQLite (via the C API). PostgreSQL support is planned for future versions.

```
Lyla/
│
├─ source/
│  ├─ sqlite/
│  │  ├─ sqlite.d
│  │  └─ sqliteGenerator.d
│  ├─ column.d
│  └─ model.d
```
- ```sqlite/``` — Contains SQLite integration and SQL generator logic.
- ```column.d``` — Defines the ```Column``` class and column types.
- ```model.d``` — Defines the ```Model``` class for representing database tables.

## ✨ Features
- 🎯 Lightweight abstraction for interacting with relational tables
- 📦 Minimal dependencies (directly uses SQLite C API)
- 🪶 Handles table creation with columns, primary keys, uniqueness, nullable, and auto-increment properties
- 🔜 Planned PostgreSQL support

## 🚀 Installation & Usage
Lyla is currently not distributed via a package manager.

To use it:

1. Copy the ```lyla/``` folder into your D project.
2. Import the relevant modules (```sqlite```, ```model```, ```column```) in your code.
3. Add ```"libs": ["sqlite3"]``` to your dub.json or the equivalent in sdl.
5. Compile your project normally.

### Minimal Example
```d
import std.stdio;
import sqlite.sqlite;
import model;
import column;

void main()
{
  // Define columns
  auto idColumn = new Column("id", ColumnTypes.INTEGER);
  idColumn.setPrimaryKey(true);
  idColumn.setAutoIncrement(true);

  auto nameColumn = new Column("username", ColumnTypes.TEXT);
  nameColumn.setUnique(true);
  nameColumn.setNullable(false);

  // Define table model
  auto userModel = new Model("users", [idColumn, nameColumn]);

  // Initialize SQLite database
  initSQLiteDatabase("example.db", [userModel]);
}
```

This will create a SQLite database example.db with a users table containing id and username columns.

## 🛣️ Roadmap
- ✅ SQLite support
- ❌ PostgreSQL support
- ❌ Starter template for easier project integration
- ❌ Extra abstraction layer for higher-level operations
- ❌ CRUD operations

## 🧪 Testing
- Unit tests are included in each module (```unittest``` blocks).
- Example: ```column.d``` includes tests for ```Column``` getters/setters.
- Tests can be run with the D compiler using dub test if configured.

## 📜 License

Lyla is open source, released under the LGPLv3 license.
You can redistribute and/or modify it under the terms of the GNU Lesser General Public License v3.
