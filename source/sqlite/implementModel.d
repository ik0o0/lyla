module sqlite.implementModel;

import std.stdio;

import sqlite.column;
import sqlite.model;

class SqliteImplementModel
{
private:
    SqliteColumn[] columns;
    SqliteColumn currentColumn;

    string tableName;
public:
    SqliteColumn[] getColumns()
    {
        return this.columns;
    }

    this(string tableName)
    {
        this.tableName = tableName;
    }

    // for standard column
    SqliteImplementModel column(string columnName, SqliteColumnTypes columnType)
    {
        if (this.currentColumn !is null)
        {
            this.columns ~= this.currentColumn;
        }
        this.currentColumn = new SqliteColumn(columnName, columnType);
        return this;
    }

    // for foreign key column
    SqliteImplementModel column(string columnName, SqliteColumnTypes columnType, SqliteModel modelRef, SqliteColumn columnRef)
    {
        if (this.currentColumn !is null)
        {
            this.columns ~= this.currentColumn;
        }
        this.currentColumn = new SqliteColumn(columnName, columnType, modelRef, columnRef);
        return this;
    }

    // setPrimaryKey(true)
    SqliteImplementModel primaryKey()
    {
        if (this.currentColumn !is null)
        {
            this.currentColumn.setPrimaryKey(true);
            return this;
        }
        else
        {
            throw new Exception("Cannot call this method without having created a column.");
        }
    }

    // setAutoIncrement(true)
    SqliteImplementModel autoIncrement()
    {
        if (this.currentColumn !is null)
        {
            this.currentColumn.setAutoIncrement(true);
            return this;
        }
        else
        {
            throw new Exception("Cannot call this method without having created a column.");
        }
    }

    // setNullable(false)
    SqliteImplementModel notNull()
    {
        if (this.currentColumn !is null)
        {
            this.currentColumn.setNullable(false);
            return this;
        }
        else
        {
            throw new Exception("Cannot call this method without having created a column.");
        }
    }

    // setUnique(true)
    SqliteImplementModel unique()
    {
        if (this.currentColumn !is null)
        {
            this.currentColumn.setUnique(true);
            return this;
        }
        else
        {
            throw new Exception("Cannot call this method without having created a column.");
        }
    }

    // insert the current column into the column array
    SqliteImplementModel finalize()
    {
        if (this.currentColumn !is null)
            this.columns ~= this.currentColumn;
        return this;
    }

    // creates a new SqliteModel and returns it
    SqliteModel build()
    {
        return new SqliteModel(this.tableName, this.columns);
    }
}

/*
 * Unit tests
 */

unittest
{
    auto model = new SqliteImplementModel("model")
        .column("col1", SqliteColumnTypes.INTEGER).primaryKey().autoIncrement()
        .column("col2", SqliteColumnTypes.TEXT).unique().notNull()
        .column("col3", SqliteColumnTypes.TEXT).notNull()
        .finalize();
    
    auto col1 = model.getColumns()[0];
    auto col2 = model.getColumns()[1];
    auto col3 = model.getColumns()[2];

    assert(col1.isPrimaryKey() == true);
    assert(col1.isAutoIncrement() == true);
    assert(col1.isUnique() == false);

    assert(col2.isUnique() == true);
    assert(col2.isNullable() == false);
    assert(col2.isPrimaryKey() == false);

    assert(col3.isNullable() == false);
    assert(col3.isUnique() == false);

    assert(model.getColumns().length == 3);
}

unittest
{
    SqliteModel User = new SqliteImplementModel("users_table")
        .column("id", SqliteColumnTypes.INTEGER).primaryKey().autoIncrement()
        .column("username", SqliteColumnTypes.TEXT).unique().notNull()
        .column("password", SqliteColumnTypes.TEXT).notNull()
        .finalize()
        .build();
    
    SqliteModel Post = new SqliteImplementModel("posts_table")
        .column("id", SqliteColumnTypes.INTEGER).primaryKey().autoIncrement()
        .column("title", SqliteColumnTypes.TEXT)
        .column("userId", SqliteColumnTypes.INTEGER, User, User.getColumnByName("id"))
        .finalize()
        .build();
    
    assert(User.getColumnByName("id").isPrimaryKey() == true);
    assert(User.getColumnByName("username").isUnique() == true);
    assert(Post.getColumnByName("title").isNullable() == true);
    assert(Post.getColumnByName("userId").isForeignKey() == true);
}
