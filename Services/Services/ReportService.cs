using Models.Post.Report;
using Models.Report;
using Newtonsoft.Json;
using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class ReportService : IReportService
    {
        private readonly IChannelRepository _channelRepository;
        private readonly IStationRepository _stationRepository;
        private readonly ICompanyRepository _companyRepository;
        private readonly IReportRepository _reportRepository;
        private readonly string _databaseProvider;
        public ReportService(IChannelRepository channelRepository, IStationRepository stationRepository, ICompanyRepository companyRepository, IReportRepository reportRepository)
        {
            _databaseProvider = ConfigurationManager.AppSettings["DatabaseProvider"];
            _channelRepository = channelRepository;
            _stationRepository = stationRepository;
            _companyRepository = companyRepository;
            _reportRepository = reportRepository;
        }

        public DataTable GenerateReport(List<int> ChannelIds, Models.Post.Report.ReportType reportType, DataAggregationType dataAggregationType, DateTime From, DateTime To)
        {
            switch (reportType)
            {
                case ReportType.DataAvailability:
                    switch (dataAggregationType)
                    {
                        case DataAggregationType.Raw:
                            return _reportRepository.GetAvailabilityReport(ChannelIds, From, To);
                        case DataAggregationType.FiveMin:
                            return _reportRepository.GetAvailabilityReport(ChannelIds, From, To);
                        case DataAggregationType.FifteenMin:
                            return _reportRepository.GetAvailabilityReport(ChannelIds, From, To);
                        case DataAggregationType.ThirtyMin:
                            return _reportRepository.GetAvailabilityReport(ChannelIds, From, To);
                        case DataAggregationType.OneHour:
                            return _reportRepository.GetAvailabilityReport(ChannelIds, From, To);
                        case DataAggregationType.Day:
                            return _reportRepository.GetAvailabilityReport(ChannelIds, From, To);
                        default:
                            return new DataTable();
                    }
                case ReportType.DataReport:
                    switch (dataAggregationType)
                    {
                        case DataAggregationType.Raw:
                            return _reportRepository.GetRawDataReport(ChannelIds, From, To);
                        case DataAggregationType.FiveMin:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 5);
                        case DataAggregationType.FifteenMin:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 15);
                        case DataAggregationType.ThirtyMin:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 30);
                        case DataAggregationType.OneHour:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 60);
                        case DataAggregationType.Day:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 1440);
                        default:
                            return new DataTable();
                    }

                case ReportType.Exceedance:
                    switch (dataAggregationType)
                    {
                        case DataAggregationType.Raw:
                            return _reportRepository.GetRawExceedanceReport(ChannelIds, From, To);
                        case DataAggregationType.FiveMin:
                            return _reportRepository.GetAverageExceedanceReport(ChannelIds, From, To, 5);
                        case DataAggregationType.FifteenMin:
                            return _reportRepository.GetAverageExceedanceReport(ChannelIds, From, To, 15);
                        case DataAggregationType.ThirtyMin:
                            return _reportRepository.GetAverageExceedanceReport(ChannelIds, From, To, 30);
                        case DataAggregationType.OneHour:
                            return _reportRepository.GetAverageExceedanceReport(ChannelIds, From, To, 60);
                        case DataAggregationType.Day:
                            return _reportRepository.GetAverageExceedanceReport(ChannelIds, From, To, 1440);
                        default:
                            return new DataTable();
                    }
                case ReportType.Trends:
                    switch (dataAggregationType)
                    {
                        case DataAggregationType.Raw:
                            return _reportRepository.GetRawDataReport(ChannelIds, From, To);
                        case DataAggregationType.FiveMin:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 5);
                        case DataAggregationType.FifteenMin:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 15);
                        case DataAggregationType.ThirtyMin:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 30);
                        case DataAggregationType.OneHour:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 60);
                        case DataAggregationType.Day:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 1440);
                        default:
                            return new DataTable();
                    }
                case ReportType.Windrose:
                    switch (dataAggregationType)
                    {
                        case DataAggregationType.Raw:
                            return _reportRepository.GetRawDataReport(ChannelIds, From, To);
                        case DataAggregationType.FiveMin:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 5);
                        case DataAggregationType.FifteenMin:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 15);
                        case DataAggregationType.ThirtyMin:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 30);
                        case DataAggregationType.OneHour:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 60);
                        case DataAggregationType.Day:
                            return _reportRepository.GetAverageDataReport(ChannelIds, From, To, 1440);
                        default:
                            return new DataTable();
                    }
                default:
                    return new DataTable();
            }
        }
        public List<Dictionary<string,object>> GetReport(ReportFilter filter)
        {

            Dictionary<int, List<int>> StationChannelPairs = new Dictionary<int, List<int>>();
            Models.Company companyDetail = _companyRepository.GetById(filter.CompanyId);
            List<Models.Station> stationsOfCompany = new List<Models.Station>();
            List<Models.Channel> channelsOfStation = new List<Models.Channel>();


            if (filter.StationsId != null && filter.StationsId.Count > 0 && filter.ChannelsId != null && filter.ChannelsId.Count > 0)
            {
                foreach (int stationId in filter.StationsId)
                {
                    List<int> channelIds = GetChannelIdsForStation(stationId);


                    List<int> matchingValues = channelIds.Intersect(filter.ChannelsId).ToList();


                    stationsOfCompany.Add(_stationRepository.GetById(stationId));
                    channelsOfStation.AddRange(matchingValues.Count > 0 ? _channelRepository.GetAll().Where(e => matchingValues.Contains(Convert.ToInt32(e.Id))).ToList() : _channelRepository.GetAll().ToList());
                    StationChannelPairs.Add(stationId, matchingValues.Count > 0 ? matchingValues : channelIds);
                }
            }

            else if (filter.StationsId != null && filter.StationsId.Count > 0)
            {
                foreach (int stationId in filter.StationsId)
                {
                    List<int> channelIds = GetChannelIdsForStation(stationId);
                    stationsOfCompany.Add(_stationRepository.GetById(stationId));
                    channelsOfStation.AddRange(_channelRepository.GetAll().Where(e => e.StationId == stationId).Where(e => e.Active == true).ToList());
                    StationChannelPairs.Add(stationId, channelIds);
                }
            }

            else
            {
                List<int> stationIds = _stationRepository.GetAll()
                                                         .Where(e => e.CompanyId == filter.CompanyId).Where(e => e.Active = true)
                                                         .Select(e => e.Id).OfType<int>()
                                                         .ToList();

                foreach (int stationId in stationIds)
                {
                    List<int> channelIds = GetChannelIdsForStation(stationId);
                    stationsOfCompany.Add(_stationRepository.GetById(stationId));
                    channelsOfStation.AddRange(_channelRepository.GetAll().Where(e => e.StationId == stationId).Where(e => e.Active == true).ToList());
                    StationChannelPairs.Add(stationId, channelIds);
                }
            }


            DataTable reportDataTable = GenerateReport(channelsOfStation.Select(e => e.Id).OfType<int>().ToList(), filter.ReportType, filter.DataAggregationType, Convert.ToDateTime(filter.From), Convert.ToDateTime(filter.To));
            List<Dictionary<string, object>> reportData = new List<Dictionary<string, object>>();
            switch (filter.ReportType)
            {
                case ReportType.DataAvailability:
                    reportData = TransformTableToList(reportDataTable);
                    break;
                case ReportType.Exceedance:
                    if (filter.DataAggregationType != DataAggregationType.Raw)
                    {
                        reportData = TransformAverageTableToList(reportDataTable);
                    }
                    else
                    {
                        reportData = TransformTableToList(reportDataTable);
                    }
                    break;
                case ReportType.DataReport:
                    if (filter.DataAggregationType != DataAggregationType.Raw)
                    {
                        reportData = TransformAverageTableToList(reportDataTable);
                    }
                    else
                    {
                        reportData = TransformTableToList(reportDataTable);
                    }
                    break;
                case ReportType.Trends:
                    if (filter.DataAggregationType != DataAggregationType.Raw)
                    {
                        reportData = TransformAverageTableToList(reportDataTable);
                    }
                    else
                    {
                        reportData = TransformTableToList(reportDataTable);
                    }
                    break;
                case ReportType.Windrose:
                    if (filter.DataAggregationType != DataAggregationType.Raw)
                    {
                        reportData = TransformAverageTableToList(reportDataTable);
                    }
                    else
                    {
                        reportData = TransformTableToList(reportDataTable);
                    }
                    break;
                default:
                    reportData = new List<Dictionary<string, object>>();
                    break;
            }
            return reportData;
        }

        public Models.Report.Selection.SelectionModel GetSelectionModel()
        {
            Models.Report.Selection.SelectionModel selectionModel = new Models.Report.Selection.SelectionModel();
            var companies = _companyRepository.GetAll();

            foreach (var company in companies)
            {
                Models.Report.Selection.Company companySelection = new Models.Report.Selection.Company();
                companySelection.Id = Convert.ToInt32(company.Id);
                companySelection.Name = company.LegalName;

                var stationsOfCompany = _stationRepository.GetAll().Where(e => e.CompanyId == company.Id);
                if (stationsOfCompany.Count() > 0)
                {
                    foreach (var station in stationsOfCompany)
                    {
                        Models.Report.Selection.Station stationSelection = new Models.Report.Selection.Station();
                        stationSelection.Id = Convert.ToInt32(station.Id);
                        stationSelection.Name = station.Name;

                        var channelsOfStation = _channelRepository.GetAll().Where(e => e.StationId == station.Id);
                        foreach (var channel in channelsOfStation)
                        {
                            Models.Report.Selection.Channel channelSelection = new Models.Report.Selection.Channel();
                            channelSelection.Id = Convert.ToInt32(channel.Id);
                            channelSelection.Name = channel.Name;
                            stationSelection.Channels.Add(channelSelection);
                        }
                        companySelection.Stations.Add(stationSelection);
                    }
                }
                selectionModel.Companies.Add(companySelection);
                selectionModel.CleanUp();
            }
            return selectionModel;
        }

        //public List<Dictionary<string, object>> TransformTableToList(DataTable dataTable)
        //{
        //    var result = new List<Dictionary<string, object>>();
        //    foreach (DataRow row in dataTable.Rows)
        //    {
        //        var rowDict = new Dictionary<string, object>();
        //        foreach (DataColumn col in dataTable.Columns)
        //        {
        //            if (col.ColumnName.Contains("_") && !col.ColumnName.Contains("_E")) continue;
        //            if (col.ColumnName.ToUpper() == "LOGTIME")
        //            {
        //                rowDict[col.ColumnName] = row[col] == DBNull.Value ? null : Convert.ToDateTime(row[col]).ToString("yyyy-MMM-dd HH:mm");
        //            }
        //            else
        //            {
        //                rowDict[col.ColumnName] = row[col] == DBNull.Value ? null : row[col];
        //            }
        //        }
        //        result.Add(rowDict);
        //    }

        //    return result;
        //}

        //public List<Dictionary<string, object>> TransformTableToList(DataTable dataTable)
        //{
        //    var result = new List<Dictionary<string, object>>();
        //    if (dataTable == null || dataTable.Rows.Count == 0) 
        //    {
        //        return result; 
        //    }

        //    string logTimeColumnName = "LOGTIME";
        //    StringComparison caseInsensitiveComparison = StringComparison.OrdinalIgnoreCase;

        //    foreach (DataRow row in dataTable.Rows)
        //    {
        //        var rowDict = new Dictionary<string, object>();
        //        foreach (DataColumn col in dataTable.Columns)
        //        {
        //            string columnName = col.ColumnName;

        //            bool containsUnderscore = columnName.Contains("_");
        //            bool containsUnderscoreE = columnName.Contains("_E");
        //            bool isLogTime = string.Equals(columnName, logTimeColumnName, caseInsensitiveComparison);

        //            if (containsUnderscore && !containsUnderscoreE)
        //            {
        //                continue; 
        //            }

        //            if (isLogTime)
        //            {                        
        //                rowDict[columnName] = row[col] == DBNull.Value ? null : Convert.ToDateTime(row[col]).ToString("yyyy-MMM-dd HH:mm");
        //            }
        //            else
        //            {
        //                rowDict[columnName] = row[col] == DBNull.Value ? null : row[col];
        //            }
        //        }
        //        result.Add(rowDict);
        //    }

        //    return result;
        //}

        public List<Dictionary<string, object>> TransformTableToList(DataTable dataTable)
        {
            var result = new List<Dictionary<string, object>>();
            if (dataTable == null || dataTable.Rows.Count == 0)
            {
                return result;
            }

            string logTimeColumnName = "LOGTIME";
            StringComparison caseInsensitiveComparison = StringComparison.OrdinalIgnoreCase;

            int originalRowCount = dataTable.Rows.Count;
            for (int i = 0; i < originalRowCount; i++)
            {
                DataRow row = dataTable.Rows[0]; 
                var rowDict = new Dictionary<string, object>();
                foreach (DataColumn col in dataTable.Columns)
                {
                    string columnName = col.ColumnName;

                    //bool containsUnderscore = columnName.Contains('_');
                    //bool containsUnderscoreE = columnName.Contains("_E");
                    bool isLogTime = string.Equals(columnName, logTimeColumnName, caseInsensitiveComparison);

                    //if (containsUnderscore && !containsUnderscoreE)
                    //{
                    //    continue;
                    //}

                    if (isLogTime)
                    {
                        rowDict[columnName] = row[col] == DBNull.Value ? null : Convert.ToDateTime(row[col]).ToString("yyyy-MMM-dd HH:mm");
                    }
                    else
                    {
                        rowDict[columnName] = row[col] == DBNull.Value ? "NA" : row[col];
                    }
                }
                result.Add(rowDict);
                dataTable.Rows.Remove(row);
            }

            return result;
        }

        //public List<Dictionary<string, object>> TransformTableToList(DataTable dataTable)
        //{
        //    var result = new List<Dictionary<string, object>>(dataTable.Rows.Count);

        //    for (int i = dataTable.Rows.Count - 1; i >= 0; i--) 
        //    {
        //        DataRow row = dataTable.Rows[i];
        //        var rowDict = new Dictionary<string, object>();

        //        foreach (DataColumn col in dataTable.Columns)
        //        {
        //            if (col.ColumnName.Contains("_") && !col.ColumnName.Contains("_E")) continue;

        //            if (col.ColumnName.ToUpper() == "LOGTIME")
        //            {
        //                rowDict[col.ColumnName] = row[col] == DBNull.Value ? null : Convert.ToDateTime(row[col]).ToString("yyyy-MMM-dd HH:mm");
        //            }
        //            else
        //            {
        //                rowDict[col.ColumnName] = row[col] == DBNull.Value ? null : row[col];
        //            }
        //        }

        //        result.Add(rowDict);
        //        dataTable.Rows.RemoveAt(i); 
        //    }

        //    dataTable.Clear(); 
        //    return result;
        //}


        //public List<Dictionary<string, object>> TransformAverageTableToList(DataTable dataTable)
        //{
        //    var result = new List<Dictionary<string, object>>();
        //    foreach (DataRow row in dataTable.Rows)
        //    {
        //        var rowDict = new Dictionary<string, object>();
        //        foreach (DataColumn col in dataTable.Columns)
        //        {
        //            if (col.ColumnName.Contains("_") && !col.ColumnName.Contains("_E")) continue;
        //            if (col.ColumnName.ToUpper() == "LOGTIME")
        //            {
        //                rowDict[col.ColumnName] = row[col] == DBNull.Value ? null : Convert.ToDateTime(row[col]).AddHours(-5).AddMinutes(-30).ToString("yyyy-MMM-dd HH:mm");
        //            }
        //            else
        //            {
        //                rowDict[col.ColumnName] = row[col] == DBNull.Value ? null : row[col];
        //            }
        //        }
        //        result.Add(rowDict);
        //    }

        //    return result;
        //}

        //public List<Dictionary<string, object>> TransformAverageTableToList(DataTable dataTable)
        //{
        //    var result = new List<Dictionary<string, object>>();
        //    if (dataTable == null || dataTable.Rows.Count == 0) 
        //    {
        //        return result; 
        //    }

        //    string logTimeColumnName = "LOGTIME";
        //    StringComparison caseInsensitiveComparison = StringComparison.OrdinalIgnoreCase;
        //    TimeSpan timeOffset = new TimeSpan(-5, -30, 0); 

        //    foreach (DataRow row in dataTable.Rows)
        //    {
        //        var rowDict = new Dictionary<string, object>();
        //        foreach (DataColumn col in dataTable.Columns)
        //        {
        //            string columnName = col.ColumnName;

        //            bool containsUnderscore = columnName.Contains("_");//ignoring other columns
        //            bool containsUnderscoreE = columnName.Contains("_E");
        //            bool isLogTime = string.Equals(columnName, logTimeColumnName, caseInsensitiveComparison);

        //            if (containsUnderscore && !containsUnderscoreE)
        //            {
        //                continue; 
        //            }

        //            if (isLogTime)
        //            {                        
        //                rowDict[columnName] = row[col] == DBNull.Value ? null : Convert.ToDateTime(row[col]).Add(timeOffset).ToString("yyyy-MMM-dd HH:mm");
        //            }
        //            else
        //            {
        //                rowDict[columnName] = row[col] == DBNull.Value ? null : row[col];
        //            }
        //        }
        //        result.Add(rowDict);
        //    }

        //    return result;
        //}

        public List<Dictionary<string, object>> TransformAverageTableToList(DataTable dataTable)
        {
            if (_databaseProvider == "NPGSQL")
            {
                var result = new List<Dictionary<string, object>>();
                if (dataTable == null || dataTable.Rows.Count == 0)
                {
                    return result;
                }
                string logTimeColumnName = "LOGTIME";
                StringComparison caseInsensitiveComparison = StringComparison.OrdinalIgnoreCase;
                TimeSpan timeOffset = new TimeSpan(-5, -30, 0);

                int originalRowCount = dataTable.Rows.Count;
                for (int i = 0; i < originalRowCount; i++)
                {
                    DataRow row = dataTable.Rows[0];
                    var rowDict = new Dictionary<string, object>();

                    foreach (DataColumn col in dataTable.Columns)
                    {
                        string columnName = col.ColumnName;

                        //bool containsUnderscore = columnName.Contains('_');
                        //bool containsUnderscoreE = columnName.Contains("_E");
                        bool isLogTime = string.Equals(columnName, logTimeColumnName, caseInsensitiveComparison);

                        //if (containsUnderscore && !containsUnderscoreE)
                        //{
                        //    continue;
                        //}
                        if (isLogTime)
                        {
                            rowDict[columnName] = row[col] == DBNull.Value
                                ? null
                                : Convert.ToDateTime(row[col]).Add(timeOffset).ToString("yyyy-MMM-dd HH:mm");
                        }
                        else
                        {
                            rowDict[columnName] = row[col] == DBNull.Value ? "NA" : row[col];
                        }
                    }
                    result.Add(rowDict);
                    dataTable.Rows.Remove(row);
                }
                return result;
            }
            else
            {
                var result = new List<Dictionary<string, object>>();
                if (dataTable == null || dataTable.Rows.Count == 0)
                {
                    return result;
                }
                string logTimeColumnName = "LOGTIME";
                StringComparison caseInsensitiveComparison = StringComparison.OrdinalIgnoreCase;
                TimeSpan timeOffset = new TimeSpan(-5, -30, 0);

                int originalRowCount = dataTable.Rows.Count;
                for (int i = 0; i < originalRowCount; i++)
                {
                    DataRow row = dataTable.Rows[0];
                    var rowDict = new Dictionary<string, object>();

                    foreach (DataColumn col in dataTable.Columns)
                    {
                        string columnName = col.ColumnName;

                        bool containsUnderscore = columnName.Contains('_');
                        bool containsUnderscoreE = columnName.Contains("_E");
                        bool isLogTime = string.Equals(columnName, logTimeColumnName, caseInsensitiveComparison);

                        if (containsUnderscore && !containsUnderscoreE)
                        {
                            continue;
                        }
                        if (isLogTime)
                        {
                            rowDict[columnName] = row[col] == DBNull.Value
                                ? null
                                : Convert.ToDateTime(row[col]).ToString("yyyy-MMM-dd HH:mm");
                        }
                        else
                        {
                            rowDict[columnName] = row[col] == DBNull.Value ? null : row[col];
                        }
                    }
                    result.Add(rowDict);
                    dataTable.Rows.Remove(row);
                }
                return result;
            }
        }

        //public List<Dictionary<string, object>> TransformAverageTableToList(DataTable dataTable)
        //{
        //    var result = new List<Dictionary<string, object>>(dataTable.Rows.Count);

        //    for (int i = dataTable.Rows.Count - 1; i >= 0; i--) 
        //    {
        //        DataRow row = dataTable.Rows[i];
        //        var rowDict = new Dictionary<string, object>();

        //        foreach (DataColumn col in dataTable.Columns)
        //        {
        //            if (col.ColumnName.Contains("_") && !col.ColumnName.Contains("_E")) continue;

        //            if (col.ColumnName.ToUpper() == "LOGTIME")
        //            {
        //                rowDict[col.ColumnName] = row[col] == DBNull.Value ? null
        //                    : Convert.ToDateTime(row[col]).AddHours(-5).AddMinutes(-30).ToString("yyyy-MMM-dd HH:mm");
        //            }
        //            else
        //            {
        //                rowDict[col.ColumnName] = row[col] == DBNull.Value ? null : row[col];
        //            }
        //        }

        //        result.Add(rowDict);
        //        dataTable.Rows.RemoveAt(i); 
        //    }

        //    dataTable.Clear();
        //    return result;
        //}


        private List<int> GetChannelIdsForStation(int stationId)
        {
            return _channelRepository.GetAll()
                                     .Where(e => e.StationId == stationId).Where(e => e.Active = true)
                                     .Select(e => e.Id).OfType<int>()
                                     .ToList();
        }
    }
}
