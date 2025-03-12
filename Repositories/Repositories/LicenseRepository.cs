using Dapper;
using Models.Licenses;
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
    public class LicenseRepository : ILicenseRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public LicenseRepository()
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

        public void Add(License license)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = PGSqlHelper.GetInsertQuery<Models.Licenses.License>(); 
                }
                else
                {
                    query = MSSqlHelper.GetInsertQuery<Models.Licenses.License>(); 
                }

                db.Execute(query, license);
            }
        }

        public void Delete(string licenseType)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "UPDATE public.\"License\" SET \"Active\" = False WHERE \"LicenseType\" = @LicenseType"; 
                }
                else
                {
                    query = "UPDATE dbo.License SET Active = 0 WHERE LicenseType = @LicenseType"; 
                }

                db.Execute(query, new { LicenseType = licenseType });
            }
        }

        public License GetLicenseByType(string licenseType)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"License\" WHERE \"LicenseType\" = @LicenseType AND \"Active\" = True"; 
                }
                else
                {
                    query = "SELECT * FROM dbo.License WHERE LicenseType = @LicenseType AND Active = 1"; 
                }

                return db.QuerySingleOrDefault<License>(query, new { LicenseType = licenseType });
            }
        }

        public void Update(License license)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = LicensePGSqlHelper.GetUpdateQuery<Models.Licenses.License>(); 
                }
                else
                {
                    query = LicenseMSSqlHelper.GetUpdateQuery<Models.Licenses.License>(); 
                }

                db.Execute(query, license);
            }
        }
    }
}
