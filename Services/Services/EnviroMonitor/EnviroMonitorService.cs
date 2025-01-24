using Models;
using Services.Interfaces;
using Services.Interfaces.EnviroMonitor;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Services.EnviroMonitor
{
    public class EnviroMonitorService : IEnviroMonitorService
    {
        private readonly IConfigSettingService configSettingService;
        private readonly IStationService stationService;
        private readonly IAnalyzerService analyzerService;
        private IChannelService channelService;       
        public EnviroMonitorService(IConfigSettingService _configSettingService, IStationService _stationService, IAnalyzerService _analyzerService, IChannelService _channelService)
        {
            configSettingService = _configSettingService;
            stationService = _stationService;
            analyzerService = _analyzerService;
            channelService = _channelService;
        }
        public void Run(List<ConfigSetting> configSettings)
        {
            List<Station> stations = LoadStations();
            ProcessStations(stations);
        }

        private void ProcessStations(List<Station> stations)
        {
            foreach(Station station in stations)
            {
                List<Channel> channels = LoadChannels((int)station.Id);
                ProcessChannels(channels);
            }
        }
        private void ProcessChannels(List<Channel> channels)
        {
            foreach(Channel channel in channels)
            {
                Analyzer analyzer= GetAnalyzer((int)channel.ProtocolId);
            }
        }

        private Analyzer GetAnalyzer(int analyzerId)
        {
            return analyzerService.GetAnalyzerById(analyzerId);
        }
        private List<Station> LoadStations()
        {
            return stationService.GetAllStations().ToList();
        }
        private List<Channel> LoadChannels(int stationId)
        {
            return channelService.GetAllChannelsByStationId(stationId).ToList();
        }
    }
}
