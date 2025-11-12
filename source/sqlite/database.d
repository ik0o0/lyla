module sqlite.database;

import std.stdio;
import std.string : toStringz, fromStringz;

import sqlite.sqlite;
import sqlite.model;
import sqlite.sqliteGenerator;

// I need to add a readable property (boolean) to Database so I'll know if it's a master or slave db
struct Database
{
    string name;
}

Database createDatabase(const char* databaseName, SqliteModel[] models)
{
    sqlite3* db;
    if (sqlite3_open(databaseName, &db) != 0)
    {
        throw new Exception("Error when opening the database.");
    }

    char* errMsg = null;
    if (sqlite3_exec(db, toStringz("PRAGMA foreign_keys = ON;"), null, null, &errMsg) != 0)
    {
        writeln("SQLite Error: ", fromStringz(errMsg).idup);
        sqlite3_free(errMsg);
    }

    string strInitStmt = "";
    foreach (model; models)
    {
        string tableName = model.getTableName();
        string columnStmt = SQLiteGenerator.createColumnStmt(model.getColumns());
        string stmt = SQLiteGenerator.createTableStmt(tableName, columnStmt);
        strInitStmt ~= stmt;
    }

    const char* initStmt = toStringz(strInitStmt);
    if (sqlite3_exec(db, initStmt, null, null, &errMsg) != 0) {
        writeln("SQLite Error: ", fromStringz(errMsg).idup);
        sqlite3_free(errMsg);
    }

    sqlite3_close(db);

    Database d;
    d.name = fromStringz(databaseName).idup;
    return d;
}


sqlite3* openDatabase(Database database)
{
    sqlite3* db;
    if (sqlite3_open(toStringz(database.name), &db) != 0)
        throw new Exception("Error when opening the database.");

    return db;
}
