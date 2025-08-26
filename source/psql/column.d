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
module psql.column;

import psql.model;

enum PsqlColumnTypes
{
    INTEGER,
    SERIAL,
    TIMESTAMP,
    DATE,
    TEXT,
    BOOLEAN,
    // Implement varchar(n)
}

class PsqlColumn
{
private:
    string columnName;
    PsqlColumnTypes columnType;
    bool primaryKey = false;
    bool nullable = true;
    bool unique = false;
    bool foreignKey = false;
    PsqlColumn columnRef;
    PsqlModel modelRef;

public:
    this(string columnName, PsqlColumnTypes columnType)
    {
        this.columnName = columnName;
        this.columnType = columnType;
    }

    this(string columnName, PsqlColumnTypes columnType, PsqlModel modelRef, PsqlColumn columnRef)
    {
        this.columnName = columnName;
        this.columnType = columnType;
        this.modelRef = modelRef;
        this.columnRef = columnRef;
        this.foreignKey = true;
    }

    /*
     *  Getter and setters
     */
    
    // columnName
    string getColumnName(){return this.columnName;}
    void setColumnName(string columnName){this.columnName = columnName;}

    // columnType
    PsqlColumnTypes getColumnType(){return this.columnType;}
    void setColumnType(PsqlColumnTypes columnType){this.columnType = columnType;}

    // primaryKey
    bool isPrimaryKey(){return this.primaryKey;}
    void setPrimaryKey(bool primaryKey){this.primaryKey = primaryKey;}

    // nullable
    bool isNullable(){return this.nullable;}
    void setNullable(bool nullable){this.nullable = nullable;}

    // unique
    bool isUnique(){return this.unique;}
    void setUnique(bool unique){this.unique = unique;}

    // foreignKey
    bool isForeignKey(){return this.foreignKey;}
    void setForeignKey(bool foreignKey){this.foreignKey = foreignKey;}

    // columnRef
    PsqlColumn getColumnRef(){return this.columnRef;}
    void setColumnRef(PsqlColumn columnRef){this.columnRef = columnRef;}

    // modelRef
    PsqlModel getModelRef(){return this.modelRef;}
    void setModelRef(PsqlModel modelRef){this.modelRef = modelRef;}
}

/*
 * Unit tests
 */

// Constructor
unittest
{
    auto c = new PsqlColumn("id", PsqlColumnTypes.SERIAL);
    assert(c.getColumnName == "id");
    assert(c.getColumnType == PsqlColumnTypes.SERIAL);
    assert(c.isPrimaryKey() == false);
    assert(c.isNullable() == true);
    assert(c.isUnique() == false);
    assert(c.isForeignKey() == false);
    assert(c.getModelRef() is null);
    assert(c.getColumnRef() is null);
}

// Constructor with references
unittest
{
    auto col1 = new PsqlColumn("id", PsqlColumnTypes.SERIAL);
    auto model = new PsqlModel("users", [col1]);
    auto col2 = new PsqlColumn("userId", PsqlColumnTypes.INTEGER, model, model.getColumns()[0]);
    assert(col2.isForeignKey() == true);
}

// Getters/setters
unittest
{
    auto c = new PsqlColumn("username", PsqlColumnTypes.TEXT);
    auto model = new PsqlModel("users", [c]);

    c.setColumnName("user_name");
    assert(c.getColumnName() == "user_name");

    c.setColumnType(PsqlColumnTypes.BOOLEAN);
    assert(c.getColumnType() == PsqlColumnTypes.BOOLEAN);

    c.setPrimaryKey(true);
    assert(c.isPrimaryKey() == true);

    c.setNullable(false);
    assert(c.isNullable == false);

    c.setUnique(true);
    assert(c.isUnique() == true);

    c.setForeignKey(true);
    assert(c.isForeignKey() == true);

    c.setModelRef(model);
    assert(c.getModelRef() == model);

    c.setColumnRef(c);
    assert(c.getColumnRef() == c);
}
