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
    public class ChannelTypeRepository : IChannelTypeRepository
    {
        private readonly string _connectionString;        

        public ChannelTypeRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }
        public void Add(Post.ChannelType channelType)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Post.ChannelType>();
                db.Execute(query, channelType);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"ChannelType\" SET  \"Active\" = False WHERE \"Id\" = @Id";
                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<ChannelType> GetAll()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"ChannelType\" WHERE \"Active\"=True";
                return db.Query<ChannelType>(query).ToList();
            }
        }

        public ChannelType GetById(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"ChannelType\" WHERE \"Id\" = @Id And \"Active\"=True ";
                return db.QuerySingleOrDefault<ChannelType>(query, new { Id = id });
            }
        }

        public void Update(ChannelType channelType)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetUpdateQuery<ChannelType>();

                db.Execute(query, channelType);
            }
        }
    }
}
