module sqlite.repository;


import std.stdio;
import std.array;
import std.string : toStringz, fromStringz;

import sqlite.column;
import sqlite.model;

import sqlite.sqlite : sqlite3, sqlite3_stmt, sqlite3_exec, sqlite3_prepare_v2, sqlite3_free, SQLiteResultCode, sqlite3_bind_text, sqlite3_step, sqlite3_errmsg, sqlite3_finalize, SQLITE_TRANSIENT;

class SqliteRepository
{
private:
    SqliteModel model;
    string tableName;
    sqlite3* db;

public:
    this(SqliteModel model, sqlite3* db)
    {
        this.model = model;
        this.tableName = this.model.getTableName();
        this.db = db;
    }

    // Repository.insert([User.column("name")], ["John"]);
    void insert(SqliteColumn[] columns, string[] values)
    {
        string[] columnNames;
        string[] colVal;
        foreach (column; columns)
        {
            columnNames ~= column.getColumnName();
            colVal ~= "?";
        }

        // I think to do a wrapper function for the prepared requests.
        // something like this
        // void exec(sqlite3* db, string stmt, string[] values) {}

        string stmtStr = "INSERT INTO " ~ this.tableName ~ " (" ~ columnNames.join(", ") ~ ") VALUES(" ~ colVal.join(", ") ~ ");";
        sqlite3_stmt* stmt;
        if (sqlite3_prepare_v2(this.db, toStringz(stmtStr), -1, &stmt, null) != SQLiteResultCode.SQLITE_OK)
        {
            writeln("Failed to prepare statement.");
            return;
        }

        foreach (i, value; values)
        {
            sqlite3_bind_text(
                stmt,
                cast(int)(i+1),
                toStringz(value),
                -1,
                SQLITE_TRANSIENT);
        }

        if (sqlite3_step(stmt) != SQLiteResultCode.SQLITE_DONE)
        {
            writeln("Insert failed: " ~ fromStringz(sqlite3_errmsg(this.db)).idup);
            return;
        }

        sqlite3_finalize(stmt);
    }
}

/*
 * Unit tests
 */
