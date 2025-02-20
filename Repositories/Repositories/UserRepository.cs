using Dapper;
using Models;
using Repositories.Helpers;
using Repositories.Interfaces;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories
{
    public class UserRepository : IUserRepository
    {
        private readonly string _connectionString;
        public UserRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }

        public void Activate(Guid id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"User\" SET  \"Active\" = True WHERE \"Id\" = @Id";
                db.Execute(query, new { Id = id });
            }
        }

        public void Add(Models.Post.Authentication.User user)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Models.Post.Authentication.User>();
                db.Query(query, user);
            }
        }

        public void Delete(Guid id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"User\" SET  \"Active\" = False WHERE \"Id\" = @Id";
                db.Execute(query, new { Id = id });
            }
        }

        public List<User> GetAll()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"User\"";
                return db.Query<Models.User>(query).ToList();
            }
        }

        public User GetByUsername(string username)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"User\" WHERE \"Username\" = @Username  ";
                return db.QuerySingleOrDefault<User>(query, new { Username = username });
            }
        }

        public async Task<User> GetByUsernameAsync(string username)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();  

                var query = "SELECT * FROM public.\"User\" WHERE \"Username\" = @Username ";                
                return await db.QuerySingleOrDefaultAsync<User>(query, new { Username = username });
            }
        }


        public void Update(Models.User User)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = UserPGSqlHelper.GetUpdateQuery<Models.User>();

                db.Execute(query, User);
            }
        }

        public void UpdateUserLoginTime(Guid userId)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();

                var query = "UPDATE public.\"User\" SET \"LastLoggedIn\" = NOW() WHERE \"Id\" = @UserId";

                db.Execute(query,new {UserId=userId });
            }
        }
    }
}
