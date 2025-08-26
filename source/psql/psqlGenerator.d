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
module psql.psqlGenerator;

import std.stdio;

import psql.column;
import psql.model;

class PsqlGenerator
{
public:
static:
    string createTableStmt(string tableName, string columnStmt)
    {
        return "CREATE TABLE IF NOT EXISTS " ~ tableName ~ "(" ~ columnStmt ~ ");";
    }

    string createColumnStmt(PsqlColumn[] columns)
    {
        string stmtAcc;
        for (int i = 0; i < columns.length; i++)
        {
            if (i == columns.length - 1)
            {
                string stmt = generateColumn(columns[i]);
                stmtAcc ~= stmt;
            }
            else
            {
                string stmt = generateColumn(columns[i]);
                stmtAcc ~= stmt ~ ", ";
            }
        }

        return stmtAcc;
    }

    string generateColumn(PsqlColumn column)
    {
        string columnName = column.getColumnName();
        PsqlColumnTypes columnType = column.getColumnType();
        bool primaryKey = column.isPrimaryKey();
        bool nullable = column.isNullable();
        bool unique = column.isUnique();
        bool foreignKey = column.isForeignKey();

        if (foreignKey)
            return generateFKColumn(column);

        string stmt = columnName;
        
        switch(columnType)
        {
            case PsqlColumnTypes.INTEGER:
                stmt ~= " INTEGER";
                break;
            case PsqlColumnTypes.SERIAL:
                stmt ~= " SERIAL";
                break;
            case PsqlColumnTypes.TEXT:
                stmt ~= " TEXT";
                break;
            case PsqlColumnTypes.BOOLEAN:
                stmt ~= " BOOLEAN";
                break;
            case PsqlColumnTypes.DATE:
                stmt ~= " DATE";
                break;
            case PsqlColumnTypes.TIMESTAMP:
                stmt ~= " TIMESTAMP";
                break;
            default:
                assert(0, "Unexpected column type.");
                throw new Exception("Unexpected column type.");
                break;
        }

        if (!nullable) stmt ~= " NOT NULL";
        if (primaryKey) stmt ~= " PRIMARY KEY";
        if (unique) stmt ~= " UNIQUE";

        return stmt;
    }

    string generateFKColumn(PsqlColumn column)
    {
        string columnName = column.getColumnName();
        PsqlColumnTypes columnType = column.getColumnType();
        bool primaryKey = column.isPrimaryKey();
        bool nullable = column.isNullable();
        bool unique = column.isUnique();
        PsqlModel modelRef = column.getModelRef();
        PsqlColumn columnRef = column.getColumnRef();

        if (!columnRef.isUnique() && !columnRef.isPrimaryKey())
            throw new Exception("Reference's columns should be UNIQUE or PRIMARY KEY.");

        string stmt = columnName;
        switch(columnType)
        {
            case PsqlColumnTypes.INTEGER:
                stmt ~= " INTEGER";
                break;
            case PsqlColumnTypes.SERIAL:
                stmt ~= " SERIAL";
                break;
            case PsqlColumnTypes.TEXT:
                stmt ~= " TEXT";
                break;
            case PsqlColumnTypes.BOOLEAN:
                stmt ~= " BOOLEAN";
                break;
            default:
                assert(0, "Unexpected column type.");
                throw new Exception("Unexpected column type.");
                break;
        }

        if (!nullable) stmt ~= " NOT NULL";
        if (primaryKey) stmt ~= " PRIMARY KEY";
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
    PsqlColumn[] userColumns;

    userColumns ~= new PsqlColumn("id", PsqlColumnTypes.SERIAL);
    userColumns[0].setPrimaryKey(true);

    PsqlModel user = new PsqlModel("users_table", userColumns);

    PsqlColumn[] postsColumns;

    postsColumns ~= new PsqlColumn("id", PsqlColumnTypes.SERIAL);
    postsColumns[0].setPrimaryKey(true);

    postsColumns ~= new PsqlColumn("userId", PsqlColumnTypes.INTEGER, user, user.getColumns()[0]);

    PsqlModel posts = new PsqlModel("posts_table", postsColumns);

    assert(PsqlGenerator.generateColumn(userColumns[0]) == "id SERIAL PRIMARY KEY");
    assert(PsqlGenerator.generateColumn(postsColumns[1]) == "userId INTEGER, FOREIGN KEY(userId) REFERENCES users_table(id)");
    assert(PsqlGenerator.createColumnStmt(postsColumns) == "id SERIAL PRIMARY KEY, userId INTEGER, FOREIGN KEY(userId) REFERENCES users_table(id)");
    assert(PsqlGenerator.createTableStmt(posts.getTableName(), "id SERIAL PRIMARY KEY, userId INTEGER, FOREIGN KEY(userId) REFERENCES users_table(id)") == "CREATE TABLE IF NOT EXISTS " ~ posts.getTableName() ~ "(id SERIAL PRIMARY KEY, userId INTEGER, FOREIGN KEY(userId) REFERENCES users_table(id));");
}

