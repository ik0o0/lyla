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
module sqlite.repository;

import std.stdio;
import std.array;
import std.string : toStringz, fromStringz;
import std.conv;
import std.variant;
import std.algorithm : map, canFind;
import std.range : join;

import sqlite.column;
import sqlite.model;

import sqlite.sqlite;
import sqlite.database;

// Alias for DX
alias Row = string[string];
alias Rows = Row[];

enum Operators : string
{
    equal = "=",
    greater = ">",
    less = "<",
    greaterOrEqual = ">=",
    lessOrEqual = "<=",
    notEqual = "!=",
    like = "LIKE",
    inList = "IN"
}

enum SortMethod : string
{
    ASC = "ASC",
    DESC = "DESC"
}

// enum Query : string
// {
//     SELECT = "SELECT",
//     WHERE = "WHERE",
//     AND = "AND",
//     OR = "OR",
//     ORDER_BY = "ORDER BY",
//     GROUP_BY = "GROUP BY",
//     LIMIT = "LIMIT"
// }

VariantN!32LU toVariant(T)(T value)
{
    return VariantN!32LU(value);
}

class SqliteRepository
{
private:
    SqliteModel model;
    string tableName;
    Database[] databases;

    string stagedStmt;
    Variant[] stagedValues;

    // Query[] queryState; // I dont know if an array is the better for the performance... maybe it's better to have multiple private variable to manage the state of the query/stagedStmt

    bool[string] queryState;

public:
    /* IMPORTANT TODO
     *
     * I need to update the support for mutltiple databases
     * I need to take care of the IO flow
     */
    this(SqliteModel model, Database[] databases)
    {
        this.model = model;
        this.tableName = this.model.getTableName();
        this.databases = databases;
        this.queryState = [
            "SELECT": false,
            "WHERE": false,
            "AND": false,
            "OR": false,
            "ORDER_BY": false,
            "GROUP_BY": false,
            "LIMIT": false
        ];
    }

    // Repository.insert([User.column("name")], [toVariant("John")]);
    void insert(SqliteColumn[] columns, Variant[] values)
    {
        foreach (database; this.databases)
        {
            sqlite3* db = openDatabase(database);

            string[] columnNames;
            string[] colVal;
            foreach (column; columns)
            {
                columnNames ~= column.getColumnName();
                colVal ~= "?";
            }

            string stmtStr = "INSERT INTO " ~ this.tableName ~ " (" ~ columnNames.join(", ") ~ ") VALUES(" ~ colVal.join(", ") ~ ");";
            sqlite3_stmt* stmt;
            if (sqlite3_prepare_v2(db, toStringz(stmtStr), -1, &stmt, null) != SQLiteResultCode.SQLITE_OK)
            {
                writeln("Failed to prepare statement.");
                return;
            }

            foreach (i, value; values)
            {
                if (value.type == typeid(int))
                {
                    sqlite3_bind_int(
                        stmt,
                        cast(int)(i+1),
                        value.get!(int));
                }
                else if (value.type == typeid(double))
                {
                    sqlite3_bind_double(
                        stmt,
                        cast(int)(i+1),
                        value.get!(double));
                }
                else if (value.type == typeid(string))
                {
                    sqlite3_bind_text(
                        stmt,
                        cast(int)(i+1),
                        toStringz(value.get!(string)),
                        -1,
                        SQLITE_TRANSIENT);
                }
                else
                {
                    throw new Exception("Unsupported type.");
                }
            }

            if (sqlite3_step(stmt) != SQLiteResultCode.SQLITE_DONE)
            {
                writeln("Insert failed: " ~ fromStringz(sqlite3_errmsg(db)).idup);
                return;
            }

            sqlite3_finalize(stmt);
            sqlite3_close(db);
        }
    }

    // SELECT id, username FROM users WHERE username = test AND salary > 1000 ORDER BY salary ASC;
    //
    // userRepositorycolumns
    //     .select([User.column("id"), User.column("username")])
    //     .where(User.column("username"), Operators.equal, "test")
    //     .and("salary", Operator.greater, "1000")
    //     .orderBy([User.column("salary")], Sort.ASC)
    //     .execute();
    //
    // Expected stmt after parse(): SELECT id, username FROM users WHERE username = ? AND salary > ? ORDER BY salary ASC;
    string[string][] execute()
    {
        // Instead of get the first database of the array i have to implement a multithreaded approach to take the database who's not used and i need to check if the database is a readable one.
        Database database = this.databases[0];
        sqlite3* db = openDatabase(database);

        sqlite3_stmt* stmt;
        auto rc = sqlite3_prepare_v2(db, toStringz(this.stagedStmt), -1, &stmt, null);
        if (rc != SQLiteResultCode.SQLITE_OK)
        {
            writeln("SQlite Error Code: ", rc);
            writeln("SQLite Error Message: ", fromStringz(sqlite3_errmsg(db)));
            throw new Exception("Failed to prepare statement.");
        }

        foreach (i, value; this.stagedValues)
        {
            if (value.type == typeid(int))
            {
                sqlite3_bind_int(
                    stmt,
                    cast(int)(i+1),
                    value.get!(int));
            }
            else if (value.type == typeid(double))
            {
                sqlite3_bind_double(
                    stmt,
                    cast(int)(i+1),
                    value.get!(double));
            }
            else if (value.type == typeid(string))
            {
                sqlite3_bind_text(
                    stmt,
                    cast(int)(i+1),
                    toStringz(value.get!(string)),
                    -1,
                    SQLITE_TRANSIENT);
            }
            else
            {
                throw new Exception("Unsupported type.");
            }
        }

        string[string][] rows;
        int columnCount = sqlite3_column_count(stmt);
        if (columnCount > 0)
        {
            while (sqlite3_step(stmt) == SQLiteResultCode.SQLITE_ROW)
            {
                string[string] row;
                for (int i = 0; i < columnCount; i++)
                {
                    string colName = fromStringz(sqlite3_column_name(stmt, i)).idup;
                    string colVal = fromStringz(sqlite3_column_text(stmt, i)).idup;
                    row[colName] = colVal;
                }
                rows ~= row;
            }
        }

        // Flush the values
        this.stagedStmt = string.init;
        this.stagedValues = Variant[].init;
        this.queryState = [
            "SELECT": false,
            "WHERE": false,
            "AND": false,
            "OR": false,
            "ORDER_BY": false,
            "GROUP_BY": false,
            "LIMIT": false
        ];

        sqlite3_finalize(stmt);
        sqlite3_close(db);
        return rows;
        // return rows = [["id": "1", "username": "iko"], ["id": "2", "username": "Penny"]];
    }

