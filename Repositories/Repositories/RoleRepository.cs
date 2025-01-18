using Dapper;
using Models;
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
    public class RoleRepository : IRoleRepository
    {
        private readonly string _connectionString;
        public RoleRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }
        public IEnumerable<Role> GetAll()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"Roles\" WHERE \"Active\"=True";
                return db.Query<Models.Role>(query).ToList();
            }
        }
    }
}
