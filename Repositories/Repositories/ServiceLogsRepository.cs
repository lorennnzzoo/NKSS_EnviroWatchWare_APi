using Dapper;
using Models;
using Repositories.Interfaces;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;

namespace Repositories
{
    public class ServiceLogsRepository : IServiceLogsRepository
    {
        private readonly string _connectionString;

        public ServiceLogsRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }
        public IEnumerable<ServiceLogs> GetPast24HourLogsByType(string Type)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"ServiceLogs\" " +
                            "WHERE \"SoftwareType\" = @Type " +
                            "AND \"LogTimestamp\" >= NOW() - INTERVAL '24 hours' " +
                            "ORDER BY \"LogId\" ASC";
                return db.Query<ServiceLogs>(query, new { Type = Type }).ToList();
            }
        }

        public IEnumerable<string> GetSoftwareTypes()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "select distinct \"SoftwareType\" from public.\"ServiceLogs\"";
                return db.Query<string>(query).ToList();
            }
        }
    }
}
