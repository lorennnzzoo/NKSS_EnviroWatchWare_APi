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
    public class ScalingFactorRepository : IScalingFactorRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public ScalingFactorRepository()
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

        public void Add(Models.Post.ScalingFactor scalingFactor)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = PGSqlHelper.GetInsertQuery<Models.Post.ScalingFactor>();
                }
                else
                {
                    query = MSSqlHelper.GetInsertQuery<Models.Post.ScalingFactor>();
                }

                db.Execute(query, scalingFactor);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "UPDATE public.\"ScalingFactor\" SET \"Active\" = False WHERE \"Id\" = @Id";
                }
                else
                {
                    query = "UPDATE dbo.[ScalingFactor] SET [Active] = 0 WHERE [Id] = @Id";
                }

                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<Models.ScalingFactor> GetAll()
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"ScalingFactor\" WHERE \"Active\"=True";
                }
                else
                {
                    query = "SELECT * FROM dbo.[ScalingFactor] WHERE [Active] = 1";
                }

                return db.Query<Models.ScalingFactor>(query).ToList();
            }
        }

        public Models.ScalingFactor GetById(int id)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"ScalingFactor\" WHERE \"Id\" = @Id AND \"Active\"=True";
                }
                else
                {
                    query = "SELECT * FROM dbo.[ScalingFactor] WHERE [Id] = @Id AND [Active] = 1";
                }

                return db.QuerySingleOrDefault<Models.ScalingFactor>(query, new { Id = id });
            }
        }

        public void Update(Models.ScalingFactor scalingFactor)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = PGSqlHelper.GetUpdateQuery<Models.ScalingFactor>();
                }
                else
                {
                    query = MSSqlHelper.GetUpdateQuery<Models.ScalingFactor>();
                }

                db.Execute(query, scalingFactor);
            }
        }
    }
}
