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

        public DataTable GetChannelDataAvailabilityReportAsDataTable(List<int> channelIds, DateTime From, DateTime To)
        {
            using (var conn = new NpgsqlConnection(_connectionString))
            {
                conn.Open();

                // Query the PostgreSQL function
                //    var query = @"
                //SELECT * 
                //FROM public.""GetRawChannelDataReport""(@StartTime, @EndTime, @ChannelIds)";
                var query = @"
            SELECT * 
            FROM public.""GetChannelDataAvailabilityReport""(@StartTime, @EndTime, @ChannelIds)";

                using (var cmd = new NpgsqlCommand(query, conn))
                {
                    cmd.Parameters.AddWithValue("StartTime", From);
                    cmd.Parameters.AddWithValue("EndTime", To);
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


        public DataTable GetRawChannelDataReportAsDataTable(List<int> channelIds, DateTime from, DateTime to)
        {
            using (var conn = new NpgsqlConnection(_connectionString))
            {
                conn.Open();

                // Query the PostgreSQL function
                //    var query = @"
                //SELECT * 
                //FROM public.""GetRawChannelDataReport""(@StartTime, @EndTime, @ChannelIds)";
                var query = @"
            SELECT * 
            FROM public.""GetRawChannelDataReport""(@StartTime, @EndTime, @ChannelIds)";

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
        public DataTable GetAvgChannelDataReportAsDataTable(List<int> channelIds, DateTime from, DateTime to, int interval)
        {
            using (var conn = new NpgsqlConnection(_connectionString))
            {
                conn.Open();

                // Query the PostgreSQL function
                //    var query = @"
                //SELECT * 
                //FROM public.""GetRawChannelDataReport""(@StartTime, @EndTime, @ChannelIds)";
                var query = @"
            SELECT * 
            FROM public.""GetRawChannelDataReport_v3""(@StartTime, @EndTime, @ChannelIds)";

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
                        DataTable aggregatedData = AggregateReportDataTable(dataTable, TimeSpan.FromMinutes(interval));
                        return aggregatedData;
                    }
                }
            }
        }
        //public static DataTable AggregateReportDataTable(DataTable inputDataTable, TimeSpan interval)
        //{
        //    if (inputDataTable == null || inputDataTable.Rows.Count == 0)
        //    {
        //        return new DataTable();
        //    }

        //    DataTable aggregatedTable = new DataTable();
        //    aggregatedTable.Columns.Add("ChannelDataLogTime", typeof(DateTime));
        //    aggregatedTable.Columns.Add("dynamic_columns", typeof(string));

        //    var groupedRows = inputDataTable.AsEnumerable()
        //        .GroupBy(row =>
        //        {
        //            DateTime logTime = Convert.ToDateTime(row["ChannelDataLogTime"]);
        //            long intervalTicks = interval.Ticks;
        //            long logTimeTicks = logTime.Ticks;
        //            long groupKeyTicks = (logTimeTicks / intervalTicks) * intervalTicks;
        //            return new DateTime(groupKeyTicks);
        //        });

        //    foreach (var group in groupedRows)
        //    {
        //        DataRow newRow = aggregatedTable.NewRow();
        //        newRow["ChannelDataLogTime"] = group.Key;

        //        var aggregatedData = new JObject();

        //        var channelNames = new HashSet<string>();
        //        foreach (var row in group)
        //        {
        //            var dynamicColumns = JObject.Parse(row["dynamic_columns"].ToString());
        //            foreach (var property in dynamicColumns.Properties())
        //            {
        //                channelNames.Add(property.Name);
        //            }
        //        }

        //        foreach (var channelName in channelNames)
        //        {
        //            var channelValues = new List<double>();

        //            foreach (var row in group)
        //            {
        //                var dynamicColumns = JObject.Parse(row["dynamic_columns"].ToString());
        //                if (dynamicColumns.ContainsKey(channelName) && dynamicColumns[channelName].Type != JTokenType.Null && dynamicColumns[channelName].ToString() != "NA")
        //                {
        //                    if (double.TryParse(dynamicColumns[channelName].ToString(), out double value))
        //                    {
        //                        channelValues.Add(value);
        //                    }
        //                }
        //            }

        //            if (channelValues.Any())
        //            {
        //                double average = channelValues.Average();
        //                average = Math.Round(average, 2); // Round to 2 decimal places
        //                aggregatedData[channelName] = average;
        //            }
        //            else
        //            {
        //                aggregatedData[channelName] = null;
        //            }
        //        }

        //        newRow["dynamic_columns"] = aggregatedData.ToString(Formatting.None);
        //        aggregatedTable.Rows.Add(newRow);
        //    }

        //    return aggregatedTable;
        //}

        //new with limit and type property 
        public static DataTable AggregateReportDataTable(DataTable inputDataTable, TimeSpan interval)
        {
            if (inputDataTable == null || inputDataTable.Rows.Count == 0)
            {
                return new DataTable();
            }

            DataTable aggregatedTable = new DataTable();
            aggregatedTable.Columns.Add("ChannelDataLogTime", typeof(DateTime));
            aggregatedTable.Columns.Add("dynamic_columns", typeof(string));

            var groupedRows = inputDataTable.AsEnumerable()
                .GroupBy(row =>
                {
                    DateTime logTime = Convert.ToDateTime(row["ChannelDataLogTime"]);
                    long intervalTicks = interval.Ticks;
                    long logTimeTicks = logTime.Ticks;
                    long groupKeyTicks = (logTimeTicks / intervalTicks) * intervalTicks;
                    return new DateTime(groupKeyTicks);
                });

            foreach (var group in groupedRows)
            {
                DataRow newRow = aggregatedTable.NewRow();
                newRow["ChannelDataLogTime"] = group.Key;

                var aggregatedData = new JObject();

                var channelNames = new HashSet<string>();
                foreach (var row in group)
                {
                    var dynamicColumns = JObject.Parse(row["dynamic_columns"].ToString());
                    foreach (var property in dynamicColumns.Properties())
                    {
                        channelNames.Add(property.Name);
                    }
                }

                foreach (var channelName in channelNames)
                {
                    var channelValues = new List<double>();
                    string channelType = null; // Store the channel type for this channelName

                    foreach (var row in group)
                    {
                        var dynamicColumns = JObject.Parse(row["dynamic_columns"].ToString());
                        if (dynamicColumns.ContainsKey(channelName))
                        {
                            var channelData = dynamicColumns[channelName];
                            if (channelData["value"] != null && channelData["value"].Type != JTokenType.Null && channelData["value"].ToString() != "NA")
                            {
                                if (double.TryParse(channelData["value"].ToString(), out double value))
                                {
                                    channelValues.Add(value);
                                }
                            }

                            if (channelType == null && channelData["Type"] != null) // Get Channel Type only once per channel
                            {
                                channelType = channelData["Type"].ToString();
                            }
                        }
                    }

                    if (channelValues.Any())
                    {
                        double aggregatedValue = 0;

                        switch (channelType?.ToUpper()) // Use the null-conditional operator and ToUpper for case-insensitive comparison
                        {
                            case "VECTOR":
                                aggregatedValue = Math.Round(channelValues.Average(v => Math.Sin(Radians(v))), 2);
                                break;
                            case "TOTAL":
                                aggregatedValue = Math.Round(channelValues.Max() - channelValues.Min(), 2);
                                break;
                            case "FLOW":
                                aggregatedValue = Math.Round(channelValues.Sum(), 2);
                                break;
                            default: // Default case (including null channelType)
                                aggregatedValue = Math.Round(channelValues.Average(), 2);
                                break;
                        }
                        aggregatedData[channelName] = aggregatedValue;
                    }
                    else
                    {
                        aggregatedData[channelName] = null;
                    }
                }

                newRow["dynamic_columns"] = aggregatedData.ToString(Formatting.None);
                aggregatedTable.Rows.Add(newRow);
            }

            return aggregatedTable;
        }
        public DataTable GetRawChannelDataExceedanceReportAsDataTable(List<int> channelIds, DateTime From, DateTime To)
        {
            using (var conn = new NpgsqlConnection(_connectionString))
            {
                conn.Open();

                // Query the PostgreSQL function
                //    var query = @"
                //SELECT * 
                //FROM public.""GetRawChannelDataReport""(@StartTime, @EndTime, @ChannelIds)";
                var query = @"
            SELECT * 
            FROM public.""GetRawChannelDataExceedanceReport""(@StartTime, @EndTime, @ChannelIds)";

                using (var cmd = new NpgsqlCommand(query, conn))
                {
                    cmd.Parameters.AddWithValue("StartTime", From);
                    cmd.Parameters.AddWithValue("EndTime", To);
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
        public DataTable GetAvgChannelDataExceedanceReportAsDataTable(List<int> channelIds, DateTime from, DateTime to, int interval)
        {
            using (var conn = new NpgsqlConnection(_connectionString))
            {
                conn.Open();

                // Query the PostgreSQL function
                //    var query = @"
                //SELECT * 
                //FROM public.""GetRawChannelDataReport""(@StartTime, @EndTime, @ChannelIds)";
                var query = @"
            SELECT * 
            FROM public.""GetRawChannelDataExceedanceReport_v2""(@StartTime, @EndTime, @ChannelIds)";

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
                        DataTable aggregatedData = AggregateExceedanceDataTable(dataTable, TimeSpan.FromMinutes(interval));
                        return aggregatedData;
                    }
                }
            }
        }
        //public static DataTable AggregateExceedanceDataTable(DataTable inputDataTable, TimeSpan interval)
        //{
        //    if (inputDataTable == null || inputDataTable.Rows.Count == 0)
        //    {
        //        return new DataTable();
        //    }

        //    DataTable aggregatedTable = new DataTable();
        //    aggregatedTable.Columns.Add("ChannelDataLogTime", typeof(DateTime));
        //    aggregatedTable.Columns.Add("dynamic_columns", typeof(string));

        //    var groupedRows = inputDataTable.AsEnumerable()
        //        .GroupBy(row =>
        //        {
        //            DateTime logTime = Convert.ToDateTime(row["ChannelDataLogTime"]);
        //            long intervalTicks = interval.Ticks;
        //            long logTimeTicks = logTime.Ticks;
        //            long groupKeyTicks = (logTimeTicks / intervalTicks) * intervalTicks;
        //            return new DateTime(groupKeyTicks);
        //        });

        //    foreach (var group in groupedRows)
        //    {
        //        DataRow newRow = aggregatedTable.NewRow();
        //        newRow["ChannelDataLogTime"] = group.Key;

        //        var aggregatedData = new JObject();

        //        var channelNames = new HashSet<string>();
        //        foreach (var row in group)
        //        {
        //            var dynamicColumns = JObject.Parse(row["dynamic_columns"].ToString());
        //            foreach (var property in dynamicColumns.Properties())
        //            {
        //                channelNames.Add(property.Name);
        //            }
        //        }

        //        foreach (var channelName in channelNames)
        //        {
        //            var channelValues = new List<double>();
        //            var exceedanceCounts = 0;
        //            var totalCounts = 0;

        //            foreach (var row in group)
        //            {
        //                var dynamicColumns = JObject.Parse(row["dynamic_columns"].ToString());
        //                if (dynamicColumns.ContainsKey(channelName) && dynamicColumns[channelName].Type == JTokenType.Object)
        //                {
        //                    var channelData = (JObject)dynamicColumns[channelName];
        //                    if (channelData.ContainsKey("value") && channelData.ContainsKey("Exceeded"))
        //                    {
        //                        if (double.TryParse(channelData["value"].ToString(), out double value))
        //                        {
        //                            channelValues.Add(value);
        //                        }
        //                        if (channelData["Exceeded"].ToObject<bool>())
        //                        {
        //                            exceedanceCounts++;
        //                        }
        //                        totalCounts++;
        //                    }
        //                }
        //            }

        //            if (totalCounts > 0)
        //            {
        //                var channelObject = new JObject();
        //                if (channelValues.Any())
        //                {
        //                    double average = channelValues.Average();
        //                    average = Math.Round(average, 2);
        //                    channelObject["average_value"] = average;
        //                }
        //                else
        //                {
        //                    channelObject["average_value"] = null;
        //                }
        //                channelObject["exceedance_percentage"] = Math.Round((double)exceedanceCounts / totalCounts * 100, 2);
        //                aggregatedData[channelName] = channelObject;
        //            }
        //            else
        //            {
        //                aggregatedData[channelName] = null;
        //            }
        //        }

        //        newRow["dynamic_columns"] = aggregatedData.ToString(Formatting.None);
        //        aggregatedTable.Rows.Add(newRow);
        //    }

        //    return aggregatedTable;
        //}

        //new with limit property and type property
        public static DataTable AggregateExceedanceDataTable(DataTable inputDataTable, TimeSpan interval)
        {
            if (inputDataTable == null || inputDataTable.Rows.Count == 0)
            {
                return new DataTable();
            }

            DataTable aggregatedTable = new DataTable();
            aggregatedTable.Columns.Add("ChannelDataLogTime", typeof(DateTime));
            aggregatedTable.Columns.Add("dynamic_columns", typeof(string));

            var groupedRows = inputDataTable.AsEnumerable()
                .GroupBy(row =>
                {
                    DateTime logTime = Convert.ToDateTime(row["ChannelDataLogTime"]);
                    long intervalTicks = interval.Ticks;
                    long logTimeTicks = logTime.Ticks;
                    long groupKeyTicks = (logTimeTicks / intervalTicks) * intervalTicks;
                    return new DateTime(groupKeyTicks);
                });

            foreach (var group in groupedRows)
            {
                DataRow newRow = aggregatedTable.NewRow();
                newRow["ChannelDataLogTime"] = group.Key;

                var aggregatedData = new JObject();

                var channelNames = new HashSet<string>();
                foreach (var row in group)
                {
                    var dynamicColumns = JObject.Parse(row["dynamic_columns"].ToString());
                    foreach (var property in dynamicColumns.Properties())
                    {
                        channelNames.Add(property.Name);
                    }
                }

                foreach (var channelName in channelNames)
                {
                    var channelValues = new List<double>();
                    double limit = double.NaN;
                    string channelType = null;
                    bool exceeded = false;

                    foreach (var row in group)
                    {
                        var dynamicColumns = JObject.Parse(row["dynamic_columns"].ToString());
                        if (dynamicColumns.ContainsKey(channelName) && dynamicColumns[channelName].Type == JTokenType.Object)
                        {
                            var channelData = (JObject)dynamicColumns[channelName];
                            if (channelData.ContainsKey("value") && channelData.ContainsKey("Limit") && channelData.ContainsKey("Type"))
                            {
                                if (double.TryParse(channelData["value"].ToString(), out double value))
                                {
                                    channelValues.Add(value);
                                }

                                if (double.TryParse(channelData["Limit"].ToString(), out double l))
                                {
                                    limit = l;
                                }
                                channelType = channelData["Type"].ToString(); // Get Channel Type
                            }
                        }
                    }

                    if (channelValues.Any() && !double.IsNaN(limit) && channelType != null)
                    {
                        double aggregatedValue = 0;

                        switch (channelType.ToUpper())
                        {
                            case "VECTOR":
                                aggregatedValue = Math.Round(channelValues.Average(v => Math.Sin(Radians(v))), 2);
                                break;
                            case "TOTAL":
                                aggregatedValue = Math.Round(channelValues.Max() - channelValues.Min(), 2);
                                break;
                            case "FLOW":
                                aggregatedValue = Math.Round(channelValues.Sum(), 2);
                                break;
                            default:
                                aggregatedValue = Math.Round(channelValues.Average(), 2);
                                break;
                        }

                        exceeded = aggregatedValue > limit;

                        var channelObject = new JObject();
                        channelObject["value"] = aggregatedValue; // Store the correctly aggregated value
                        channelObject["Exceeded"] = exceeded;

                        aggregatedData[channelName] = channelObject;
                    }
                    else
                    {
                        aggregatedData[channelName] = null;
                    }
                }

                newRow["dynamic_columns"] = aggregatedData.ToString(Formatting.None);
                aggregatedTable.Rows.Add(newRow);
            }

            return aggregatedTable;
        }
        private static double Radians(double degrees)
        {
            return degrees * Math.PI / 180;
        }



        //public DataTable GetAvgChannelDataReportAsDataTable(List<int> channelIds, DateTime from, DateTime to, int interval)
        //{
        //    using (var conn = new NpgsqlConnection(_connectionString))
        //    {
        //        conn.Open();

        //        // Query the PostgreSQL function GetAggregatedChannelDataWithIds
        //    //    var query = @"
        //    //SELECT * 
        //    //FROM public.""GetAvgChannelDataReport""(@StartTime, @EndTime, @ChannelIds, @IntervalMinutes)";

        //        var query = @"
        //    SELECT * 
        //    FROM public.""GetAvgChannelDataReport""(@StartTime, @EndTime,@ChannelIds, @IntervalMinutes)";

        //        using (var cmd = new NpgsqlCommand(query, conn))
        //        {
        //            //cmd.CommandTimeout = 300;

        //            // Add the parameters required for the function
        //            cmd.Parameters.AddWithValue("StartTime", from);
        //            cmd.Parameters.AddWithValue("EndTime", to);
        //            cmd.Parameters.AddWithValue("ChannelIds", channelIds.ToArray());
        //            cmd.Parameters.AddWithValue("IntervalMinutes", interval);

        //            // Use NpgsqlDataAdapter to fill a DataTable
        //            using (var adapter = new NpgsqlDataAdapter(cmd))
        //            {
        //                var dataTable = new DataTable();
        //                adapter.Fill(dataTable);
        //                return dataTable;
        //            }
        //        }
        //    }
        //}
    }
}
