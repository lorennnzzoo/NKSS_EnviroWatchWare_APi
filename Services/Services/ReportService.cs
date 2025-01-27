using Models.Post.Report;
using Models.Report;
using Newtonsoft.Json;
using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
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
        public ReportService(IChannelRepository channelRepository, IStationRepository stationRepository, ICompanyRepository companyRepository, IReportRepository reportRepository)
        {
            _channelRepository = channelRepository;
            _stationRepository = stationRepository;
            _companyRepository = companyRepository;
            _reportRepository = reportRepository;
        }

        public DataTable GenerateReport(List<int> ChannelIds, Models.Post.Report.ReportType reportType, DataAggregationType dataAggregationType, DateTime From, DateTime To)
        {
            switch (reportType)
            {
                case ReportType.DataReport:
                    switch (dataAggregationType)
                    {
                        case DataAggregationType.Raw:
                            return _reportRepository.GetRawChannelDataReportAsDataTable(ChannelIds, From, To);
                        case DataAggregationType.FifteenMin:
                            return _reportRepository.GetAvgChannelDataReportAsDataTable(ChannelIds, From, To, 15);
                        case DataAggregationType.OneHour:
                            return _reportRepository.GetAvgChannelDataReportAsDataTable(ChannelIds, From, To, 60);
                        default:
                            return new DataTable();
                    }

                case ReportType.Exceedance:
                    switch (dataAggregationType)
                    {
                        case DataAggregationType.Raw:
                            return _reportRepository.GetAvgChannelDataExceedanceReportAsDataTable(ChannelIds, From, To,1);
                        case DataAggregationType.FifteenMin:
                            return _reportRepository.GetAvgChannelDataExceedanceReportAsDataTable(ChannelIds, From, To, 15);
                        case DataAggregationType.OneHour:
                            return _reportRepository.GetAvgChannelDataExceedanceReportAsDataTable(ChannelIds, From, To, 60);
                        default:
                            return new DataTable();
                    }
                default:
                    return new DataTable();
            }            
        }
        public List<ChannelDataReport> GetReport(ReportFilter filter)
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
                    channelsOfStation.AddRange( matchingValues.Count > 0 ? _channelRepository.GetAll().Where(e => matchingValues.Contains(Convert.ToInt32(e.Id))).ToList() : _channelRepository.GetAll().ToList());
                    StationChannelPairs.Add(stationId, matchingValues.Count > 0 ? matchingValues : channelIds);
                }
            }
            
            else if (filter.StationsId != null && filter.StationsId.Count > 0)
            {
                foreach (int stationId in filter.StationsId)
                {
                    List<int> channelIds = GetChannelIdsForStation(stationId);
                    stationsOfCompany.Add(_stationRepository.GetById(stationId));
                    channelsOfStation.AddRange( _channelRepository.GetAll().Where(e => e.StationId == stationId).Where(e => e.Active == true).ToList());
                    StationChannelPairs.Add(stationId, channelIds);
                }
            }
            
            else
            {
                List<int> stationIds = _stationRepository.GetAll()
                                                         .Where(e => e.CompanyId == filter.CompanyId).Where(e=>e.Active=true)
                                                         .Select(e => e.Id).OfType<int>()
                                                         .ToList();

                foreach (int stationId in stationIds)
                {
                    List<int> channelIds = GetChannelIdsForStation(stationId);
                    stationsOfCompany.Add(_stationRepository.GetById(stationId));
                    channelsOfStation.AddRange( _channelRepository.GetAll().Where(e => e.StationId == stationId).Where(e=>e.Active==true).ToList());
                    StationChannelPairs.Add(stationId, channelIds);
                }
            }


            DataTable reportDataTable =GenerateReport(channelsOfStation.Select(e => e.Id).OfType<int>().ToList(),filter.ReportType, filter.DataAggregationType,Convert.ToDateTime( filter.From), Convert.ToDateTime(filter.To));
            List<ChannelDataReport> reportData = new List<ChannelDataReport>();
            switch(filter.ReportType)
            {
                case ReportType.Exceedance:
                     reportData=TransformDataTableToExceedanceReport(reportDataTable);
                    break;
                case ReportType.DataReport:
                    reportData = TransformDataTableToDataReport(reportDataTable);
                    break;
                default:
                    reportData = new List<ChannelDataReport>();
                    break;
            }
            return reportData;
        }



















        public List<ChannelDataReport> TransformDataTableToDataReport(DataTable dataTable)
        {
            var results = new List<ChannelDataReport>();

            foreach (DataRow row in dataTable.Rows)
            {
                var result = new ChannelDataReport
                {
                    ChannelDataLogTime = row.Field<DateTime>("ChannelDataLogTime"),
                    DynamicColumns = new Dictionary<string, string>()
                };

                // Deserialize the JSONB column into a dictionary
                var dynamicColumnsJson = row.Field<string>("dynamic_columns");
                if (!string.IsNullOrEmpty(dynamicColumnsJson))
                {
                    result.DynamicColumns = Newtonsoft.Json.JsonConvert
                        .DeserializeObject<Dictionary<string, string>>(dynamicColumnsJson);
                }

                results.Add(result);
            }

            return results;
        }

        public List<ChannelDataReport> TransformDataTableToExceedanceReport(DataTable dataTable)
        {
            var results = new List<ChannelDataReport>();

            foreach (DataRow row in dataTable.Rows)
            {
                var result = new ChannelDataReport
                {
                    ChannelDataLogTime = row.Field<DateTime>("ChannelDataLogTime"),
                    DynamicColumns = new Dictionary<string, string>()
                };

                // Get the raw JSON string from the data
                var dynamicColumnsJson = row.Field<string>("dynamic_columns");

                // Clean up the double quotes by replacing doubled quotes ("") with single quotes (")
                if (!string.IsNullOrEmpty(dynamicColumnsJson))
                {
                    dynamicColumnsJson = dynamicColumnsJson.Replace("\"\"", "\"");

                    try
                    {
                        // Now deserialize the cleaned-up JSON string
                        var dynamicColumns = Newtonsoft.Json.JsonConvert
                            .DeserializeObject<Dictionary<string, Dictionary<string, object>>>(dynamicColumnsJson);

                        // Iterate through the channels in the dynamic columns
                        foreach (var dynamicColumn in dynamicColumns)
                        {
                            // Add each channel's data to the result
                            var channelKey = dynamicColumn.Key;
                            var channelData = dynamicColumn.Value;

                            // You can access "Exceeded" and "avg_value" from the channelData dictionary
                            if (channelData.ContainsKey("Exceeded"))
                            {
                                result.DynamicColumns.Add(channelKey + "-Exceeded", channelData["Exceeded"].ToString());
                            }

                            if (channelData.ContainsKey("avg_value"))
                            {
                                result.DynamicColumns.Add(channelKey, channelData["avg_value"].ToString());
                            }
                        }
                    }
                    catch (JsonException ex)
                    {
                        Console.WriteLine("Error deserializing dynamic columns: " + ex.Message);
                    }
                }

                // Add the result to the list
                results.Add(result);
            }

            return results;
        }




        public Models.Report.Selection.SelectionModel GetSelectionModel()
        {
            Models.Report.Selection.SelectionModel selectionModel = new Models.Report.Selection.SelectionModel();
            var companies = _companyRepository.GetAll();

            foreach(var company in companies)
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
        private List<int> GetChannelIdsForStation(int stationId)
        {
            return _channelRepository.GetAll()
                                     .Where(e => e.StationId == stationId).Where(e=>e.Active=true)
                                     .Select(e => e.Id).OfType<int>()
                                     .ToList();
        }

    }
}
