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
    
    string selectStmt;

    string whereStmt;
    Variant[] whereVariant;

    string andStmt; // AND salary > ? AND username = ?
    Variant[] andVariants; // [1000, "test"]

    string orStmt;
    Variant[] orVariants;

    string orderByStmt;

    string groupByStmt;

    string limitStmt;

    string stagedStmt;
    Variant[] stagedValues;

    void push_SELECT()
    {
        this.stagedStmt ~= this.selectStmt ~ "FROM " ~ this.tableName ~ " ";
    }

    void push_WHERE()
    {
        this.stagedStmt ~= this.whereStmt;
        this.stagedValues ~= this.whereVariant; // Add the variant in stagedValues before doing ANYTHING, like that we have a list of variants(values) who's in the order for match with our "?" in stagedStmt when we're gonna bind our stmt with C interop
    }

    void push_AND()
    {
        this.stagedStmt ~= this.andStmt;
        this.stagedValues ~= this.andVariants;
    }

    void push_OR()
    {
        this.stagedStmt ~= this.orStmt;
        this.stagedValues ~= this.orVariants;
    }

    void push_ORDER_BY()
    {
        this.stagedStmt ~= this.orderByStmt;
    }

    void push_GROUP_BY()
    {
        this.stagedStmt ~= this.groupByStmt;
    }

    void push_LIMIT()
    {
        this.stagedStmt ~= this.limitStmt;
    }

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

    // SELECT id, username FROM users WHERE username = test AND salary > 1000 ORDER BY salary ASC;
    //
    // userRepository
    //     .select([User.column("id"), User.column("username")])
    //     .where("username", Operators.equal, "test")
    //     .and("salary", Operator.greater, "1000")
    //     .orderBy([User.column("salary")], Sort.ASC)
    //     .execute();
    //
    // Expected stmt after parse(): SELECT id, username FROM users WHERE username = ? AND salary > ? ORDER BY salary ASC;
    string[string][] execute()
    {
        sqlite3_stmt* stmt;
        if (sqlite3_prepare_v2(this.db, toStringz(this.stagedStmt), -1, &stmt, null) != SQLiteResultCode.SQLITE_OK)
        {
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

        sqlite3_finalize(stmt);
        return rows; // return rows = [["id": "1", "username": "iko"], ["id": "2", "username": "Penny"]];
    }

    // IMPORTANT TODO: We ABSOLUTELY have to find a better way than 'if else' statements to do this
    // The code i've write in parse() terrified me!
    // I think my approach in repository.d isn't very good, but actually i just want something that works
    /** 
     * Idk why i use a parse() method instead of pushing the stmt and values in stagesStmt/stagedValues directly when
     * select(), where(), groupBy(), ... methods are called, maybe it's the answer, i know that this approach will result in the
     * possibility of calling an and() method before a select() method but we can implement a state management easily for check the
     * status of the query before pushing or we can just let the developer throw an Exception.
     */
    SqliteRepository parse()
    {
        // SELECT
        if (this.selectStmt !is null)
        {
            push_SELECT();

            // WHERE
            if (this.whereStmt !is null &&
                this.whereVariant !is null)
            {
                push_WHERE();

                // AND
                if (this.andStmt !is null &&
                    this.andVariants !is null)
                {
                    push_AND();

                    // OR
                    if (this.orStmt !is null &&
                        this.orVariants !is null)
                    {
                        push_OR();

                        // GROUP BY
                        if (this.groupByStmt !is null)
                        {
                            push_GROUP_BY();

                            // ORDER BY
                            if (this.orderByStmt !is null)
                            {
                                push_ORDER_BY();

                                // LIMIT
                                if (this.limitStmt !is null)
                                {
                                    push_LIMIT();
                                }
                            }
                            // LIMIT
                            else if (this.limitStmt !is null)
                            {
                                push_LIMIT();
                            }
                        }
                        // ORDER BY
                        else if (this.orderByStmt !is null)
                        {
                            push_ORDER_BY();

                            // LIMIT
                            if (this.limitStmt !is null)
                            {
                                push_LIMIT();
                            }
                        }
                        // LIMIT
                        else if (this.limitStmt !is null)
                        {
                            push_LIMIT();
                        }
                    }
                    // GROUP BY
                    else if (this.groupByStmt !is null)
                    {
                        push_GROUP_BY();

                        // ORDER BY
                        if (this.orderByStmt !is null)
                        {
                            push_ORDER_BY();

                            // LIMIT
                            if (this.limitStmt !is null)
                            {
                                push_LIMIT();
                            }
                        }
                        else if (this.limitStmt !is null)
                        {
                            push_LIMIT();
                        }
                    }
                    // ORDER BY
                    else if (this.orderByStmt !is null)
                    {
                        push_ORDER_BY();

                        // LIMIT
                        if (this.limitStmt !is null)
                        {
                            push_LIMIT();
                        }
                    }
                    // LIMIT
                    else if (this.limitStmt !is null)
                    {
                        push_LIMIT();
                    }
                }
                // OR
                else if (this.orStmt !is null &&
                        this.orVariants !is null)
                {
                    push_OR();

                    // GROUP BY
                    if (this.groupByStmt !is null)
                    {
                        push_GROUP_BY();

                        // ORDER BY
                        if (this.orderByStmt !is null)
                        {
                            push_ORDER_BY();

                            // LIMIT
                            if (this.limitStmt !is null)
                            {
                                push_LIMIT();
                            }
                        }
                        // LIMIT
                        else if (this.limitStmt !is null)
                        {
                            push_LIMIT();
                        }
                    }
                    // ORDER BY
                    else if (this.orderByStmt !is null)
                    {
                        push_ORDER_BY();
                        
                        // LIMIT
                        if (this.limitStmt !is null)
                        {
                            push_LIMIT();
                        }
                    }
                    // LIMIT
                    else if (this.limitStmt !is null)
                    {
                        push_LIMIT();
                    }
                }
                // GROUP BY
                else if (this.groupByStmt !is null)
                {
                    push_GROUP_BY();

                    // ORDER BY
                    if (this.orderByStmt !is null)
                    {
                        push_ORDER_BY();

                        // LIMIT
                        if (this.limitStmt !is null)
                        {
                            push_LIMIT();
                        }
                    }
                    // LIMIT
                    else if (this.limitStmt !is null)
                    {
                        push_LIMIT();
                    }
                }
                // ORDER BY
                else if (this.orderByStmt !is null)
                {
                    push_ORDER_BY();

                    // LIMIT
                    if (this.limitStmt !is null)
                    {
                        push_LIMIT();
                    }
                }
                // LIMIT
                else if (this.limitStmt !is null)
                {
                    push_LIMIT();
                }
            }
            // GROUP BY
            else if (this.groupByStmt !is null)
            {
                push_GROUP_BY();

                // ORDER BY
                if (this.orderByStmt !is null)
                {
                    push_ORDER_BY();

                    // LIMIT
                    if (this.limitStmt !is null)
                    {
                        push_LIMIT();
                    }
                }
                // LIMIT
                else if (this.limitStmt !is null)
                {
                    push_LIMIT();
                }
            }
            // ORDER BY
            else if (this.orderByStmt !is null)
            {
                push_ORDER_BY();
                
                // LIMIT
                if (this.limitStmt !is null)
                {
                    push_LIMIT();
                }
            }
            // LIMIT
            else if (this.limitStmt !is null)
            {
                push_LIMIT();
            }
        }
        return this;
    }

    SqliteRepository select()
    {
        if (this.selectStmt !is null)
        {
            throw new Exception("You cannot select two times int the same query.");
        }

        this.selectStmt ~= "SELECT * ";
        return this;
    }

    SqliteRepository select(SqliteColumn[] columns)
    {
        if (this.selectStmt !is null)
        {
            throw new Exception("You cannot select two times in the same query.");
        }

        string[] columnsNames;
        foreach (column; columns)
        {
            columnsNames ~= column.getColumnName();
        }

        this.selectStmt ~= "SELECT " ~ columnsNames.join(", ") ~ " ";
        return this;
    }

    // Later we have to create several where() methods with different signature where(SqliteColumn, Operators, int/string/double) instead of one method with a Variant parameter
    SqliteRepository where(SqliteColumn field, Operators operator, string variant)
    {
        if (this.whereStmt !is null || this.whereVariant !is null)
        {
            throw new Exception("You cannot execute where two times in the same query.");
        }

        this.whereStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.whereVariant ~= toVariant(variant);
        return this;
    }

    SqliteRepository where(SqliteColumn field, Operators operator, int variant)
    {
        if (this.whereStmt !is null || this.whereVariant !is null)
        {
            throw new Exception("You cannot execute where two times in the same query.");
        }

        this.whereStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.whereVariant ~= toVariant(variant);
        return this;
    }

    SqliteRepository where(SqliteColumn field, Operators operator, double variant)
    {
        if (this.whereStmt !is null || this.whereVariant !is null)
        {
            throw new Exception("You cannot execute where two times in the same query.");
        }

        this.whereStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.whereVariant ~= toVariant(variant);
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, string variant)
    {
        if (this.whereStmt is null || this.whereVariant is null)
        {
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");
        }

        this.andStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.andVariants ~= toVariant(variant);
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, double variant)
    {
        if (this.whereStmt is null || this.whereVariant is null)
        {
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");
        }

        this.andStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.andVariants ~= toVariant(variant);
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, int variant)
    {
        if (this.whereStmt is null || this.whereVariant is null)
        {
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");
        }

        this.andStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.andVariants ~= toVariant(variant);
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, string variant)
    {
        if (this.whereStmt is null || this.whereVariant is null)
        {
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");
        }

        this.orStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.orVariants ~= toVariant(variant);
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, double variant)
    {
        if (this.whereStmt is null || this.whereVariant is null)
        {
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");
        }

        this.orStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.orVariants ~= toVariant(variant);
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, int variant)
    {
        if (this.whereStmt is null || this.whereVariant is null)
        {
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");
        }

        this.orStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.orVariants ~= toVariant(variant);
        return this;
    }

    SqliteRepository orderBy(SqliteColumn[] columns, SortMethod sort)
    {
        if (this.selectStmt is null)
        {
            throw new Exception("Invalid query. A SELECT query with an ORDER BY clause is required.");
        }

        string[] columnsNames;
        foreach (column; columns)
        {
            columnsNames ~= column.getColumnName();
        }

        this.orderByStmt ~= "ORDER BY " ~ columnsNames.join(", ") ~ " " ~ sort ~ " ";   
        return this;
    }

    SqliteRepository groupBy(SqliteColumn[] columns)
    {
        if (this.whereStmt is null || this.whereVariant is null)
        {
            throw new Exception("Invalid query. A GROUP BY clause should follow a WHERE clause.");
        }
        else if (this.orderByStmt !is null)
        {
            throw new Exception("Invalid query. A GROUP BY clause should precede an ORDER BY clause.");
        }

        string[] columnsNames;
        foreach (column; columns)
        {
            columnsNames ~= column.getColumnName();
        }

        this.groupByStmt ~= "GROUP BY " ~ columnsNames.join(", ") ~ " ";
        return this;
    }

    SqliteRepository limit(int nLimit)
    {
        if (this.selectStmt is null)
        {
            throw new Exception("Invalid query. A LIMIT clause should follow a SELECT clause.");
        }

        this.limitStmt ~= "LIMIT " ~ to!string(nLimit) ~ " ";
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
