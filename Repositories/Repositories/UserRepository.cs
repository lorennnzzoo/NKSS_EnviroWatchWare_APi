using Dapper;
using Models;
using Npgsql;
using Repositories.Helpers;
using Repositories.Interfaces;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories
{
    public class UserRepository : IUserRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public UserRepository()
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


        public void Activate(Guid id)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "UPDATE public.\"User\" SET \"Active\" = True WHERE \"Id\" = @Id";
                }
                else 
                {
                    query = "UPDATE dbo.[User] SET [Active] = 1 WHERE [Id] = @Id";
                }

                db.Execute(query, new { Id = id });
            }
        }

        public void Add(Models.Post.Authentication.User user)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = PGSqlHelper.GetInsertQuery<Models.Post.Authentication.User>();
                }
                else 
                {
                    query = MSSqlHelper.GetInsertQuery<Models.Post.Authentication.User>();
                }

                db.Execute(query, user);
            }
        }

        public void Delete(Guid id)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = $"UPDATE public.\"User\" SET \"Active\" = False WHERE \"Id\" = @Id";
                }
                else 
                {
                    query = $"UPDATE dbo.[User] SET [Active] = 0 WHERE [Id] = @Id";
                }

                db.Execute(query, new { Id = id });
            }
        }

        public List<User> GetAll()
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"User\"";
                }
                else 
                {
                    query = "SELECT * FROM dbo.[User]";
                }

                return db.Query<User>(query).ToList();
            }
        }

        public User GetByUsername(string username)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"User\" WHERE \"Username\" = @Username";
                }
                else 
                {
                    query = "SELECT * FROM dbo.[User] WHERE [Username] = @Username";
                }

                return db.QuerySingleOrDefault<User>(query, new { Username = username });
            }
        }

        public async Task<User> GetByUsernameAsync(string username)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"User\" WHERE \"Username\" = @Username";
                }
                else 
                {
                    query = "SELECT * FROM dbo.[User] WHERE [Username] = @Username";
                }

                return await db.QuerySingleOrDefaultAsync<User>(query, new { Username = username });
            }
        }


        public void Update(Models.User User)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = UserPGSqlHelper.GetUpdateQuery<Models.User>();
                }
                else
                {
                    query = UserMSSqlHelper.GetUpdateQuery<Models.User>();
                }

                db.Execute(query, User);
            }
        }

        public void UpdateUserLoginTime(Guid userId)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "UPDATE public.\"User\" SET \"LastLoggedIn\" = NOW() WHERE \"Id\" = @UserId";
                }
                else 
                {
                    query = "UPDATE [User] SET [LastLoggedIn] = GETDATE() WHERE [Id] = @UserId";
                }

                db.Execute(query, new { UserId = userId });
            }
        }
    }
}
