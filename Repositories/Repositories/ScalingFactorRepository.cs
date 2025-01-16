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
    public class ScalingFactorRepository : IScalingFactorRepository
    {
        private readonly string _connectionString;
        public ScalingFactorRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }
        public void Add(Models.Post.ScalingFactor scalingFactor)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Post.ScalingFactor>();
                db.Execute(query, scalingFactor);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"ScalingFactor\" SET  \"Active\" = False WHERE \"Id\" = @Id";
                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<Models.ScalingFactor> GetAll()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"ScalingFactor\" WHERE \"Active\"=True";
                return db.Query<ScalingFactor>(query).ToList();
            }
        }

        public Models.ScalingFactor GetById(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"ScalingFactor\" WHERE \"Id\" = @Id And \"Active\"=True ";
                return db.QuerySingleOrDefault<ScalingFactor>(query, new { Id = id });
            }
        }

        public void Update(Models.ScalingFactor scalingFactor)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetUpdateQuery<ScalingFactor>();

                db.Execute(query, scalingFactor);
            }
        }
    }
}
