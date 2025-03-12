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
    public class ChannelTypeRepository : IChannelTypeRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;

        public ChannelTypeRepository()
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
        public void Add(Post.ChannelType channelType)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query = _databaseProvider == "NPGSQL"
                    ? PGSqlHelper.GetInsertQuery<Post.ChannelType>() 
                    : MSSqlHelper.GetInsertQuery<Post.ChannelType>(); 

                db.Execute(query, channelType);
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
                    query = "UPDATE public.\"ChannelType\" SET \"Active\" = False WHERE \"Id\" = @Id"; 
                }
                else
                {
                    query = "UPDATE ChannelType SET Active = 0 WHERE Id = @Id"; 
                }

                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<ChannelType> GetAll()
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"ChannelType\" WHERE \"Active\" = True";
                }
                else
                {
                    query = "SELECT * FROM ChannelType WHERE Active = 1";
                }

                return db.Query<ChannelType>(query).ToList();
            }
        }

        public ChannelType GetById(int id)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"ChannelType\" WHERE \"Id\" = @Id AND \"Active\" = True"; 
                }
                else
                {
                    query = "SELECT * FROM ChannelType WHERE Id = @Id AND Active = 1"; 
                }

                return db.QuerySingleOrDefault<ChannelType>(query, new { Id = id });
            }
        }

        public void Update(ChannelType channelType)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query = _databaseProvider == "NPGSQL"
                    ? PGSqlHelper.GetUpdateQuery<ChannelType>() 
                    : MSSqlHelper.GetUpdateQuery<ChannelType>(); 

                db.Execute(query, channelType);
            }
        }
    }
}
