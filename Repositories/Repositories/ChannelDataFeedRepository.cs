using Models;
using Repositories.Interfaces;
using Dapper;
using System.Collections.Generic;
using System.Configuration;
using System.Data;

namespace Repositories
{
    public class ChannelDataFeedRepository : IChannelDataFeedRepository
    {
        private readonly string _connectionString;
        public ChannelDataFeedRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }        

        public IEnumerable<Models.DashBoard.ChannelDataFeed> GetByStationId(int stationId)
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                db.Open();
                var query = @"
                                SELECT 
                                    s.""Name"",
                                    cdf.""ChannelName"", 
                                    cdf.""ChannelValue"", 
                                    cdf.""Units"", 
                                    cdf.""ChannelDataLogTime"", 
                                    cdf.""PcbLimit"", 
                                    cdf.""Active"", 
                                    cdf.""Minimum"", 
                                    cdf.""Maximum"", 
                                    cdf.""Average""
                                FROM public.""ChannelDataFeed"" cdf
                                LEFT JOIN public.""Station"" s 
                                    ON cdf.""StationId"" = s.""Id""
                                LEFT JOIN public.""Channel"" ch 
                                    ON cdf.""ChannelId"" = ch.""Id""
                                WHERE s.""Id"" = @StationId  -- Filter for StationId = 1
                                ORDER BY ch.""Priority"";  -- Order by Priority";
                return db.Query<Models.DashBoard.ChannelDataFeed>(query, new { StationId = stationId });
            }
        }
    }
}
