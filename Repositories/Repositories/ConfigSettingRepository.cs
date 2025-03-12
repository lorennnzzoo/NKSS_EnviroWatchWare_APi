using Dapper;
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
    public class ConfigSettingRepository : IConfigSettingRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;

        public ConfigSettingRepository()
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
        public void Add(Models.Post.ConfigSetting configSettings)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query = _databaseProvider == "NPGSQL"
                    ? PGSqlHelper.GetInsertQuery<Models.Post.ConfigSetting>()  
                    : MSSqlHelper.GetInsertQuery<Models.Post.ConfigSetting>(); 

                db.Execute(query, configSettings);
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
                    query = "UPDATE public.\"ConfigSetting\" SET \"Active\" = False WHERE \"Id\" = @Id";
                }
                else
                {
                    query = "UPDATE ConfigSetting SET Active = 0 WHERE Id = @Id"; 
                }

                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<Models.ConfigSetting> GetAll()
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"ConfigSetting\" WHERE \"Active\" = True"; 
                }
                else
                {
                    query = "SELECT * FROM ConfigSetting WHERE Active = 1"; 
                }

                return db.Query<Models.ConfigSetting>(query).ToList();
            }
        }

        public IEnumerable<Models.ConfigSetting> GetByGroupName(string groupName)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"ConfigSetting\" WHERE \"GroupName\" = @GroupName AND \"Active\" = True"; 
                }
                else
                {
                    query = "SELECT * FROM ConfigSetting WHERE GroupName = @GroupName AND Active = 1";
                }

                return db.Query<Models.ConfigSetting>(query, new { GroupName = groupName }).ToList();
            }
        }

        public Models.ConfigSetting GetById(int id)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"ConfigSetting\" WHERE \"Id\" = @Id AND \"Active\" = True"; 
                }
                else
                {
                    query = "SELECT * FROM ConfigSetting WHERE Id = @Id AND Active = 1"; 
                }

                return db.QuerySingleOrDefault<Models.ConfigSetting>(query, new { Id = id });
            }
        }

        public void Update(Models.ConfigSetting configSettings)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = PGSqlHelper.GetUpdateQuery<Models.ConfigSetting>(); 
                }
                else
                {
                    query = MSSqlHelper.GetUpdateQuery<Models.ConfigSetting>(); 
                }

                db.Execute(query, configSettings);
            }
        }
    }
}
