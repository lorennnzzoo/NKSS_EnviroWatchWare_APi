using Dapper;
using Models.Licenses;
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
    public class LicenseRepository : ILicenseRepository
    {
        private readonly string _connectionString;
        public LicenseRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }
        public License GetLicenseByType(string licenseType)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"License\" WHERE \"LicenseType\" = @LicenseType ";
                return db.QuerySingleOrDefault<License>(query, new { LicenseType = licenseType });
            }
        }
    }
}
