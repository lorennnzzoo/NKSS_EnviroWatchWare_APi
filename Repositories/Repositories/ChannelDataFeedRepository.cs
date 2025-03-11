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
                //    var query = @"
                //SELECT 
                //    tcd.""ChannelId"", 
                //    tcd.""ChannelName"", 
                //    tcd.""ChannelValue"", 
                //    tcd.""Units"", 
                //    tcd.""ChannelDataLogTime"", 
                //    tcd.""PcbLimit"",
                //    tcd.""Average""
                //FROM 
                //    ""ChannelDataFeed"" tcd
                //INNER JOIN 
                //    ""Channel"" chnl ON chnl.""Id"" = tcd.""ChannelId""
                //WHERE 
                //    tcd.""StationId"" = @stationId
                //    AND tcd.""Active"" = TRUE 
                //    AND chnl.""Active"" = TRUE
                //ORDER BY 
                //    chnl.""Priority"";";
                //            var query = @"
                //WITH channel_availability AS (
                //    SELECT 
                //        ""ChannelId"",
                //        COUNT(""ChannelDataLogTime"") AS actual_records,
                //        1440 AS expected_records, -- Since each channel should log once per minute
                //        ROUND((COUNT(""ChannelDataLogTime"")::DECIMAL / 1440) * 100, 2) AS availability_percentage
                //    FROM 
                //        ""ChannelData""
                //    WHERE 
                //        ""ChannelDataLogTime"" >= NOW() - INTERVAL '24 hours'
                //    GROUP BY 
                //        ""ChannelId""
                //)

                //SELECT 
                //    tcd.""ChannelId"", 
                //    tcd.""ChannelName"", 
                //    tcd.""ChannelValue"", 
                //    tcd.""Units"", 
                //    tcd.""ChannelDataLogTime"", 
                //    tcd.""PcbLimit"",
                //    tcd.""Average"",
                //    COALESCE(ca.availability_percentage, 0) AS Availability -- Handle cases where no data exists
                //FROM 
                //    ""ChannelDataFeed"" tcd
                //INNER JOIN 
                //    ""Channel"" chnl ON chnl.""Id"" = tcd.""ChannelId""
                //LEFT JOIN 
                //    channel_availability ca ON ca.""ChannelId"" = tcd.""ChannelId""
                //WHERE 
                //    tcd.""StationId"" = @stationId
                //    AND tcd.""Active"" = TRUE 
                //    AND chnl.""Active"" = TRUE
                //ORDER BY 
                //    chnl.""Priority"";";


                string query = @"
WITH channel_availability AS (
    SELECT 
        ""ChannelId"",
        COUNT(*) AS actual_records,
        1440 AS expected_records, -- Since each channel should log once per minute
        ROUND((COUNT(""ChannelDataLogTime"")::DECIMAL / 60) * 100, 2) AS availability_percentage
    FROM 
        ""ChannelData""
    WHERE 
        ""ChannelDataLogTime"" >= NOW() - INTERVAL '1 hour'
    GROUP BY 
        ""ChannelId""
)

SELECT 
    chnl.""Id"" AS ""ChannelId"", 
    chnl.""Name"" AS ""ChannelName"", 
    tcd.""ChannelValue"", 
    chnl.""LoggingUnits"" as ""Units"", 
    tcd.""ChannelDataLogTime"", 
    ox.""Limit"" AS ""PcbLimit"", -- Fetching PcbLimit from Oxide table
    tcd.""Average"",
    chnl.""Active"",
    COALESCE(ca.availability_percentage, 0) AS ""Availability"" -- Handle cases where no data exists
FROM 
    ""Channel"" chnl
LEFT JOIN 
    ""ChannelDataFeed"" tcd 
    ON chnl.""Id"" = tcd.""ChannelId"" 
    AND tcd.""StationId"" = @stationId 
    AND tcd.""Active"" = TRUE
LEFT JOIN 
    ""Oxide"" ox 
    ON chnl.""OxideId"" = ox.""Id"" -- Join Oxide table to fetch PcbLimit
LEFT JOIN 
    channel_availability ca 
    ON ca.""ChannelId"" = chnl.""Id""
WHERE 
    chnl.""StationId"" = @stationId
ORDER BY 
    chnl.""Priority"";
";

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
