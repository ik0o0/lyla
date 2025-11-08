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

enum Query : string
{
    SELECT = "SELECT",
    WHERE = "WHERE",
    AND = "AND",
    OR = "OR",
    ORDER_BY = "ORDER BY",
    GROUP_BY = "GROUP BY",
    LIMIT = "LIMIT"
}

VariantN!32LU toVariant(T)(T value)
{
    return VariantN!32LU(value);
}

class SqliteRepository
{
private:
    SqliteModel model;
    string tableName;
    sqlite3* db;

    string stagedStmt;
    Variant[] stagedValues;

    Query[] queryState; // I dont know if an array is the better for the performance... maybe it's better to have multiple private variable to manage the state of the query/stagedStmt

public:
    /* IMPORTANT TODO
     *
     * I need to add the support for multiple databases so we can do:
     * 
     * auto db1 = initSQLiteDatabase("lyla-database.db", [Model1, Model2]);
     * auto db2 = initSQLiteDatabase("lyla-database2.db", [Model1, Model2]);
     *
     * auto model1Repository = new SqliteRepository(User, [db1, db2]);
     * auto model2Repository = new SqliteRepository(Post, [db1, db2]);
     */
    this(SqliteModel model, sqlite3* db)
    {
        this.model = model;
        this.tableName = this.model.getTableName();
        this.db = db;
    }

    // Repository.insert([User.column("name")], [toVariant("John")]);
    void insert(SqliteColumn[] columns, Variant[] values)
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
            writeln("Insert failed: " ~ fromStringz(sqlite3_errmsg(this.db)).idup);
            return;
        }

        sqlite3_finalize(stmt);
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
        // To add the support for multiple databases I think we can just do foreach (database; this.databases) { and the actual body of execute here with the db slice instead of this.db }
        sqlite3_stmt* stmt;
        auto rc = sqlite3_prepare_v2(this.db, toStringz(this.stagedStmt), -1, &stmt, null);
        if (rc != SQLiteResultCode.SQLITE_OK)
        {
            writeln("SQlite Error Code: ", rc);
            writeln("SQLite Error Message: ", fromStringz(sqlite3_errmsg(this.db)));
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
        this.queryState = Query[].init;

        sqlite3_finalize(stmt);
        return rows; // return rows = [["id": "1", "username": "iko"], ["id": "2", "username": "Penny"]];
    }

    SqliteRepository select()
    {
        if (this.queryState.canFind(Query.SELECT))
            throw new Exception("You cannot select two times in the same query.");

        this.stagedStmt ~= "SELECT * FROM " ~ this.tableName ~ " ";
        this.queryState ~= Query.SELECT;
        return this;
    }

    SqliteRepository select(SqliteColumn[] columns)
    {
        if (this.queryState.canFind(Query.SELECT))
            throw new Exception("You cannot select two times in the same query.");

        this.stagedStmt ~= "SELECT " ~ columns.map!(col => col.getColumnName()).join(", ") ~ " FROM " ~ this.tableName ~ " ";
        this.queryState ~= Query.SELECT;
        return this;
    }

    SqliteRepository where(SqliteColumn field, Operators operator, string variant)
    {
        if (this.queryState.canFind(Query.WHERE))
            throw new Exception("You cannot execute where two times in the same query.");

        this.stagedStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState ~= Query.WHERE;
        return this;
    }

    SqliteRepository where(SqliteColumn field, Operators operator, int variant)
    {
        if (this.queryState.canFind(Query.WHERE))
            throw new Exception("You cannot execute where two times in the same query.");

        this.stagedStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState ~= Query.WHERE;
        return this;
    }

    SqliteRepository where(SqliteColumn field, Operators operator, double variant)
    {
        if (this.queryState.canFind(Query.WHERE))
            throw new Exception("You cannot execute where two times in the same query.");

        this.stagedStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState ~= Query.WHERE;
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, string variant)
    {
        if (!this.queryState.canFind(Query.WHERE))
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");

        this.stagedStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState ~= Query.AND;
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, double variant)
    {
        if (!this.queryState.canFind(Query.WHERE))
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");

        this.stagedStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState ~= Query.AND;
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, int variant)
    {
        if (!this.queryState.canFind(Query.WHERE))
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");

        this.stagedStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState ~= Query.AND;
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, string variant)
    {
        if (!this.queryState.canFind(Query.WHERE))
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");

        this.stagedStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState ~= Query.OR;
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, double variant)
    {
        if (!this.queryState.canFind(Query.WHERE))
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");

        this.stagedStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState ~= Query.OR;
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, int variant)
    {
        if (!this.queryState.canFind(Query.WHERE))
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");

        this.stagedStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.stagedValues ~= toVariant(variant);
        this.queryState ~= Query.OR;
        return this;
    }

    SqliteRepository orderBy(SqliteColumn[] columns, SortMethod sort)
    {
        if (!this.queryState.canFind(Query.SELECT))
            throw new Exception("Invalid query. A SELECT query with an ORDER BY clause is required.");

        this.stagedStmt ~= "ORDER BY " ~ columns.map!(col => col.getColumnName()).join(", ") ~ " " ~ sort ~ " ";
        this.queryState ~= Query.ORDER_BY;
        return this;
    }

    SqliteRepository groupBy(SqliteColumn[] columns)
    {
        if (!this.queryState.canFind(Query.WHERE))
            throw new Exception("Invalid query. A GROUP BY clause should follow a WHERE clause.");

        if (this.queryState.canFind(Query.ORDER_BY))
            throw new Exception("Invalid query. A GROUP BY clause should precede an ORDER BY clause.");

        this.stagedStmt ~= "GROUP BY " ~ columns.map!(col => col.getColumnName()).join(", ") ~ " ";
        this.queryState ~= Query.GROUP_BY;
        return this;
    }

    SqliteRepository limit(int nLimit)
    {
        if (!this.queryState.canFind(Query.SELECT))
            throw new Exception("Invalid query. A LIMIT clause should follow a SELECT clause.");
        
        this.stagedStmt ~= "LIMIT " ~ to!string(nLimit) ~ " ";
        this.queryState ~= Query.LIMIT;
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
