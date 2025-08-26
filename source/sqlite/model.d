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
module sqlite.model;

import sqlite.column;
import sqlite.sqlite;

class SqliteModel
{
private:
    string tableName;
    SqliteColumn[] columns;

public:
    this(string tableName, SqliteColumn[] columns)
    {
        this.tableName = tableName;
        this.columns = columns;
    }


    /*
     *  Getter and setters
     */
    
    // tableName
    string getTableName(){return this.tableName;}
    void setTableName(string tableName){this.tableName = tableName;}

    // columns
    SqliteColumn[] getColumns(){return this.columns;}
    void setColumns(SqliteColumn[] columns){this.columns = columns;}
}

/*
 * Unit tests
 */

// Constructor
unittest
{
    auto col1 = new SqliteColumn("id", SqliteColumnTypes.INTEGER);
    auto col2 = new SqliteColumn("username", SqliteColumnTypes.TEXT);

    auto model = new SqliteModel("users", [col1, col2]);
    assert(model.getTableName() == "users");
    assert(model.getColumns().length == 2);
    assert(model.getColumns[0] == col1);
    assert(model.getColumns[1] == col2);
}

// Getters/setters
unittest
{
    auto col1 = new SqliteColumn("id", SqliteColumnTypes.INTEGER);
    auto col2 = new SqliteColumn("username", SqliteColumnTypes.TEXT);
    auto model = new SqliteModel("users", [col1]);

    model.setTableName("accounts");
    assert(model.getTableName() == "accounts");
    
    model.setColumns([col1, col2]);
    auto cols = model.getColumns();
    assert(cols.length == 2);
    assert(cols[0].getColumnName() == "id");
    assert(cols[1].getColumnName() == "username");
}

// Constructor with empty vector
unittest
{
    auto model = new SqliteModel("empty_table", []);
    assert(model.getColumns().length == 0);
    assert(model.getTableName() == "empty_table");
}
