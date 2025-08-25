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

import column;

class SQLiteGenerator
{
public:
static:
    string createTableStmt(string tableName, string columnStmt)
    {
        return "CREATE TABLE IF NOT EXISTS " ~ tableName ~ "(" ~ columnStmt ~ ");";
    }

    string createColumnStmt(Column[] columns)
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

    string generateColumn(Column column)
    {
        string columnName = column.getColumnName();
        ColumnTypes columnType = column.getColumnType();
        bool primaryKey = column.isPrimaryKey();
        bool autoIncrement = column.isAutoIncrement();
        bool nullable = column.isNullable();
        bool unique = column.isUnique();

        string stmt = columnName;
        
        switch(columnType)
        {
            case ColumnTypes.INTEGER:
                stmt ~= " INTEGER";
                break;
            case ColumnTypes.TEXT:
                stmt ~= " TEXT";
                break;
            case ColumnTypes.BOOLEAN:
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
}

/*
 * Unit tests
 */


