using Dapper;
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
    public class ConfigSettingRepository : IConfigSettingRepository
    {
        private readonly string _connectionString;

        public ConfigSettingRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }
        public void Add(Models.Post.ConfigSetting configSettings)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Models.Post.ConfigSetting>();
                db.Execute(query, configSettings);
            }
        }

        public void Delete(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"ConfigSetting\" SET  \"Active\" = False WHERE \"Id\" = @Id";
                db.Execute(query, new { Id = id });
            }
        }

        public IEnumerable<Models.ConfigSetting> GetAll()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"ConfigSetting\" WHERE \"Active\"=True";
                return db.Query<Models.ConfigSetting>(query).ToList();
            }
        }

        public IEnumerable<Models.ConfigSetting> GetByGroupName(string groupName)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"ConfigSetting\" WHERE \"GroupName\" =@GroupName and \"Active\"=True";
                return db.Query<Models.ConfigSetting>(query,new {GroupName=groupName }).ToList();
            }
        }

        public Models.ConfigSetting GetById(int id)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"ConfigSetting\" WHERE \"Id\" = @Id And \"Active\"=True ";
                return db.QuerySingleOrDefault<Models.ConfigSetting>(query, new { Id = id });
            }
        }

        public void Update(Models.ConfigSetting configSettings)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetUpdateQuery<Models.ConfigSetting>();

                db.Execute(query, configSettings);
            }
        }
    }
}
