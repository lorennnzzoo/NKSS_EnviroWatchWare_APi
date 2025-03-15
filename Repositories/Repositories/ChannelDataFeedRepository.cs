using Models;
using Repositories.Interfaces;
using Dapper;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using Npgsql;
using System.Data.SqlClient;

namespace Repositories
{
    public class ChannelDataFeedRepository : IChannelDataFeedRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public ChannelDataFeedRepository()
        {
            _databaseProvider = ConfigurationManager.AppSettings["DatabaseProvider"];
            
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

        public IEnumerable<Models.DashBoard.ChannelDataFeed> GetByStationId(int stationId)
        {
            using (IDbConnection db = CreateConnection())
            {
                db.Open();
                string query;

                if (_databaseProvider.ToUpper() == "NPGSQL")
                {
                    query = @"
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
                }
                else 
                {
                    query = @"
WITH channel_availability AS (
    SELECT
        [ChannelId],
        COUNT(*) AS actual_records,
        1440 AS expected_records, -- Since each channel should log once per minute
        ROUND((COUNT([ChannelDataLogTime]) * 100.0 / 1440.0), 2) AS availability_percentage
    FROM
        [ChannelData]
    WHERE
        [ChannelDataLogTime] >= DATEADD(hour, -1, GETDATE())
    GROUP BY
        [ChannelId]
)

SELECT
    chnl.[Id] AS ChannelId,
    chnl.[Name] AS ChannelName,
    tcd.[ChannelValue],
    chnl.[LoggingUnits] AS Units,
    tcd.[ChannelDataLogTime],
    ox.[Limit] AS PcbLimit, -- Fetching PcbLimit from Oxide table
    tcd.[Average],
    chnl.[Active],
    ISNULL(ca.availability_percentage, 0) AS Availability -- Handle cases where no data exists
FROM
    [Channel] chnl
LEFT JOIN
    [ChannelDataFeed] tcd
    ON chnl.[Id] = tcd.[ChannelId]
    AND tcd.[StationId] = @stationId
    AND tcd.[Active] = 1
LEFT JOIN
    [Oxide] ox
    ON chnl.[OxideId] = ox.[Id] -- Join Oxide table to fetch PcbLimit
LEFT JOIN
    channel_availability ca
    ON ca.[ChannelId] = chnl.[Id]
WHERE
    chnl.[StationId] = @stationId
ORDER BY
    chnl.[Priority];
";
                }

                return db.Query<Models.DashBoard.ChannelDataFeed>(query, new { StationId = stationId });
            }
        }

        public void InsertChannelData(int channelId, decimal channelValue, System.DateTime datetime, string passPhrase)
        {
            using (IDbConnection db = CreateConnection())
            {
                
                db.Open();

                
                var parameters = new
                {
                    p_channelid = channelId,
                    p_channelvalue = channelValue,
                    p_datetime = datetime,
                    p_pass_phrase = passPhrase
                };

                
                
                if (_databaseProvider == "NPGSQL")
                {
                    db.Execute("SELECT public.\"InsertOrUpdateChannelDataFeed\"(@p_channelid, @p_channelvalue, @p_datetime, @p_pass_phrase)", parameters);
                }
                else
                {
                    using (var cmd = new SqlCommand("dbo.InsertOrUpdateChannelDataFeed", (SqlConnection)db))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@p_channelid", channelId);
                        cmd.Parameters.AddWithValue("@p_channelvalue", channelValue);
                        cmd.Parameters.AddWithValue("@p_datetime", datetime);
                        cmd.ExecuteNonQuery();
                    }
                }
            }
        }

        public void InsertBulkData(DataTable bulkData)
        {
            using (IDbConnection connection = CreateConnection()) 
            {
                connection.Open();

                if (_databaseProvider == "NPGSQL")
                {
                    using (var writer = ((NpgsqlConnection)connection).BeginBinaryImport(
                        "COPY ChannelData (\"ChannelId\", \"ChannelValue\", \"ChannelDataLogTime\") FROM STDIN (FORMAT BINARY)"))
                    {
                        foreach (DataRow row in bulkData.Rows)
                        {
                            writer.StartRow();
                            writer.Write(row["ChannelId"], NpgsqlTypes.NpgsqlDbType.Integer);
                            writer.Write(row["ChannelValue"], NpgsqlTypes.NpgsqlDbType.Double);
                            writer.Write(row["ChannelDataLogTime"], NpgsqlTypes.NpgsqlDbType.Timestamp);
                        }
                        writer.Complete();
                    }
                }
                else 
                {
                    using (SqlBulkCopy bulkCopy = new SqlBulkCopy((SqlConnection)connection))
                    {
                        bulkCopy.DestinationTableName = "ChannelData";
                        bulkCopy.ColumnMappings.Add("ChannelId", "ChannelId");
                        bulkCopy.ColumnMappings.Add("ChannelValue", "ChannelValue");
                        bulkCopy.ColumnMappings.Add("ChannelDataLogTime", "ChannelDataLogTime");

                        bulkCopy.WriteToServer(bulkData);
                    }
                }
            }
        }

    }
}
