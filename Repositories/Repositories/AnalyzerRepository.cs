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
    public class AnalyzerRepository : IAnalyzerRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;

        public AnalyzerRepository()
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
        public void Add(Post.Analyzer analyzer)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query = _databaseProvider == "NPGSQL"
                    ? PGSqlHelper.GetInsertQuery<Post.Analyzer>()  
                    : MSSqlHelper.GetInsertQuery<Post.Analyzer>(); 

                db.Execute(query, analyzer);
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
                    query = "UPDATE public.\"Analyzer\" SET \"Active\" = False WHERE \"Id\" = @Id"; 
                }
                else
                {
                    query = "UPDATE Analyzer SET Active = 0 WHERE Id = @Id";
                }

                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<Analyzer> GetAll()
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"Analyzer\" WHERE \"Active\"=True"; 
                }
                else
                {
                    query = "SELECT * FROM Analyzer WHERE Active = 1"; 
                }

                return db.Query<Analyzer>(query).ToList();
            }
        }

        public Analyzer GetById(int id)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"Analyzer\" WHERE \"Id\" = @Id AND \"Active\" = True"; 
                }
                else
                {
                    query = "SELECT * FROM Analyzer WHERE Id = @Id AND Active = 1"; 
                }

                return db.QuerySingleOrDefault<Analyzer>(query, new { Id = id });
            }
        }

        public void Update(Analyzer analyzer)
        {

            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query = _databaseProvider == "NPGSQL"
                    ? PGSqlHelper.GetUpdateQuery<Analyzer>()
                    : MSSqlHelper.GetUpdateQuery<Analyzer>();

                db.Execute(query, analyzer);
            }
        }
    }
}
