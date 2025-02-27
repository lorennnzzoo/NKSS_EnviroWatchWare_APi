//using Dapper;
//using Npgsql;
//using System;
//using System.Collections.Generic;
//using System.Data;
//using System.Linq;
//using System.Configuration;
//using System.Text;
//using Newtonsoft.Json;

//namespace RepositoriesTest
//{
//    class Program
//    {
//        static void Main(string[] args)
//        {
//            var channelIds = new List<int> { 1, 2, 3, 4, 5, 6, 7, 8 };
//            DateTime fromDate = new DateTime(2020, 01, 01, 00, 00, 00);
//            DateTime toDate = new DateTime(2021, 12, 31, 23, 59, 59);
//            DataTransformer.ValidateQueryLimits(channelIds, fromDate, toDate);
//            var channelsData=DataFetcher.GetRawChannelData(channelIds, fromDate, toDate);
//            var reportData = DataTransformer.TransformToChannelDataReport(channelsData.ToList());
//        }
//    }
//    public class ChannelDataRaw
//    {
//        public DateTime ChannelDataLogTime { get; set; }
//        public decimal ChannelValue { get; set; }
//        public string ChannelName { get; set; }
//        public string LoggingUnits { get; set; }
//        public string StationName { get; set; }
//    }
//    public class ChannelDataReport
//    {
//        public DateTime ChannelDataLogTime { get; set; }
//        public Dictionary<string, string> DynamicColumns { get; set; }
//    }
//    public class DataFetcher 
//    { 
//        public static IEnumerable<ChannelDataRaw> GetRawChannelData(List<int> channelIds, DateTime fromDate, DateTime toDate)
//        {
//            string connectionString = System.Configuration.ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
//            using (IDbConnection db = new NpgsqlConnection(connectionString))
//            {
//                string query = @"
//                    SELECT cd.""ChannelDataLogTime"", cd.""ChannelValue"",
//                           c.""Name"" AS ChannelName, c.""LoggingUnits"", s.""Name"" AS StationName
//                    FROM public.""ChannelData"" cd
//                    JOIN public.""Channel"" c ON cd.""ChannelId"" = c.""Id""
//                    JOIN public.""Station"" s ON c.""StationId"" = s.""Id""
//                    WHERE cd.""ChannelId"" = ANY(@ChannelIds)
//                    AND cd.""ChannelDataLogTime"" BETWEEN @FromDate AND @ToDate
//                    ORDER BY cd.""ChannelDataLogTime"";";

//                return db.Query<ChannelDataRaw>(query, new { ChannelIds = channelIds, FromDate = fromDate, ToDate = toDate }).ToList();
//            }
//        }
//    }
//    public class DataTransformer
//    {
//        const int MaxRecordsAllowed = 15_000_000; // Limit based on experience
//        const long MaxMemoryUsageBytes = 1L * 1024 * 1024 * 1024; // 1 GB (Adjust based on available RAM)
//        const int EstimatedRowSizeBytes = 100; // Rough estimate

//        public static void ValidateQueryLimits(List<int> channelIds, DateTime fromDate, DateTime toDate)
//        {
//            int totalChannels = channelIds.Count;
//            int totalMinutes = (int)(toDate - fromDate).TotalMinutes;
//            long estimatedRecords = (long)totalChannels * totalMinutes;

//            // Estimate memory usage
//            long estimatedMemoryUsage = estimatedRecords * EstimatedRowSizeBytes;

//            // Check if records exceed allowed limit
//            if (estimatedRecords > MaxRecordsAllowed)
//            {
//                throw new DataLoadLimitExceededException($"System can't handle this many records: {estimatedRecords}");
//            }

//            if (estimatedMemoryUsage > MaxMemoryUsageBytes)
//            {
//                throw new DataLoadLimitExceededException($"Estimated memory usage ({estimatedMemoryUsage / (1024 * 1024)} MB) is too high.");
//            }
//        }
//        public static List<ChannelDataReport> TransformToChannelDataReport(List<ChannelDataRaw> rawData)
//        {
//            var groupedData = rawData
//                .GroupBy(cd => cd.ChannelDataLogTime)
//                .OrderBy(g => g.Key)
//                .ToList();

//            List<ChannelDataReport> reports = new List<ChannelDataReport>();

//            foreach (var group in groupedData)
//            {
//                var report = new ChannelDataReport
//                {
//                    ChannelDataLogTime = group.Key,
//                    DynamicColumns = new Dictionary<string, string>()
//                };

//                foreach (var data in group)
//                {
//                    string columnKey = $"{data.StationName}-{data.ChannelName}-{data.LoggingUnits}";
//                    report.DynamicColumns[columnKey] = data.ChannelValue.ToString();
//                }

//                reports.Add(report);
//            }

//            return reports;
//        }

//    }
//    public class DataLoadLimitExceededException : Exception
//    {
//        public DataLoadLimitExceededException(string message) : base(message)
//        {
//        }
//    }
//}


