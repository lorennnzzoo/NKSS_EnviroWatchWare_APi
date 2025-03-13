using Npgsql;
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
    public class ConfigurationRepository : IConfigurationRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public ConfigurationRepository()
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

        public DataSet GetConfigurationDataSet()
        {
            DataSet dataSet = new DataSet();
            if (_databaseProvider == "NPGSQL")
            {
                string query = @"
                    SELECT * FROM public.""Company"";
                    SELECT * FROM public.""Station"";
                    SELECT * FROM public.""Channel"";
                    SELECT * FROM public.""MonitoringType"";
                    SELECT * FROM public.""ChannelType"";
                    SELECT * FROM public.""Oxide"";
                    SELECT * FROM public.""Analyzer"";
                    SELECT * FROM public.""ScalingFactor"";
                    SELECT * FROM public.""License"";
                    SELECT * FROM public.""ConfigSetting"";
                ";

                using (NpgsqlConnection conn = (NpgsqlConnection)CreateConnection())
                {
                    NpgsqlDataAdapter dataAdapter = new NpgsqlDataAdapter(query, conn);
                    dataAdapter.Fill(dataSet);
                }
            }
            else
            {
                string query = @"
                                SELECT * FROM Company;
                                SELECT * FROM Station;
                                SELECT * FROM Channel;
                                SELECT * FROM MonitoringType;
                                SELECT * FROM ChannelType;
                                SELECT * FROM Oxide;
                                SELECT * FROM Analyzer;
                                SELECT * FROM ScalingFactor;
                                SELECT * FROM License;
                                SELECT * FROM ConfigSetting;
                            ";
                using (SqlConnection conn = (SqlConnection)CreateConnection())
                {
                    SqlDataAdapter dataAdapter = new SqlDataAdapter(query, conn);
                    dataAdapter.Fill(dataSet);
                }
            }
            return dataSet;
        }
    }
}
