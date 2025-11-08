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
module psql.psql;

import std.string : toStringz, fromStringz;

import psql.model;
import psql.psqlGenerator;

enum ConnStatusType : int
{
    CONNECTION_OK = 0,
    CONNECTION_BAD = 1
}

enum ExecStatusType : int
{
    PGRES_EMPTY_QUERY = 0,
    PGRES_COMMAND_OK = 1,
    PGRES_TUPLES_OK = 2
}

extern(C)
{
    /* PGconn encapsulates a connection to the backend.
     * The contents of this struct are not supposed to be known to applications.
     */
    struct PGconn;

    /* PGresult encapsulates the result of a query (or more precisely, of a single
     * SQL command --- a query string given to PQsendQuery can contain multiple
     * commands and thus return multiple PGresult objects).
     * The contents of this struct are not supposed to be known to applications.
     */
    struct PGresult;
    
    PGconn* PQconnectdb(const char* conninfo);
    ConnStatusType PQstatus(const PGconn* conn);
    char* PQerrorMessage(const PGconn* conn);
    PGresult* PQexec(PGconn* conn, const char* query);
    ExecStatusType PQresultStatus(const PGresult* res);
    int PQntuples(const PGresult* res);
    int PQnfields(const PGresult* res);
    char* PQgetValue(const PGresult* res, int tup_num, int field_num);
    void PQfinish(PGconn* conn);
    void PQclear(PGresult* res);
}

PGconn* initPsqlDatabase(
    string host,
    string port,
    string dbname,
    string user,
    string password,
    PsqlModel[] models
)
{
    PGconn* conn = PQconnectdb(toStringz("host=" ~ host ~ "port=" ~ port ~ "dbname=" ~ dbname ~ "user=" ~ user ~ "password=" ~ password));
    if (PQstatus(conn) != ConnStatusType.CONNECTION_OK)
    {
        char* errMsg = PQerrorMessage(conn);
        PQfinish(conn);
        throw new Exception("Connection error: ", fromStringz(errMsg).idup);
    }

    string initStmt = "";
    foreach (model; models)
    {
        string tableName = model.getTableName();
        string columnsStmt = PsqlGenerator.createColumnStmt(model.getColumns());
        initStmt ~= PsqlGenerator.createTableStmt(tableName, columnsStmt);
    }

    PGresult* res = PQexec(conn, toStringz(initStmt));
    if (PQresultStatus(res) != ExecStatusType.PGRES_COMMAND_OK)
    {
        char* errMsg = PQerrorMessage(conn);
        PQclear(res);
        PQfinish(conn);
        throw new Exception("Error in the query: ", fromStringz(errMsg).idup);
    }

    PQclear(res);
    PQfinish(conn);

    return conn;
}

/*
 * Unit tests
 */
