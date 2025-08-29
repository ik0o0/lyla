/*
 * This file is part of a project licensed under the GNU Lesser General Public License v3 (LGPLv3).
 *
 * You can redistribute it and/or modify it under the terms of the GNU LGPLv3 as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This code is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this project.  If not, see <https://www.gnu.org/licenses/>.
 */
module sqlite.sqlite;

import std.stdio;
import std.string : fromStringz, toStringz;

import sqlite.model;
import sqlite.column;
import sqlite.sqliteGenerator;

enum SQLiteResultCode : int
{
    SQLITE_OK = 0,              /* Successful result */
    SQLITE_ERROR = 1,           /* Generic error */
    SQLITE_INTERNAL = 2,        /* Internal logic error in SQLite */
    SQLITE_PERM = 3,            /* Access permission denied */
    SQLITE_ABORT = 4,           /* Callback routine requested an abort */
    SQLITE_BUSY = 5,            /* The database file is locked */
    SQLITE_LOCKED = 6,          /* A table in the database is locked */
    SQLITE_NOMEM = 7,           /* A malloc() failed */
    SQLITE_READONLY = 8,        /* Attempt to write a readonly database */
    SQLITE_INTERRUPT = 9,       /* Operation terminated by sqlite3_interrupt()*/
    SQLITE_IOERR = 10,          /* Some kind of disk I/O error occurred */
    SQLITE_CORRUPT = 11,        /* The database disk image is malformed */
    SQLITE_NOTFOUND = 12,       /* Unknown opcode in sqlite3_file_control() */
    SQLITE_FULL = 13,           /* Insertion failed because database is full */
    SQLITE_CANTOPEN = 14,       /* Unable to open the database file */
    SQLITE_PROTOCOL = 15,       /* Database lock protocol error */
    SQLITE_EMPTY = 16,          /* Internal use only */
    SQLITE_SCHEMA = 17,         /* The database schema changed */
    SQLITE_TOOBIG = 18,         /* String or BLOB exceeds size limit */
    SQLITE_CONSTRAINT = 19,     /* Abort due to constraint violation */
    SQLITE_MISMATCH = 20,       /* Data type mismatch */
    SQLITE_MISUSE = 21,         /* Library used incorrectly */
    SQLITE_NOLFS = 22,          /* Uses OS features not supported on host */
    SQLITE_AUTH = 23,           /* Authorization denied */
    SQLITE_FORMAT = 24,         /* Not used */
    SQLITE_RANGE = 25,          /* 2nd parameter to sqlite3_bind out of range */
    SQLITE_NOTADB = 26,         /* File opened that is not a database file */
    SQLITE_NOTICE = 27,         /* Notifications from sqlite3_log() */
    SQLITE_WARNING = 28,        /* Warnings from sqlite3_log() */
    SQLITE_ROW = 100,           /* sqlite3_step() has another row ready */
    SQLITE_DONE = 101,          /* sqlite3_step() has finished executing */
}

extern(C)
{
    struct sqlite3;
    struct sqlite3_stmt;

    int sqlite3_open(const char* filename, sqlite3** db);
    int sqlite3_close(sqlite3* db);
    int sqlite3_exec(
        sqlite3* db,                                // Database handle
        const char* sql,                            // SQL statement
        int function(void*, int, char**, char**),   // Callback function
        void*,                                      // First argument of callback function
        char** errmsg                               // Error message
    );
    int sqlite3_prepare_v2(
        sqlite3* db,                // Database handle
        const char* zSql,           // SQL statement
        int nByte,                  // Maximum length of zSql in bytes
        sqlite3_stmt** ppStmt,      // OUT: Statement handle
        const char** pzTail         // OUT: Pointer to unused portion of zSQL
    );
    int sqlite3_bind_text(
        sqlite3_stmt* stmt,
        int index,
        const char* text,
        int nByte,
        void function(void*) destructor
    );
    int sqlite3_step(sqlite3_stmt* stmt);
    const(char)* sqlite3_errmsg(sqlite3* db);
    int sqlite3_finalize(sqlite3_stmt* stmt);
    void sqlite3_free(void*);

    enum : void function(void*)
    {
        SQLITE_STATIC = null,
        SQLITE_TRANSIENT = cast(void function(void*))cast(void*)-1
    }
}

sqlite3* initSQLiteDatabase(const char* databaseName, SqliteModel[] models)
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

    return db;
}

/*
 * Unit tests
 */

// Unit test for initSQLiteDatabase() with :memory: should be writted but i struggle to do it so if you have a way to do it go on.
// Check CONTRIBUTIONS.md and submit your PR.
