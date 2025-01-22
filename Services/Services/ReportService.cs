using Models.Post.Report;
using Models.Report;
using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
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

        public List<Data> GenerateReport(int ChannelId, DataAggregationType dataAggregationType, DateTime From, DateTime To)
        {
            
            switch (dataAggregationType)
            {
                case DataAggregationType.Raw:
                    return _reportRepository.GenerateRawDataReportForChannel(ChannelId, From, To);
                case DataAggregationType.FifteenMin:
                    return _reportRepository.Generate15MinsAvgReportForChannel(ChannelId, From, To);
                case DataAggregationType.OneHour:
                    return _reportRepository.Generate1HourAvgReportForChannel(ChannelId, From, To);
                case DataAggregationType.TwelveHours:
                    return _reportRepository.Generate12HourAvgReportForChannel(ChannelId, From, To);
                case DataAggregationType.TwentyFourHours:
                    return _reportRepository.Generate24HourAvgReportForChannel(ChannelId, From, To);
                case DataAggregationType.Month:
                    return _reportRepository.GenerateMonthAvgReportForChannel(ChannelId, From, To);
                case DataAggregationType.SixMonths:
                    return _reportRepository.GenerateSixMonthAvgReportForChannel(ChannelId, From, To);
                case DataAggregationType.Year:
                    return _reportRepository.GenerateYearAvgReportForChannel(ChannelId, From, To);
                default:
                    return new List<Data>();
            }            
        }

        public ReportData GetReport(ReportFilter filter)
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

            
            ReportData reportData = new ReportData {
                Company = new Company
                {
                    Name=companyDetail.LegalName,
                    Address=companyDetail.Address,
                    Logo=companyDetail.Logo,
                    Stations = stationsOfCompany.Select(e =>new Station
                    {
                        Name=e.Name,
                        Channels=channelsOfStation.Where(S=>S.StationId==e.Id).Select(c=>new Channel
                        {
                            Name=c.Name,
                            Units=c.LoggingUnits,  
                            Data=GenerateReport((int) c.Id,filter.DataAggregationType,Convert.ToDateTime( filter.From), Convert.ToDateTime(filter.To))
                        }).ToList()
                    }).ToList()
                },
                From= Convert.ToDateTime(filter.From),
                To= Convert.ToDateTime(filter.To),
            };

            reportData.CleanChannelLessData();
            return reportData;
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
