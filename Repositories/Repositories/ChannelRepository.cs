using Dapper;
using Models;
using Post = Models.Post;
using Repositories.Helpers;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using Repositories.Interfaces;
using Npgsql;
using System.Data.SqlClient;

namespace Repositories
{
    public class ChannelRepository : IChannelRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public ChannelRepository()
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
        public void Add(Post.Channel channel)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query = _databaseProvider == "NPGSQL"
                    ? PGSqlHelper.GetInsertQuery<Post.Channel>()  
                    : MSSqlHelper.GetInsertQuery<Post.Channel>(); 

                db.Execute(query, channel);
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
                    query = "UPDATE public.\"Channel\" SET \"Active\" = False WHERE \"Id\" = @Id"; 
                }
                else
                {
                    query = "UPDATE Channel SET Active = 0 WHERE Id = @Id"; 
                }

                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<Channel> GetAll()
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"Channel\" WHERE \"Active\"=True"; 
                }
                else
                {
                    query = "SELECT * FROM Channel WHERE Active = 1";
                }

                return db.Query<Channel>(query).ToList();
            }
        }

        public Channel GetById(int id)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"Channel\" WHERE \"Id\" = @Id AND \"Active\" = True"; 
                }
                else
                {
                    query = "SELECT * FROM Channel WHERE Id = @Id AND Active = 1"; 
                }

                return db.QuerySingleOrDefault<Channel>(query, new { Id = id });
            }
        }

        public void Update(Channel channel)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query = _databaseProvider == "NPGSQL"
                    ? PGSqlHelper.GetUpdateQuery<Channel>()  
                    : MSSqlHelper.GetUpdateQuery<Channel>(); 

                db.Execute(query, channel);
            }
        }
    }
}

