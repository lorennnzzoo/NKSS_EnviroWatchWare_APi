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
        public void Add(Models.Post.Authentication.User user)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Models.Post.Authentication.User>();
                db.Query(query, user);
            }
        }

        public User GetByUsername(string username)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"User\" WHERE \"Username\" = @Username And \"Active\"=True ";
                return db.QuerySingleOrDefault<User>(query, new { Username = username });
            }
        }

        public async Task<User> GetByUsernameAsync(string username)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();  

                var query = "SELECT * FROM public.\"User\" WHERE \"Username\" = @Username AND \"Active\" = True";                
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
    }
}
