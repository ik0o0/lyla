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
import std.string;
import core.stdc.stdlib : free;

import model;
import column;
import sqlite.sqliteGenerator;

extern(C):
    int sqlite3_open(const char* filename, void** db);
    int sqlite3_close(void* db);
    int sqlite3_exec(
        void* db,                                   // Database
        const char* sql,                            // SQL statement
        int function(void*, int, char**, char**),   // Callback function
        void*,                                      // First argument of callback function
        char** errmsg                               // Error message
    );

void initSQLiteDatabase(const char* databaseName, Model[] models)
{
    void* db;
    if (sqlite3_open(databaseName, &db) != 0)
    {
        writeln("Error when opening the database.");
        return;
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
    char* errMsg = null;
    if (sqlite3_exec(db, initStmt, null, null, &errMsg) != 0) {
        writeln("SQLite Error: ", errMsg);
        free(errMsg);
    }
}

/*
 * Unit tests
 */

// Unit test for initSQLiteDatabase() with :memory: should be writed but i struggle to do it so if you have a way to do it go on.
// Check CONTRIBUTIONS.md and submit your PR.
