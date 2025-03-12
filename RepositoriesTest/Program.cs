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
using System.Data.SqlClient;
using System.IO;
using System.Xml;

namespace RepositoriesTest
{
    class Program
    {
        static void Main(string[] args)
        {
            string connectionString = @"Data Source=BHANU\BHANU;Initial Catalog=MSSQLNKSS;Integrated Security=False;uid=sa;pwd=nkss@123;";

            

            // Step 1: Fetch the data for all tables using a single query
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

            //using (SqlConnection conn = new SqlConnection(connectionString))
            //{
            //    SqlDataAdapter dataAdapter = new SqlDataAdapter(query, conn);
            //    DataSet dataSet = new DataSet();
            //    dataAdapter.Fill(dataSet);

            //    // Step 2: Create an XmlDocument to hold the XML data
            //    XmlDocument xmlDoc = new XmlDocument();

            //    // Create the root element <Configuration>
            //    XmlElement rootElement = xmlDoc.CreateElement("Configuration");
            //    xmlDoc.AppendChild(rootElement);

            //    // Step 3: Build <Companies> and nested elements
            //    XmlElement companiesElement = xmlDoc.CreateElement("Companies");
            //    rootElement.AppendChild(companiesElement);

            //    foreach (DataRow companyRow in dataSet.Tables[0].Rows)
            //    {
            //        XmlElement companyElement = xmlDoc.CreateElement("Company");
            //        companiesElement.AppendChild(companyElement);

            //        // Add company fields
            //        foreach (DataColumn column in dataSet.Tables[0].Columns)
            //        {
            //            XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //            fieldElement.InnerText = companyRow[column]?.ToString() ?? "";
            //            companyElement.AppendChild(fieldElement);
            //        }

            //        // Step 4: Add <Stations> for each company
            //        XmlElement stationsElement = xmlDoc.CreateElement("Stations");
            //        companyElement.AppendChild(stationsElement);

            //        foreach (DataRow stationRow in dataSet.Tables[1].Rows)
            //        {
            //            if (stationRow.Field<int>("CompanyId") == companyRow.Field<int>("Id"))
            //            {
            //                XmlElement stationElement = xmlDoc.CreateElement("Station");
            //                stationsElement.AppendChild(stationElement);

            //                // Add station fields
            //                foreach (DataColumn column in dataSet.Tables[1].Columns)
            //                {
            //                    XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //                    fieldElement.InnerText = stationRow[column]?.ToString() ?? "";
            //                    stationElement.AppendChild(fieldElement);
            //                }

            //                // Step 5: Add <MonitoringType> for each station
            //                XmlElement monitoringTypeElement = xmlDoc.CreateElement("MonitoringType");
            //                stationElement.AppendChild(monitoringTypeElement);

            //                var monitoringTypeRow = dataSet.Tables[3].AsEnumerable()
            //                    .FirstOrDefault(r => r.Field<int>("Id") == stationRow.Field<int>("MonitoringTypeId"));
            //                if (monitoringTypeRow != null)
            //                {
            //                    foreach (DataColumn column in dataSet.Tables[3].Columns)
            //                    {
            //                        XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //                        fieldElement.InnerText = monitoringTypeRow[column]?.ToString() ?? "";
            //                        monitoringTypeElement.AppendChild(fieldElement);
            //                    }
            //                }

            //                // Step 6: Add <Channels> for each station
            //                XmlElement channelsElement = xmlDoc.CreateElement("Channels");
            //                stationElement.AppendChild(channelsElement);

            //                foreach (DataRow channelRow in dataSet.Tables[2].Rows)
            //                {
            //                    if (channelRow.Field<int>("StationId") == stationRow.Field<int>("Id"))
            //                    {
            //                        XmlElement channelElement = xmlDoc.CreateElement("Channel");
            //                        channelsElement.AppendChild(channelElement);

            //                        // Add channel fields
            //                        foreach (DataColumn column in dataSet.Tables[2].Columns)
            //                        {
            //                            XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //                            fieldElement.InnerText = channelRow[column]?.ToString() ?? "";
            //                            channelElement.AppendChild(fieldElement);
            //                        }

            //                        // Step 7: Add <Analyzer> for each channel
            //                        XmlElement analyzerElement = xmlDoc.CreateElement("Analyzer");
            //                        channelElement.AppendChild(analyzerElement);

            //                        var analyzerRow = dataSet.Tables[6].AsEnumerable()
            //                            .FirstOrDefault(r => r.Field<int>("Id") == channelRow.Field<int>("ProtocolId"));
            //                        if (analyzerRow != null)
            //                        {
            //                            foreach (DataColumn column in dataSet.Tables[6].Columns)
            //                            {
            //                                XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //                                fieldElement.InnerText = analyzerRow[column]?.ToString() ?? "";
            //                                analyzerElement.AppendChild(fieldElement);
            //                            }
            //                        }
            //                        else
            //                        {
            //                            analyzerElement.InnerText = "[]"; // No analyzer data found
            //                        }

            //                        // Step 8: Add <Oxide> for each channel
            //                        XmlElement oxideElement = xmlDoc.CreateElement("Oxide");
            //                        channelElement.AppendChild(oxideElement);

            //                        var oxideRow = dataSet.Tables[5].AsEnumerable()
            //                            .FirstOrDefault(r => r.Field<int>("Id") == channelRow.Field<int>("OxideId"));
            //                        if (oxideRow != null)
            //                        {
            //                            foreach (DataColumn column in dataSet.Tables[5].Columns)
            //                            {
            //                                XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //                                fieldElement.InnerText = oxideRow[column]?.ToString() ?? "";
            //                                oxideElement.AppendChild(fieldElement);
            //                            }
            //                        }
            //                        else
            //                        {
            //                            oxideElement.InnerText = "[]"; // No oxide data found
            //                        }

            //                        // Step 9: Add <ChannelType> for each channel
            //                        XmlElement channelTypeElement = xmlDoc.CreateElement("ChannelType");
            //                        channelElement.AppendChild(channelTypeElement);

            //                        var channelTypeRow = dataSet.Tables[4].AsEnumerable()
            //                            .FirstOrDefault(r => r.Field<int>("Id") == channelRow.Field<int>("ChannelTypeId"));
            //                        if (channelTypeRow != null)
            //                        {
            //                            foreach (DataColumn column in dataSet.Tables[4].Columns)
            //                            {
            //                                XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //                                fieldElement.InnerText = channelTypeRow[column]?.ToString() ?? "";
            //                                channelTypeElement.AppendChild(fieldElement);
            //                            }
            //                        }
            //                        else
            //                        {
            //                            channelTypeElement.InnerText = "[]"; // No channel type data found
            //                        }

            //                        // Step 10: Add <ScalingFactor> for each channel
            //                        XmlElement scalingFactorElement = xmlDoc.CreateElement("ScalingFactor");
            //                        channelElement.AppendChild(scalingFactorElement);

            //                        var scalingFactorRow = dataSet.Tables[7].AsEnumerable()
            //                            .FirstOrDefault(r => r.Field<int>("Id") == channelRow.Field<int>("ScalingFactorId"));
            //                        if (scalingFactorRow != null)
            //                        {
            //                            foreach (DataColumn column in dataSet.Tables[7].Columns)
            //                            {
            //                                XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //                                fieldElement.InnerText = scalingFactorRow[column]?.ToString() ?? "";
            //                                scalingFactorElement.AppendChild(fieldElement);
            //                            }
            //                        }
            //                        else
            //                        {
            //                            scalingFactorElement.InnerText = "[]"; // No scaling factor data found
            //                        }
            //                    }
            //                }
            //            }
            //        }

            //        // Step 11: Add <Licenses> section
            //        XmlElement licensesElement = xmlDoc.CreateElement("Licenses");
            //        rootElement.AppendChild(licensesElement);

            //        foreach (DataRow licenseRow in dataSet.Tables[8].Rows)
            //        {
            //            XmlElement licenseElement = xmlDoc.CreateElement("License");
            //            licensesElement.AppendChild(licenseElement);

            //            foreach (DataColumn column in dataSet.Tables[8].Columns)
            //            {
            //                XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //                fieldElement.InnerText = licenseRow[column]?.ToString() ?? "";
            //                licenseElement.AppendChild(fieldElement);
            //            }
            //        }

            //        // Step 12: Add <ConfigSettings> section
            //        XmlElement configSettingsElement = xmlDoc.CreateElement("ConfigSettings");
            //        rootElement.AppendChild(configSettingsElement);

            //                XmlElement configSettingElement = xmlDoc.CreateElement("ConfigSetting");
            //        foreach (DataRow configSettingRow in dataSet.Tables[9].Rows)
            //        {
            //            if (configSettingRow != null)
            //            {
            //                configSettingsElement.AppendChild(configSettingElement);

            //                foreach (DataColumn column in dataSet.Tables[9].Columns)
            //                {
            //                    XmlElement fieldElement = xmlDoc.CreateElement(column.ColumnName);
            //                    fieldElement.InnerText = configSettingRow[column]?.ToString() ?? "";
            //                    configSettingElement.AppendChild(fieldElement);
            //                }
            //            }
            //            else
            //            {
            //                configSettingElement.InnerText = "[]"; // No scaling factor data found
            //            }


            //        }

            //        // Step 13: Save XML to file
            //        xmlDoc.Save("configuration.xml");
            //    }
            //}

            using (SqlConnection conn = new SqlConnection(connectionString))
            {
                SqlDataAdapter dataAdapter = new SqlDataAdapter(query, conn);
                DataSet dataSet = new DataSet();
                dataAdapter.Fill(dataSet);

                // Create the structure for the JSON
                var configuration = new Dictionary<string, object>
        {
            { "Configuration", new Dictionary<string, object>() }
        };

                var configurationElement = (Dictionary<string, object>)configuration["Configuration"];

                // Create companies section
                var companies = new List<Dictionary<string, object>>();
                foreach (DataRow companyRow in dataSet.Tables[0].Rows)
                {
                    var companyElement = new Dictionary<string, object>();

                    // Add company fields with correct types
                    foreach (DataColumn column in dataSet.Tables[0].Columns)
                    {
                        companyElement[column.ColumnName] = ConvertValueBasedOnType(companyRow[column], column.DataType);
                    }

                    // Stations for the company
                    var stations = new List<Dictionary<string, object>>();
                    foreach (DataRow stationRow in dataSet.Tables[1].Rows)
                    {
                        if (stationRow.Field<int>("CompanyId") == companyRow.Field<int>("Id"))
                        {
                            var stationElement = new Dictionary<string, object>();

                            // Add station fields with correct types
                            foreach (DataColumn column in dataSet.Tables[1].Columns)
                            {
                                stationElement[column.ColumnName] = ConvertValueBasedOnType(stationRow[column], column.DataType);
                            }

                            // MonitoringType for the station
                            var monitoringTypes = new List<Dictionary<string, object>>();
                            foreach (DataRow monitoringTypeRow in dataSet.Tables[3].Rows)
                            {
                                if (monitoringTypeRow.Field<int>("Id") == stationRow.Field<int>("MonitoringTypeId"))
                                {
                                    var monitoringTypeElement = new Dictionary<string, object>();
                                    foreach (DataColumn column in dataSet.Tables[3].Columns)
                                    {
                                        monitoringTypeElement[column.ColumnName] = ConvertValueBasedOnType(monitoringTypeRow[column], column.DataType);
                                    }
                                    monitoringTypes.Add(monitoringTypeElement);
                                }
                            }
                            stationElement["MonitoringType"] = monitoringTypes;

                            // Channels for the station
                            var channels = new List<Dictionary<string, object>>();
                            foreach (DataRow channelRow in dataSet.Tables[2].Rows)
                            {
                                if (channelRow.Field<int>("StationId") == stationRow.Field<int>("Id"))
                                {
                                    var channelElement = new Dictionary<string, object>();

                                    // Add channel fields with correct types
                                    foreach (DataColumn column in dataSet.Tables[2].Columns)
                                    {
                                        channelElement[column.ColumnName] = ConvertValueBasedOnType(channelRow[column], column.DataType);
                                    }

                                    // Analyzer for the channel
                                    var analyzers = new List<Dictionary<string, object>>();
                                    foreach (DataRow analyzerRow in dataSet.Tables[6].Rows)
                                    {
                                        if (analyzerRow.Field<int>("Id") == channelRow.Field<int>("ProtocolId"))
                                        {
                                            var analyzerElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[6].Columns)
                                            {
                                                analyzerElement[column.ColumnName] = ConvertValueBasedOnType(analyzerRow[column], column.DataType);
                                            }
                                            analyzers.Add(analyzerElement);
                                        }
                                    }
                                    channelElement["Analyzer"] = analyzers;

                                    // Oxide for the channel
                                    var oxides = new List<Dictionary<string, object>>();
                                    foreach (DataRow oxideRow in dataSet.Tables[5].Rows)
                                    {
                                        if (oxideRow.Field<int>("Id") == channelRow.Field<int>("OxideId"))
                                        {
                                            var oxideElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[5].Columns)
                                            {
                                                oxideElement[column.ColumnName] = ConvertValueBasedOnType(oxideRow[column], column.DataType);
                                            }
                                            oxides.Add(oxideElement);
                                        }
                                    }
                                    channelElement["Oxide"] = oxides;

                                    // ChannelType for the channel
                                    var channelTypes = new List<Dictionary<string, object>>();
                                    foreach (DataRow channelTypeRow in dataSet.Tables[4].Rows)
                                    {
                                        if (channelTypeRow.Field<int>("Id") == channelRow.Field<int>("ChannelTypeId"))
                                        {
                                            var channelTypeElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[4].Columns)
                                            {
                                                channelTypeElement[column.ColumnName] = ConvertValueBasedOnType(channelTypeRow[column], column.DataType);
                                            }
                                            channelTypes.Add(channelTypeElement);
                                        }
                                    }
                                    channelElement["ChannelType"] = channelTypes;

                                    // ScalingFactor for the channel
                                    var scalingFactors = new List<Dictionary<string, object>>();
                                    foreach (DataRow scalingFactorRow in dataSet.Tables[7].Rows)
                                    {
                                        if (scalingFactorRow.Field<int>("Id") == channelRow.Field<int>("ScalingFactorId"))
                                        {
                                            var scalingFactorElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[7].Columns)
                                            {
                                                scalingFactorElement[column.ColumnName] = ConvertValueBasedOnType(scalingFactorRow[column], column.DataType);
                                            }
                                            scalingFactors.Add(scalingFactorElement);
                                        }
                                    }
                                    channelElement["ScalingFactor"] = scalingFactors;

                                    channels.Add(channelElement);
                                }
                            }
                            stationElement["Channels"] = channels;

                            stations.Add(stationElement);
                        }
                    }
                    companyElement["Stations"] = stations;

