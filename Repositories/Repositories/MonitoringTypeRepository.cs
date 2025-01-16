using Dapper;
using Repositories.Interfaces;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using Models;
using Post = Models.Post;
using Repositories.Helpers;

namespace Repositories
{
    public class MonitoringTypeRepository : IMonitoringTypeRepository
    {
        private readonly string _connectionString;
        public MonitoringTypeRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }
        public void Add(Post.MonitoringType monitoringType)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Post.MonitoringType>();
                db.Execute(query, monitoringType);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"MonitoringType\" SET  \"Active\" = False WHERE \"Id\" = @Id";
                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<MonitoringType> GetAll()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"MonitoringType\" WHERE \"Active\"=True";
                return db.Query<MonitoringType>(query).ToList();
            }
        }

        public MonitoringType GetById(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"MonitoringType\" WHERE \"Id\" = @Id And \"Active\"=True ";
                return db.QuerySingleOrDefault<MonitoringType>(query, new { Id = id });
            }
        }

        public void Update(MonitoringType monitoringType)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetUpdateQuery<MonitoringType>();

                db.Execute(query, monitoringType);
            }
        }
    }
}