    SqliteRepository select()
    {
        if (this.queryState["SELECT"] == true)
            throw new Exception("You cannot select two times in the same query.");

        this.stagedStmt ~= "SELECT * FROM " ~ this.tableName ~ " ";
        this.queryState["SELECT"] = true;
        return this;
    }

    SqliteRepository select(SqliteColumn[] columns)
    {
        if (this.queryState["SELECT"] == true)
            throw new Exception("You cannot select two times in the same query.");

        this.stagedStmt ~= "SELECT " ~ columns.map!(col => col.getColumnName()).join(", ") ~ " FROM " ~ this.tableName ~ " ";
        this.queryState["SELECT"] = true;
        return this;
    }

    SqliteRepository where(SqliteColumn field, Operators operator, string variant)
    {
        if (this.queryState["WHERE"] == true)
            throw new Exception("You cannot execute where two times in the same query.");

        this.stagedStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState["WHERE"] = true;
        return this;
    }

    SqliteRepository where(SqliteColumn field, Operators operator, int variant)
    {
        if (this.queryState["WHERE"] == true)
            throw new Exception("You cannot execute where two times in the same query.");

        this.stagedStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState["WHERE"] = true;
        return this;
    }

    SqliteRepository where(SqliteColumn field, Operators operator, double variant)
    {
        if (this.queryState["WHERE"] == true)
            throw new Exception("You cannot execute where two times in the same query.");

        this.stagedStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState["WHERE"] = true;
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, string variant)
    {
        if (this.queryState["WHERE"] == false)
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");

        this.stagedStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState["AND"] = true;
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, double variant)
    {
        if (this.queryState["WHERE"] == false)
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");

        this.stagedStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState["AND"] = true;
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, int variant)
    {
        if (this.queryState["WHERE"] == false)
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");

        this.stagedStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState["AND"] = true;
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, string variant)
    {
        if (this.queryState["WHERE"] == false)
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");

        this.stagedStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState["OR"] = true;
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, double variant)
    {
        if (this.queryState["WHERE"] == false)
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");

        this.stagedStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState["OR"] = true;
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, int variant)
    {
        if (this.queryState["WHERE"] == false)
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");

        this.stagedStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState["OR"] = true;
        return this;
    }

    SqliteRepository orderBy(SqliteColumn[] columns, SortMethod sort)
    {
        if (this.queryState["SELECT"] == false)
            throw new Exception("Invalid query. A SELECT query with an ORDER BY clause is required.");

        this.stagedStmt ~= "ORDER BY " ~ columns.map!(col => col.getColumnName()).join(", ") ~ " " ~ sort ~ " ";
        this.queryState["ORDER_BY"] = true;
        return this;
    }

    SqliteRepository groupBy(SqliteColumn[] columns)
    {
        if (this.queryState["ORDER_BY"] == true)
            throw new Exception("Invalid query. A GROUP BY clause should precede an ORDER BY clause.");

        this.stagedStmt ~= "GROUP BY " ~ columns.map!(col => col.getColumnName()).join(", ") ~ " ";
        this.queryState["GROUP_BY"] = true;
        return this;
    }

    SqliteRepository limit(int nLimit)
    {
        if (this.queryState["SELECT"] == false)
            throw new Exception("Invalid query. A LIMIT clause should follow a SELECT clause.");
        
        this.stagedStmt ~= "LIMIT " ~ to!string(nLimit) ~ " ";
        this.queryState["LIMIT"] = true;
        return this;
    }
}

/*
 * Unit tests
 */
unittest
{
    // import sqlite.implementModel;
    // import sqlite.sqlite;

    // SqliteModel User = new SqliteImplementModel("users_table")
    //     .column("id", SqliteColumnTypes.INTEGER).primaryKey().autoIncrement()
    //     .column("username", SqliteColumnTypes.TEXT).notNull()
    //     .column("salary", SqliteColumnTypes.INTEGER).notNull()
    //     .finalize()
    //     .build();
    
    // auto db = initSQLiteDatabase("test.db", [User]);
    
    // SqliteRepository userRepository = new SqliteRepository(User, db);

    // // SELECT id, username FROM users WHERE username = test AND salary > 1000 ORDER BY salary ASC;
    // Rows users = userRepository
    //     .select([User.column("id"), User.column("username")])
    //     .where(User.column("username"), Operators.equal, "test")
    //     .and(User.column("salary"), Operators.greater, "1000")
    //     .orderBy([User.column("salary")], SortMethod.ASC)
    //     .parse()
    //     .execute();
    
    // foreach (user; users)
    // {
    //     string userId = user["id"];
    //     string username = user["username"];
    //     writeln("userId: " ~ userId ~ " username: " ~ username);
    // }
}
