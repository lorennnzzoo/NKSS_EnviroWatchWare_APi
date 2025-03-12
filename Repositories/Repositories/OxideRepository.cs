using Dapper;
using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using Repositories.Helpers;
using Npgsql;
using System.Data.SqlClient;

namespace Repositories
{
    public class OxideRepository : IOxideRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public OxideRepository()
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

        public void Add(Post.Oxide oxide)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? PGSqlHelper.GetInsertQuery<Post.Oxide>()
                    : MSSqlHelper.GetInsertQuery<Post.Oxide>();

                db.Execute(query, oxide);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? "UPDATE public.\"Oxide\" SET \"Active\" = False WHERE \"Id\" = @Id"
                    : "UPDATE dbo.[Oxide] SET [Active] = 0 WHERE [Id] = @Id";

                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<Oxide> GetAll()
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? "SELECT * FROM public.\"Oxide\" WHERE \"Active\"=True"
                    : "SELECT * FROM dbo.[Oxide] WHERE [Active] = 1";

                return db.Query<Oxide>(query).ToList();
            }
        }

        public Oxide GetById(int id)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? "SELECT * FROM public.\"Oxide\" WHERE \"Id\" = @Id AND \"Active\"=True"
                    : "SELECT * FROM dbo.[Oxide] WHERE [Id] = @Id AND [Active] = 1";

                return db.QuerySingleOrDefault<Oxide>(query, new { Id = id });
            }
        }

        public void Update(Oxide oxide)
        {

            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = (_databaseProvider == "NPGSQL")
                    ? PGSqlHelper.GetUpdateQuery<Oxide>()
                    : MSSqlHelper.GetUpdateQuery<Oxide>();

                db.Execute(query, oxide);
            }
        }
    }
}
