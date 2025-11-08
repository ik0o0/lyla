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
module sqlite.sqliteGenerator;

import std.stdio;
import std.conv;

import sqlite.column;
import sqlite.model;

class SQLiteGenerator
{
public:
static:
    string createTableStmt(string tableName, string columnStmt)
    {
        return "CREATE TABLE IF NOT EXISTS " ~ tableName ~ "(" ~ columnStmt ~ ");";
    }

    string createColumnStmt(SqliteColumn[string] columns)
    {
        string stmtAcc;
        int i = 0;
        foreach (SqliteColumn column; columns)
        {
            if (i != columns.length - 1)
                stmtAcc ~= generateColumn(column) ~ ", ";
            else
                stmtAcc ~= generateColumn(column);
            ++i;
        }

        return stmtAcc;
    }

    string generateColumn(SqliteColumn column)
    {
        string columnName = column.getColumnName();
        SqliteColumnTypes columnType = column.getColumnType();
        bool primaryKey = column.isPrimaryKey();
        bool autoIncrement = column.isAutoIncrement();
        bool nullable = column.isNullable();
        bool unique = column.isUnique();
        bool foreignKey = column.isForeignKey();

        if (foreignKey)
            return generateFKColumn(column);

        string stmt = columnName;
        
        switch(columnType)
        {
            case SqliteColumnTypes.INTEGER:
                stmt ~= " INTEGER";
                break;
            case SqliteColumnTypes.TEXT:
                stmt ~= " TEXT";
                break;
            case SqliteColumnTypes.BOOLEAN:
                stmt ~= " INTEGER";
                break;
            default:
                assert(0, "Unexpected column type.");
                throw new Exception("Unexpected column type.");
                break;
        }

        if (!nullable) stmt ~= " NOT NULL";
        if (primaryKey) stmt ~= " PRIMARY KEY";
        if (autoIncrement) stmt ~= " AUTOINCREMENT";
        if (unique) stmt ~= " UNIQUE";

        return stmt;
    }

    string generateFKColumn(SqliteColumn column)
    {
        string columnName = column.getColumnName();
        SqliteColumnTypes columnType = column.getColumnType();
        bool primaryKey = column.isPrimaryKey();
        bool autoIncrement = column.isAutoIncrement();
        bool nullable = column.isNullable();
        bool unique = column.isUnique();
        SqliteModel modelRef = column.getModelRef();
        SqliteColumn columnRef = column.getColumnRef();

        if (!columnRef.isUnique() && !columnRef.isPrimaryKey())
            throw new Exception("Reference columns should be UNIQUE or PRIMARY KEY.");

        string stmt = columnName;
        switch(columnType)
        {
            case SqliteColumnTypes.INTEGER:
                stmt ~= " INTEGER";
                break;
            case SqliteColumnTypes.TEXT:
                stmt ~= " TEXT";
                break;
            case SqliteColumnTypes.BOOLEAN:
                stmt ~= " INTEGER";
                break;
            default:
                assert(0, "Unexpected column type.");
                throw new Exception("Unexpected column type.");
                break;
        }

        if (!nullable) stmt ~= " NOT NULL";
        if (primaryKey) stmt ~= " PRIMARY KEY";
        if (autoIncrement) stmt ~= " AUTOINCREMENT";
        if (unique) stmt ~= " UNIQUE";

        stmt ~= ", FOREIGN KEY(" ~ columnName ~ ") REFERENCES " ~ modelRef.getTableName() ~ "(" ~ columnRef.getColumnName() ~ ")";
        return stmt;
    }
}

/*
 * Unit tests
 */

unittest
{
    SqliteColumn[] userColumns;

    userColumns ~= new SqliteColumn("id", SqliteColumnTypes.INTEGER);
    userColumns[0].setPrimaryKey(true);
    userColumns[0].setAutoIncrement(true);

    SqliteModel user = new SqliteModel("users_table", userColumns);

    SqliteColumn[] postsColumns;

    postsColumns ~= new SqliteColumn("id", SqliteColumnTypes.INTEGER);
    postsColumns[0].setPrimaryKey(true);
    postsColumns[0].setAutoIncrement(true);

    postsColumns ~= new SqliteColumn("userId", SqliteColumnTypes.INTEGER, user, user.getColumns()[0]);

    SqliteModel posts = new SqliteModel("posts_table", postsColumns);

    assert(SQLiteGenerator.generateColumn(userColumns[0]) == "id INTEGER PRIMARY KEY AUTOINCREMENT");
    assert(SQLiteGenerator.generateColumn(postsColumns[1]) == "userId INTEGER, FOREIGN KEY(userId) REFERENCES users_table(id)");
    assert(SQLiteGenerator.createColumnStmt(postsColumns) == "id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, FOREIGN KEY(userId) REFERENCES users_table(id)");
    assert(SQLiteGenerator.createTableStmt(posts.getTableName(), "id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, FOREIGN KEY(userId) REFERENCES users_table(id)") == "CREATE TABLE IF NOT EXISTS " ~ posts.getTableName() ~ "(id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, FOREIGN KEY(userId) REFERENCES users_table(id));");
}
