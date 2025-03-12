using Dapper;
using Models;
using Npgsql;
using Repositories.Interfaces;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;

namespace Repositories
{
    public class ServiceLogsRepository : IServiceLogsRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;

        public ServiceLogsRepository()
        {
            _databaseProvider = ConfigurationManager.AppSettings["DatabaseProvider"];
            //_connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
            if (_databaseProvider == "NPGSQL")
            {
                _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
            }
            else if (_databaseProvider == "MSSQL")
            {
                _connectionString = ConfigurationManager.ConnectionStrings["MicrosoftSQLConnection"].ConnectionString;
            }
            else
            {
                throw new ConfigurationErrorsException("Invalid DatabaseProvider in web.config");
            }
        }

        private IDbConnection CreateConnection()
        {
            if (_databaseProvider == "NPGSQL")
            {
                return new NpgsqlConnection(_connectionString);
            }
            else if (_databaseProvider == "MSSQL")
            {
                return new SqlConnection(_connectionString);
            }
            throw new ConfigurationErrorsException("Invalid DatabaseProvider in web.config");
        }

        public IEnumerable<ServiceLogs> GetPast24HourLogsByType(string Type)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"ServiceLogs\" " +
                            "WHERE \"SoftwareType\" = @Type " +
                            "AND \"LogTimestamp\" >= NOW() - INTERVAL '24 hours' " +
                            "ORDER BY \"LogId\" ASC";
                }
                else 
                {
                    query = "SELECT * FROM dbo.ServiceLogs " +
                            "WHERE SoftwareType = @Type " +
                            "AND LogTimestamp >= DATEADD(HOUR, -24, GETDATE()) " +
                            "ORDER BY LogId ASC";
                }

                return db.Query<ServiceLogs>(query, new { Type = Type }).ToList();
            }
        }

        public IEnumerable<string> GetSoftwareTypes()
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT DISTINCT \"SoftwareType\" FROM public.\"ServiceLogs\"";
                }
                else 
                {
                    query = "SELECT DISTINCT SoftwareType FROM dbo.ServiceLogs";
                }

                return db.Query<string>(query).ToList();
            }
        }
    }
}