using Dapper;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Configuration;
using System.Text;
using Newtonsoft.Json;
using System.Text.Json;

namespace RepositoriesTest
{
    class Program
    {
        static void Main(string[] args)
        {
            var channelIds = new List<int> { 1, 2, 3, 4, 5, 6, 7, 8 };
            DateTime fromDate = new DateTime(2020, 01, 01, 00, 00, 00); // 5 years ago
            DateTime toDate = new DateTime(2024, 12, 31, 23, 59, 59);
            //DataTransformer.ValidateQueryLimits(channelIds, fromDate, toDate);

            var rawData = DataFetcher.GetRawChannelDataReports(channelIds, fromDate, toDate);
            //var dataReport = rawData.ToList();
            //foreach( var item in rawData)
            //{
            //    Console.WriteLine($"Logtime : {item.ChannelDataLogTime}");
            //    foreach( var values in item.DynamicColumns)
            //    {
            //        Console.WriteLine($"    {values.Key} : {values.Value}");
            //    }
            //}
            //var reportData = DataTransformer.TransformToChannelDataReport(rawData);
        }
    }

    public struct ChannelDataRaw // Consider struct
    {
        public DateTime ChannelDataLogTime { get; set; }
        public decimal ChannelValue { get; set; }
        public string ChannelName { get; set; }
        public string LoggingUnits { get; set; }
        public string StationName { get; set; }
    }

    public class ChannelDataReport
    {
        public DateTime ChannelDataLogTime { get; set; }
        public Dictionary<string, string> DynamicColumns { get; set; }
    }

    //public class DataFetcher
    //{
    //    public static IEnumerable<ChannelDataRaw> GetRawChannelData(List<int> channelIds, DateTime fromDate, DateTime toDate)
    //    {
    //        string connectionString = System.Configuration.ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
    //        using (IDbConnection db = new NpgsqlConnection(connectionString))
    //        {
    //            string query = @"
    //                SELECT cd.""ChannelDataLogTime"", cd.""ChannelValue"",
    //                       c.""Name"" AS ChannelName, c.""LoggingUnits"", s.""Name"" AS StationName
    //                FROM public.""ChannelData"" cd
    //                JOIN public.""Channel"" c ON cd.""ChannelId"" = c.""Id""
    //                JOIN public.""Station"" s ON c.""StationId"" = s.""Id""
    //                WHERE cd.""ChannelId"" = ANY(@ChannelIds)
    //                AND cd.""ChannelDataLogTime"" BETWEEN @FromDate AND @ToDate
    //                ORDER BY cd.""ChannelDataLogTime"";";

    //            return db.Query<ChannelDataRaw>(query, new { ChannelIds = channelIds, FromDate = fromDate, ToDate = toDate }); // No .ToList()
    //        }
    //    }
    //}
    public class DataFetcher
    {
        public static IEnumerable<ChannelDataReport> GetRawChannelDataReports(List<int> channelIds, DateTime fromDate, DateTime toDate)
        {
            string connectionString = System.Configuration.ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
            using (IDbConnection db = new NpgsqlConnection(connectionString))
            {
                string query = @"
                    SELECT
                        cd.""ChannelDataLogTime"",
                        jsonb_object_agg(
                            s.""Name"" || '-' || c.""Name"" || '-' || c.""LoggingUnits"",
                            cd.""ChannelValue""
                        ) AS ""DynamicColumns""
                    FROM
                        public.""ChannelData"" cd
                    JOIN
                        public.""Channel"" c ON cd.""ChannelId"" = c.""Id""
                    JOIN
                        public.""Station"" s ON c.""StationId"" = s.""Id""
                    WHERE
                        cd.""ChannelId"" = ANY(@ChannelIds)
                        AND cd.""ChannelDataLogTime"" BETWEEN @FromDate AND @ToDate
                    GROUP BY
                        cd.""ChannelDataLogTime""
                    ORDER BY
                        cd.""ChannelDataLogTime"";";

                var results = db.Query(query, new { ChannelIds = channelIds, FromDate = fromDate, ToDate = toDate });

                return results.Select(row => new ChannelDataReport
                {
                    ChannelDataLogTime = row.ChannelDataLogTime,
                    DynamicColumns = JsonConvert.DeserializeObject<Dictionary<string, string>>(row.DynamicColumns.ToString())
                });
            }
        }

