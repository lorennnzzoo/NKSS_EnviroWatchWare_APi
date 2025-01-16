using Dapper;
using Models.Licenses;
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
    public class LicenseRepository : ILicenseRepository
    {
        private readonly string _connectionString;
        public LicenseRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }

        public void Add(License license)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = PGSqlHelper.GetInsertQuery<Models.Licenses.License>();
                db.Query(query, license);
            }
        }

        public void Delete(string licenseType)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"UPDATE public.\"License\" SET  \"Active\" = False WHERE \"LicenseType\" = @LicenseType";
                db.Execute(query, new { LicenseType = licenseType });
            }
        }

        public License GetLicenseByType(string licenseType)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = "SELECT * FROM public.\"License\" WHERE \"LicenseType\" = @LicenseType and \"Active\"=True ";
                return db.QuerySingleOrDefault<License>(query, new { LicenseType = licenseType });
            }
        }

        public void Update(License license)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = LicensePGSqlHelper.GetUpdateQuery<Models.Licenses.License>();

                db.Execute(query, license);
            }
        }
    }
}
