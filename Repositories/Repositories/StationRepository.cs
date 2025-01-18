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
    public class StationRepository : IStationRepository
    {
        private readonly string _connectionString;
        public StationRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString; ;
        }
        public void Add(Post.Station station)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Post.Station>();
                db.Execute(query, station);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"Station\" SET  \"Active\" = False WHERE \"Id\" = @Id";
                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<int> GetActiveStationIds()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT \"Id\" FROM public.\"Station\" WHERE \"Active\"=True";
                return db.Query<int>(query).ToList();
            }
        }

        public IEnumerable<Station> GetAll()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"Station\" WHERE \"Active\"=True";
                return db.Query<Station>(query).ToList();
            }
        }        
        public Station GetById(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"Station\" WHERE \"Id\" = @Id And \"Active\"=True";
                return db.QuerySingleOrDefault<Station>(query, new { Id = id });
            }
        }

        public void Update(Models.Put.Station station)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetUpdateQuery<Models.Put.Station>();
                db.Execute(query, station);
            }
        }
    }
}