        public static IEnumerable<ChannelDataReport> GetAvgChannelDataReports(List<int> channelIds, DateTime fromDate, DateTime toDate)
        {
            string connectionString = System.Configuration.ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
            using (IDbConnection db = new NpgsqlConnection(connectionString))
            {
                string query = @"
                    SELECT
                        cd.""ChannelDataLogTime"",
                        jsonb_object_agg(
                            s.""Name"" || '-' || c.""Name"" || '-' || c.""LoggingUnits"",
                            jsonb_build_object(
                                'Value', cd.""ChannelValue"",
                                'ChannelType', ct.""ChannelTypeValue""
                            )
                        ) AS ""DynamicColumns""
                    FROM
                        public.""ChannelData"" cd
                    JOIN
                        public.""Channel"" c ON cd.""ChannelId"" = c.""Id""
                    JOIN
                        public.""Station"" s ON c.""StationId"" = s.""Id""
                    LEFT JOIN
                        public.""ChannelType"" ct ON c.""ChannelTypeId"" = ct.""Id""
                    WHERE
                        cd.""ChannelId"" = ANY(@ChannelIds)
                        AND cd.""ChannelDataLogTime"" BETWEEN @FromDate AND @ToDate
                    GROUP BY
                        cd.""ChannelDataLogTime""
                    ORDER BY
                        cd.""ChannelDataLogTime"";
                ";

                var results = db.Query(query, new { ChannelIds = channelIds, FromDate = fromDate, ToDate = toDate });

                return results.Select(row => new ChannelDataReport
                {
                    ChannelDataLogTime = row.ChannelDataLogTime,
                    DynamicColumns = JsonConvert.DeserializeObject<Dictionary<string, JsonElement>>(row.DynamicColumns.ToString())
                });
            }
        }

        public static string GetChannelDataReportsJson(List<int> channelIds, DateTime fromDate, DateTime toDate)
        {
            string connectionString = System.Configuration.ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
            using (IDbConnection db = new NpgsqlConnection(connectionString))
            {
                string query = @"
                    SELECT
                        json_agg(
                            json_build_object(
                                'ChannelDataLogTime', cd.""ChannelDataLogTime"",
                                'DynamicColumns', jsonb_object_agg(
                                    s.""Name"" || '-' || c.""Name"" || '-' || c.""LoggingUnits"",
                                    jsonb_build_object(
                                        'Value', cd.""ChannelValue"",
                                        'ChannelType', ct.""ChannelTypeValue""
                                    )
                                )
                            )
                        ) AS ""ChannelDataReports""
                    FROM
                        public.""ChannelData"" cd
                    JOIN
                        public.""Channel"" c ON cd.""ChannelId"" = c.""Id""
                    JOIN
                        public.""Station"" s ON c.""StationId"" = s.""Id""
                    LEFT JOIN
                        public.""ChannelType"" ct ON c.""ChannelTypeId"" = ct.""Id""
                    WHERE
                        cd.""ChannelId"" = ANY(@ChannelIds)
                        AND cd.""ChannelDataLogTime"" BETWEEN @FromDate AND @ToDate
                    GROUP BY
                        cd.""ChannelDataLogTime""
                    ORDER BY
                        cd.""ChannelDataLogTime"";";

                return db.QuerySingle<string>(query, new { ChannelIds = channelIds, FromDate = fromDate, ToDate = toDate });
            }
        }
    }

    public class DataTransformer
    {
        //const int MaxRecordsAllowed = 25_000_000;
        //const long MaxMemoryUsageBytes = 25000000 * 1024 * 1024 * 1024;
        //const int EstimatedRowSizeBytes = 100;

        //public static void ValidateQueryLimits(List<int> channelIds, DateTime fromDate, DateTime toDate)
        //{
        //    int totalChannels = channelIds.Count;
        //    int totalMinutes = (int)(toDate - fromDate).TotalMinutes;
        //    long estimatedRecords = (long)totalChannels * totalMinutes;

        //    long estimatedMemoryUsage = estimatedRecords * EstimatedRowSizeBytes;

        //    if (estimatedRecords > MaxRecordsAllowed)
        //    {
        //        throw new DataLoadLimitExceededException($"System can't handle this many records: {estimatedRecords}");
        //    }

        //    if (estimatedMemoryUsage > MaxMemoryUsageBytes)
        //    {
        //        throw new DataLoadLimitExceededException($"Estimated memory usage ({estimatedMemoryUsage / (1024 * 1024)} MB) is too high.");
        //    }
        //}

        public static List<ChannelDataReport> TransformToChannelDataReport(IEnumerable<ChannelDataRaw> rawData)
        {
            var groupedData = rawData
                .GroupBy(cd => cd.ChannelDataLogTime)
                .OrderBy(g => g.Key)
                .ToList(); // Materialize the grouped data into a list

            List<ChannelDataReport> reports = new List<ChannelDataReport>();

            foreach (var group in groupedData)
            {
                var report = new ChannelDataReport
                {
                    ChannelDataLogTime = group.Key,
                    DynamicColumns = new Dictionary<string, string>()
                };

                foreach (var data in group)
                {
                    StringBuilder columnKeyBuilder = new StringBuilder();
                    columnKeyBuilder.Append(data.StationName).Append("-").Append(data.ChannelName).Append("-").Append(data.LoggingUnits);
                    string columnKey = columnKeyBuilder.ToString();
                    report.DynamicColumns[columnKey] = data.ChannelValue.ToString();
                }

                reports.Add(report);
            }

            return reports; // Return the entire list
        }
    }

    public class DataLoadLimitExceededException : Exception
    {
        public DataLoadLimitExceededException(string message) : base(message)
        {
        }
    }
}
