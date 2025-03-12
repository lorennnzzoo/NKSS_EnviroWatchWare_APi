using Dapper;
using Models.Report;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
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
    public class ReportRepository : IReportRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseProvider;
        public ReportRepository()
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

        public DataTable GetAvailabilityReport(List<int> channelIds, DateTime From, DateTime To)
        {
            DataTable dataTable = new DataTable();
            using (var conn = CreateConnection())
            {
                conn.Open();

                if (_databaseProvider == "NPGSQL")
                {
                    string metadataQuery = $@"
        SELECT c.""Id"" AS ""ChannelId"", s.""Name"" AS ""StationName"", c.""Name"" AS ""ChannelName"", c.""LoggingUnits"" AS ""ChannelUnits""
        FROM public.""Channel"" c
        JOIN public.""Station"" s ON c.""StationId"" = s.""Id""
        WHERE c.""Id"" IN ({string.Join(",", channelIds)});";

                    var channels = new List<dynamic>();

                    using (var cmd = new NpgsqlCommand(metadataQuery, (NpgsqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3)
                            });
                        }
                    }

                    TimeSpan timeSpan = To - From.AddMinutes(-1);
                    int expectedDataPoints = (int)Math.Ceiling(timeSpan.TotalMinutes);

                    string selectClause = "SELECT ";
                    var columnClauses = new List<string>();

                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}";
                        string columnExpression = $@"
            ROUND(COUNT(*) FILTER (WHERE ""ChannelId"" = {channel.ChannelId}) * 100.0 / {expectedDataPoints}::numeric, 2) AS ""{columnAlias}"""; //added round and cast
                        columnClauses.Add(columnExpression);
                    }

                    string finalQuery = selectClause + string.Join(", ", columnClauses) + $@"
        FROM public.""ChannelData""
        WHERE ""ChannelDataLogTime"" BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' AND '{To:yyyy-MM-dd HH:mm:ss}'";

                    using (var cmd = new NpgsqlCommand(finalQuery, (NpgsqlConnection)conn))
                    using (var adapter = new NpgsqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }
                else
                {
                    string metadataQuery = $@"
            SELECT c.Id AS ChannelId, s.Name AS StationName, c.Name AS ChannelName, c.LoggingUnits AS ChannelUnits
            FROM Channel c
            JOIN Station s ON c.StationId = s.Id
            WHERE c.Id IN ({string.Join(",", channelIds)});";

                    var channels = new List<dynamic>();
                    using (var cmd = new SqlCommand(metadataQuery, (SqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3)
                            });
                        }
                    }

                    TimeSpan timeSpan = To - From.AddMinutes(-1);
                    int expectedDataPoints = (int)Math.Ceiling(timeSpan.TotalMinutes);

                    string selectClause = "SELECT ";
                    var columnClauses = new List<string>();
                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}";
                        string columnExpression = $@"
                ROUND(COUNT(CASE WHEN ChannelId = {channel.ChannelId} THEN 1 END) * 100.0 / {expectedDataPoints}, 2) AS [{columnAlias}]";
                        columnClauses.Add(columnExpression);
                    }

                    string finalQuery = selectClause + string.Join(", ", columnClauses) + $@"
            FROM ChannelData
            WHERE ChannelDataLogTime BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' AND '{To:yyyy-MM-dd HH:mm:ss}'";

                    using (var cmd = new SqlCommand(finalQuery, (SqlConnection)conn))
                    using (var adapter = new SqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }
            }
            return dataTable;
        }

        public DataTable GetAverageDataReport(List<int> channelIds, DateTime From, DateTime To, int IntervalInMinutes)
        {
            DataTable dataTable = new DataTable();
            using (var conn = CreateConnection())
            {
                conn.Open();
                if (_databaseProvider == "NPGSQL")
                {
                    string metadataQuery = $@"
                                SELECT 
                                    c.""Id"" AS ""ChannelId"", 
                                    s.""Name"" AS ""StationName"", 
                                    c.""Name"" AS ""ChannelName"",
                                    c.""LoggingUnits"" AS ""ChannelUnits"",
                                    o.""Limit"" AS ""OxideLimit"",
                                    ct.""ChannelTypeValue""
                                FROM public.""Channel"" c
                                JOIN public.""Station"" s ON c.""StationId"" = s.""Id""
                                JOIN public.""Oxide"" o ON c.""OxideId"" = o.""Id""
                                JOIN public.""ChannelType"" ct ON c.""ChannelTypeId"" = ct.""Id""
                                WHERE c.""Id"" IN ({string.Join(",", channelIds)});";

                    var channels = new List<dynamic>();

                    using (var cmd = new NpgsqlCommand(metadataQuery, (NpgsqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3),
                                OxideLimit = reader.GetString(4),
                                ChannelTypeValue = reader.GetString(5)
                            });
                        }
                    }


                    string selectClause = $@"
                    SELECT CAST(to_timestamp(
                        FLOOR(EXTRACT(EPOCH FROM cd.""ChannelDataLogTime"") / ({IntervalInMinutes} * 60)) * ({IntervalInMinutes} * 60)
                    ) AS TIMESTAMP WITHOUT TIME ZONE) AS ""LogTime"", ";

                    string fromClause = " FROM public.\"ChannelData\" cd ";

                    string whereClause = $@"
                    WHERE cd.""ChannelId"" IN ({string.Join(",", channelIds)}) 
                      AND cd.""ChannelDataLogTime"" BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' 
                                                       AND '{To:yyyy-MM-dd HH:mm:ss}'";

                    string groupByClause = " GROUP BY \"LogTime\" ORDER BY \"LogTime\";";

                    var columnClauses = new List<string>();

                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}".Replace(" ", "_");

                        string columnExpression = $@"
                    CAST(AVG(CASE 
                        WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'VECTOR' THEN SIN(RADIANS(cd.""ChannelValue"")) 
                        ELSE NULL 
                    END) AS NUMERIC(10,2)) AS ""{columnAlias}_SIN"", 

                    CAST(AVG(CASE 
                        WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'VECTOR' THEN COS(RADIANS(cd.""ChannelValue"")) 
                        ELSE NULL 
                    END) AS NUMERIC(10,2)) AS ""{columnAlias}_COS"", 

                    CAST(MAX(CASE 
                        WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'TOTAL' THEN cd.""ChannelValue""
                        ELSE NULL 
                    END) - MIN(CASE 
                        WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'TOTAL' THEN cd.""ChannelValue""
                        ELSE NULL 
                    END) AS NUMERIC(10,2)) AS ""{columnAlias}_TOTAL_RANGE"",

                    CAST(SUM(CASE 
                        WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'FLOW' THEN cd.""ChannelValue""
                        ELSE NULL 
                    END) AS NUMERIC(10,2)) AS ""{columnAlias}_FLOW_SUM"",

                    CAST(AVG(CASE 
                        WHEN cd.""ChannelId"" = {channel.ChannelId} THEN cd.""ChannelValue""
                        ELSE NULL 
                    END) AS NUMERIC(10,2)) AS ""{columnAlias}""";

                        columnClauses.Add(columnExpression);
                    }


                    string finalQuery = selectClause + string.Join(", ", columnClauses) + fromClause + whereClause + groupByClause;

                    using (var cmd = new NpgsqlCommand(finalQuery, (NpgsqlConnection)conn))
                    using (var adapter = new NpgsqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }
                else
                {
                    string metadataQuery = $@"
                SELECT 
                    c.Id AS ChannelId, 
                    s.Name AS StationName, 
                    c.Name AS ChannelName,
                    c.LoggingUnits AS ChannelUnits,
                    o.Limit AS OxideLimit,
                    ct.ChannelTypeValue
                FROM dbo.Channel c
                JOIN dbo.Station s ON c.StationId = s.Id
                JOIN dbo.Oxide o ON c.OxideId = o.Id
                JOIN dbo.ChannelType ct ON c.ChannelTypeId = ct.Id
                WHERE c.Id IN ({string.Join(",", channelIds)})";

                    var channels = new List<dynamic>();
                    using (var cmd = new SqlCommand(metadataQuery, (SqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3),
                                OxideLimit = reader.GetString(4),
                                ChannelTypeValue = reader.GetString(5)
                            });
                        }
                    }

                    string selectClause = $@"
                SELECT 
                    DATEADD(MINUTE, (DATEDIFF(MINUTE, 0, cd.ChannelDataLogTime) / {IntervalInMinutes}) * {IntervalInMinutes}, 0) AS LogTime, ";

                    string fromClause = " FROM dbo.ChannelData cd ";

                    string whereClause = $@"
                WHERE cd.ChannelId IN ({string.Join(",", channelIds)}) 
                AND cd.ChannelDataLogTime BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' 
                                             AND '{To:yyyy-MM-dd HH:mm:ss}'";

                    string groupByClause = $" GROUP BY DATEADD(MINUTE, (DATEDIFF(MINUTE, 0, cd.ChannelDataLogTime) / {IntervalInMinutes}) * {IntervalInMinutes}, 0) ORDER BY LogTime;";

                    var columnClauses = new List<string>();

                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}".Replace(" ", "_");

                        string columnExpression = $@"
                CAST(AVG(CASE 
                    WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'VECTOR' THEN SIN(RADIANS(cd.ChannelValue)) 
                    ELSE NULL 
                END) AS DECIMAL(10,2)) AS [{columnAlias}_SIN], 

                CAST(AVG(CASE 
                    WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'VECTOR' THEN COS(RADIANS(cd.ChannelValue)) 
                    ELSE NULL 
                END) AS DECIMAL(10,2)) AS [{columnAlias}_COS], 

                CAST(MAX(CASE 
                    WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'TOTAL' THEN cd.ChannelValue
                    ELSE NULL 
                END) - MIN(CASE 
                    WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'TOTAL' THEN cd.ChannelValue
                    ELSE NULL 
                END) AS DECIMAL(10,2)) AS [{columnAlias}_TOTAL_RANGE],

                CAST(SUM(CASE 
                    WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'FLOW' THEN cd.ChannelValue
                    ELSE NULL 
                END) AS DECIMAL(10,2)) AS [{columnAlias}_FLOW_SUM],

                CAST(AVG(CASE 
                    WHEN cd.ChannelId = {channel.ChannelId} THEN cd.ChannelValue
                    ELSE NULL 
                END) AS DECIMAL(10,2)) AS [{columnAlias}]";

                        columnClauses.Add(columnExpression);
                    }

                    string finalQuery = selectClause + string.Join(", ", columnClauses) + fromClause + whereClause + groupByClause;

                    using (var cmd = new SqlCommand(finalQuery, (SqlConnection)conn))
                    using (var adapter = new SqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }

            }
            return dataTable;
        }

        public DataTable GetAverageExceedanceReport(List<int> channelIds, DateTime From, DateTime To, int IntervalInMinutes)
        {
            DataTable dataTable = new DataTable();
            using (var conn = CreateConnection())
            {
                conn.Open();
                if (_databaseProvider == "NPGSQL")
                {
                    string metadataQuery = $@"
                                SELECT 
                                    c.""Id"" AS ""ChannelId"", 
                                    s.""Name"" AS ""StationName"", 
                                    c.""Name"" AS ""ChannelName"",
                                    c.""LoggingUnits"" AS ""ChannelUnits"",
                                    CAST(o.""Limit"" AS NUMERIC) AS ""OxideLimit"",  -- Ensure numeric type
                                    ct.""ChannelTypeValue""
                                FROM public.""Channel"" c
                                JOIN public.""Station"" s ON c.""StationId"" = s.""Id""
                                JOIN public.""Oxide"" o ON c.""OxideId"" = o.""Id""
                                JOIN public.""ChannelType"" ct ON c.""ChannelTypeId"" = ct.""Id""
                                WHERE c.""Id"" IN ({string.Join(",", channelIds)});";

                    var channels = new List<dynamic>();

                    using (var cmd = new NpgsqlCommand(metadataQuery, (NpgsqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3),
                                OxideLimit = reader.GetDecimal(4),
                                ChannelTypeValue = reader.GetString(5)
                            });
                        }
                    }

                    string selectClause = $@"
                                SELECT CAST(to_timestamp(
                                    FLOOR(EXTRACT(EPOCH FROM cd.""ChannelDataLogTime"") / ({IntervalInMinutes} * 60)) * ({IntervalInMinutes} * 60)
                                ) AS TIMESTAMP WITHOUT TIME ZONE) AS ""LogTime"", ";

                    string fromClause = " FROM public.\"ChannelData\" cd ";

                    string whereClause = $@"
                                WHERE cd.""ChannelId"" IN ({string.Join(",", channelIds)}) 
                                AND cd.""ChannelDataLogTime"" BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' 
                                                                 AND '{To:yyyy-MM-dd HH:mm:ss}'";

                    string groupByClause = " GROUP BY \"LogTime\" ORDER BY \"LogTime\";";

                    var columnClauses = new List<string>();

                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}".Replace(" ", "_");

                        string columnExpression = $@"
                                CAST(AVG(CASE 
                                    WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'VECTOR' THEN SIN(RADIANS(cd.""ChannelValue"")) 
                                    ELSE NULL 
                                END) AS NUMERIC(10,2)) AS ""{columnAlias}_SIN"", 

                                CAST(AVG(CASE 
                                    WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'VECTOR' THEN COS(RADIANS(cd.""ChannelValue"")) 
                                    ELSE NULL 
                                END) AS NUMERIC(10,2)) AS ""{columnAlias}_COS"", 

                                CAST(MAX(CASE 
                                    WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'TOTAL' THEN cd.""ChannelValue""
                                    ELSE NULL 
                                END) - MIN(CASE 
                                    WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'TOTAL' THEN cd.""ChannelValue""
                                    ELSE NULL 
                                END) AS NUMERIC(10,2)) AS ""{columnAlias}_TOTAL_RANGE"",

                                CAST(SUM(CASE 
                                    WHEN cd.""ChannelId"" = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'FLOW' THEN cd.""ChannelValue""
                                    ELSE NULL 
                                END) AS NUMERIC(10,2)) AS ""{columnAlias}_FLOW_SUM"",

                                CAST(AVG(CASE 
                                    WHEN cd.""ChannelId"" = {channel.ChannelId} THEN cd.""ChannelValue""
                                    ELSE NULL 
                                END) AS NUMERIC(10,2)) AS ""{columnAlias}"",

                                -- Exceeded column
                                (CAST(AVG(CASE 
                                    WHEN cd.""ChannelId"" = {channel.ChannelId} THEN cd.""ChannelValue""
                                    ELSE NULL 
                                END) AS NUMERIC(10,2)) > {channel.OxideLimit}) AS ""{columnAlias}_Exceeded""";

                        columnClauses.Add(columnExpression);
                    }

                    string finalQuery = selectClause + string.Join(", ", columnClauses) + fromClause + whereClause + groupByClause;

                    using (var cmd = new NpgsqlCommand(finalQuery, (NpgsqlConnection)conn))
                    using (var adapter = new NpgsqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }
                else
                {
                    string metadataQuery = $@"
                SELECT 
                    c.Id AS ChannelId, 
                    s.Name AS StationName, 
                    c.Name AS ChannelName,
                    c.LoggingUnits AS ChannelUnits,
                    CAST(o.Limit AS DECIMAL(10,2)) AS OxideLimit,  -- Ensure numeric type
                    ct.ChannelTypeValue
                FROM dbo.Channel c
                JOIN dbo.Station s ON c.StationId = s.Id
                JOIN dbo.Oxide o ON c.OxideId = o.Id
                JOIN dbo.ChannelType ct ON c.ChannelTypeId = ct.Id
                WHERE c.Id IN ({string.Join(",", channelIds)})";

                    var channels = new List<dynamic>();

                    using (var cmd = new SqlCommand(metadataQuery, (SqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3),
                                OxideLimit = reader.GetDecimal(4),
                                ChannelTypeValue = reader.GetString(5)
                            });
                        }
                    }

                    string selectClause = $@"
                SELECT 
                    DATEADD(SECOND, DATEDIFF(SECOND, '1970-01-01', cd.ChannelDataLogTime) / ({IntervalInMinutes} * 60) * ({IntervalInMinutes} * 60), '1970-01-01') AS LogTime, ";

                    string fromClause = " FROM dbo.ChannelData cd ";

                    string whereClause = $@"
                WHERE cd.ChannelId IN ({string.Join(",", channelIds)}) 
                AND cd.ChannelDataLogTime BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' 
                                              AND '{To:yyyy-MM-dd HH:mm:ss}'";

                    string groupByClause = $" GROUP BY DATEADD(SECOND, DATEDIFF(SECOND, '1970-01-01', cd.ChannelDataLogTime) / ({IntervalInMinutes} * 60) * ({IntervalInMinutes} * 60), '1970-01-01') ORDER BY LogTime;";

                    var columnClauses = new List<string>();

                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}".Replace(" ", "_");

                        string columnExpression = $@"
                    CAST(AVG(CASE 
                        WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'VECTOR' THEN SIN(RADIANS(cd.ChannelValue)) 
                        ELSE NULL 
                    END) AS DECIMAL(10,2)) AS [{columnAlias}_SIN], 

                    CAST(AVG(CASE 
                        WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'VECTOR' THEN COS(RADIANS(cd.ChannelValue)) 
                        ELSE NULL 
                    END) AS DECIMAL(10,2)) AS [{columnAlias}_COS], 

                    CAST(MAX(CASE 
                        WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'TOTAL' THEN cd.ChannelValue
                        ELSE NULL 
                    END) - MIN(CASE 
                        WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'TOTAL' THEN cd.ChannelValue
                        ELSE NULL 
                    END) AS DECIMAL(10,2)) AS [{columnAlias}_TOTAL_RANGE],

                    CAST(SUM(CASE 
                        WHEN cd.ChannelId = {channel.ChannelId} AND '{channel.ChannelTypeValue}' = 'FLOW' THEN cd.ChannelValue
                        ELSE NULL 
                    END) AS DECIMAL(10,2)) AS [{columnAlias}_FLOW_SUM],

                    CAST(AVG(CASE 
                        WHEN cd.ChannelId = {channel.ChannelId} THEN cd.ChannelValue
                        ELSE NULL 
                    END) AS DECIMAL(10,2)) AS [{columnAlias}],

                    -- Exceeded column
                    CASE 
                        WHEN AVG(CASE WHEN cd.ChannelId = {channel.ChannelId} THEN cd.ChannelValue ELSE NULL END) > {channel.OxideLimit} 
                        THEN 1 ELSE 0 
                    END AS [{columnAlias}_Exceeded]";

                        columnClauses.Add(columnExpression);
                    }

                    string finalQuery = selectClause + string.Join(", ", columnClauses) + fromClause + whereClause + groupByClause;

                    using (var cmd = new SqlCommand(finalQuery, (SqlConnection)conn))
                    using (var adapter = new SqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }
            }
            return dataTable;
        }

        public DataTable GetRawDataReport(List<int> channelIds, DateTime From, DateTime To)
        {
            DataTable dataTable = new DataTable();
            using (var conn = CreateConnection())
            {
                conn.Open();
                if (_databaseProvider == "NPGSQL")
                {
                    string metadataQuery = $@"
                                SELECT 
                                    c.""Id"" AS ""ChannelId"", 
                                    s.""Name"" AS ""StationName"", 
                                    c.""Name"" AS ""ChannelName"",
                                    c.""LoggingUnits"" AS ""ChannelUnits"",
                                    o.""Limit"" AS ""OxideLimit"",
                                    ct.""ChannelTypeValue""
                                FROM public.""Channel"" c
                                JOIN public.""Station"" s ON c.""StationId"" = s.""Id""
                                JOIN public.""Oxide"" o ON c.""OxideId"" = o.""Id""
                                JOIN public.""ChannelType"" ct ON c.""ChannelTypeId"" = ct.""Id""
                                WHERE c.""Id"" IN ({string.Join(",", channelIds)});";

                    var channels = new List<dynamic>();

                    using (var cmd = new NpgsqlCommand(metadataQuery, (NpgsqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3),
                                OxideLimit = reader.GetString(4),
                                ChannelTypeValue = reader.GetString(5)
                            });
                        }
                    }

                    string selectClause = "SELECT cd.\"ChannelDataLogTime\" AS \"LogTime\", ";
                    string fromClause = " FROM public.\"ChannelData\" cd ";
                    string whereClause = $" WHERE cd.\"ChannelId\" IN ({string.Join(",", channelIds)}) AND cd.\"ChannelDataLogTime\" BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' AND '{To:yyyy-MM-dd HH:mm:ss}'";
                    string groupByClause = " GROUP BY cd.\"ChannelDataLogTime\" ORDER BY cd.\"ChannelDataLogTime\";";
                    var columnClauses = new List<string>();

                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}";
                        //string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}-{channel.OxideLimit}-{channel.ChannelTypeValue}";
                        string columnExpression = $"MAX(cd.\"ChannelValue\") FILTER (WHERE cd.\"ChannelId\" = {channel.ChannelId}) AS \"{columnAlias}\"";
                        columnClauses.Add(columnExpression);
                    }

                    string finalQuery = selectClause + string.Join(", ", columnClauses) + fromClause + whereClause + groupByClause;
                    using (var cmd = new NpgsqlCommand(finalQuery, (NpgsqlConnection)conn))
                    using (var adapter = new NpgsqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }
                else
                {
                    string metadataQuery = $@"
                            SELECT 
                                c.Id AS ChannelId, 
                                s.Name AS StationName, 
                                c.Name AS ChannelName,
                                c.LoggingUnits AS ChannelUnits,
                                o.Limit AS OxideLimit,
                                ct.ChannelTypeValue
                            FROM Channel c
                            JOIN Station s ON c.StationId = s.Id
                            JOIN Oxide o ON c.OxideId = o.Id
                            JOIN ChannelType ct ON c.ChannelTypeId = ct.Id
                            WHERE c.Id IN ({string.Join(",", channelIds)});";

                    var channels = new List<dynamic>();
                    using (var cmd = new SqlCommand(metadataQuery, (SqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3),
                                OxideLimit = reader.GetString(4),
                                ChannelTypeValue = reader.GetString(5)
                            });
                        }
                    }

                    string selectClause = "SELECT cd.ChannelDataLogTime AS LogTime, ";
                    string fromClause = " FROM ChannelData cd ";
                    string whereClause = $" WHERE cd.ChannelId IN ({string.Join(",", channelIds)}) AND cd.ChannelDataLogTime BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' AND '{To:yyyy-MM-dd HH:mm:ss}'";
                    string groupByClause = " GROUP BY cd.ChannelDataLogTime ORDER BY cd.ChannelDataLogTime;";
                    var columnClauses = new List<string>();

                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}";
                        string columnExpression = $"MAX(CASE WHEN cd.ChannelId = {channel.ChannelId} THEN cd.ChannelValue END) AS [{columnAlias}]";
                        columnClauses.Add(columnExpression);
                    }

                    string finalQuery = selectClause + string.Join(", ", columnClauses) + fromClause + whereClause + groupByClause;
                    using (var cmd = new SqlCommand(finalQuery, (SqlConnection)conn))
                    using (var adapter = new SqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }

            }
            return dataTable;
        }

        public DataTable GetRawExceedanceReport(List<int> channelIds, DateTime From, DateTime To)
        {
            DataTable dataTable = new DataTable();
            using (var conn = CreateConnection())
            {
                conn.Open();
                if (_databaseProvider == "NPGSQL")
                {
                    string metadataQuery = $@"
                                SELECT 
                                    c.""Id"" AS ""ChannelId"", 
                                    s.""Name"" AS ""StationName"", 
                                    c.""Name"" AS ""ChannelName"",
                                    c.""LoggingUnits"" AS ""ChannelUnits"",
                                    CAST(o.""Limit"" AS NUMERIC) AS ""OxideLimit"",  -- Ensure it's numeric
                                    ct.""ChannelTypeValue""
                                FROM public.""Channel"" c
                                JOIN public.""Station"" s ON c.""StationId"" = s.""Id""
                                JOIN public.""Oxide"" o ON c.""OxideId"" = o.""Id""
                                JOIN public.""ChannelType"" ct ON c.""ChannelTypeId"" = ct.""Id""
                                WHERE c.""Id"" IN ({string.Join(",", channelIds)});";

                    var channels = new List<dynamic>();

                    using (var cmd = new NpgsqlCommand(metadataQuery, (NpgsqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3),
                                OxideLimit = reader.GetDecimal(4),
                                ChannelTypeValue = reader.GetString(5)
                            });
                        }
                    }

                    string selectClause = "SELECT cd.\"ChannelDataLogTime\" AS \"LogTime\", ";
                    string fromClause = " FROM public.\"ChannelData\" cd ";
                    string whereClause = $" WHERE cd.\"ChannelId\" IN ({string.Join(",", channelIds)}) AND cd.\"ChannelDataLogTime\" BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' AND '{To:yyyy-MM-dd HH:mm:ss}'";
                    string groupByClause = " GROUP BY cd.\"ChannelDataLogTime\" ORDER BY cd.\"ChannelDataLogTime\";";
                    var columnClauses = new List<string>();

                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}".Replace(" ", "_");

                        string columnExpression = $@"
                                    MAX(cd.""ChannelValue"") FILTER (WHERE cd.""ChannelId"" = {channel.ChannelId}) AS ""{columnAlias}""";

                        string exceededColumnExpression = $@"
                                    (MAX(cd.""ChannelValue"") FILTER (WHERE cd.""ChannelId"" = {channel.ChannelId}) > {channel.OxideLimit}) AS ""{columnAlias}_Exceeded""";

                        columnClauses.Add(columnExpression);
                        columnClauses.Add(exceededColumnExpression);
                    }

                    string finalQuery = selectClause + string.Join(", ", columnClauses) + fromClause + whereClause + groupByClause;

                    using (var cmd = new NpgsqlCommand(finalQuery, (NpgsqlConnection)conn))
                    using (var adapter = new NpgsqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }
                else
                {
                    string metadataQuery = $@"
                SELECT 
                    c.Id AS ChannelId, 
                    s.Name AS StationName, 
                    c.Name AS ChannelName,
                    c.LoggingUnits AS ChannelUnits,
                    CAST(o.Limit AS DECIMAL(10,2)) AS OxideLimit,  -- Ensure it's numeric
                    ct.ChannelTypeValue
                FROM dbo.Channel c
                JOIN dbo.Station s ON c.StationId = s.Id
                JOIN dbo.Oxide o ON c.OxideId = o.Id
                JOIN dbo.ChannelType ct ON c.ChannelTypeId = ct.Id
                WHERE c.Id IN ({string.Join(",", channelIds)})";

                    var channels = new List<dynamic>();

                    using (var cmd = new SqlCommand(metadataQuery, (SqlConnection)conn))
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            channels.Add(new
                            {
                                ChannelId = reader.GetInt32(0),
                                StationName = reader.GetString(1),
                                ChannelName = reader.GetString(2),
                                ChannelUnits = reader.GetString(3),
                                OxideLimit = reader.GetDecimal(4),
                                ChannelTypeValue = reader.GetString(5)
                            });
                        }
                    }

                    string selectClause = "SELECT cd.ChannelDataLogTime AS LogTime, ";
                    string fromClause = " FROM dbo.ChannelData cd ";
                    string whereClause = $@"
                WHERE cd.ChannelId IN ({string.Join(",", channelIds)}) 
                AND cd.ChannelDataLogTime BETWEEN '{From.AddMinutes(-1):yyyy-MM-dd HH:mm:ss}' 
                                             AND '{To:yyyy-MM-dd HH:mm:ss}'";

                    string groupByClause = " GROUP BY cd.ChannelDataLogTime ORDER BY cd.ChannelDataLogTime;";

                    var columnClauses = new List<string>();

                    foreach (var channel in channels)
                    {
                        string columnAlias = $"{channel.StationName}-{channel.ChannelName}-{channel.ChannelUnits}".Replace(" ", "_");

                        string columnExpression = $@"
                    MAX(CASE WHEN cd.ChannelId = {channel.ChannelId} THEN cd.ChannelValue ELSE NULL END) AS [{columnAlias}]";

                        string exceededColumnExpression = $@"
                    MAX(CASE 
                        WHEN cd.ChannelId = {channel.ChannelId} AND cd.ChannelValue > {channel.OxideLimit} THEN 1 
                        ELSE 0 
                    END) AS [{columnAlias}_Exceeded]";

                        columnClauses.Add(columnExpression);
                        columnClauses.Add(exceededColumnExpression);
                    }

                    string finalQuery = selectClause + string.Join(", ", columnClauses) + fromClause + whereClause + groupByClause;

                    using (var cmd = new SqlCommand(finalQuery, (SqlConnection)conn))
                    using (var adapter = new SqlDataAdapter(cmd))
                    {
                        adapter.Fill(dataTable);
                    }
                }
            }
            return dataTable;
        }
    }
}
