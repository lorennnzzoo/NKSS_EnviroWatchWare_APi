using Dapper;
using Models.Report;
using Npgsql;
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

        public DataTable GetRawChannelDataAsDataTable(List<int> channelIds, DateTime from, DateTime to)
        {
            using (var conn = new NpgsqlConnection(_connectionString))
            {
                conn.Open();

                // Query the PostgreSQL function
                var query = @"
            SELECT * 
            FROM public.""GetRawChannelDataWithIds""(@StartTime, @EndTime, @ChannelIds)";

                using (var cmd = new NpgsqlCommand(query, conn))
                {
                    cmd.Parameters.AddWithValue("StartTime", from);
                    cmd.Parameters.AddWithValue("EndTime", to);
                    cmd.Parameters.AddWithValue("ChannelIds", channelIds.ToArray());

                    // Use NpgsqlDataAdapter to fill a DataTable
                    using (var adapter = new NpgsqlDataAdapter(cmd))
                    {
                        var dataTable = new DataTable();
                        adapter.Fill(dataTable);
                        return dataTable;
                    }
                }
            }
        }
    }
}
