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
    public class CompanyRepository : ICompanyRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;

        public CompanyRepository()
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

        
        public Company GetById(int id)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"Company\" WHERE \"Id\" = @Id AND \"Active\" = True"; 
                }
                else
                {
                    query = "SELECT * FROM Company WHERE Id = @Id AND Active = 1"; 
                }

                return db.QuerySingleOrDefault<Company>(query, new { Id = id });
            }
        }

        
        public IEnumerable<Company> GetAll()
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query;

                if (_databaseProvider == "NPGSQL")
                {
                    query = "SELECT * FROM public.\"Company\" WHERE \"Active\" = True"; 
                }
                else
                {
                    query = "SELECT * FROM Company WHERE Active = 1"; 
                }

                return db.Query<Company>(query).ToList();
            }
        }

        
        public void Add(Post.Company company)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query = _databaseProvider == "NPGSQL"
                    ? PGSqlHelper.GetInsertQuery<Post.Company>()  
                    : MSSqlHelper.GetInsertQuery<Post.Company>(); 

                db.Execute(query, company);
            }
        }

        
        public void Update(Models.Put.Company company)
        {
            using (IDbConnection db = CreateConnection()) 
            {
                db.Open();
                string query = _databaseProvider == "NPGSQL"
                    ? PGSqlHelper.GetUpdateQuery<Models.Put.Company>()  
                    : MSSqlHelper.GetUpdateQuery<Models.Put.Company>(); 

                db.Execute(query, company);
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
                    query = "UPDATE public.\"Company\" SET \"Active\" = False WHERE \"Id\" = @Id"; 
                }
                else
                {
                    query = "UPDATE Company SET Active = 0 WHERE Id = @Id"; 
                }

                db.Execute(query, new { Id = id });
            }
        }
    }
}
