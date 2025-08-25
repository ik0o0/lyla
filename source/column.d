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
module column;

enum ColumnTypes
{
    INTEGER,
    TEXT,
    BOOLEAN
}

class Column
{
private:
    string columnName;
    ColumnTypes columnType;
    bool primaryKey = false;
    bool autoIncrement = false;
    bool nullable = true;
    bool unique = false;

public:
    this(string columnName, ColumnTypes columnType)
    {
        this.columnName = columnName;
        this.columnType = columnType;
    }

    /*
     *  Getter and setters
     */
    
    // columnName
    string getColumnName(){return this.columnName;}
    void setColumnName(string columnName){this.columnName = columnName;}

    // columnType
    ColumnTypes getColumnType(){return this.columnType;}
    void setColumnType(ColumnTypes columnType){this.columnType = columnType;}

    // primaryKey
    bool isPrimaryKey(){return this.primaryKey;}
    void setPrimaryKey(bool primaryKey){this.primaryKey = primaryKey;}
    
    // autoIncrement
    bool isAutoIncrement(){return this.autoIncrement;}
    void setAutoIncrement(bool autoIncrement){this.autoIncrement = autoIncrement;}

    // nullable
    bool isNullable(){return this.nullable;}
    void setNullable(bool nullable){this.nullable = nullable;}

    // unique
    bool isUnique(){return this.unique;}
    void setUnique(bool unique){this.unique = unique;}
}

/*
 * Unit tests
 */

// Constructor
unittest
{
    auto c = new Column("id", ColumnTypes.INTEGER);
    assert(c.getColumnName == "id");
    assert(c.getColumnType == ColumnTypes.INTEGER);
    assert(c.isPrimaryKey() == false);
    assert(c.isAutoIncrement() == false);
    assert(c.isNullable() == true);
    assert(c.isUnique() == false);
}

// Getters/setters
unittest
{
    auto c = new Column("username", ColumnTypes.TEXT);

    c.setColumnName("user_name");
    assert(c.getColumnName() == "user_name");

    c.setColumnType(ColumnTypes.BOOLEAN);
    assert(c.getColumnType() == ColumnTypes.BOOLEAN);

    c.setPrimaryKey(true);
    assert(c.isPrimaryKey() == true);

    c.setAutoIncrement(true);
    assert(c.isAutoIncrement() == true);

    c.setNullable(false);
    assert(c.isNullable == false);

    c.setUnique(true);
    assert(c.isUnique() == true);
}
