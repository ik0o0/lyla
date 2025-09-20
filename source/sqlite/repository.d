module sqlite.repository;


import std.stdio;
import std.array;
import std.string : toStringz, fromStringz;
import std.conv;

import sqlite.column;
import sqlite.model;

import sqlite.sqlite : sqlite3, sqlite3_stmt, sqlite3_exec, sqlite3_prepare_v2, sqlite3_free, SQLiteResultCode, sqlite3_bind_text, sqlite3_step, sqlite3_errmsg, sqlite3_finalize, SQLITE_TRANSIENT;

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

enum Sort : string
{
    ASC = "ASC",
    DESC = "DESC"
}

struct Clause
{
    string stmt;
    string[] variants;
}

class SqliteRepository
{
private:
    SqliteModel model;
    string tableName;
    sqlite3* db;
    
    string selectStmt;

    string whereStmt;
    string whereVariant;

    // INFO: IDK if its the great approach, i dont think it is... i think we have to write the C interop execute() function before trying to implement anything
    // TODO: Replace all the andStmt + andVariants, orStmt + orVariants implementation by an array of Clause
    // Clause[] clauses;

    string andStmt; // AND salary > ? AND username = ?
    string[] andVariants; // ["1000", "test"]

    string orStmt;
    string[] orVariants;

    string orderByStmt;

    string groupByStmt;

    string limitStmt;

    string stagedStmt;
    string[] stagedValues;

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
    void executeSql()
    {
        sqlite3_stmt* stmt;
        if (sqlite3_prepare_v2(this.db, toStringz(this.stagedStmt), -1, &stmt, null) != SQLiteResultCode.SQLITE_OK)
        {
            writeln("Failed to prepare statement.");
            return;
        }

        foreach (int i, value; this.stagedValues)
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
            writeln("Query failed: " ~ fromStringz(sqlite3_errmsg(this.db)).idup);
            return;
        }

        sqlite3_finalize(stmt);
    }

    void parse()
    {
        if (this.selectStmt !is null)
        {
            this.stagedStmt ~= this.selectStmt ~ "FROM " ~ this.tableName ~ " ";

            if (this.whereStmt !is null)
            {
                this.stagedStmt ~= this.whereStmt;
                this.stagedValues ~= this.whereVariant; // Add the variant in stagedValues before doing ANYTHING, like that we have a list of variants(values) who's in the order for match with our "?" in stagedStmt when we're gonna bind our stmt with C interop

                if (this.andStmt !is null &&
                    this.andVariants !is null)
                {

                }
            }
            else if (this.orderByStmt !is null)
            {
                // add ORDER BY to the stagedStmt
            }
        }
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

    SqliteRepository where(SqliteColumn field, Operators operator, string variant)
    {
        if (this.whereStmt !is null || this.whereVariant !is null)
        {
            throw new Exception("You cannot execute where two times in the same query.");
        }

        this.whereStmt ~= "WHERE " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.whereVariant = variant;
        return this;
    }

    SqliteRepository and(SqliteColumn field, Operators operator, string variant)
    {
        if (this.whereStmt is null || this.whereVariant is null)
        {
            throw new Exception("Invalid query. A WHERE clause with an AND operator is required.");
        }

        // Dont think so...
        // this.clauses ~= Clause("AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ", variant);

        this.andStmt ~= "AND " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.andVariants ~= variant;
        return this;
    }

    SqliteRepository or(SqliteColumn field, Operators operator, string variant)
    {
        if (this.whereStmt is null || this.whereVariant is null)
        {
            throw new Exception("Invalid query. A WHERE clause with an OR operator is required.");
        }

        this.orStmt ~= "OR " ~ field.getColumnName() ~ " " ~ operator ~ " ? ";
        this.orVariants ~= variant;
        return this;
    }

    SqliteRepository orderBy(SqliteColumn[] columns, Sort sort)
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

    // SELECT id, username FROM User
    // userRepo.select(["id", "username"]) || userRepo.select([User.column("id"), User.column("username")])
    // void select(SqliteColumn[] columns)
    // {
    //     string[] columnsNames;
    //     foreach (column; columns)
    //     {
    //         columnsNames ~= column.getColumnName();
    //     }

    //     preparedStmt ~= "SELECT " ~ columnsNames.join(", ") ~ " FROM " ~ this.tableName;
    // }
    
    void selectWhere(
        SqliteColumn[] columns,
        string firstValue,
        Operators operator,
        string secondValue)
    {
        string[] columnNames;
        foreach (column; columns)
        {
            columnNames ~= column.getColumnName();
        }

        string stmtStr = "SELECT " ~ columnNames.join(", ") ~ " FROM " ~ this.tableName ~ " WHERE " ~ "? " ~ operator ~ " ?;";
        sqlite3_stmt* stmt;
        if (sqlite3_prepare_v2(this.db, toStringz(stmtStr), -1, &stmt, null) != SQLiteResultCode.SQLITE_OK)
        {
            writeln("Failed to prepare statement.");
            return;
        }

        sqlite3_bind_text(stmt, 1, toStringz(firstValue), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, toStringz(secondValue), -1, SQLITE_TRANSIENT);

        // if (sqlite3_step(stmt) != SQLiteResultCode.SQLITE_DONE)
        // {
        //     writeln("Insert failed: " ~ fromStringz(sqlite3_errmsg(this.db)).idup);
        //     return;
        // }

        while (sqlite3_step(stmt) != SQLiteResultCode.SQLITE_DONE)
        {
            
        }

        sqlite3_finalize(stmt);
    }

    void selectWhere(
        SqliteColumn[] columns,
        string value,
        string operator)
    {
        string[] columnNames;
        foreach (column; columns)
        {
            columnNames ~= column.getColumnName();
        }

        string stmtStr = "SELECT " ~ columnNames.join(", ") ~ " FROM " ~ this.tableName ~ " WHERE " ~ "? " ~ operator ~ ";";
        sqlite3_stmt* stmt;
        if (sqlite3_prepare_v2(this.db, toStringz(stmtStr), -1, &stmt, null) != SQLiteResultCode.SQLITE_OK)
        {
            writeln("Failed to prepare statement.");
            return;
        }

        sqlite3_bind_text(stmt, 1, toStringz(value), -1, SQLITE_TRANSIENT);

        // if (sqlite3_step(stmt) != SQLiteResultCode.SQLITE_DONE)
        // {
        //     writeln("Insert failed: " ~ fromStringz(sqlite3_errmsg(this.db)).idup);
        //     return;
        // }

        sqlite3_finalize(stmt);
    }
}

/*
 * Unit tests
 */
unittest
{
    import sqlite.implementModel;
    import sqlite.sqlite;

    SqliteModel User = new SqliteImplementModel("users_table")
        .column("id", SqliteColumnTypes.INTEGER).primaryKey().autoIncrement()
        .column("username", SqliteColumnTypes.TEXT).unique().notNull()
        .finalize()
        .build();
    
    auto db = initSQLiteDatabase("test.db", [User]);
    
    SqliteRepository userRepository = new SqliteRepository(User, db);

    // SELECT * FROM user WHERE id = 1;
    userRepository
        .select() // .select(["id", "username"]) == SELECT id, username
        .where("id", "=", "1")
        .execute();
}
