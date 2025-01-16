using Dapper;
using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using Repositories.Helpers;

namespace Repositories
{
    public class AnalyzerRepository : IAnalyzerRepository
    {
        private readonly string _connectionString;

        public AnalyzerRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }
        public void Add(Post.Analyzer analyzer)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Post.Analyzer>();
                db.Execute(query, analyzer);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"Analyzer\" SET  \"Active\" = False WHERE \"Id\" = @Id";
                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<Analyzer> GetAll()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"Analyzer\" WHERE \"Active\"=True";
                return db.Query<Analyzer>(query).ToList();
            }
        }

        public Analyzer GetById(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"Analyzer\" WHERE \"Id\" = @Id And \"Active\"=True ";
                return db.QuerySingleOrDefault<Analyzer>(query, new { Id = id });
            }
        }

        public void Update(Analyzer analyzer)
        {

            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetUpdateQuery<Analyzer>();

                db.Execute(query, analyzer);
            }          
        }
    }
}
