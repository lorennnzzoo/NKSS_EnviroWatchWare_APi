using Dapper;
using Models;
using Post = Models.Post;
using Repositories.Helpers;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using Repositories.Interfaces;

namespace Repositories
{
    public class ChannelRepository : IChannelRepository
    {
        private readonly string _connectionString;
        public ChannelRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }

        public void Add(Post.Channel channel)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Post.Channel>();
                db.Execute(query, channel);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"Channel\" SET \"Active\" = False WHERE \"Id\" = @Id";
                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<Channel> GetAll()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"Channel\" WHERE \"Active\"=True";
                return db.Query<Channel>(query).ToList();
            }
        }

        public Channel GetById(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"Channel\" WHERE \"Id\" = @Id AND \"Active\"=True ";
                return db.QuerySingleOrDefault<Channel>(query, new { Id = id });
            }
        }

        public void Update(Channel channel)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetUpdateQuery<Channel>();
                db.Execute(query, channel);
            }
        }
    }
}

