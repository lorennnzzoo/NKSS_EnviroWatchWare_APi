using Dapper;
using Repositories.Interfaces;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using Models;
using Post = Models.Post;
using Repositories.Helpers;
using Npgsql;
using System.Data.SqlClient;

namespace Repositories
{
    public class MonitoringTypeRepository : IMonitoringTypeRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public MonitoringTypeRepository()
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

        public void Add(Post.MonitoringType monitoringType)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? PGSqlHelper.GetInsertQuery<Post.MonitoringType>()
                    : MSSqlHelper.GetInsertQuery<Post.MonitoringType>();

                db.Execute(query, monitoringType);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? "UPDATE public.\"MonitoringType\" SET \"Active\" = False WHERE \"Id\" = @Id"
                    : "UPDATE dbo.[MonitoringType] SET [Active] = 0 WHERE [Id] = @Id";

                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<MonitoringType> GetAll()
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? "SELECT * FROM public.\"MonitoringType\" WHERE \"Active\"=True"
                    : "SELECT * FROM dbo.[MonitoringType] WHERE [Active]=1";

                return db.Query<MonitoringType>(query).ToList();
            }
        }

        public MonitoringType GetById(int id)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? "SELECT * FROM public.\"MonitoringType\" WHERE \"Id\" = @Id AND \"Active\"=True"
                    : "SELECT * FROM dbo.[MonitoringType] WHERE [Id] = @Id AND [Active] = 1";

                return db.QuerySingleOrDefault<MonitoringType>(query, new { Id = id });
            }
        }

        public void Update(MonitoringType monitoringType)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? PGSqlHelper.GetUpdateQuery<MonitoringType>()
                    : MSSqlHelper.GetUpdateQuery<MonitoringType>();

                db.Execute(query, monitoringType);
            }
        }
    }
}
