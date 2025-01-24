using Models;
using Repositories.Interfaces;
using Dapper;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using Npgsql;

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

        public void InsertChannelData(int channelId, decimal channelValue, System.DateTime datetime, string passPhrase)
        {
            using (IDbConnection db = new NpgsqlConnection(_connectionString))
            {
                // Open connection
                db.Open();

                // Execute the stored procedure using Dapper
                var parameters = new
                {
                    p_channelid = channelId,
                    p_channelvalue = channelValue,
                    p_datetime = datetime,
                    p_pass_phrase = passPhrase
                };

                // Execute stored procedure
                db.Execute("SELECT public.\"InsertOrUpdateChannelDataFeed\"(@p_channelid, @p_channelvalue, @p_datetime, @p_pass_phrase)", parameters);
            }
        }
    }
}