                    companies.Add(companyElement);
                }
                configurationElement["Companies"] = companies;

                // Licenses section
                var licenses = new List<Dictionary<string, object>>();
                foreach (DataRow licenseRow in dataSet.Tables[8].Rows)
                {
                    var licenseElement = new Dictionary<string, object>();
                    foreach (DataColumn column in dataSet.Tables[8].Columns)
                    {
                        licenseElement[column.ColumnName] = ConvertValueBasedOnType(licenseRow[column], column.DataType);
                    }
                    licenses.Add(licenseElement);
                }
                configurationElement["Licenses"] = licenses;

                // ConfigSettings section
                var configSettings = new List<Dictionary<string, object>>();
                foreach (DataRow configSettingRow in dataSet.Tables[9].Rows)
                {
                    var configSettingElement = new Dictionary<string, object>();
                    foreach (DataColumn column in dataSet.Tables[9].Columns)
                    {
                        configSettingElement[column.ColumnName] = ConvertValueBasedOnType(configSettingRow[column], column.DataType);
                    }
                    configSettings.Add(configSettingElement);
                }
                configurationElement["ConfigSettings"] = configSettings;

                // Convert to JSON string
                string json = JsonConvert.SerializeObject(configuration, Newtonsoft.Json.Formatting.Indented);

                // Output or save the JSON string
                Console.WriteLine(json);
            }

        }
        private static object ConvertValueBasedOnType(object value, Type type)
        {
            if (value == DBNull.Value)
                return null;

            if (type == typeof(int) || type == typeof(long) || type == typeof(short))
                return Convert.ToInt64(value);

            if (type == typeof(decimal) || type == typeof(float) || type == typeof(double))
                return Convert.ToDecimal(value);

            if (type == typeof(DateTime))
                return Convert.ToDateTime(value).ToString("yyyy-MM-ddTHH:mm:ss");

            if (type == typeof(bool))
                return Convert.ToBoolean(value);

            return value.ToString(); // Default to string if no other match
        }
        private static object BuildCompanyData(DataTable companiesTable, DataTable stationsTable, DataTable channelsTable, DataTable monitoringTypesTable, DataTable channelTypesTable, DataTable oxidesTable, DataTable analyzersTable, DataTable scalingFactorsTable)
        {
            return companiesTable.AsEnumerable().Select(companyRow => new
            {
                Company = companyRow.Table.Columns.Cast<DataColumn>().ToDictionary(col => col.ColumnName, col => companyRow[col]),
                Stations = stationsTable.AsEnumerable()
                    .Where(stationRow => stationRow.Field<int>("CompanyId") == companyRow.Field<int>("Id"))
                    .Select(stationRow => new
                    {
                        Station = stationRow.Table.Columns.Cast<DataColumn>().ToDictionary(col => col.ColumnName, col => stationRow[col]),
                        Channels = channelsTable.AsEnumerable()
                            .Where(channelRow => channelRow.Field<int>("StationId") == stationRow.Field<int>("Id"))
                            .Select(channelRow => new
                            {
                                Channel = channelRow.Table.Columns.Cast<DataColumn>().ToDictionary(col => col.ColumnName, col => channelRow[col]),
                                ChannelType = channelTypesTable.AsEnumerable()
                                    .FirstOrDefault(ct => ct.Field<int>("Id") == channelRow.Field<int>("ChannelTypeId")),
                                Oxide = oxidesTable.AsEnumerable()
                                    .FirstOrDefault(oxideRow => oxideRow.Field<int>("Id") == channelRow.Field<int>("OxideId")),
                                Analyzer = analyzersTable.AsEnumerable()
                                    .FirstOrDefault(analyzerRow => analyzerRow.Field<int>("Id") == channelRow.Field<int>("ProtocolId")),
                                ScalingFactor = scalingFactorsTable.AsEnumerable()
                                    .FirstOrDefault(scalingFactorRow => scalingFactorRow.Field<int>("Id") == channelRow.Field<int>("ScalingFactorId"))
                            })
                            .ToList(),
                        MonitoringType = monitoringTypesTable.AsEnumerable()
                            .FirstOrDefault(monitoringRow => monitoringRow.Field<int>("Id") == stationRow.Field<int>("MonitoringTypeId"))
                    })
                    .ToList()
            }).ToList();
        }

        private static object BuildLicenseData(DataTable licensesTable)
        {
            return licensesTable.AsEnumerable().Select(licenseRow => new
            {
                License = licenseRow.Table.Columns.Cast<DataColumn>().ToDictionary(col => col.ColumnName, col => licenseRow[col])
            }).ToList();
        }

        private static object BuildConfigSettingData(DataTable configSettingsTable)
        {
            return configSettingsTable.AsEnumerable().Select(configSettingRow => new
            {
                ConfigSetting = configSettingRow.Table.Columns.Cast<DataColumn>().ToDictionary(col => col.ColumnName, col => configSettingRow[col])
            }).ToList();
        }
    }
    public class JsonBuilder
    {
        public static string BuildJson(DataTable companies, DataTable stations, DataTable channels,
                                       DataTable analyzers, DataTable oxides, DataTable channelTypes,
                                       DataTable scalingFactors, DataTable monitoringTypes)
        {
            var companyList = new List<object>();

            foreach (DataRow companyRow in companies.Rows)
            {
                var companyId = companyRow["CompanyId"];
                var companyName = companyRow["Name"];

                // Get stations for each company
                var stationList = stations.AsEnumerable()
                                          .Where(s => s["CompanyId"].Equals(companyId))
                                          .Select(s => new
                                          {
                                              StationId = s["StationId"],
                                              MonitoringTypeId = s["MonitoringTypeId"],
                                              MonitoringType = monitoringTypes.AsEnumerable()
                                                                              .FirstOrDefault(m => m["MonitoringTypeId"].Equals(s["MonitoringTypeId"]))?["Name"],
                                          // Get channels for each station
                                          Channels = channels.AsEnumerable()
                                                                  .Where(c => c["StationId"].Equals(s["StationId"]))
                                                                  .Select(c => new
                                                                  {
                                                                      ChannelId = c["ChannelId"],
                                                                      ProtocolId = c["ProtocolId"],
                                                                      OxideId = c["OxideId"],
                                                                      ChannelTypeId = c["ChannelTypeId"],
                                                                      ScalingFactorId = c["ScalingFactorId"],
                                                                  // Get related foreign keys for each channel
                                                                  Analyzer = analyzers.AsEnumerable()
                                                                                          .FirstOrDefault(a => a["AnalyzerId"].Equals(c["ProtocolId"]))?["Name"],
                                                                      Oxide = oxides.AsEnumerable()
                                                                                    .FirstOrDefault(o => o["OxideId"].Equals(c["OxideId"]))?["Name"],
                                                                      ChannelType = channelTypes.AsEnumerable()
                                                                                        .FirstOrDefault(ct => ct["ChannelTypeId"].Equals(c["ChannelTypeId"]))?["Name"],
                                                                      ScalingFactor = scalingFactors.AsEnumerable()
                                                                                        .FirstOrDefault(sf => sf["ScalingFactorId"].Equals(c["ScalingFactorId"]))?["Name"]
                                                                  }).ToList()
                                          }).ToList();

                companyList.Add(new
                {
                    CompanyId = companyId,
                    Name = companyName,
                    Stations = stationList
                });
            }

            // Serialize the company list to JSON
            string json = JsonConvert.SerializeObject(companyList);
            return json;
        }
    }
    public class DatabaseFetcher
    {
        private string connectionString;

        public DatabaseFetcher(string connectionString)
        {
            this.connectionString = connectionString;
        }

        public DataTable FetchData(string query)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                connection.Open();
                using (var command = new SqlCommand(query, connection))
                {
                    using (var adapter = new SqlDataAdapter(command))
                    {
                        var dataTable = new DataTable();
                        adapter.Fill(dataTable);
                        return dataTable;
                    }
                }
            }
        }
        public DataTable FetchCompanies()
        {
            string query = "SELECT * FROM Company";
            return FetchData(query);
        }

        public DataTable FetchMonitoringTypes()
        {
            string query = "SELECT * FROM MonitoringType";
            return FetchData(query);
        }

        public DataTable FetchStations(int companyId)
        {
            string query = "SELECT * FROM Station WHERE CompanyId = @CompanyId";
            using (var connection = new SqlConnection(connectionString))
            {
                connection.Open();
                using (var command = new SqlCommand(query, connection))
                {
                    command.Parameters.AddWithValue("@CompanyId", companyId);
                    using (var adapter = new SqlDataAdapter(command))
                    {
                        var dataTable = new DataTable();
                        adapter.Fill(dataTable);
                        return dataTable;
                    }
                }
            }
        }

        public DataTable FetchChannels(int stationId)
        {
            string query = "SELECT * FROM Channel WHERE StationId = @StationId";
            using (var connection = new SqlConnection(connectionString))
            {
                connection.Open();
                using (var command = new SqlCommand(query, connection))
                {
                    command.Parameters.AddWithValue("@StationId", stationId);
                    using (var adapter = new SqlDataAdapter(command))
                    {
                        var dataTable = new DataTable();
                        adapter.Fill(dataTable);
                        return dataTable;
                    }
                }
            }
        }

        // Fetch related foreign key tables
        public DataTable FetchAnalyzers()
        {
            string query = "SELECT * FROM Analyzer";
            return FetchData(query);
        }

        public DataTable FetchOxides()
        {
            string query = "SELECT * FROM Oxide";
            return FetchData(query);
        }

        public DataTable FetchChannelTypes()
        {
            string query = "SELECT * FROM ChannelType";
            return FetchData(query);
        }

        public DataTable FetchScalingFactors()
        {
            string query = "SELECT * FROM ScalingFactor";
            return FetchData(query);
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
