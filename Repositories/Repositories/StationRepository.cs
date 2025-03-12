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
    public class StationRepository : IStationRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public StationRepository()
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

        public void Add(Post.Station station)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = PGSqlHelper.GetInsertQuery<Post.Station>();
                }
                else 
                {
                    query = MSSqlHelper.GetInsertQuery<Post.Station>();
                }

                db.Execute(query, station);
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
                    query = "UPDATE public.\"Station\" SET \"Active\" = False WHERE \"Id\" = @Id";
                }
                else 
                {
                    query = "UPDATE dbo.Station SET Active = 0 WHERE Id = @Id";
                }

                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<int> GetActiveStationIds()
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT \"Id\" FROM public.\"Station\" WHERE \"Active\" = True";
                }
                else 
                {
                    query = "SELECT Id FROM dbo.Station WHERE Active = 1";
                }

                return db.Query<int>(query).ToList();
            }
        }

        public IEnumerable<Station> GetAll()
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"Station\" WHERE \"Active\" = True";
                }
                else 
                {
                    query = "SELECT * FROM dbo.Station WHERE Active = 1";
                }

                return db.Query<Station>(query).ToList();
            }
        }        
        public Station GetById(int id)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"Station\" WHERE \"Id\" = @Id AND \"Active\" = True";
                }
                else 
                {
                    query = "SELECT * FROM dbo.Station WHERE Id = @Id AND Active = 1";
                }

                return db.QuerySingleOrDefault<Station>(query, new { Id = id });
            }
        }

        public void Update(Models.Put.Station station)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = PGSqlHelper.GetUpdateQuery<Models.Put.Station>();
                }
                else 
                {
                    query = MSSqlHelper.GetUpdateQuery<Models.Put.Station>();
                }

                db.Execute(query, station);
            }
        }
    }
}
