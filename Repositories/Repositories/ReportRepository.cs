using Dapper;
using Models.Report;
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
    public class ReportRepository : IReportRepository
    {
        private readonly string _connectionString;
        public ReportRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString; ;
        }
        public List<Data> Generate12HourAvgReportForChannel(int ChannelId, DateTime From, DateTime To)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"SELECT \"ChannelValue\", \"ChannelDataLogTime\"            FROM public.\"ChannelData_12HourAvg\"            WHERE \"ChannelId\" = @ChannelId           AND \"ChannelDataLogTime\" >= '{From.ToString("yyyy-MM-dd HH:mm:00")}'           AND \"ChannelDataLogTime\" <= '{To.ToString("yyyy-MM-dd HH:mm:00")}'";
                return db.Query<Data>(query, new { ChannelId = ChannelId }).ToList();
            }
        }

        public List<Data> Generate15MinsAvgReportForChannel(int ChannelId, DateTime From, DateTime To)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"SELECT \"ChannelValue\", \"ChannelDataLogTime\"            FROM public.\"ChannelData_15MinAvg\"            WHERE \"ChannelId\" = @ChannelId           AND \"ChannelDataLogTime\" >= '{From.ToString("yyyy-MM-dd HH:mm:00")}'           AND \"ChannelDataLogTime\" <= '{To.ToString("yyyy-MM-dd HH:mm:00")}'";
                return db.Query<Data>(query, new { ChannelId = ChannelId }).ToList();
            }
        }

        public List<Data> Generate1HourAvgReportForChannel(int ChannelId, DateTime From, DateTime To)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"SELECT \"ChannelValue\", \"ChannelDataLogTime\"            FROM public.\"ChannelData_HourlyAvg\"            WHERE \"ChannelId\" = @ChannelId           AND \"ChannelDataLogTime\" >= '{From.ToString("yyyy-MM-dd HH:mm:00")}'           AND \"ChannelDataLogTime\" <= '{To.ToString("yyyy-MM-dd HH:mm:00")}'";
                return db.Query<Data>(query, new { ChannelId = ChannelId }).ToList();
            }
        }

        public List<Data> Generate24HourAvgReportForChannel(int ChannelId, DateTime From, DateTime To)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"SELECT \"ChannelValue\", \"ChannelDataLogTime\"            FROM public.\"ChannelData_24HourAvg\"            WHERE \"ChannelId\" = @ChannelId           AND \"ChannelDataLogTime\" >= '{From.ToString("yyyy-MM-dd HH:mm:00")}'           AND \"ChannelDataLogTime\" <= '{To.ToString("yyyy-MM-dd HH:mm:00")}'";
                return db.Query<Data>(query, new { ChannelId = ChannelId }).ToList();
            }
        }

        public List<Data> GenerateMonthAvgReportForChannel(int ChannelId, DateTime From, DateTime To)
        {
            throw new NotImplementedException();
        }

        public List<Data> GenerateRawDataReportForChannel(int ChannelId, DateTime From, DateTime To)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = $"SELECT pgp_sym_decrypt(public.\"ChannelData\".\"ChannelValue\"::bytea, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?') AS ChannelValue, \"ChannelDataLogTime\"            FROM public.\"ChannelData\"            WHERE \"ChannelId\" = @ChannelId           AND \"ChannelDataLogTime\" >= '{From.ToString("yyyy-MM-dd HH:mm:00")}'           AND \"ChannelDataLogTime\" <= '{To.ToString("yyyy-MM-dd HH:mm:00")}'";
                return db.Query<Data>(query,new { ChannelId=ChannelId}).ToList();
            }
        }

        public List<Data> GenerateSixMonthAvgReportForChannel(int ChannelId, DateTime From, DateTime To)
        {
            throw new NotImplementedException();
        }

        public List<Data> GenerateYearAvgReportForChannel(int ChannelId, DateTime From, DateTime To)
        {
            throw new NotImplementedException();
        }
    }
}
